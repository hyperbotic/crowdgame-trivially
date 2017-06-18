# ==================================================================================================================
class HTTPServerProxy

  gInstance = null
  kHTTPServerJSFile = "http_server_stub.js"

  # ----------------------------------------------------------------------------------------------------------------
  @get: ()-> gInstance

  # ----------------------------------------------------------------------------------------------------------------
  @create: (fnServerReady, fnSocketOpened, fnSocketClosed, fnMessageReceived, fnStatusChange, ownThread=false)->

    if not gInstance?
      new HTTPServerProxy(fnServerReady, fnSocketOpened, fnSocketClosed, fnMessageReceived, fnStatusChange, ownThread)

    return gInstance

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (@fnServerReady, @fnSocketOpened, @fnSocketClosed, @fnMessageReceived, @fnServiceStatusChange, @ownThread)->
    Hy.Trace.debug("HTTPServerProxy::constructor")

    gInstance = this

    this.initHandlers()

    this.start()

    this

  # ----------------------------------------------------------------------------------------------------------------
  isOwnThread: ()-> @ownThread

  # ----------------------------------------------------------------------------------------------------------------
  initState: ()->
    @started = false
    @ready = false
    @sockets = []

    if @window
      @window.close()
      @window = null

    this

  # ----------------------------------------------------------------------------------------------------------------
  start: ()->
    Hy.Trace.debug("HTTPServerProxy::start (ownThread=#{@ownThread})")

    this.initState()

    if @ownThread
      @window = Ti.UI.createWindow(this.windowOptions())
      @window.open()
      @window.hide()
    else
      # instance can be referenced via Hy.Network.HTTPServer.get(), defined in http_server.coffee/js
      require("generated_js/http_server.js") # 2.7

    @started = true

    this

  # ----------------------------------------------------------------------------------------------------------------
  restart: ()->
    Hy.Trace.debug("HTTPServerProxy::restart (ownThread=#{@ownThread})")

    if @ownThread
       Ti.App.fireEvent("httpServerRestart", {})
    else
       Hy.Network.HTTPServer.get().restart()

    this

  # ----------------------------------------------------------------------------------------------------------------
  stop: ()->
    Hy.Trace.debug("HTTPServerProxy::stop")

#    if @ownThread
#      Ti.App.fireEvent("httpServerStop", {})
#    else
#      Hy.Network.HTTPServer.get().stop()

    this.initState()

    this

  # ----------------------------------------------------------------------------------------------------------------
  windowOptions: ()->
    {
      zIndex : 0, 
      url    : kHTTPServerJSFile
    }

  # ----------------------------------------------------------------------------------------------------------------
  # These events are fired only when the HTTP Server is running is its own thread
  initHandlers: ()->
    Ti.App.addEventListener("httpServerReady",           
                            (e)=>
                               this.serverReady(e.hostname, e.port)
                               null)

    Ti.App.addEventListener("httpServerMessageReceived", 
                            (e)=>
                               this.messageReceived(e.socketID, e.message)
                               null)

    Ti.App.addEventListener("httpServerSocketOpened",    
                            (e)=>
                               this.socketOpened(e.socketID)
                               null)

    Ti.App.addEventListener("httpServerSocketClosed",    
                            (e)=>
                               this.socketClosed(e.socketID)
                               null)

    Ti.App.addEventListener("httpServerServiceStatusChange",    
                            (e)=>
                               this.serviceStatusChange(e.status, e.domain, e.type_, e.name)
                               null)


  # ----------------------------------------------------------------------------------------------------------------
  getHostname: ()->
    @hostname

  # ----------------------------------------------------------------------------------------------------------------
  getPort: ()->
    @port

  # ----------------------------------------------------------------------------------------------------------------
  dumpStr: ()->
    "HTTPServerProxy (#{@hostname}:#{@port} #{if @started then "STARTED" else "NOT STARTED"} #sockets=#{_.size(@sockets)})"

  # ----------------------------------------------------------------------------------------------------------------
  isStarted: ()->
    @started

  # ----------------------------------------------------------------------------------------------------------------
  isReady: ()->
    @ready

  # ----------------------------------------------------------------------------------------------------------------
  findSocketByID: (socketID)->
    _.detect(@sockets, (s)=>s.socketID is socketID)

  # ----------------------------------------------------------------------------------------------------------------
  serverReady: (hostname, port)->
    @ready = true
    @hostname = hostname
    @port = port

    @fnServerReady?(this)

    Hy.Trace.debug("HTTPServerProxy::serverReady (#{this.dumpStr()})")

    this

  # ----------------------------------------------------------------------------------------------------------------
  socketOpened: (socketID)->

    if this.findSocketByID(socketID)
      Hy.Trace.debug "httpServer::socketOpened (duplicate socket #{socketID})"
    else
      @sockets.push {socketID:socketID}    

      Hy.Trace.debug("HTTPServerProxy::socketOpened (#{socketID} #{this.dumpStr()})")

    @fnSocketOpened?(this, socketID)

    this

  # ----------------------------------------------------------------------------------------------------------------
  socketClosed: (socketID)->

    if this.findSocketByID(socketID)
      Hy.Trace.debug("HTTPServerProxy::socketClosed (#{socketID} #{this.dumpStr()})")
      @sockets = _.reject(@sockets, (s)=>s.socketID is socketID)

      @fnSocketClosed?(this, socketID)
    else
      Hy.Trace.debug "httpServer::socketClosed (unknown socket #{socketID})"

    this

  # ----------------------------------------------------------------------------------------------------------------
  serviceStatusChange: (status, domain, type_, name)->

    Hy.Trace.debug "HTTPServerProxy::serviceStatusChange (#{status}: #{domain} #{type_} #{name})"

    @fnServiceStatusChange(status, domain, type_, name)

    this

  # ----------------------------------------------------------------------------------------------------------------
  sendMessage: (socketID, m)->

    if this.isReady()    
      if this.findSocketByID(socketID)
        Hy.Trace.debug("HTTPServerProxy::sendMessage (#{socketID} #{m})")

        if @ownThread
          Ti.App.fireEvent("httpServerSendMessage", {socketID:socketID, message:m})
        else
          Hy.Network.HTTPServer.get().sendMessage(socketID, m)

      else
        Hy.Trace.debug "httpServer::sendMessage (socket not found #{socketID})"
    else
      Hy.Trace.debug "httpServer::sendMessage (NOT READY)"

    this

  # ----------------------------------------------------------------------------------------------------------------
  messageReceived: (socketID, message)->

    Hy.Trace.debug("HTTPServerProxy::messageReceived (#{socketID} #{message})")

    @fnMessageReceived?(this, socketID, message)

    this

# ==================================================================================================================
# assign to global namespace:
if not Hy.Network?
  Hy.Network = {}

Hy.Network.HTTPServerProxy = HTTPServerProxy



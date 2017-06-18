# ==================================================================================================================
class HTTPServer

  gInstance = null

  # ----------------------------------------------------------------------------------------------------------------
  @get: ()-> gInstance

  # ----------------------------------------------------------------------------------------------------------------
  @init: (mod)->
    new HTTPServer(mod)

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (@trivnet)->

    gInstance = this

    @ownThread = true
    @proxy = false

    if Hy.Network.HTTPServerProxy?
      @proxy = Hy.Network.HTTPServerProxy.get()

      if @proxy?
        @ownThread = @proxy.isOwnThread()

    this.initHandlers()

    @trivnet.startServer()

    this.startWatchdog()

    this

  # ----------------------------------------------------------------------------------------------------------------
  isOwnThread: ()-> @ownThread

  # ----------------------------------------------------------------------------------------------------------------
  startWatchdog: ()->

    Ti.API.debug "HTTPServer::startWatchdog"
  
    this.stopWatchdog()

    @fn_Watchdog = ()=>
      Ti.API.debug "HTTPServer::watchdog (module pattern=#{@trivnet.pattern})"

    setInterval @fn_Watchdog, 20*1000

    this

  # ----------------------------------------------------------------------------------------------------------------
  stopWatchdog: ()->

    if @fn_Watchdog?
      clearInterval @fn_Watchdog

    this

  # ----------------------------------------------------------------------------------------------------------------
  #
  initHandlers: ()->

    @trivnet.addEventListener("httpServerReady",           
                              (e)=>
                                 this.httpServerReady(e)
                                 null)

    @trivnet.addEventListener("httpServerMessageReceived", 
                              (e)=>
                                 this.httpServerMessageReceived(e)
                                 null)

    @trivnet.addEventListener("httpServerSocketOpened",    
                              (e)=>
                                 this.httpServerSocketOpened(e)
                                 null)

    @trivnet.addEventListener("httpServerSocketClosed",    
                              (e)=>
                                 this.httpServerSocketClosed(e)
                                 null)

    @trivnet.addEventListener("httpServerServiceStatusChange",    
                              (e)=>
                                 this.httpServerServiceStatusChange(e)
                                 null)

    # These are used if running in our own thread. If not, HTTPServerProxy calls the corresponding methods directly
    Ti.App.addEventListener("httpServerSendMessage",       
                            (e)=>
                              this.sendMessage(e.socketID, e.message)
                              null)

    Ti.App.addEventListener("httpServerStop",              
                            (e)=>
                               this.stop()
                               null)

    Ti.App.addEventListener("httpServerRestart",           
                            (e)=>
                               this.restart()
                               null)
    this

  # ----------------------------------------------------------------------------------------------------------------
  httpServerReady: (e)->

    if this.isOwnThread()
      Ti.App.fireEvent("httpServerReady", e)
    else
      @proxy.serverReady(e.hostname, e.port)

    this

  # ---------------------------------------------------------------------------------------------------------------
  httpServerMessageReceived: (e)->
    
    if this.isOwnThread()
      Ti.App.fireEvent("httpServerMessageReceived", e)
    else
      @proxy.messageReceived(e.socketID, e.message)

    this

  # ----------------------------------------------------------------------------------------------------------------
  httpServerSocketOpened: (e)->

    if this.isOwnThread()
      Ti.App.fireEvent("httpServerSocketOpened", e)
    else
      @proxy.socketOpened(e.socketID)

    this

  # ----------------------------------------------------------------------------------------------------------------
  httpServerSocketClosed: (e)->

    if this.isOwnThread()
      Ti.App.fireEvent("httpServerSocketClosed", e)
    else
      @proxy.socketClosed(e.socketID)

    this

  # ----------------------------------------------------------------------------------------------------------------
  httpServerServiceStatusChange: (e)->

    Hy.Trace.debug("HTTPServer::httpServerServiceStatusChange(#{e.status} #{e.domain} #{e.type_} #{e.name})")

    if this.isOwnThread()
      Ti.App.fireEvent("httpServerServiceStatusChange", e)
    else
      @proxy.serviceStatusChange(e.status, e.domain, e.type_, e.name)

    this


  # ----------------------------------------------------------------------------------------------------------------
  sendMessage: (socketID, message)->
    @trivnet.sendMessage(socketID, message)
    this

  # ----------------------------------------------------------------------------------------------------------------
  stop: ()->
    Ti.API.debug "HTTPServer::stop"
    @trivnet.stop()

    this

  # ----------------------------------------------------------------------------------------------------------------
  restart: ()->

    Ti.API.debug "HTTPServer::restart"

    if false
      @trivnet.restart() #crashes
    else  
      try
        @trivnet.restart() #crashes
      catch e
        Hy.Trace.debug("HTTPServer::restart (EXCEPTION=#{e.message})")

    this


# ==================================================================================================================

if not Hy.Network?
  Hy.Network = {}

Hy.Network.HTTPServer = HTTPServer

mod = require('com.crowdgame.trivnet') # 2.7
#mod = require('./trivnet-v1.1-for-2.5.0')
HTTPServer.init(mod)


# ==================================================================================================================
# This class is how the main app (in its own thread) communications with the PlayerNetwork (in a different thread)
# To send a request to the PlayerNetwork thread, this class fires events. To receive messages, it registers event handlers.
# ==================================================================================================================
class PlayerNetworkProxy

  kPlayerNetworkStubJSFile = "player_network_stub.js"

  # ----------------------------------------------------------------------------------------------------------------
  # Public interface
  # ----------------------------------------------------------------------------------------------------------------

  # ----------------------------------------------------------------------------------------------------------------
  @create: (fnReady, fnError, fnMessageReceived, fnAddPlayer, fnRemovePlayer, fnPlayerStatusChange, fnServiceStatusChange)->

    new PlayerNetworkProxy(fnReady, fnError, fnMessageReceived, fnAddPlayer, fnRemovePlayer, fnPlayerStatusChange, fnServiceStatusChange)

  # ----------------------------------------------------------------------------------------------------------------
  isOwnThread: ()-> @ownThread

  # ----------------------------------------------------------------------------------------------------------------
  start: ()->

    if this.isOwnThread()
      @window = Ti.UI.createWindow(this.windowOptions())
      @window.open()
      @window.hide()
    else
      require('generated_js/http_server_proxy.js')
      require('generated_js/player_network.js')

      new Hy.Network.PlayerNetwork()

    @started = true

    this

  # ----------------------------------------------------------------------------------------------------------------
  stop: ()->
    Ti.App.fireEvent("playerNetwork_Stop", {})

    this.initState()

    this

  # ----------------------------------------------------------------------------------------------------------------
  pause: ()->
    Ti.App.fireEvent("playerNetwork_Pause", {})

    @paused = true
    @ready = false

    this

  # ----------------------------------------------------------------------------------------------------------------
  resumed: ()->
    Ti.App.fireEvent("playerNetwork_Resumed", {})

    @paused = false

    this

  # ----------------------------------------------------------------------------------------------------------------
  isStarted: () -> @started

  # ----------------------------------------------------------------------------------------------------------------
  isReady: ()-> @ready

  # ----------------------------------------------------------------------------------------------------------------
  isPaused: ()-> @paused

  # ----------------------------------------------------------------------------------------------------------------
  sendSingle: (connectionIndex, op, data)->

    result = true

    if this.isReady()
      Ti.App.fireEvent("playerNetwork_SendSingle", {connectionIndex:connectionIndex, op:op, data:data})
    else
      Hy.Trace.debug "PlayerNetworkProxy::sendSingle (ERROR NOT READY op=#{op})"
      result = false

    result

  # ----------------------------------------------------------------------------------------------------------------
  sendAll: (op, data)->

    result = true

    if this.isReady()
      Ti.App.fireEvent("playerNetwork_SendAll", {op:op, data:data})
    else
      Hy.Trace.debug "PlayerNetworkProxy::sendAll (ERROR NOT READY op=#{op})"
      result = false

    result

  # ----------------------------------------------------------------------------------------------------------------
  # Internal interface
  # ----------------------------------------------------------------------------------------------------------------

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (@fnReady, @fnError, @fnMessageReceived, @fnAddPlayer, @fnRemovePlayer, @fnPlayerStatusChange, @fnServiceStatusChange)->

    @ownThread = Hy.Config.PlayerNetwork.RunsInOwnThread

    this.initState()

    this.initHandlers()

    this.start()

    this

  # ----------------------------------------------------------------------------------------------------------------
  initState: ()->
    @started = false
    @ready = false
    @paused = false

    if @window?
      @window.close()
      @window = null

    this

  # ----------------------------------------------------------------------------------------------------------------
  windowOptions: ()->
    {
      zIndex : 0, 
      url    : kPlayerNetworkStubJSFile,
    }

  # ----------------------------------------------------------------------------------------------------------------
  initHandlers: ()->

    Ti.App.addEventListener("playerNetwork_Ready",              
                           (e)=> 
                             @ready = true
                             @fnReady(e.httpPort)
                             null)

    Ti.App.addEventListener("playerNetwork_Error",              
                           (e)=>
                             @fnError(e.error, e.restartNetwork)
                             null)

    Ti.App.addEventListener("playerNetwork_MessageReceived",    
                            (e)=>
                              @fnMessageReceived(e.playerConnectionIndex, e.op, e.data)
                              null)

    Ti.App.addEventListener("playerNetwork_AddPlayer",          
                            (e)=>
                              @fnAddPlayer(e.playerConnectionIndex, e.playerLabel, e.majorVersion, e.minorVersion)
                              null)

    Ti.App.addEventListener("playerNetwork_RemovePlayer",       
                            (e)=>
                              @fnRemovePlayer(e.playerConnectionIndex)
                              null)

    Ti.App.addEventListener("playerNetwork_PlayerStatusChange", 
                            (e)=>
                              @fnPlayerStatusChange(e.playerConnectionIndex, e.status)
                              null)

    Ti.App.addEventListener("playerNetwork_ServiceStatusChange", 
                            (e)=>
                              @fnServiceStatusChange(e.serviceStatus)
                              null)

    this

# ==================================================================================================================
# assign to global namespace:
if not Hy.Network?
  Hy.Network = {}

Hy.Network.PlayerNetworkProxy = PlayerNetworkProxy



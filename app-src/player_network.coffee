# TODO
# Factor out Message, MessageQueue so that these can be used for HTTP as well, if necessary
# Figure out how to stop HTTP Service
# Figure out how to close a socket associated with an HTTP user that has been removed
# Abstract various message types, refactor used of "messageInfo"
#
#
# message = <connection><data>
#
# <connection> = <core_connection> [<bonjour_connection> | <http_connection>]
#  <core_connection> = tag:
#  <bonjour_connection> = dest:value + ??
#
# ==================================================================================================================
# Abstracts all player network interactions. A single instance is created, running in its own thread,
# when the application is initialized, via the .js file "player_network_stub.js", which is attached to a
# standalone window (and therefore runs in its own thread).
#
# The main app communicates with this instance via the "PlayerNetworkProxy" class; PlayerNetworkProxy" and "PlayerNetwork" 
# fire/listen for events across the thread boundaries.
#
#
# Manages an instance of Bonjour network service, HTTP nework service for players, etc.
#
# Responds to these global events:
#   "playerNetwork_Stop"        {}
#   "playerNetwork_Pause"       {}
#   "playerNetwork_Resumed"     {}
#   "playerNetwork_SendSingle"  {connectionIndex, op, data}
#   "playerNetwork_SendAll"     {op, data}
#
# Fires these global events
#
#   "playerNetwork_Ready"               {httpPort}
#   "playerNetwork_Error"               {error, restartNetwork}
#   "playerNetwork_MessageReceived"     {playerConnectionIndex, op, data}
#   "playerNetwork_AddPlayer"           {playerConnectionIndex, playerLabel}
#   "playerNetwork_RemovePlayer"        {playerConnectionIndex}
#   "playerNetwork_PlayerStatusChange"  {playerConnectionIndex, status}
#   "playerNetwork_ServiceStatusChange" {serviceStatus}
#

class PlayerNetwork

  @kKindHTTP    = 1
  @kKindBonjour = 2

  # ----------------------------------------------------------------------------------------------------------------
  # Methods below are "private" or "protected", used only by this class and friends
  # ----------------------------------------------------------------------------------------------------------------

  # ----------------------------------------------------------------------------------------------------------------
  constructor: ()->

    this.init()
    this.initHandlers()

    this

  # ----------------------------------------------------------------------------------------------------------------
  init: ()->
    @receivedMessageProcessors = []
    @sentMessageProcessors = []

    this.startServices()

    PlayerConnection.start(this)

    ActivityMonitor.start(this)

    this

  # ----------------------------------------------------------------------------------------------------------------
  startServices: ()->

    @services = []

    s1 = {kind: PlayerNetwork.kKindHTTP}
    s2 = {kind: PlayerNetwork.kKindBonjour}

    @services.push s1
#    @services.push s2 # No bonjour discovery for V2

    @serviceWatchdog = new ServiceStartupWatchdog(this)

    s1.service = (new HTTPPlayerService(this)).start()
#    s2.service = (new BonjourService(this)).start()

    this

  # ----------------------------------------------------------------------------------------------------------------
  # After a "stop", can not restart the same instance. Must start over again with a new instance
  #
  stop: ()->

    for s in @services
      s.service?.stop()

    @serviceWatchdog?.stop()

    ActivityMonitor.stop()

    PlayerConnection.stop()

    this

  # ----------------------------------------------------------------------------------------------------------------
  pause: ()->

    @serviceWatchdog?.pause()

    for s in @services
      s.service?.pause()

    ActivityMonitor.pause()

    PlayerConnection.pause()

    this

  # ----------------------------------------------------------------------------------------------------------------
  resumed: ()->

    @serviceWatchdog?.resumed()

    for s in @services
      s.service?.resumed()

    PlayerConnection.resumed()

    ActivityMonitor.resumed()

    this

  # ----------------------------------------------------------------------------------------------------------------
  initHandlers: ()->

    Ti.App.addEventListener("playerNetwork_Stop",           
                            (e)=>
                                this.stop()
                                null)

    Ti.App.addEventListener("playerNetwork_Pause",          
                            (e)=>
                                this.pause()
                                null)

    Ti.App.addEventListener("playerNetwork_Resumed",        
                            (e)=>
                                this.resumed()
                                null)

    Ti.App.addEventListener("playerNetwork_SendSingle",     
                            (e)=>
                                this.sendSingle(e.connectionIndex, e.op, e.data)
                                null)

    Ti.App.addEventListener("playerNetwork_SendAll",        
                            (e)=>
                                this.sendAll(e.op, e.data)
                                null)

    this

  # ----------------------------------------------------------------------------------------------------------------
  setServiceReady: (service)->

    @serviceWatchdog?.serviceCheckin(service)

  # ----------------------------------------------------------------------------------------------------------------
  sendSingle: (connectionIndex, op, data)->

    playerConnection = PlayerConnection.findByIndex(connectionIndex)

    # We use an anonymous object, "messageInfo", to group together message-related info, which
    # allows message processors to rewrite the data as necesssary before it's sent off.
    # TODO: consider abstracting messages into a hierarchy of sorts, to keep this a little 
    # more sane.

    message = {op:op, data:data}    
    messageInfo = {playerConnection:playerConnection, message:message, handled:false}
    messageInfo = this.doSentMessageProcessors(messageInfo)

    if messageInfo.playerConnection?
      service = messageInfo.playerConnection.getService()

      if service?
#        Hy.Trace.debug "PlayerNetwork::sendSingle (op=#{messageInfo.message.op} #{messageInfo.playerConnection.dumpStr()})"
        service.sendSingle(messageInfo.playerConnection, messageInfo.message.op, messageInfo.message.data)
      else
        Hy.Trace.debug "PlayerNetwork::sendSingle (ERROR NO SERVICE for #{connectionIndex})"

    else
      Hy.Trace.debug "PlayerNetwork::sendSingle (ERROR CANT FIND PlayerConnection for #{connectionIndex})"

    this

  # ----------------------------------------------------------------------------------------------------------------
  sendAll: (op, data)->

    Hy.Trace.debug "PlayerNetwork::sendAll (op=#{op})"

    message = {op:op, data:data}
    messageInfo = {message:message, handled:false}
    messageInfo = this.doSentMessageProcessors(messageInfo)

    for s in @services
      s.service?.sendAll(messageInfo.message.op, messageInfo.message.data)

    this

  # ----------------------------------------------------------------------------------------------------------------
  doReady: ()->

    httpPlayerService = this.findService(PlayerNetwork.kKindHTTP)
    if httpPlayerService?
      port = httpPlayerService.service.getPort()
    Ti.App.fireEvent("playerNetwork_Ready", {httpPort:port})

  # ----------------------------------------------------------------------------------------------------------------
  doError: (error, restartNetwork=false)->

    Hy.Trace.debug "PlayerNetwork::doError (ERROR /#{error}/ restartNetwork=#{restartNetwork})"

    Ti.App.fireEvent("playerNetwork_Error", {error:error, restartNetwork:restartNetwork})

    this

  # ----------------------------------------------------------------------------------------------------------------
  doMessageReceived: (playerConnectionIndex, op, data)->

    Hy.Trace.debug "PlayerNetwork::doMessageReceived (op=#{op} data=#{data})"

    Ti.App.fireEvent("playerNetwork_MessageReceived", {playerConnectionIndex:playerConnectionIndex, op:op, data:data})

    this

  # ----------------------------------------------------------------------------------------------------------------
  doAddPlayer: (playerConnectionIndex, playerLabel, majorVersion, minorVersion)->

    Hy.Trace.debug "PlayerNetwork::doAddPlayer (##{playerConnectionIndex}/#{playerLabel})"

    Ti.App.fireEvent("playerNetwork_AddPlayer", {playerConnectionIndex:playerConnectionIndex, playerLabel:playerLabel, majorVersion:majorVersion, minorVersion:minorVersion}) 

    this

  # ----------------------------------------------------------------------------------------------------------------
  doRemovePlayer: (playerConnectionIndex)->

    Ti.App.fireEvent("playerNetwork_RemovePlayer", {playerConnectionIndex:playerConnectionIndex})

    this

  # ----------------------------------------------------------------------------------------------------------------
  doPlayerStatusChange: (playerConnectionIndex, status)->

    Ti.App.fireEvent("playerNetwork_PlayerStatusChange", {playerConnectionIndex:playerConnectionIndex, status:status})

    this

  # ----------------------------------------------------------------------------------------------------------------
  doServiceStatusChange: (serviceStatus)->

    Ti.App.fireEvent("playerNetwork_ServiceStatusChange", {serviceStatus: serviceStatus})

    this
  # ----------------------------------------------------------------------------------------------------------------
  getServices: ()->
    @services

  # ----------------------------------------------------------------------------------------------------------------
  findService: (kind)->

    _.detect(@services, (s)=>s.kind is kind)

  # ----------------------------------------------------------------------------------------------------------------
  findServiceByConnection: (connection)->

    this.findService(connection.kind)

  # ----------------------------------------------------------------------------------------------------------------
  addReceivedMessageProcessor: (fn)->

    @receivedMessageProcessors.push fn  

  # ----------------------------------------------------------------------------------------------------------------
  addSentMessageProcessor: (fn)->

    @sentMessageProcessors.push fn  

  # ----------------------------------------------------------------------------------------------------------------
  doMessageProcessors: (list, messageInfo)->

    for fn in list
      messageInfo = fn(this, messageInfo)

    messageInfo

  # ----------------------------------------------------------------------------------------------------------------
  doReceivedMessageProcessors: (messageInfo)->

    this.doMessageProcessors(@receivedMessageProcessors, messageInfo)

  # ----------------------------------------------------------------------------------------------------------------
  doSentMessageProcessors: (messageInfo)->

    this.doMessageProcessors(@sentMessageProcessors, messageInfo)

  # ----------------------------------------------------------------------------------------------------------------
  messageReceived: (connection, message)->

    playerConnection = PlayerConnection.findByConnection(connection)

#    Hy.Trace.debug "PlayerNetwork::messageReceived (/#{message.op}/ from #{if playerConnection? then playerConnection.dumpStr() else connection.kind})"

    # We use an anonymous object, "messageInfo", to group together message-related info, which
    # allows message processors to rewrite the data as necesssary before it's sent off.
    # TODO: consider abstracting messages into a hierarchy of sorts, to keep this a little 
    # more sane.

    messageInfo = {connection:connection, playerConnection:playerConnection, message:message, handled:false}

    messageInfo = this.doReceivedMessageProcessors(messageInfo)

    if not messageInfo.handled
      if messageInfo.playerConnection?
        this.doMessageReceived(messageInfo.playerConnection.getIndex(), messageInfo.message.op, messageInfo.message.data)
      else
        this.doError("Unhandled message Received from unknown player (op=#{messageInfo.message.op}")
    
    this

# ==================================================================================================================
class ServiceStartupWatchdog

  kServiceStartupTimeout = 15 * 1000

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (@networkManager)->

    this.initState()

    this.setTimer()

    this

  # ----------------------------------------------------------------------------------------------------------------
  initState: ()->
    @paused = false
    @ready = false
    @failed = false

    this.clearReadyState()

    this.clearTimer()

    this

  # ----------------------------------------------------------------------------------------------------------------
  clearTimer: ()->
    if @timer?
      @timer.clear()
      @timer = null

    this

  # ----------------------------------------------------------------------------------------------------------------
  clearReadyState: ()->

    for s in @networkManager.getServices()
      s.ready = false

    this

  # ----------------------------------------------------------------------------------------------------------------
  setTimer: ()->

    this.clearTimer()    
    @timer = Hy.Utils.Deferral.create(kServiceStartupTimeout, ()=>this.timerExpired())

    this

  # ----------------------------------------------------------------------------------------------------------------
  timerExpired: ()->

    snr = this.servicesNotReady()

    if _.size(snr) is 0
      @ready = true  # Should never get here
    else
      @failed = true

      failedServices = ""
      for s in snr
        failedServices += "#{s.kind} "

      @networkManager.doError("Player network services did not start in time: #{failedServices}", true)

    this

  # ----------------------------------------------------------------------------------------------------------------
  servicesNotReady: ()->
     _.select(@networkManager.getServices(), (s)=>not s.ready)
  
  # ----------------------------------------------------------------------------------------------------------------
  serviceCheckin: (service)->

    s = @networkManager.findService(service.getKind())

    if s?
      s.ready = true

    snr = this.servicesNotReady()

    Hy.Trace.debug "ServiceStartupWatchdog::serviceCheckin (service=#{service.getKind()} # not ready = #{_.size(snr)})"

    if _.size(snr) is 0
      @ready = true
      this.clearTimer()
      @networkManager.doReady()

    this

  # ----------------------------------------------------------------------------------------------------------------
  stop: ()->

    this.clearTimer()

  # ----------------------------------------------------------------------------------------------------------------
  pause: ()->

    this.clearTimer()

  # ----------------------------------------------------------------------------------------------------------------
  resumed: ()->

    this.initState()
    this.setTimer()

# ==================================================================================================================
# Abstract superclass representing what we need to keep track of a player's connection to the app. 
#
# PlayerConnection
#     HTTPPlayerConnection
#     BonjourPlayerConnection

class PlayerConnection

  gInstanceCount = 0
  gInstances = []

  @kStatusActive       = 1
  @kStatusInactive     = 2
  @kStatusDisconnected = 3 # when a remote has disconnected... we allow some time to reconnect

  # ----------------------------------------------------------------------------------------------------------------
  @start: (networkManager)->

    gInstances = []

    gInstanceCount = 0

    networkManager.addReceivedMessageProcessor(PlayerConnection.processReceivedMessage)
    networkManager.addSentMessageProcessor(PlayerConnection.processSentMessage)

  # ----------------------------------------------------------------------------------------------------------------
  @stop: ()->

    for pc in PlayerConnection.getPlayerConnections()
      pc.stop()

    gInstances = []

    null

  # ----------------------------------------------------------------------------------------------------------------
  @pause: ()->

    for pc in PlayerConnection.getPlayerConnections()
      pc.pause()

    null

  # ----------------------------------------------------------------------------------------------------------------
  @resumed: ()->

    for pc in PlayerConnection.getPlayerConnections()
      pc.resumed()

  # ----------------------------------------------------------------------------------------------------------------
  @processReceivedMessage: (networkManager, messageInfo)->

#    Hy.Trace.debug "PlayerConnection::processReceivedMessage (#{messageInfo.message.op})"

    switch messageInfo.message.op 
     when "suspend" # HTTP clients don't send this
        messageInfo.handled = true
        if messageInfo.playerConnection? 
          Hy.Trace.debug "PlayerConnection::processReceivedMessage (suspend #{messageInfo.playerConnection.dumpStr()})"
          messageInfo.playerConnection.deactivate(true)

      when "resumed" # HTTP clients don't send this
        messageInfo.handled = true
        if messageInfo.playerConnection? 
          Hy.Trace.debug "PlayerConnection::processReceivedMessage (resumed #{messageInfo.playerConnection.dumpStr()})"

      when "join"
        messageInfo.handled = true
        messageInfo = PlayerConnection.join(networkManager, messageInfo)

    messageInfo

  # ----------------------------------------------------------------------------------------------------------------
  @processSentMessage: (networkManager, messageInfo)->

    Hy.Trace.debug "PlayerConnection::processSentMessage (#{messageInfo.message.op})"

    switch messageInfo.message.op
      when "welcome"
        messageInfo.handled = true
        if messageInfo.playerConnection? and messageInfo.playerConnection.tagIsGenerated()

            # We add in the tag, which we generated and which is assigned to some clients, such as those connected via HTTP. 
            # Other clients (Bonjour) tell us their tags when they send a join message (and so this is redundant). 
            # This is a legacy situation.

            messageInfo.message.data.assignedTag = messageInfo.playerConnection.getTag()

    messageInfo

  # ----------------------------------------------------------------------------------------------------------------
  @join: (networkManager, messageInfo)->

    if not messageInfo.playerConnection?
      # Is this a request from a player we've already seen? Check the tag
      tag = messageInfo.message.tag

      if tag?
        messageInfo.playerConnection = PlayerConnection.findByTag(tag)

    if messageInfo.playerConnection?
      # An existing player may be rejoining over a different socket, etc.
      PlayerConnection.swap(messageInfo.playerConnection, messageInfo.connection)
    else
      messageInfo.playerConnection = PlayerConnection.create(networkManager, messageInfo.connection, messageInfo.message.data)

    # We always send a "welcome" when we receive a join
    if messageInfo.playerConnection?
      networkManager.doAddPlayer(messageInfo.playerConnection.getIndex(), messageInfo.playerConnection.getLabel(), messageInfo.playerConnection.getMajorVersion(), messageInfo.playerConnection.getMinorVersion())

    messageInfo

  # ----------------------------------------------------------------------------------------------------------------
  # If an existing player connects over a new socket. We want to keep the higher-level player state while swapping
  # out the specifics of the connection. 
  #
  @swap: (playerConnection, newConnection)->

    # Tell the current remote to go away
    playerConnection.getService().sendSingle(playerConnection, "ejected", {reason:"You connected in another browser window"}, false)

    # Swap in our new connection info, the higher-level app code won't know the difference
    playerConnection.resetConnection(newConnection)

    # Will result in the console app doing a reactivate, and then sending a welcome. A little wierd.
    playerConnection.activate()

    this

  # ----------------------------------------------------------------------------------------------------------------
  @create: (networkManager, connection, data)->

    playerConnection = null

    t = null
    switch connection.kind
      when PlayerNetwork.kKindHTTP   
        t = HTTPPlayerConnection
      when PlayerNetwork.kKindBonjour
        t = BonjourPlayerConnection

    if t?
      playerConnection = t.create(networkManager, connection, data)

    playerConnection

  # ----------------------------------------------------------------------------------------------------------------
  @getPlayerConnections: ()-> 
    gInstances

  # ----------------------------------------------------------------------------------------------------------------
  @numPlayerConnections: ()->

    _.size(gInstances)

  # ----------------------------------------------------------------------------------------------------------------
  @findByConnection: (connection)->

    _.detect(PlayerConnection.getPlayerConnections(), (pc)=>pc.compare(connection))

  # ----------------------------------------------------------------------------------------------------------------
  @findByIndex: (index)->
    
    _.detect(PlayerConnection.getPlayerConnections(), (pc)=>pc.getIndex() is index)

  # ----------------------------------------------------------------------------------------------------------------
  @findByTag: (tag)->
    
    _.detect(PlayerConnection.getPlayerConnections(), (pc)=>pc.getTag() is tag)

  # ----------------------------------------------------------------------------------------------------------------
  @getActivePlayerConnections: ()->

    _.select(PlayerConnection.getPlayerConnections(), (pc)->pc.isActive())

  # ----------------------------------------------------------------------------------------------------------------
  @getActivePlayersByServiceKind: (kind)->

    _.select(PlayerConnection.getPlayerConnections(), (pc)->(pc.isActive()) and (pc.getKind() is kind))

  # ----------------------------------------------------------------------------------------------------------------  
  # Does some basic checks before we allow a new remote player to join
  #
  @preAddPlayer: (networkManager, connection, data)->

    status = true

    # Check version
    status = status and PlayerConnection.checkPlayerVersion(networkManager, connection, data)

    # Are we at player limit?
    status = status and PlayerConnection.makeRoomForPlayer(networkManager, connection, data)

    status

  # ----------------------------------------------------------------------------------------------------------------  
  @makeRoomForPlayer: (networkManager, connection, data)->

    status = true

    if PlayerConnection.numPlayerConnections() >= Hy.Config.kMaxRemotePlayers
      Hy.Trace.debug "PlayerConnection::makeRoomForPlayer (count=#{PlayerConnection.numPlayerConnections()} limit=#{Hy.Config.kMaxRemotePlayers})"

      toRemove = []
      for p in PlayerConnection.getPlayerConnections()
        if !p.isActive()
          toRemove.push p

      for p in toRemove
        Hy.Trace.debug "PlayerConnection::makeRoomForPlayer (Removing player: #{p.dumpStr()}, count=#{PlayerConnection.numPlayerConnections()})"
        p.remove("You appear to be inactive,<br>so we are making room for another player")

      if PlayerConnection.numPlayerConnections() >= Hy.Config.kMaxRemotePlayers
        Hy.Trace.debug "PlayerConnection::makeRoomForPlayer (TOO MANY PLAYERS #{connection} Count=#{PlayerConnection.numPlayerConnections()})"
        s = networkManager.findServiceByConnection(connection)
        if s?
          reason = "Too many remote players!<br>(Maximum is #{Hy.Config.kMaxRemotePlayers})"
          s.service.sendSingle_(connection, "joinDenied", {reason: reason}, PlayerConnection.getLabelFromMessage(data), false)
        status = false

    return status

  # ----------------------------------------------------------------------------------------------------------------  
  @checkPlayerVersion: (networkManager, connection, data)->

    majorVersion = data.majorVersion
    minorVersion = data.minorVersion

    status = true

    if !majorVersion? or (majorVersion < Hy.Config.Version.Remote.kMinRemoteMajorVersion)
      Hy.Trace.debug "PlayerConnection::checkPlayerVersion (WRONG VERSION #{connection} Looking for #{Hy.Config.Version.Remote.kMinRemoteMajorVersion} Remote is version #{majorVersion}.#{minorVersion})"
      s = networkManager.findServiceByConnection(connection)
      if s?
        s.service.sendSingle_(connection,"joinDenied", {reason: 'Update Required! Please visit the AppStore to update this app!'}, PlayerConnection.getLabelFromMessage(data))
      status = false

    return status

  # ----------------------------------------------------------------------------------------------------------------
  @getLabelFromMessage: (data)->
    unescape(data.label)

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (@networkManager, connection, data, @requiresActivityMonitor)->

    gInstances.push this

    @majorVersion = data.majorVersion
    @minorVersion = data.minorVersion

    @label = PlayerConnection.getLabelFromMessage(data)

    @index = ++gInstanceCount

    this.setConnection(connection)

    Hy.Trace.debug "PlayerConnection::constructor (##{@index} label=/#{@label}/ tag=/#{@tag}/ count=#{_.size(gInstances)})"

    if @requiresActivityMonitor
      ActivityMonitor.addPlayerConnection(this)      

    this.activate()

    this

  # ----------------------------------------------------------------------------------------------------------------
  getIndex: ()-> @index

  # ----------------------------------------------------------------------------------------------------------------
  getNetworkManager: ()-> @networkManager

  # ----------------------------------------------------------------------------------------------------------------
  getMajorVersion: ()-> @majorVersion

  # ----------------------------------------------------------------------------------------------------------------
  getMinorVersion: ()-> @minorVersion

  # ----------------------------------------------------------------------------------------------------------------
  checkVersion: (majorVersion, minorVersion=null)->

    status = false
    if @majorVersion >= majorVersion
      if minorVersion?
        if @minorVersion >= minorVersion
          status = true
      else
        status = true

    status

  # ----------------------------------------------------------------------------------------------------------------
  setConnection: (connection)->

    @tag = connection.tag

    @generatedTag = not @tag?    

    if @generatedTag
      this.createTag()

    this
  # ----------------------------------------------------------------------------------------------------------------
  resetConnection: (connection)->

  # ----------------------------------------------------------------------------------------------------------------
  getConnection: ()-> null

  # ----------------------------------------------------------------------------------------------------------------
  getTag: (tag)-> @tag

  # ----------------------------------------------------------------------------------------------------------------
  tagIsGenerated: ()-> @generatedTag

  # ----------------------------------------------------------------------------------------------------------------
  createTag: ()->

    @generatedTag = true
    found = true

    while found
      tag = Hy.Utils.UUID.generate()
      found = PlayerConnection.findByTag(tag)?

    Hy.Trace.debug "PlayerConnection::createTag (tag=#{tag})"

    @tag = tag


  # ----------------------------------------------------------------------------------------------------------------
  getLabel: ()-> @label

  # ----------------------------------------------------------------------------------------------------------------
  compare: (connection)->

    this.getKind() is connection.kind

  # ----------------------------------------------------------------------------------------------------------------
  getService: ()->

    service = null
    s = this.getNetworkManager().findService(this.getKind())
    if s?
      service = s.service

    service

  # ----------------------------------------------------------------------------------------------------------------
  getKind: ()-> null

  # ----------------------------------------------------------------------------------------------------------------
  getStatus: ()-> @status

  # ----------------------------------------------------------------------------------------------------------------
  getStatusString: ()->

    s = switch this.getStatus()
      when PlayerConnection.kStatusActive
        "active"
      when PlayerConnection.kStatusInactive
        "inactive"
      when PlayerConnection.kStatusDisconnected
        "disconnected"
      else
        "???"

    s
  # ----------------------------------------------------------------------------------------------------------------
  setStatus: (newStatus)->

    if newStatus isnt @status
      @status = newStatus

      s = switch @status
        when PlayerConnection.kStatusActive
          true
        when PlayerConnection.kStatusInactive, PlayerConnection.kStatusDisconnected
          false
        else
          false
    
      this.getNetworkManager().doPlayerStatusChange(this.getIndex(), s)

    @status

  # ----------------------------------------------------------------------------------------------------------------
  isActive: ()->
  
    @status is PlayerConnection.kStatusActive

  # ----------------------------------------------------------------------------------------------------------------
  activate: ()->

    this.setStatus(PlayerConnection.kStatusActive)

  # ----------------------------------------------------------------------------------------------------------------
  reactivate: ()->

    this.activate()

  # ----------------------------------------------------------------------------------------------------------------
  # If "disconnected", means that the socket as closed or something similar
  #
  deactivate: (disconnected = false)->

    this.setStatus(if disconnected then PlayerConnection.kStatusDisconnected else PlayerConnection.kStatusInactive)

  # ----------------------------------------------------------------------------------------------------------------
  stop: ()->

    this.deactivate()

  # ----------------------------------------------------------------------------------------------------------------
  pause: ()->

  # ----------------------------------------------------------------------------------------------------------------
  resumed: ()->

  # ----------------------------------------------------------------------------------------------------------------
  remove: (warn=null)->

    Hy.Trace.debug "PlayerConnection::remove (Removing #{this.dumpStr()} warn=#{warn})"

    if @requiresActivityMonitor
      ActivityMonitor.removePlayerConnection(this)

    if warn?
      service = this.getService()
      if service?
        service.sendSingle(this, "ejected", {reason:warn}, false)

    gInstances = _.without(gInstances, this)

    this.getService().doneWithPlayerConnection(this)

    this.getNetworkManager().doRemovePlayer(this.getIndex())

    null

  # ----------------------------------------------------------------------------------------------------------------
  dumpStr: ()->

    "#{this.constructor.name}: ##{this.getIndex()} #{this.getLabel()} #{this.getStatusString()} #{this.getTag()}"

# ==================================================================================================================
class HTTPPlayerConnection extends PlayerConnection

  # ----------------------------------------------------------------------------------------------------------------
  @create: (networkManager, connection, data)->

    if PlayerConnection.preAddPlayer(networkManager, connection, data)
      new HTTPPlayerConnection(networkManager, connection, data)
    else
      null

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (networkManager, connection, data)->

    Hy.Trace.debug "HTTPPlayerConnection::constructor (ENTER)"

    super networkManager, connection, data, true

    Hy.Trace.debug "HTTPPlayerConnection::constructor (EXIT)"

    this

  # ----------------------------------------------------------------------------------------------------------------
  setConnection: (connection)->

    super

    @socketID = connection.socketID

    this

  # ----------------------------------------------------------------------------------------------------------------
  resetConnection: (connection)->

    super

    if connection.socketID isnt @socketID
      @socketID = connection.socketID

    this

  # ----------------------------------------------------------------------------------------------------------------
  getConnection: ()-> {kind:this.getKind(), socketID:@socketID}

  # ----------------------------------------------------------------------------------------------------------------
  getKind: ()-> PlayerNetwork.kKindHTTP

  # ----------------------------------------------------------------------------------------------------------------
  compare: (connection)->

    result = super and (@socketID is connection.socketID)

    result

  # ----------------------------------------------------------------------------------------------------------------
  dumpStr: ()->
    super + " socketID=#{@socketID}"

# ==================================================================================================================
class BonjourPlayerConnection extends PlayerConnection

  # ----------------------------------------------------------------------------------------------------------------
  @create: (networkManager, connection, data)->

    if PlayerConnection.preAddPlayer(networkManager, connection, data)
      new BonjourPlayerConnection(networkManager, connection, data)
    else
      null

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (networkManager, connection, data)->

    Hy.Trace.debug "BonjourPlayerConnection::constructor"

    # Should do a version check on the remote; if less than iOS 4, requires activityMonitor

    super networkManager, connection, data, true

    this

  # ----------------------------------------------------------------------------------------------------------------
  getConnection: ()-> {kind:this.getKind(), tag:@tag}

  # ----------------------------------------------------------------------------------------------------------------
  getKind: ()-> PlayerNetwork.kKindBonjour

  # ----------------------------------------------------------------------------------------------------------------
  compare:(connection)->

    result = super and (@tag is connection.tag)

    result

  # ----------------------------------------------------------------------------------------------------------------
  dumpStr: ()->
    super

# ==================================================================================================================
class ActivityMonitor

  gInstance = null

  # ----------------------------------------------------------------------------------------------------------------
  @start: (networkManager)->

    if gInstance?
      gInstance.stop()

    new ActivityMonitor(networkManager)

  # ----------------------------------------------------------------------------------------------------------------
  @stop: ()->
    if gInstance
      gInstance.stop()

      gInstance = null

    null

  # ----------------------------------------------------------------------------------------------------------------
  @pause: ()->

    if gInstance
      gInstance.pause()

    null

  # ----------------------------------------------------------------------------------------------------------------
  @resumed: ()->

    if gInstance
      gInstance.resumed()

    null

  # ----------------------------------------------------------------------------------------------------------------
  @getTime: ()->
    (new Date()).getTime()

  # ----------------------------------------------------------------------------------------------------------------
  @processReceivedMessage: (networkManager, messageInfo)->

    if gInstance?
      messageInfo = gInstance.processReceivedMessage(networkManager, messageInfo)

    messageInfo

  # ----------------------------------------------------------------------------------------------------------------
  @addPlayerConnection: (pc)->

    if gInstance?
      gInstance.addPlayerConnection(pc)

    null

  # ----------------------------------------------------------------------------------------------------------------
  @removePlayerConnection: (pc)->

    if gInstance?
      gInstance.removePlayerConnection(pc)

    null

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (@networkManager)->
#    Hy.Trace.debug "ActivityMonitor::constructor"

    gInstance = this

    @playerConnections = []

    @networkManager.addReceivedMessageProcessor(ActivityMonitor.processReceivedMessage)

    this.startTimer()

    this

  # ----------------------------------------------------------------------------------------------------------------
  startTimer: ()->

    fnTick = ()=>this.tick()

    @interval = setInterval(fnTick, Hy.Config.PlayerNetwork.ActivityMonitor.kCheckInterval)

  # ----------------------------------------------------------------------------------------------------------------
  clearTimer: ()->

    if @interval?
      clearInterval(@interval) 
      @interval = null

    this

  # ----------------------------------------------------------------------------------------------------------------
  stop: ()->
    Hy.Trace.debug "ActivityMonitor::stop"
    this.clearTimer()
    @playerConnections = []

    this

  # ----------------------------------------------------------------------------------------------------------------
  pause: ()->
    Hy.Trace.debug "ActivityMonitor::pause"

    this.clearTimer()

  # ----------------------------------------------------------------------------------------------------------------
  resumed: ()->

    Hy.Trace.debug "ActivityMonitor::resumed"

    this.startTimer()

  # ----------------------------------------------------------------------------------------------------------------

  processReceivedMessage: (networkManager, messageInfo)->

#    Hy.Trace.debug "ActivityMonitor::processReceivedMessage (#{messageInfo.op})"

    if messageInfo.playerConnection?
      p = this.updatePlayerConnection(messageInfo.playerConnection)
    
      switch messageInfo.message.op
        when "ping"
          p.lastPing = messageInfo.message.data.pingCount

          service = messageInfo.playerConnection.getService()
          if service?
            service.sendSingle(messageInfo.playerConnection, "ack", {pingCount:messageInfo.message.data.pingCount}, false)
          messageInfo.handled = true

    messageInfo

  # ----------------------------------------------------------------------------------------------------------------
  addPlayerConnection: (pc)->

    if not this.updatePlayerConnection(pc)?
      @playerConnections.push {playerConnection: pc, pingTimestamp:ActivityMonitor.getTime(), lastPing:null}
      Hy.Trace.debug "ActivityMonitor::addPlayerConnection (size=#{_.size(@playerConnections)} Added:#{pc.dumpStr()})"

    pc

  # ----------------------------------------------------------------------------------------------------------------
  updatePlayerConnection: (pc)->

    p = _.detect(@playerConnections, (c)=>c.playerConnection is pc)

    if p?
      timeNow = ActivityMonitor.getTime()
      Hy.Trace.debug "ActivityMonitor::updatePlayerConnection (Updated #{pc.dumpStr()} last heard from=#{timeNow-p.pingTimestamp} lastPing=#{p.lastPing})"
      p.pingTimestamp = timeNow
      pc.reactivate()

    p

  # ----------------------------------------------------------------------------------------------------------------
  removePlayerConnection: (pc)->

    # Why the following, Michael??
    # @pingTimestamp = @pingTimestamp - 5*1000

    @playerConnections = _.reject(@playerConnections, (p)=>p.playerConnection is pc)

  # ----------------------------------------------------------------------------------------------------------------
  tick: ()->
    Hy.Trace.debug "ActivityMonitor::tick (#connections=#{_.size(@playerConnections)})"

    for pc in @playerConnections
      this.checkActivity(pc.playerConnection, pc.pingTimestamp, pc.lastPing)
    null

  # ----------------------------------------------------------------------------------------------------------------
  checkActivity: (pc, pingTimestamp, lastPing)->

    # this mechanism appears to be needed mostly for iPod 1Gs or perhaps anything else not running iOS 4+, and which 
    # don't send a "suspend" to the console when the button is pushed

    fnTestActive = (pc, timeNow, pingTimestamp)->
      ((timeNow - pingTimestamp) <= Hy.Config.PlayerNetwork.ActivityMonitor.kThresholdActive)

    fnTestAlive  = (pc, timeNow, pingTimestamp)->
      ((timeNow - pingTimestamp) <= Hy.Config.PlayerNetwork.ActivityMonitor.kThresholdAlive)

    timeNow = ActivityMonitor.getTime()

    debugString = "#{pc.dumpStr()} last heard from=#{timeNow-pingTimestamp} lastPing=#{lastPing}"

    if fnTestAlive(pc, timeNow, pingTimestamp)
      switch pc.getStatus()
        when PlayerConnection.kStatusActive
          if not fnTestActive(pc, timeNow, pingTimestamp)
            Hy.Trace.debug "PlayerConnection::checkActivity (Deactivating formerly active player #{debugString})"
            pc.deactivate()
        when PlayerConnection.kStatusInactive
          if fnTestActive(pc, timeNow, pingTimestamp)
            Hy.Trace.debug "PlayerConnection::checkActivity (Reactivating formerly inactive player #{debugString})"
            pc.reactivate()
        when PlayerConnection.Disconnected
          # We do nothing here. If the player manages to reconnect, the join code will handle that
          null
    else
      Hy.Trace.debug "ActivityMonitor::checkActivity (Removing #{debugString})"
      pc.remove("You appear to be inactive")

#    if !fnTestAlive(pc, timeNow, pingTimestamp)
#      Hy.Trace.debug "ActivityMonitor::checkActivity (Removing #{pc.dumpStr()} #{timeNow-pingTimestamp})"
#      pc.remove("You appear to be inactive")
#    else if pc.isActive() and !fnTestActive(pc, timeNow, pingTimestamp)
#      Hy.Trace.debug "PlayerConnection::checkActivity (Deactivating player #{pc.dumpStr()} #{timeNow-pingTimestamp})"
#      pc.deactivate()
#        else if !player.isActive() and fnTestActive(player)
#          this.playerReactivate player 

    this

# ==================================================================================================================
# Abstract superclass for all player network types
# Each instance of a subtype of this type is managed by PlayerNetwork
#
# PlayerNetworkService
#      HTTPPlayerService
#      BonjourService
#
class PlayerNetworkService

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (@networkManager)->

    username = Ti.Platform.username

    # to allow two simulators to run on the same network
    if username is "iPad Simulator"
      username = "#{username}-#{Hy.Utils.Math.random(10000)}"

    @tag = escape username

    this

  # ----------------------------------------------------------------------------------------------------------------
  start: ()->
    Hy.Trace.debug "PlayerNetworkService::start"
    this

  # ----------------------------------------------------------------------------------------------------------------
  stop: ()->
    Hy.Trace.debug "PlayerNetworkService::stop"
    this

  # ----------------------------------------------------------------------------------------------------------------
  pause: ()->
    Hy.Trace.debug "PlayerNetworkService::pause"
    this

  # ----------------------------------------------------------------------------------------------------------------
  resumed: ()->
    Hy.Trace.debug "PlayerNetworkService::resumed"
    this

  # ----------------------------------------------------------------------------------------------------------------
  getKind: ()-> null

  # ----------------------------------------------------------------------------------------------------------------
  setReady: ()->
    Hy.Trace.debug "PlayerNetworkService::setReady (service=#{this.getKind()})"

    @networkManager.setServiceReady(this)

  # ----------------------------------------------------------------------------------------------------------------
  getActivePlayers: ()->
    PlayerConnection.getActivePlayersByServiceKind(this.getKind())

  # ----------------------------------------------------------------------------------------------------------------
  sendSingle_: (connection, op, data, label, requireAck=true)->
    Hy.Trace.debug "PlayerNetworkService::sendSingle (#{this.constructor.name} op=#{op} label=#{label})"

  # ----------------------------------------------------------------------------------------------------------------
  sendSingle: (playerConnection, op, data, requireAck=true)->

    this.sendSingle_(playerConnection.getConnection(), op, data, playerConnection.getLabel(), requireAck)

  # ----------------------------------------------------------------------------------------------------------------
  sendAll: (op, data, requireAck=true)->
    Hy.Trace.debug "PlayerNetworkService::sendAll (#{this.constructor.name} op=#{op})"

  # ----------------------------------------------------------------------------------------------------------------
  doneWithPlayerConnection: (playerConnection)->

# ==================================================================================================================
class HTTPPlayerService extends PlayerNetworkService

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (networkManager)->

    super networkManager
 
    this

  # ----------------------------------------------------------------------------------------------------------------
  getKind: ()-> PlayerNetwork.kKindHTTP

  # ----------------------------------------------------------------------------------------------------------------
  getPort: ()->
    port = null
    if @httpServer?
      port = @httpServer.getPort()

    port

  # ----------------------------------------------------------------------------------------------------------------
  start: ()->

    Hy.Trace.debug "HTTPPlayerService::start"

    fnServerReady = (server)=>this.setReady()

    fnSocketOpened = (server, socketID)=> # Rely on clients to send 'join'
      Hy.Trace.debug "HTTPPlayerService::fnSocketOpened (socket=#{socketID})"
      null

    fnSocketClosed = (server, socketID)=>
      Hy.Trace.debug "HTTPPlayerService::fnSocketClosed (socket=#{socketID})"
      pc = PlayerConnection.findByConnection({kind:this.getKind(), socketID:socketID})
#      pc?.remove()
      pc?.deactivate(true) # if the user refreshes the browser window, the socket is closed. Let's try to preserve the user's app state across that refresh
      null

    fnMessageReceived = (server, socketID, messageText)=>this.messageReceived(socketID, messageText)

    fnServiceStatusChange = (status, domain, type_, name)=>this.serviceStatusChange(status, domain, type_, name)

    @httpServer = Hy.Network.HTTPServerProxy.create(fnServerReady, fnSocketOpened, fnSocketClosed, fnMessageReceived, fnServiceStatusChange, Hy.Config.PlayerNetwork.HTTPServerRunsInOwnThread)

    super

  # ----------------------------------------------------------------------------------------------------------------
  stop: ()->

    Hy.Trace.debug "HTTPPlayerService::stop"

    @httpServer?.stop() # ?? for some reason, this doesn't work (error in the trivnet module at runtime)

    @httpServer = null

    super

  # ----------------------------------------------------------------------------------------------------------------
  pause: ()->

    Hy.Trace.debug "HTTPPlayerService::pause"

    super

  # ----------------------------------------------------------------------------------------------------------------
  resumed: ()->

    Hy.Trace.debug "HTTPPlayerService::resumed (#active=#{_.size(this.getActivePlayers())})"

    # If we have resumed and the connections are still connected, then do nothing. Otherwise, restart
    if _.size(this.getActivePlayers()) is 0
      @httpServer?.restart() 

    this.setReady()

    super

  # ----------------------------------------------------------------------------------------------------------------
  messageReceived: (socketID, messageText)->

    try
      message = JSON.parse messageText
    catch e
      @networkManager.doError("Error parsing HTTP message /#{messageText}/")
      return null      

    @networkManager.messageReceived({kind:this.getKind(), socketID:socketID}, message)

    null

  # ----------------------------------------------------------------------------------------------------------------
  serviceStatusChange: (status, domain, type_, name)->

    Hy.Trace.debug "HTTPPlayerService::serviceStatusChange (#{status} #{domain} #{type_} #{name})"

    serviceStatus = {}

    switch status
      when "bonjourPublishSuccess", "bonjourPublishFailure"
        serviceStatus.bonjourPublish = {status: status, domain: domain, type_: type_, name: name}

    @networkManager.doServiceStatusChange(serviceStatus)

    this

  # ----------------------------------------------------------------------------------------------------------------
  getServiceStatus: ()-> @serviceStatus

  # ----------------------------------------------------------------------------------------------------------------
  sendSingle_: (connection, op, data, label, requireAck=true)->

    # requireAck is not implemented
    super

    try
      message = JSON.stringify src: @tag, op: op, data: data
      @httpServer.sendMessage(connection.socketID, message)
    catch e
      @networkManager.doError("Error encoding HTTP message (connection=#{connection.socketID} op=#{op} tag=#{@tag} data=#{@data})")

    this

  # ----------------------------------------------------------------------------------------------------------------
  sendAll: (op, data, requireAck=true)->

    super

    for p in this.getActivePlayers()
      this.sendSingle(p, op, data, requireAck)

    this

  # ----------------------------------------------------------------------------------------------------------------
  doneWithPlayerConnection: (playerConnection)->

    super

    # Should figure out a way to close the socket associated with this connection

# ==================================================================================================================
class BonjourService extends PlayerNetworkService

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (networkManager)->
    super networkManager

    Hy.Trace.debug "BonjourService::constructor"

    this

  # ----------------------------------------------------------------------------------------------------------------
  getKind: ()-> PlayerNetwork.kKindBonjour

  # ----------------------------------------------------------------------------------------------------------------
  startBonjourNetwork: ()->
    this.openSocket()
    this.publishService()

    this
  # ----------------------------------------------------------------------------------------------------------------
  stopBonjourNetwork: ()->

    if @localService?
      @localService.stop() 
      @localService = null

    if @socket? 
      if @socket.isValid
        @socket.close()
      @socket = null

    this

  # ----------------------------------------------------------------------------------------------------------------
  start: ()->
    Hy.Trace.debug "BonjourService::start"

    this.startBonjourNetwork()

    @messageQueue = MessageQueue.create(@networkManager, this)

    this.setReady()

    super

  # ----------------------------------------------------------------------------------------------------------------
  stop: ()->
    Hy.Trace.debug "BonjourService::stop"

    this.stopBonjourNetwork()

    @messageQueue.stop()

    super

  # ----------------------------------------------------------------------------------------------------------------
  pause: ()->
    Hy.Trace.debug "BonjourService::pause"
    this.stop()

    super

  # ----------------------------------------------------------------------------------------------------------------
  resumed: ()->
    Hy.Trace.debug "BonjourService::resumed"
    this.start()

    super

  # ----------------------------------------------------------------------------------------------------------------
  dumpSocket: ()->
    (Hy.Trace.debug "socket.#{prop} => #{val}") for prop, val of @socket
    Hy.Trace.debug "socket.isValid => #{@socket.isValid}"
    Hy.Trace.debug "socket.mode => #{@socket.mode}"
    Hy.Trace.debug "socket.port => #{@socket.port}"
    Hy.Trace.debug "socket.hostName => #{@socket.hostName}"

  # ----------------------------------------------------------------------------------------------------------------
  openSocket: ()->
    Hy.Trace.debug "BonjourService::openSocket"
    @socket = Ti.Network.createTCPSocket(hostName:Hy.Config.Bonjour.hostName, mode:Hy.Config.Bonjour.mode, port:Hy.Config.Bonjour.port)

    fnRead = (evt)=>
      this.messageReceived(evt)
      null

    @socket.addEventListener 'read', fnRead

#    @socket.stripTerminator = true

    fnReadError = (evt)=>
      @networkManager.doError("Bonjour READ ERROR (code=#{evt.code}/#{evt.error}/#{evt.type})")
      null

    @socket.addEventListener 'readError', fnReadError

    fnWriteError = (evt)=>
      @networkManager.doError("Bonjour WRITE ERROR (code=#{evt.code}/#{evt.error}/#{evt.type})")
      null

    @socket.addEventListener 'writeError', fnWriteError

    @socket.listen()

  # ----------------------------------------------------------------------------------------------------------------
  publishService: ()->
    Hy.Trace.debug "BonjourService::publishService"
    @localService = Ti.Network.createBonjourService name:@tag, type:Hy.Config.Bonjour.serviceType, domain:Hy.Config.Bonjour.domain
    try
      @localService.publish @socket
    catch error
      @networkManager.doError("Bonjour Open Error", true)

    this

  # ----------------------------------------------------------------------------------------------------------------
  parseForMultiple: (text)->

    level = 0
    results = []
    out = ""

    for c in text
      if c.charCodeAt(0) is 0
        null
      else
        switch c
          when '{'
            level++
          when '}'
            level--
        out += c
 
        if level is 0
          results.push out
          out = ""

    return results
      
  # ----------------------------------------------------------------------------------------------------------------
  messageReceived: (evt)->

    text = "UNKNOWN"    

    text = evt.data.text

#    Hy.Trace.debug "BonjourService::messageReceived (length=#{text.length} last=#{text.charCodeAt(text.length-1)})"

    # "suddenly", started seeing null bytes at the end of these strings, and multiple messages at the same time - 2011-08-12    
    if text.charCodeAt(text.length-1) isnt 125 # 125=}
      text = text.substring(0, text.length-1)

    results = this.parseForMultiple(text)

    for r in results
      try
        message = JSON.parse r
      catch e
        @networkManager.doError("Error parsing Bonjour message /#{text}/")
        return null      

      if (message.dest is 0) or (message.dest isnt @tag)
        null
      else
        Hy.Trace.debug "BonjourService::messageReceived (message=#{r})"
        @networkManager.messageReceived({kind:this.getKind(), tag:message.src}, message)

    null

  # ----------------------------------------------------------------------------------------------------------------
  sendSingle_: (connection, op, data, label, requireAck=true)->

    super

    message = new Message(@tag, op, data, requireAck, false)

    message.addDest(connection.tag, label)

    this.sendMessage message

  # ----------------------------------------------------------------------------------------------------------------
  sendAll: (op, data, requireAck=true)->

    super op, data

#    Hy.Trace.info "BonjourService::sendMultipleClients(op=#{op} data=#{JSON.stringify(data)})"

    players = this.getActivePlayers()

    if _.size(players) isnt 0
      message = new Message(@tag, op, data, requireAck, true)

      for player in players
        message.addDest(player.getConnection().tag, player.label)

      this.sendMessage(message)

    this

  # ----------------------------------------------------------------------------------------------------------------
  sendMessage: (message)->
#    Hy.Trace.info "BonjourService::sendMessage (#{message.dump()})"

    message.send(@socket)

    if message.requireAck
      @messageQueue.insert(message)

    this

# ==================================================================================================================
class Message

  messageCount = 0

  # ----------------------------------------------------------------------------------------------------------------  
  constructor: (@src, @op, @data, @requireAck, @isBroadcast)->
    messageCount++

    @id = messageCount
    @dests = []
    @createTime = (new Date()).getTime()
    @sendCount = 0
    @sentTime = null
    @broadcastPartiallyAckd = false # set true if we receive at least one response to a broadcast

    this

  # ----------------------------------------------------------------------------------------------------------------  
  addDest: (tag, label)->
    
    @dests.push {tag: tag, label: label, ack: false, ackCount: 0}

  # ----------------------------------------------------------------------------------------------------------------  
  getPacket: (tag)->

    try
      p = JSON.stringify m: @id, count: @sendCount, src: @src, dest: tag, op: @op, data: @data
    catch e
      Hy.Trace.info "Message::getPacket (ERROR could not encode packet data=#{@data})"
      p = ""

    p

  # ----------------------------------------------------------------------------------------------------------------  
  getPacket2: (isBroadcast=false)->

    tags = []

    if not isBroadcast
      for d in @dests
        tags.push d.tag

    try
      p = JSON.stringify m: @id, count: @sendCount, src: @src, dest: tags, op: @op, data: @data
#      Hy.Trace.info "Message::getPacket (packet=#{p})"
    catch e
      Hy.Trace.info "Message::getPacket (ERROR could not encode packet data=#{@data})"
      p = ""

    p

  # ----------------------------------------------------------------------------------------------------------------  
  send: (socket)->

#    Hy.Trace.info "Message:send (ENTER #{this.dump()})"

    @sentTime = (new Date().getTime())
    @sendCount++

    dest = null

    if 1 # Trying to reduce network traffic by making it possible for a message to target multiple clients
      if @isBroadcast and not @broadcastPartiallyAckd
        socket.write this.getPacket2(true)
        Hy.Trace.info "Message:send (Broadcast #{this.dump()})"
      else
        socket.write this.getPacket2()
        Hy.Trace.info "Message:send (Direct #{this.dump()})"
    else
      if @isBroadcast and not @broadcastPartiallyAckd
        socket.write this.getPacket(0)
        Hy.Trace.info "Message:send (Broadcast #{this.dump()})"
      else
        for dest in @dests
          Hy.Trace.info "Message:send (Direct to #{dest.label} #{this.dump()})"
          socket.write this.getPacket(dest.tag)

#    Hy.Trace.info "Message:send (EXIT #{this.dump()})"

  # ---------------------------------------------------------------------------------------------------------------- 
  hasDest: (tag)->
    for dest in @dests
      if dest.tag is tag
        return dest

    return null

  # ----------------------------------------------------------------------------------------------------------------  
  setAck: (tag, messageCount)->

    ackdBefore = false
    ackCount = 0

    if @isBroadcast 
      @broadcastPartiallyAckd = true

    dest = this.hasDest tag

    if dest?
      if dest.ack
        ackdBefore = true
      else
        @ack = (new Date()).getTime()
        dest.ack = true
        dest.ackCount = messageCount

      ackCount = dest.ackCount

#      Hy.Trace.info "Message:setAck (#{if ackdBefore then "NOT THE FIRST TIME" else ""} label=#{dest.label} message=#{@id} op=#{@op} createTime=#{this.dumpCreateTime()} sendCount=#{@sendCount} ackCount=#{dest.ackCount})"
    else
      Hy.Trace.info "Message:setAck (Unexpected Ack: tag=#{tag} message=#{@id})"

    ackCount

  # ----------------------------------------------------------------------------------------------------------------
  removeAckdDests: ()->
    if @dests.length>0

      newDests = _.reject @dests, (d)=>d.ack

      @dests = newDests

    return @dests.length > 0

  # ----------------------------------------------------------------------------------------------------------------
  removeDest: (tag)->
    if @dests.length>0

      newDests = _.reject @dests, (d)=>d.tag is tag

      @dests = newDests

    return @dests.length > 0

  # ----------------------------------------------------------------------------------------------------------------  
  removeDests: ()->
    @dests= {}
    this

  # ----------------------------------------------------------------------------------------------------------------  
  removeDestsInCommon: (message)->

#    Hy.Trace.info "Message:removeDestInCommon (ENTER)"

    if @dests.length is 0 or message.dests.length is 0
      return

    newDests = []

    for d in @dests
      if _.detect(message, (d1)=>d1.tag is d.tag)?
        Hy.Trace.info "Message:removeDestsInCommon (Message=#{message.id} in common with #{@id}: Removing #{d.label})"
      else
        newDests.push d

    @dests = newDests
        
    this

  # ----------------------------------------------------------------------------------------------------------------  
  hasOutstandingDests: ()->
    @dests.length > 0

  # ----------------------------------------------------------------------------------------------------------------  
  getNumDests: ()->
    @dests.length

  # ----------------------------------------------------------------------------------------------------------------  
  dumpCreateTime: ()->
    now = (new Date()).getTime()
    if @createTime? then ("#{now-this.createTime} milliseconds ago") else "(NO CREATE TIME)"

  # ----------------------------------------------------------------------------------------------------------------  
  dumpSentTime: ()->
    now = (new Date()).getTime()
    if @sentTime? then ("#{now-@sentTime} milliseconds ago") else "NOT SENT"

  # ----------------------------------------------------------------------------------------------------------------  
  dump: ()->
    output = "Message=#{@id} op=#{@op} Broadcast=#{@isBroadcast}/#{@broadcastPartiallyAckd} create=#{this.dumpCreateTime()} AckRequired=#{if @requireAck then 'Yes' else 'No'} sent=#{this.dumpSentTime()} sendCount=#{@sendCount} #dests=#{@dests.length} "

    count = 0
    for dest in @dests
      count++
      a = if dest.ack then "ACKd" else "NOT ACKd"
      output += "/##{count}: label=#{dest.label} ack=#{a} ackCount=#{dest.ackCount}/ "

    output


# ==================================================================================================================
class MessageQueue

  gInstance = null

  kMessageDeliveryThreshold = 1500
  kMaxSendAttempts = 5

  # ----------------------------------------------------------------------------------------------------------------  
  @create: (networkManager, networkService)->

    new MessageQueue(networkManager, networkService)

  # ----------------------------------------------------------------------------------------------------------------  
  @processReceivedMessage: (networkManager, messageInfo)->

#    Hy.Trace.debug "MessageQueue::processReceivedMessage (#{messageInfo.message.op})"

    switch messageInfo.message.op
      when "ack2"
        messageInfo.handled = true
        if messageInfo.playerConnection?
          if gInstance?
            gInstance.ackReceived(messageInfo.message.data.m, messageInfo.message.data.count, messageInfo.connection.tag)

    messageInfo

  # ----------------------------------------------------------------------------------------------------------------  
  constructor: (@networkManager, @networkService)->
#    Hy.Trace.info "MessageQueue::constructor"

    gInstance = this

    @messages = []

    @networkManager.addReceivedMessageProcessor(MessageQueue.processReceivedMessage)

    this.initStats()

    f = ()=>if @messages.length > 0 then this.check()

    @interval = null

    @interval = setInterval f, kMessageDeliveryThreshold

  # ----------------------------------------------------------------------------------------------------------------  
  stop: ()->
#    Hy.Trace.debug "MessageQueue::stop"

    clearInterval @interval if @interval?

    @interval = null
    @messages = []
    this.initStats()

  # ----------------------------------------------------------------------------------------------------------------  
  initStats: ()->
    # Note that we count each destination in a broadcast as a separate message

    @numberOfSentMessages = 0             # Total number of messages sent with "ack required" set
    @numberOfResentMessages = 0           # Total number of messages sent more than once
    @numberOfAckdMessages = 0             # Total number of messages ack'd

    @numberOfAckdOnFirstSendMessages = 0  # Total number of messages ack'd after first send
    @totalFirstSendAckdTime = 0           # For all messages ack'd after first send, sum of time between send and ack

    @numberOfAckdOnRetryMessages = 0      # Total number of messages ack'd after one or more retries
    @totalRetryTime = 0                   # For all messages sent more than once, sum of time between send and ack

    @numberOfFailedMessages = 0           # Total number of messages we've given up trying to resend

  # ----------------------------------------------------------------------------------------------------------------
  dumpStats: ()->
    stat = "Sent/Ackd/Resent/Failed=#{@numberOfSentMessages}/#{@numberOfAckdMessages}/#{@numberOfResentMessages}/#{@numberOfFailedMessages} "

    stat += "1st Send Ackd=#{@numberOfAckdOnFirstSendMessages} Ave=#{@totalFirstSendAckdTime/@numberOfAckdOnFirstSendMessages} secs "

    stat += "Ackd after Retry=#{@numberOfAckdOnRetryMessages} Ave=#{@totalRetryTime/@numberOfAckdOnRetryMessages} secs"

    stat

  # ----------------------------------------------------------------------------------------------------------------  
  dump: ()->
    for message in @messages
      Hy.Trace.info "MessageQueue::dump (#{message.dump()})"
    this
    
  # ----------------------------------------------------------------------------------------------------------------
  insert: (message)->
#    Hy.Trace.info "MessageQueue::insert"

    # Broadcast messages trump all previous messages, except 'welcome'
    if message.isBroadcast and not message.broadcastPartiallyAckd
      m = _.select @messages, (m)=>m.op is 'welcome'

#      Hy.Trace.info "MessageQueue::insert (Broadcast inserted, was #{@messages.length} now #{m.length})"    

      @messages = m

    else
      for m in @messages
        m.removeDestsInCommon message

    @messages.push message

    @numberOfSentMessages += message.getNumDests()

#    Hy.Trace.info "MessageQueue::insert (EXIT)"

    this

  # ----------------------------------------------------------------------------------------------------------------
  ackReceived: (messageId, messageCount, tag)->

    for message in @messages
      if message.id is messageId
        ackCount = message.setAck(tag, messageCount)

        t = message.ack - message.createTime

        if ackCount is 1
          @numberOfAckdOnFirstSendMessages++
          @totalFirstSendAckdTime += t
        else
          @numberOfAckdOnRetryMessages++
          @totalRetryTime += t

        @numberOfAckdMessages++

        return

    this

  # ----------------------------------------------------------------------------------------------------------------
  check: ()->
#    Hy.Trace.debug "MessageQueue::check (ENTERING number of messages=#{@messages.length} #{this.dumpStats()})"

    timeNow = (new Date()).getTime()

    messagesToCheckLater = []
    messagesToResendNow = []

    for message in @messages

      # First, remove all clients that have ackd this message
      if message.removeAckdDests()

        # Then, remove all destinations representing clients that aren't active
        for p in @networkService.getActivePlayers()
          if !p.isActive()
            message.removeDest p.tag

        # If there are still outstanding destinations, then have we reached the resend limit?
        if message.hasOutstandingDests()
          if message.sendCount is kMaxSendAttempts
            Hy.Trace.debug "MessageQueue::check (Message - too many retries: #{message.dump()})"
            @numberOfFailedMessages += message.getNumDests()
          else
            # Decide whether to resend now or later
            t = message.sentTime
            if t?
              if (timeNow - t) > kMessageDeliveryThreshold
                messagesToResendNow.push message
              else
                messagesToCheckLater.push message
            else
                Hy.Trace.debug "MessageQueue::check (Message not sent! #{message.dump()})"
                messagesToCheckLater.push message

    @messages = []
    @messages = messagesToCheckLater

    for message in messagesToResendNow #should be safe to iterate while appending
      Hy.Trace.debug "MessageQueue::check (Resending message: #{message.dump()})"
      @numberOfResentMessages += message.getNumDests()
      @networkService.sendMessage message

#    Hy.Trace.debug "MessageQueue::check (EXITING number of messages=#{@messages.length})"

#    this.dump()

# ==================================================================================================================
# assign to global namespace:
if not Hy.Network?
  Hy.Network = {}

Hy.Network.PlayerNetwork = PlayerNetwork


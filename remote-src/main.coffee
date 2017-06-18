# ==================================================================================================================
# 
class Avatar

  kDefaultPose = "default-1"
  kCorrectPose = "correct-1"
  kIncorrectPose = "incorrect-1"
  kClickedPose = "twitch-1"

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (@elementHandler, @avatarName, @avatarSetName, @avatarWidth, @avatarHeight)->

    Hy.Web.Info.set("Welcome, " + @avatarName + "!")

    @currentPose = null
    @timeout = null

    this.showDefault()

    this

  # ----------------------------------------------------------------------------------------------------------------
  getName: ()-> @avatarName

  # ----------------------------------------------------------------------------------------------------------------
  getAvatarImageName: (poseName)->
    imageName = "http://??/trivially/assets/avatars/#{@avatarSetName}/#{@avatarName}/#{poseName}"
 
    if Hy.Web.Device.useHighResImages()
      imageName += "@2x"

    imageName += ".png" 

    imageName

  # ----------------------------------------------------------------------------------------------------------------
  setAvatarImage: (poseName)->
    if not @avatarImageElement?
      @avatarImageElement = Hy.Web.ElementHandler.getElement("avatar_image")

    if @timeout?
      clearTimeout @timeout
      @timeout = null
      
    @avatarImageElement.setSrc(this.getAvatarImageName(poseName))

    @currentPose = poseName

#    @avatarImageElement.setDimensions(@avatarWidth, @avatarHeight)

  # ----------------------------------------------------------------------------------------------------------------
  showDefault: ()->

    this.setAvatarImage(kDefaultPose)

  # ----------------------------------------------------------------------------------------------------------------
  showCorrectness: (correctness, score)->

    this.setAvatarImage(if correctness then kCorrectPose else kIncorrectPose)
    
    if not @playerScoreElement?
      @playerScoreElement = Hy.Web.ElementHandler.getElement("player_score")

    @playerScoreElement.set(if correctness then score else "")

    this

  # ----------------------------------------------------------------------------------------------------------------
  clearAvatar: (avatar)->

    @avatarImageElement.clear()
    @timeout = null
    @currentPose = null

    this

  # ----------------------------------------------------------------------------------------------------------------
  showClicked: ()->

    currentPose = @currentPose

    fn = ()=>
      if currentPose?
        this.setAvatarImage(currentPose)
        @timeout = null
      @avatarAnimationInProgress = null
      null

    if not @avatarAnimationInProgress?
      @avatarAnimationInProgress = true
      this.setAvatarImage(kClickedPose)
      @timeout = setTimeout(fn, 1000)

    this


# ==================================================================================================================
# 
class Pinger

  kPingInterval = 30 * 1000

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (@app, @connection)->

    fnPing = ()=>this.send()
    @pinger = window.setInterval(fnPing, kPingInterval)

    @counter = 0
  
    this

  # ----------------------------------------------------------------------------------------------------------------
  send: ()->

    Hy.Web.Debug.set("Sending Ping...")

    if @connection.isConnected()
      data = { "pingCount" : ++@counter }

      @app.sendRequest("ping", data)
      @timeSent = (new Date()).getTime()

    this

  # ----------------------------------------------------------------------------------------------------------------
  ackReceived: (message)->

    t = ((new Date()).getTime()) - @timeSent

    Hy.Web.Debug.set("ACK Received (#{t} ms)")

  # ----------------------------------------------------------------------------------------------------------------
  clear: ()->
    if @pinger?
      window.clearInterval(@pinger)
      @pinger = null
    this

# ==================================================================================================================
# 
class PerfTest

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (@app, @connection, @limit = 1000)->

    @totalTime = 0
    @receivedCount = 0

    @counter = 0

    Hy.Web.Debug.set("Started Perf Test...")

    this.send()
  
    this

  # ----------------------------------------------------------------------------------------------------------------
  send: ()->

    if @connection.isConnected()
      data = { "pingCount" : ++@counter }

      @app.sendRequest("ping", data)
      @timeSent = (new Date()).getTime()

    this

  # ----------------------------------------------------------------------------------------------------------------
  ackReceived: (message)->

    @receivedCount++

    t = ((new Date()).getTime()) - @timeSent

    @totalTime += t

    if @counter is @limit
      this.completed()
    else
      this.send()

    this
  # ----------------------------------------------------------------------------------------------------------------
  completed: ()->

    s = "Sent: #{@counter} Received: #{@receivedCount} Total Time: #{@totalTime} Ave Time: #{@totalTime/@receivedCount}"

    Hy.Web.Debug.set("Completed Perf Test: (#{s})")

  # ----------------------------------------------------------------------------------------------------------------
  clear: ()->
    if @pinger?
      window.clearInterval(@pinger)
      @pinger = null
    this

# ==================================================================================================================
# 
class RemoteApp

  transitions = {}

  elements = []

  gAssignedTag = null

  kMaxPlayerNameLength = 8

  # ----------------------------------------------------------------------------------------------------------------
  @getAssignedTag: ()-> gAssignedTag

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (@socketURL="%%WEBSOCKET_URL%%")->

    @connection = null

    @label = "WEB REMOTE"
    @src = "WEB-1"

    this.initSessionCookieFlag()

    @questionId = null
    
    @avatar = null
 
    @answerIndex = null
    @questionIdLastAnswered = null
    @myAnswerIndex = null

    @playerIndex = null
    @assignedTag = null

    @startEnabled = false
    @consoleSuspended = false
    @answeringAllowed = false

    @waitingForNewGameConfirmation = null

    @requestedPlayerName = null

    @elementHandler = new Hy.Web.ElementHandler(this, this.initElements())
    @transitionHandler = null

    this

  # ----------------------------------------------------------------------------------------------------------------
  isWelcomed: ()-> @playerIndex?

  # ----------------------------------------------------------------------------------------------------------------
  # by default, we set a session cookie to remember this user across browser instances
  #
  initSessionCookieFlag: ()->

    @sessionCookieFlag = switch Hy.Web.URL.getArg(["cookies", "c"], ["true", "false"])
      when "true"
        true
      when "false"
        false
      else
        true

    @sessionCookieFlag

  # ----------------------------------------------------------------------------------------------------------------
  useSessionCookie: ()-> @sessionCookieFlag

  # ----------------------------------------------------------------------------------------------------------------
  setPlayerName: (newName)->
    @_player_name.set(@playerName = newName)
    this

  # ----------------------------------------------------------------------------------------------------------------
  requestPlayerNameChange: (newName)->

    ok = true

    if newName? and (newName isnt "")
      @_player_name_hint.setStyleProperty("display", "none")
      @requestedPlayerName = newName
      this.sendRequest("playerNameChangeRequest", {name: newName})
    else
      ok = false

    ok

  # ----------------------------------------------------------------------------------------------------------------
  getPlayerName: ()-> @playerName

  # ----------------------------------------------------------------------------------------------------------------
  clearPlayerName: ()->

    @playerName = ""

    @playerNameElement?.set("")

    this

  # ----------------------------------------------------------------------------------------------------------------
  promptForPlayerName: ()->

    fn = (response)=>
      if (response is "ok")
        this.requestPlayerNameChange(@_alert.getValue())

      @_alert.hide()

      this

    if not @_alert.isAlertInProgress()
      if @playerName?
        @_alert.setValue("")

      t1 = "Please enter your name and tap \"ok\":"
      t2 = "(At most #{kMaxPlayerNameLength} characters, avoid \"<\")"
      @_alert.show(t1, t2, fn)
      Hy.Web.Info.clear()


    this

  # ----------------------------------------------------------------------------------------------------------------

  loaded: ()->

    @elementHandler.loaded()

    @transitionHandler = new Hy.Web.TransitionHandler(this, this.initTransitions(), @elementHandler)

    @orientationHandler = new Hy.Web.OrientationHandler(@elementHandler, "", @_stylesheet_link, @_page_wrapper)

    @transitionHandler?.doOpTransition("_INIT_", null)

    if this.initializeConnection()
      @connection.connect()

    this

  # ----------------------------------------------------------------------------------------------------------------
  updateOrientation: ()->

    @orientationHandler?.updateOrientation()

  # ----------------------------------------------------------------------------------------------------------------
  initializeConnection: ()->

    @connection = null

    if Hy.Web.Browser.isSupported()
      fnOpened = ()=>this.connectionOpened()
      fnMessageReceived = (data)=>this.connectionMessageReceived(data)
      fnClosed = ()=>this.connectionClosed()
      fnError = ()=>this.connectionError()
      @connection = Hy.Web.Connection.create(@socketURL, fnOpened, fnMessageReceived, fnClosed, fnError)
  
    if not @connection?
      @_info.setAttribute("connected", "false")
      Hy.Web.Debug.set("Your browser isn't supported")
      s = "Sorry, your browser isn't supported<br>"
      s += "Please use Safari (Mac, PC, iOS 4.3+)<br>"
      s += "Chrome (Mac, PC) or<br>Firefox (Mac, PC)"
      Hy.Web.Info.set(s)
      @transitionHandler?.doOpTransition("_NOT_SUPPORTED_")

    @connection

  # ----------------------------------------------------------------------------------------------------------------
  connectionClosed: ()=>
    Hy.Web.Debug.set("Connection Closed")

    this.connectionCleanup()

  # ----------------------------------------------------------------------------------------------------------------
  connectionError: ()=>
    Hy.Web.Debug.set("Connection Error")

    this.connectionCleanup()

  # ----------------------------------------------------------------------------------------------------------------
  connectionCleanup: ()->

    @_alert?.hide()

    @_info.setAttribute("connected", "false")

    @transitionHandler?.doOpTransition("_CN_CLOSED_", null)

    @pinger?.clear()
    @pinger = null

    this

  # ----------------------------------------------------------------------------------------------------------------
  connectionOpened: ()->

    Hy.Web.Debug.set("Connection opened")

    if not this.isWelcomed()
      this.sendJoin()

    @pinger = new Pinger(this, @connection)  # HACK
#    @pinger = new PerfTest(this, @connection) 

    @_info.setAttribute("connected", "true")

#    alert(Hy.Web.Device.isiPhoneWith4InchScreen())

    this

  # ----------------------------------------------------------------------------------------------------------------
  connectionMessageReceived: (data)->

    message = JSON.parse(data)        

    if @consoleSuspended
      @consoleSuspended = false

    Hy.Web.Debug.set("Op #{message.op} Received")

    this.do_op(message.op, message)

    this

  # ----------------------------------------------------------------------------------------------------------------
  do_op: (op, message)->

    # These are the messages that we'll process even if not in "isWelcomed" state
    preWelcomeOps = ["welcome", "joinDenied", "ejected", "op_suspend"]

    op_ = if this.isWelcomed()
      op
    else 
      if preWelcomeOps.indexOf(op) isnt -1
        op
      else
        null

    if op_?
      this.do_op_(op_, message)
    else 
      null

  # ----------------------------------------------------------------------------------------------------------------
  do_op_: (op, message)->

    # shouldn't need to do this, but just in case...
    if not message.data?
      message.data = {}

    transition = null
    chainedOps = []
    
    method = "op_#{op}"
    fn = this[method]
    if fn? and typeof(fn) is "function"
      if (r = this[method](message))?
        if r.info?
          Hy.Web.Info.set(r.info)
        if r.transition?
          transition = r.transition
        if r.chainedOps?
          chainedOps = r.chainedOps

    @transitionHandler?.doOpTransition((if transition? then transition else op), message)
 
    for chainedOp in chainedOps
#      alert "Chained Ops: #{chainedOp}"
      this.do_op(chainedOp.op, {data:chainedOp.data})      

    Hy.Web.Browser.hideLocationBar()

    this

  # ----------------------------------------------------------------------------------------------------------------
  op_ack: (message)->

    @pinger.ackReceived(message)

    null

  # ----------------------------------------------------------------------------------------------------------------
  setCookieForTag: ()->
 
    if @assignedTag? and this.useSessionCookie()
      Hy.Web.Cookie.set("assignedTag", @assignedTag)
      Hy.Web.Debug.set("Tag cookie set: " + @assignedTag)

    this

  # ----------------------------------------------------------------------------------------------------------------
  checkCookieForTag: ()->

    if not @assignedTag? and this.useSessionCookie()
      t = Hy.Web.Cookie.get("assignedTag")

      if t?
        Hy.Web.Debug.set("Tag cookie found: " + t)
        @assignedTag = t

    this

  # ----------------------------------------------------------------------------------------------------------------
  clearGameState: ()->

    @avatar.clearAvatar()
    this.clearPlayerName()

    this

  # ----------------------------------------------------------------------------------------------------------------
  resetAnswerButtons: ()->

  # ----------------------------------------------------------------------------------------------------------------
  op_revealAnswer: (message)->

    @answeringAllowed = false

    questionId = message.data.questionId
    indexCorrectAnswer = message.data.indexCorrectAnswer
    responses = message.data.responses

    correct = false
    responded = false
    score = null

    for r in message.data.responses
      if (r.player is @playerIndex) and (questionId is @questionIdLastAnswered)
        responded = true

        if indexCorrectAnswer is @myAnswerIndex
          correct = true;

        if r.score?
          incrementalScore = r.score

    @myAnswerIndex = null

    if correct
      @_score.increment(incrementalScore)

    if responded
      @avatar.showCorrectness(correct, incrementalScore)
      
    for i in [0..3]
      Hy.Web.AnswerButtonElement.setEmphasisByButtonCode(RemoteApp.getAnswerLetter(i), if i is indexCorrectAnswer then "correct" else "incorrect")

    m = if correct 
      "Yes! "
    else
      if responded
        "Nope! "
      else
        ""
    m = m + "Correct answer is: " + RemoteApp.getAnswerLetter(indexCorrectAnswer)

    {info:m, transition:"revealAnswer"}

  # ----------------------------------------------------------------------------------------------------------------
  op_ejected: (message)->

    Hy.Web.Debug.set("Ejected. Reason: #{message.data.reason}")

    this.connectionCleanup()

    null

  # ----------------------------------------------------------------------------------------------------------------
  op_joinDenied: (message)->

    Hy.Web.Debug.set("Join Denied. Reason: #{message.data.reason}")

    this.connectionCleanup()

    null

  # ----------------------------------------------------------------------------------------------------------------
  op_startContest: (message)->

    @_score.set(0)

    Hy.Web.AnswerButtonElement.setAllEmphasis("inactive")

    null

 
  # ----------------------------------------------------------------------------------------------------------------
  op_suspend: (message)->
    @consoleSuspended = true

    null

  # ----------------------------------------------------------------------------------------------------------------
  op_welcome: (message)->

#    Hy.Web.Hy.Web.Device.dump()

    @playerIndex = message.data.index # Once this is set, state is now "isWelcomed"

    @questionId = message.data.questionId
    @answerIndex =  message.data.answerIndex

    gAssignedTag = @assignedTag = message.data.assignedTag
    Hy.Web.Debug.setTag(@assignedTag)

    @consoleName = unescape(message.src)

    @_score.set(message.data.score)
    @addressEncodingInfo = message.data.addressEncoding

    this.setPlayerName(message.data.playerName)

    @avatar = new Avatar(@elementHandler, message.data.avatar.name, message.data.avatar.avatarSet, message.data.avatar.avatarWidth, message.data.avatar.avatarHeight)

    @src = "WEB-" + @playerIndex + "-" + this.getPlayerName()

    this.setCookieForTag()

    Hy.Web.Debug.set("assigned tag=" + @assignedTag)

    page = message.data.page

    {info:null, transition:"welcome", chainedOps:[page]}

  # ----------------------------------------------------------------------------------------------------------------
  op_showQuestion: (message)->

    @questionId = message.data.questionId
    @answeringAllowed = true

    @avatar.showDefault()

    Hy.Web.AnswerButtonElement.setAllEmphasis()

    {info:null, transition:"showQuestion"}

  # ----------------------------------------------------------------------------------------------------------------
  op_contestCompleted: (message)->

    Hy.Web.AnswerButtonElement.setAllEmphasis()

    @avatar.showDefault()

    info = "Game Over!"

    if message.data? and (leaderboard = message.data.leaderboard)?
      if (leaderboardComment = this.getLeaderboardComment(leaderboard))?
        info += "<br>#{leaderboardComment}"

    {info:info, transition:"contestCompleted"}

  # ----------------------------------------------------------------------------------------------------------------
  getLeaderboardComment: (leaderboard)->

    comment = null

    numPlayers = 0
    for o in leaderboard
      numPlayers += o.group.length

    if numPlayers is 1
      return null

    rank = 0
    numRankings = leaderboard.length
    for o in leaderboard
      rank++
      if o.group.indexOf(@playerIndex) isnt -1 
        if o.score isnt "0"
          comment = "You #{if o.group.length is 1 then "finished in" else "shared"}"
          if (numRankings > 1) and (rank is numRankings)
            comment += " last"
          else
            comment += " #{rank}<sup>#{this.getNumberThingie(rank)}</sup>"

          comment += " place"

          if (numOtherPlayers = (o.group.length-1)) > 0
            comment += "<br> with #{numOtherPlayers} other player#{if numOtherPlayers > 1 then "s" else ""},"
          comment += "<br>out of a total of #{numPlayers} players"

          return comment

    null

  # ----------------------------------------------------------------------------------------------------------------
  getNumberThingie: (rank)->
    switch rank
      when 1
        "st"
      when 2
        "nd"
      when 3
        "rd"
      else
        "th"

  # ----------------------------------------------------------------------------------------------------------------
  op_prepForContest: (message)->

    Hy.Web.AnswerButtonElement.setAllEmphasis()

    @answeringAllowed = false
    @myAnswerIndex = null

    @avatar.showDefault()

    @startEnabled = if message.data.startEnabled? then message.data.startEnabled else false
    reason = message.data.reason
    standard = "Tap \"Start Game\" to Play!"

    info = if @startEnabled
      if reason?
        "#{standard}<br><br>#{reason}"
      else
        standard
    else
      if reason?
        reason
      else
        standard
      
    @_start_game_button.setAttribute("enabled", if @startEnabled then "true" else "false")

    {info:info, transition:"prepForContest"}

  # ----------------------------------------------------------------------------------------------------------------
  op_playerNameChangeRequestResponse: (message)->

    if message.data.errorMessage?
      Hy.Web.Info.set(message.data.errorMessage)
    else
      this.setPlayerName(@playerName = message.data.givenName)
      Hy.Web.Info.set("You are now \"#{@playerName}\"")

    @requestedPlayerName = null

    null

  # ----------------------------------------------------------------------------------------------------------------
  sendRequest: (op, data)->

    request = { 
      "src"  : @src,
      "op"   : op
      }

    if @assignedTag?
      request.tag = @assignedTag

    if data?
      request.data = data

    requestText = JSON.stringify(request)

    @connection?.sendMessage(requestText)

  # ----------------------------------------------------------------------------------------------------------------
  @getAnswerLetter: (index)->

    ["A","B","C","D"][index]

  # ----------------------------------------------------------------------------------------------------------------
  sendAnswer: (answer)->

    if @consoleSuspended
      Hy.Web.Info.set("Sorry - Game is suspended!")
    else
      if @answeringAllowed
        if @myAnswerIndex?
          Hy.Web.Info.set("Sorry - You already answered #{RemoteApp.getAnswerLetter(@myAnswerIndex)}!")
        else
          @myAnswerIndex = answer
          @questionIdLastAnswered = @questionId
  
          answerLetter = RemoteApp.getAnswerLetter(answer)
          Hy.Web.AnswerButtonElement.setEmphasisByButtonCode(answerLetter, "answered")
          Hy.Web.Info.set("You guessed #{answerLetter}...")

          data = {
              "questionId" : @questionId,
              "answerIndex": answer
            }

          this.sendRequest("answer", data)
      else
        Hy.Web.Info.set("Sorry - Please wait for a question!")

    this

  # ----------------------------------------------------------------------------------------------------------------
  sendJoin: ()->
    if @connection?
      if not @connection.isConnected()
        Hy.Web.Info.set("Attempting to connect...")
        @connection.connect()
      else
        data = { 
          "label"        : @label,
          "majorVersion" : 2,
          "minorVersion" : 0 }

        this.checkCookieForTag()

        this.sendRequest("join", data)

    this

  # ----------------------------------------------------------------------------------------------------------------
  sendJoinRequested2: ()->

    window.location.reload()

  # ----------------------------------------------------------------------------------------------------------------
  sendJoinRequested: ()->

    fnResponse = (success, code, responseText)=>
      if success
        window.location.reload()
      else
#        alert "Failed to connect with Console (code=#{if code? then code else "?"})"
        @transitionHandler?.doOpTransition("_CN_CLOSED_", null)

    # Is the console there?
    xmlHttpRequest = new Hy.Web.HTTPRequest().do("test.txt", fnResponse)

    @transitionHandler?.doOpTransition("_CN_TRYING_TO_CONNECT_", null)

    this

  # ----------------------------------------------------------------------------------------------------------------
  sendPauseRequested: ()->
    if @connection? and @connection.isConnected()
      this.sendRequest("pauseRequested", {})

    this

  # ----------------------------------------------------------------------------------------------------------------
  sendContinueRequested: ()->
    if @connection? and @connection.isConnected()
      this.sendRequest("continueRequested", {})

    this

  # ----------------------------------------------------------------------------------------------------------------
  sendNewGameRequested: (confirm = false)->

    if @connection? and @connection.isConnected()

      if confirm
        if @waitingForNewGameConfirmation?
          this.clearNewGameRequestedConfirmation()
          this.sendRequest("newGameRequested", {})
        else
          counter = Hy.Web.Info.setSecondary("Tap \"New Game\" again<br>to confirm...")
          @waitingForNewGameConfirmation = setTimeout((()=>this.clearNewGameRequestedConfirmation(counter)), 10 * 1000)

      else
        this.sendRequest("newGameRequested", {})

    this

  # ----------------------------------------------------------------------------------------------------------------
  clearNewGameRequestedConfirmation: (counter)->
     if @waitingForNewGameConfirmation?

       clearTimeout(@waitingForNewGameConfirmation)
       @waitingForNewGameConfirmation = null

       if counter is Hy.Web.Info.getSecondaryCounter()
         Hy.Web.Info.setSecondary()

     this

  # ----------------------------------------------------------------------------------------------------------------
  avatarClicked: ()->
    
    @avatar?.showClicked()

    this.promptForPlayerName()

    this

  # ----------------------------------------------------------------------------------------------------------------
  getAddressEncodingInfo: ()-> 

    if @addressEncodingInfo?
      "<i>More players?</i><br>Each player should visit<br>JoinCG.com<br>and enter code: <span style=\"color:red;\">#{@addressEncodingInfo}</span>"
    else
      ""
  # ----------------------------------------------------------------------------------------------------------------
  alertHandler: (response)->

    @_alert?.handler(response)

    Hy.Web.Browser.hideLocationBar()

    this

  # ----------------------------------------------------------------------------------------------------------------
  test: ()->

#     test_1();
#     @orientationHandler.swapOrientation()

#    @creator = new Creator(this)

    this

  # ----------------------------------------------------------------------------------------------------------------
  test_1: ()->

    fnResponse = (success, code, responseText)=>
      if success
        alert responseText
      else
        alert "Failed code=#{if code? then code else "?"}"

    @connection?.xmlHttpRequest("test.txt", fnResponse)

    null

  # ----------------------------------------------------------------------------------------------------------------
  initElements: ()->
    elements = [
      {ID: "debug",                       klass: Hy.Web.Debug,               ctor: null, controls: ["format"]},
      {ID: "copyright",                   klass: Hy.Web.Copyright,           ctor: null, controls: ["op", "format"]},
      {ID: "test",                        klass: Hy.Web.Element,             ctor: null, controls: ["format"]},
      {ID: "player_name_hint",            klass: Hy.Web.TextElement,         ctor: null, controls: ["format"]},
      {ID: "player_score",                klass: Hy.Web.TextElement,         ctor: null, controls: ["op", "format"]},
      {ID: "player_name",                 klass: Hy.Web.TextElement,         ctor: null, controls: ["format"]},
      {ID: "avatar_image",                klass: Hy.Web.ImageElement,        ctor: null, controls: ["format"]},
      {ID: "avatar_container",            klass: Hy.Web.ImageElement,        ctor: null, controls: ["op", "format"]},
      {ID: "score",                       klass: Hy.Web.NumberElement,       ctor: null, controls: ["format"]},
      {ID: "score_container",             klass: Hy.Web.Element,             ctor: null, controls: ["format", "density"]},
      {ID: "score_label",                 klass: Hy.Web.Element,             ctor: null, controls: ["density"]},
      {ID: "score_wrapper",               klass: Hy.Web.Element,             ctor: null, controls: ["op", "format"]},
      {ID: "info2",                       klass: Hy.Web.TextElement,         ctor: null, controls: ["op", "format"]},
      {ID: "info",                        klass: Hy.Web.Info,                ctor: null, controls: ["op", "format"]},
      {ID: "info3",                       klass: Hy.Web.Info3,               ctor: null, controls: ["op", "format"]},
#      {ID: "spinner",                     klass: Hy.Web.Element,             ctor: null, controls: ["op", "format", "density"]},
      {ID: "join_button",                 klass: Hy.Web.Element,             ctor: null, controls: ["op", "format"]},
      {ID: "join_button_image",           klass: Hy.Web.Element,             ctor: null, controls: ["op", "density"]},
      {ID: "join_button_label",           klass: Hy.Web.Element,             ctor: null, controls: ["op", "density"]},
      {ID: "pause_button",                klass: Hy.Web.Element,             ctor: null, controls: ["op", "format"]},
      {ID: "pause_label",                 klass: Hy.Web.Element,             ctor: null, controls: ["density"]},
      {ID: "pause_button_image",          klass: Hy.Web.Element,             ctor: null, controls: ["density"]},
      {ID: "continue_button",             klass: Hy.Web.Element,             ctor: null, controls: ["op", "format"]},
      {ID: "continue_label",              klass: Hy.Web.Element,             ctor: null, controls: ["density"]},
      {ID: "continue_button_image",       klass: Hy.Web.Element,             ctor: null, controls: ["density"]},

      {ID: "start_game_button",           klass: Hy.Web.Element,             ctor: null, controls: ["op", "format"]},
      {ID: "start_game_label",            klass: Hy.Web.Element,             ctor: null, controls: ["density"]},
      {ID: "start_game_button_image",     klass: Hy.Web.Element,             ctor: null, controls: ["density"]},
      {ID: "new_game_button",             klass: Hy.Web.Element,             ctor: null, controls: ["op", "format"]},
      {ID: "new_game_label",              klass: Hy.Web.Element,             ctor: null, controls: ["density"]},
      {ID: "new_game_button_image",       klass: Hy.Web.Element,             ctor: null, controls: ["density"]},

      {ID: "new_game_button2",            klass: Hy.Web.Element,             ctor: null, controls: ["op", "format"]},
      {ID: "new_game_label2",             klass: Hy.Web.Element,             ctor: null, controls: ["density"]},
      {ID: "new_game_button_image2",      klass: Hy.Web.Element,             ctor: null, controls: ["density"]},

      {ID: "button_A",                    klass: Hy.Web.AnswerButtonElement, ctor: null, controls: ["format", "density"]},
      {ID: "button_B",                    klass: Hy.Web.AnswerButtonElement, ctor: null, controls: ["format", "density"]},
      {ID: "button_C",                    klass: Hy.Web.AnswerButtonElement, ctor: null, controls: ["format", "density"]},
      {ID: "button_D",                    klass: Hy.Web.AnswerButtonElement, ctor: null, controls: ["format", "density"]},
      {ID: "stage_answers",               klass: Hy.Web.Element,             ctor: null, controls: ["op", "format", "density"]},
      {ID: "stage_empty",                 klass: Hy.Web.Element,             ctor: null, controls: ["op", "format", "density"]},
      {ID: "test",                        klass: Hy.Web.Element,             ctor: null, controls: ["op", "format"]},
      {ID: "stylesheet_link",             klass: Hy.Web.Element,             ctor: null},
      {ID: "page_wrapper",                klass: Hy.Web.Element,             ctor: null, controls: ["op", "format"]},
      {ID: "logo",                        klass: Hy.Web.Element,             ctor: null, controls: ["op", "format", "density"]},


      {ID: "alert_text_area",             klass: Hy.Web.TextElement,         ctor: null, controls: ["format"]},
      {ID: "alert_text_1",                klass: Hy.Web.TextElement,         ctor: null, controls: ["format"]},
      {ID: "alert_text_2",                klass: Hy.Web.TextElement,         ctor: null, controls: ["format"]},
      {ID: "alert_input",                 klass: Hy.Web.InputTextElement,    ctor: null, controls: ["format"]},
      {ID: "alert_ok_button",             klass: Hy.Web.Element,             ctor: null, controls: ["format"]},
      {ID: "alert_ok_button_image",       klass: Hy.Web.Element,             ctor: null, controls: ["density", "format"]},
      {ID: "alert_ok_button_label",       klass: Hy.Web.Element,             ctor: null, controls: ["density"]},

      {ID: "alert_cancel_button",         klass: Hy.Web.Element,             ctor: null, controls: ["format"]},
      {ID: "alert_cancel_button_image",   klass: Hy.Web.Element,             ctor: null, controls: ["density", "format"]},
      {ID: "alert_cancel_button_label",   klass: Hy.Web.Element,             ctor: null, controls: ["density"]},

      {ID: "alert_background",            klass: Hy.Web.Element,             ctor: null, controls: ["format", "density"]}
      {ID: "alert",                       klass: Hy.Web.AlertElement,        ctor: null, controls: ["format"]}
    ]

  # ----------------------------------------------------------------------------------------------------------------
  initTransitions: ()->
    transitions["_INIT_"] =
      userInfo: (app, m)->"Welcome!"
  
    transitions["_NOT_SUPPORTED_"] = 
      userInfo: null
  
    transitions["_CN_CLOSED_"] = 
      userInfo: (app, m)->
        Hy.Web.Info3.set("<a href=\"http://joincg.com\">Or tap <b>here</b> to enter<br>a different join code</a>")
        "Sorry, connection lost!<br>Tap <b>here</b> to try to reconnect..."
  
    transitions["_CN_TRYING_TO_CONNECT_"] = 
      userInfo: (app, m)->
        "Trying to connect to Trivially..."
  
    transitions["ejected"] =  
      userInfo: (app, m)->"Sorry, connection lost!<br>Reason: #{m.data.reason}<br>Tap \"Join\" to try to connect again..."
  
    transitions["joinDenied"] =  
      userInfo: (app, m)->"Sorry, could not join the Game!<br>#{m.data.reason}<br><br>Tap \"Join\" to try to connect again..."
   
    transitions["welcome"] =     
      userInfo: (app, m)->"Welcome, from #{unescape(m.src).substr(0,14)}!"
  
    transitions["gamePaused"] =  
      userInfo: (app, m)->"Game Paused!"
  
    transitions["aboutPage"] =  
      userInfo: (app, m)->"See iPad for instructions...<br><br>#{app.getAddressEncodingInfo()}"
  
    transitions["suspend"] =     
      userInfo: (app, m)->"Trivially Suspended!"
  
    transitions["introPage"] =
      userInfo: (app, m)->"Tap iPad to Start Game...<br><br>#{app.getAddressEncodingInfo()}"
  
    transitions["prepForContest"] =
      userInfo: null
  
    transitions["startContest"] =
      userInfo: (app, m)->"Game is starting"
  
    transitions["showQuestion"] =
      userInfo: (app, m)->"Question challenge in progress"
  
    transitions["waitingForQuestion"] =
      userInfo: (app, m)->"Waiting for a Question"
  
    transitions["revealAnswer"] =
      userInfo: null
  
    transitions["contestCompleted"] =
      userInfo: null

    transitions["alert"] =
      userInfo: (app, m)->""

    transitions


# ==================================================================================================================

if window.Hyperbotic?
  null
else
  window.Hyperbotic = {}

Hy = Hyperbotic = window.Hyperbotic

window.remoteApp = new RemoteApp()


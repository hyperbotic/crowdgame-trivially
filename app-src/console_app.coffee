# ==================================================================================================================
#
# IT IS REALLY IMPORTANT THAT App-level event handlers return null.
#   Ti.App.addEventListener("eventName", (event)=>null)
# 
#
class ConsoleApp extends Hy.UI.Application

  gInstance = null

  # ----------------------------------------------------------------------------------------------------------------
  @get: ()-> gInstance

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (backgroundWindow, tempImage)->

    gInstance = this

    @singleUser = false

    super backgroundWindow, tempImage

    this.initSetup()

    Hy.Pages.StartPage.addObserver this

    Hy.Trace.debug "ConsoleApp::constructor (Clipboard=#{Ti.UI.Clipboard.getText()})" #2.6.2

    this

  # ----------------------------------------------------------------------------------------------------------------
  initSetup: ()->
    @initFnChain = [
      {label: "Trace",                    init: ()=>Hy.Trace.init(this)}
      {label: "Analytics",                init: ()=>@analytics = Hy.Analytics.Analytics.init()}
#      {label: "CommerceManager",          init: ()=>Hy.Commerce.CommerceManager.init()} # As of 2.7
      {label: "Page/Video",               init: ()=>@pageState = Hy.Pages.PageState.init(this)}
      {label: "Splash Page",              init: ()=>this.showSplashPage()}
      {label: "SoundManager",             init: ()=>Hy.Media.SoundManager.init()}
      {label: "Network Service",          init: ()=>this.initNetwork()}
      {label: "Player Network",           init: ()=>this.initPlayerNetwork()}
      {label: "Update Service",           init: ()=>Hy.Update.UpdateService.init()}
      {label: "ContentManager",           init: ()=>Hy.Content.ContentManager.init(this.checkURLArg())}
      {label: "AvatarSet",                init: ()=>Hy.Avatars.AvatarSet.init()}
      {label: "Console Player",           init: ()=>Hy.Player.ConsolePlayer.init()}
#      {label: "CommerceManagerInventory", init: ()=>Hy.Commerce.CommerceManager.inventoryManagedFeatures()} # As of 2.7
    ]

    this 

  # ----------------------------------------------------------------------------------------------------------------
  init: ()->
    super

    Hy.Utils.MemInfo.init()
    Hy.Utils.MemInfo.log "INITIALIZING (init #=#{_.size(@initFnChain)})"

    @timedOperation = new Hy.Utils.TimedOperation("INITIALIZATION")

    fnExecute = ()=>
      while _.size(@initFnChain) > 0
        fnSpec = _.first(@initFnChain)
        fnSpec.init()
        @initFnChain.shift()
        @timedOperation.mark(fnSpec.label)
      null

    fnExecute()
    
    this

  # ----------------------------------------------------------------------------------------------------------------
  start: ()->
    Hy.Trace.debug "ConsoleApp::start"

    super

    @analytics?.logApplicationLaunch()

    this

  # ----------------------------------------------------------------------------------------------------------------
  # Triggered when the app is backgrounded. Have to work quick here. Do the important stuff first
  pause: (evt)->
    Hy.Trace.debug "ConsoleApp::pause (ENTER)"

    this.getPage()?.pause()
    @playerNetwork?.sendAll('suspend', {})
    @playerNetwork?.pause() 
    @httpPort = null
    Hy.Network.NetworkService.get().pause()

    super evt

    Hy.Trace.debug "ConsoleApp::pause (EXIT)"

  # ----------------------------------------------------------------------------------------------------------------
  # Triggered at the start of the process of being foregrounded. Nothing to do here.
  resume: (evt)->
    Hy.Trace.debug "ConsoleApp::resume (ENTER page=#{this.getPage()?.constructor.name})"

    super evt

    Hy.Trace.debug "ConsoleApp::resume (EXIT page=#{this.getPage()?.constructor.name})"

  # ----------------------------------------------------------------------------------------------------------------
  # Triggered when app is fully foregrounded.
  resumed: (evt)->

    Hy.Trace.debug "ConsoleApp::resumed (ENTER page=#{this.getPage()?.constructor.name})"

    super

    this.init()

    Hy.Network.NetworkService.get().resumed()
    Hy.Network.NetworkService.get().setImmediate()

    @playerNetwork?.resumed()

    if false #(newUrl = this.checkURLArg())?
      null # do something
    else
      this.resumedPage()

    Hy.Trace.debug "ConsoleApp::resumed (EXIT page=#{this.getPage()?.constructor.name})"

  # ----------------------------------------------------------------------------------------------------------------
  #
  # To handle the edge case where we were backgrounded while transitioning to a new page.
  # In the more complex cases, the tactic for handling this is to simply go back to the previous page.
  # This approach seems to be needed when the page is based on a web view and requires images to load
  #
  resumedPage: ()->

    Hy.Trace.debug "ConsoleApp::resumedPage (ENTER (transitioning=#{@pageState.isTransitioning()?})"

    fn = ()=>@pageState.resumed()

    if @pageState.isTransitioning()?
      stopTransitioning = true
      switch (oldPageState = @pageState.getOldPageState())
        when Hy.Pages.PageState.Intro, Hy.Pages.PageState.Start, null, Hy.Pages.PageState.Splash
          fn = ()=>this.showStartPage()
        when Hy.Pages.PageState.Any, Hy.Pages.PageState.Unknown
          new Hy.Utils.ErrorMessage("fatal", "Console App", "Unexpected state \"#{oldPageState}\" in resumedPage") #will display popup dialog
          fn = ()=>this.showStartPage()
        else # About, UCCInfo, Join, Answer, Scoreboard, Completed
          stopTransitioning = false
          null

      if stopTransitioning
        @pageState.stopTransitioning()
 
    else
      if not this.getPage()?
        fn = ()=>this.showStartPage()

    Hy.Trace.debug "ConsoleApp::resumedPage (EXIT: \"#{fn}\")"

    fn?()

    this

  # ----------------------------------------------------------------------------------------------------------------
  checkURLArg: ()->

    args = Ti.App.getArguments()
    hasChanged = false

    if (url = args.url)?
      hasChanged = @argURL? and (@argURL != url)

    # HACK
    url = "https://spreadsheets.google.com/feeds/download/spreadsheets/Export?key=0AvVyfy1LBTe3dEVHWk9GbTdWSWkyZFBJRldaMDJQVmc&exportFormat=csv" #HACK
    hasChanged = true

    @argURL = url

    if hasChanged then @argURL else null
    	 
  # ----------------------------------------------------------------------------------------------------------------
  showPage: (newPageState, fn_newPageInit, postFunctions = [])->

    Hy.Trace.debug "ConsoleApp::showPage (ENTER #{newPageState} #{@pageState?.display()})"

    fn_showPage = ()=>
      Hy.Trace.debug "ConsoleApp::showPage (FIRING #{newPageState} #{@pageState.display()})"
      @pageState?.showPage(newPageState, fn_newPageInit, postFunctions)

    f = ()=> Hy.Utils.Deferral.create(0, ()=>fn_showPage())

    if (newPageState1 = @pageState.isTransitioning())?
      if newPageState1 isnt newPageState
        @pageState.addPostTransitionAction(f)
    else
      f()

    Hy.Trace.debug "ConsoleApp::showPage (EXIT #{newPageState} #{@pageState.display()})"

    this

  # ----------------------------------------------------------------------------------------------------------------
  showSplashPage: ()->

    if not @splashShown?
      this.showPage(Hy.Pages.PageState.Splash, (page)=>page.initialize())
      @splashShown = true
    null

  # ----------------------------------------------------------------------------------------------------------------
  initNetwork: ()->

    Hy.Network.NetworkService.init().setImmediate()
    Hy.Network.NetworkService.addObserver this

  # ----------------------------------------------------------------------------------------------------------------
  # Called by NetworkService when there's a change in the network scenery (since ConsoleApp is an "observer")
  #
  obs_networkChanged: (reason)->

    super

    if not @pageState.isTransitioning()?
      this.getPage()?.obs_networkChanged(reason)

    this

  # ----------------------------------------------------------------------------------------------------------------
  initPlayerNetwork: ()->

    if @playerNetwork?
      return

    Hy.Trace.debugM "ConsoleApp::initPlayerNetwork (ENTER)"

    fnReady = (httpPort)=>
      Hy.Trace.debug "ConsoleApp::Network Ready (port=#{httpPort})"
      Hy.Trace.debug "ConsoleApp::Network Ready (Clipboard=#{Ti.UI.Clipboard.getText()})" #2.6.2

      @timedOperation.mark("Network Ready")
      @httpPort = httpPort

      if this.getPage()?
        if this.getPage().getState() is Hy.Pages.PageState.Splash
          this.showIntroPage()
        else
          this.getPage().resumed()
          remotePage = this.remotePlayerMapPage()
          @playerNetwork?.sendAll(remotePage.op, remotePage.data)
      else
        if (newPageState = @pageState.isTransitioning())?
          if newPageState is Hy.Pages.PageState.Splash
            this.showIntroPage()

      Hy.Network.NetworkService.setConsoleHTTPPort(@httpPort) # will trigger a "obs_networkChanged" event

      null

    fnError = (error, restartNetwork)=>
      Hy.Trace.debug "ConsoleApp (NETWORK ERROR /#{error}/)"

      if restartNetwork
        Hy.Trace.debug "ConsoleApp (NETWORK ERROR - RESTARTING)"
        new Hy.Utils.ErrorMessage("fatal", "Player Network", error) #will display popup dialog
#        this.restartPlayerNetwork()
      null

    fnMessageReceived    = (connection, op, data)=>this.remotePlayerMessage(connection, op, data)
    fnAddPlayer          = (connection, label, majorVersion, minorVersion)=>this.remotePlayerAdded(connection, label, majorVersion, minorVersion)
    fnRemovePlayer       = (connection)=>this.remotePlayerRemoved(connection)
    fnPlayerStatusChange = (connection, status)=>this.remotePlayerStatusChanged(connection, status)
    fnServiceStatusChange = (serviceStatus)=>this.serviceStatusChange(serviceStatus)

    if @singleUser
      Hy.Trace.debugM "ConsoleApp::initPlayerNetwork (SINGLE USER)"
      fnReady(null)
    else
      @playerNetwork = Hy.Network.PlayerNetworkProxy.create(fnReady, fnError, fnMessageReceived, fnAddPlayer, fnRemovePlayer, fnPlayerStatusChange, fnServiceStatusChange)

    Hy.Trace.debugM "ConsoleApp::initPlayerNetwork (EXIT)"

  # ----------------------------------------------------------------------------------------------------------------
  restartPlayerNetwork: ()->

    Hy.Trace.debug "ConsoleApp::restartPlayerNetwork"

    this.stopPlayerNetwork()
    this.initPlayerNetwork()

  # ----------------------------------------------------------------------------------------------------------------
  stopPlayerNetwork: ()->

    @playerNetwork?.stop()
    @playerNetwork = null

  # ----------------------------------------------------------------------------------------------------------------
  serviceStatusChange: (serviceStatus)->

    Hy.Network.NetworkService.setBonjourPublishInfo(serviceStatus)
    
    this

  # ----------------------------------------------------------------------------------------------------------------
  showIntroPage: ()->
    Hy.Trace.debug "ConsoleApp::ShowIntroPage (ENTER)"

    fn = ()=>this.showStartPage()
    this.showPage(Hy.Pages.PageState.Intro, (page)=>page.initialize(fn))

    # It seems that we'll sometimes hang on startup if there's no wifi... something about the iOS "Turn on Wifi" dialog,
    # and the resulting suspend/resume, messes up the Intro page... doesn't show. This is a hack to get around that.
    fnIntroPageTimeout = ()=>
      Hy.Trace.debug "ConsoleApp::showIntroPage (IntroPageTimeout)"
      if this.getPage()? and this.getPage().getState() is Hy.Pages.PageState.Intro
        Hy.Trace.debug "ConsoleApp::showIntroPage (IntroPageTimeout - forcing transition to Start Page)"
        fn()

    if not Hy.Network.NetworkService.isOnlineWifi()
      Hy.Utils.Deferral.create(7 * 1000, fnIntroPageTimeout)

    Hy.Trace.debug "ConsoleApp::ShowIntroPage (EXIT)"
    this

  # ----------------------------------------------------------------------------------------------------------------
  showAboutPage: ()->
    @playerNetwork?.sendAll("aboutPage", {})
    this.showPage(Hy.Pages.PageState.About, (page)=>page.initialize())

  # ----------------------------------------------------------------------------------------------------------------
  showJoinCodeInfoPage: ()->
    @playerNetwork?.sendAll("aboutPage", {})
    this.showPage(Hy.Pages.PageState.JoinCodeInfo, (page)=>page.initialize())

  # ----------------------------------------------------------------------------------------------------------------
  # Show the start page, and then execute the specified functions
  #
  showStartPage: (postFunctions = [])->
    Hy.Trace.debug "ConsoleApp::showStartPage"

    @questionChallengeInProgress = false

    this.showPage(Hy.Pages.PageState.Start, ((page)=>page.initialize()), postFunctions)

    @playerNetwork?.sendAll("prepForContest", {})

    this

  # ----------------------------------------------------------------------------------------------------------------
  # Invoked from "StartPage" when the enabled state of the Start Button changes.
  #
  obs_startPageStartButtonStateChanged: (state, reason)->

    @playerNetwork?.sendAll("prepForContest", {startEnabled: state, reason: reason})

    this

  # ----------------------------------------------------------------------------------------------------------------
  # Invoked from Page "StartPage" when "Start Game" button is touched
  #
  contestStart: ()->

    page = this.getPage()

    Hy.Media.SoundManager.get().playEvent("gameStart")
    page.contentPacksLoadingStart()

    if this.loadQuestions()
      @nQuestions = @contest.contestQuestions.length
      @iQuestion = 0
      @nAnswered = 0 # number of times at least one player responded

      page.contentPacksLoadingCompleted()

      Hy.Player.ConsolePlayer.findConsolePlayer().setHasAnswered(false)

      Hy.Network.NetworkService.get().setSuspended()

      @playerNetwork?.sendAll('startContest', {})

      this.showCurrentQuestion()

      @analytics?.logContestStart()

    else

      page.contentPacksLoadingCompleted()

      page.resetStartButtonClicked()

    this

  # ----------------------------------------------------------------------------------------------------------------
  #
  loadQuestions: ()->

    fnEdgeCaseError = (message)=>
      new Hy.Utils.ErrorMessage("fatal", "Console App Options", message) #will display popup dialog
      false

    contentManager = Hy.Content.ContentManager.get()

    this.getPage().contentPacksLoading("Loading topics...")

    @contentLoadTimer = new Hy.Utils.TimedOperation("INITIAL CONTENT LOAD")

    totalNumQuestions = 0
    for contentPack in (contentPacks = _.select(contentManager.getLatestContentPacksOKToDisplay(), (c)=>c.isSelected()))
      # Edge case: content pack isn't actually local...!
      if contentPack.isReadyForPlay()
        contentPack.load()
        totalNumQuestions += contentPack.getNumRecords()
      else
        return fnEdgeCaseError("Topic \"#{contentPack.getDisplayName()}\" not ready for play. Please unselect it")

    numSelectedContentPacks = _.size(contentPacks)

    @contentLoadTimer.mark("done")

    # Edge case: Shouldn't be here if no topics chosen...
    if numSelectedContentPacks is 0
      return fnEdgeCaseError("No topics chosen - Please choose one or more topics and try again")

    # Edge case: corruption in the option
    if not (numQuestionsNeeded = Hy.Options.numQuestions.getValue())? or not Hy.Options.numQuestions.isValidValue(numQuestionsNeeded)
      fnEdgeCaseError("Invalid \"Number of Questions\" option, resetting to 5 (#{numQuestionsNeeded})")
      numQuestionsNeeded = 5
      Hy.Options.numQuestions.setValue(numQuestionsNeeded)
      this.getPage().panelNumberOfQuestions.syncCurrentChoiceWithAppOption()

    # Special Case: numQuestions is -1, means "Play as many questions as possible, up to some limit"
    if numQuestionsNeeded is -1
      # Enforce max number
      numQuestionsNeeded = Math.min(totalNumQuestions, Hy.Config.Dynamics.maxNumQuestions)

    # Edge case: Shouldn't really be in this situation, either: not enough questions!
    # We should be able to set numQuestionsNeeded to a lower value to make it work, since
    # we know that the min number of questions in any contest is 5.
    if (shortfall = (numQuestionsNeeded - totalNumQuestions)) > 0
      for choice in Hy.Options.numQuestions.getChoices().slice(0).reverse()
        if choice isnt -1
          if (shortfall = (choice-totalNumQuestions)) <= 0
            numQuestionsNeeded = choice
            Hy.Options.numQuestions.setValue(numQuestionsNeeded)
            this.getPage().panelNumberOfQuestions.syncCurrentChoiceWithAppOption()
            this.getPage().contentPacksLoading("Number of questions reduced to accomodate selected topics...")
            break

      # Something's wrong: apparently have a contest with fewer than 5 questions
      if shortfall > 0
        return fnEdgeCaseError("Not enough questions - Please choose more topics and try again (requested=#{numQuestionsNeeded} shortfall=#{shortfall})")

    this.getPage().contentPacksLoading("Selecting questions...")

    # Edge case: if number of selected content packs > number of requested questions...
    numQuestionsPerPack = Math.max(1, Math.floor(numQuestionsNeeded / numSelectedContentPacks))

    @contest = new Hy.Contest.Contest()

    # This loop should always terminate because we know there are more than enough questions
    contentPacks = Hy.Utils.Array.shuffle(contentPacks)
    index = -1
    numQuestionsFound = 0
    while numQuestionsFound < numQuestionsNeeded

      if index < (numSelectedContentPacks - 1)
        index++
      else
        index = 0
        numQuestionsPerPack = 1 # To fill in the remainder

      contentPack = contentPacks[index]

      numQuestionsFound += (numQuestionsAdded = @contest.addQuestions(contentPack, numQuestionsPerPack))

      if numQuestionsAdded < numQuestionsPerPack
        Hy.Trace.debug "ConsoleApp::loadQuestions (NOT ENOUGH QUESTIONS FOUND pack=#{contentPack.getProductID()} #requested=#{numQuestionsPerPack} #found=#{numQuestionsAdded})"
#        return false # We should be ok, because we know there are enough questions in total...

    for contestQuestion in @contest.getQuestions()
      question = contestQuestion.getQuestion()
      Hy.Trace.debug "ConsoleApp::contestStart (question ##{question.id} #{question.topic})"

    true
  
  # ----------------------------------------------------------------------------------------------------------------
  contestPaused: (remotePage)->

    @playerNetwork?.sendAll('gamePaused', {page: remotePage})

    this

  # ----------------------------------------------------------------------------------------------------------------
  contestRestart: (completed = true)->
    # set this before showing the Start Page
    Hy.Network.NetworkService.get().setImmediate()

    this.showStartPage()

#    this.logContestEnd(completed, @nQuestions, @nAnswered, @contest)

    this

  # ----------------------------------------------------------------------------------------------------------------
  # Player requested that we skip to the final Scoreboard
  #
  contestForceFinish: ()->

    this.contestCompleted()

    this

  # ----------------------------------------------------------------------------------------------------------------
  contestCompleted: ()->

    Hy.Trace.debug("ConsoleApp::contestCompleted")

    fnNotify = ()=>
      
      for o in (leaderboard = this.getPage().getLeaderboard())
        for player in o.group
          Hy.Trace.debug("ConsoleApp::contestCompleted (score: #{o.score} player#: #{player})")

      @playerNetwork?.sendAll('contestCompleted', {leaderboard: leaderboard})

      null

    iQuestion = @iQuestion # By the time the init function below is called, @iQuestion will have been nulled out
    Hy.Network.NetworkService.get().setImmediate()

    this.showPage(Hy.Pages.PageState.Completed, (page)=>page.initialize(fnNotify))

    Hy.Network.NetworkService.get().setImmediate()
    this.logContestEnd(true, @iQuestion, @nAnswered, @contest)

    @nQuestions = null
    @iQuestion = null
    @cq = null

    Hy.Utils.MemInfo.log "Contest Completed"

    this

  # ----------------------------------------------------------------------------------------------------------------
  showQuestionChallengePage: (startingDelay)->

    someText = @cq.question.question
    someText = someText.substr(0, Math.min(30, someText.length))

    Hy.Trace.debug "ConsoleApp::showQuestionChallengePage (#=#{@iQuestion} question=#{@cq.question.id}/#{someText})"

    @currentPageHadResponses = false #set to true if at least one player responded to current question

    @questionChallengeInProgress = true

    # we copy these here to avoid possible issues with variable bindings, when the callbacks below are invoked
    cq = @cq
    iQuestion = @iQuestion
    nQuestions = @nQuestions

    fnNotify = ()=>@playerNetwork?.sendAll('showQuestion', {questionId: cq.question.id})
    fnPause = ()=>this.contestPaused("showQuestion")
    fnCompleted = ()=>this.challengeCompleted()

    nSeconds = Hy.Options.secondsPerQuestion.choices[Hy.Options.secondsPerQuestion.index]

    if not nSeconds? or not (nSeconds >= 10 and nSeconds <= 570) # this is brittle. HACK
      error = "INVALID nSeconds: #{nSeconds}"
      Hy.Trace.debug "ConsoleApp (#{error})"
      new Hy.Utils.ErrorMessage("fatal", "Console App Options", error) #will display popup dialog
      nSeconds = 10
      Hy.Options.secondsPerQuestion.setIndex(0)
      this.getPage().panelSecondsPerQuestion.syncCurrentChoiceWithAppOption()

    this.showPage(Hy.Pages.PageState.Question, (page)=>page.initializeForQuestion(fnNotify, fnPause, fnCompleted, nSeconds, startingDelay, cq, iQuestion, nQuestions))

  # ----------------------------------------------------------------------------------------------------------------
  challengeCompleted: (finishedEarly=false)->

    if @questionChallengeInProgress 
      Hy.Media.SoundManager.get().playEvent("challengeCompleted")
      this.getPage().animateCountdownQuestionCompleted()
      this.getPage().stop() #haltCountdown() #adding this here to ensure that countdown stops immediately, avoid overlapping countdowns

      @questionChallengeInProgress = false
      @cq.setUsed()
      @nAnswered++ if @currentPageHadResponses

      this.showQuestionAnswerPage()

  # ----------------------------------------------------------------------------------------------------------------
  showQuestionAnswerPage: ()->
#    Hy.Trace.debug "ConsoleApp::showQuestionAnswerPage(#=#{@iQuestion} question=#{@cq.question.id} Responses=#{@currentPageHadResponses} nAnswered=#{@nAnswered})"

    responseVector = []

    # Tell the remotes if we received their responses in time
    for response in Hy.Contest.ContestResponse.selectByQuestionID(@cq.question.id)
      responseVector.push {player: response.getPlayer().getIndex(), score: response.getScore()}
    
    fnNotify = ()=>@playerNetwork?.sendAll('revealAnswer', {questionId: @cq.question.id, indexCorrectAnswer: @cq.indexCorrectAnswer, responses:responseVector})
    fnPause = ()=>this.contestPaused("revealAnswer")
    fnCompleted = ()=>this.questionAnswerCompleted()

    this.showPage(Hy.Pages.PageState.Answer, (page)=>page.initializeForAnswers(fnNotify, fnPause, fnCompleted, Hy.Config.Dynamics.revealAnswerTime, 0))

  # ----------------------------------------------------------------------------------------------------------------
  questionAnswerCompleted: ()->

    Hy.Trace.debug "ConsoleApp::questionAnswerCompleted(#=#{@iQuestion} question=#{@cq.question.id})"

    @iQuestion++

    if @iQuestion >= @nQuestions
      this.contestCompleted() 
    else
      this.showCurrentQuestion()

    this


  # ----------------------------------------------------------------------------------------------------------------
  showCurrentQuestion: ()->

    Hy.Trace.debug "ConsoleApp::showCurrentQuestion(#=#{@iQuestion})"

    @cq = @contest.contestQuestions[@iQuestion]

    if @iQuestion >= @nQuestions
      this.contestCompleted()
    else
      this.showQuestionChallengePage(500)

    this

  # ----------------------------------------------------------------------------------------------------------------  
  remotePlayerAdded: (connection, label, majorVersion, minorVersion)->

    Hy.Trace.debug "ConsoleApp::remotePlayerAdded (##{connection}/#{label})"
    s = "?"

    player = Hy.Player.RemotePlayer.findByConnection(connection)

    if player?
      player.reactivate()
      s = "EXISTING"
    else
      player = Hy.Player.RemotePlayer.create(connection, label, majorVersion, minorVersion)
      @analytics?.logNewPlayer(Hy.Player.Player.count() - 1 ) # Don't count the console player
      s = "NEW"

    Hy.Media.SoundManager.get().playEvent("remotePlayerJoined")

    remotePage = this.remotePlayerMapPage()

    currentResponse = null
    if @cq?
      currentResponse = Hy.Contest.ContestResponse.selectByQuestionIDAndPlayer @cq.question.id, player

    Hy.Trace.debug "ConsoleApp::remotePlayerAdded (#{s} #{player.dumpStr()} page=#{remotePage.op} currentAnswerIndex=#{if currentResponse? then currentResponse.answerIndex else -1})"

    op = "welcome"
    data = {}
    data.index = player.index
    data.page = remotePage
    data.questionId = (if @cq? then @cq.question.id else -1)
    data.answerIndex = (if currentResponse? then currentResponse.answerIndex else -1)
    data.score = player.score()
    data.addressEncoding = Hy.Network.NetworkService.getAddressEncoding()

    data.playerName = player.getName()

    avatar = player.getAvatar()
    data.avatar = {}
    data.avatar.name = avatar.getName()
    data.avatar.avatarSet = avatar.getAvatarSetName()
    data.avatar.avatarHeight = avatar.getHeight()
    data.avatar.avatarWidth = avatar.getWidth()

    @playerNetwork?.sendSingle(player.getConnection(), op, data)

    player

  # ----------------------------------------------------------------------------------------------------------------  
  remotePlayerRemoved: (connection)->

    Hy.Trace.debug "ConsoleApp::remotePlayerRemoved (#{connection})"

    player = Hy.Player.RemotePlayer.findByConnection(connection)

    if player?

      Hy.Trace.debug "ConsoleApp::remotePlayerRemoved (#{player.dumpStr()})"
      player.destroy()

    this

  # ----------------------------------------------------------------------------------------------------------------
  remotePlayerStatusChanged: (connection, status)->

    player = Hy.Player.RemotePlayer.findByConnection(connection)

    if player?
      Hy.Trace.debug "ConsoleApp::remotePlayerStatusChanged (status=#{status} #{player.dumpStr()})"
      if status
        player.reactivate()
      else
        player.deactivate()

    this

  # ----------------------------------------------------------------------------------------------------------------
  remotePlayerMessage: (connection, op, data)->

    player = Hy.Player.RemotePlayer.findByConnection(connection)

    if player?
      if @pageState.isTransitioning()
        Hy.Trace.debug "ConsoleApp::messageReceivedFromPlayer (IGNORING, in Page Transition)"
      else
        handled = if op is "playerNameChangeRequest"
          this.doPlayerNameChangeRequest(player, data)
        else
          this.doGameOp(player, op, data)

        if not handled
          Hy.Trace.debug "ConsoleApp::messageReceivedFromPlayer (UNKNOWN OP #{op} #{connection})"
    else
      Hy.Trace.debug "ConsoleApp::messageReceivedFromPlayer (UNKNOWN PLAYER #{connection})"

    this

  # ----------------------------------------------------------------------------------------------------------------
  doPlayerNameChangeRequest: (player, data)->

    result = player.setName(data.name)

    if result.errorMessage?
      data.errorMessage = result.errorMessage
    else
      data.givenName = result.givenName
   
    @playerNetwork?.sendSingle(player.getConnection(), "playerNameChangeRequestResponse", data)

    true
  # ----------------------------------------------------------------------------------------------------------------
  doGameOp: (player, op, data)->

    handled = true

    switch op
      when "answer"  
        Hy.Trace.debug "ConsoleApp::messageReceivedFromPlayer (Answered: question=#{data.questionId} answer=#{data.answerIndex} player=#{player.dumpStr()})"
        this.playerAnswered(player, data.questionId, data.answerIndex)
      when "pauseRequested"
        Hy.Trace.debug "ConsoleApp::messageReceivedFromPlayer (pauseRequested: player=#{player.dumpStr()})"
        if this.getPage()?
          switch this.getPage().getState()
            when Hy.Pages.PageState.Question, Hy.Pages.PageState.Answer
              if not this.getPage().isPaused()
                this.getPage().fnPauseClick()
      when "continueRequested"
        Hy.Trace.debug "ConsoleApp::messageReceivedFromPlayer (continueRequested: player=#{player.dumpStr()})"
        if this.getPage()?
          switch this.getPage().getState()
            when Hy.Pages.PageState.Question, Hy.Pages.PageState.Answer
              if this.getPage().isPaused()
                this.getPage().fnClickContinueGame()
      when "newGameRequested"
        Hy.Trace.debug "ConsoleApp::messageReceivedFromPlayer (newGameRequested: player=#{player.dumpStr()})"
        if this.getPage()?
          switch this.getPage().getState()
            when Hy.Pages.PageState.Start
              this.getPage().fnClickStartGame()
            when Hy.Pages.PageState.Completed
              this.getPage().fnClickPlayAgain()
            when Hy.Pages.PageState.Question, Hy.Pages.PageState.Answer
              if this.getPage().isPaused()
                this.getPage().fnClickNewGame()
      else 
        handled = false

    handled

  # ----------------------------------------------------------------------------------------------------------------
  remotePlayerMapPage: ()->

    page = this.getPage()

    remotePage = if page?
      switch page.constructor.name
        when "SplashPage", "IntroPage"
          {op: "introPage"}
        when "StartPage"
          [state, reason] = page.getStartEnabled()
          {op: "prepForContest", data: {startEnabled:state, reason: reason}}
        when "AboutPage", "UserCreatedContentInfoPage"
          {op: "aboutPage"}
        when "QuestionPage"
          if page.isPaused()
            {op: "gamePaused"}
          else 
            if @questionChallengeInProgress && page.getCountdownValue() > 5
              {op: "showQuestion", data: {questionId: (if @cq? then @cq.question.id else -1)}}
            else
              {op: "waitingForQuestion"}
        when "ContestCompletedPage"
          {op: "contestCompleted"}
        else
          {op: "prepForContest"}
    else
      {op: "prepForContest"}
 
    remotePage

  # ----------------------------------------------------------------------------------------------------------------
  consolePlayerAnswered: (answerIndex)->

    Hy.Player.ConsolePlayer.findConsolePlayer().setHasAnswered(true)
    this.playerAnswered(Hy.Player.ConsolePlayer.findConsolePlayer(), @cq.question.id, answerIndex)

    this

  # ----------------------------------------------------------------------------------------------------------------
  playerAnswered: (player, questionId, answerIndex)->

    if not this.answeringAllowed(questionId)
      return

    isConsole = player.isKind(Hy.Player.Player.kKindConsole)

    responses = Hy.Contest.ContestResponse.selectByQuestionID(questionId)

    if (r = this.playerAlreadyAnswered(player, responses))?
#      Hy.Trace.debug "ConsoleApp::playerAnswered(Player already answered! questionId=#{questionId}, answerIndex (last time)=#{r.answerIndex} answerIndex (this time)=#{answerIndex} player => #{player.index})"
      return

    cq = Hy.Contest.ContestQuestion.findByQuestionID(@contest.contestQuestions, questionId)

    isCorrectAnswer = cq.indexCorrectAnswer is answerIndex

#    Hy.Trace.debug "ConsoleApp::playerAnswered(#=#{@iQuestion} questionId=#{questionId} answerIndex=#{answerIndex} correct=#{cq.indexCorrectAnswer} #{if isCorrectAnswer then "CORRECT" else "INCORRECT"} player=#{player.index}/#{player.label})"

    response = player.buildResponse(cq, answerIndex, this.getPage().getCountdownStartValue(), this.getPage().getCountdownValue())
    this.getPage().playerAnswered(response)

    @currentPageHadResponses = true

    firstCorrectMode = Hy.Options.firstCorrect.getValue() is "yes"

    # if all remote players have answered OR if the console player answers, end this challenge
    done = if isConsole
      true
    else
      if firstCorrectMode and isCorrectAnswer
        true
      else
        activeRemotePlayers = Hy.Player.Player.getActivePlayersByKind(Hy.Player.Player.kKindRemote)

        if (activeRemotePlayers.length is responses.length+1)
          true
        else
          false

    if done
      this.challengeCompleted(true)

    this

  # ----------------------------------------------------------------------------------------------------------------
  playerAlreadyAnswered: (player, responses)->

    return _.detect(responses, (r)=>r.player.index is player.index)

  # ----------------------------------------------------------------------------------------------------------------
  answeringAllowed: (questionId)->

    (@questionChallengeInProgress is true) && (questionId is @cq.question.id)

  # ----------------------------------------------------------------------------------------------------------------
  logContestEnd: (completed, nQuestions, nAnswered, contest)->

    numUserCreatedQuestions = 0

    topics = []
    for contestQuestion in contest.getQuestions()
      if contestQuestion.wasUsed()
        # Find the contentPack via the topic, which is really a ProductID
        if (contentPack = Hy.Content.ContentPack.findLatestVersion(topic = contestQuestion.getQuestion().topic))?
          if contentPack.isThirdParty()
            numUserCreatedQuestions++
          else
            topics.push(topic)

    @analytics?.logContestEnd(completed, nQuestions, nAnswered, topics, numUserCreatedQuestions)

    this

  # ----------------------------------------------------------------------------------------------------------------
  userCreatedContentAction: (action, context = null, showStartPage = false)->

    contentManager = Hy.Content.ContentManager.get()

    if showStartPage
      this.showStartPage([(page)=>this.userCreatedContentAction(action, context, false)])
    else
      switch action
        when "refresh"
          contentManager.userCreatedContentRefreshRequested(context)
        when "delete"
          contentManager.userCreatedContentDeleteRequested(context)
        when "upsell"
          contentManager.userCreatedContentUpsell()
        when "buy"
          contentManager.userCreatedContentBuyFeature()
        when "add"
          contentManager.userCreatedContentAddRequested()
        when "info"
          this.showUserCreatedContentInfoPage()
    this

  # ----------------------------------------------------------------------------------------------------------------
  showUserCreatedContentInfoPage: ()->
    @playerNetwork?.sendAll("aboutPage", {})
    this.showPage(Hy.Pages.PageState.UCCInfo, (page)=>page.initialize())

  # ----------------------------------------------------------------------------------------------------------------
  restoreAction: ()->

    this.showStartPage([(page)=>Hy.Content.ContentManager.get().restore()])

    this


# ==================================================================================================================
# assign to global namespace:
Hy.ConsoleApp = ConsoleApp


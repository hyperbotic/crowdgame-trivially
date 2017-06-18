# ==================================================================================================================
class Panel extends Hy.UI.ViewProxy
  # ----------------------------------------------------------------------------------------------------------------
  constructor: (options = {})->

    defaultOptions = 
      _tag: "Panel: #{this.constructor.name}"

    super Hy.UI.ViewProxy.mergeOptions(defaultOptions, options)

    this

  # ----------------------------------------------------------------------------------------------------------------
  initialize: ()->

    this

  # ----------------------------------------------------------------------------------------------------------------
  obs_networkChanged: (reason)->

    this

# ==================================================================================================================
class CountdownPanel extends Panel

  kWidth = 86
  kHeight = 86

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (options = {}, @fnPauseClick)->

    defaultOptions = 
      height: kHeight
      width: kWidth
      zIndex: 102

    super Hy.UI.ImageViewProxy.mergeOptions(defaultOptions,options)

    buttonOptions = 
      font: Hy.UI.Fonts.specBiggerNormal
      backgroundImage: "assets/icons/circle-black.png"
      backgroundSelectedImage: "assets/icons/circle-black-selected.png"
      color: Hy.UI.Colors.white
      textAlign: 'center'
      zIndex: 150
      _tag: "Timer"
      height: kWidth - 20
      height: (kWidth - 20)/2
      width: kWidth - 20
      _style: "plain"
#      borderWidth: 1
#      borderColor: Hy.UI.Colors.white

    this.addChild(@pauseButton = new Hy.UI.ButtonProxy(buttonOptions))

    f = ()=>@fnPauseClick()

    @pauseButton.addEventListener("click", f)

    buttonRimOptions = 
      image: "assets/icons/countdown-background.png"
      height: kHeight
      width: kWidth

    this.addChild(@pauseButtonRim = new Hy.UI.ImageViewProxy(buttonRimOptions))

    this

  # ----------------------------------------------------------------------------------------------------------------
  initialize: ()->

    super

    this.initButtonRimAnimation()

    this

  # ----------------------------------------------------------------------------------------------------------------
  animateCountdown: (options, value = null, total = null, init = false)->

    this.animateButtonRim(options, value, total, init)

    this.animateLabel(options, value, total, init)

  # ----------------------------------------------------------------------------------------------------------------
  initButtonRimAnimation: ()->

    animation = Ti.UI.createAnimation()
    m = Ti.UI.create2DMatrix()

    @buttonRotation = 0
    animation.duration = 0
    animation.transform = m.rotate(0)

    @pauseButtonRim.animate(animation)

  # ----------------------------------------------------------------------------------------------------------------
  animateButtonRim: (options, value, total, init)->

    if options._style? and options._style is "frantic" and not init
      animation = Ti.UI.createAnimation()
      m = Ti.UI.create2DMatrix()

      animation.transform = m.rotate(++@buttonRotation * 90)
      animation.duration = 100

      @pauseButtonRim.animate(animation)

    this

  # ----------------------------------------------------------------------------------------------------------------
  setLabelTitle: (value)->

    minutes = Math.floor(value / 60)
    seconds = value % 60

    s = ""

    if minutes is 0
      s = "#{seconds}"
      font = Hy.UI.Fonts.specBiggerNormal
    else
      font = Hy.UI.Fonts.mergeFonts(Hy.UI.Fonts.specBiggerNormal, {fontSize: 30})

      s = "#{minutes}:#{if seconds < 10 then "0" else ""}#{seconds}"

    @pauseButton.setUIProperty("font", font)

    @pauseButton.setUIProperty("title", s)
    this

  # ----------------------------------------------------------------------------------------------------------------
  animateLabel: (options, value, total, init)->

    if value?
      this.setLabelTitle(value)

    if options._style?
      color = switch options._style
        when "normal"
          Hy.UI.Colors.white

        when "frantic"
          if value? and value <= Hy.Config.Dynamics.panicAnswerTime
            Hy.UI.Colors.MrF.Red
          else
            Hy.UI.Colors.white

        when "completed"
          Hy.UI.Colors.MrF.Red
  
        else
          Hy.UI.Colors.white

#      @label.setUIProperty("color", color)
      @pauseButton.setUIProperty("color", color)
    this

# ==================================================================================================================
class QuestionInfoPanel extends Panel

  kHeight = kWidth = 86
  # ----------------------------------------------------------------------------------------------------------------
  constructor: (options = {})->

    defaultOptions = 
      height: kHeight
      width:  kWidth
      zIndex: 120

    super (options = Hy.UI.ViewProxy.mergeOptions(defaultOptions,options))

    labelOptions = 
      font: Hy.UI.Fonts.specMediumNormal
      textAlign: 'center'
      height: (options.height * .35)
      width: (options.width * .35)
      _tag: "Question Info"
      zIndex: defaultOptions.zIndex + 1

    labelOptions.font.fontSize = 24
    
    this.addChild(@currentQLabel = new Hy.UI.LabelProxy(Hy.UI.ViewProxy.mergeOptions(labelOptions, {color: Hy.UI.Colors.black, bottom: (options.height/2), right: (options.width/2)})))

    fudge = 3
    this.addChild(@totalQLabel =   new Hy.UI.LabelProxy(Hy.UI.ViewProxy.mergeOptions(labelOptions, {color: Hy.UI.Colors.MrF.DarkBlue, top: ((options.height/2)-fudge), left: (options.width/2)})))

    this.addChild(new Hy.UI.ImageViewProxy({image: "assets/icons/question-info-background.png", zIndex: labelOptions.zIndex-1}))

    this

  # ----------------------------------------------------------------------------------------------------------------
  initialize: (currentQ, totalQ, color)->

    super

    @currentQLabel.setUIProperty("text", currentQ)
#    @currentQLabel.setUIProperty("color", color)

    @totalQLabel.setUIProperty("text", "#{totalQ}")
#    @totalQLabel.setUIProperty("color", color)

    this

# ==================================================================================================================
class CritterPanel extends Panel

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (options = {})->

    super options

    @stages = []

    this.addAvatarStages()

    this

  # ----------------------------------------------------------------------------------------------------------------
  addAvatarStages: ()->

    options = 
      _orientation:"horizontal"
      bottom: 0
      left:0

    this.addChild(@avatarStage = new Hy.Avatars.AvatarStage(options))

    this.setUIProperty("height", @avatarStage.getUIProperty("height"))

    @stages.push @avatarStage

    this    

  # ----------------------------------------------------------------------------------------------------------------
  initialize: ()->

    super

    @players = []

    for stage in @stages
      stage.initialize()

    this

  # ----------------------------------------------------------------------------------------------------------------
  start: ()->
    super

    for stage in @stages
      stage.start()

    this
  # ----------------------------------------------------------------------------------------------------------------
  stop: ()->

    for stage in @stages
      stage.stop()

    super

    this
  # ----------------------------------------------------------------------------------------------------------------
  pause: ()->
    super

    for stage in @stages
      stage.pause()

    this
  # ----------------------------------------------------------------------------------------------------------------
  resumed: ()->
    super

    for stage in @stages
      stage.resumed()

    this

  # ----------------------------------------------------------------------------------------------------------------
  findPlayer: (player)->

    _.detect(@players, (p)=>p.playerIndex is player.getIndex())

  # ----------------------------------------------------------------------------------------------------------------
  addPlayer: (player, avatarStage)->

    avatarSpec = avatarStage.addAvatar(player.getAvatar())

    playerSpec = {playerIndex:player.getIndex(), avatarSpec: avatarSpec}
    @players.push playerSpec

    playerSpec

  # ----------------------------------------------------------------------------------------------------------------
  removePlayer: (player, avatarStage = @avatarStage)->

    if (playerSpec = this.findPlayer(player))?
      avatarStage.removeAvatar(playerSpec.avatarSpec)
      @players = _.without(@players, playerSpec)

    this

  # ----------------------------------------------------------------------------------------------------------------
  checkPlayer: (player, avatarStage = @avatarStage)->

    playerSpec = this.findPlayer player

    if !playerSpec?
      playerSpec = this.addPlayer(player, avatarStage)

    playerSpec

  # ----------------------------------------------------------------------------------------------------------------
  animateCritter: (player, animation, options={}, avatarStage = @avatarStage)->

    avatarStage?.animateAvatars([this.checkPlayer(player).avatarSpec], animation, options)

    this

  # player{Created,Deactivated,Reactivated,Destroyed} are called by Hy.Player.Player as observers, registered by 
  # CheckInCritterPanel
  #
  # ----------------------------------------------------------------------------------------------------------------
  obs_playerCreated: (player)->

    this

  # ----------------------------------------------------------------------------------------------------------------
  obs_playerDeactivated: (player)->

    this

  # ----------------------------------------------------------------------------------------------------------------
  obs_playerReactivated: (player)->

    this

  # ----------------------------------------------------------------------------------------------------------------
  obs_playerDestroyed: (player)->

    this.removePlayer(player)

    this

# ==================================================================================================================
class CheckInCritterPanel extends CritterPanel

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (options = {})->

    super options

  # ----------------------------------------------------------------------------------------------------------------
  start: ()->
    super

    Hy.Player.Player.addObserver this

    activePlayers = Hy.Player.Player.getActivePlayersSortedByJoinOrder()

    # if there are remote players, don't show the console player
    if _.size(activePlayers) > 1
      activePlayers = _.without(activePlayers, Hy.Player.ConsolePlayer.findConsolePlayer())

    avatarSpecs = []
    for player in activePlayers
      avatarSpecs.push this.checkPlayer(player).avatarSpec

    options = 
      _stageOrder: "asProvided"

    @avatarStage?.animateAvatars(avatarSpecs, "created", options)

    this

  # ----------------------------------------------------------------------------------------------------------------
  stop: ()->

    Hy.Player.Player.removeObserver this

    super

  # ----------------------------------------------------------------------------------------------------------------
  pause: ()->
    super

  # ----------------------------------------------------------------------------------------------------------------
  resumed: ()->
    super

  # ----------------------------------------------------------------------------------------------------------------
  initialize: ()->

    super

  # ----------------------------------------------------------------------------------------------------------------
  obs_playerCreated: (player)->

    Hy.Trace.debug "CritterPanel::playerCreated (#{player.dumpStr()})"
 
    super

    # this will attempt to place the avatar in the same position as when last created
    this.animateCritter(player, "created", {_stageOrder: "perAvatar"})

    this

  # ----------------------------------------------------------------------------------------------------------------
  obs_playerDeactivated: (player)->

    Hy.Trace.debug "CritterPanel::playerDeactivated (#{player.dumpStr()})"

    this.animateCritter(player, "deactivated")

    super

    this

  # ----------------------------------------------------------------------------------------------------------------
  obs_playerReactivated: (player)->

    Hy.Trace.debug "CritterPanel::playerReactivated (#{player.dumpStr()})"

    super

    # this will attempt to place the avatar in the same position as when last created
    this.animateCritter(player, "reactivated", {_stageOrder: "perAvatar"})

    this

  # ----------------------------------------------------------------------------------------------------------------
  obs_playerDestroyed: (player)->

    Hy.Trace.debug "CritterPanel::playerDestroyed (#{player.dumpStr()})"

    this.animateCritter(player, "destroyed")

    super

    this

# ==================================================================================================================
class AnswerCritterPanel extends CritterPanel

  # ----------------------------------------------------------------------------------------------------------------
  playerAnswered: (response, showCorrectness = false, topScorer = false)->

    options = 
      _stageOrder: "fill" # will place the avatar on the stage in order created (answered)

    animation = if showCorrectness then "showCorrectness" else "answered"

    if showCorrectness
      options._showCorrectness = response.getCorrect()
      options._score = response.getScore()
      options._topScorer = topScorer

    this.animateCritter(response.player, animation, options)

# ==================================================================================================================
class ScoreboardCritterPanel extends CritterPanel

  # Per Ed's design
  stageLayouts = [
    {low: 1, high:  3, numStages: 1, maxPerStage: 3}
    {low: 4, high:  4, numStages: 2, maxPerStage: 2}
    {low: 5, high:  6, numStages: 2, maxPerStage: 3}
    {low: 7, high:  8, numStages: 2, maxPerStage: 4}
    {low: 9, high: 12, numStages: 3, maxPerStage: 4}
    ]

  # ----------------------------------------------------------------------------------------------------------------
  findLayoutSpec: (numAvatars)->
    for layout in stageLayouts
      if layout.low <= numAvatars <= layout.high
        return layout
    return null

  # ----------------------------------------------------------------------------------------------------------------
  # How many stages will we need to fit numAvatars?
  #
  computeNumStages: (numAvatars)->

    if (layout = this.findLayoutSpec(numAvatars))?
      layout.numStages
    else
      0

  # ----------------------------------------------------------------------------------------------------------------
  # How many avatars should be placed on stage# stageIndex (1-based)?
  #
  computeNumAvatarsOnStage: (numAvatars, stageIndex)->

    count = 0
    if (layout = this.findLayoutSpec(numAvatars))?
      if stageIndex < layout.numStages
        count = layout.maxPerStage
      else
        count = numAvatars - ((layout.numStages-1) * layout.maxPerStage)

    count

  # ----------------------------------------------------------------------------------------------------------------
  addAvatarStages: ()->

    numPlayers = _.size(Hy.Player.Player.collection())

    # if console player didn't participate, don't show in the leaderboard
    if not Hy.Player.ConsolePlayer.findConsolePlayer().hasAnswered()
      numPlayers--

    options = 
      _scoreOrientation: "horizontal"
      _avatarBacklighting: true

    updateOptions = {}

    switch this.getUIProperty("_orientation")
      when "horizontal"
        options._orientation = "horizontal"
        updateOptions._verticalLayout = "group"
        updateOptions._horizontalLayout = "center"

      when "vertical"
        options._orientation = "vertical"
        updateOptions._verticalLayout = "center"
        updateOptions._horizontalLayout = "group"

    this.setUIProperties(updateOptions)

    @stages = []

    if numPlayers > 0
      for i in [1..this.computeNumStages(numPlayers)]
        options._maxNumAvatars = this.computeNumAvatarsOnStage(numPlayers, i)
        @stages.push (stage = new Hy.Avatars.AvatarStageWithScores(options))

      this.addChildren(@stages)
       
    this

  # ----------------------------------------------------------------------------------------------------------------
  displayScores: ()->

    players = Hy.Player.Player.collection()

    # if console player didn't participate, don't show in the leaderboard
    if not Hy.Player.ConsolePlayer.findConsolePlayer().hasAnswered()
      players = _.without(players, Hy.Player.ConsolePlayer.findConsolePlayer())

    fnSortPlayers = (p1, p2)=>p2.score(Hy.ConsoleApp.get().contest) - p1.score(Hy.ConsoleApp.get().contest)
    @leaderboard = players.sort(fnSortPlayers)
    numPlayers = _.size(@leaderboard)

    initialScore = null

    playerNum = 0
    for stage, stageNum in @stages
      for position in [1..this.computeNumAvatarsOnStage(numPlayers, stageNum + 1)]
        player = @leaderboard[playerNum++]

        stage.animateAvatars([this.checkPlayer(player, stage).avatarSpec], "showScore", {_score: player.score()})

    this

  # ----------------------------------------------------------------------------------------------------------------
  # Returns an array of objects: {score: <number>, group: <array>}, where "group" is an array of playerIndex representing
  # players with "score". Array is sorted in order of decreasing score.
  #
  # Used to send scores to remotes!
  #
  getLeaderboard: ()->

    standings = []

    if @leaderboard?
      tempObj = _.groupBy(@leaderboard, (p)=>p.score())

      # "temp" is an object. We want a sorted array
      tempArray = []
      for score, group of tempObj
        tempArray.push {score:score, group:_.pluck(group, "index")}

      _.sortBy(tempArray, (o)=>o.score).reverse()
    else
      null

# ==================================================================================================================

class UtilityPanel extends Panel

  kRowHeight = 16
  @kButtonContainerWidth = 180
  @kButtonBottom = 70

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (options = {})->

    super options

    @labelView = null   

    this

  # ----------------------------------------------------------------------------------------------------------------
  # 
  # We re-render everything here since these Panels tend to have dynamic info on 'em
  #
  initialize: ()->

    super

    this.addInfo()

    this.initButtonState()

    this

  # ----------------------------------------------------------------------------------------------------------------
  viewOptions: ()-> {}

  # ----------------------------------------------------------------------------------------------------------------
  addInfo: (animateFlag = false)->

    duration = 250

    fn = ()=>
      if @labelView?
        this.removeChild(@labelView)
        @labelView = null

      this.addChild(@labelView = new Hy.UI.ViewProxy(this.labelViewOptions()))
 
      for labelSection in this.labelSections()
        this.addLabelItem(@labelView, labelSection)

      if animateFlag
        this.animate({opacity: 1, duration: duration})

      null

    # Animate out gracefully if there's text already on display
    if animateFlag
      this.animate({opacity: 0, duration: duration}, (e)=>fn(duration))
    else
      fn()

    this

  # ----------------------------------------------------------------------------------------------------------------
  labelViewOptions: ()-> {}

  # ----------------------------------------------------------------------------------------------------------------
  labelSections: ()-> []

  # ----------------------------------------------------------------------------------------------------------------
  labelOptions: ()-> 
    top:     8
    left:   20
    right:  20
    height: 'auto'
    font:   Hy.UI.Fonts.specSmallNormal
    zIndex: this.getUIProperty("zIndex")-1
    color: Hy.UI.Colors.black
    _tag: "Info Label"
#    borderWidth: 1
#    borderColor: Hy.UI.Colors.white

  # ----------------------------------------------------------------------------------------------------------------
  addLabelItem: (view, labelSpecs)->
    views = []
    for labelSpec in labelSpecs
      view.addChild(v = new Hy.UI.LabelProxy(Hy.UI.ViewProxy.mergeOptions(this.labelOptions(), labelSpec.options, {text: labelSpec.text})))
      views.push v

    views

  # ----------------------------------------------------------------------------------------------------------------
  addButton: (name, fnClick, containerOptions, buttonOptions, labelOptionsArray)->

    buttonDimensions = height = 72
    width = UtilityPanel.kButtonContainerWidth
    padding = 10

    defaultContainerOptions =
      width: width
      height: height
      bottom: UtilityPanel.kButtonBottom
      _tag: "Button Container"
#      borderColor: Hy.UI.Colors.white
#      borderWidth: 1

    container = new Hy.UI.ViewProxy(Hy.UI.ViewProxy.mergeOptions(defaultContainerOptions, containerOptions))

    defaultButtonOptions = 
      height: buttonDimensions
      width: buttonDimensions
      left: 0
      bottom: 0
      zIndex: 150
      _tag: "Button"
#      borderColor: Hy.UI.Colors.white
#      borderWidth: 1

    container.addChild(button = new Hy.UI.ButtonProxy(Hy.UI.ViewProxy.mergeOptions(defaultButtonOptions, buttonOptions)))

    this.setButtonState(name, false)

    fn = (e, v)=>
      if not this.getButtonState(name)
        this.setButtonState(name, true)
        fnClick(e, v)
      null
  
    button.addEventListener("click", fn)

    defaultLabelOptions = 
      font: Hy.UI.Fonts.mergeFonts(Hy.UI.Fonts.specMediumNormal, {fontSize: 18})
      color: Hy.UI.Colors.white
      left: buttonDimensions + padding
#      bottom: 0
      width: width - (buttonDimensions + padding)
      _tag: "Button Label"
#      borderColor: Hy.UI.Colors.green
#      borderWidth: 1

    for labelOptions in labelOptionsArray
      container.addChild(new Hy.UI.LabelProxy(Hy.UI.ViewProxy.mergeOptions(defaultLabelOptions, labelOptions)))

    container

  # ----------------------------------------------------------------------------------------------------------------
  findButtonState: ()->
    if not @buttonState?
      @buttonState = {}
    @buttonState

  # ----------------------------------------------------------------------------------------------------------------
  getButtonState: (name)-> 
    this.findButtonState()[name]

  # ----------------------------------------------------------------------------------------------------------------
  setButtonState: (name, value)-> 
    this.findButtonState()[name] = value

  # ----------------------------------------------------------------------------------------------------------------
  initButtonState: ()->
    for name, value of this.findButtonState()
      this.setButtonState(name, false)

    this

  # ----------------------------------------------------------------------------------------------------------------
  launchURL: (url)->

    Ti.Platform.openURL(url)

    this

# ==================================================================================================================

class IntroPanel extends UtilityPanel

  @kWidth = 900
  @kHeight = 500

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (options = {})->

    super options

  # ----------------------------------------------------------------------------------------------------------------
  obs_networkChanged: (reason)->

    super

    if reason is "Wifi"
      this.addInfo(true)

    this

  # ----------------------------------------------------------------------------------------------------------------
  viewOptions: ()->
    height: IntroPanel.kHeight
    width: IntroPanel.kWidth
    borderRadius: 16
    zIndex: 102
    _tag: "Info"
#    borderColor: Hy.UI.Colors.green
#    borderWidth: 1

  # ----------------------------------------------------------------------------------------------------------------
  labelViewOptions: ()->
    top: 0
    height: IntroPanel.kHeight
    width: IntroPanel.kWidth
    layout: 'vertical'
    zIndex: this.getUIProperty("zIndex")

  # ----------------------------------------------------------------------------------------------------------------
  labelSections: ()->
    [this.sectionTitle(), this.sectionBody(), this.sectionDismiss()]

  # ----------------------------------------------------------------------------------------------------------------
  sectionBody: ()->

    t = []
    t.push {text: "One person can play on this iPad directly, OR", options: {textAlign: "center"}}
    t.push {text: "Up to #{Hy.Config.kMaxRemotePlayers} players with iOS devices, or", options: {textAlign: "center"}}
    t.push {text: "Safari, FireFox, Chrome, or IE on Windows 8, MacOS, or Ubuntu,", options: {textAlign: "center"}}
    t.push {text: "can compete to answer questions displayed on this iPad", options: {textAlign: "center"}}
    t.push {text: "", options: {textAlign: "center"}}
    t.push {text: "All player devices and this iPad should be on the same Wifi network", options: {textAlign: "center"}}

    if Hy.Network.NetworkService.isOnlineWifi()
      if (encoding = Hy.Network.NetworkService.getAddressEncoding())?
        t.push {text: "Each player should visit #{Hy.Config.Rendezvous.URLDisplayName} and enter code:", options: {textAlign: "center"}}
        t.push {text: " #{encoding} ", options: {textAlign: "center", color: Hy.UI.Colors.MrF.Red, font: Hy.UI.Fonts.specMediumCode }}
      else
        t.push {text: "Please join this iPad to the same WiFi network as the other devices and restart Trivially.", options: {textAlign: "center"}}
    else
      t.push {text: "(Note that this iPad currently isn\'t connected to WiFi)", options: {textAlign: "center", color: Hy.UI.Colors.MrF.Red}}

    t

  # ----------------------------------------------------------------------------------------------------------------
  sectionTitle: ()->
    [ {text: "Welcome to CrowdGame™ Trivially!", options: {font: Hy.UI.Fonts.specMediumMrF, textAlign: "center"}} ]

  # ----------------------------------------------------------------------------------------------------------------
  sectionDismiss: ()->
    [ {text:"\n\nTap the screen to begin the game", options: {textAlign: "center"}} ]

# ==================================================================================================================
class AboutPanel extends IntroPanel

  kWidth = 850
  kButtonMargin = 35
  kButtonSpacing = (kWidth - ( (4*UtilityPanel.kButtonContainerWidth) + (2*kButtonMargin)))/3

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (options, @fnClickDone, @fnClickRestore, @fnClickJoinHelp)->

    super options
  
    this

  # ----------------------------------------------------------------------------------------------------------------
  initialize: ()->

    super

    this.addLabelItem(this, this.sectionCopyright())
    this.addLabelItem(this, this.sectionVersionInfo())

    if @done?
      this.removeChild(@done)
    this.addChild(@done = this.addDoneButton())

    if @contact?
      this.removeChild(@contact)
    this.addChild(@contact = this.addContactButton())

    if @restore?
      this.removeChild(@restore)
    this.addChild(@restore = this.addRestoreButton())

    if @joinHelp?
      this.removeChild(@joinHelp)
    this.addChild(@joinHelp = this.addJoinHelpButton())

    this

  # ----------------------------------------------------------------------------------------------------------------
  viewOptions: ()->
    options = 
      top: 125
      height: 600
      width: kWidth
      zIndex: 150
      backgroundImage: Hy.UI.Backgrounds.pixelOverlay

    Hy.UI.ViewProxy.mergeOptions(super, options)

  # ----------------------------------------------------------------------------------------------------------------
  labelSections: ()->
    [this.sectionTitle(), this.sectionBody(), this.sectionRestore(), this.sectionContactUs(), this.sectionDismiss()]

  # ----------------------------------------------------------------------------------------------------------------
  labelViewOptions: ()->
    top: 0
    height: 465
    width: 850
    layout: 'vertical'
    zIndex: 102

  # ----------------------------------------------------------------------------------------------------------------
  sectionTitle: ()->
    [ {text: "Instructions", options: {font: Hy.UI.Fonts.specBigNormal, color: Hy.UI.Colors.MrF.DarkBlue, textAlign: "center"}} ]

  # ----------------------------------------------------------------------------------------------------------------
  sectionBody: ()->

    t = []

    t.push {text: "One person can play on this iPad directly, OR up to #{Hy.Config.kMaxRemotePlayers} players can compete", options: {textAlign: "center"}}
    t.push {text: "to answer questions displayed on this iPad. Tap \"Join Help\" for more info", options: {textAlign: "center"}}
    t.push {text: "", options: {textAlign: "center"}}
    t.push {text: "Scoring is time-based: answer correctly within 3 seconds for 3 points,", options: {textAlign: "center"}}
    t.push {text: "within 6 seconds for 2 points, otherwise for 1 point!", options: {textAlign: "center"}}

    t

  # ----------------------------------------------------------------------------------------------------------------
  sectionContactUs: ()->

    [ {text: "We'd love to hear from you!", options: {font: Hy.UI.Fonts.specBigNormal, color: Hy.UI.Colors.MrF.DarkBlue, textAlign: "center"}},
      {text: "Tap \"Contact Us\" to send feedback or questions or to join our mailing list,", options: {textAlign: "center"}},
      {text: "or visit crowdgame.com or call us at ??", options: {textAlign: "center"}} ]

  # ----------------------------------------------------------------------------------------------------------------
  sectionDismiss: ()->
    [ {text: "", options: {textAlign: "center"}}, {text: "Tap \"Back\" to continue the game", options: {textAlign: "center"}} ]

  # ----------------------------------------------------------------------------------------------------------------
  sectionRestore: ()->
    [ {text: "Tap \"Restore Purchases\" to add previous purchases to this device", options: {textAlign: "center"}} ]

  # ----------------------------------------------------------------------------------------------------------------
  sectionCopyright: ()->

    options = 
      bottom: 10
      top: null
      textAlign: "center"
      height: 'auto'
      color: Hy.UI.Colors.gray
      font: Hy.UI.Fonts.specTinyNormal

    [{text: Hy.Config.Version.copyright, options: options}]

  # ----------------------------------------------------------------------------------------------------------------
  sectionVersionInfo: ()->

    options = 
      bottom: 10
      right: 0
      top: null
#      textAlign: "center"
      height: 'auto'
      color: Hy.UI.Colors.gray
      font: Hy.UI.Fonts.specMinisculeNormal

    [{text: "v#{Hy.Config.Version.Console.kConsoleMajorVersion}.#{Hy.Config.Version.Console.kConsoleMinorVersion}.#{Hy.Config.Version.Console.kConsoleMinor2Version}", options: options}]

  # ----------------------------------------------------------------------------------------------------------------
  labelOptions: ()->

    options = 
      color: Hy.UI.Colors.white

    Hy.UI.ViewProxy.mergeOptions(super, options)

  # ----------------------------------------------------------------------------------------------------------------
  addDoneButton: ()->

    buttonOptions = 
      backgroundImage: "assets/icons/button-restart.png"

    this.addButton("done", ((e, v)=>@fnClickDone()), {left: kButtonMargin}, buttonOptions, [{text: "Back"}])

  # ----------------------------------------------------------------------------------------------------------------
  addRestoreButton: ()->

    buttonOptions = 
      backgroundImage: "assets/icons/circle-blue-large.png"
      title: "$"
      font: Hy.UI.Fonts.cloneFont(Hy.UI.Fonts.specBigNormal)

    left = kButtonMargin + UtilityPanel.kButtonContainerWidth + kButtonSpacing

    fn = (e, v)=>
      this.setButtonState("restore", false)
      @fnClickRestore()
      null

    this.addButton("restore", fn, {left: left}, buttonOptions, [{text: "Restore\nPurchases"}])

  # ----------------------------------------------------------------------------------------------------------------
  addContactButton: ()->

    buttonOptions = 
      backgroundImage: "assets/icons/button-contact-us.png"

    right = kButtonMargin + UtilityPanel.kButtonContainerWidth + kButtonSpacing

    fn = (e, v)=>
      this.launchURL(Hy.Config.Support.contactUs)
      this.setButtonState("contact", false)
      null

    this.addButton("contact", fn, {right: right}, buttonOptions, [{text: "Contact\nUs"}])

  # ----------------------------------------------------------------------------------------------------------------
  addJoinHelpButton: ()->

    buttonOptions = 
      backgroundImage: "assets/icons/circle-blue-large.png"
      title: "?"
      font: Hy.UI.Fonts.specBigNormal

    fn = (e, v)=>
      this.setButtonState("joinHelp", false)
      @fnClickJoinHelp()
      null

    this.addButton("joinHelp", fn, {right: kButtonMargin}, buttonOptions, [{text: "Join\nHelp"}])

# ==================================================================================================================
OptionPanels = 
  kButtonHeight:      53
  kButtonWidth:       53

  kPadding:            5

  kLabelWidth:       120

  kPanelHeight:       60

  kPanelWidthSmall:  120
  kPanelWidthLarge:  250

  # ----------------------------------------------------------------------------------------------------------------
  createSoundPanel: (page, options = {}, labelOptions = {}, choiceOptions = {})->

    defaultLabelOptions =
      width: 100
      text: "Sound"
      _attach: "left"
      _padding: OptionPanels.kPadding
      height: OptionPanels.kPanelHeight
      width: OptionPanels.kLabelWidth

    _buttons = [
      {_value: "on"}
      {_value: "off"}
    ]

    defaultChoiceOptions = 
      _style: "plain"
      _buttons: _buttons
      width: OptionPanels.kButtonWidth
      height: OptionPanels.kButtonHeight
      _appOption: Hy.Options.sound
      _state: "toggle"

    stackingOptions = 
      _horizontalLayout: "group"
      _verticalLayout: "center"
      _padding: OptionPanels.kPadding

    defaultOptions = 
      height: OptionPanels.kPanelHeight
      width:  OptionPanels.kLabelWidth + 250
      _tag: "Sound Toggle Options"

    new Hy.UI.OptionsList(Hy.UI.ViewProxy.mergeOptions(defaultOptions, options), Hy.UI.ViewProxy.mergeOptions(defaultLabelOptions, labelOptions), Hy.UI.ViewProxy.mergeOptions(defaultChoiceOptions, choiceOptions), stackingOptions)

  # ----------------------------------------------------------------------------------------------------------------
  createNumberOfQuestionsPanel: (page, options = {})->

    labelOptions =
      text: "Number Of Questions"
      _attach: "left"
      _padding: OptionPanels.kPadding
      height: OptionPanels.kPanelHeight
      width: OptionPanels.kLabelWidth

    _buttons = [
      {_value: 5},
      {_value: 10},
      {_value: 20},
      {_value: -1, _text: "ALL"}
    ]

    choiceOptions = 
      _style: "plain"
      _buttons: _buttons
      width: OptionPanels.kButtonWidth
      height: OptionPanels.kButtonHeight
      _appOption: Hy.Options.numQuestions
      _state: "toggle"

    stackingOptions = 
      _horizontalLayout: "group"
      _verticalLayout: "center"
      _padding: OptionPanels.kPadding

    defaultOptions = 
      height: OptionPanels.kPanelHeight
      width:  OptionPanels.kLabelWidth + 250 + 15 # Add room for caveat
#      borderColor: Hy.UI.Colors.green
#      borderWidth: 1

    panel = new Hy.UI.OptionsList(Hy.UI.ViewProxy.mergeOptions(defaultOptions, options), labelOptions, choiceOptions, stackingOptions)

    # Caveat re: #of questions
    caveatOptions = 
      text: "Max\n#{Hy.Config.Dynamics.maxNumQuestions}"
      right: 0
      top: 0
      height: OptionPanels.kButtonHeight
      font: Hy.UI.Fonts.mergeFonts(Hy.UI.Fonts.specTinyNormal, {fontSize: 14})
      textAlign: "center"
#      borderColor: Hy.UI.Colors.white
#      borderWidth: 1

    panel.addChild(new Hy.UI.LabelProxy(caveatOptions))

    panel

  # ----------------------------------------------------------------------------------------------------------------
  createSecondsPerQuestionPanel: (page, options = {})->

    labelOptions =
      _attach: "left"
      _padding: OptionPanels.kPadding
      text: "Time Per Question"
      height: OptionPanels.kPanelHeight
      width: OptionPanels.kLabelWidth

    # This is sub-optimal
    _buttons = [
      {_value: 10, _text: "10 seconds"}
      {_value: 15, _text: "15 seconds"}
      {_value: 20, _text: "20 seconds"}
      {_value: 30, _text: "30 seconds"}
      {_value: 45, _text: "45 seconds"}
      {_value: 60, _text: "1 minute"}
      {_value: 90, _text: "1 min 30 sec"}
      {_value: 120, _text: "2 minutes"}
      {_value: 150, _text: "2 min 30 sec"}
      {_value: 180, _text: "3 minutes"}
      {_value: 210, _text: "3 min 30 sec"}
      {_value: 240, _text: "4 minutes"}
      {_value: 270, _text: "4 min 30 sec"}
      {_value: 300, _text: "5 minutes"}
      {_value: 360, _text: "6 minutes"}
      {_value: 420, _text: "7 minutes"}
      {_value: 480, _text: "8 minutes"}
      {_value: 540, _text: "9 minutes"}
      {_value: 570, _text: "9 min 30 sec"}
    ]

    choiceOptions = 
      _style: "plain"
      _buttons: _buttons
      width: OptionPanels.kButtonWidth
      height: OptionPanels.kButtonHeight
      _appOption: Hy.Options.secondsPerQuestion

    stackingOptions = 
      _horizontalLayout: "group"
      _verticalLayout: "center"
      _padding: OptionPanels.kPadding

    defaultOptions = 
      height: OptionPanels.kPanelHeight
      width:  OptionPanels.kLabelWidth + 250
      _tag: "Seconds per Question Toggle Options"

    new Hy.UI.OptionsSelector(Hy.UI.ViewProxy.mergeOptions(defaultOptions, options), labelOptions, choiceOptions, stackingOptions)

  # ----------------------------------------------------------------------------------------------------------------
  createSecondsPerQuestionPanel2: (page, options = {})->

    labelOptions =
      _attach: "left"
      _padding: OptionPanels.kPadding
      text: "Seconds Per Question"
      height: OptionPanels.kPanelHeight
      width: OptionPanels.kLabelWidth

    _buttons = [
      {_value: 10}
      {_value: 15}
      {_value: 20}
      {_value: 30}
    ]

    choiceOptions = 
      _style: "plain"
      _buttons: _buttons
      width: OptionPanels.kButtonWidth
      height: OptionPanels.kButtonHeight
      _appOption: Hy.Options.secondsPerQuestion
      _state: "toggle"

    stackingOptions = 
      _horizontalLayout: "group"
      _verticalLayout: "center"
      _padding: OptionPanels.kPadding

    defaultOptions = 
      height: OptionPanels.kPanelHeight
      width:  OptionPanels.kLabelWidth + 250
      _tag: "Seconds per Question Toggle Options"

    new Hy.UI.OptionsList(Hy.UI.ViewProxy.mergeOptions(defaultOptions, options), labelOptions, choiceOptions, stackingOptions)

  # ----------------------------------------------------------------------------------------------------------------
  createFirstCorrectPanel: (page, options = {})->

    labelOptions =
      text: "First Correct Answer Wins"
      _attach: "left"
      _padding: OptionPanels.kPadding
      height: OptionPanels.kPanelHeight
      width: OptionPanels.kLabelWidth

    _buttons = [
      { _value: "yes"}
      { _value: "no"}
    ]

    choiceOptions = 
      _style: "plain"
      _buttons: _buttons
      width: OptionPanels.kButtonWidth
      height: OptionPanels.kButtonHeight
      _appOption: Hy.Options.firstCorrect
      _state: "toggle"

    stackingOptions = 
      _horizontalLayout: "group"
      _verticalLayout: "center"
      _padding: OptionPanels.kPadding

    defaultOptions = 
      height: OptionPanels.kPanelHeight
      width:  OptionPanels.kLabelWidth + 250
      _tag: "First Correct Toggle Options"

    new Hy.UI.OptionsList(Hy.UI.ViewProxy.mergeOptions(defaultOptions, options), labelOptions, choiceOptions, stackingOptions)

  # ----------------------------------------------------------------------------------------------------------------
  createUserCreatedContentInfoPanel2: (page, options = {})->

    labelOptions =
      text: "Custom Trivia Packs"
      _attach: "left"
      _padding: OptionPanels.kPadding
      height: OptionPanels.kPanelHeight
      width: OptionPanels.kLabelWidth
      color: Hy.UI.Colors.MrF.DarkBlue

    fnClick = (action)=>
      if page.isPageEnabled()
        page.getApp().userCreatedContentAction(action)
      null

    _buttons = [
      { _value: Hy.Config.Content.kThirdPartyContentNewText,  _fnCallback: (evt, view)=>fnClick("add")},
      { _value: Hy.Config.Content.kThirdPartyContentInfoText, _fnCallback: (evt, view)=>fnClick("info")},
      { _value: Hy.Config.Content.kThirdPartyContentBuyText,  _fnCallback: (evt, view)=>fnClick("upsell")}
    ]

    choiceOptions = 
      _style: "plain"
      _buttons: _buttons
      width: OptionPanels.kButtonWidth
      height: OptionPanels.kButtonHeight

    stackingOptions = 
      _horizontalLayout: "group"
      _verticalLayout: "center"
      _padding: OptionPanels.kPadding

    defaultOptions = 
      height: OptionPanels.kPanelHeight
      width:  OptionPanels.kLabelWidth + 250
      _tag: "createUserCreatedContentInfoPanel2"

    new Hy.UI.OptionsList(Hy.UI.ViewProxy.mergeOptions(defaultOptions, options), labelOptions, choiceOptions, stackingOptions)

# ==================================================================================================================
class ContentView extends Hy.UI.ViewProxy

  @kVerticalPadding =  3
  @kHorizontalPadding = 5

  @kSummaryHeight = @kNameHeightDefault = 60

  @kInfoArrowWidth = 32
  @kInfoArrowHeight = 40

  @kDifficultyWidth = @kIconWidth =  @kIconHeight = 33
  @kDifficultyHeight = 15

  @kBuyWidth = @kBuyHeight = @kSelectedHeight = @kSelectedWidth = @kResetWidth = @kResetHeight = 40

  @kPriceHeight = @kDescriptionHeight = @kUsageHeight = 30

  @kPriceWidth = @kUsageWidth = 70

  @kUCCDetailsHeight = 55
  @kUCCDetailsWidth = 150

  gInstances = []

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (options, @contentOptionsPanel, @contentPack)->

    gInstances.push this

    @buyButton = null
    @hasUsage = false
    @usage = null
    @usageInfoView = null

    @selectedIndicatorHandlerIndex = null
    @resetButtonHandlerIndex = null

    defaultOptions =
      borderColor:  @borderColor = Hy.UI.Colors.white
      borderWidth:  @borderWidth = 0

    super Hy.UI.ViewProxy.mergeOptions(defaultOptions, options)

    this.update()

    this

  # ----------------------------------------------------------------------------------------------------------------
  @getInstances: (contentPack = null)->

    if contentPack?
      _.select(gInstances, (v)=>v.getContentPack() is contentPack)
    else
      gInstances

  # ----------------------------------------------------------------------------------------------------------------
  # Call this when done with this view, so we can clean up event handlers, etc
  #
  done: ()->

    this.removeSelectedClickHandler()

    gInstances = _.without(gInstances, this)

    null

  # ----------------------------------------------------------------------------------------------------------------
  viewOptions: ()->

    options=
      left: 0
#      backgroundImage: Hy.UI.Backgrounds.pixelOverlay      
      borderRadius:16


  # ----------------------------------------------------------------------------------------------------------------            
  update: ()->

    this

  # ----------------------------------------------------------------------------------------------------------------
  finishUpdate: ()->

    if @usage?
      @hasUsage = true

    this.renderAsAppropriate()

  # ----------------------------------------------------------------------------------------------------------------
  renderAsAppropriate: ()->

    for contentView in ContentView.getInstances(this.getContentPack())
      contentView.renderAsAppropriate_()

  # ----------------------------------------------------------------------------------------------------------------
  renderAsAppropriate_: (readyToPlay = [], readyToBuy = [])->

    fnShow = (views)=> view?.show() for view in views
    fnHide = (views)=> view?.hide() for view in views

    if this.getContentPack().isReadyForPlay()

      fnShow(readyToPlay)
      fnHide(readyToBuy)

      @selectedIndicatorView?.setSelected(this.getContentPack().isSelected())
#      @selectedIndicatorView?.setEmphasisUI(this.getContentPack().isSelected())
#      this.setSelected(this.getContentPack().isSelected())

    else

      fnShow(readyToBuy)
      fnHide(readyToPlay)

    this

  # ----------------------------------------------------------------------------------------------------------------
  getContentPack: ()-> @contentPack

  # ----------------------------------------------------------------------------------------------------------------
  createIcon: (options = {})->

    iconView = null

    if (icon = this.getContentPack().getIcon())?

      defaultOptions = 
        height: ContentView.kIconHeight
        width: ContentView.kIconWidth
        image: icon.getPathname()
        borderColor: @borderColor
        borderWidth: @borderWidth

      iconView = new Hy.UI.ImageViewProxy(Hy.UI.ViewProxy.mergeOptions(defaultOptions, options))

    iconView

  # ----------------------------------------------------------------------------------------------------------------
  createDifficulty: (options = {}, longForm = false)->

    defaultOptions = 
      text: this.getContentPack().getDifficultyDisplay(longForm)
      font: Hy.UI.Fonts.specTinyCode
      color: Hy.UI.Colors.white
      textAlign: 'center'
      height: ContentView.kDifficultyHeight
      width: ContentView.kDifficultyWidth
      borderColor: @borderColor
      borderWidth: @borderWidth

    new Hy.UI.LabelProxy(Hy.UI.ViewProxy.mergeOptions(defaultOptions, options))

  # ----------------------------------------------------------------------------------------------------------------
  createName: (options = {})->

    font = if true #this.getContentPack().isThirdParty() 
      Hy.UI.Fonts.mergeFonts(Hy.UI.Fonts.specSmall, {fontSize: 20})
    else 
      Hy.UI.Fonts.mergeFonts(Hy.UI.Fonts.specSmallMrF, {fontSize: 21})

    defaultOptions = 
#      text: "12345678901234567890123456789012345678901234567890" #this.getContentPack().getDisplayName()
      text: this.getContentPack().getDisplayName()
      font: font
      color: if this.getContentPack().isThirdParty() then Hy.UI.Colors.white else Hy.UI.Colors.MrF.DarkBlue
#      textAlign: 'left'
      textAlign: 'center'
      height: ContentView.kNameHeightDefault
      borderColor: @borderColor
      borderWidth: @borderWidth

    new Hy.UI.LabelProxy(Hy.UI.ViewProxy.mergeOptions(defaultOptions, options))

  # ----------------------------------------------------------------------------------------------------------------
  createDescription: (options={})->

    # Ensure compatibility with pre-1.3 installations
    if not (description = this.getContentPack().getLongDescriptionDisplay())?
      description = this.getContentPack().getDescription()

#    description = "1234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345"

    defaultOptions = 
      text: description
      font: Hy.UI.Fonts.specTinyNormalNoBold
      color:Hy.UI.Colors.white
      textAlign:'left'
      height: ContentView.kDescriptionHeight
      borderColor: @borderColor
      borderWidth: @borderWidth

    new Hy.UI.LabelProxy(Hy.UI.ViewProxy.mergeOptions(defaultOptions, options))

  # ----------------------------------------------------------------------------------------------------------------
  getBuyButton: ()-> @buyButton

  # ----------------------------------------------------------------------------------------------------------------
  createBuy: (options = {})->

    kBuyButtonHeight = 40
    kBuyButtonWidth = 40

    buttonOptions = 
      title: "Buy"
      _tag: "Buy Button for #{this.getContentPack().getDisplayName()}"
      color: Hy.UI.Colors.MrF.Red
      height: kBuyButtonHeight
      width: kBuyButtonWidth
      backgroundImage: "assets/icons/circle-white.png"
#      _imageNotSelected: "assets/icons/circle-white.png"
#      _imageSelected: "assets/icons/circle-blue.png"
      font: Hy.UI.Fonts.specTinyMrF

    @buyButton = new Hy.UI.ButtonProxy(buttonOptions)

    fnBuy = (e, view)=>
      if @buyButtonClicked? # 2.5.0
        Hy.Trace.debug "ContentView::createBuy (ignoring - buy already in progress..)"
        null
      else
        @buyButtonClicked = true
        Hy.Trace.debug "ContentView::createBuy (preparing for \"doBuy\"...)"
        @contentOptionsPanel.doBuy(this.getContentPack(), "ContentList")
        @buyButtonClicked = null
      null

    @buyButton.addEventListener("click", fnBuy)

    containerOptions = 
      width: ContentView.kBuyWidth
      height: ContentView.kBuyHeight

    buyContainer = new Hy.UI.ViewProxy(Hy.UI.ViewProxy.mergeOptions(containerOptions, options))

    buyContainer.addChild(@buyButton)

    this.enableBuy()

    buyContainer

  # ----------------------------------------------------------------------------------------------------------------
  createPrice: (options= {})->

    kPriceLabelWidth = 70

#    if (price = "1234567")?

    if (price = this.getContentPack().getDisplayPrice())?
      priceOptions = 
        text: price
        font: Hy.UI.Fonts.specTinyCode
        color: Hy.UI.Colors.white
        textAlign:'center'
        height: ContentView.kPriceHeight
        width: kPriceLabelWidth
  
      priceLabel = new Hy.UI.LabelProxy(priceOptions)

      containerOptions = 
        height: ContentView.kPriceHeight
        width: ContentView.kPriceWidth
        borderColor: @borderColor
        borderWidth: @borderWidth

      priceContainer = new Hy.UI.ViewProxy(Hy.UI.ViewProxy.mergeOptions(containerOptions, options))
      priceContainer.addChild(priceLabel)

      priceContainer        

    else
      null
    
  # ----------------------------------------------------------------------------------------------------------------
  disableBuy: ()->

    @buy?.setEnabled(false)

  # ----------------------------------------------------------------------------------------------------------------
  enableBuy: ()->

    @buy?.setEnabled(true)

  # ----------------------------------------------------------------------------------------------------------------
  getInfoArrowButton: ()-> @infoArrowButton

  # ----------------------------------------------------------------------------------------------------------------
  createInfoArrow: (options = {})->

    buttonOptions = 
      backgroundImage: "assets/icons/arrow-right-blue.png"
      width: ContentView.kInfoArrowWidth,
      height: ContentView.kInfoArrowHeight
      _tag: "Info Arrow Button for #{this.getContentPack().getDisplayName()}"

    defaultContainerOptions = 
      _verticalLayout: "distribute"
      _tag: "Info Arrow Button Container for #{this.getContentPack().getDisplayName()}"
      borderColor: @borderColor
      borderWidth: @borderWidth
      width: ContentView.kInfoArrowWidth
      height: ContentView.kInfoArrowHeight

    container = new Hy.UI.ViewProxy(Hy.UI.ViewProxy.mergeOptions(defaultContainerOptions, options))
    container.addChild(@infoArrowButton = new Hy.UI.ButtonProxy(buttonOptions))

    fnClick = (e, v)=>
      if @infoArrowClicked?  # 2.5.0
        null
      else
        @infoArrowClicked = true
        @contentOptionsPanel.showContentOptions(this.getContentPack())
        @infoArrowClicked = null
      null

    @infoArrowButton.addEventListener("click", fnClick)

    container

  # ----------------------------------------------------------------------------------------------------------------
  createSelectedIndicator: (options = {})->

    kCheckImageWidth = kCheckImageHeight = 40
    buttonOptions = 
      _style: "check"
      width: kCheckImageWidth,
      height: kCheckImageHeight

    @selectedIndicatorView = new Hy.UI.ButtonProxyWithState(buttonOptions)

    containerOptions = 
      width: ContentView.kSelectedWidth
      height: ContentView.kSelectedHeight
      borderColor: @borderColor
      borderWidth: @borderWidth

    container = new Hy.UI.ViewProxy(Hy.UI.ViewProxy.mergeOptions(containerOptions, options))
    container.addChild(@selectedIndicatorView)

    this.addSelectedClickHandler()

    container

  # ----------------------------------------------------------------------------------------------------------------
  addSelectedClickHandler: ()->

    fnHandler = (e, view)=>
      this.toggleSelected()
      null

    this.removeSelectedClickHandler()

    if @selectedIndicatorView?
      @selectedIndicatorHandlerIndex = @selectedIndicatorView.addEventListener("click", fnHandler)
  
    this

  # ----------------------------------------------------------------------------------------------------------------
  removeSelectedClickHandler: ()->

    if @selectedIndicatorHandlerIndex?
      @selectedIndicatorView?.removeEventListenerByIndex(@selectedIndicatorHandlerIndex)
      @selectedIndicatorHandlerIndex = null

    this    

  # ----------------------------------------------------------------------------------------------------------------
  updateUsage: ()->

    if @hasUsage
      if @usage? and (u = this.getUsageText())?
        @usageLabel?.setUIProperty("text", u)
      else
        @fnCreateUsage?()
        @fnAddUsage?()

      this.renderAsAppropriate()

    this

  # ----------------------------------------------------------------------------------------------------------------
  getUsageText: ()->

    usage = if (u = @contentPack.getUsage())?
      u = Math.round(u*100)

      "#{u}%\nPlayed"
    else
      null

    usage
  # ----------------------------------------------------------------------------------------------------------------
  createUsage: (options= {})->

    kUsageLabelWidth = ContentView.kUsageWidth

    if (usage = this.getUsageText())

      usageOptions = 
        text: usage
        font: Hy.UI.Fonts.mergeFonts(Hy.UI.Fonts.specTinyCode, {fontSize:12})
        color: Hy.UI.Colors.white
        textAlign:'center'
        height: ContentView.kUsageHeight
        width: kUsageLabelWidth
  
      @usageLabel = new Hy.UI.LabelProxy(usageOptions)

      containerOptions = 
        height: ContentView.kUsageHeight
        width: ContentView.kUsageWidth
        borderColor: @borderColor
        borderWidth: @borderWidth

      usageContainer = new Hy.UI.ViewProxy(Hy.UI.ViewProxy.mergeOptions(containerOptions, options))
      usageContainer.addChild(@usageLabel)

      usageContainer        

    else
      null

  # ----------------------------------------------------------------------------------------------------------------
  createReset: (options= {})->

    kCheckImageWidth = kCheckImageHeight = 40
    buttonOptions = 
      _style: "plainOnDarkBackground"
      title: "Reset"
      width: kCheckImageWidth,
      height: kCheckImageHeight
      font: Hy.UI.Fonts.mergeFonts(Hy.UI.Fonts.specTinyCode, {fontSize:10})

    @resetButtonView = new Hy.UI.ButtonProxy(buttonOptions)

    containerOptions = 
      width: ContentView.kResetWidth
      height: ContentView.kResetHeight
      borderColor: @borderColor
      borderWidth: @borderWidth

    container = new Hy.UI.ViewProxy(Hy.UI.ViewProxy.mergeOptions(containerOptions, options))
    container.addChild(@resetButtonView)

    this.addResetClickHandler()

    container

  # ----------------------------------------------------------------------------------------------------------------
  addResetClickHandler: ()->

    fnHandler = (e, view)=>
      this.getContentPack().resetUsage()
      this.updateUsage()
      null

    this.removeResetClickHandler()

    if @resetButtonView?
      @resetButtonHandlerIndex = @resetButtonView.addEventListener("click", fnHandler)
  
    this

  # ----------------------------------------------------------------------------------------------------------------
  removeResetClickHandler: ()->

    if @resetButtonHandlerIndex?
      @resetButtonView?.removeEventListenerByIndex(@resetButtonHandlerIndex)
      @resetButtonHandlerIndex = null

    this    


  # ----------------------------------------------------------------------------------------------------------------
#  setEmphasisUI: (emphasis)->

#    @selectedIndicatorView?.setEmphasisUI(emphasis)

#    this
  
  # ----------------------------------------------------------------------------------------------------------------
  # Toggle selected state and update all contentViews
  #
  toggleSelected: ()->

    if (contentPack = this.getContentPack()).isReadyForPlay()

      contentPack.toggleSelected()

      this.renderAsAppropriate()

    this

  # ----------------------------------------------------------------------------------------------------------------
  createUCCDetails: (containerOptions = {}, labelOptions = {})->

    container = null
    defaultLabelHeight = 15

    if (contentPack = this.getContentPack()).isThirdParty()

      defaultContainerOptions = 
        height: ContentView.kUCCDetailsHeight
        width: ContentView.kUCCDetailsWidth
        borderColor: @borderColor
        borderWidth: @borderWidth
        _verticalLayout: "distribute"
        _margin: 0

      container = new Hy.UI.ViewProxy(Hy.UI.ViewProxy.mergeOptions(defaultContainerOptions, containerOptions))

      font = Hy.UI.Fonts.mergeFonts(Hy.UI.Fonts.specTinyNormalNoBold, {fontSize: 11})
      defaultLabelOptions = 
        font: font
        color: Hy.UI.Colors.white
        textAlign:'center'
        left: 0
        height: defaultLabelHeight
        width: ContentView.kUCCDetailsWidth
        borderColor: @borderColor
        borderWidth: @borderWidth

      labelsOptions = []
      labelsOptions.push {text: "Custom Trivia Pack"}
      labelsOptions.push {text: "# of Questions: #{contentPack.getNumRecords()}"}

      if (t = contentPack.getAuthorVersionInfo())?
        labelsOptions.push {text: "Version: #{t}"}

      for options in labelsOptions
        container.addChild(c = new Hy.UI.LabelProxy(Hy.UI.ViewProxy.mergeOptions(defaultLabelOptions, labelOptions, options)))

    container

# ==================================================================================================================
# 
class ContentViewSummary extends ContentView

  # ----------------------------------------------------------------------------------------------------------------
  @getHeight: ()->

    ContentView.kVerticalPadding + ContentView.kSummaryHeight + ContentView.kVerticalPadding

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (options, contentOptionsView, contentPack)->

    defaultOptions = 
      _tag: "ContentViewSummary #{contentPack.getDisplayName()}"
      height: ContentViewSummary.getHeight()

    super Hy.UI.ViewProxy.mergeOptions(defaultOptions, options), contentOptionsView, contentPack

    this

  # ----------------------------------------------------------------------------------------------------------------
  update: ()->

    super

    this.removeChildren()

    vOptions = 
      top: 0
      left: ContentView.kHorizontalPadding
      height: ContentViewSummary.getHeight()
      width: Math.max(ContentView.kIconWidth, ContentView.kDifficultyWidth)
      borderColor: Hy.UI.Colors.white
      borderWidth: @borderWidth
      _verticalLayout: "distribute"

    this.addChild(v1 = new Hy.UI.ViewProxy(vOptions))
    v1?.addChild(@icon = this.createIcon({left: 0}))
    v1?.addChild(@difficulty = this.createDifficulty({left: 0}))

    this.addChild((arrow = this.createInfoArrow({right: ContentView.kHorizontalPadding})), false, {_verticalLayout: "distribute"})

    buyOrSelectOptions = 
      right: ContentView.kHorizontalPadding + arrow.getUIProperty("width") + ContentView.kHorizontalPadding

    @selectedIndicator = this.createSelectedIndicator(buyOrSelectOptions)
    @buy = this.createBuy(buyOrSelectOptions)

    this.addChild(@selectedIndicator, false, {_verticalLayout: "distribute"})
    this.addChild(@buy, false, {_verticalLayout: "distribute"})
    h = Math.max(@selectedIndicator.getUIProperty("height"), @buy.getUIProperty("height"))

    nameOptions = 
     left: ContentView.kHorizontalPadding + v1.getUIProperty("width") + ContentView.kHorizontalPadding
     right: ContentView.kHorizontalPadding + arrow.getUIProperty("width") + ContentView.kHorizontalPadding + h + ContentView.kHorizontalPadding

    this.addChild((@name = this.createName(nameOptions)), false, {_verticalLayout: "distribute"})

    this.finishUpdate()

    this

  # ----------------------------------------------------------------------------------------------------------------
  renderAsAppropriate_: ()->

    readyToPlay    = [@selectedIndicator]
    readyToBuy     = [@buy]

    super(readyToPlay, readyToBuy)

    this

# ==================================================================================================================
# 
class ContentViewDetailed extends ContentView

  # ----------------------------------------------------------------------------------------------------------------
  @getHeight: ()->

    200

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (options, contentOptionsView, contentPack)->

    defaultOptions = 
      _tag: "ContentViewDetailed #{contentPack.getDisplayName()}"
      width: contentOptionsView.getNavGroup().getButtonWidth() # Relies on navGroup already existing, obviously
      height: ContentViewDetailed.getHeight()

    super Hy.UI.ViewProxy.mergeOptions(defaultOptions, options), contentOptionsView, contentPack

    this

  # ----------------------------------------------------------------------------------------------------------------
  update: ()->

    super

    this.removeChildren()

    c = []

    spacing = 3
    margin = 5
    containerHeight = this.getUIProperty("height")
    containerWidth = this.getUIProperty("width")

    top = margin

    rowZeroHeight = 50
    rowTwoHeight = ContentView.kUCCDetailsHeight
    rowOneHeight = ContentViewDetailed.getHeight() - (rowZeroHeight + rowTwoHeight + (2 * spacing) + (2 * margin))

    # Row 0: "name" centered across entire width
    nameOptions = 
      top: top
      height: rowZeroHeight
      width: containerWidth - (2 * margin)
      left: margin
      font: Hy.UI.Fonts.mergeFonts(Hy.UI.Fonts.specSmall, {fontSize: 19})
      textAlign: 'center'
    c.push @name = this.createName(nameOptions)
    top += rowZeroHeight + spacing

    # Row 1: "description", full-width
    font = Hy.UI.Fonts.cloneFont(Hy.UI.Fonts.specTinyNormal)
    font.fontSize = 15

    descriptionInnerMargin = 5
    descriptionOptions = 
      top: top
      right: margin
      left: margin
      height: rowOneHeight
      font: font
    c.push @description = this.createDescription(descriptionOptions)
    top += rowOneHeight + spacing

    # Row 2: 
    # Icon/Difficulty vertically stacked, horizontally centered across entire width.
    # "uccDetails" hugging the left.
    # "selected" hugging the right
    # "usageinfo" between Icon/Difficulty and "selected"
    #
    rowTwoOptions = 
      top: top
      width: containerWidth
      height: rowTwoHeight
      _verticalLayout: "center"
    c.push rowTwoView = new Hy.UI.ViewProxy(rowTwoOptions)
    top += rowTwoHeight + spacing

    # Starting on the right, add "selected"
    rowTwoView.addChild(@selectedIndicator = this.createSelectedIndicator({right: margin}))

    # In the middle: a stack o' icon and difficulty
    iconDifficultyStackOptions = 
      top: 0
      width: Math.max(ContentView.kIconHeight, ContentView.kDifficultyHeight)
      height: rowTwoHeight
      _verticalLayout: "distribute"
    iconDifficultyStackView = new Hy.UI.ViewProxy(iconDifficultyStackOptions)

    iconDifficultyStackView.addChild(@icon = this.createIcon())
    iconDifficultyStackView.addChild(@difficulty = this.createDifficulty())
    rowTwoView.addChild(iconDifficultyStackView, false, {_horizontalLayout: "center"})

    @usageInfoView = null
    @fnCreateUsage = ()=>this.createUsage({right: spacing})
    @fnAddUsage = ()->if @usage? then @usageInfoView?.addChild(@usage) else null

    # Then add usage info, between it and the "selected" button
    if this.getContentPack().isEntitled() and (@usage = @fnCreateUsage())?

      reset = this.createReset({left: spacing})

      width = @usage.getUIProperty("width") + reset.getUIProperty("width") + (3*spacing)

      r_selectedIndicator = @selectedIndicator.getUIProperty("right")
      w_selectedIndicator = @selectedIndicator.getUIProperty("width")
      right = (((iconDifficultyStackView.getUIProperty("right") - (r_selectedIndicator + w_selectedIndicator)) - width)/2) + r_selectedIndicator + w_selectedIndicator

      usageInfoOptions = 
        top: 0
        height: rowTwoHeight
        right: right
        width: width
        borderColor: @borderColor
        borderWidth: @borderWidth

      rowTwoView.addChild(@usageInfoView = new Hy.UI.ViewProxy(usageInfoOptions))

      @fnAddUsage()
      @usageInfoView.addChild(reset)

    # Finish with "uccInfo", on the far left
    if @contentPack.isThirdParty()
      font2 = Hy.UI.Fonts.mergeFonts(Hy.UI.Fonts.specTinyNormal, {fontSize: 14})

      rowTwoView.addChild(@uccDetails = this.createUCCDetails({left: margin}, {font: font2}))

    this.addChildren(c)

    this.finishUpdate()

    this

  # ----------------------------------------------------------------------------------------------------------------
  update2: ()->

    super

    this.removeChildren()

    c = []

    spacing = 3
    margin = 5
    containerHeight = this.getUIProperty("height")
    containerWidth = this.getUIProperty("width")

    top = margin

    rowZeroHeight = 50
    rowTwoHeight = ContentView.kUCCDetailsHeight
    rowOneHeight = ContentViewDetailed.getHeight() - (rowZeroHeight + rowTwoHeight + (2 * spacing) + (2 * margin))

    # Row 0: "icon"/"difficulty" stacked in a column on the left, and "name" on the right
    rowZeroLeftColumnOptions = 
      top: top
      left: margin
      width: rowZeroLeftColumnWidth = Math.max(ContentView.kIconHeight, ContentView.kDifficultyHeight)
      height: rowZeroHeight
      _verticalLayout: "distribute"
    c.push rowZeroLeftColumnView = new Hy.UI.ViewProxy(rowZeroLeftColumnOptions)

    rowZeroLeftColumnView.addChild(@icon = this.createIcon())
    rowZeroLeftColumnView.addChild(@difficulty = this.createDifficulty())

    nameOptions = 
      top: top
      height: rowZeroHeight
      width: nameWidth = containerWidth - (rowZeroLeftColumnWidth + (2 * margin) + spacing)
      right: margin
      font: Hy.UI.Fonts.mergeFonts(Hy.UI.Fonts.specSmall, {fontSize: 19})
      textAlign: 'center'
    c.push @name = this.createName(nameOptions)
    top += rowZeroHeight + spacing

    # Row 1: "description", full-width
    font = Hy.UI.Fonts.cloneFont(Hy.UI.Fonts.specTinyNormal)
    font.fontSize = 15

    descriptionInnerMargin = 5
    descriptionOptions = 
      top: top
      right: margin
      left: margin
      height: rowOneHeight
      font: font
    c.push @description = this.createDescription(descriptionOptions)
    top += rowOneHeight + spacing

    # Row 2: "usage", "uccDetails", and "selected", vertical centers aligned.
    # "usage" and "selected" hug the sides, "uccDetails" is centered horizontally
    rowTwoOptions = 
      top: top
      width: containerWidth
      height: rowTwoHeight
      _verticalLayout: "center"
    c.push rowTwoView = new Hy.UI.ViewProxy(rowTwoOptions)
    top += rowTwoHeight + spacing

    rowTwoView.addChild(@selectedIndicator = this.createSelectedIndicator({right: margin}))

    if this.getContentPack().isEntitled()
      if (@usage = this.createUsage({left: margin}))?
        rowTwoView.addChild(@usage)

    if @contentPack.isThirdParty()
      font2 = Hy.UI.Fonts.mergeFonts(Hy.UI.Fonts.specTinyNormal, {fontSize: 14})

      rowTwoView.addChild(@uccDetails = this.createUCCDetails({}, {font: font2}), false, {_horizontalLayout: "center"})

    this.addChildren(c)

    this.finishUpdate()

    this

  # ----------------------------------------------------------------------------------------------------------------
  renderAsAppropriate_: ()->

    readyToPlay    = [@selectedIndicator]
    readyToBuy     = []

    super(readyToPlay, readyToBuy)

    this

# ==================================================================================================================
# 
class ContentPackList extends Hy.UI.ScrollOptions

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (@contentOptionsPanel, @page, options={}, labelOptions = {}, scrollOptions = {}, childViewOptions = {}, arrowsOptions)->

    defaultOptions = 
      _tag: "Content Options"
#      borderColor: Hy.UI.Colors.yellow
#      borderWidth: 1

    defaultScrollOptions = 
      _padding: 3
      _orientation: "vertical"
      _rowHeight: this.getContentViewHeight()
      _dividerImage: "assets/icons/topic-divider.png"
      _dividerImageThickness: 10
      _fnViews: ()=>this.getContentViews()

    combinedScrollOptions = Hy.UI.ViewProxy.mergeOptions(defaultScrollOptions, scrollOptions)

    # We handle various events here: buy, more info, and select
    # UPDATE: not any more... moved to handlers on the individual buttons

    fnTouchAndHold = (e, view)=>
      this.doTouchAndHold(e, view)

    fnClicked = (e, view)=>
      if view?
        if e.source?
          contentPack = view.contentPack

          fn = switch e.source
            when view.getBuyButton()?.getView()
              if contentPack?
                ()=>@contentOptionsPanel.doBuy(contentPack, "ContentList")
            when view.getInfoArrowButton()?.getView()
              if contentPack?
                ()=>@contentOptionsPanel.showContentOptions(contentPack)
              else
                null
            else
              view.toggleSelected()
              null

          if fn?
            Hy.Utils.Deferral.create(0, fn)

    super Hy.UI.ViewProxy.mergeOptions(defaultOptions, options), labelOptions, combinedScrollOptions, childViewOptions, arrowsOptions, null, null

    this

  # ----------------------------------------------------------------------------------------------------------------
  mapToGlobalCoords: (eventPoint, view)->

    windowView = @page.getWindow().getView()
    scrollView = this.getScrollView().getView()
    viewHeight = view.getUIProperty("height")

    # Regardless of where within the ContentView the user touched, we remap it to the extreme left, and halfway down,
    # the ContentView
    #
    newPoint = if eventPoint.y? and (c1 = view.getView().convertPointToView({x: 0, y: viewHeight/2}, scrollView))? and (c2 = scrollView.convertPointToView(c1, windowView))?
      c2
    else
      x: 0
      y: 0

    fnDumpPoint = (point)=> "(#{point.x},#{point.y})"

#    Hy.Trace.debug "ContentPackList::mapToGlobalCoords (view: #{fnDumpPoint({x: evt.x, y: evt.y})} scrollView: #{fnDumpPoint(c1)} windowView: #{fnDumpPoint(c2)})"

    newPoint

  # ----------------------------------------------------------------------------------------------------------------
  doTouchAndHold: (evt, view)->

    if (contentPack = view.contentPack)? and contentPack.isThirdParty() # HACK UNTIL WE ADD A DEDICATED UI ELEMENT
      @contentOptionsPanel.showContentOptions(contentPack)

    return this

    if (coord = this.mapToGlobalCoords({x: evt.x, y: evt.y}, view))? and (contentPack = view.contentPack)? and contentPack.isThirdParty()
      @page.getApp().userCreatedContentAction("selected", {contentPack: contentPack, coord: coord})

    this

  # ----------------------------------------------------------------------------------------------------------------
  reInitViews: (autoScroll = true)->

    super autoScroll

    if autoScroll
      this.scrollToSelectedContentPack()

    this    

  # ----------------------------------------------------------------------------------------------------------------
  viewOptions: ()->

    {}

  # ----------------------------------------------------------------------------------------------------------------
  # We want to group all topics in a category together. We use the "icon" property as a proxy for "category".
  # Within a category, we sort by productId or by the "sort" property, if present.
  # We show custom content first.
  #
  getContentPacks: ()->

    result = []

    contentPacks = Hy.Content.ContentManager.get().getLatestContentPacksOKToDisplay()

    thirdPartyContentPacks = _.select(contentPacks, (c)=>c.isThirdParty())
    thirdPartyContentPacks = _.sortBy(thirdPartyContentPacks, (c)=>c.getDisplayName())
    result = result.concat(thirdPartyContentPacks)

    otherContentPacks = _.select(contentPacks, (c)=>not c.isThirdParty()) # 2.5.0
    otherContentPacks = _.sortBy(otherContentPacks, (c)=>c.getIconSpec())

    groupSpecs = []
    for c in otherContentPacks
      if not (groupSpec = _.detect(groupSpecs, (g)=>g.iconSpec is c.getIconSpec()))?
        groupSpecs.push (groupSpec = {iconSpec: c.getIconSpec(), contentPacks: []})
      groupSpec.contentPacks.push c

    for groupSpec in groupSpecs

      # Use of "sort" field is all or nothing... all packs must have a sort spec, otherwise ignore
      hasSort = not _.detect(groupSpec.contentPacks, (c)=>c.getSort() is -1)?

      for c in _.sortBy(groupSpec.contentPacks, (c)=>if hasSort then c.getSort() else c.getProductID()) # 2.5.0
        if c.isOKToDisplay()
          result.push c

    result

  # ----------------------------------------------------------------------------------------------------------------
  getContentViews: ()->

    contentViews = []

    for c in this.getContentPacks()
      if not this.findContentViewByContentPack(c)?
        contentViews.push new ContentViewSummary({}, @contentOptionsPanel, c)

    contentViews

  # ----------------------------------------------------------------------------------------------------------------
  getContentViewHeight: ()->

    ContentViewSummary.getHeight()

  # ----------------------------------------------------------------------------------------------------------------
  findContentViewByContentPack: (contentPack)->

    this.findViewByProperty("contentPack", contentPack)

  # ----------------------------------------------------------------------------------------------------------------
  scrollToSelectedContentPack: ()->

    index = -1
    for contentPack in this.getContentPacks()
      index++
      if contentPack.isSelected()
        this.makeViewVisible(index)
        return

    this

  # ----------------------------------------------------------------------------------------------------------------
  start: ()->

    this.scrollToSelectedContentPack()

    this

  # ----------------------------------------------------------------------------------------------------------------
  stop: ()->

    this

  # ----------------------------------------------------------------------------------------------------------------
  open: ()->

    this

  # ----------------------------------------------------------------------------------------------------------------
  close: ()->

#    this.clearEventHandler() # 2.5.0 Where is this defined?

    this

  # ----------------------------------------------------------------------------------------------------------------
  initialize: ()->
    super

    # Update the %used info for each content pack
    this.applyToViews("updateUsage")

    this

  # ----------------------------------------------------------------------------------------------------------------
  pause: ()->
    super
    this

  # ----------------------------------------------------------------------------------------------------------------
  resumed: ()->
    super
    this

# ==================================================================================================================
#
class ContentOptionsPanel extends Panel

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (@page, options)->

    @zIndex = 110

    @contentPackDetails = null # Set if we've generated a detail page for a content pack

    containerWidth = 440
    containerHeight = 400
    containerPadding = 5

    paddingHeight = 10 #20
    paddingWidth = 15

    arrowPadding = 50    

    @navViewWidth = containerWidth - (2*paddingWidth)
    @navViewHeight = containerHeight - (2*paddingHeight)

    defaultOptions = 
      height: containerHeight + (2*arrowPadding)
      width: containerWidth + (2*containerPadding)
      _tag: "ContentOptionsPanel"
#      borderColor: Hy.UI.Colors.green
#      borderWidth: 1
      zIndex: @zIndex

    super Hy.UI.ViewProxy.mergeOptions(defaultOptions, options)

    this.addBackgroundImage({top: arrowPadding, left: containerPadding, width: containerWidth, height: containerHeight})

    arrowsOptions = 
      _parent: this
      left: paddingWidth + containerPadding
      top: 0
      bottom: 0

    @contentPackList = this.createContentPackList({width: @navViewWidth, height: @navViewHeight}, 
                                                  {width: @navViewWidth, height: @navViewHeight}, arrowsOptions)

    @navGroup = null
    @navGroupStarted = false
    navGroupOptions = 
      top: arrowPadding + paddingHeight
#      left: paddingWidth + containerPadding
      right: paddingWidth + containerPadding # 2.5.0
      width: @navViewWidth
      height: @navViewHeight

    this.addNavGroup(navGroupOptions, {_root: true, _id: "ContentList", _backButton: "_none", _view: @contentPackList})

    this

  # ----------------------------------------------------------------------------------------------------------------
  addBackgroundImage: (options)->

    backgroundImageOptions = 
      backgroundImage: "assets/icons/topics-background.png"
      zIndex: @zIndex

    this.addChild(new Hy.UI.ImageViewProxy(Hy.UI.ViewProxy.mergeOptions(backgroundImageOptions, options)))

    this
  
  # ----------------------------------------------------------------------------------------------------------------
  createContentPackList: (options, scrollOptions, arrowsOptions)->

    labelOptions = {}
    childViewOptions = {}

    defaultOptions =
      backgroundColor: Hy.UI.Colors.black

    combinedOptions = Hy.UI.ViewProxy.mergeOptions(defaultOptions, options)

    defaultScrollOptions = 
#      borderColor: Hy.UI.Colors.white
      borderWidth: 1

    combinedScrollOptions = Hy.UI.ViewProxy.mergeOptions(defaultScrollOptions, scrollOptions)

    new Hy.Panels.ContentPackList(this, @page, combinedOptions, labelOptions, combinedScrollOptions, childViewOptions, arrowsOptions)

  # ----------------------------------------------------------------------------------------------------------------
  update: ()->

    @contentPackList.reInitViews()
    this.updateContentOptions()

    this
  # ----------------------------------------------------------------------------------------------------------------
  getNavGroup: ()-> @navGroup

  # ----------------------------------------------------------------------------------------------------------------
  addNavGroup: (options, navSpec)->

    defaultNavGroupOptions = 
#      borderColor: Hy.UI.Colors.red
      borderWidth: 1
      _colorScheme: "black"

    mergedOptions = Hy.UI.ViewProxy.mergeOptions(defaultNavGroupOptions, options)
    mergedOptions.top += this.getUIProperty("top")
    mergedOptions.right += this.getUIProperty("right")

    # 2.5.0: Titanium 3.1.3 deprecates iPhone.NavigationGroup... 
    # The replacement, iOS.NavigationWindow, is a top-level window
#    this.addChild(@navGroup = new Hy.UI.NavGroup(Hy.UI.ViewProxy.mergeOptions(defaultNavGroupOptions, options), navSpec)) 

    @navGroup = new Hy.UI.NavGroup(mergedOptions, navSpec)

    this

  # ----------------------------------------------------------------------------------------------------------------
  animate: (options)->

    @navGroup.animate(options)
    super options
    this

  # ----------------------------------------------------------------------------------------------------------------
  start: ()->

    super

    Hy.Content.ContentManager.addObserver this
    Hy.Content.ContentManagerActivity.addObserver this

    if @navGroupStarted # 2.5.0
      if not @hackUpdate?
        @contentPackList.animate({opacity: 1, duration: 200})
        @hackUpdate = true
    else
      @navGroup.start()
      @navGroupStarted = true

    @contentPackList.start()

    this

  # ----------------------------------------------------------------------------------------------------------------
  stop: ()->

    Hy.Content.ContentManager.removeObserver this
    Hy.Content.ContentManagerActivity.removeObserver this

#    @contentPackList.stop() # 2.5.0 Function doesn't do anything

    this.getNavGroup().dismiss(true, "_root")

    super

    this

  # ----------------------------------------------------------------------------------------------------------------
  open: ()->

    @navGroup.open() # 2.5.0
    @contentPackList.open()

    this

  # ----------------------------------------------------------------------------------------------------------------
  close: (options)-> # 2.5.0 added options

#    @contentPackList.close(options) # 2.5.0 Function doesn't do anything
    @navGroup.close(options)

    this

  # ----------------------------------------------------------------------------------------------------------------
  initialize: ()->

    super

    @contentPackList.initialize()

    this

  # ----------------------------------------------------------------------------------------------------------------
  pause: ()->

    @contentPackList.pause()

    super

    this

  # ----------------------------------------------------------------------------------------------------------------
  resumed: ()->
    super

    @contentPackList.resumed()

    this

  # ----------------------------------------------------------------------------------------------------------------
  # Note that contentPacks may have been updated, so we may be holding on to old versions...
  #
  obs_contentUpdateSessionCompleted: (report, changes)->

    if changes
      @contentPackList.reInitViews()
      this.updateContentOptions()

    null

  # ----------------------------------------------------------------------------------------------------------------
  obs_inventoryCompleted: (status, message)->

    if status
      @contentPackList.reInitViews()
      this.updateContentOptions()

    null

  # ----------------------------------------------------------------------------------------------------------------
  obs_purchaseInitiated: (label, report)->

#    @contentPackList.applyToViews("disableBuy")

  # ----------------------------------------------------------------------------------------------------------------
  obs_purchaseCompleted: (report)->

    @contentPackList.applyToViews("enableBuy")
    this.updateContentOptions()    

    null

  # ----------------------------------------------------------------------------------------------------------------
  obs_restoreInitiated: (report)->

    @contentPackList.applyToViews("disableBuy")

    null

  # ----------------------------------------------------------------------------------------------------------------
  obs_restoreCompleted: (report, changes = false)->

    Hy.Trace.debug "ContentOptionsPanel::obs_restoreCompleted (report=#{report}, changes=#{changes})"

    @contentPackList.applyToViews("enableBuy")

    if changes
      @contentPackList.reInitViews()
      this.updateContentOptions()

    null

  # ----------------------------------------------------------------------------------------------------------------
  obs_userCreatedContentSessionCompleted: (report = null, changes = false)->

    if changes
      @contentPackList.reInitViews(true) # Was "false" - why?
      this.updateContentOptions()

    null

  # --------------------------------------------------------------------------------------------------------------
  contentOptionsNavSpec: (contentPack)->

    fnMakeContext = (fnDone)=>
      context = 
        contentPack: contentPack
        navGroup: this.getNavGroup()
        fnDone: fnDone
        _dismiss: "ContentOptions"
      context

    fnUserCreatedContentAction = (action, fnDone)=>
      @page.getApp().userCreatedContentAction(action, fnMakeContext(fnDone))
      null

    fnDone = (context, status, navSpec, changes, target)=>
      if navSpec?
        navSpec._backButton = target
        context.navGroup.pushNavSpec(navSpec)   
      null

    fnDone1 = (context, status, navSpec, changes)=>
      fnDone(context, status, navSpec, changes, "ContentOptions")

    fnDone2 = (context, status, navSpec, changes)=>
      fnDone(context, status, navSpec, changes, "ContentList")

    fnBuy = (fnDone)=>
      if @buyButtonClicked? # 2.5.0
        Hy.Trace.debug "ContentOptionsPanel::contentOptionsNavSpec (ignoring - buy already in progress..)"
        null
      else
        @buyButtonClicked = true
        Hy.Trace.debug "ContentOptionsPanel::contentOptionsNavSpec (preparing for \"doBuy\"...)"
        this.doBuy(contentPack, "ContentOptions")
        @buyButtonClicked = null
      null

    buttonSpecs = if contentPack.isThirdParty()
      [
        {_value: "remove this Trivia Pack", _destructive: true, _navSpec: 
          _title: "" #contentPack.getDisplayName() 
          _backButton: "_previous"
          _explain: "#{contentPack.getDisplayName()}\n\nAre you sure you want to remove this Trivia Pack?"
          _buttonSpecs: [
            {_value: "yes, remove it", _destructive: true, _navSpecFnCallback: (event, view, navGroup)=>fnUserCreatedContentAction("delete", fnDone2)}
            {_value: "cancel", _dismiss: "_previous", _cancel: true}
          ]
        },
        {_value: "check for update", _navSpecFnCallback: (event, view, navGroup)=>fnUserCreatedContentAction("refresh", fnDone1)}
      ]
    else if contentPack.showPurchaseOption()
      price = contentPack.getDisplayPrice() # May not have been inventoried yet. Stall.
      [
        {_value: "buy this Trivia Pack#{if price? then " for " + price else ""}", _navSpecFnCallback: (event, view, navGroup)=>fnBuy(fnDone1)}
      ]     
    else
      null

    contentInfoOptions = 
      borderColor: Hy.UI.Colors.MrF.Gray
      borderWidth: 1
      top: 5 # 0 # 2.5.0

    navSpec = 
      _id: "ContentOptions"
      _backButton: "ContentList"
      _title: "" #"1234567890123456789012345678901234567890" #contentPack.getDisplayName() # 2.5.0
      _view: (@contentPackDetails = new ContentViewDetailed(contentInfoOptions, this, contentPack))
      _buttonSpecs: buttonSpecs
      _verticalLayout: "manual"

    navSpec

  # ----------------------------------------------------------------------------------------------------------------
  showContentOptions: (contentPack)->

    @contentPackList.setArrowsEnabled(false)

    this.getNavGroup().pushFnGuard(this,"viewDismiss", ()=>@contentPackList.setArrowsEnabled(true))
    this.getNavGroup().pushFnGuard(this,"viewDismiss", ()=>this.clearContentPackDetails())
    this.getNavGroup().pushNavSpec(this.contentOptionsNavSpec(contentPack))

    null

  # ----------------------------------------------------------------------------------------------------------------
  clearContentPackDetails: ()->

    @contentPackDetails?.done() # Removes event handler, etc
    @contentPackDetails = null

  # ----------------------------------------------------------------------------------------------------------------
  updateContentOptions: ()->

    if @contentPackDetails?

      contentPack = @contentPackDetails.getContentPack()

      this.clearContentPackDetails()

      # Make sure we have the latest version of the content pack in hand
      if (contentPack = Hy.Content.ContentPack.findLatestVersionOKToDisplay(contentPack.getProductID()))
        this.getNavGroup().replaceNavView(this.contentOptionsNavSpec(contentPack))

    null

  # ----------------------------------------------------------------------------------------------------------------
  doBuy: (contentPack, returnTarget)->

    contentView = @contentPackList.findContentViewByContentPack(contentPack)

    fnDoneBuy = (context, status, navSpec, changes)=>
      if navSpec?
        navSpec._backButton = returnTarget
        context.navGroup.pushNavSpec(navSpec)   

      contentView.enableBuy()
      contentView.renderAsAppropriate()

      if status
        contentView.toggleSelected()

      null

    contentView.disableBuy()

    @contentPackList.setArrowsEnabled(false)
    this.getNavGroup().pushFnGuard(this,"viewDismiss", ()=>@contentPackList.setArrowsEnabled(true))

    context = 
      contentPack: contentPack
      navGroup: this.getNavGroup()
      fnDone: fnDoneBuy

    status = Hy.Content.ContentManager.get().buyContentPack(context)
   
    status

# ==================================================================================================================
class WebViewPanel extends Panel

  gEventHandler = false
  gListeners = []
  gEventCount = 0
  gOutstandingEvents = []

  gWebView = null

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (options, @htmlOptions)->

    defaultOptions = 
#      borderColor: Hy.UI.Colors.green
#      borderWidth: 10

    super Hy.UI.ViewProxy.mergeOptions(defaultOptions, options)

    @webView = null
    @webViewLoaded = false
    @webViewInitialized = false
    @fnInitialized = null

    this.show()

    this

  # ----------------------------------------------------------------------------------------------------------------
  webViewCreate: ()->

    @webView = null
    @webViewLoaded = false
    @webViewInitialized = false

    if (@webView = gWebView)?
      @webView.setUIProperties(@htmlOptions)
      @webView.show()
    else
      @webView = gWebView = new Hy.UI.WebViewProxy(@htmlOptions)

    this.addChild(@webView)

    this

  # ----------------------------------------------------------------------------------------------------------------
  isLoaded: ()-> @webViewLoaded

  # ----------------------------------------------------------------------------------------------------------------
  isInitialized: ()-> @webViewInitialized

  # ----------------------------------------------------------------------------------------------------------------
  event_pageLoaded: ()->
    if not @webViewLoaded
      @webViewLoaded = true
      Hy.Trace.debug "WebViewPanel::pageEventHandler (#{@options._tag} LOADED)"

    this.event_pageInitialized()

  # ----------------------------------------------------------------------------------------------------------------
  event_pageInitialized: ()->
    if not @webViewInitialized
      @webViewInitialized = true
      Hy.Trace.debug "WebViewPanel::pageEventHandler (#{@options._tag} INITIALIZED)"
      @fnInitialized?()

    this

  # ----------------------------------------------------------------------------------------------------------------
  initialize: (fnInitialized = null)->

    WebViewPanel.initEventHandler(this)

    @webViewInitialized = false

    @fnInitialized = fnInitialized

    if @webView?
      this.event_pageInitialized()
    else
      this.webViewCreate()

    this

  # ----------------------------------------------------------------------------------------------------------------  
  start: ()->

    this

  # ----------------------------------------------------------------------------------------------------------------  
  stop: ()->

    this

  # ----------------------------------------------------------------------------------------------------------------  
  open: ()->

    this
    
  # ----------------------------------------------------------------------------------------------------------------  
  close: ()->

    WebViewPanel.clearEventHandler(this)

    this.removeChild(@webView)

    @webView = null
    @webViewLoaded = false
    @webViewInitialized = false

    this

  # ----------------------------------------------------------------------------------------------------------------
  @initEventHandler: (webViewPanel)->

    if not gEventHandler
      gEventHandler = true
      Ti.App.addEventListener("_pageEventOut", 
                              (event)=>
                                 WebViewPanel.pageEventHandler(event)
                                 null)

    if not _.detect(gListeners, (e)=>e.panel is webViewPanel)
      gListeners.push {panel: webViewPanel}
 
    this

  # ----------------------------------------------------------------------------------------------------------------
  @clearEventHandler: (webViewPanel)->

    gListeners = _.reject(gListeners, (e)=>e.panel is webViewPanel)

#    if _.size(gListeners) is 0
#      Ti.App.removeEventListener("_pageEventOut", WebViewPanel.pageEventHandlerWrapper)

    this

  # ----------------------------------------------------------------------------------------------------------------
  @pageEventHandlerWrapper: (event)->
    Hy.Utils.Deferral.create(0, (event)=>WebViewPanel.pageEventHandler(event)) 

  # ----------------------------------------------------------------------------------------------------------------
  # Handler for outbound events (those coming from the html page)
  #
  @pageEventHandler: (event)->

    if event._responseRequired
      if (pendingEvent = _.detect(gOutstandingEvents, (e)=>e.event._counter is event._counter))?
        gOutstandingEvents = _.without(gOutstandingEvents, pendingEvent)
        pendingEvent.fnCompleted(event)
    else
      method = "event_#{event.kind}"

      for listener in gListeners
        fn = listener.panel[method]
        if fn? and typeof(fn) is "function"
          listener.panel[method](event.data)

    this

  # ----------------------------------------------------------------------------------------------------------------
  fireEvent: (event, fnCompleted = null)->
    Hy.Trace.debug "WebViewPanel::fireEvent (FIRING #{event.kind})"

    event._counter = ++gEventCount

    if (event._responseRequired = fnCompleted?)
      gOutstandingEvents.push {event: event, fnCompleted: fnCompleted}

    Ti.App.fireEvent("_PageEventIn", event)

    this

# ==================================================================================================================
class LabeledButtonPanel extends Panel

  kWidth = 150
  kHeight = 100
  kTextHeightRatio = 0.5
  kButtonImageWidth = 53

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (options = {}, @buttonOptions = {}, @fnClicked = null, @topTextOptions = {}, @bottomTextOptions = {}) ->

    @defaultBorderWidth = 0

    defaultOptions =
      width: kWidth
      height: kHeight
      _tag: "LabeledButtonPanel"
      borderColor: Hy.UI.Colors.white
      borderWidth: @defaultBorderWidth

    super Hy.UI.ViewProxy.mergeOptions(defaultOptions,options)

    this

  # ----------------------------------------------------------------------------------------------------------------
  addInfo: (animatedFlag = false, enabled = true)->

    duration = 250

    fn = ()=>
      this.removeChildren()

      this.addTopText(@topTextOptions)
          .addButton(@buttonOptions, @fnClicked)
          .addBottomText(@bottomTextOptions)

      this.setEnabled(enabled)

      null

    if animatedFlag
      this.animate({opacity: 0, duration: duration}, (e)=>fn()) # Callback may not be fired if view isn't onscreen...!
    else
      fn()
    
    this

  # ----------------------------------------------------------------------------------------------------------------
  # Presume that initialized state == enabled. Subclasses can change as necessary
  #
  initialize: (animatedFlag = false, enabled = true)->

    super

    this.addInfo(animatedFlag, enabled)

    this

  # ----------------------------------------------------------------------------------------------------------------
  createTextLabel: (options)->

    defaultTextOptions = 
      width: this.getUIProperty("width")
      height: this.getUIProperty("height")  * (1 - kTextHeightRatio) * .5
      font: Hy.UI.Fonts.specMinisculeNormal
      textAlign: 'center'
      borderColor: Hy.UI.Colors.white
      borderWidth: @defaultBorderWidth
      text: ""

    this.addChild(new Hy.UI.LabelProxy(Hy.UI.ViewProxy.mergeOptions(defaultTextOptions, options)))

    this 

  # ----------------------------------------------------------------------------------------------------------------
  addTopText: (options)->

    defaultOptions = 
      top: 0
      _tag: "Top Text"

    this.createTextLabel(Hy.UI.ViewProxy.mergeOptions(defaultOptions, options))

    this

  # ----------------------------------------------------------------------------------------------------------------
  addBottomText: (options)->

    defaultOptions = 
      bottom: 0
      _tag: "Bottom Text"

    this.createTextLabel(Hy.UI.ViewProxy.mergeOptions(defaultOptions, options))

    this

  # ----------------------------------------------------------------------------------------------------------------
  addButton: (options, fnClicked = null)->

    defaultOptions = 
      width: kButtonImageWidth
      height: this.getUIProperty("height") * kTextHeightRatio
      backgroundImage: "assets/icons/circle-black.png"
      backgroundSelectedImage: "assets/icons/circle-black-selected.png"
      borderColor: Hy.UI.Colors.white
      borderWidth: @defaultBorderWidth
      _tag: "Button"
      title: "?"
      font: Hy.UI.Fonts.specMinisculeNormal

    this.addChild(@button = new Hy.UI.ButtonProxy(Hy.UI.ViewProxy.mergeOptions(defaultOptions, options)))

    if fnClicked?
      @button.addEventListener("click", fnClicked) # TODO: debounce??

    this

  # ----------------------------------------------------------------------------------------------------------------
  setEnabled: (enabled)->

    @button?.setEnabled(enabled)

    super enabled

    this

# ==================================================================================================================
class CodePanel extends LabeledButtonPanel

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (options = {}, fnClicked = null)->

    defaultOptions = {}

    super Hy.UI.ViewProxy.mergeOptions(defaultOptions,options), {}, fnClicked, {text: "joinCG.com"}, {text: "Tap for Info"}

    this

  # ----------------------------------------------------------------------------------------------------------------
  obs_networkChanged: (reason)->

    super

    if reason is "Wifi"
      this.initialize(true)

    this

  # ----------------------------------------------------------------------------------------------------------------
  addButton: (buttonOptions, fnClicked)->

    encodingText = if (encoding = Hy.Network.NetworkService.getAddressEncoding())? then encoding else "no wifi"

    # Only display up to 7 characters
    if encodingText.length > 7
      encodingText = ""

    # We want to take the default values from the font spec, and then change the font size a bit.
    # So we make a copy of the font spec first.
    defaultButtonOptions = 
      font: Hy.UI.Fonts.cloneFont(Hy.UI.Fonts.specMinisculeNormal)
      title: encodingText

    defaultButtonOptions.font.fontSize = switch encodingText.length
      when 1
        24
      when 2
        23
      when 3
        19
      when 4
        16
      when 5, 6, 7
        13
      else
        10

    super Hy.UI.ViewProxy.mergeOptions(defaultButtonOptions, buttonOptions), fnClicked

    this

# ==================================================================================================================
class UpdateAvailablePanel extends LabeledButtonPanel

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (options = {}, fnClicked = null)->

    defaultOptions = {}

    super Hy.UI.ViewProxy.mergeOptions(defaultOptions,options), {}, fnClicked, {text: "Update"}, {text: "Available?"}

    this

  # ----------------------------------------------------------------------------------------------------------------
  obs_networkChanged: (reason)->

    super

    if reason is "Wifi"
      this.initialize(true)

    this

  # ----------------------------------------------------------------------------------------------------------------
  obs_updateAvailable: ()->

    this.initialize(true)

    this

  # ----------------------------------------------------------------------------------------------------------------
  isUpdateAvailable: ()->

    Hy.Network.NetworkService.isOnline() and (Hy.Content.ContentManifestUpdate.getUpdate()? or Hy.Update.ConsoleAppUpdate.getUpdate()?)

  # ----------------------------------------------------------------------------------------------------------------
  initialize: (animatedFlag = false)->

    super animatedFlag, this.isUpdateAvailable()

  # ----------------------------------------------------------------------------------------------------------------
  addButton: (buttonOptions, fnClicked)->

    title = if Hy.Network.NetworkService.isOnline()
      if this.isUpdateAvailable()
        "Yes!"
      else
        "No"
    else
      "?"

    defaultButtonOptions = 
      title: title
      font: Hy.UI.Fonts.specSmallNormal

    super Hy.UI.ViewProxy.mergeOptions(defaultButtonOptions, buttonOptions), fnClicked

    this


# ==================================================================================================================
class UserCreatedContentInfoPanel extends UtilityPanel

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (options, @fnClickDone, @fnClickBuy)->

    super options, false

    this

  # ----------------------------------------------------------------------------------------------------------------
  initialize: ()->

    super

    this.addIconRow()

    this.addButtons()  

    this

  # ----------------------------------------------------------------------------------------------------------------
  viewOptions: ()->
    options = 
      top: 125
      height: 600
      width: 850
      zIndex: 150
      backgroundImage: Hy.UI.Backgrounds.pixelOverlay

    Hy.UI.ViewProxy.mergeOptions(super, options)

  # ----------------------------------------------------------------------------------------------------------------
  getUCCPurchaseItem: ()-> Hy.Content.ContentManager.get().getUCCPurchaseItem()

  # ----------------------------------------------------------------------------------------------------------------
  labelSections: ()->

    if this.getUCCPurchaseItem().isPurchased()
      [this.sectionTitleInstructions(), this.sectionBodyInstructions()]
    else
      [this.sectionTitleUpsell(), this.sectionBodyUpsell()]

  # ----------------------------------------------------------------------------------------------------------------
  labelViewOptions: ()->
    top: 0
    height: 465
    width: 850
    layout: 'vertical'
    zIndex: 102

  # ----------------------------------------------------------------------------------------------------------------
  sectionTitleUpsell: ()->

    [{text: "Create and Share Your Own Trivia Packs!", options: {font: Hy.UI.Fonts.specBigNormal, color: Hy.UI.Colors.MrF.DarkBlue, textAlign: "center"}}]

  # ----------------------------------------------------------------------------------------------------------------
  sectionTitleInstructions: ()->

    [{text: "It\'s Easy to Create Your Own Trivia Packs!", options: {font: Hy.UI.Fonts.specBigNormal, color: Hy.UI.Colors.MrF.DarkBlue, textAlign: "center"}}]

  # ----------------------------------------------------------------------------------------------------------------
  sectionBodyUpsell: ()->

    uccPurchaseItem = this.getUCCPurchaseItem()
    isPurchased = uccPurchaseItem.isPurchased()
    price = uccPurchaseItem.getDisplayPrice()

    t = []

    t.push {text: "", options: {textAlign: "center"}}
    t.push {text: "", options: {textAlign: "center"}}

    t.push {text: "It\'s easy with the optional Custom Trivia Pack feature!", options: {textAlign: "center"}}

    t.push {text: "", options: {textAlign: "center"}}
    t.push {text: "Enter your questions & answers into a Google Docs Spreadsheet, and", options: {textAlign: "center"}}
    t.push {text: "Trivially imports the Trivia Pack for you!", options: {textAlign: "center"}}

    t.push {text: "", options: {textAlign: "center"}}
    t.push {text: "You can create an unlimited number of Trivia Packs, and also", options: {textAlign: "center"}}
    t.push {text: "import Trivia Packs shared with you via email, Twitter, and Facebook", options: {textAlign: "center"}}

    t.push {text: "", options: {textAlign: "center"}}

    if isPurchased
      null
    else
      if price?
        t.push {text: "Buy this feature for only only #{price}", options: {textAlign: "center", color: Hy.UI.Colors.MrF.DarkBlue}}
      t.push {text: "Tap \"Buy Now\" to start creating!", options: {textAlign: "center", color: Hy.UI.Colors.MrF.DarkBlue}}

    t.push {text: "", options: {textAlign: "center"}}
    t.push {text: "", options: {textAlign: "center"}}

#    t.push {text: "Tap \"Help\" for detailed instructions, or \"Cancel\" to return to Start Page", options: {textAlign: "center"}} 

    t

  # ----------------------------------------------------------------------------------------------------------------
  sectionBodyInstructions: ()->

    uccPurchaseItem = this.getUCCPurchaseItem()
    isPurchased = uccPurchaseItem.isPurchased()
    price = uccPurchaseItem.getDisplayPrice()

    t = []

#    t.push {text: "", options: {textAlign: "center"}}

    options = {textAlign: "left", font: Hy.UI.Fonts.specTinyNormal}

    t.push {text: "On a PC or Mac, create a new Google Docs spreadsheet and add your content as follows:", options: options}
    t.push {text: "1: Row #1: Enter \"##Trivia\" in cell #1", options: options}
    t.push {text: "2: Row #2: Leave blank", options: options}
    t.push {text: "3: Rows #3-7: Enter question in cell #1, correct answer in cell #2, fake answers in cells #3-5", options: options}
    t.push {text: "4: Select \"File\", \"Publish...\", \"Start Publishing\"", options: options}

    t.push {text: "5: Copy the spreadsheet URL to your iPad\'s clipboard (email it to yourself on the iPad, etc)", options: options}
    t.push {text: "6: On the Trivially Start screen, tap \"new\" to import your Trivia Pack", options: options}

    t.push {text: "", options: options}
    t.push {text: "To Edit a Trivia Pack:", options: options}
    t.push {text: "1: Edit the spreadsheet, select \"File\", \"Publish...\", \"Republish now\"", options: options}
    t.push {text: "2: On the Trivially Start Page, tap the Trivia Pack's blue arrow, to see more info about it", options: options}
    t.push {text: "3: Tap \"check for update\" to update it, or \"remove\" to remove it from this iPad", options: options}
    t.push {text: "", options: options}
    t.push {text: "Tap \"Help & Examples\" for examples and info on specifying name, description, icon, difficulty", options: options}

    t

  # ----------------------------------------------------------------------------------------------------------------
  labelOptions: ()->

    options = 
      color: Hy.UI.Colors.white

    Hy.UI.ViewProxy.mergeOptions(super, options)

  # ----------------------------------------------------------------------------------------------------------------
  addIconRow: ()->

    iconContainerOptions = 
      top: 60
      width: this.getUIProperty("width")
#      height: 100
      _horizontalLayout: "group"
      _verticalLayout: "center"
      _padding: 40
#      borderColor: Hy.UI.Colors.green
#      borderWidth: 1

    uccPurchaseItem = this.getUCCPurchaseItem()
    isPurchased = uccPurchaseItem.isPurchased()

    if @iconRow?
      this.removeChild(@iconRow)
      @iconRow = null

    if not isPurchased
      this.addChild(@iconRow = new Hy.UI.ViewProxy(iconContainerOptions))

      defaultIconOptions = {}

      for icon in ["sport", "history", "literature", "science", "geography", "general"]
        iconOptions = 
          image: "data/#{icon}.png"
          width: 33  # @2x
          height: 33
#          borderColor: Hy.UI.Colors.green
#          borderWidth: 1

        @iconRow.addChild(new Hy.UI.ImageViewProxy(Hy.UI.ViewProxy.mergeOptions(defaultIconOptions, iconOptions)))

    this
  # ----------------------------------------------------------------------------------------------------------------
  addButtons: ()->

    if @buttonContainer?
      this.removeChild(@buttonContainer)
      @buttonContainer = null

    buttonContainerOptions = 
      bottom: 50
      width: this.getUIProperty("width")
      _horizontalLayout: "group"
      _verticalLayout: "center"
      _padding: 40
#      borderColor: Hy.UI.Colors.green
#      borderWidth: 1

    this.addChild(@buttonContainer = new Hy.UI.ViewProxy(buttonContainerOptions))

    @buttonContainer.addChild(this.addDoneButton())
    @buttonContainer.addChild(this.addBuyButton())
    @buttonContainer.addChild(this.addHelpButton())

    this

  # ----------------------------------------------------------------------------------------------------------------
  addDoneButton: (options = {})->

    fnDone = (e, v)=>
      @fnClickDone()
      null

#    label = if this.getUCCPurchaseItem().isPurchased() then "Return To Start Page" else "Cancel"

    this.addButton("done", fnDone, options, {backgroundImage: "assets/icons/button-restart.png"}, [{text: "Back"}])

  # ----------------------------------------------------------------------------------------------------------------
  addBuyButton: (options = {})->

    fnBuy = (e, v)=>
      if this.getUCCPurchaseItem().isPurchased()
        null
      else
        @fnClickBuy()
      null

    uccPurchaseItem = this.getUCCPurchaseItem()
    isPurchased = uccPurchaseItem.isPurchased()
    price = uccPurchaseItem.getDisplayPrice()

    #price = "1234567"

    buttonOptions = 
      backgroundImage: "assets/icons/circle-blue-large.png"
      title: if price? then price else "Buy"
      font: Hy.UI.Fonts.cloneFont(Hy.UI.Fonts.specTinyNormalNoBold)

    if price?
      buttonOptions.font.fontSize = switch price.length
        when 1, 2, 3
          34
        when 4
          26
        when 5
          22
        when 6
          18
        else
          16

    labelOptionsArray = []

    height = 36
    width = 100

    buyLabelOptions = 
      text: "Buy Now"
      textAlign: 'center'
      width: width
#      borderColor: Hy.UI.Colors.green
#      borderWidth: 1

    buyInfoLabelOptions = 
      font: Hy.UI.Fonts.specMinisculeNormal
      color: Hy.UI.Colors.MrF.DarkBlue
      height: height
      width: width
      bottom: 0
      textAlign: 'center'
#      borderColor: Hy.UI.Colors.white
#      borderWidth: 1

    if isPurchased
      buttonOptions.opacity = 0.5

      labelOptionsArray.push buyLabelOptions
      buyLabelOptions.top = 0
      buyLabelOptions.height = height
      buyLabelOptions.opacity = 0.5

      labelOptionsArray.push buyInfoLabelOptions
      buyInfoLabelOptions.text = "Feature Enabled!"

    else
      labelOptionsArray.push buyLabelOptions
      buyLabelOptions.height = height
#      buyLabelOptions.bottom = 0

    button = this.addButton("buy", fnBuy, options, buttonOptions, labelOptionsArray)

    button

  # ----------------------------------------------------------------------------------------------------------------
  addHelpButton: (options = {})->

    fnHelp = (e, v)=>
      this.launchURL(Hy.Config.Content.kHelpPage)
      this.setButtonState("help", false)
      null

    buttonOptions = 
      backgroundImage: "assets/icons/circle-blue-large.png"
      title: "?"
      font: Hy.UI.Fonts.specBigNormal

    button = this.addButton("help", fnHelp, options, buttonOptions, [{text: "Help & Examples"}])

    button

# ==================================================================================================================
class JoinCodeInfoPanel extends UtilityPanel

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (options, @fnClickDone)->

    super options, true

    @connectionAdvice = null
    @ipURLViews = null

    this

  # ----------------------------------------------------------------------------------------------------------------
  obs_networkChanged: (reason)->

    super

    refreshNeeded = if @connectionAdvice?
      # Optimization: don't refresh if we last showed Wifi advice, and this change is about Bonjour
      if @connectionAdvice is "Wifi" and reason is "Bonjour"
        false
      else
        true
    else
      true

    if refreshNeeded
      this.addInfo(true)

    this.updateIPURLViews()
    
    this

  # ----------------------------------------------------------------------------------------------------------------
  initialize: ()->

    super

    this.updateIPURLViews()

    this.addButtons()  

    this

  # ----------------------------------------------------------------------------------------------------------------
  updateIPURLViews: ()->

    if @ipURLViews?
      for v in @ipURLViews
        this.removeChild(v)

    @ipURLViews = this.addLabelItem(this, this.sectionIPURL())

    this

  # ----------------------------------------------------------------------------------------------------------------
  viewOptions: ()->
    options = 
      top: 125
      height: 600
      width: 850
      zIndex: 150
      backgroundImage: Hy.UI.Backgrounds.pixelOverlay

    Hy.UI.ViewProxy.mergeOptions(super, options)

  # ----------------------------------------------------------------------------------------------------------------
  labelSections: ()->

    [this.sectionTitle(), this.sectionBody()]

  # ----------------------------------------------------------------------------------------------------------------
  labelViewOptions: ()->
    top: 0
    height: 465
    width: 850
    layout: 'vertical'
    zIndex: 102

  # ----------------------------------------------------------------------------------------------------------------
  sectionBody: ()->

    t = []
    t.push {text: "One person can play on this iPad directly, or up to #{Hy.Config.kMaxRemotePlayers} players", options: {textAlign: "center"}}
    t.push {text: "can compete to answer questions displayed on this iPad", options: {textAlign: "center"}}
    t.push {text: "", options: {textAlign: "center"}}
    t.push {text: "Each player uses an iOS device, or", options: {textAlign: "center"}}
    t.push {text: "Safari, FireFox, Chrome, or IE on Windows 8, MacOS, or Ubuntu,", options: {textAlign: "center"}}
    t.push {text: "on the same WiFi network as this iPad", options: {textAlign: "center"}}

    @connectionAdvice = null

    if Hy.Network.NetworkService.isOnlineWifi()
      @connectionAdvice = "Wifi"

      if (encoding = Hy.Network.NetworkService.getAddressEncoding())?
        t.push {text: "Each player should visit #{Hy.Config.Rendezvous.URLDisplayName} and enter code:", options: {textAlign: "center"}}
        t.push {text: " #{encoding} ", options: {textAlign: "center", color: Hy.UI.Colors.MrF.Red, font: Hy.UI.Fonts.specMediumCode }} #, borderColor: Hy.UI.Colors.MrF.LightBlue}}
      else
        t.push {text: "Please join this iPad to the same WiFi network as the other devices and restart Trivially.", options: {textAlign: "center"}}
    else
      t.push {text: "Note that this iPad currently isn\'t connected to WiFi", options: {textAlign: "center", color: Hy.UI.Colors.MrF.Red}}

      if (bonjourURL = Hy.Network.NetworkService.getBonjourURL())?
        @connectionAdvice = "Bonjour"

        t.push {text: "If this iPad is a Personal Hotspot, each player should connect to it and visit:", options: {textAlign: "center"}}

#        bonjourURL = "123456789012345678901234567890123456789012345678901234567890"

        fontSize = if bonjourURL.length <= 25
          26
        else if bonjourURL.length <= 50
          24
        else
          20
        font = Hy.UI.Fonts.mergeFonts(Hy.UI.Fonts.specMediumCode, {fontSize: fontSize})

        t.push {text: " #{bonjourURL} ", options: {textAlign: "center", font: font }}

    t.push {text: "", options: {textAlign: "center"}}
    t.push {text: "Tap \"More Help\" for more instructions, or \"Back\" to return to Start Page", options: {textAlign: "center"}} 

    t

  # ----------------------------------------------------------------------------------------------------------------
  sectionTitle: ()->

    [{text: "How to enjoy CrowdGame™ Trivially with multiple players", options: {font: Hy.UI.Fonts.specBigNormal, color: Hy.UI.Colors.MrF.DarkBlue, textAlign: "center"}}]

  # ----------------------------------------------------------------------------------------------------------------
  sectionIPURL: ()->

    options = 
      bottom: 10
      top: null
      textAlign: "center"
      height: 'auto'
      color: Hy.UI.Colors.gray
      font: Hy.UI.Fonts.specMinisculeNormal

    text = Hy.Network.NetworkService.getIPURL()

    [{text: (if text? and Hy.Network.NetworkService.isOnlineWifi() then text else ""), options: options}]

  # ----------------------------------------------------------------------------------------------------------------
  labelOptions: ()->

    options = 
      color: Hy.UI.Colors.white

    Hy.UI.ViewProxy.mergeOptions(super, options)

  # ----------------------------------------------------------------------------------------------------------------
  addButtons: ()->

    if @buttonContainer?
      this.removeChild(@buttonContainer)
      @buttonContainer = null

    buttonContainerOptions = 
      bottom: 50
      width: this.getUIProperty("width")
      _horizontalLayout: "group"
      _verticalLayout: "center"
      _padding: 40
#      borderColor: Hy.UI.Colors.green
#      borderWidth: 1

    this.addChild(@buttonContainer = new Hy.UI.ViewProxy(buttonContainerOptions))

    @buttonContainer.addChild(this.addDoneButton())
    @buttonContainer.addChild(this.addHelpButton())

    this

  # ----------------------------------------------------------------------------------------------------------------
  addDoneButton: (options = {})->

    fnDone = (e, v)=>
      @fnClickDone()
      null

    this.addButton("done", fnDone, options, {backgroundImage: "assets/icons/button-restart.png"}, [{text: "Back"}])

  # ----------------------------------------------------------------------------------------------------------------
  addHelpButton: (options = {})->

    fnHelp = (e, v)=>
      this.launchURL(Hy.Config.PlayerNetwork.kHelpPage)
      this.setButtonState("help", false)
      null
      
    buttonOptions = 
      backgroundImage: "assets/icons/circle-blue-large.png"
      title: "?"
      font: Hy.UI.Fonts.specBigNormal

    button = this.addButton("help", fnHelp, options, buttonOptions, [{text: "More Help"}])

    button


# ==================================================================================================================
if not Hyperbotic.Panels?
  Hyperbotic.Panels = {}

Hyperbotic.Panels.Panel = Panel
Hyperbotic.Panels.QuestionInfoPanel = QuestionInfoPanel
Hyperbotic.Panels.CheckInCritterPanel = CheckInCritterPanel
Hyperbotic.Panels.AnswerCritterPanel = AnswerCritterPanel
Hyperbotic.Panels.ScoreboardCritterPanel = ScoreboardCritterPanel
Hyperbotic.Panels.IntroPanel = IntroPanel
Hyperbotic.Panels.AboutPanel = AboutPanel
Hyperbotic.Panels.ContentPackList = ContentPackList
Hyperbotic.Panels.ContentView = ContentView
Hyperbotic.Panels.ContentOptionsPanel = ContentOptionsPanel

Hyperbotic.Panels.OptionPanels = OptionPanels
Hyperbotic.Panels.CountdownPanel = CountdownPanel
Hyperbotic.Panels.WebViewPanel = WebViewPanel

Hyperbotic.Panels.LabeledButtonPanel = LabeledButtonPanel
Hyperbotic.Panels.CodePanel = CodePanel
Hyperbotic.Panels.UpdateAvailablePanel = UpdateAvailablePanel
Hyperbotic.Panels.UserCreatedContentInfoPanel = UserCreatedContentInfoPanel
Hyperbotic.Panels.JoinCodeInfoPanel = JoinCodeInfoPanel

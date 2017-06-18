# ==================================================================================================================
class CountdownTicker
  # ----------------------------------------------------------------------------------------------------------------
  constructor: (@fnInitView, @fnUpdateView, @fnCompleted, @fnSound)->

    this

  # ----------------------------------------------------------------------------------------------------------------
  init: (@value, startingDelay)->
    @startValue = @value

    this.clearTimers()

    this.display true

    fnTick = ()=>
      this.tick()

    f = ()=>
      this.display false
      @countdownInterval = setInterval fnTick, 1000
      @startingDelay = null

    if startingDelay > 0
      @startingDelay = Hy.Utils.Deferral.create startingDelay, f
    else
      f()
 
    this

  # ----------------------------------------------------------------------------------------------------------------
  getValue: ()->
    @value

  # ----------------------------------------------------------------------------------------------------------------
  clearTimers: ()->

    if @countdownInterval?
      clearInterval(@countdownInterval)
      @countdownInterval = null

    if @startingDelay?
      @startingDelay.clear() 
      @startingDelay = null

    this

  # ----------------------------------------------------------------------------------------------------------------
  display: (init)->

    if init
      @fnInitView @value
    else
      @fnSound @value
      @fnUpdateView @value

    this

  # ----------------------------------------------------------------------------------------------------------------
  exit: ()->
    this.pause()
    @value = null
    null

  # ----------------------------------------------------------------------------------------------------------------
  pause: ()->

    this.clearTimers()

    this

  # ----------------------------------------------------------------------------------------------------------------
  continue_: ()->
    this.init(@value||@startValue, 0)

  # ----------------------------------------------------------------------------------------------------------------
  reset: ()->
    @value = @startValue || 10 # TODO: should get default value from app

  # ----------------------------------------------------------------------------------------------------------------
  tick: ()->
    @value -= 1
    
    if @value >= 0
      this.display false

    if @value <= 0
      this.exit()
      @fnCompleted(source:this) 
    this

# ==================================================================================================================
#
#
# zIndex scheme:
#  windows: 1-10
#  page-owned stuff: 50-100
#  overlays, buttons, other clickbale stuff: 101+
#
# Lifecycle of a Page:
#   created
#   initialize
#   open
#   start
#    ...
#   close
#   stop
#
#   also:
#     pause
#     resumed
# 
class Page
  gInstanceCount = 0

  gPages = []
  
  # ----------------------------------------------------------------------------------------------------------------
  @findPage: (pageClass)->
    for page in gPages
      if page.constructor.name is pageClass.name
        return page
    null
  # ----------------------------------------------------------------------------------------------------------------
  @getPage: (pageMap)->

    p = (Page.findPage(pageMap.pageClass)) || new pageMap.pageClass(pageMap.state, Hy.ConsoleApp.get())

    p

  # ----------------------------------------------------------------------------------------------------------------
  # NOT IMPLEMENTED
  @doneWithPage: (pageMap)->

    if (p = Page.findPage(pageMap.pageClass))
      gPages = gPages.reject(p)
      p.doneWithPage()

    null

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (@state, @app)->
    @instance = ++gInstanceCount

    gPages.push this

    options = 
      fullscreen: true
      zIndex: 2
      orientationModes: [Ti.UI.LANDSCAPE_LEFT, Ti.UI.LANDSCAPE_RIGHT]
      opacity: 0
      _tag: "Main Window"

    @window = new Hy.UI.WindowProxy(options)

    @window.addChild(@container = new Hy.UI.ViewProxy(this.containerOptions()))

    @container.addChild(this.createAnimationContainer())

#    @window.setTrace("opacity")
    this

  # ----------------------------------------------------------------------------------------------------------------
  initialize: ()->

    # We do this here since a page's state can change (since pages can be reused, such as Question)
    @container.setUIProperty("backgroundImage", if (background = PageState.getPageMap(this.getState()).background)? then background else null)

    @allowEvents = false

    true

  # ----------------------------------------------------------------------------------------------------------------
  getAllowEvents: ()-> @allowEvents

  # ----------------------------------------------------------------------------------------------------------------
  getState: ()-> @state

  # ----------------------------------------------------------------------------------------------------------------
  setState: (state)-> @state = state

  # ----------------------------------------------------------------------------------------------------------------
  getWindow: ()->@window

  # ----------------------------------------------------------------------------------------------------------------
  getApp: ()-> @app

  # ----------------------------------------------------------------------------------------------------------------
  obs_networkChanged: (reason)->
    this

  # ----------------------------------------------------------------------------------------------------------------  
  openWindow: (options={})->
    @window.open(options)

    this

  # ----------------------------------------------------------------------------------------------------------------
  closeWindow: (options={})->
    @window.close()

    this

  # ----------------------------------------------------------------------------------------------------------------
  animateWindow: (options)-> # 2.5.0
    @window.animate(options)

    this

  # ----------------------------------------------------------------------------------------------------------------
  start: ()->

    @allowEvents = true

    this.setStopAnimating(false)

    this

  # ----------------------------------------------------------------------------------------------------------------
  stop: ()->

    @allowEvents = false

    this.setStopAnimating(true)

    this

  # ----------------------------------------------------------------------------------------------------------------
  pause: ()->
    this

  # ----------------------------------------------------------------------------------------------------------------
  resumed: ()->
    this

  # ----------------------------------------------------------------------------------------------------------------
  containerOptions: ()->

    top: 0
    left: 0
    width: Hy.UI.iPad.screenWidth # must set these, else _layout{vertical, horizontal} directives wont work
    height: Hy.UI.iPad.screenHeight
    zIndex: 101
    _tag: "Main Container"

  # ----------------------------------------------------------------------------------------------------------------
  createAnimationContainer: ()->
    animationContainerOptions = 
      top:    0
      left:   0 
      right:  0
      bottom: 0
      zIndex: 200
      opacity: 1
      _tag: "Animation Container"

    @animationContainer = new Hy.UI.ViewProxy(animationContainerOptions)
    @animationContainer.hide()
    @animationContainerHidden = true

    @animationContainer
     
  # ----------------------------------------------------------------------------------------------------------------
  buildAnimationFromScenes: (scenes, previousScenes = null)->

    sceneTotalDuration = 0
    currentStart = 0

    for scene in scenes
      sceneDuration = 0
      sceneCurrentStart = 0
      sceneFirstStart = null
      for animationOption in scene.animationOptions
        sceneCurrentStart += animationOption._incrementalDelay

        if not sceneFirstStart?
          sceneFirstStart = sceneCurrentStart

        if not animationOption.duration?
          animationOption.duration = 0

        sceneDuration = Math.max(sceneDuration, sceneCurrentStart + animationOption.duration)

        aOptions =
          delay: currentStart + sceneCurrentStart

        animationOption._animationObjectOptions = Hy.UI.ViewProxy.mergeOptions(animationOption, aOptions)

      computedOptions = Hy.UI.ViewProxy.mergeOptions(scene.imageOptions, {}) #make a copy

      createdNewScene = true
      if previousScenes?
        if(existingScene = _.detect(previousScenes, (s)=>s.image is scene.image))?
          createdNewScene = false
          scene._view = existingScene._view
          scene._view.setUIProperties(computedOptions)

      if not scene._view?
        computedOptions._tag = "Animation"

        if scene.image?
          computedOptions.image = "assets/bkgnds/animations/#{scene.image}.png"
          scene._view = new Hy.UI.ImageViewProxy(computedOptions)
        else
          if scene.method?      
            scene._view = scene.method(computedOptions)
          else
            Hy.Trace.debug "Page::buildAnimationFromScenes (NO SCENE IMAGE OR METHOD)"

      # STOP events don't seem to be getting fired. The below callback is never called.
      if scene._view? and createdNewScene
        scene._view.addEventListener("stop", (evt, view)=>Hy.Trace.debug("ANIMATION STOP EVENT (#{scene.image} view=#{view?.getTag()}"))

      sceneTotalDuration = Math.max(sceneTotalDuration, currentStart + sceneDuration)
      currentStart += sceneFirstStart

    [scenes, sceneTotalDuration]

  # ----------------------------------------------------------------------------------------------------------------
  setStopAnimating: (flag)-> @stopAnimating = flag

  # ----------------------------------------------------------------------------------------------------------------
  clearAnimation: ()->
    Hy.Trace.debug "Page::hideAnimation (CLEARING ANIMATION CONTAINER)"

    this.hideAnimation()

    @animationContainer.removeChildren()

    this

  # ----------------------------------------------------------------------------------------------------------------
  hideAnimation: ()->
    Hy.Trace.debug "Page::hideAnimation (HIDING ANIMATION CONTAINER)"

    @animationContainer?.hide()
    @animationContainerHidden = true

    this

  # ----------------------------------------------------------------------------------------------------------------
  animateScenes: (scenes)->

    this.setStopAnimating(false)

    @animationOpenedWindow = false

    for scene in scenes
      this.animateScene(scenes, scene, 0)

    this

  # ----------------------------------------------------------------------------------------------------------------
  animateScene: (scenes, scene, index)->

    animationOption = scene.animationOptions[index]
    animationOption._animationObject = null  #TEST

    imageOptions = {}
    if animationOption._startOpacity?
      imageOptions.opacity = animationOption._startOpacity
    else
      if animationOption.opacity?
        imageOptions.opacity = 0

    scene._view.setUIProperties(imageOptions)

    if @animationContainerHidden
      @animationContainerHidden = false
      @animationContainer.show()

    if not @animationContainer.hasChild(scene._view)
      @animationContainer.addChild(scene._view)

    Hy.Trace.debug "Page::animateScene (BEGIN ANIMATE #{scene.image} ##{index})"
  
    if not @animationOpenedWindow
      @window.setUIProperty("opacity", 1.0)
      this.openWindow()
      @animationOpenedWindow = true

    animateFn = ()=>
      Hy.Trace.debug "Page::animateScene (CONTINUING ANIMATION #{scene.image})"
      animationOption._animationObject = Ti.UI.createAnimation(animationOption._animationObjectOptions)
      animationOption._animationObject.addEventListener("complete", (evt)=>this.animateCompleteEvent(evt.source, scenes))
      scene._view.animate(animationOption._animationObject)
      null

    # Note that this is a hack and won't work as intended if there are multiple scenes to be animated
    if (fn = animationOption._waitForWindowFn)?
      Hy.Utils.Deferral.create(0, ()=>fn(animateFn))
    else
      animateFn()

    this

  # ----------------------------------------------------------------------------------------------------------------
  # TODO: it's possible that our version of the properties of an object that's been animated may no longer
  # reflect reality, at the end of an animation. Should really set UIProperties at the end, here.
  animateCompleteEvent: (animationObject, scenes)->

    for scene in scenes
      index = -1
      for animationOption in scene.animationOptions
        index++
        if animationOption._animationObject is animationObject
          if index < (_.size(scene.animationOptions)-1)
            if @stopAnimating
              Hy.Trace.debug "Page::animateCompleteEvent (ANIMATION STOPPED #{scene.image})"
            else
              Hy.Trace.debug "Page::animateCompleteEvent (ANIMATION COMPLETED FOR #{scene.image} ##{index}, continuing)"
              this.animateScene(scenes, scene, index+1)
          else
            # if we're here, we're done with this scene. But we can't necessarily remove the scene's view.
            Hy.Trace.debug "Page::animateCompleteEvent (ANIMATION COMPLETED #{scene.image})"

#            @animationContainer.removeChild(scene._view)
          return this

    this

# ==================================================================================================================
class SplashPage extends Page

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (state, app)->

    super state, app

#    @container.addChild(this.createJewelContainer())

    this

  # ----------------------------------------------------------------------------------------------------------------
  createJewelContainer: ()->

    defaultOptions = 
      image: "assets/icons/trivially-01.png"
      height: 100
      width: 100
      _tag: "Jewel Container"

    @jewelView = new Hy.UI.ImageViewProxy(defaultOptions)

    @jewelView

  # ----------------------------------------------------------------------------------------------------------------
  initialize: (fnReady)->

    super

    true

  # ----------------------------------------------------------------------------------------------------------------
  start: ()->

    super

    this

# ==================================================================================================================
class IntroPage extends Page
  # ----------------------------------------------------------------------------------------------------------------
  constructor: (state, app)->

    super state, app

    this.webViewPanelCreate()

    this.addClick()

    this

  # ----------------------------------------------------------------------------------------------------------------
  openWindow: (options={})->
  
    super options

    @webView?.open()

    this

  # ----------------------------------------------------------------------------------------------------------------
  closeWindow: (options={})->

    @webViewPanel?.close()

    super

    this

  # ----------------------------------------------------------------------------------------------------------------
  initialize: (fnReady)->

    super

    @fnReady = fnReady
    @clicked = false
    @clickAllowed = true
    @finishingUp = false
    @finishedAnimatingIn = false

    # apparently, the window has to be open in order for the webview to work...
#    @window.setUIProperty("opacity", 0)
    this.openWindow()

    @webViewPanel?.initialize( (event)=>Hy.Utils.Deferral.create(0, ()=>PageState.get().resumed()) )

    @introPanel?.initialize() # Not likely

    false # Wait

  # ----------------------------------------------------------------------------------------------------------------
  start: ()->

    super

#    @clickAllowed = true

    @webView?.start()
    this

  # ----------------------------------------------------------------------------------------------------------------
  stop: ()->

    @clickAllowed = false

    @webView?.stop()

    super

    this

  # ----------------------------------------------------------------------------------------------------------------
  resumed: ()->

    super

    this

  # ----------------------------------------------------------------------------------------------------------------
  obs_networkChanged: (reason)->
    super

    @introPanel?.obs_networkChanged(reason)

    this

  # ----------------------------------------------------------------------------------------------------------------
  setStopAnimating: (flag)-> 
    super

    if not @finishedAnimatingIn
      @webViewPanel?.fireEvent({kind: "stopAnimating"}, (event)=>this.animateInFinished())

    this

  # ----------------------------------------------------------------------------------------------------------------
  addClick: ()->

    options = 
      top: 0
      bottom: 0
      right: 0
      left: 0
      zIndex: @animationContainer.getUIProperty("zIndex") + 1
      _tag: "Click Container"

    @container.addChild(v = new Hy.UI.ViewProxy(options))

    fnClick = (evt)=>
      if not @clicked and @clickAllowed
        @clicked = true
        @finishingUp = true
        if (pageState = PageState.get()).isTransitioning()
          Hy.Trace.debug("IntroPage::addClick (WAITING FOR TRANSITION)")
          pageState.addPostTransitionAction(()=>@fnReady?())
          this.setStopAnimating(true)
        else
          Hy.Trace.debug("IntroPage::addClick (NOT TRANSITIONING)")
          this.animateOutIntroPanelAndTitle()
          @fnReady?()

      null

    v.addEventListener("click", fnClick)

    this      

  # ----------------------------------------------------------------------------------------------------------------
  addTitle: ()->

    options = 
      top: 140 # 170 # 2.5.0
      left: (Hy.UI.iPad.screenWidth-315)/2
      image: "assets/bkgnds/animations/label-Trivially.png"
      width: 315
      height: 100 
      zIndex: 102
      opacity: 0
      _tag: "Title"

    @container.addChild(@title = new Hy.UI.ImageViewProxy(options))

    this

  # ----------------------------------------------------------------------------------------------------------------
  addIntroPanel: ()->
    options = 
      top: 260 # 290 # 2.5.0
      zIndex: 102
      touchEnabled: false
      opacity: 0

    @container.addChild(@introPanel = new Hy.Panels.IntroPanel(options))

    @introPanel.initialize() 

    this

  # ----------------------------------------------------------------------------------------------------------------
  animateInFinished: ()->
    if not @finishingUp and not @introPanel?
      this.addTitle()
      this.addIntroPanel()
      this.animateInIntroPanelAndTitle()

      @finishedAnimatingIn = true

    Hy.Utils.Deferral.create(0, ()=>PageState.get().resumed())

  # ----------------------------------------------------------------------------------------------------------------
  animateIn: ()->
    @webViewPanel?.fireEvent({kind: "animateIn"}, (event)=>this.animateInFinished())
    this.animateWindow({opacity: 1, duration: 0})
    return -1

  # ----------------------------------------------------------------------------------------------------------------
  animateInIntroPanelAndTitle: ()->

    @introPanel?.animate({opacity:1, duration: 100})
    @title?.animate({opacity:1, duration: 100})

    this

  # ----------------------------------------------------------------------------------------------------------------
  animateOutIntroPanelAndTitle: (fnDone = null)->

    Hy.Trace.debug("IntroPage::animateOutIntroPanelAndTitle")

    animateCount = 0

    fn = (evt)=>
      Hy.Trace.debug("IntroPage::animateOutIntroPanelAndTitle (#{animateCount})")

      if ++animateCount is 2
        fnDone?()
      null

    if true
      @introPanel?.animate({opacity:0, duration: 50}, fn)
      @title?.animate({opacity:0, duration: 50}, fn)
    else
      @introPanel?.setUIProperty("opacity", 0)
      @title?.setUIProperty("opacity", 0)
      fnDone?()

    this

  # ----------------------------------------------------------------------------------------------------------------
  animateOut: ()->

    Hy.Trace.debug("IntroPage::animateOut")

    @clickAllowed = false

    fn = ()=>
      @webViewPanel?.fireEvent({kind: "animateOut"}, (event)=>this.animateOutFinished())
      null

    this.animateOutIntroPanelAndTitle(fn)

    return -1

  # ----------------------------------------------------------------------------------------------------------------
  animateOut2: ()->

    @clickAllowed = false
    @webViewPanel?.fireEvent({kind: "animateOut"}, (event)=>this.animateOutFinished())
    @introPanel?.animate({opacity:0, duration: 100})
    @title?.animate({opacity:0, duration: 100})

    return -1

  # ----------------------------------------------------------------------------------------------------------------
  animateOutFinished: ()->

    duration = 0
    this.animateWindow({opacity: 0, duration: duration}) # 2.5.0
    Hy.Utils.Deferral.create(duration, ()=>PageState.get().resumed())

    this

  # ----------------------------------------------------------------------------------------------------------------

  webViewPanelCreate: ()->

    options = this.containerOptions()
    options._tag = "WebViewPanel"
#    options.borderWidth = 10
#    options.borderColor = Hy.UI.Colors.green

    webViewOptions =
      top: options.top
      left: options.left
      width: options.width
      height: options.height
      _tag: "Intro Page Web View"
      scalesPageToFit:false
      url: "html-intro-page.html"
      zIndex: 50 #@zIndexPassive
      backgroundColor:'transparent' # http://developer.appcelerator.com/question/45491/can-i-change-the-white-background-that-shows-when-a-web-view-is-loading

    @container.addChild(@webViewPanel = new Hy.Panels.WebViewPanel(options, webViewOptions))
 
    this

  # ----------------------------------------------------------------------------------------------------------------
  # Bummed. Steve Jobs just died. 2011 Oct 5.
  # ----------------------------------------------------------------------------------------------------------------

# ==================================================================================================================
class UtilityPage extends Page

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (state, app)->

    @subpanels = []

    super state, app

    this.addCrowdGameLogo()
        .addTitle()

    this

  # ----------------------------------------------------------------------------------------------------------------
  addSubpanel: (subpanel)->

    @container.addChild(subpanel)

    @subpanels.push subpanel

    this

  # ----------------------------------------------------------------------------------------------------------------
  containerOptions: ()->
  
    options = super
    options.zIndex = 90

    options

  # ----------------------------------------------------------------------------------------------------------------
  initialize: ()->

    super

    for panel in @subpanels
      panel.initialize()

    true

  # ----------------------------------------------------------------------------------------------------------------
  obs_networkChanged: (reason)->

    super

    for panel in @subpanels
      panel.obs_networkChanged(reason)

    this

  # ----------------------------------------------------------------------------------------------------------------
  addCrowdGameLogo: ()->
 
    options = 
      top: 20
      left: 30
      image: "assets/icons/CrowdGame.png"
      width: 215
      height: 50
      _tag: "Logo"

    @container.addChild(new Hy.UI.ImageViewProxy(options))

    this

  # ----------------------------------------------------------------------------------------------------------------
  addTitle: ()->

    options = 
      top: 20
      left: (Hy.UI.iPad.screenWidth-316)/2
      image: "assets/icons/label-Trivially.png"
      width: 316
      height: 101
      _tag: "Title"

    @container.addChild(new Hy.UI.ImageViewProxy(options))

    this

# ==================================================================================================================
class AboutPage extends UtilityPage

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (state, app)->

    super state, app

    @restored = false

    this.addSubpanel(this.addAboutPanel())

    this

  # ----------------------------------------------------------------------------------------------------------------
  addAboutPanel: ()->

    fnClickDone = ()=>
      # If we did a restore, we need to reinitialize the content list on the Start Page
      r = @restored
      @restored = false
      this.getApp().showStartPage(if r then [((page)=>page.updateContentOptionsPanel())] else [])
      null

    fnUpdateClicked = (evt, clickedView)=>
      if evt.index is 0
        Hy.Content.ContentManager.get()?.updateManifests()
      null

    fnClickRestore = ()=>
      # Must be online
      if Hy.Network.NetworkService.isOnline() 

        # If an update is available, force it first
        if Hy.Content.ContentManifestUpdate.getUpdate()?
          options = 
            message: "Trivially requires an update before purchases can be restored.\nTap \"update\" to begin"
            buttonNames: ["update", "cancel"]
            cancel: 1
          dialog = new Hy.UI.AlertDialog(options)
          dialog.addEventListener("click", fnUpdateClicked)
        else
          @restored = true
          Hy.Content.ContentManager.get()?.restore() # Let's present the restore UI on the About page
#          this.getApp().restoreAction()
      else
        new Hy.UI.AlertDialog("Please connect to Wifi and try again")

      null

    fnClickJoinHelp = ()=>
      this.getApp().showJoinCodeInfoPage()
      null

    new Hy.Panels.AboutPanel({}, fnClickDone, fnClickRestore, fnClickJoinHelp)

# ==================================================================================================================
class UserCreatedContentInfoPage extends UtilityPage

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (state, app)->

    super state, app

    this.addSubpanel(this.addInfoPanel())

    this

  # ----------------------------------------------------------------------------------------------------------------
  addInfoPanel: ()->

    fnClickDone = ()=>
      this.getApp().showStartPage()
      null

    fnClickBuy = ()=>
      this.getApp().userCreatedContentAction("buy", null, true)
      null
    
    new Hy.Panels.UserCreatedContentInfoPanel({},  fnClickDone, fnClickBuy)

# ==================================================================================================================
class JoinCodeInfoPage extends UtilityPage

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (state, app)->

    super state, app

    this.addSubpanel(this.addInfoPanel())

    this

  # ----------------------------------------------------------------------------------------------------------------
  addInfoPanel: ()->

    fnClickDone = ()=>
      this.getApp().showStartPage()
      null

    new Hy.Panels.JoinCodeInfoPanel({},  fnClickDone)

# ==================================================================================================================
class StartPage extends Page

  _.extend StartPage, Hy.Utils.Observable # For changes to the state of the Start button

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (state, app)->

    super state, app

    @pageEnabled = true

    @startEnabled = {state: false, reason: null}

    fnStart = (evt)=>this.startClicked()

    this.addCrowdGameLogo()
        .addTitle()
        .addAboutPageButton()
        .addGameOptionPanels() 
        .addContentOptionsPanel()
        .addStartButton(fnStart)
        .addStartButtonText()
        .addContentOptionsInfo()
        .addJoinCodeInfo()
        .addUpdateAvailableInfo()
   
    @message = new Hy.Panels.MessageMarquee(this, @container)
    
    this.createCheckInCritterPanel()

    @fnContentPacksChanged = (evt)=>this.contentPacksChanged(evt)

    Hy.Pages.StartPage.addObserver this # For tracking changes to Start Button state

    this

  # ----------------------------------------------------------------------------------------------------------------
  isPageEnabled: ()-> @pageEnabled

  # ----------------------------------------------------------------------------------------------------------------
  setPageEnabled: (enabled)-> 

    @pageEnabled = enabled

    for panel in [@aboutPanel, @joinCodeInfoPanel, @updateAvailablePanel]
      if enabled
        panel?.initialize()
      else
        panel?.setEnabled(false)
   
    StartPage.notifyObservers (observer)=>observer.obs_startPagePageEnabledStateChange?(@pageEnabled)

    this.updateUCCInfo()
    
    this    

  # ----------------------------------------------------------------------------------------------------------------
  containerOptions: ()->
  
    options = super
    options.zIndex = 90

    options

  # ----------------------------------------------------------------------------------------------------------------
  openWindow: (options={})->

    super options

    @contentOptionsPanel.open(options)

    this

  # ----------------------------------------------------------------------------------------------------------------
  closeWindow: (options={})->

    @contentOptionsPanel.close(options)

    super

    this

  # ----------------------------------------------------------------------------------------------------------------
  animateWindow: (options)-> # 2.5.0

    @contentOptionsPanel.animate(options)

    super options

    this

  
  # ----------------------------------------------------------------------------------------------------------------
  start: ()->

    super

    Hy.Options.contentPacks.addEventListener 'change', @fnContentPacksChanged

    Hy.Content.ContentManager.addObserver this # Tracking inventory changes
    Hy.Content.ContentManagerActivity.addObserver this # ContentPack updates

    Hy.Update.Update.addObserver this # as updates become available: "obs_updateAvailable"

    @contentOptionsPanel.start()
    @message.start()
    @checkInCritterPanel.start()

    # Check for required or strongly-urged content or app updates, which appear to the user
    # as a popover, which either allows dismissal, with frequent reminders, or which can't be dismissed, in 
    # the case of required updates.
    # First, make sure we're online and not otherwise busy
    if not Hy.Pages.PageState.get().hasPostFunctions() and Hy.Network.NetworkService.isOnline() 
      if not Hy.Content.ContentManager.get().doUpdateChecks() # Do update checks first
        if not Hy.Update.ConsoleAppUpdate.getUpdate()?.doRequiredUpdateCheck() # Then app updates
          Hy.Update.RateAppReminder.getUpdate()?.doRateAppReminderCheck() # Then rate app requests

    this


  # ----------------------------------------------------------------------------------------------------------------
  stop: ()->

    Hy.Options.contentPacks.removeEventListener 'change', @fnContentPacksChanged

    Hy.Content.ContentManager.removeObserver this
    Hy.Content.ContentManagerActivity.removeObserver this

    Hy.Update.Update.removeObserver this

    @contentOptionsPanel.stop()
    @message.stop()
    @checkInCritterPanel.stop()

    super

    this

  # ----------------------------------------------------------------------------------------------------------------
  pause: ()->
    @message.pause()
    @checkInCritterPanel.pause()

    super

    this

  # ----------------------------------------------------------------------------------------------------------------
  resumed: ()->

    super

    @message.resumed()
    @checkInCritterPanel.resumed()

    # If our state shows that the Start Button was clicked, and we're being resumed, then
    # it's likely that we were backgrounded while preparing a contest. So just reset state and let
    # the user tap the button again if so inclined
    if this.startButtonIsClicked()
      this.resetStartButtonClicked()

    this

  # ----------------------------------------------------------------------------------------------------------------
  initialize: ()->

    super

    this.updateStartButtonEnabledState()

    this.resetStartButtonClicked()

    @aboutPanelButtonClicked = false
    @joinCodeInfoPanelButtonClicked = false
    @updateAvailablePanelButtonClicked = false

    @aboutPanel.initialize()
    @updateAvailablePanel.initialize()
    @joinCodeInfoPanel.initialize()

    if @panelSound?
      @panelSound.syncCurrentChoiceWithAppOption()

    @checkInCritterPanel.initialize()

    @contentOptionsPanel.initialize()

    this.updateUCCInfo()

    true

  # ----------------------------------------------------------------------------------------------------------------
  obs_networkChanged: (reason)->

    super

    if this.isPageEnabled()
      @joinCodeInfoPanel.obs_networkChanged(reason)
      @updateAvailablePanel.obs_networkChanged(reason)

    this

  # ----------------------------------------------------------------------------------------------------------------
  obs_updateAvailable: (update)->

    if this.isPageEnabled()
      if update.isContentManifestUpdate() or update.isConsoleAppUpdate()
        @updateAvailablePanel.obs_updateAvailable()

    this

  # ----------------------------------------------------------------------------------------------------------------
  updateUCCInfo: ()->

    buyButton = @panelUCCInfo.findButtonViewByValue(Hy.Config.Content.kThirdPartyContentBuyText)
    addButton = @panelUCCInfo.findButtonViewByValue(Hy.Config.Content.kThirdPartyContentNewText)
    infoButton = @panelUCCInfo.findButtonViewByValue(Hy.Config.Content.kThirdPartyContentInfoText)

    if this.isPageEnabled()
      isPurchased = Hy.Content.ContentManager.get().getUCCPurchaseItem().isPurchased()
      buyButton?.setEnabled(not isPurchased)
      addButton?.setEnabled(isPurchased)
      infoButton?.setEnabled(true)
    else
      buyButton?.setEnabled(false)
      addButton?.setEnabled(false)
      infoButton?.setEnabled(false)
      
    this

  # ----------------------------------------------------------------------------------------------------------------
  addCrowdGameLogo: ()->

    options = 
      top: 20
      left: 30
      image: "assets/icons/CrowdGame.png"
      width: 215
      height: 50
      _tag: "Logo"

    @container.addChild(@crowdGameLogoView = new Hy.UI.ImageViewProxy(options))

    this


  # ----------------------------------------------------------------------------------------------------------------
  addTitle: ()->

    options = 
      top: 20
      left: (Hy.UI.iPad.screenWidth-316)/2
      image: "assets/icons/label-Trivially.png"
      width: 315
      height: 100
      _tag: "Title"

    @container.addChild(@titleView = new Hy.UI.ImageViewProxy(options))

    this

  # ----------------------------------------------------------------------------------------------------------------
  #
  addAboutPageButton: ()->

    @aboutPanelButtonClicked = false

    fnClick = ()=>
      if @aboutPanel.isEnabled() and not @aboutPanelButtonClicked
        @aboutPanelButtonClicked = true
        this.getApp().showAboutPage()
      null

    # We take our cues from other screen elements: CrowdGame Logo image, Trivially label
    options = 
      top: @titleView.getUIProperty("top")
      right: @crowdGameLogoView.getUIProperty("left")
      title: "?"
      font: Hy.UI.Fonts.specBigNormal
      _tag: "About Button"

    buttonOptions = 
      title: "?"
      font: Hy.UI.Fonts.specBigNormal

    topTextOptions = {}
    bottomTextOptions = {text: "Help"}

    @container.addChild(@aboutPanel = new Hy.Panels.LabeledButtonPanel(options, buttonOptions, fnClick, topTextOptions, bottomTextOptions))

    this

  # ----------------------------------------------------------------------------------------------------------------
  obs_contentUpdateSessionStarted: (label, report)->

#    @message.startAdHocSession(label)

    this.updateStartButtonEnabledState()

    this.setPageEnabled(false)

#    if report?
#      @message.addAdHoc(report)

    this

  # ----------------------------------------------------------------------------------------------------------------
  obs_contentUpdateSessionProgressReport: (report, percentDone = -1)->
    Hy.Trace.debug "StartPage::contentUpdateSessionProgressReport (#{report} / #{percentDone})"

    if percentDone isnt -1
       report += " (#{percentDone}% done)"

#    if report?
#      @message.addAdHoc report

    this

  # ----------------------------------------------------------------------------------------------------------------
  obs_contentUpdateSessionCompleted: (report, changes)->
    Hy.Trace.debug "StartPage::contentUpdateSessionCompleted #{report}"

#    @message.addAdHoc(report)
#    @message.endAdHocSession()

    this.updateStartButtonEnabledState()

    this.setPageEnabled(true)

    @updateAvailablePanel.initialize()

    this

  # ----------------------------------------------------------------------------------------------------------------
  obs_inventoryInitiated: ()->

    @message.startAdHocSession("Syncing with Apple App Store")

    @message.addAdHoc("Contacting Store")

    this
  # ----------------------------------------------------------------------------------------------------------------
  obs_inventoryUpdate: (status, message)->

    if message?
      @message.addAdHoc(message)

    this

  # ----------------------------------------------------------------------------------------------------------------
  obs_inventoryCompleted: (status, message)->
    if message?
      @message.addAdHoc(message)

    @message.endAdHocSession()

    this

  # ----------------------------------------------------------------------------------------------------------------
  obs_purchaseInitiated: (label, report)->

    this.updateStartButtonEnabledState()

    this.setPageEnabled(false)

#    @message.startAdHocSession(label)

#    if report?
#      @message.addAdHoc(report)

    this

  # ----------------------------------------------------------------------------------------------------------------
  obs_purchaseProgressReport: (report)->
    Hy.Trace.debug "StartPage::purchaseProgressReport #{report}"
   
#    if report?
#      @message.addAdHoc(report)

    null

  # ----------------------------------------------------------------------------------------------------------------
  obs_purchaseCompleted: (report)->
    this.updateStartButtonEnabledState()

    this.setPageEnabled(true)

    this.updateUCCInfo()

#    if report?
#      @message.addAdHoc(report)

#    @message.endAdHocSession()

    null

  # ----------------------------------------------------------------------------------------------------------------
  obs_restoreInitiated: (report)->
    this.updateStartButtonEnabledState()

    this.setPageEnabled(false)

#    @message.startAdHocSession("Restore of purchases")

#    if report?
#      @message.addAdHoc(report)

    null

  # ----------------------------------------------------------------------------------------------------------------
  obs_restoreProgressReport: (report)->

#    if report?
#      @message.addAdHoc(report)

    null

  # ----------------------------------------------------------------------------------------------------------------
  obs_restoreCompleted: (report)->
    this.updateStartButtonEnabledState()

    this.setPageEnabled(true)

#    if report?
#      @message.addAdHoc(report)

#    @message.endAdHocSession()

    null

  # ----------------------------------------------------------------------------------------------------------------
  addStartButton: (fn)->

    options = 
      height: 110
      width: 110
      top: 415
      left: 277
      zIndex: 101
      backgroundImage: "assets/icons/button-play.png"
      backgroundSelectedImage: "assets/icons/button-play-selected.png"
      _tag: "Start Button"

    @container.addChild(@startButton = new Hy.UI.ButtonProxy(options))

    this.resetStartButtonClicked()

    @fnClickStartGame = (evt)=>
      if @startEnabled.state
        if not this.startButtonIsClicked()
          this.setStartButtonClicked()
          fn()
      null

    @startButton.addEventListener 'click', @fnClickStartGame
    this

  # ----------------------------------------------------------------------------------------------------------------
  startButtonIsClicked: ()-> @startButtonClicked

  # ----------------------------------------------------------------------------------------------------------------
  setStartButtonClicked: ()-> @startButtonClicked = true

  # ----------------------------------------------------------------------------------------------------------------
  resetStartButtonClicked: ()->
    @startButtonClicked = false

  # ----------------------------------------------------------------------------------------------------------------
  getStartEnabled: ()-> [@startEnabled.state, @startEnabled.reason]

  # ----------------------------------------------------------------------------------------------------------------
  setStartEnabled: (state, reason)->

    @startEnabled.state = state
    @startEnabled.reason = reason

    @startButton.setEnabled(state)

    this.setContentOptionsInfo(state, reason)

    StartPage.notifyObservers (observer)=>observer.obs_startPageStartButtonStateChanged?(state, reason)
    
    this

  # ----------------------------------------------------------------------------------------------------------------
  addStartButtonText: ()->

    width = 200

    options = 
      top: @startButton.getUIProperty("top") + 120
      left: @startButton.getUIProperty("left") - ((width-@startButton.getUIProperty("width"))/2)
      width: width
      height: 50
      text: "Start Game"
      font: Hy.UI.Fonts.specMediumMrF
      zIndex:@startButton.getUIProperty("zIndex")
      textAlign: 'center'
      _tag: "Start Game Label"

    @container.addChild(@startButtonTextView = new Hy.UI.LabelProxy(options))

    this

  # ----------------------------------------------------------------------------------------------------------------
  # "1 topic selected", etc
  #
  addContentOptionsInfo: ()->

    width = 70

    options =
      top: @startButton.getUIProperty("top")
      left: @startButton.getUIProperty("left") - (width + 20)
      width: width
      height:  @startButton.getUIProperty("height")
      font: Hy.UI.Fonts.specMinisculeNormal
      color: Hy.UI.Colors.black
      zIndex:@startButton.getUIProperty("zIndex")
      textAlign: 'center'
      _tag: "Content Options Info"
#      borderColor: Hy.UI.Colors.white

    @container.addChild(@contentOptionsPanelInfoView = new Hy.UI.LabelProxy(options))

    this

  # ----------------------------------------------------------------------------------------------------------------
  setContentOptionsInfo: (state, info = null)->

    @contentOptionsPanelInfoView.setUIProperty("color", if state then Hy.UI.Colors.black else Hy.UI.Colors.MrF.Red)
    @contentOptionsPanelInfoView.setUIProperty("text", info)

    this

  # ----------------------------------------------------------------------------------------------------------------
  # We position this relative to the ? About Page Button...
  #
  addJoinCodeInfo: ()->

    @joinCodeInfoPanelButtonClicked = false

    fnClick = ()=>
      if @joinCodeInfoPanel.isEnabled() and not @joinCodeInfoPanelButtonClicked
        @joinCodeInfoPanelButtonClicked = true
        this.getApp().showJoinCodeInfoPage()
      null

    options =
      bottom: @startButtonTextView.getUIProperty("bottom") - 20
      left: 50

    @container.addChild(@joinCodeInfoPanel = new Hy.Panels.CodePanel(options, fnClick))

    this

  # ----------------------------------------------------------------------------------------------------------------
  # We position this relative to the ? About Page Button...
  #
  addUpdateAvailableInfo: ()->

    @updateAvailablePanelButtonClicked = false

    fnClick = (e, v)=>
      if @updateAvailablePanel.isEnabled() and not @updateAvailablePanelButtonClicked
        @updateAvailablePanelButtonClicked = true

        if Hy.Network.NetworkService.isOnline()
           # Check for Content Update, then App Update
          if Hy.Content.ContentManifestUpdate.getUpdate()?
            Hy.Content.ContentManager.get()?.updateManifests()
          else if (update = Hy.Update.ConsoleAppUpdate.getUpdate())?
            update.doURL()

        @updateAvailablePanelButtonClicked = false
      null

    options =
      top: @startButton.getUIProperty("top") - 20
      left: 50

    @container.addChild(@updateAvailablePanel = new Hy.Panels.UpdateAvailablePanel(options, fnClick))

    this

  # ----------------------------------------------------------------------------------------------------------------
  addGameOptionPanels: ()->

    top = 93 #130 #155
    left = 85 #75
    padding = 55

    panelSpecs = [
      {varName: "panelSound",              fnName: "createSoundPanel",                   options: {left: left}},
      {varName: "panelNumberOfQuestions",  fnName: "createNumberOfQuestionsPanel",       options: {left: left}},
      {varName: "panelSecondsPerQuestion", fnName: "createSecondsPerQuestionPanel",      options: {left: left}},
      {varName: "panelFirstCorrect",       fnName: "createFirstCorrectPanel",            options: {left: left}},
      {varName: "panelUCCInfo",            fnName: "createUserCreatedContentInfoPanel2", options: {left: left}}
      ]

    for panelSpec in panelSpecs
      this[panelSpec.varName] = Hy.Panels.OptionPanels[panelSpec.fnName](this, Hy.UI.ViewProxy.mergeOptions(panelSpec.options, {top: top}))
      @container.addChild(this[panelSpec.varName])

      top += padding

    this

  # ----------------------------------------------------------------------------------------------------------------
  addContentOptionsPanel: ()->

    options = 
      top: 100
      right: 80

    @container.addChild(@contentOptionsPanel = new Hy.Panels.ContentOptionsPanel(this, options))

    this

  # ----------------------------------------------------------------------------------------------------------------
  updateContentOptionsPanel: ()->

    Hy.Trace.debug "StartPage::updateContentOptionsPanel"

    @contentOptionsPanel?.update()

    this

  # ----------------------------------------------------------------------------------------------------------------
  obs_userCreatedContentSessionStarted: (label, report = null)->

    this.updateStartButtonEnabledState()

    this.setPageEnabled(false)

#    @message.startAdHocSession(label)

#    @message.addAdHoc(if report? then report else "Starting... This will only take a moment...")

    this

  # ----------------------------------------------------------------------------------------------------------------
  obs_userCreatedContentSessionProgressReport: (report = null)->

#    if report?
#      @message.addAdHoc(report)

    this

  # ----------------------------------------------------------------------------------------------------------------
  obs_userCreatedContentSessionCompleted: (report = null, changes = false)->

    this.updateUCCInfo()

    this.updateStartButtonEnabledState()

    this.setPageEnabled(true)

#    @message.addAdHoc(if report? then report else "Completed")

#    @message.endAdHocSession()

    this

  # ----------------------------------------------------------------------------------------------------------------
  createCheckInCritterPanel: ()->

    options = 
      left: 0
      bottom: 0

    @container.addChild(@checkInCritterPanel = new Hy.Panels.CheckInCritterPanel(options))
    this

  # ----------------------------------------------------------------------------------------------------------------
  startClicked: ()->
    
    Hy.Utils.Deferral.create 0, ()=>this.getApp().contestStart() # must use deferral to trigger startContest outside of event handler
   
    this

  # ----------------------------------------------------------------------------------------------------------------
  updateStartButtonEnabledState: ()->
    Hy.Trace.debug "StartPage::updateStartButtonEnabledState"

    reason = null
    state = false

    numTopics = _.size(_.select(Hy.Content.ContentManager.get().getLatestContentPacksOKToDisplay(), (c)=>c.isSelected()))

    if numTopics <= 0
      reason = "No topics selected!"
      state = false
    else
      state = true
      reason = "#{numTopics} topic#{if numTopics > 1 then "s" else ""} selected"

    if (r = Hy.Content.ContentManager.isBusy())?
      reason = "Please wait: #{r}"
      state = false

    this.setStartEnabled(state, reason)

    this

  # ----------------------------------------------------------------------------------------------------------------
  categoriesChanged: (evt)->
    this.updateStartButtonEnabledState()

  # ----------------------------------------------------------------------------------------------------------------
  contentPacksChanged: (evt)->
    this.updateStartButtonEnabledState()

  # ----------------------------------------------------------------------------------------------------------------
  contentPacksLoadingStart: ()->
    @message.startAdHocSession("Preparing Contest")

  # ----------------------------------------------------------------------------------------------------------------
  contentPacksLoadingCompleted: ()->
    @message.endAdHocSession()

  # ----------------------------------------------------------------------------------------------------------------
  contentPacksLoading: (report)->
    @message.addAdHoc(report)

# ==================================================================================================================
class NotifierPage extends Page
  # ----------------------------------------------------------------------------------------------------------------
  constructor: (state, app)->
    super state, app

    @fnNotify = null

    this

  # ----------------------------------------------------------------------------------------------------------------
  initialize: (fnNotify)->
    super

    @fnNotify = fnNotify

    true

  # ----------------------------------------------------------------------------------------------------------------
  start: ()->
    super

    @fnNotify?()

    this
    
  # ----------------------------------------------------------------------------------------------------------------
  resumed: ()->

    super

    @fnNotify?()

    this

# ==================================================================================================================

class BasePage extends NotifierPage

  constructor: (state, app)->
    super state, app

    @container.addChild(@questionInfoPanel = new Hy.Panels.QuestionInfoPanel(this.questionInfoPanelOptions()))

    this

  # ----------------------------------------------------------------------------------------------------------------
  labelColor: ()->
    Hy.UI.Colors.white

  # ----------------------------------------------------------------------------------------------------------------
  questionInfoPanelOptions: ()->
    {}

# ==================================================================================================================
# adds support for pause button and countdown

class CountdownPage extends BasePage

  kCountdownStateUndefined = 0
  kCountdownStateRunning   = 1
  kCountdownStatePaused    = 2

  @kWidth = 164

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (state, app)->

    super state, app

    @fnPause = null
    @fnCompleted = null

    @pauseClicked = false
    @overlayClicked = false
    @overlayShowing = false

    @currentCountdownValue = null
    @countdownSeconds = 0
    @startingDelay = 0
    @countdownDeferral = null

    @fnPauseClick = (evt)=>
      if not @pauseClicked
        @pauseClicked = true
        this.click()
      null

    @fnClickContinueGame = ()=>
      this.continue_()
      @overlayClicked = false
      @pauseClicked = false
      null

    @fnClickNewGame = ()=>
      @overlayClicked = false
      @pauseClicked = false
      this.getApp().contestRestart(false)
      null

    @fnClickForceFinish = ()=>
      @overlayClicked = false
      @pauseClicked = false
      this.getApp().contestForceFinish()
      null


    @container.addChild(@countdownPanel = new Hy.Panels.CountdownPanel(this.countdownPanelOptions(), @fnPauseClick))

    @container.addChild(this.createPauseButton(this.pauseButtonOptions()))
    @container.addChild(this.createPauseButtonText(this.pauseButtonTextOptions()))

    this

  # ----------------------------------------------------------------------------------------------------------------
  countdownPanelOptions: ()->

    {}

  # ----------------------------------------------------------------------------------------------------------------
  pauseButtonOptions: ()->

    {}

  # ----------------------------------------------------------------------------------------------------------------
  pauseButtonTextOptions: ()->

    {}
  # ----------------------------------------------------------------------------------------------------------------
  pause: ()->
    return if @countdownState is kCountdownStatePaused
    @countdownState = kCountdownStatePaused
    this.disablePause()
    @countdownTicker?.pause()
    this.showOverlay({opacity:1, duration: 200})
#    Hy.Network.NetworkService.get().setImmediate()
    @fnPause()

  # ----------------------------------------------------------------------------------------------------------------
  resumed: ()->
    super
    this.pause()

    this

  # ----------------------------------------------------------------------------------------------------------------
  continue_: ()->
    return if @countdownState is kCountdownStateRunning
#    Hy.Network.NetworkService.get().setSuspended()
    @countdownState = kCountdownStateRunning

    f = ()=>
      this.enablePause()
      @countdownTicker?.continue_()
      @fnNotify()

    this.hideOverlay({opacity:0, duration: 200}, f)

    this

  # ----------------------------------------------------------------------------------------------------------------
  start: ()->
    super

    this.initCountdown()

    this

  # ----------------------------------------------------------------------------------------------------------------
  stop: ()->

    this.haltCountdown()

    super

    this

  # ----------------------------------------------------------------------------------------------------------------
  haltCountdown: ()->

    @countdownDeferral.clear() if @countdownDeferral?.enqueued()
    @countdownTicker?.exit()
    this

  # ----------------------------------------------------------------------------------------------------------------
  initialize: (fnNotify, fnPause, fnCompleted, countdownSeconds, startingDelay)->

    super fnNotify

    @countdownState = kCountdownStateUndefined

    @fnPause = fnPause
    @fnCompleted = fnCompleted

    @currentCountdownValue = null
    @countdownSeconds = countdownSeconds
    @startingDelay = startingDelay

    @pauseClicked = false
    @overlayClicked = false

    this.hideOverlayImmediate()
    this.enablePause()

    this.getCountdownPanel().initialize().animateCountdown(this.countdownAnimationOptions(@countdownSeconds), @countdownSeconds, null, true)

    true

  # ----------------------------------------------------------------------------------------------------------------
  obs_networkChanged: (reason)->

    Hy.Trace.debug("QuestionPage::obs_networkChanged (isPaused=#{this.isPaused()})")
    super

    if this.isPaused()
      this.updateConnectionInfo(reason)

    this

  # ----------------------------------------------------------------------------------------------------------------
  createPauseButton: (options)->

    defaultOptions = 
      zIndex: 101
      backgroundImage: "assets/icons/button-pause-question-page.png"
      _tag: "Pause"

    @pauseButton = new Hy.UI.ButtonProxy(Hy.UI.ViewProxy.mergeOptions(defaultOptions, options))

    f = ()=>
      @fnPauseClick()
      null

    @pauseButton.addEventListener("click", f)

    @pauseButton

  # ----------------------------------------------------------------------------------------------------------------
  createPauseButtonText: (options)->

    defaultOptions = 
      zIndex: 101
      text: 'Pause'
      font: Hy.UI.Fonts.specTinyMrF
      color: Hy.UI.Colors.MrF.DarkBlue
      height: 'auto'
      textAlign: 'center'
      _tag: "Pause Text"

    @pauseButtonText = new Hy.UI.LabelProxy(Hy.UI.ViewProxy.mergeOptions(defaultOptions, options))

    @pauseButtonText

  # ----------------------------------------------------------------------------------------------------------------
  getCountdownPanel: ()->
    @countdownPanel

  # ----------------------------------------------------------------------------------------------------------------
  animateCountdown: (init, value)->

    this.getCountdownPanel().animateCountdown(this.countdownAnimationOptions(value), value, @countdownSeconds, init)

    this

  # ----------------------------------------------------------------------------------------------------------------
  countdownAnimationOptions: (value)->

    _style: "normal"

  # ----------------------------------------------------------------------------------------------------------------
  playCountdownSound: (value)->
    if (event = this.countdownSound(value))?
      Hy.Media.SoundManager.get().playEvent(event)

    this

  # ----------------------------------------------------------------------------------------------------------------
  initCountdown: ()->
    @countdownState = kCountdownStateRunning
    @countdownDeferral = null if @countdownDeferral?.triggered()

    fnInitView = (value)=>
      @currentCountdownValue = value
      this.animateCountdown(true, value)

    fnUpdateView = (value)=>
      @currentCountdownValue = value
      this.animateCountdown(false, value)

    fnCompleted = (evt)=>this.countdownCompleted()
    fnSound = (value)=>this.playCountdownSound(value)
    @countdownTicker = new CountdownTicker(fnInitView, fnUpdateView, fnCompleted, fnSound)

    @countdownTicker.init(@countdownSeconds, @startingDelay)

    this

  # ----------------------------------------------------------------------------------------------------------------
  getCountdownStartValue: ()-> @countdownSeconds

  # ----------------------------------------------------------------------------------------------------------------
  getCountdownValue: ()->
#    @countdownTicker?.getValue()     # This isn't reliable, if console user answers
     @currentCountdownValue

  # ----------------------------------------------------------------------------------------------------------------
  countdownSound: (value)->
    null

  # ----------------------------------------------------------------------------------------------------------------
  countdownCompleted: ()->

    this.disablePause()

    @fnCompleted()

  # ----------------------------------------------------------------------------------------------------------------
  click: (evt)->
    this.pause() if @countdownState is kCountdownStateRunning

  # ----------------------------------------------------------------------------------------------------------------
  disablePause: ()->
    for view in [@pauseButton, @pauseButtonText]
      view?.animate({duration: 100, opacity: 0})
      view?.hide()

    this

  # ----------------------------------------------------------------------------------------------------------------
  enablePause: ()->
    for view in [@pauseButton, @pauseButtonText]
#      view?.animate({duration: 100, opacity: 1})
      view?.setUIProperty("opacity", 1)
      view?.show()

    this

  # ----------------------------------------------------------------------------------------------------------------
  isPaused: ()->
    @countdownState is kCountdownStatePaused  

  # ----------------------------------------------------------------------------------------------------------------
  createOverlay: ()->
    container = this.overlayContainer()

    overlayBkgndOptions = 
      top: 0
      bottom: 0
      left: 0
      right: 0
      backgroundImage: Hy.UI.Backgrounds.pixelOverlay
      zIndex: 200
      opacity: 0
      _tag: "Overlay Background"

    container.addChild(@overlayBkgnd = new Hy.UI.ViewProxy(overlayBkgndOptions))

    overlayFrameOptions =  
      top: 100
      bottom: 100
      left: 100
      right: 100
      borderColor: Hy.UI.Colors.white
      borderRadius: 16
      borderWidth: 4
      zIndex: 201
#      _alignment: "center"
      opacity: 0
      _tag: "Overlay Frame"
    
    container.addChild(@overlayFrame = new Hy.UI.ViewProxy(overlayFrameOptions))

    elementOptions = 
      width: 400
    
    @overlayFrame.addChild(this.overlayBody(elementOptions))

    this
    
  # ----------------------------------------------------------------------------------------------------------------
  showOverlay: (options, fnDone = null)->

    fn = ()=>
      if fnDone? 
        Hy.Utils.Deferral.create(0, fnDone)
      null

    if not @overlayBkgnd?
      this.createOverlay()

    this.updateConnectionInfo()

    @panelSound?.syncCurrentChoiceWithAppOption()

    for view in [@overlayBkgnd, @overlayFrame]
      view.setUIProperty("opacity", 0)
      view.show()

    @overlayBkgnd.animate(options, ()=>)
    @overlayFrame.animate(options, fn)

    this

  # ----------------------------------------------------------------------------------------------------------------
  hideOverlayImmediate: ()->

    for view in [@overlayBkgnd, @overlayFrame]
      view?.hide()

    this

  # ----------------------------------------------------------------------------------------------------------------
  hideOverlay: (options, fnDone = null)->

    fn = ()=>
      for view in [@overlayBkgnd, @overlayFrame]
        view?.hide()
      if fnDone?
        Hy.Utils.Deferral.create(0, fnDone)
      null

    if @overlayBkgnd?
      @overlayFrame.animate(options, ()=>)
      @overlayBkgnd.animate(options, fn)
    else
      fn()

    this

  # ----------------------------------------------------------------------------------------------------------------
  overlayContainer: ()->
    @container

  # ----------------------------------------------------------------------------------------------------------------
  overlayBody: (elementOptions)->

    options = 
      backgroundImage: Hy.UI.Backgrounds.pixelOverlay
      _tag: "Overlay Body"

    body = new Hy.UI.ViewProxy(options)

    body.addChild(this.createGamePausedText())

    top = 170 #200
    verticalPadding = 90 #elementOptions.height + 15 #25
    textOffset = 125

    horizontalPadding = 20

    choiceOptions = 
      _style: "plainOnDarkBackground"

    @panelSound = Hy.Panels.OptionPanels.createSoundPanel(this, Hy.UI.ViewProxy.mergeOptions(elementOptions, {top:top}), {font: Hy.UI.Fonts.specBigNormal, color: Hy.UI.Colors.white, _attach: "right"}, choiceOptions)
    body.addChild(@panelSound)

    continueGame = this.createOverlayButtonPanel(Hy.UI.ViewProxy.mergeOptions(elementOptions, {top: (top += verticalPadding)}), {backgroundImage: "assets/icons/button-play-small-blue.png", left: horizontalPadding}, {left: textOffset, text: "Continue Game"}, @fnClickContinueGame)
    body.addChild(continueGame)

    forceFinishGame = this.createOverlayButtonPanel(Hy.UI.ViewProxy.mergeOptions(elementOptions, {top: (top += verticalPadding)}), {backgroundImage: "assets/icons/button-cancel.png", left: horizontalPadding}, {left: textOffset, text: "Finish Game"}, @fnClickForceFinish)
    body.addChild(forceFinishGame)

    newGame = this.createOverlayButtonPanel(Hy.UI.ViewProxy.mergeOptions(elementOptions, {top: (top += verticalPadding)}), {backgroundImage: "assets/icons/button-restart.png", left: horizontalPadding}, {left: textOffset, text: "Restart Game"}, @fnClickNewGame)
    body.addChild(newGame)

    @connectionInfo = this.createConnectionInfo(Hy.UI.ViewProxy.mergeOptions(elementOptions, {top: (top += verticalPadding)}))
    this.updateConnectionInfo()
    body.addChild(@connectionInfo)

    body


  # ----------------------------------------------------------------------------------------------------------------
  updateConnectionInfo: (reason = "Wifi")->

    text = ""

    if reason is "Wifi"
      if Hy.Network.NetworkService.isOnlineWifi()
        if (encoding = Hy.Network.NetworkService.getAddressEncoding())?
          text = "Additional players? Visit #{Hy.Config.Rendezvous.URLDisplayName} and enter: #{encoding}"

      @connectionInfo?.setUIProperty("text", text)

    this

  # ----------------------------------------------------------------------------------------------------------------
  createConnectionInfo: (commonOptions)->

    options = 
      width: 600
      font: Hy.UI.Fonts.specSmallNormal
      color: Hy.UI.Colors.white
      _tag: "Connection Info"
      height: 'auto'
      textAlign: 'center'
      _tag: "Connection Info"

    new Hy.UI.LabelProxy(Hy.UI.ViewProxy.mergeOptions(commonOptions, options))


  # ----------------------------------------------------------------------------------------------------------------
  createGamePausedText: ()->

    gamePausedOptions = 
      text: 'Game Paused'
      font: Hy.UI.Fonts.specGiantMrF
      color: Hy.UI.Colors.white
      top: 50
      height: 'auto'
      textAlign: 'center'
      _tag: "Game Paused"

    new Hy.UI.LabelProxy(gamePausedOptions)

  # ----------------------------------------------------------------------------------------------------------------
  createOverlayButtonPanel: (containerOptions, buttonOptions, labelOptions, fnClick)->

    options = 
      height: 72
      _tag: "Overlay Button Panel"

    container = new Hy.UI.ViewProxy(Hy.UI.ViewProxy.mergeOptions(options, containerOptions))

    f = ()=>
      if not @overlayClicked
        @overlayClicked = true
        fnClick()
      null

    defaultButtonOptions = 
      height: 72
      width: 72
      left: 0
      _tag: "Overlay Button"

    button = new Hy.UI.ButtonProxy(Hy.UI.ViewProxy.mergeOptions(defaultButtonOptions, buttonOptions))
    button.addEventListener 'click', f
    container.addChild(button)

    defaultLabelOptions = 
      font: Hy.UI.Fonts.specBigNormal
      color: Hy.UI.Colors.white
      _tag: "Overlay Label"

    container.addChild(new Hy.UI.LabelProxy(Hy.UI.ViewProxy.mergeOptions(defaultLabelOptions, labelOptions)))

    container

# ==================================================================================================================
class QuestionPage extends CountdownPage

  kQuestionBlockHeight = 215
  kQuestionBlockWidth = 944

  kQuestionInfoHeight = kQuestionInfoWidth = 86

  kQuestionBlockHorizontalMargin = (Hy.UI.iPad.screenWidth - kQuestionBlockWidth)/2
#  kQuestionBlockVerticalMargin = 30
  kQuestionBlockVerticalMargin = 25

  kQuestionTextMargin = 10
  kQuestionTextWidth = kQuestionBlockWidth - (kQuestionTextMargin + kQuestionInfoWidth)
  kQuestionTextHeight = kQuestionBlockHeight - (2*kQuestionTextMargin)

  kAnswerBlockWidth = 460
  kAnswerBlockHeight = 206
  kAnswerBlockHorizontalPadding = 24
  kAnswerBlockVerticalPadding = 15

#  kAnswerContainerVerticalMargin = 20
  kAnswerContainerVerticalMargin = 7
  kAnswerContainerHorizontalMargin = kQuestionBlockHorizontalMargin
  kAnswerContainerWidth = (2*kAnswerBlockWidth) + kAnswerBlockHorizontalPadding
  kAnswerContainerHeight = (2*kAnswerBlockHeight) + kAnswerBlockVerticalPadding

  kAnswerLabelWidth = 60
  kAnswerTextMargin = 10
  kAnswerTextHeight = kAnswerBlockHeight - (2*kAnswerTextMargin)
  kAnswerTextWidth = kAnswerBlockWidth - ((2*kAnswerTextMargin) + kAnswerLabelWidth)
  kCountdownClockHeight = kCountdownClockWidth = 86

  kButtonOffset = 5

  kPauseButtonHeight = kPauseButtonWidth = 86
  kPauseButtonVerticalMargin = kQuestionBlockVerticalMargin + kQuestionBlockHeight - (kPauseButtonHeight - kButtonOffset)
  kPauseButtonHorizontalMargin = kQuestionBlockHorizontalMargin - 20

  kQuestionInfoVerticalMargin = kQuestionBlockVerticalMargin - kButtonOffset
  kQuestionInfoHorizontalMargin = kQuestionBlockHorizontalMargin - 20

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (state, app)->

    @zIndexPassive = 110
    @zIndexActive = 150

    @top = 0

    @sound = null
    super state, app

    @soundCounter ||= 0
    @soundKeys = ["countDown_0", "countDown_1", "countDown_2", "countDown_3", "countDown_4"]

    @nSounds = @soundKeys.length

    @pageImage = null

    this.webViewPanelCreate()

    @container.addChild(this.createQuestionBlock())
    @container.addChild(this.createAnswerBlocks())

    this.createAnswerCritterPanel()

    @questionTestCount = 0
    @answerTestCount = 0

    # It's important that these all share the same view, due to the overlapping nature of the animations
    [@animateInLongScenes, @animateInLongSceneDuration] = this.buildAnimationFromScenes(this.initAnimateInLongScenes())
    [@animateInShortScenes, @animateInShortSceneDuration] = this.buildAnimationFromScenes(this.initAnimateInShortScenes(), @animateInLongScenes)
    [@animateOutScenes, @animateOutSceneDuration] = this.buildAnimationFromScenes(this.initAnimateOutScenes(), @animateInShortScenes)

    this

  # ----------------------------------------------------------------------------------------------------------------
  countdownPanelOptions: ()->
    top     : kQuestionBlockVerticalMargin + kQuestionBlockHeight + kAnswerContainerVerticalMargin + (kAnswerContainerHeight - kCountdownClockHeight)/2
    left    : kAnswerContainerHorizontalMargin + (kAnswerContainerWidth - kCountdownClockWidth)/2
    height  : kCountdownClockHeight
    width   : kCountdownClockWidth
    zIndex  : @zIndexActive + 2

  # ----------------------------------------------------------------------------------------------------------------
  pauseButtonOptions: ()->
    zIndex : @zIndexActive + 2
    height : kPauseButtonHeight
    width  : kPauseButtonWidth
    top    : kPauseButtonVerticalMargin
    right  : kPauseButtonHorizontalMargin

  # ----------------------------------------------------------------------------------------------------------------
  pauseButtonTextOptions: ()->
    textHeight = 25
    buttonOptions = this.pauseButtonOptions()

    options = 
      top    : buttonOptions.top - (textHeight + 5)
      right  : buttonOptions.right
      width  : buttonOptions.width
      height : textHeight
      zIndex : buttonOptions.zIndex

    options

  # ----------------------------------------------------------------------------------------------------------------
  questionInfoPanelOptions: ()->
    top   : kQuestionInfoVerticalMargin
    right : kQuestionInfoHorizontalMargin

  # ----------------------------------------------------------------------------------------------------------------
  start: ()->
    super

    this.clearAnimation()

    @sound?.play()

    if not @showingAnswers 
      @answerCritterPanel.start()

    this

  # ----------------------------------------------------------------------------------------------------------------
  stop: ()->

    @sound.stop() if @sound?.isPlaying()

    if @showingAnswers 
      @answerCritterPanel.stop()

    super

    this

  # ----------------------------------------------------------------------------------------------------------------
  pause: ()->
    @sound.pause() if @sound?.isPlaying()
    @answerCritterPanel.pause()

    super

    this

  # ----------------------------------------------------------------------------------------------------------------
  resumed: ()->

    super

    @sound.play() if @sound? and not @sound.isPlaying()
    @answerCritterPanel.resumed()

    this

  # ----------------------------------------------------------------------------------------------------------------
  closeWindow: (options={})->

    @webViewPanel?.close()

    super

    this
  
  # ----------------------------------------------------------------------------------------------------------------
  openWindow: (options={})->

    super options

    this

  # ----------------------------------------------------------------------------------------------------------------
  continue_: ()->

    super

    @sound.play() if @sound? and not @sound.isPlaying()

    this

  # ----------------------------------------------------------------------------------------------------------------
  initializeForQuestion: (fnNotify, fnPause, fnCompleted, countdownSeconds, startingDelay, contestQuestion, iQuestion, nQuestions)->

    @showingAnswers = false
    @consoleAnswered = false
    @showingAnswersClicked = false

    this.initialize fnNotify, fnPause, fnCompleted, countdownSeconds, startingDelay, contestQuestion, iQuestion, nQuestions

    @answerCritterPanel.initialize()

    # apparently, the window has to be open in order for the webview to work...
    @window.setUIProperty("opacity", 0)
    this.animateChildren({duration: 0, opacity: 0})

    this.openWindow()

    @webViewPanel?.initialize(()=>this.webViewPanelContentInitialize())

    false

  # ----------------------------------------------------------------------------------------------------------------
  initializeForAnswers: (fnNotify, fnPause, fnCompleted, countdownSeconds, startingDelay)->

    @showingAnswers = true

    this.initialize fnNotify, fnPause, fnCompleted, countdownSeconds, startingDelay, @contestQuestion, @iQuestion, @nQuestions

    this.revealAnswer()

    true
  
  # ----------------------------------------------------------------------------------------------------------------
  initialize: (fnNotify, fnPause, fnCompleted, countdownSeconds, startingDelay, contestQuestion, iQuestion, nQuestions)->

    super

    @contestQuestion = contestQuestion
    @iQuestion = iQuestion
    @nQuestions = nQuestions

    @sound?.reset()

    @questionInfoPanel.initialize @iQuestion+1, @nQuestions, this.labelColor()

    true

  # ----------------------------------------------------------------------------------------------------------------
  initAnimateInLongScenes: ()->

    [
      {image: "splash", imageOptions: {zIndex: 200, top: 0, left: 0, right: 0, bottom: 0}, animationOptions: [{_incrementalDelay: 500, duration: 400, _startOpacity: 1.0, opacity: 0.0, _waitForWindowFn: ((fn)=>this.webViewPanelWait(fn))}]}
    ]

  # ----------------------------------------------------------------------------------------------------------------
  initAnimateInShortScenes: ()->

    [
      {image: "black", imageOptions: {zIndex: 200, top: 0, left: 0, right: 0, bottom: 0}, animationOptions: [{_incrementalDelay: 0, duration: 400, _startOpacity: 1.0, opacity: 0.0, _waitForWindowFn: ((fn)=>this.webViewPanelWait(fn))}]}
    ]

  # ----------------------------------------------------------------------------------------------------------------
  initAnimateOutScenes: ()->

    [
      {image: "black", imageOptions: {zIndex: 200, top: 0, left: 0, right: 0, bottom: 0, opacity: 0}, animationOptions: [{_incrementalDelay: 0, duration: 400, _startOpacity: 0, opacity: 1.0}]}
    ]

  # ----------------------------------------------------------------------------------------------------------------
  # Animates all child views EXCEPT the web view, which we animate separately
  #
  animateChildren: (options)->

    for child in @container.getChildren()
      if child isnt @webViewPanel
        if options.opacity?
          child.setUIProperty("opacity", options.opacity)
#        child.animate(options)
    this

  # ----------------------------------------------------------------------------------------------------------------
  animateIn: (useCurtains = false)->
    Hy.Trace.debug "QuestionPage::animateIn (ENTER)"

    @webViewPanel?.fireEvent({kind: "animateIn", data: {useCurtains: useCurtains}}, (event)=>this.animateInFinished())
    this.animateWindow({opacity: 1, duration: 0, delay: 150}) # 2.6.0: 50->150

    -1

  # ----------------------------------------------------------------------------------------------------------------
  animateInFinished: ()->
    Hy.Trace.debug "QuestionPage::animateInFinished (ENTER)"
    this.animateChildren({opacity: 1, duration: 100})
    Hy.Utils.Deferral.create(100, ()=>PageState.get().resumed())

  # ----------------------------------------------------------------------------------------------------------------
  animateOut: (useCurtains = false)->

    this.animateChildren({opacity: 0, duration: 50})
    Hy.Utils.Deferral.create(50, ()=>@webViewPanel?.fireEvent({kind: "animateOut", data: {useCurtains: useCurtains}}, (event)=>this.animateOutFinished()))

    return -1

    this.animateScenes(@animateOutScenes)

    @animateOutSceneDuration

  # ----------------------------------------------------------------------------------------------------------------
  animateOutFinished: ()->
    @window.setUIProperty("opacity", 0)
    Hy.Utils.Deferral.create(0, ()=>PageState.get().resumed())
  
  # ----------------------------------------------------------------------------------------------------------------
  dump: ()->
    Hy.Trace.debug "QuestionPage::dump (Question=#{@contestQuestion.getQuestionID()}/#{@contestQuestion.getQuestionText()})"

    for i in [0..3]
      Hy.Trace.debug "QuestionPage::dump (#{i} #{@contestQuestion.getAnswerText(i)})"   

    this

  # ----------------------------------------------------------------------------------------------------------------
  labelColor: ()->
    if @showingAnswers then Hy.UI.Colors.paleYellow else Hy.UI.Colors.white

  # ----------------------------------------------------------------------------------------------------------------
  animateCountdown: (init, value)->
  
    super

    color = Hy.UI.Colors.white

    if not init
      if not @showingAnswers
        if value <= Hy.Config.Dynamics.panicAnswerTime
          color = Hy.UI.Colors.MrF.Red

#    @questionLabel.setUIProperty("color", color) #TODO

    this

  # ----------------------------------------------------------------------------------------------------------------
  countdownAnimationOptions: (value)->

    _style: if @showingAnswers then "normal" else "frantic"
         
  # ----------------------------------------------------------------------------------------------------------------
  # Called from ConsoleApp
  animateCountdownQuestionCompleted: ()->

    this.getCountdownPanel().animateCountdown({_style: "completed"})

    this

  # ----------------------------------------------------------------------------------------------------------------
  webViewPanelCreate: ()->

    options = this.containerOptions()
    options._tag = "WebViewPanel"
#    options.borderWidth = 10
#    options.borderColor = Hy.UI.Colors.green

    webViewOptions =
      top: options.top
      left: options.left
      width: options.width
      height: options.height
      _tag: "Question Page Web View"
      scalesPageToFit:false
      url: "html-question-page.html"
      zIndex: 50 #@zIndexPassive
      backgroundColor:'transparent' # http://developer.appcelerator.com/question/45491/can-i-change-the-white-background-that-shows-when-a-web-view-is-loading

    @container.addChild(@webViewPanel = new Hy.Panels.WebViewPanel(options, webViewOptions))
 
    this

  # ----------------------------------------------------------------------------------------------------------------
  webViewPanelWait: (fn)->

    Hy.Trace.debug "QuestionPage::webViewPanelWait (PAGE WAIT: WebViewInitialized=#{@webViewPanel.isInitialized()})"

    @webViewPanelFinishAnimateInFn = fn

    if @webViewPanel.isInitialized()
      this.webViewPanelFinishAnimation()
    else
      null

    null

  # ----------------------------------------------------------------------------------------------------------------
  webViewPanelFinishAnimation: ()->

    Hy.Trace.debug "QuestionPage::webViewPanelFinishAnimation (FINISH ANIMATION: WebViewInitialized=#{@webViewPanel.isInitialized()})"

    if @webViewPanelFinishAnimateInFn?
      if @webViewPanel.isInitialized()
        Hy.Trace.debug "QuestionPage::webViewPanelFinishAnimation (FINISHING ANIMATION)"
        @webViewPanelFinishAnimateInFn()
        @webViewPanelFinishAnimateInFn = null
        Hy.Utils.Deferral.create(@animateInSceneDuration, ()=>PageState.get().resumed())
    else
      Hy.Trace.debug "QuestionPage::webViewPanelFinishAnimation (NO ANIMATION TO FINISH)"

    this

  # ----------------------------------------------------------------------------------------------------------------
  webViewPanelContentInitialize: ()->

    data = {}

    data.question = {}

    data.question.text = this.formatText(@contestQuestion.getQuestionText()).text

    code = switch (format = @contestQuestion.getContentPack().getFormatting("question"))
      when "bold"
        "b"
      when "italic"
        "i"
      when "none"
        null
      else
        "i"

    if code?
      data.question.text = "<#{code}>#{data.question.text}</#{code}>"

    data.answers = []

    for i in [0..3]
      data.answers[i] = {}
      data.answers[i].text = this.formatText(@contestQuestion.getAnswerText(i)).text

    @webViewPanel.fireEvent({kind: "initializePage", data: data}, (event)=>this.webViewPanelContentInitialized())

    this

  # ----------------------------------------------------------------------------------------------------------------
  webViewPanelContentInitialized: ()->

    Hy.Utils.Deferral.create(0, ()=>PageState.get().resumed())
    
    null

  # ----------------------------------------------------------------------------------------------------------------
  webViewPanelShowConsoleSelection: (indexSelectedAnswer)->
    @webViewPanel.fireEvent({kind: "showConsoleSelection", data: {indexSelectedAnswer: indexSelectedAnswer}})

  # ----------------------------------------------------------------------------------------------------------------
  webViewPanelRevealAnswer: (indexCorrectAnswer)->
    @webViewPanel.fireEvent({kind: "revealAnswer", data: {indexCorrectAnswer: indexCorrectAnswer}})

  # ----------------------------------------------------------------------------------------------------------------
  createQuestionBlock: ()->

    #Hack to prevent user "copy" actions, since all other approaches aren't working

    overlayViewOptions = 
      top: (@top += kQuestionBlockVerticalMargin)
      width: kQuestionBlockWidth
      height: kQuestionBlockHeight
      left: kQuestionBlockHorizontalMargin
      zIndex: @zIndexPassive + 1
      _tag: "Question Block Blocker"

    @top += overlayViewOptions.height

    new Hy.UI.ViewProxy(overlayViewOptions)

  # ----------------------------------------------------------------------------------------------------------------
  formatText: (text)->

    output = ""

    chunks = text.split("|")

    for i in [1..chunks.length]
      if i > 1
#        output += "\n"
        output += " "
      output += chunks[i-1]

    numLines = chunks.length
    if chunks[chunks.length-1].length is 0
      numLines--

    {numLines: numLines, text: output}

  # ----------------------------------------------------------------------------------------------------------------
  createAnswerBlocks: ()->

    answerItems = [
      {index: 0, label: "A", height: kAnswerBlockHeight, width: kAnswerBlockWidth, left: 0, top: 0}
      {index: 1, label: "B", height: kAnswerBlockHeight, width: kAnswerBlockWidth, left: kAnswerBlockWidth + kAnswerBlockHorizontalPadding, top: 0}
      {index: 2, label: "C", height: kAnswerBlockHeight, width: kAnswerBlockWidth, left: 0, top: kAnswerBlockHeight + kAnswerBlockVerticalPadding}
      {index: 3, label: "D", height: kAnswerBlockHeight, width: kAnswerBlockWidth, left: kAnswerBlockWidth + kAnswerBlockHorizontalPadding, top: kAnswerBlockHeight + kAnswerBlockVerticalPadding}
    ]

    answerContainerOptions = 
      top: (@top += kAnswerContainerVerticalMargin)
      left: kAnswerContainerHorizontalMargin
      height: kAnswerContainerHeight
      width: kAnswerContainerWidth
      _tag: "Answer Container"
      zIndex: @zIndexActive + 1

    @answersContainer = new Hy.UI.ViewProxy(answerContainerOptions)

    @answerBlocks = []

    this.createAnswerBlock(answerItem) for answerItem in answerItems
    @answersContainer

  # ----------------------------------------------------------------------------------------------------------------
  answerBlockOptions: (answerItem)->
    height            : answerItem.height,
    width             : answerItem.width, 
    top               : answerItem.top, 
    left              : answerItem.left, 
    _tag              : "Answer Container #{answerItem.label}"

  # ----------------------------------------------------------------------------------------------------------------
  createAnswerBlock: (answerItem)->

    # For direct play
    fnClick = (evt)=>
      this.answerBlockClicked(evt)

    answerBlockView = new Hy.UI.ViewProxy(this.answerBlockOptions(answerItem))
    answerBlockView.addEventListener("click", fnClick) 
        
    @answerBlocks.push {answerBlockView: answerBlockView, index: answerItem.index, label: answerItem.label}
    @answersContainer.addChild(answerBlockView)

    this

  # ----------------------------------------------------------------------------------------------------------------
  answerBlockClicked: (evt)->

    answerBlock = _.detect(@answerBlocks, (b)=>b.answerBlockView.getView() is evt.source)

    Hy.Trace.debug "QuestionPage::answerBlockClicked (label=#{if answerBlock? then answerBlock.label else "?"} allowEvents=#{this.getAllowEvents()} showingAnswers=#{@showingAnswers} consoleAnswered=#{@consoleAnswered} showingAnswersClicked=#{@showingAnswersClicked} PageState.state=#{PageState.get().getState()})"

    fn = null

    if this.getAllowEvents()
      if answerBlock?
        if @showingAnswers 
          if not @showingAnswersClicked
            @showingAnswersClicked = true
            fn = ()=>
              Hy.Trace.debug "QuestionPage::answerBlockClicked (done showing answers)"
              this.getApp().questionAnswerCompleted()
              null
        else 
          if not @consoleAnswered
            @consoleAnswered = true
            this.webViewPanelShowConsoleSelection(answerBlock.index)
            fn = ()=>
              Hy.Trace.debug "QuestionPage::answerBlockClicked (console answered)"
              this.getApp().consolePlayerAnswered(answerBlock.index)
              null
  
    if fn?
      this.haltCountdown()
      Hy.Utils.Deferral.create(0, ()=>fn())

    null

  # ----------------------------------------------------------------------------------------------------------------
  createAnswerCritterPanel: ()->

    options = 
      zIndex: @zIndexActive
      left: 0
      bottom: 0

    @container.addChild(@answerCritterPanel = new Hy.Panels.AnswerCritterPanel(options))

    this

  # ----------------------------------------------------------------------------------------------------------------
  countdownSound: (value)->

    sound = null

    if not @showingAnswers and value isnt 0
      sound = @soundKeys[@soundCounter++ % @nSounds]
    sound

  # ----------------------------------------------------------------------------------------------------------------
  playerAnswered: (response)->

    @answerCritterPanel.playerAnswered(response)

  # ----------------------------------------------------------------------------------------------------------------
  revealAnswer: ()->

    this.webViewPanelRevealAnswer(@contestQuestion.indexCorrectAnswer)

    # We want to display highest scorers first
    correct = []
    incorrect = []

    for response in Hy.Contest.ContestResponse.selectByQuestionID(@contestQuestion.getQuestionID())
      if response.getCorrect()
        correct.push response
      else
        incorrect.push response

    sortedCorrect = correct.sort((r1, r2)=> r2.getScore() - r1.getScore())    

    topScore = null

    fnResponse = (response)=>
      # We want to display first place scorers differently
      t = if topScore?
        response.getScore() is topScore
      else
        topScore = response.getScore()
        true
      @answerCritterPanel.playerAnswered(response, true, t)

    for response in sortedCorrect
      fnResponse(response)

    for response in incorrect
      fnResponse(response)

    this

# ==================================================================================================================
class ContestCompletedPage extends NotifierPage

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (state, app)->

    super state, app

    @top = 65
    @defaultZIndex = 40

    this.addBackground(@top)

    @top += 25
    this.addGameOverText()

    this.addPlayAgainButtonAndText()

#    this.addAnimation()

    this

  # ----------------------------------------------------------------------------------------------------------------
  addBackground: (top)->
    @backgroundOptions = 
      top: top
      height: 635
      width: 800
      image: "assets/icons/scoreboard-background.png"
      zIndex: @defaultZIndex-1
      _tag: "Scoreboard Background"

    @container.addChild(new Hy.UI.ImageViewProxy(@backgroundOptions))

  # ----------------------------------------------------------------------------------------------------------------
  addGameOverText: ()->

    height = 74

    options = 
      image: "assets/icons/label-Game-Over.png"
      top: @top
      height: 74
      width: 374
      zIndex: @defaultZIndex
      _tag: "Game Over Text"

    @top += height

    @container.addChild(@gameOverText = new Hy.UI.ImageViewProxy(options))

    this

  # ----------------------------------------------------------------------------------------------------------------
  addPlayAgainButtonAndText: ()->

    height = 72
    buttonOptions = 
      top: (@top += 20)
      height: height
      width: height
      backgroundImage: "assets/icons/button-play-small-blue.png"
      zIndex: @defaultZIndex
      _tag: "Play Again"

    @container.addChild(@playAgainButton = new Hy.UI.ButtonProxy(buttonOptions))

    textOptions = 
      top: @top
      height: height
#      width: 120
#      borderColor: Hy.UI.Colors.white
      zIndex: @defaultZIndex

    padding = 20
    this.addButtonText(Hy.UI.ViewProxy.mergeOptions(textOptions, {text: "play",  textAlign: "right", right: (Hy.UI.iPad.screenWidth/2) + (height/2) + padding}))
    this.addButtonText(Hy.UI.ViewProxy.mergeOptions(textOptions, {text: "again", textAlign: "left",  left:  (Hy.UI.iPad.screenWidth/2) + (height/2) + padding}))

    @playAgainButtonClicked = false

    @fnClickPlayAgain = (evt)=>
      if not @playAgainButtonClicked
        @playAgainButtonClicked = true
        this.playAgainClicked()
      null

    @playAgainButton.addEventListener("click", @fnClickPlayAgain)

    @top += height

    this

  # ----------------------------------------------------------------------------------------------------------------
  addButtonText: (options)->

    defaultOptions =
      font: Hy.UI.Fonts.specBigMrF
      color: Hy.UI.Colors.white
      zIndex: @defaultZIndex + 1
      _tag: "Button Text"

    @container.addChild(new Hy.UI.LabelProxy(Hy.UI.ViewProxy.mergeOptions(defaultOptions, options)))

    this

  # ----------------------------------------------------------------------------------------------------------------
  createScoreboardCritterPanel: ()->

    padding = 10
    width = @backgroundOptions.width
    height = @backgroundOptions.height - ((@top - @backgroundOptions.top) + (2*padding))
    scoreboardOptions = 
      top: @top
      height: height
      width: width
      left: (Hy.UI.iPad.screenWidth - width)/2
      zIndex: @defaultZIndex+2
      _orientation: "horizontal"
#      borderWidth: 1
#      borderColor: Hy.UI.Colors.red

    @container.addChild(@scoreboardCritterPanel = new Hy.Panels.ScoreboardCritterPanel(scoreboardOptions))

    @scoreboardCritterPanel

  # ----------------------------------------------------------------------------------------------------------------
  initialize: (fnNotify)->

    super
    
    @playAgainButtonClicked = false

#    @nQuestions = nQuestions

#    @questionInfoPanel?.initialize @nQuestions, @nQuestions, this.labelColor()

    this.createScoreboardCritterPanel().initialize().displayScores()

    true

  # ----------------------------------------------------------------------------------------------------------------
  start: ()->

    super

    this

  # ----------------------------------------------------------------------------------------------------------------
  stop: ()->

    if @scoreboardCritterPanel?
      this.container.removeChild(@scoreboardCritterPanel)
      @scoreboardCritterPanel.stop()
      @scoreboardCritterPanel = null

    super

    this

  # ----------------------------------------------------------------------------------------------------------------
  playAgainClicked: ()->
    Hy.Utils.Deferral.create(0, ()=>this.getApp().contestRestart(true))

  # ----------------------------------------------------------------------------------------------------------------
  getLeaderboard: ()->
    @scoreboardCritterPanel?.getLeaderboard()

  # ----------------------------------------------------------------------------------------------------------------
  addAnimation: ()->

#    @animateInScenes = null
    @animateOutScenes = null

    animationContainerOptions = 
      top:    0
      left:   0 
      right:  0
      bottom: 0
      zIndex: 50
    
#    [@animateInScenes, sceneTotalDuration] = this.buildAnimationFromScenes(this.initAnimateInScenes())
#    [@animateOutScenes, @animateOutSceneDuration] = this.buildAnimationFromScenes(this.initAnimateOutScenes(), @animateoutScenes)

    this

  # ----------------------------------------------------------------------------------------------------------------
  animateOut: ()->

    [@animateOutScenes, @animateOutSceneDuration] = this.buildAnimationFromScenes(this.initAnimateOutScenes(), @animateoutScenes)

    this.animateScenes(@animateOutScenes)

    @animateOutSceneDuration

  # ----------------------------------------------------------------------------------------------------------------
  initAnimateOutScenes: ()->

    [
      {image: "intro-TV",                  imageOptions: {zIndex: 50},                                                                 animationOptions: [{_incrementalDelay:    0, duration:    0, opacity: 1.0}]}

#      {image: "black",                     imageOptions: {zIndex: 49, top: 0, left: 0, right: 0, bottom: 0, opacity: 0},               animationOptions: [{_incrementalDelay:    0, duration: 1500, opacity: 1.0},                        {_incrementalDelay:  500, duration: 0, opacity: 0}]}

      {image: "intro-left-front-curtain",  imageOptions: {zIndex: 45, top: 0, width:514, height:768, right: Hy.UI.iPad.screenWidth, borderColor: Hy.UI.Colors.white},   animationOptions: [{_incrementalDelay:    0, duration: 1500, right: Hy.UI.iPad.screenWidth/2},     {_incrementalDelay:    0, duration: 100, right: Hy.UI.iPad.screenWidth}]}
      {image: "intro-right-front-curtain", imageOptions: {zIndex: 45, top: 0, width:514, height:768, left:  Hy.UI.iPad.screenWidth, borderColor: Hy.UI.Colors.white},   animationOptions: [{_incrementalDelay:    0, duration: 1500, left:  (Hy.UI.iPad.screenWidth/2)-5}, {_incrementalDelay:    0, duration: 100, left: Hy.UI.iPad.screenWidth}]}
    ]

# ==================================================================================================================
class PageState

  gOperationIndex = 0

  @Any          = -1
  @Unknown      =  0
  @Splash       =  1
  @Intro        =  2
  @Start        =  3
  @Question     =  4
  @Answer       =  5
  @Scoreboard   =  6
  @Completed    =  7
  @About        =  8
  @UCCInfo      =  9
  @JoinCodeInfo = 10

  stateToPageClassMap = [
    {state: PageState.Splash,       pageClass: SplashPage,                 background: Hy.UI.Backgrounds.splashPage},
    {state: PageState.Intro,        pageClass: IntroPage,                  background: null}, 
    {state: PageState.Start,        pageClass: StartPage,                  background: Hy.UI.Backgrounds.startPage}
    {state: PageState.Question,     pageClass: QuestionPage,               background: Hy.UI.Backgrounds.stageNoCurtain}
    {state: PageState.Answer,       pageClass: QuestionPage,               background: Hy.UI.Backgrounds.stageNoCurtain}
    {state: PageState.Completed,    pageClass: ContestCompletedPage,       background: Hy.UI.Backgrounds.stageCurtain}
    {state: PageState.About,        pageClass: AboutPage,                  background: Hy.UI.Backgrounds.startPage}
    {state: PageState.UCCInfo,      pageClass: UserCreatedContentInfoPage, background: Hy.UI.Backgrounds.startPage}
    {state: PageState.JoinCodeInfo, pageClass: JoinCodeInfoPage,           background: Hy.UI.Backgrounds.startPage}
  ]

  @defaultAnimateOut = {duration: 250, _startOpacity: 1, opacity: 0}
  @defaultAnimateIn  = {duration: 250, _startOpacity: 0, opacity: 1}

  transitionMaps = [
    {
     oldState:               [PageState.Any],
     newState:               [PageState.Splash],
     animateOutBackground:   Hy.UI.Backgrounds.splashPage,
     interstitialBackground: Hy.UI.Backgrounds.splashPage,
     animateInBackground:    Hy.UI.Backgrounds.splashPage
    },
    {
     oldState:               [PageState.Splash],
     newState:               [PageState.Intro],   
     animateOutBackground:   Hy.UI.Backgrounds.splashPage,
     interstitialBackground: Hy.UI.Backgrounds.splashPage,
     animateInBackground:    Hy.UI.Backgrounds.splashPage,
     animateInFn:            ((page)=>page.animateIn()),
    },
    {
     oldState:               [PageState.Intro],
     newState:               [PageState.Start],   
     animateOutFn:           ((page)=>page.animateOut()),
     animateOutBackground:   Hy.UI.Backgrounds.splashPage,
     interstitialBackground: Hy.UI.Backgrounds.splashPage,
     animateInBackground:    Hy.UI.Backgrounds.splashPage,
     animateIn:              {duration: 500, _startOpacity: 0, opacity: 1}
    },
    { # 2.5.0: To handle case where we're backgrounded. See ConsoleApp::resumedPage for details
     oldState:               [PageState.Any],
     newState:               [PageState.Start],   
     interstitialBackground: Hy.UI.Backgrounds.splashPage,
     animateInBackground:    Hy.UI.Backgrounds.splashPage,
     animateIn:              {duration: 500, _startOpacity: 0, opacity: 1}
    },
    {
     oldState:               [PageState.Start],
     newState:               [PageState.Question],   
     animateOut:             {duration: 500, opacity: 0},
     animateInFn:           ((page)=>page.animateIn(true))
    },
    {
     oldState:               [PageState.Question],
     newState:               [PageState.Answer],
     animateOut:             null,
     delay:                  500,
     animateIn:              null
    },
    {
     oldState:               [PageState.Answer],
     newState:               [PageState.Question],
     animateOutFn:           ((page)=>page.animateOut(false)),
     animateInFn:            ((page)=>page.animateIn(false)),
    },
    {
     oldState:               [PageState.Question, PageState.Answer],
     newState:               [PageState.Completed],
     animateOutFn:           ((page)=>page.animateOut(true)),
     animateIn:              {duration: 500, _startOpacity: 0, opacity: 1}
    },
    {
     oldState:               [PageState.Question, PageState.Answer],
     newState:               [PageState.Start],
     animateOutFn:           ((page)=>page.animateOut(true)),
     animateIn:              @defaultAnimateIn,
    },
    {
     oldState:               [PageState.Completed],
     newState:               [PageState.Start],  
     animateOut:             @defaultAnimateOut,
     animateIn:              @defaultAnimateIn,
    },
    {
     oldState:               [PageState.About, PageState.Start],
     newState:               [PageState.Start, PageState.About],
     animateOut:             @defaultAnimateOut,
     animateIn:              @defaultAnimateIn,
    },
    {
     oldState:               [PageState.UCCInfo, PageState.Start],
     newState:               [PageState.Start, PageState.UCCInfo],
     animateOut:             @defaultAnimateOut,
     animateIn:              @defaultAnimateIn,
    },
    {
     oldState:               [PageState.JoinCodeInfo, PageState.Start],
     newState:               [PageState.Start, PageState.JoinCodeInfo],
     animateOut:             @defaultAnimateOut,
     animateIn:              @defaultAnimateIn,
    }
  ]

  gInstance = null

  # ----------------------------------------------------------------------------------------------------------------
  @findTransitionMap: (oldPage, newPageState)->
    for map in transitionMaps
      if (oldPage? and oldPage.state in map.oldState) or (PageState.Any in map.oldState) # 2.5.0 
        if (newPageState in map.newState) or (PageState.Any in map.newState) # 2.5.0 
          return map

    return null

  # ----------------------------------------------------------------------------------------------------------------
  @getPageMap: (pageState)->
    for map in stateToPageClassMap
      if map.state is pageState
        return map
    return null
  
  # ----------------------------------------------------------------------------------------------------------------
  @getPageName: (pageState)->
    name = null
    map = this.getPageMap(pageState)
    if map?
      name = map.pageClass.name
    return name

  # ----------------------------------------------------------------------------------------------------------------
  @findPage: (pageState)->

    page = if (map = this.getPageMap(pageState))?
      Page.findPage(map.pageClass)
    else
      null

    page

  # ----------------------------------------------------------------------------------------------------------------
  @getPage: (pageState)->
    
    page = if (map = this.getPageMap(pageState))?
      Page.getPage(map)
    else
      null

    page

  # ----------------------------------------------------------------------------------------------------------------
  @get: ()-> gInstance

  # ----------------------------------------------------------------------------------------------------------------
  @doneWithPage: (pageState)->
  
    if (map = this.getPageMap(pageState))?
      Page.doneWithPage(map)
      
    null

  # ----------------------------------------------------------------------------------------------------------------
  @init: (app)->
    if not gInstance?
      gInstance = new PageState(app)
    gInstance

  # ----------------------------------------------------------------------------------------------------------------
  display: ()->
    s = "PageState::display"

    s += "("
    if (state = this.getState())?
      s += "#{state.oldPageState}->#{state.newPageState}"
    s += ")"

    s
  # ----------------------------------------------------------------------------------------------------------------
  constructor: (@app)->

    this.initialize()
    this

  # ----------------------------------------------------------------------------------------------------------------
  initialize: ()->

    @state = null

    timedOperation = new Hy.Utils.TimedOperation("PAGE INITIALIZATION")

    for map in transitionMaps
      for v in ["videoOut", "videoIn"]
        if (videoOptions = map[v])?
          timedOperation.mark("video: #{videoOptions._url}")
          map["_#{v}Instance"] = player = Hy.Media.VideoPlayer.create(videoOptions)
#          player.prepareToPlay().play()

    timedOperation.mark("DONE")
 
    this

  # ----------------------------------------------------------------------------------------------------------------
  stop: ()->
    if (page = this.getApp().getpage())?
      page?.closeWindow()
      page?.stop()
      this.getApp().setPage(null)

    this
  
  # ----------------------------------------------------------------------------------------------------------------
  getApp: ()-> @app

  # ----------------------------------------------------------------------------------------------------------------
  getState: ()-> @state

  # ----------------------------------------------------------------------------------------------------------------
  setState: (state)-> @state = state

  # ----------------------------------------------------------------------------------------------------------------
  isTransitioning: ()-> 
    if (state = this.getState(false))?
      state.newPageState
    else
      null

  # ----------------------------------------------------------------------------------------------------------------
  getOldPageState: ()->
    this.getState()?.oldPageState

  # ----------------------------------------------------------------------------------------------------------------
  stopTransitioning: ()->
    this.setState(null)

  # ----------------------------------------------------------------------------------------------------------------
  addPostTransitionAction: (fnPostTransition)->

    if (state = this.getState())?
      @postFunctions.push(fnPostTransition)

    this

  # ----------------------------------------------------------------------------------------------------------------
  hasPostFunctions: ()-> _.size(@postFunctions) > 0

  # ----------------------------------------------------------------------------------------------------------------
  # I've re-written this function about 5 times so far. "This time for sure".
  # I've re-written this function about 6 times so far. "This time for sure".
  #
  showPage: (newPageState, fn_newPageInit, postFunctions = [])->

    initialState = 
      oldPage: this.getApp().getPage()
#      newPage: Hy.Pages.PageState.getPage(newPageState)
      newPage_: null # defer creating the new page 
      oldPageState: (if (oldPage = this.getApp().getPage())? then oldPage.getState() else null)
      newPageState: newPageState
      fn_newPageInit: fn_newPageInit

    if (existingState = this.getState())?
      s = "OLD STATE: oldPageState=#{if existingState.oldPage? then existingState.oldPage.getState() else "(NONE)"} newPageState=#{existingState.newPageState}"
      s += " NEW STATE: oldPageState=#{if initialState.oldPage? then initialState.oldPage.getState() else "(NONE)"} newPageState=#{initialState.newPageState}"      

      Hy.Trace.debug "PageState::showPage (RECURSION #{s})", true
      new Hy.Utils.ErrorMessage("fatal", "PageState::showPage", s)
      return

    @postFunctions = [].concat(postFunctions)

    this.setState(this.showPage_setup(initialState))

    this.showPage_execute()

    this

  # ----------------------------------------------------------------------------------------------------------------
  showPage_setup: (state)->

    state.spec = Hy.Pages.PageState.findTransitionMap(state.oldPage, state.newPageState)
    state.delay = if state.spec? then (if state.spec.delay? then state.spec.delay else 0) else 0
    state.exitVideo = if state.spec? then state.spec._videoOutInstance else null
    state.introVideo = if state.spec? then state.spec._videoInInstance else null
    state.animateOut = if state.spec? then state.spec.animateOut else Hy.Pages.PageState.defaultAnimateOut
    state.animateOutFn = if state.spec? then state.spec.animateOutFn
    state.animateInFn = if state.spec? then state.spec.animateInFn
    state.animateIn = if state.spec? then state.spec.animateIn else Hy.Pages.PageState.defaultAnimateIn
    state.previousVideo = null
    state.networkServiceLevel = null
    state.operationIndex = ++gOperationIndex # For logging
    state.fnIndex = 0 # 
    state.fnCompleted = false

    fnDebug = (fnName, s="")=>
      p = ""
      if (state = this.getState())?
        p += "##{state.operationIndex} fn:#{state.fnIndex} "
        p += if (oldPageState = this.getState().oldPageState)? then oldPageState else "NONE"
        p += ">#{this.getState().newPageState}"
      else
        p = "(NO STATE!)"

      Hy.Trace.debug("PageState::showPage (#{p} #{fnName} #{if s? then s else ""})")
      null

    fnExecuteNext = (restart = false)=>
      ok = false

      if (state = this.getState())?
        if restart and not state.fnCompleted
          # Try the last operation again
          null 
        else
          ++state.fnIndex

        if state.fnIndex <= state.fnChain.length
          state.fnCompleted = false
          ok = true
          state.fnChain[state.fnIndex-1]()
          state.fnCompleted = true
      ok

    fnExecutePostFunction = ()=>
      if (f = @postFunctions.shift())?
        f(this.getApp().getPage())
      null

    fnExecuteRemaining = ()=>
      if (state = this.getState())?
        while fnExecuteNext()
          null

        this.showPage_exit(state.operationIndex)

        while _.size(@postFunctions) > 0
          fnExecutePostFunction()

      null

    fnIndicateActive = ()=>
      Hy.Network.NetworkService.setIsActive()
      fnExecuteNext()
      null

    fnSuspendNetwork = ()=>
      fnDebug("fnSuspendNetwork")
      if (ns = Hy.Network.NetworkService.get())?
        l = this.getState().networkServiceLevel = ns.getServiceLevel()
        fnDebug("fnSuspendNetwork (from \"#{l}\")")
        ns.setSuspended()
      fnExecuteNext()
      null

    fnResumeNetwork = ()=>
      fnDebug("fnResumeNetwork")
      if (serviceLevel = this.getState().networkServiceLevel)?
        Hy.Network.NetworkService.get().setServiceLevel(serviceLevel)
      fnExecuteNext()
      null

    # Returns existing instance of this kind of page, if it exists. 
    fnCheckNewPage =  ()=>
      Hy.Pages.PageState.findPage(state.newPageState)
     
    fnGetNewPage = ()=>
      this.getState().newPage_

    fnCreateNewPage = ()=>
      s = this.getState()
      if not s.newPage_?
        s.newPage_ = Hy.Pages.PageState.getPage(state.newPageState)
      s.newPage_
       
    fnSetBackground = (backgroundName = null)=>
      fnDebug("fnSetBackground", backgroundName)
      bkgnd = if backgroundName? then this.getState().spec?[backgroundName] else null
      this.getApp().setBackground(bkgnd)
      fnExecuteNext()

    fnCleanupVideo = (video)=>
      fnDebug("fnCleanupVideo")
      video.setUIProperty("borderColor", Hy.UI.Colors.green)
      fnExecuteNext()
      null

    fnPlayVideo = (video, preBackground, postBackground)=>
      fnDebug("fnPlayVideo")
      if this.getState().previousVideo?
        this.getState().previousVideo.release()
      video.setVideoProperty("backgroundImage", preBackground)
      f = ()=>fnCleanupVideo(video)
      video.prepareToPlay(f)
      this.getApp().getBackgroundWindow().add(video.getView())
      this.getApp().setBackground(postBackground)
      video.setUIProperty("borderColor", Hy.UI.Colors.white)
      video.play()
      video.setUIProperty("borderColor", Hy.UI.Colors.red)
      this.getState().previousVideo = video
      null

    fnStopOldPage = ()=>
      fnDebug("fnStopOldPage")
      this.getState().oldPage?.stop()
      fnExecuteNext()
      null

    fnAnimateOut = ()=>
      fnDebug("fnAnimateOut")
      duration = 0
      if (oldPage = this.getState().oldPage)?
        animateOut = this.getState().animateOut
        animateOutFn = this.getState().animateOutFn
        if animateOut?
          if animateOut._startOpacity?
            oldPage.window.setUIProperty("opacity", animateOut._startOpacity)
          oldPage.animateWindow(animateOut)
          duration = animateOut.duration
        else
          if animateOutFn?
            duration = animateOutFn(oldPage)
      if duration is -1 # -1 means we'll get called back to resume page transition
        fnDebug("fnAnimateOut", "WAITING")
      else
        Hy.Utils.Deferral.create(duration, fnExecuteNext)
      null

    fnCloseOldPage = ()=>
      fnDebug("fnCloseOldPage")
      if (oldPage = this.getState().oldPage)?
        newPage = fnCheckNewPage() # Might be null if page hasn't been created/used before #this.getState().newPage
        if oldPage isnt newPage
          oldPage.closeWindow()
        this.getApp().setPage(null)        
      fnExecuteNext()
      null

    fnPlayExitVideo = ()=>
      fnDebug("fnPlayExitVideo")
      if this.getState().exitVideo?
        fnPlayVideo(this.getState().exitVideo, this.getState().spec.animateOutBackground, this.getState().spec.interstitialBackground)
      else
        fnExecuteNext()
      null

    fnPlayIntroVideo = ()=>
      fnDebug("fnPlayIntroVideo")
      if this.getState().introVideo?
        fnPlayVideo(this.getState().introVideo, this.getState().spec.interstitialBackground, this.getState().spec.animateInBackground)
      else
        fnExecuteNext()
      null

    fnInitNewPage = ()=>
      fnDebug("fnInitNewPage")
      newPage = fnCreateNewPage() #this.getState().newPage
      this.getApp().setPage(newPage)
      newPage.setState(this.getState().newPageState)
      if (result = this.getState().fn_newPageInit(newPage))
        fnExecuteNext()
      else
        fnDebug("fnInitNewPage: waiting")

    fnAnimateInAndOpenNewPage = ()=>
      fnDebug("fnAnimateInAndOpenNewPage")
      duration = 0
      newPage = fnGetNewPage() #this.getState().newPage
      animateIn = this.getState().animateIn
      animateInFn = this.getState().animateInFn

      if animateIn? 
        duration = animateIn.duration
        if animateIn._startOpacity?
          newPage.window.setUIProperty("opacity", animateIn._startOpacity)

        if newPage is this.getState().oldPage
          newPage.animateWindow(animateIn)
        else
          newPage.openWindow(animateIn)
      else
        if animateInFn?
#          if newPage isnt this.getState().oldPage
#            newPage.openWindow()
          duration = animateInFn(newPage)
        else
          if newPage isnt this.getState().oldPage
            newPage.openWindow({opacity:1, duration:0})
          else
            newPage.animateWindow({opacity:1, duration:0})

      if duration is -1 # -1 means we'll get called back to resume page transition
        fnDebug("fnAnimateInAndOpenNewPage", "Waiting for callback")
      else
        fnDebug("fnAnimateInAndOpenNewPage", "Waiting #{duration}")
        Hy.Utils.Deferral.create(duration, fnExecuteNext)
      null

    fnStartNewPage = ()=>
      fnDebug("fnStartNewPage")
      fnGetNewPage().start()      
      fnExecuteNext()
      null

    # We do it this way since it makes it easier to change the order and timing of things,
    # and ensure the integrity of the transition across pause/resumed
    state.fnChain = # 2.5.0: removed default fnChain... 
      [
        fnSuspendNetwork,
        fnStopOldPage,
        fnAnimateOut, 
        ()=>fnSetBackground("animateOutBackground"),
        fnCloseOldPage,
        fnPlayExitVideo,
        ()=>fnSetBackground("interstitialBackground"),
        ()=>Hy.Utils.Deferral.create(this.getState().delay, fnExecuteNext),

        fnPlayIntroVideo,
        ()=>fnSetBackground("animateInBackground"),
        fnInitNewPage,
        fnAnimateInAndOpenNewPage,
        ()=>fnSetBackground(),
#        ()=>Hy.Utils.Deferral.create(0, fnStartNewPage), # 2.5.0
        fnStartNewPage, 
        fnResumeNetwork,
        fnIndicateActive,
        fnExecuteRemaining
      ]

    state.fnExecuteNext = fnExecuteNext

    state

  # ----------------------------------------------------------------------------------------------------------------
  showPage_execute: (restart = false)->

    @state?.fnExecuteNext(restart) 

    this

  # ----------------------------------------------------------------------------------------------------------------
  showPage_exit: (operationIndex)->

    Hy.Trace.debug "PageState::showPage_exit (##{operationIndex})"

    this.setState(null)

  # ----------------------------------------------------------------------------------------------------------------
  resumed: (restart = false)->
    Hy.Trace.debug "PageState::resumed"

    if this.getState()?
      this.showPage_execute(restart)
    else
      if (page = this.getApp().getPage())?
        page.resumed()
      else
        Hy.Trace.debug "PageState::showPage (RESUMED BUT NO WHERE TO GO)"

    null

# ==================================================================================================================
Hyperbotic.Pages =
  Page: Page
  NotifierPage: NotifierPage
  IntroPage: IntroPage
  SplashPage: SplashPage
  AboutPage: AboutPage
  UserCreatedContentInfoPage: UserCreatedContentInfoPage
  StartPage: StartPage
  QuestionPage: QuestionPage
  ContestCompletedPage: ContestCompletedPage
  PageState: PageState
  CountdownPage: CountdownPage


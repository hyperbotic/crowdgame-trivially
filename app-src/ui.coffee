# ==================================================================================================================
class Backgrounds

  @stageNoCurtain = "assets/bkgnds/stage-no-curtain.png"
  @stageCurtain   = "assets/bkgnds/stage-curtain.png"
  @startPage      = "assets/bkgnds/stage-startPage.png"
  @splashPage     = "assets/bkgnds/animations/splash.png"

  @pixelOverlay   = "assets/bkgnds/pixel-overlay.png"

  @defaultDimOpacity = 0.2

# ==================================================================================================================
class Device

  @getDensity: ()-> Ti.Platform.displayCaps.density

class iPad extends Device
  @screenWidth = 1024
  @screenHeight = 768

class iPhone extends Device
  @screenWidth =  320
  @screenHeight = 480

class iPhoneRetina #THIS IS WRONG
  @screenWidth =  640
  @screenHeight = 960

# ==================================================================================================================
class Fonts
  @Font1 = "Trebuchet MS"
  @Font2 = "Courier New"
  @Font3 = "Helvetica Neue, Condensed Bold"
  @font4 = "Helvetica Neue"
  @MrF   = "Mr. F blockserif"

  @defaultDarkShadowColor = '#666'
  @defaultLightShadowColor = '#fff'
  @defaultShadowOffset = {x:2,y:2}

  @specGiantMrF =  {fontSize: 84, fontWeight: 'bold', fontFamily: "Mr. F blockserif"}
  @specBigMrF =    {fontSize: 48, fontWeight: 'bold', fontFamily: "Mr. F blockserif"}
  @specMediumMrF = {fontSize: 36, fontWeight: 'bold', fontFamily: "Mr. F blockserif"}
  @specSmallMrF =  {fontSize: 30, fontWeight: 'bold', fontFamily: "Mr. F blockserif"}
  @specTinyMrF  =  {fontSize: 14, fontWeight: 'bold', fontFamily: "Mr. F blockserif"}

  @specBiggerNormal =     {fontSize:48,fontWeight:'bold', fontFamily: "Trebuchet MS"}
  @specBigNormal =        {fontSize:36,fontWeight:'bold', fontFamily: "Trebuchet MS"}
  @specMediumNormal =     {fontSize:28,fontWeight:'bold', fontFamily: "Trebuchet MS"}
  @specSmallNormal =      {fontSize:22,fontWeight:'bold', fontFamily: "Trebuchet MS"}  
  @specTinyNormal =       {fontSize:18,fontWeight:'bold', fontFamily: "Trebuchet MS"}  
  @specTinyNormalNoBold = {fontSize:18,fontWeight:'bold', fontFamily: "Trebuchet MS"}  
  @specMinisculeNormal =  {fontSize:12,fontWeight:'bold', fontFamily: "Trebuchet MS"}  

  @specMediumCode =   {fontSize:28,fontWeight:'bold', fontFamily: "Courier New"}
  @specTinyCode =     {fontSize:14,fontWeight:'bold', fontFamily: "Courier New"}

  # ----------------------------------------------------------------------------------------------------------------
  # Returns a new font object based on merging the properties of fontA and fontB. fontB overrides fontA
  #
  @mergeFonts: (fontA, fontB)->

    newFont = {}

    for font in [fontA, fontB]    
      for prop, value of font
        newFont[prop] = value

    newFont

  @cloneFont: (font)->

    _.clone(font)

# ==================================================================================================================
Colors = 
  white:  '#fff'
  black:  '#000'
  red:    '#f00'
  green:  '#0a5' #<00><176><80>
  blue:   '#07c' #<00><112><192>
  yellow: '#ea0' #<255><192><0>
  gray:   '#ccc'
  
  darkRed:    '#900'
  darkGreen:  '#072'
  darkBlue:   '#049'
  darkYellow: '#b70'
  paleYellow: '#ffc'

  MrF:
    DarkBlue:  '#0099ff'
    LightBlue: '#66ccff'

    Red:       '#ec2f2f'
    RedDark:   '#B32424'

    Orange:    '#ff6600'

    Gray:      '#9a9a9a'
    GrayLight: '#CCCCCC'

# ==================================================================================================================
class Application

  gInstance = null

  # ----------------------------------------------------------------------------------------------------------------
  @get: ()->
    gInstance

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (@backgroundWindow = null, @tempImage = null)->
    Hy.Trace.info "Application::constructor"

    gInstance = this

    @page = null

    Ti.App.addEventListener('close', 
                            (evt)=>
                               this.exit(evt)
                               null)

    if Hy.Config.Version.isiOS4Plus()
      Ti.App.addEventListener('resume', 
                              (evt)=>
                                this.resume(evt)
                                null)
      Ti.App.addEventListener('resumed', 
                              (evt)=>
                                this.resumed(evt)
                                null)
      Ti.App.addEventListener('pause', 
                              (evt)=>
                                this.pause(evt)
                                null)

    Ti.App.idleTimerDisabled = true

    this

  # ----------------------------------------------------------------------------------------------------------------
  getBackgroundWindow: ()-> @backgroundWindow

  # ----------------------------------------------------------------------------------------------------------------
  setBackground: (background)->

     this.getBackgroundWindow().backgroundImage = background

     if @tempImage? # 2.5.0
       this.getBackgroundWindow().remove(@tempImage)
       @tempImage = null

     this
    
  # ----------------------------------------------------------------------------------------------------------------
  getMajorVersion: ()-> Hy.Config.Version.Console.kConsoleMajorVersion

  # ----------------------------------------------------------------------------------------------------------------
  getMinorVersion: ()-> Hy.Config.Version.Console.kConsoleMinorVersion

  # ----------------------------------------------------------------------------------------------------------------
  getVersionString: ()->
    this.getMajorVersion() + "." + this.getMinorVersion()

  # ----------------------------------------------------------------------------------------------------------------
  init: ()->
    Hy.Trace.info "Application::init"

    this

  # ----------------------------------------------------------------------------------------------------------------
  start: ()->
    Hy.Trace.info "Application::run"

    this

  # ----------------------------------------------------------------------------------------------------------------
  pause: (evt)->
    Hy.Trace.info "Application::pause (ENTER)"

    Hy.Utils.DeferralBase.cleanup()

    Hy.Trace.info "Application::pause (EXIT)"
    this

  # ----------------------------------------------------------------------------------------------------------------
  exit: (evt)->
    Hy.Trace.info "Application::exit"

    this

  # ----------------------------------------------------------------------------------------------------------------
  resume: (evt)->
    Hy.Trace.info "Application::resume"

    this

  # ----------------------------------------------------------------------------------------------------------------
  resumed: (evt)->
    Hy.Trace.info "Application::resumed"

    Hy.Utils.DeferralBase.cleanup()

    this

  # ----------------------------------------------------------------------------------------------------------------
  getPage: ()-> @page

  # ----------------------------------------------------------------------------------------------------------------
  setPage: (page)-> @page = page

  # ----------------------------------------------------------------------------------------------------------------
  obs_networkChanged: (reason)->

    this

# ==================================================================================================================
Hyperbotic.UI =
  Colors: Colors
  Application: Application
  Fonts: Fonts
  Device: Device
  iPad: iPad
  Backgrounds: Backgrounds



 
# ==================================================================================================================
class HtmlIntroPage

  delayedElementSpecs = [

      {id: "splash",                    
      index: 16, 
      src: "assets/bkgnds/animations/splash.png", 
      src2x: "assets/bkgnds/animations/splash@2x.png"},

      {id: "black",                     
      index: 14, 
      src: "assets/bkgnds/animations/black.png"},

      {id: "left_front_curtain",        
      index: 11, 
      src: "assets/bkgnds/animations/intro-left-front-curtain.jpg", 
      src2x: "assets/bkgnds/animations/intro-left-front-curtain@2x.jpg"},

      {id: "right_front_curtain",       
      index: 12, 
      src: "assets/bkgnds/animations/intro-right-front-curtain.jpg", 
      src2x: "assets/bkgnds/animations/intro-right-front-curtain@2x.jpg"},

      {id: "background_full",           
      index: 15, 
      src: "assets/bkgnds/animations/intro-background-full.jpg", 
      src2x: "assets/bkgnds/animations/intro-background-full@2x.jpg"},

      {id: "spotlights",                
      index: 22, 
      src: "assets/bkgnds/animations/intro-spotlights.png", 
      src2x: "assets/bkgnds/animations/intro-spotlights@2x.png"},

      {id: "tv",                        
      index:  9, 
      src: "assets/bkgnds/animations/intro-TV.png", 
      src2x: "assets/bkgnds/animations/intro-TV@2x.png"},

  ]

  elementNames = [
    "page_wrapper"
  ]
 
  # ----------------------------------------------------------------------------------------------------------------
  constructor: ()->

    if (@utility = window.htmlPageUtility)?
      @utility.initApp(this, elementNames, delayedElementSpecs)

    @animationInProgress = null

    this

  # ----------------------------------------------------------------------------------------------------------------
  animationDoCompletionCallback: (event)->
     if event._responseRequired
       event._responseCompleted = true
       @utility.fireEvent("_pageEventOut", event)
     this

  # ----------------------------------------------------------------------------------------------------------------
  animationSetupCompletionEvent: (event, delay)->

    fnDone = ()=>
       if @animationInProgress?
         this.animationDoCompletionCallback(@animationInProgress.event)
         @animationInProgress = null
       null

    @animationInProgress = {timeout: setTimeout(fnDone, delay), event: event}

    this

  # ----------------------------------------------------------------------------------------------------------------
  # http://trac.webkit.org/wiki/QtWebKitGraphic
  # http://www.mobigeni.com/2010/09/22/how-to-use-hardware-accelerated-css3-3d-transitions-on-ipad-and-iphone/
  #
  event_animateIn: (event)=>

    @_splash.style.opacity = 0

    f1 = ()=>
      @_black.style.opacity = 0
      @_left_front_curtain.style.opacity = 1
      @_right_front_curtain.style.opacity = 1

      setTimeout(f2, 2000)

    f2 = ()=> # 2.5.0
      @_spotlights.style.opacity = 1
      @_background_full.style.opacity = 1

      @_left_front_curtain.style.webkitTransform = "translate3d(-512px, 0, 0)"
      @_right_front_curtain.style.webkitTransform = "translate3d(512px, 0, 0)"
      this.animationSetupCompletionEvent(event, 1500)
      null

    setTimeout(f1, 0)

    this

  # ----------------------------------------------------------------------------------------------------------------
  event_animateOut: (event)=>

    @_spotlights.style.opacity = 0

    duration = 2000 #1500 # 2.5.0

    @_black.style.opacity = 1

    @_left_front_curtain.style.webkitTransform = ""
    @_right_front_curtain.style.webkitTransform = ""
    
    this.animationSetupCompletionEvent(event, duration)

    this

  # ----------------------------------------------------------------------------------------------------------------
  event_stopAnimating: (event)=>

    if @animationInProgress?
#      alert "Cleared timeout"
      clearTimeout(@animationInProgress.timeout)
      this.animationDoCompletionCallback(@animationInProgress.event)      
      @animationInProgress = null

    if event._responseRequired
      event._responseCompleted = true
      setTimeout( (()=>@utility.fireEvent("_pageEventOut", event)), 0)

    this


# ==================================================================================================================

window.htmlIntroPage = new HtmlIntroPage()

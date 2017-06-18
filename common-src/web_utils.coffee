# ==================================================================================================================
# Wraps XMLHttpRequest
#
# https://developer.mozilla.org/en/XMLHttpRequest
#
class HTTPRequest

  # ----------------------------------------------------------------------------------------------------------------
  @isSupported: ()->
    Hy.Web.Browser.supportsXMLHttpRequest()

  # ----------------------------------------------------------------------------------------------------------------
  constructor: ()->

    this
  # ----------------------------------------------------------------------------------------------------------------
  do: (url, fnResponse)->

    @xmlHTTPTimer = null
    timeout = 5000
    xhreq = null

    fnTimeout = ()=>
      @xmlHTTPTimer = null
      Hy.Web.Debug.set("xmlHTTPResponse never returned")
      xhReq.abort()
      fnResponse(false, null, null)
      null

    fnResponseReceived = ()=>
      if xhReq.readyState is 4
        r = "Response=#{xhReq.readyState}"

        if @xmlHTTPTimer?
          window.clearTimeout(@xmlHTTPTimer)
          @xmlHTTPTimer = null
        
        r += " status=#{xhReq.status}"
        r += " responseText=#{xhReq.responseText}"
        r += " statusText=#{xhReq.statusText}"

        Hy.Web.Debug.set("xmlHTTPResponse: #{r}")

        fnResponse((if xhReq.status is 200 then true else false), xhReq.status, xhReq.responseText)
      null

    if HTTPRequest.isSupported()
      xhReq = new XMLHttpRequest()
      xhReq.open("GET", url, true)
      xhReq.onreadystatechange = fnResponseReceived
      xhReq.send(null)

      Hy.Web.Debug.set("xmlHTTPResponse sent: #{url}")

      @xmlHTTPTimer = window.setTimeout(fnTimeout, timeout)
    else
      Hy.Web.Debug.set("xmlHTTPResponse not supported")

    xhreq?

# ==================================================================================================================
# 
class Connection

  # ----------------------------------------------------------------------------------------------------------------
  @create: (url, fnOpened, fnMessageReceived, fnClosed, fnError)->

    if WebSocketConnection.isSupported() 
      new WebSocketConnection(url, fnOpened, fnMessageReceived, fnClosed, fnError)
    else
      null 

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (@url, @fnOpened, @fnMessageReceived, @fnClosed, @fnError)->

    @connected = false
    this

  # ----------------------------------------------------------------------------------------------------------------
  isConnected: ()-> @connected

  # ----------------------------------------------------------------------------------------------------------------
  connect: ()->
    true

# ==================================================================================================================
# 
class WebSocketConnection extends Connection

  # ----------------------------------------------------------------------------------------------------------------
  @isSupported: ()-> `"WebSocket" in window`

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (url, fnOpened, fnMessageReceived, fnClosed, fnError)->

    super url, fnOpened, fnMessageReceived, fnClosed, fnError

    @ws = null

    this

  # ----------------------------------------------------------------------------------------------------------------
  connect: ()->

    status = super

    if status
      if (status = WebSocketConnection.isSupported())
        @ws = new WebSocket(@url)

        @ws.onopen = ()=>this.webSocketOpened()
        @ws.onmessage = (evt)=>@fnMessageReceived?(evt.data)
        @ws.onclose = ()=>this.webSocketClosed()

    status

  # ----------------------------------------------------------------------------------------------------------------
  webSocketOpened: ()->
    Hy.Web.Debug.set("SocketOpened")
    @connected = true
    @fnOpened?()

  # ----------------------------------------------------------------------------------------------------------------
  webSocketClosed: ()->
    Hy.Web.Debug.set("Socket Closed")

    @connected = false
    @ws = null
    @fnClosed?()

  # ----------------------------------------------------------------------------------------------------------------
  sendMessage: (messageText)->
    if this.isConnected()
      @ws.send(messageText)
    else
      Hy.Web.Debug.set("Socket is not open")

    @this

# ==================================================================================================================
# 
class Device 

  # ----------------------------------------------------------------------------------------------------------------
  @isiPhone: ()->
    (navigator.userAgent.indexOf("iPhone") isnt -1) or (navigator.userAgent.indexOf("iPod") isnt -1)

  # ----------------------------------------------------------------------------------------------------------------
  @isiPhoneWith4InchScreen: ()->
    Device.isiPhone() and (Device.getDeviceHeight() is 568)

  # ----------------------------------------------------------------------------------------------------------------
  @isiPad: ()->
    (navigator.userAgent.indexOf("iPad") isnt -1)

  # ----------------------------------------------------------------------------------------------------------------
  @hasCellularCapability: ()->

    Device.isiPhone() or Device.isiPad()

  # ----------------------------------------------------------------------------------------------------------------
  @getType: ()->
    if Device.isiPhone()
      "iPhone"
    else
      if Device.isiPad()
        "iPad"
      else
        "other"

  # ----------------------------------------------------------------------------------------------------------------
  # This implementation also exists in html-page-utility.coffee
  #
  @hasRetinaDisplay: ()->
    window.devicePixelRatio? and (window.devicePixelRatio > 1)

  # ----------------------------------------------------------------------------------------------------------------
  @useHighResImages: ()->
    
    Device.getDensity() isnt "1x"

  # ----------------------------------------------------------------------------------------------------------------
  @getDensity: ()->

    if not (density = Device.getDensityOverride())?
       density = if Device.hasRetinaDisplay() or Device.isBigScreen() then "2x" else "1x"

    density
    
  # ----------------------------------------------------------------------------------------------------------------
  @getDensityOverride: ()->

    URL.getArg(["d","density"], ["1x", "2x"])

  # ----------------------------------------------------------------------------------------------------------------
  @isBigScreen: ()->

    Device.getScreenWidth() > 480

  # ----------------------------------------------------------------------------------------------------------------
  @getDeviceWidth: ()->
    screen.width

  # ----------------------------------------------------------------------------------------------------------------
  @getDeviceHeight: ()->
    screen.height

  # ----------------------------------------------------------------------------------------------------------------
  # this isn't really a device property...
  @getScreenWidth: ()->
    document.documentElement.clientWidth

  # ----------------------------------------------------------------------------------------------------------------
  @getScreenHeight: ()->
    document.documentElement.clientHeight

  # ----------------------------------------------------------------------------------------------------------------
  @dump: ()->
    s = "type=#{Device.getType()} retina=#{Device.hasRetinaDisplay()}"
    s += "\n"
    s += "screen width=#{Device.getScreenWidth()} height=#{Device.getScreenHeight()}"
    s += "\n"
    s += "device width=#{Device.getDeviceWidth()}"

    alert s

    null    

  # ----------------------------------------------------------------------------------------------------------------
  @getOrientation: ()->

    orientation = switch(window.orientation)
      when 0, 180
        orientation = "portrait"
      when -90, 90
        orientation = "landscape"
      else
        orientation = "portrait"

#    alert "Orientation is: #{orientation}"

    orientation

# ==================================================================================================================
# 
class Browser

  # ----------------------------------------------------------------------------------------------------------------
  # http://caniuse.com/#feat=websockets
  #
  # Chrome on PC: all versions
  # Chrome on device: not supported
  #
  # Safari on Mac: all versions
  # Safari on ioS: 4.2 and above
  #
  # Firefox on PC: all versions
  #
  @isSupported: ()->

    supported = false

    if WebSocketConnection.isSupported() 
      if Browser.isSafari() or (Browser.isChrome() and not Browser.isAndroid()) or Browser.isFirefox() or Browser.isIE10()
        supported = true

    supported

  # ----------------------------------------------------------------------------------------------------------------
  @isSafari: ()->
    (v = navigator.vendor)? and (v.indexOf("Apple") isnt -1)

  # ----------------------------------------------------------------------------------------------------------------
  @isChrome: ()->
    navigator.userAgent.indexOf("Chrome") isnt -1

  # ----------------------------------------------------------------------------------------------------------------
  @isFirefox: ()->
    navigator.userAgent.indexOf("Firefox") isnt -1

  # ----------------------------------------------------------------------------------------------------------------
  @isIE10: ()->
    navigator.userAgent.indexOf("MSIE 10") isnt -1

  # ----------------------------------------------------------------------------------------------------------------
  # https://developers.google.com/chrome/mobile/docs/user-agent
  #
  @isAndroid: ()->
    navigator.userAgent.indexOf("Android") isnt -1

  # ----------------------------------------------------------------------------------------------------------------
  @supportsXMLHttpRequest: ()->
    window.XMLHttpRequest

  # ----------------------------------------------------------------------------------------------------------------
  # http://developer.apple.com/library/safari/#documentation/appleapplications/reference/SafariHTMLRef/Articles/MetaTags.html
  #
  @isFullScreen: ()->
    if window.navigator.standalone?
      window.navigator.standalone
    else
      false

  # ----------------------------------------------------------------------------------------------------------------
  @hideLocationBar: ()->

    # iOS 7: this no longer works
    # http://www.mobilexweb.com/blog/safari-ios7-html5-problems-apis-review

    fnScroll = ()=>
      window.scrollTo(0, 1) # pan to the bottom, hides the location bar  

    setTimeout(fnScroll, 100)


# ==================================================================================================================
# 
class OrientationHandler

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (@elementHandler, @path = "", @stylesheetElement, @pageWrapperElement)->

    @orientation = null
    @size = null

#    @stylesheetElement = ElementHandler.getElement(stylesheet)
#    @pageWrapperElement = ElementHandler.getElement(pageWrapper)

    this.updateOrientation()

    this

  # ----------------------------------------------------------------------------------------------------------------
  getOrientation: ()-> @orientation

  # ----------------------------------------------------------------------------------------------------------------
  getOrientationSize: ()-> @size

  # ----------------------------------------------------------------------------------------------------------------
  getScreenSizeOverride: ()->

    URL.getArg(["s", "size"], ["small", "medium"])

  # ----------------------------------------------------------------------------------------------------------------
  getOrientationOverride: ()->

    URL.getArg(["o","orientation"], ["landscape", "portrait"])

  # ----------------------------------------------------------------------------------------------------------------
  setOrientationStyle: (orientation)->

    if (overrideOrientation = this.getOrientationOverride())?
      orientation = overrideOrientation

    @orientation = orientation

    type = Device.getType()

    if not (@size = this.getScreenSizeOverride())?
      @size = switch type
        when "iPhone"
          "small"
        when "iPad"
          "medium"
        else
          if Device.isBigScreen()
            "medium"
          else
            "small"

#    alert "Size=#{@size} Orientation=#{@orientation}"

    format = "#{@size}-#{@orientation}"

    if (type is "iPhone" and Device.isiPhoneWith4InchScreen()) or URL.hasArg("iPhone5")
      format += "-iPhone4Inch"
#      alert "iPhone 5"

    @elementHandler.applyControl("format", format)

    if @size is "medium"
      @stylesheetElement.setAttribute("href", "#{@path}medium.css")

    @elementHandler.applyControl("density", Device.getDensity())

    if not Browser.isFullScreen()
      Browser.hideLocationBar()

    this

  # ----------------------------------------------------------------------------------------------------------------
  doOrientationTransition: (orientation)->

    Debug.set("Orientation changed to #{orientation}")

    @pageWrapperElement.setStyleProperty("opacity", 0)

    fn = ()=>
      this.setOrientationStyle(orientation)
      @pageWrapperElement.setStyleProperty("opacity", 1)
      Browser.hideLocationBar()
      Debug.set("Orientation transition completed")

    setTimeout(fn, 1000)

    this

  # ----------------------------------------------------------------------------------------------------------------
  swapOrientation: ()->

    orientation = if not @orientation?
      Device.getOrientation()
    else
      switch @orientation
        when "portrait"
          "landscape"
        when "landscape"
          "portrait"

    this.doOrientationTransition(orientation)

  # ----------------------------------------------------------------------------------------------------------------
  updateOrientation: ()->

    orientation = Device.getOrientation()

    if not @orientation?
      this.setOrientationStyle(orientation)
      @pageWrapperElement.setStyleProperty("opacity", 1)
    else
      if @orientation isnt orientation
        this.doOrientationTransition(orientation)

    Browser.hideLocationBar()

    this

# ==================================================================================================================
# 
class URL

  # ----------------------------------------------------------------------------------------------------------------
  @getArgs: ()->
    args = []

    searchString = document.location.search

    searchString = searchString.substring(1)

    for pair in searchString.split("&")
      vn = pair.split("=")
      args.push {name: vn[0], value: vn[1]}

    args

  # ----------------------------------------------------------------------------------------------------------------
  @getArg: (names, allowedValues=null)->

    if (arg = URL.getArg_(names))?
      if allowedValues? 
        URL.checkAllowedValues(arg.value, allowedValues)
      else      
        arg.value
    else
      null

  # ----------------------------------------------------------------------------------------------------------------
  @getArg_: (names)->
    for name in names
      for arg in URL.getArgs()
        if arg.name is name
          return arg

    return null
  
  # ----------------------------------------------------------------------------------------------------------------
  @checkAllowedValues: (value, allowedValues)->

    for v in allowedValues
      if v is value
        return value
    return null

  # ----------------------------------------------------------------------------------------------------------------
  @hasArg: (name)->

    URL.getArg_([name])?

# ==================================================================================================================
# 

class Cookie

  # ----------------------------------------------------------------------------------------------------------------
  @set: (name, value, expires=null, path="/", domain=null, secure=null)->

    today = new Date()
    today.setTime( today.getTime() )

    cookie = "#{name}=#{escape(value)}"

    # if the expires variable is set, make the correct
    # expires time, the current script below will set
    # it for x number of days, to make it for hours,
    # delete * 24, for minutes, delete * 60 * 24

    if expires?
      expires = expires * 1000 * 60 * 60 * 24
      expires_date = new Date( today.getTime() + (expires) )
      cookie += ";expires=" + expires_date.toGMTString()

    if path?
      cookie += ";path=" + path

    if domain?
      cookie += ";domain=" + domain

    if secure?
      cookie += ";secure"

    document.cookie = cookie

    null

  # ----------------------------------------------------------------------------------------------------------------
  # this fixes an issue with the old method, ambiguous values
  # with this test document.cookie.indexOf( name + "=" );
  #
  @get: (check_name)->

    # first we'll split this cookie up into name/value pairs
    # note: document.cookie only returns name=value, not the other components
    a_all_cookies = document.cookie.split( ';' )
    a_temp_cookie = ''
    cookie_name = ''
    cookie_value = null
    b_cookie_found = false # set boolean t/f default f

    for s in a_all_cookies
      # now we'll split apart each name=value pair
      a_temp_cookie = s.split( '=' );

      # and trim left/right whitespace while we're at it
      cookie_name = a_temp_cookie[0].replace(/^\s+|\s+$/g, '')

      # if the extracted name matches passed check_name
      if cookie_name is check_name
        b_cookie_found = true
        
        # we need to handle case where cookie has no value but exists (no = sign, that is):
        if a_temp_cookie.length > 1
          cookie_value = unescape( a_temp_cookie[1].replace(/^\s+|\s+$/g, '') )

        # note that in cases where cookie is initialized but no value, null is returned
        return cookie_value

      a_temp_cookie = null
      cookie_name = ''

    if not b_cookie_found
      return null

    null

  # ----------------------------------------------------------------------------------------------------------------
  @delete: (name, path="/", domain=null)->

    if Cookie.get(name)?

      v = name + "="

      if path?
        v += ";path=" + path

      if domain?
        v += ";domain=" + domain

      v += ";expires=Thu, 01-Jan-1970 00:00:01 GMT"

      document.cookie = v

    null

  # ----------------------------------------------------------------------------------------------------------------
  @test: ()->

    Cookie.set('test', 'it works', null, '/', null, null)

    if Cookie.get('test')?
      alert "Cookie Test: should have a value: " + Cookie.get('test')

    Cookie.delete('test', '/', null)

    if Cookie.get('test')
      alert "Cookie Test: should not have a value: " + Cookie.get('test')
    else
      alert "Cookie Test: Correct - no value!"

    null

# ==================================================================================================================
class Element

  # ----------------------------------------------------------------------------------------------------------------
  @getElementByID: (ID)->

    document.getElementById(ID)

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (@elementHandler, @ID)->

    @element = Element.getElementByID(@ID)
    @visible = false

    this

  # ----------------------------------------------------------------------------------------------------------------
  isValidElement: ()->
    @element?

  # ----------------------------------------------------------------------------------------------------------------
  getElement: ()-> @element

  # ----------------------------------------------------------------------------------------------------------------
  focus: ()->
    this.getElement().focus()

    this
  # ----------------------------------------------------------------------------------------------------------------
  getValue: ()-> @element.value

  # ----------------------------------------------------------------------------------------------------------------
  setValue: (value = "")-> 

    @element?.value = value

  # ----------------------------------------------------------------------------------------------------------------
  setInnerHTML: (text)->
    @element.innerHTML = text
    this

  # ----------------------------------------------------------------------------------------------------------------
  getInnerHTML: ()->
    @element.innerHTML

  # ----------------------------------------------------------------------------------------------------------------
  setClass: (className)->

    @element.setAttribute("class", className)

  # ----------------------------------------------------------------------------------------------------------------
  setAttribute: (attributeName, value)->

    if @element?
      @element.setAttribute(attributeName, value)
    else
      alert "Trivially Error: null element in setAttribute(#{attributeName},#{value})"
    null

  # ----------------------------------------------------------------------------------------------------------------
  setStyleProperty: (attribute, value)->

#    alert "Prop: #{@ID} #{attribute}=#{value}"

    if @element? 
      switch attribute
        when "visibility"
          @element.style.visibility = value 
        when "display"
          @element.style.display = value 
        when "opacity"
          @element.style.opacity = value 
        when "color"
          @element.style.color = value

    null

# ==================================================================================================================
# 
class TextElement extends Element

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (elementHandler, ID)->

    super elementHandler, ID

  # ----------------------------------------------------------------------------------------------------------------
  set: (text)->
    if text?
      this.setInnerHTML(text)
    text

  # ----------------------------------------------------------------------------------------------------------------
  clear: ()->
    this.setInnerHTML("")

# ==================================================================================================================
# 
class InputTextElement extends Element

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (elementHandler, ID)->

    super elementHandler, ID

  # ----------------------------------------------------------------------------------------------------------------
  getValue: ()->

    if @element?
      @element.value
    else
      ""

  # ----------------------------------------------------------------------------------------------------------------
  clearValue: ()->

    @element?.value = ""

# ==================================================================================================================
# 
class NumberElement extends Element

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (elementHandler, ID)->

    super elementHandler, ID

    @value = 0
 
    this.set()

  # ----------------------------------------------------------------------------------------------------------------
  set: (value = @value)->
    @value = value
    this.setInnerHTML(@value)
    @value

  # ----------------------------------------------------------------------------------------------------------------
  increment: (amount=1)->

    this.set(@value + amount)
    @value

  # ----------------------------------------------------------------------------------------------------------------
  clear: ()->
    @value = 0
    this.setInnerHTML("")

# ==================================================================================================================
# Represents a specific single text element, such as a debug element 
#
class DedicatedTextElement extends TextElement

  # ----------------------------------------------------------------------------------------------------------------
  set_alert: (message)->
    alert(message)

    this

  # ----------------------------------------------------------------------------------------------------------------
  getCounter: ()-> @counter

# ==================================================================================================================
# 
class Debug extends DedicatedTextElement

  kShowDebug = false

  gTag = "?"
  gInstance = null

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (elementHandler, ID)->

    gInstance = this

    super elementHandler, ID

  # ----------------------------------------------------------------------------------------------------------------
  @setTag: (tag)->
    gTag = tag

  # ----------------------------------------------------------------------------------------------------------------
  @set: (message = "")->

    if kShowDebug or URL.hasArg("debug")
      if gInstance?
        gInstance.set("#{gTag}: #{message}")
      else
        if message?
          DedicatedTextElement.set_alert(message)

    message

  # ----------------------------------------------------------------------------------------------------------------
  @clear: ()->

    if gInstance?
      gInstance.clear()

    this


# ==================================================================================================================
# 
class Info extends DedicatedTextElement

  gInstance = null

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (elementHandler, ID)->

    gInstance = this

    super elementHandler, ID

    @secondaryCounter = 0

    @info2Element = ElementHandler.getElement("info2")

    this

  # ----------------------------------------------------------------------------------------------------------------
  set: (message)->

    this.setSecondary()

    super

  # ----------------------------------------------------------------------------------------------------------------
  setSecondary: (message = "")->

    @info2Element?.set(message)

    ++@secondaryCounter

  # ----------------------------------------------------------------------------------------------------------------
  clear: ()->
    super
    @info2Element?.clear()
    this

  # ----------------------------------------------------------------------------------------------------------------
  getSecondaryCounter: ()-> @secondaryCounter

  # ----------------------------------------------------------------------------------------------------------------
  @getSecondaryCounter: ()-> 
    gInstance.getSecondaryCounter()

  # ----------------------------------------------------------------------------------------------------------------
  @set: (message = "")->

    if gInstance?
      gInstance.set(message)
    else
      if message?
        DedicatedTextElement.set_alert(message)

    message

  # ----------------------------------------------------------------------------------------------------------------
  @setSecondary: (message = "")->

    if gInstance?
      gInstance.setSecondary(message)
    else
      -1

  # ----------------------------------------------------------------------------------------------------------------
  @clear: ()->

    if gInstance?
      gInstance.clear()

    this


# ==================================================================================================================
# 
class Info3 extends DedicatedTextElement

  gInstance = null

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (elementHandler, ID)->

    gInstance = this

    super elementHandler, ID

    this

  # ----------------------------------------------------------------------------------------------------------------
  set: (message)->

    super

  # ----------------------------------------------------------------------------------------------------------------
  @set: (message = "")->

    if gInstance?
      gInstance.set(message)

    message

  # ----------------------------------------------------------------------------------------------------------------
  @clear: ()->

    if gInstance?
      gInstance.clear()

    this


# ==================================================================================================================
# 
class Copyright extends DedicatedTextElement

  gInstance = null
  kCopyright = "Copyright© 2013 Hyperbotic Labs, Inc. \“CrowdGame\” and \“Trivially\” are Trademarks of Hyperbotic Labs, Inc. All Rights Reserved."

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (elementHandler, ID)->

    gInstance = this

    super elementHandler, ID

    this.set(kCopyright)

    this

# ==================================================================================================================
# 
class ImageElement extends Element

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (elementHandler, ID)->

    super elementHandler, ID

  # ----------------------------------------------------------------------------------------------------------------
  setSrc: (src)->
    @src = src

    @element.src = src

    this

  # ----------------------------------------------------------------------------------------------------------------
  setDimensions: (width, height)->

    if width?
      @width = width
      @element.width = @width

    if height?
      @height = height
      @element.height = @height

    this

  # ----------------------------------------------------------------------------------------------------------------
  clear: ()->
    @element.src=null

# ==================================================================================================================
# 
class ButtonElement extends Element

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (elementHandler, ID)->

    super elementHandler, ID


# ==================================================================================================================
# 
class AnswerButtonElement extends ButtonElement

  gInstances = []

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (elementHandler, ID)->

    gInstances.push this

    super elementHandler, ID

  # ----------------------------------------------------------------------------------------------------------------
  setEmphasis: (value="none")->

    this.setAttribute("emphasis", value)

  # ----------------------------------------------------------------------------------------------------------------
  @setEmphasisByButtonCode: (buttonCode, value="none")->

    ElementHandler.getElement("button_#{buttonCode}").setEmphasis(value)
    
  # ----------------------------------------------------------------------------------------------------------------
  @setAllEmphasis: (value="none")->

    for button in gInstances
      button.setEmphasis(value)

# ==================================================================================================================
# 
class RadioButtonElement extends ButtonElement

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (elementHandler, ID)->

    super elementHandler, ID

  # ----------------------------------------------------------------------------------------------------------------
  isChecked: ()->

    if @element?
      @element.checked
    else
      false

  # ----------------------------------------------------------------------------------------------------------------
  setChecked: (checked = true)->

    if @element?
      @element.checked = checked

    checked

# ==================================================================================================================
# 
class AlertElement extends Element

  gAlertInProgress = false
  kAnimationDuration = 500 # Should be slightly longer than CSS animation duration

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (elementHandler, ID)->

    super elementHandler, ID

    @text1Element = ElementHandler.getElement("#{ID}_text_1")
    @text2Element = ElementHandler.getElement("#{ID}_text_2")
    @inputElement = ElementHandler.getElement("#{ID}_input")

    @fnCallback = null

    this

  # ----------------------------------------------------------------------------------------------------------------
  isAlertInProgress: ()-> gAlertInProgress

  # ----------------------------------------------------------------------------------------------------------------
  handler: (response)->

    @fnCallback?(response)

    this

  # ----------------------------------------------------------------------------------------------------------------
  show: (text1, text2, fnCallback)->

    ok = if not this.isAlertInProgress()

      gAlertInProgress = true

      @fnCallback = fnCallback

      @text1Element?.set(text1)
      @text2Element?.set(text2)
      this.setStyleProperty("visibility", "visible")
      @inputElement.focus()
      this.setStyleProperty("opacity", 1) # Will trigger CSS animation

      true

    else
      false

    ok

  # ----------------------------------------------------------------------------------------------------------------

  hide: ()->

    gAlertInProgress = false

    this.setStyleProperty("opacity", 0) # Will trigger CSS animation

    window.setTimeout( (()=>this.setStyleProperty("visibility", "hidden")), kAnimationDuration) # Wait for animation

    this

  # ----------------------------------------------------------------------------------------------------------------
  getValue: ()->

    @inputElement?.getValue()

  # ----------------------------------------------------------------------------------------------------------------
  setValue: (value = "")-> 

    @inputElement?.setValue(value)

    this


# ==================================================================================================================
# 
class ElementHandler

  gInstance = null

  instances = {}

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (@app, @elements)->
    gInstance = this

    this

  # ----------------------------------------------------------------------------------------------------------------
  initElements: ()->

    view = null

    for e in @elements
      @app["_#{e.ID}"] = instances[e.ID] = if e.ctor? 
        e.ctor(this, e.ID) 
      else 
        if e.klass?
          new e.klass(this, e.ID)       
        else
          alert "Trivially Error: Initialization problem with element \"#{e.ID}\""
          null

    this

  # ----------------------------------------------------------------------------------------------------------------
  getElements: ()-> @elements

  # ----------------------------------------------------------------------------------------------------------------
  @getElement: (ID)->

    instances[ID]

  # ----------------------------------------------------------------------------------------------------------------
  loaded: ()->

    this.initElements()

    this

  # ----------------------------------------------------------------------------------------------------------------
  applyControl: (kind, value)->

    for element in this.getElements()
      if element.controls?
        for control in element.controls
          if control is kind
            if (e = ElementHandler.getElement(element.ID)) and e.isValidElement()
              e.setAttribute(kind, value)
            else
              alert "Trivially Error: element \"#{element.ID}\" not in DOM"

    this


# ==================================================================================================================
#
class TransitionHandler

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (@app, @transitions, @elementHandler)->

  # ----------------------------------------------------------------------------------------------------------------
  doOpTransition: (op, message)->

    if (m = @transitions[op])? 
      @elementHandler.applyControl("op", op)

      if m.userInfo?
        Info.set(m.userInfo(@app, message))

    m?

# ==================================================================================================================
if window?
  if window.Hyperbotic?
    null
#     alert("window.HY exists")
  else
#    alert("window.HY does not exist")
    window.Hyperbotic = {}

  if not Hyperbotic?
    Hyperbotic = window.Hyperbotic

  window.Hy = Hy = Hyperbotic

  if not window.Hyperbotic.Web?
    window.Hyperbotic.Web = {}

  window.Hyperbotic.Web.HTTPRequest = HTTPRequest
  window.Hyperbotic.Web.Connection = Connection
  window.Hyperbotic.Web.WebSocketConnection = WebSocketConnection
  window.Hyperbotic.Web.Device = Device
  window.Hyperbotic.Web.Browser = Browser
  window.Hyperbotic.Web.OrientationHandler = OrientationHandler
  window.Hyperbotic.Web.URL = URL
  window.Hyperbotic.Web.Cookie = Cookie
  window.Hyperbotic.Web.Element = Element
  window.Hyperbotic.Web.TextElement = TextElement
  window.Hyperbotic.Web.InputTextElement = InputTextElement
  window.Hyperbotic.Web.NumberElement = NumberElement
  window.Hyperbotic.Web.Debug = Debug
  window.Hyperbotic.Web.Info = Info
  window.Hyperbotic.Web.Info3 = Info3
  window.Hyperbotic.Web.Copyright = Copyright
  window.Hyperbotic.Web.ImageElement = ImageElement
  window.Hyperbotic.Web.ButtonElement = ButtonElement
  window.Hyperbotic.Web.RadioButtonElement = RadioButtonElement
  window.Hyperbotic.Web.AnswerButtonElement = AnswerButtonElement
  window.Hyperbotic.Web.AlertElement = AlertElement
  window.Hyperbotic.Web.ElementHandler = ElementHandler
  window.Hyperbotic.Web.TransitionHandler = TransitionHandler



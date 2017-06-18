# ==================================================================================================================
class HtmlPageUtility

  gUtilityElementNames = [
    "debug"
  ]

  # ----------------------------------------------------------------------------------------------------------------
  constructor: ()->

    @isLoaded = false
    @lastEventCounter = null

    this

  # ----------------------------------------------------------------------------------------------------------------
  initApp: (@app, @elementNames, @delayedElementSpecs)->

    this.addEventListener("_PageEventIn", (event)=>this.eventFired(event))

    this

  # ----------------------------------------------------------------------------------------------------------------
  # Copied from common/web_utils.coffee
  #
  hasRetinaDisplay: ()->

    window.devicePixelRatio? and (window.devicePixelRatio > 1)

  # ----------------------------------------------------------------------------------------------------------------
  addEventListener: (kind, fnEvent)->

    if Ti?
      Ti.App.addEventListener(kind, 
                              (event)=>
                                fnEvent(event)
                                null)

    this

  # ----------------------------------------------------------------------------------------------------------------
  fireEvent: (kind, data)->
    if Ti?
      Ti.App.fireEvent(kind, data)
    this

  # ----------------------------------------------------------------------------------------------------------------
  debug: (text)->

#    alert "Debug: #{text}"
#    @_debug.innertHTML = "\"text\""

    this

  # ----------------------------------------------------------------------------------------------------------------
  findElement: (name)->
    e = document.getElementById(name)

    if not e?
      alert "HTML Page: Couldn't find #{name}"

    e

  # ----------------------------------------------------------------------------------------------------------------
  initElements: ()->

    names = [].concat(@elementNames, gUtilityElementNames)

    for elementName in names
      @app["_#{elementName}"] = this.findElement(elementName)

    @delayedElements = []

    for e in @delayedElementSpecs
      r = 
        element: (@app["_#{e.id}"] = this.findElement(e.id)), 
        index: e.index, 
        src: if this.hasRetinaDisplay() and e.src2x? then e.src2x else e.src,
        loading: false,
        loaded: false

      @delayedElements.push r

    this

  # ----------------------------------------------------------------------------------------------------------------
  eventFired: (event)->

    this.debug("Event received: #{event.kind}")

    if @lastEventCounter? and (event._counter is @lastEventCounter)
      # ignore it
#      alert "Ignoring duplicate event ##{event._counter}"
    else
      method = "event_#{event.kind}"
      fn = @app[method]
      if fn? and typeof(fn) is "function"
        @app[method](event)
      else
        alert "Unknown event: #{event.kind}"

        @lastEventCounter = event._counter

    this

  # ----------------------------------------------------------------------------------------------------------------
  loaded: ()-> 

    @isLoaded = true
    this.initElements()

    this.loadDelayedElement()

    this

  # ----------------------------------------------------------------------------------------------------------------
  loadDelayedElement: ()->
    for e in @delayedElements
      if not e.loading and not e.loaded
        e.element.src = e.src
        e.loading = true

        return this

    this.loadedComplete()

    this

  # ----------------------------------------------------------------------------------------------------------------
  loadedDelayedElement: (elementIndex)->

    for e in @delayedElements
      if e.index is elementIndex
        e.loaded = true
        e.loading = false
        e.element.style.display = "block"
        break

    this.loadDelayedElement()

    this

  # ----------------------------------------------------------------------------------------------------------------
  loadedComplete: ()->

    this.fireEvent("_pageEventOut", {kind: "pageLoaded"})

    this

# ==================================================================================================================

window.htmlPageUtility = new HtmlPageUtility()


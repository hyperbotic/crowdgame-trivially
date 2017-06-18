class HtmlQuestionPage

  delayedElementSpecs = [
      {id: "black",                     index:  1, src: "assets/bkgnds/animations/black.png"},
      {id: "left_front_curtain",        index:  2, src: "assets/bkgnds/animations/intro-left-front-curtain.jpg"},
      {id: "right_front_curtain",       index:  3, src: "assets/bkgnds/animations/intro-right-front-curtain.jpg"},
  ]

  elementNames = [
    "page_wrapper",
    "question",
    "answer_A",
    "answer_B",
    "answer_C",
    "answer_D"
  ]

  # ----------------------------------------------------------------------------------------------------------------
  constructor: ()->

    if (@utility = window.htmlPageUtility)?
      @utility.initApp(this, elementNames, delayedElementSpecs)

    this

  # ----------------------------------------------------------------------------------------------------------------
  event_animateIn: (event)=>

    @_black.style.opacity = 0

    if event.data.useCurtains
      @_left_front_curtain.style.webkitTransform = "translate3d(-514px, 0, 0)"
      @_right_front_curtain.style.webkitTransform = "translate3d(514px, 0, 0)"

    if event._responseRequired
      # App is expecting a reply
      event._responseCompleted = true
      setTimeout( (()=>@utility.fireEvent("_pageEventOut", event)), 500)

    this

  # ----------------------------------------------------------------------------------------------------------------
  event_animateOut: (event)=>

    @_black.style.opacity = 1

    if event.data.useCurtains
      @_left_front_curtain.style.webkitTransform = ""
      @_right_front_curtain.style.webkitTransform = ""

    if event._responseRequired
      # App is expecting a reply
      event._responseCompleted = true
      setTimeout( (()=>@utility.fireEvent("_pageEventOut", event)), 800) # allow a little extra time

    this

  # ----------------------------------------------------------------------------------------------------------------
  event_initializePage: (event)->

    this.initPageContent(event.data)

    this.resetEmphasis()

    if event._responseRequired
      # App is expecting a reply
      event._responseCompleted = true
      @utility.fireEvent("_pageEventOut", event)

    this

  # ----------------------------------------------------------------------------------------------------------------
  event_showConsoleSelection: (event)->
    @answers[event.data.indexSelectedAnswer].setAttribute("emphasis", "selected")

  # ----------------------------------------------------------------------------------------------------------------
  event_revealAnswer: (event)->

    for i in [0..3]
      @answers[i].setAttribute("emphasis", if i is event.data.indexCorrectAnswer then "correct" else "incorrect")

    this

  # ----------------------------------------------------------------------------------------------------------------
  resetEmphasis: ()->

    for i in [0..3]
      @answers[i].setAttribute("emphasis", "none")

  # ----------------------------------------------------------------------------------------------------------------
  initAnswerElements: ()->

    @answers = (this["_answer_#{letter}"] for letter in ["A", "B", "C", "D"])

  # ----------------------------------------------------------------------------------------------------------------
  questionFontSizes: ()->
    [
      78,
      66,
      56,
      50,
      48,
      42,
      36,
      25  #failsafe
    ]

  # ----------------------------------------------------------------------------------------------------------------
  answerFontSizes: ()->
    [
      66,
      56,
      50,
      48,
      42,
      36,
      33,
      25  #failsafe
    ]

  # ----------------------------------------------------------------------------------------------------------------
  testData: (data)->

    data.question = {}
    data.question.text = "Which Bavarian castle did Walt Disney sculpt Cinderella's after?"

    data.answers = []
    for i in [0..3]
      data.answers[i] = {}

    data.answers[0].text = "Neuschwanstein Castle"
#    data.answers[1].text = "Mad King Ludwig's"
    data.answers[1].text = "1984"
    data.answers[2].text = "The Home of the Studious Megakao"
    data.answers[3].text = "Neuschwanstein Castle"

    data

  # ----------------------------------------------------------------------------------------------------------------
  initPageContent: (data)->

    this.initAnswerElements()

#    this.testData(data)

    @_question.innerHTML = data.question.text
    questionFontSize = this.findBestFontSize(@_question, {height: 195, width: 848}, this.questionFontSizes())

    @_question.style.fontSize = "#{questionFontSize}px"

    for i in [0..3]
      @answers[i].innerHTML = data.answers[i].text
      fontSize = this.findBestFontSize(@answers[i], {height: 186, width: 380}, this.answerFontSizes())
      @answers[i].style.fontSize = "#{fontSize}px"

    this

  # ----------------------------------------------------------------------------------------------------------------
  findBestFontSize: (element, maxDimensions, fontSizes)->

    heightNormal = heightBreakWord = "??"

    for size in fontSizes
      element.style.fontSize = "#{size}px"

      element.style.wordWrap = "normal"
      heightNormal = element.clientHeight
      widthNormal = element.clientWidth

      element.style.wordWrap = "break-word"
      heightBreakWord = element.clientHeight
      widthBreakWord = element.clientWidth

      if (heightBreakWord is heightNormal) and (heightNormal <= maxDimensions.height) and 
         (widthBreakWord is widthNormal) and (widthNormal <= maxDimensions.width)
#        alert "Text:#{element.innerHTML} width:#{heightBreakWord}/#{heightNormal} #{widthBreakWord}/#{widthNormal} font:#{size}"
        return size

    alert("Font: Failsafe current last heightNormal=#{heightNormal} heightBreakWord=#{heightBreakWord}")

    return 30

  # ----------------------------------------------------------------------------------------------------------------
  findBestFontSize2: (element, maxDimensions, fontSizes)->

    fnOK = ()=> (element.clientHeight <= maxDimensions.height) and (element.clientWidth <= maxDimensions.width)

    for size in fontSizes
      element.style.fontSize = "#{size}px"

      if fnOK()
        return size

    if not fnOK()
      element.style.fontSize = "30px"
      this.debug("Font: Failsafe current height=#{element.clientHeight} current width=#{element.clientWidth}")

    null

 
# ==================================================================================================================

window.htmlQuestionPage = new HtmlQuestionPage()

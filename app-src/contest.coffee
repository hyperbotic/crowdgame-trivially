# ==================================================================================================================
class Contest
  gInstanceCount = 0
  
  # ----------------------------------------------------------------------------------------------------------------
  constructor: ()->

    @instance = ++gInstanceCount
    @contestQuestions = []

    this

  # ----------------------------------------------------------------------------------------------------------------
  addQuestions: (contentPack, numQuestionsNeeded)->
    q = _.min(contentPack.getContent(), (q)->Hy.Content.Questions.getUsageCount(q))

    minDisplayCount = Hy.Content.Questions.getUsageCount(q)

    numQuestionsAdded = if (numRecords = contentPack.getNumRecords()) < numQuestionsNeeded
      numRecords
    else
      numQuestionsNeeded

    # Returns actual number added
    this.addQuestions_(contentPack, minDisplayCount, numQuestionsAdded)

  # ----------------------------------------------------------------------------------------------------------------
  addQuestions_: (contentPack, minDisplayCount, nNeeded)->

    numAdded = 0

    questions = contentPack.getContent()

    qs = _.select(questions, (q)->Hy.Content.Questions.getUsageCount(q) is minDisplayCount)

    # Check for duplicates
    currentQuestions = _.map(@contestQuestions, (contestQuestion)=>contestQuestion.getQuestion())
    qs = _.without(qs, currentQuestions)

    if qs.length is 0
      null # huh
    else
      numAdded = nNeeded

      if qs.length > nNeeded
        # more eligible questions than we need, so select randomly:
        for i in [0...nNeeded]
          q1 = qs[Hy.Utils.Math.random(_.size(qs))]
          qs = _.reject(qs, (q)->q.id is q1.id)
          @contestQuestions.push(new ContestQuestion(this, contentPack, q1)) 
      else
        # first include all questions returned in select:
        @contestQuestions.push(new ContestQuestion(this, contentPack, q)) for q in qs

        # now fill up remainder with next set:
        if (remainingNeeded = nNeeded - qs.length) > 0
          this.addQuestions_(contentPack, ++minDisplayCount, remainingNeeded)

    numAdded

  # ----------------------------------------------------------------------------------------------------------------
  getQuestions: ()-> @contestQuestions

# ==================================================================================================================
class ContestQuestion
  # ----------------------------------------------------------------------------------------------------------------
  constructor: (@contest, @contentPack, @question)->
    @questionText = @question.question

    indeces = Hy.Utils.Array.shuffle([0,1,2,3])
    @answers = (@question["answer#{index+1}"] for index in indeces)

#    as = @question.answers
#    @answers = (as[index] for index in indeces)

    i = 0
    i++ while (indeces[i] != 0 and i < indeces.length)
    @indexCorrectAnswer = i

    @used = false

    gInstances.push this

    this

  # ----------------------------------------------------------------------------------------------------------------
  # Class Methods:
  # ----------------------------------------------------------------------------------------------------------------
  gInstances = []

  # ----------------------------------------------------------------------------------------------------------------
  # TODO: is this ever used??
  @collection: ()->gInstances
  
  # ----------------------------------------------------------------------------------------------------------------
  @findByQuestionID: (contestQuestions, questionID)->
    for cq in contestQuestions
      return cq if cq.question.id is questionID
    null
    
  # ----------------------------------------------------------------------------------------------------------------
  # Instance Methods:
  # ----------------------------------------------------------------------------------------------------------------
  getContentPack: ()-> @contentPack
  # ----------------------------------------------------------------------------------------------------------------
  getQuestionID: ()-> @question.id

  # ----------------------------------------------------------------------------------------------------------------
  getQuestionText: ()-> @questionText

  # ----------------------------------------------------------------------------------------------------------------
  getAnswerText: (index)-> @answers[index]

  # ----------------------------------------------------------------------------------------------------------------
  getQuestion: ()-> @question
  
  # ----------------------------------------------------------------------------------------------------------------
  setUsed: ()->
    @used = true
    Hy.Content.Questions.incrementUsageCount(@question)
    this

  # ----------------------------------------------------------------------------------------------------------------
  wasUsed: ()-> @used

# ==================================================================================================================
class ContestResponse

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (@player, @contestQuestion, @answerIndex, @startTime, @answerTime)->

    gInstances.push this
    @instance = ++gInstanceCount

    @correct = (@answerIndex is @contestQuestion.indexCorrectAnswer)
    @score = null

    this

  # ----------------------------------------------------------------------------------------------------------------
  # Class Methods:
  # ----------------------------------------------------------------------------------------------------------------
  gInstances = []
  gInstanceCount = 0

  # ----------------------------------------------------------------------------------------------------------------
  @collection: ()->gInstances
  
  # ----------------------------------------------------------------------------------------------------------------
  # Returns responses for the CURRENT contest
  @selectByQuestionID: (questionID)->

    fnFilter = (response)->
      cq = response.contestQuestion
      (cq.getQuestionID() is questionID) and (cq.contest is Hy.ConsoleApp.get().contest)

    filteredResponses = _.select gInstances, fnFilter

    fnSortBy = (r)->
      r.instance
    sortedResponses = _.sortBy filteredResponses, fnSortBy

  # ----------------------------------------------------------------------------------------------------------------
  # Returns responses for the CURRENT contest
  @selectByQuestionIDAndPlayer: (questionID, player)->

    responses = ContestResponse.selectByQuestionID(questionID)
    for r in responses
      if r.player.index is player.index
        return r

    return null

  # ----------------------------------------------------------------------------------------------------------------
  # Returns responses for the CURRENT contest
  @selectByPlayer: (player)->

    responses = []

    for r in gInstances
      if (r.player.index is player.index) and (r.contestQuestion.contest is Hy.ConsoleApp.get().contest)
        responses.push r

    responses

  # ----------------------------------------------------------------------------------------------------------------
  # Instance Methods:
  # ----------------------------------------------------------------------------------------------------------------
  contest: ()->@contestQuestion.contest

  # ----------------------------------------------------------------------------------------------------------------
  getPlayer: ()-> @player
  # ----------------------------------------------------------------------------------------------------------------
  getCorrect: ()-> @correct

  # ----------------------------------------------------------------------------------------------------------------
  getStartTime: ()-> @startTime

  # ----------------------------------------------------------------------------------------------------------------
  getAnswerTime: ()-> @answerTime

  # ----------------------------------------------------------------------------------------------------------------
  getScore: ()->

    if not @score?
      @score = this.computeScore()

    @score

  # ----------------------------------------------------------------------------------------------------------------
  computeScore: ()->

    score = 0

    if this.getCorrect()
      switch this.getStartTime() - this.getAnswerTime()
        when 0, 1, 2, 3
          score = 3
        when 4, 5, 6
          score = 2
        else
          score = 1

    score

# ==================================================================================================================
# assign to global namespace:
Hy.Contest =
  Contest:         Contest
  ContestQuestion: ContestQuestion
  ContestResponse: ContestResponse


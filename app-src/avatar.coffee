# ==================================================================================================================
# Represents a group of avatars that work together as a team
# Generally speaking, there is only one instance of AvatarSet around at a time
#
class AvatarSet

  gInstance = null

  # ----------------------------------------------------------------------------------------------------------------
  @init: (avatarSetSpec=Hy.Config.Avatars.gameshow)->

    if not gInstance?
      gInstance = new AvatarSet(avatarSetSpec).loadSet()

    gInstance

  # ----------------------------------------------------------------------------------------------------------------
  @getCurrent: ()->
    gInstance

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (@avatarSetSpec)->

    @avatarSpecs = []

    this

  # ----------------------------------------------------------------------------------------------------------------
  numAvatars: ()->

    _.size(@avatarSpecs)

  # ----------------------------------------------------------------------------------------------------------------
  getProperty: (property)-> 
    @avatarSetSpec[property]

  # ----------------------------------------------------------------------------------------------------------------
  isAnimated: ()->
    this.getProperty("animated")

  # ----------------------------------------------------------------------------------------------------------------
  getAvatarSetName: ()-> 
    this.getProperty("name")

  # ----------------------------------------------------------------------------------------------------------------
  getWidth: ()->
    this.getProperty("width")

  # ----------------------------------------------------------------------------------------------------------------
  getHeight: ()->
    this.getProperty("height")

  # ----------------------------------------------------------------------------------------------------------------
  getPadding: ()->
    this.getProperty("padding")

  # ----------------------------------------------------------------------------------------------------------------
  findAvailableAvatar: ()->
    _.detect(Hy.Utils.Array.shuffle(@avatarSpecs), (a)=>not a.inUse)

  # ----------------------------------------------------------------------------------------------------------------
  findAvatarSpec: (avatar)->
    _.detect(@avatarSpecs, (a)=>a.avatar is avatar)

  # ----------------------------------------------------------------------------------------------------------------
  assignAvatar: ()->

    avatar = null

    avatarSpec = this.findAvailableAvatar()

    if avatarSpec?
      avatar = avatarSpec.avatar
      avatarSpec.inUse = true
    else
      new Hy.Utils.ErrorMessage("fatal", "Avatar", "Not enough Avatars")

    avatar

  # ----------------------------------------------------------------------------------------------------------------
  unassignAvatar: (avatar)->

    this.findAvatarSpec(avatar)?.inUse = false

  # ----------------------------------------------------------------------------------------------------------------
  # "private" methods
  # ----------------------------------------------------------------------------------------------------------------
  scanDirectoryForAvatars: ()->
    files = []

    directory = this.getAvatarSetDirectory()

    d = Ti.Filesystem.getFile(directory)
    dirList = d.getDirectoryListing()

    for filename in dirList

      if filename.match(/^\w+$/)?
#        Hy.Trace.debug "AvatarSet::scanDirectoryForAvatars (file=#{filename})"
        files.push filename

    files

  # ----------------------------------------------------------------------------------------------------------------
  # Apparent bug with regex forces duplication of this code
  #
  scanDirectoryForAvatarSequence: (avatarName, sequenceName)->

    files = []

    d = Ti.Filesystem.getFile(this.getAvatarDirectory(avatarName))
    dirList = d.getDirectoryListing()

    for filename in dirList
      matches = false

      if filename.match(/^\w+-\d.png$/)?
        if filename.indexOf("#{sequenceName}-") is 0
          matches = true

#      Hy.Trace.debug "AvatarSet::scanDirectoryForAvatarSequence (avatarName=#{avatarName} sequenceName=#{sequenceName} file=#{filename} matches=#{matches})"

      if matches
        files.push filename

    files

  # ----------------------------------------------------------------------------------------------------------------
  loadSet: ()->

    for filename in Hy.Utils.Array.shuffle(this.scanDirectoryForAvatars())
      this.load(filename)

    Hy.Trace.debug "AvatarSet::load #{this.getDumpStr()}"

    this

  # ----------------------------------------------------------------------------------------------------------------
  getAvatarSetDirectory: ()->

    "#{Hy.Config.Avatars.kShippedDirectory}/#{this.getAvatarSetName()}"

  # ----------------------------------------------------------------------------------------------------------------
  getAvatarDirectory: (avatar)->

    "#{this.getAvatarSetDirectory()}/#{avatar}"

  # ----------------------------------------------------------------------------------------------------------------
  load: (filename)->
    a = new Avatar(this, filename, this.getAvatarDirectory(filename))

    if a?
      @avatarSpecs.push {avatar:a, inUse: false}

    this

  # ----------------------------------------------------------------------------------------------------------------
  getDumpStr: ()->
    s = "AvatarSet: #{this.getAvatarSetName()} #=#{this.numAvatars()}"

    for a in @avatarSpecs
      s += " #{if a.inUse then "In Use " else " "}#{a.avatar.getDumpStr()}"

    s

# ==================================================================================================================
# Represents a specific avatar in an AvatarSet
# There is only one instance created for each specific avatar
# Manages all of the "poses" for an avatar, rendered on the AvatarStage.
#

class Avatar
  kWalkDuration = 300

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (@avatarSet, @name, @directory)->

    @walkDuration = null
    @walkDelta = null

    # Tracks sets of poses that form animation sequences
    @sequenceSpecs = []

    @defaultPose = this.getPoseByName("default-1")

    this

  # ----------------------------------------------------------------------------------------------------------------
  getWalkDuration: ()->

    kWalkDuration

  # ----------------------------------------------------------------------------------------------------------------
  getWalkDelta: ()->
    this.getWidth()/5

  # ----------------------------------------------------------------------------------------------------------------
  getName: ()-> @name

  # ----------------------------------------------------------------------------------------------------------------
  getPlayerName: ()-> @playerName

  # ----------------------------------------------------------------------------------------------------------------
  setPlayerName: (playerName)->

    @playerName = playerName

    Pose.applyByAvatar(this, (pose)=>pose.updatePlayerNameLabel())

    this

  # ----------------------------------------------------------------------------------------------------------------
  getWidth: ()->
    @avatarSet.getWidth()

  # ----------------------------------------------------------------------------------------------------------------
  getHeight: ()->
    @avatarSet.getHeight()

  # ----------------------------------------------------------------------------------------------------------------
  getPadding: ()->
    @avatarSet.getPadding()

  # ----------------------------------------------------------------------------------------------------------------
  getDirectory: ()-> @directory

  # ----------------------------------------------------------------------------------------------------------------
  getFilename: (pose)-> "#{pose}.png"

  # ----------------------------------------------------------------------------------------------------------------
  getAvatarSet: ()-> @avatarSet
 
  # ----------------------------------------------------------------------------------------------------------------
  getAvatarSetName: ()-> @avatarSet.getAvatarSetName()

  # ----------------------------------------------------------------------------------------------------------------
  isAnimated: ()-> @avatarSet.isAnimated()

  # ----------------------------------------------------------------------------------------------------------------
  getDumpStr: ()-> "Avatar:#{this.getName()}"

  # ----------------------------------------------------------------------------------------------------------------
  getPoses: ()->
    Pose.findAllByAvatar(this)

  # ----------------------------------------------------------------------------------------------------------------
  getPoseByName: (name)->

    if not (pose = Pose.findByAvatarAndName(this, name))?
      pose = new Pose(this, name)
    pose

  # ----------------------------------------------------------------------------------------------------------------
  getDefaultPose: ()-> @defaultPose

  # ----------------------------------------------------------------------------------------------------------------
  getSequencePoses: (sequenceName)->

    sequenceSpec = this.findSequenceSpec(sequenceName)

    if not sequenceSpec?
      sequenceSpec = this.createSequence(sequenceName)

    sequenceSpec.poses

  # ----------------------------------------------------------------------------------------------------------------
  findSequenceSpec: (sequenceName)->

    _.detect(@sequenceSpecs, (a)=>a.sequenceName is sequenceName)

  # ----------------------------------------------------------------------------------------------------------------
  createSequence: (sequenceName)->

    files = this.getAvatarSet().scanDirectoryForAvatarSequence(this.getName(), sequenceName)

    poses = for file in files
      name = file.substring(0, file.lastIndexOf(".png"))
      this.getPoseByName(name)

    sequenceSpec = {sequenceName:sequenceName, poses:poses}
    @sequenceSpecs.push sequenceSpec
 
    sequenceSpec

# ==================================================================================================================
class PlayerNameLabel extends Hy.UI.LabelProxy

  kHeight = 20

  # ----------------------------------------------------------------------------------------------------------------
  @getHeight: ()-> kHeight

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (@avatar, options)->

    super Hy.UI.ViewProxy.mergeOptions(this.defaultOptions(), options)

    this.setUIProperty("color", Hy.UI.Colors.white)

    this

  # ----------------------------------------------------------------------------------------------------------------
  getAvatar: ()-> @avatar

  # ----------------------------------------------------------------------------------------------------------------
  defaultOptions: ()->

    height: PlayerNameLabel.getHeight()
    width: this.getAvatar().getWidth()
    left: 0
    bottom: 0
    font: Hy.UI.Fonts.mergeFonts(Hy.UI.Fonts.specMinisculeNormal, {fontSize:14})
    textAlign: "center"
    color: Hy.UI.Colors.white
#    backgroundColor: Hy.UI.Colors.black
    backgroundImage: "assets/icons/avatar-name-background.png"
    text: this.getAvatar().getPlayerName()
#    borderColor: Hy.UI.Colors.white
#    borderWidth: 1

  # ----------------------------------------------------------------------------------------------------------------
  update: ()->

    this.setUIProperty("text", @avatar.getPlayerName())

    this
  
# ==================================================================================================================
# Represents a rendering of avatars on the screen. Instances come and go; typically there's only one around at a time.
#
#  _maxNumAvatars: the max number of avatars this stage should support. If not specified, defaults to the
#                  max number of players supported. This value is used to set width.
#
# Avatars are added via "addAvatar", and can be removed via "removeAvatar". An avatar can exist on the stage
# without being visible.
#
class AvatarStage extends Hy.UI.ViewProxy

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (options = {}, @avatarSet=AvatarSet.getCurrent())->

    defaultOptions = {}
#      borderWidth: 1
#      borderColor: Hy.UI.Colors.green

    if not options._orientation?
      defaultOptions._orientation = "horizontal"

    super Hy.UI.ViewProxy.mergeOptions(defaultOptions, options)

    # The avatars on this stage
    @avatarSpecs = []

    # The active animations on this stage
    @animationSequences = []

    if not (@maxNumAvatars = options._maxNumAvatars)?
      @maxNumAvatars = Hy.Config.Avatars.kMaxNumAvatars

    this.adjustDimensionsToFitAvatars()

    this

 # ----------------------------------------------------------------------------------------------------------------
  # "EXTERNAL" methods
  # ----------------------------------------------------------------------------------------------------------------
 # ----------------------------------------------------------------------------------------------------------------
  # options:
  #  _stageOrder:      for requests involving more than one avatar. Overrides "_stagePosition" to impose
  #                    the order in which the supplied avatars are animation. Valid values:
  #
  #                       "asProvided": avatars arranged in the order in which they appear in the
  #                                     supplied array of avatarSpecs. Used for Scoreboard, etc.
  #
  #                       "perAvatar" : use avatar._stagePosition if possible.
  #                                     Otherwise defaults to "natural".
  #                                     Used for Start page.
  #               
  #                       "fill"   :    Default. Places the avatar in the first available position or hole. Used
  #                                     for question/answer page.
  #
  #                       In all cases, if a requested position is null or already in use, reverts to "fill".
  #                                 
  #  _showCorrectness: true or false, according to whether the avatar's player answered correctly
  #
  #  _score:           avatar's player's score
  #
  animateAvatars: (avatarSpecs, animation, options={})->

    currentStagePosition = -1    

    for avatarSpec in avatarSpecs

      if (sequenceKind = this.getAnimationSequenceKind(avatarSpec, animation, options))?

        # Generally speaking, an avatar can only be doing one thing at a time
        this.applyToAnimationsByAvatar(avatarSpec.avatar, "destroyAnimation")

        this.computeStagePosition(avatarSpec, options, ++currentStagePosition, animation)

        animationSequence = new sequenceKind(this, avatarSpec.avatar, options)

        Hy.Trace.debug("AvatarStage::animateAvatar (STARTNG \"#{animation}\" #{avatarSpec.avatar.getDumpStr()})")

        animationSequence.animateStart()

    this

  # ----------------------------------------------------------------------------------------------------------------
  addAvatar: (avatar)->

    if not (avatarSpec = this.findByAvatar(avatar))?
      avatarSpec = {avatar:avatar, visible:false, _stagePosition:null}
      this.getAvatarSpecs().push avatarSpec

    avatarSpec

# ----------------------------------------------------------------------------------------------------------------
  removeAvatar: (avatarSpec)->

    Hy.Trace.debug("AvatarStage::removeAvatar (#{avatarSpec.avatar.getDumpStr()})")

    if (as = this.findByAvatar(avatarSpec.avatar))?
      # "destroyAnimation" will stop any animation, remove the active pose, and remove the animation itself.
      this.applyToAnimationsByAvatar(avatarSpec.avatar, "destroyAnimation")

      @avatarSpecs = _.without(@avatarSpecs, avatarSpec)

    this

 # ----------------------------------------------------------------------------------------------------------------
  initialize: ()->

    this.stop()
    @avatarSpecs = []

  # ----------------------------------------------------------------------------------------------------------------
  start: ()->
    this

  # ----------------------------------------------------------------------------------------------------------------
  # "stop" means "stop and terminate/destroy any ongoing animation". Does not remove avatars from the stage, etc.
  #
  stop: ()->
    this.applyToAllAnimations("destroyAnimation")

    this

  # ----------------------------------------------------------------------------------------------------------------
  pause: ()-> 
    this.applyToAllAnimations("pauseAnimation")

    this

  # ----------------------------------------------------------------------------------------------------------------
  resumed: ()->
    this.applyToAllAnimations("resumeAnimation")

    this

  # ----------------------------------------------------------------------------------------------------------------
  getDumpStr: ()->

    s = ""

    s += " #avatars=#{_.size(@avatarSpecs)}"

    for avatarSpec in @avatarSpecs
      s += " /#{avatarSpec.avatar.getDumpStr()} visible:#{this.isVisibleByAvatar(avatarSpec.avatar)} position:#{avatarSpec._stagePosition}/"

    s += " Sequences=#{_.size(@animationSequences)}"

    for sequence in @animationSequences
      s += " *#{sequence.getDumpStr()}*"

    s

 # ----------------------------------------------------------------------------------------------------------------
  #
  # "INTERNAL" methods
  #
  # ----------------------------------------------------------------------------------------------------------------

  # ----------------------------------------------------------------------------------------------------------------
  isSequenceOnStage: (sequence)->

    _.indexOf(@animationSequences, sequence) isnt -1

  # ----------------------------------------------------------------------------------------------------------------
  addSequenceToStage: (sequence)->

    if this.isSequenceOnStage(sequence)
      Hy.Trace.debug("AvatarStage.addSequenceToStage (ERROR SEQUENCE ALREADY ON STAGE stage=/#{this.getDumpStr()}/ sequence=/#{sequence.getDumpStr()}/)")
    else
      @animationSequences.push sequence

    this
      
  # ----------------------------------------------------------------------------------------------------------------
  removeSequenceFromStage: (sequence)->

    if this.isSequenceOnStage(sequence)
      @animationSequences = _.without(@animationSequences, sequence)
    else
      Hy.Trace.debug("AvatarStage.removeSequenceFromStage (ERROR SEQUENCE NOT ON STAGE stage=/#{this.getDumpStr()}/ sequence=/#{sequence.getDumpStr()}/)")

    this

  # ----------------------------------------------------------------------------------------------------------------
  isVisibleByAvatar: (avatar)->

    if (avatarSpec = this.findByAvatar(avatar))?
      avatarSpec.visible
    else
      false
  
  # ----------------------------------------------------------------------------------------------------------------
  setVisibleByAvatar: (avatar, visible)->

    if (avatarSpec = this.findByAvatar(avatar))?
      avatarSpec.visible = visible
  
    this
  
  # ----------------------------------------------------------------------------------------------------------------
  getMaxNumAvatars: ()-> @maxNumAvatars

  # ----------------------------------------------------------------------------------------------------------------
  adjustDimensionsToFitAvatars: ()->
    options = {}

    n = this.getMaxNumAvatars()

    if this.getOrientation() is "horizontal"
      options.height = this.getAvatarDisplayHeight() + PlayerNameLabel.getHeight()

      options.width = (n * this.getAvatarDisplayWidth()) + ((n - 1) * @avatarSet.getPadding())
    else
      options.width = this.getAvatarDisplayWidth()
      options.height = (n * (this.getAvatarDisplayHeight() + PlayerNameLabel.getHeight())) + ((n - 1) * @avatarSet.getPadding())

    this.setUIProperties(options)

    this

  # ----------------------------------------------------------------------------------------------------------------
  getOrientation: ()-> this.getUIProperty("_orientation")

  # ----------------------------------------------------------------------------------------------------------------
  # This class handles its own layout
  layoutChildren:()->

    this

  # ----------------------------------------------------------------------------------------------------------------
  getAvatarDisplayHeight: ()->
    this.getAvatarSet().getHeight()

  # ----------------------------------------------------------------------------------------------------------------
  getAvatarDisplayWidth: ()->
    this.getAvatarSet().getWidth()

  # ----------------------------------------------------------------------------------------------------------------
  requiresAvatarBacklighting: ()-> 

    if (prop = this.getUIProperty("_avatarBacklighting"))? 
      prop 
    else 
      false

  # ----------------------------------------------------------------------------------------------------------------
  # For any given avatar, there may be more than one pose on the stage at the same time; currently this
  # happens only during transitions (see AvatarAnimationSequence.transitionPose).
  #
  addPose: (pose)->

    this.addChild(pose)
    pose.addedToAvatarStage(this)

    this

  # ----------------------------------------------------------------------------------------------------------------
  removePose: (pose)->

    this.removeChild(pose)

    pose.removedFromAvatarStage()

    this

  # ----------------------------------------------------------------------------------------------------------------
  getAvatarSpecs: ()-> @avatarSpecs

  # ----------------------------------------------------------------------------------------------------------------
  getAvatarSet: ()-> @avatarSet

  # ----------------------------------------------------------------------------------------------------------------
  findByProperty: (property, value)->

    _.detect(this.getAvatarSpecs(), (a)=>a[property] is value)

  # ----------------------------------------------------------------------------------------------------------------
  findByAvatar: (avatar)->
    this.findByProperty("avatar", avatar)

  # ----------------------------------------------------------------------------------------------------------------
  applyToAllAnimations: (fn)->
    _.select(AvatarAnimationSequence.findByAvatarStage(this), (a)=>a[fn]?())

  # ----------------------------------------------------------------------------------------------------------------
  applyToAnimationsByAvatar: (avatar, fn)->
    _.select(AvatarAnimationSequence.findByAvatar(avatar), (a)=>a[fn]?())

  # ----------------------------------------------------------------------------------------------------------------
  # Maps a high-level animation request (such as "created") into a mid-level sequence. A sequence might be used by
  # multiple high-level requests.
  #
  getAnimationSequenceKind: (avatarSpec, animation, options)->

    sequence = null

    switch animation

      when "created", "reactivated"
        if not this.isVisibleByAvatar(avatarSpec.avatar)
          sequence = AvatarAnimationSequenceWaitNervously

      when "answered" 
        sequence = AvatarAnimationSequenceAnswered

      when "showCorrectness" 
        sequence = AvatarAnimationSequenceShowCorrectness

      when "showScore"
        sequence = AvatarAnimationSequenceShowScore

      when "deactivated", "destroyed"
        if this.isVisibleByAvatar(avatarSpec.avatar)
          sequence = AvatarAnimationSequenceHide

      else
        Hy.Trace.debug "AvatarStage::animateAvatar (ERROR UNKNOWN ANIMATION #{animation})"
        sequence = AvatarAnimationSequenceDefault

    sequence

  # ----------------------------------------------------------------------------------------------------------------
  computeStagePosition: (avatarSpec, options, currentStagePosition, animation)->

    info = ""

    fnSlotTaken = (a)=>_.detect(this.getAvatarSpecs(), (s)=>s._stagePosition is a)

    # start with requested _stageOrder options "asProvided" and "perAvatar"
    options._stagePosition = switch options._stageOrder
      when "asProvided"
        currentStagePosition
      when "perAvatar"
        avatarSpec._stagePosition # Might be null
      else
        null
 
    # Is the requested slot already in use by some other avatar?
    if options._stagePosition? and (as = fnSlotTaken(options._stagePosition))? and (as isnt avatarSpec)
      options._stagePosition = null

    # Implement "fill" and edge cases
    if not options._stagePosition?

      # First, does it already happen to have a place of its own?
      if avatarSpec._stagePosition? and (as = fnSlotTaken(avatarSpec._stagePosition))? and (as is avatarSpec)
        options._stagePosition = avatarSpec._stagePosition
        info += " Re-using own slot"
      else
        # find a nice empty spot
        for i in [0..this.getMaxNumAvatars() - 1]
          if not fnSlotTaken(i)?
            options._stagePosition = i
            info += " Found empty slot"
            break

    # screw'd case
    if not options._stagePosition?
      options._stagePosition = 0
      info += " COULD NOT PLACE"
      Hy.Trace.debug "AvatarStage::computeStagePosition (COULD NOT PLACE AVATAR #{animation} #{avatarSpec.avatar.getDumpStr()})"

    # Remember where we put this sucker.
    avatarSpec._stagePosition = options._stagePosition

    Hy.Trace.debug "AvatarStage::computeStagePosition (\"#{animation}\" #{avatarSpec.avatar.getDumpStr()} at #{avatarSpec._stagePosition} #{info} #{this.getDumpStr()})"

    this
  # ----------------------------------------------------------------------------------------------------------------
  # 0-based indicator of stage position
  # We pass in options to allow more runtime control.
  #
  computeAvatarCoordinates: (avatar, options)->

    position = null

    # At the very least, should have been computed when the animation was created
    if not (stagePosition = options._stagePosition)?
      stagePosition = 0 # fallback

    a = true

    p = stagePosition*avatar.getPadding() + if this.getOrientation() is "horizontal"
      stagePosition*this.getAvatarDisplayWidth()
    else
      a = false
      stagePosition*this.getAvatarDisplayHeight()

    new Hy.UI.Position((if a then 0 else p), (if a then p else 0))

# ==================================================================================================================
class Score extends Hy.UI.LabelProxy

  kScoreHeight = 40
  kScoreWidth = 70

  # ----------------------------------------------------------------------------------------------------------------
  @getHeight: ()-> kScoreHeight

  # ----------------------------------------------------------------------------------------------------------------
  @getWidth: ()-> kScoreWidth

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (options, @scoreText)->

    defaultOptions = 
      top: 0
      height: Score.getHeight()
      width: Score.getWidth()
      color: Hy.UI.Colors.white
      font: Hy.UI.Fonts.specBigNormal
      textAlign: 'center'
      text: @scoreText

    super Hy.UI.ViewProxy.mergeOptions(defaultOptions, options)

    this

# ==================================================================================================================
class AvatarStageWithScores extends AvatarStage

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (options = {}, avatarSet=AvatarSet.getCurrent())->

    defaultOptions = {}

    if not options._scoreOrientation?
      defaultOptions._scoreOrientation = "horizontal"

    super Hy.UI.ViewProxy.mergeOptions(defaultOptions, options), avatarSet

    this

  # ----------------------------------------------------------------------------------------------------------------
  getScoreOrientation: ()->
    this.getUIProperty("_scoreOrientation")

  # ----------------------------------------------------------------------------------------------------------------
  getAvatarDisplayHeight: ()->

    height = this.getAvatarSet().getHeight()
    if this.getScoreOrientation() is "vertical"
      height += Score.getHeight()

    height

  # ----------------------------------------------------------------------------------------------------------------
  getAvatarDisplayWidth: ()->

    width = this.getAvatarSet().getWidth()
    if this.getScoreOrientation() is "horizontal"
      width += Score.getWidth()

    width

  # ----------------------------------------------------------------------------------------------------------------
  # 0-based indicator of stage position
  computeAvatarCoordinates: (avatar, options)->

    if (position = super)?
      top = position.getTop()
      left = position.getLeft()

      switch this.getScoreOrientation()
        when "horizontal"
          null

        when "vertical"
          top += Score.getHeight()

      position = new Hy.UI.Position(top, left)

    position


# ==================================================================================================================
# Associates individual poses with views, so we can reuse the views.
# Instances therefore stick around, and are managed by Avatars (which also stick around)
#
class Pose extends Hy.UI.ViewProxy

  gInstances = []
  kZIndex = 100

  # ----------------------------------------------------------------------------------------------------------------
  @findByAvatarAndName: (avatar, name)->

    _.find(gInstances, (p)=>p.avatar is avatar and p.name is name)

  # ----------------------------------------------------------------------------------------------------------------
  @findAllByAvatar: (avatar)->

    _.select(gInstances, (p)=>p.avatar is avatar)

  # ----------------------------------------------------------------------------------------------------------------
  @applyByAvatar: (avatar, fn)->

    for pose in Pose.findAllByAvatar(avatar)
       fn(pose)

    this

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (@avatar, @name)->

    gInstances.push this

    super {}

    this.addChild(@avatarImageView = this.createAvatarImageView())

    @auxViewSpecs = []

    @position = null

    @backlight = null
    @playerNameLabel = null

    this

  # ----------------------------------------------------------------------------------------------------------------
  viewOptions: ()->
    height: this.getAvatar().getHeight() + PlayerNameLabel.getHeight()
    width: this.getAvatar().getWidth()
    left:0
    top:0
    zIndex: kZIndex

  # ----------------------------------------------------------------------------------------------------------------
  getName: ()-> @name

  # ----------------------------------------------------------------------------------------------------------------
  getAvatar: ()-> @avatar

  # ----------------------------------------------------------------------------------------------------------------
  setPosition: (position)->  
    this.setUIProperty("left", position.getLeft())
    this.setUIProperty("top", position.getTop())
    @position = position

  # ----------------------------------------------------------------------------------------------------------------
  createAvatarImageView: ()->
    options = this.avatarImageViewOptions()
    options.image = "#{this.getAvatar().getDirectory()}/#{this.getAvatar().getFilename(this.getName())}"

    new Hy.UI.ImageViewProxy(options)

  # ----------------------------------------------------------------------------------------------------------------
  avatarImageViewOptions: ()->

    height: this.getAvatar().getHeight()
    width: this.getAvatar().getWidth()
    left:0
    top:0
    zIndex: kZIndex

  # ----------------------------------------------------------------------------------------------------------------
  avatarBacklightOptions: ()->

    image: "assets/avatars/gameshow/headglow.png"
    height: this.getAvatar().getHeight()
    width: this.getAvatar().getWidth()
    left: 0
    top: 0
    zIndex: kZIndex - 2

  # ----------------------------------------------------------------------------------------------------------------
  updatePlayerNameLabel: ()->

    @playerNameLabel?.update()

  # ----------------------------------------------------------------------------------------------------------------
  addedToAvatarStage: (avatarStage)-> 

#    Hy.Trace.debug("Pose::addedToAvatarStage (avatar=#{@avatar.getDumpStr()} pose=#{@name} backlighting=#{avatarStage.requiresAvatarBacklighting()})")

    this.setUIProperty("height", avatarStage.getAvatarDisplayHeight() + PlayerNameLabel.getHeight())
    this.setUIProperty("width", avatarStage.getAvatarDisplayWidth())
    this.getView().show()

    if avatarStage.requiresAvatarBacklighting()
      if not @backlight?
        @backlight = new Hy.UI.ImageViewProxy(this.avatarBacklightOptions())

#      this.addAuxView(@backlight, true) # Bug found by Mike Swanson for 2.3
      this.addAuxView(@backlight, false) 

    if not @playerNameLabel?
      @playerNameLabel = new PlayerNameLabel(@avatar, {zIndex: kZIndex + 1})

    this.addAuxView(@playerNameLabel, true)

    this

  # ----------------------------------------------------------------------------------------------------------------
  removedFromAvatarStage: ()->

#    Hy.Trace.debug("Pose::removedFromAvatarStage (avatar=#{@avatar.getDumpStr()} pose=#{@name} backlighting=#{avatarStage.requiresAvatarBacklighting()} aux views=#{_.size(@auxViewSpecs)})")

    this.clearAuxViews(false, true)

    null

  # ----------------------------------------------------------------------------------------------------------------
  addAuxView: (auxView, isPermanent, attachOptions = null, fnDone = null)->

#    Hy.Trace.debug("Pose::addAuxView (avatar=#{@avatar.getDumpStr()} pose=#{@name})")

    if not _.any(@auxViewSpecs, (as)=>as.auxView is auxView)
      @auxViewSpecs.push {auxView:auxView, isPermanent: isPermanent, fnDone:fnDone}
      this.addChild(auxView)
      if attachOptions?
        auxView.attachToView(@avatarImageView, attachOptions)
      auxView.show()

    this

  # ----------------------------------------------------------------------------------------------------------------
  clearAuxViews: (permanent, temporary)->

    for as in @auxViewSpecs.slice() # we make a copy since array may be modified while looping
      if (as.isPermanent and permanent) or ((not as.isPermanent) and temporary)
        this.clearAuxViewBySpec(as)

    this

  # ----------------------------------------------------------------------------------------------------------------
  clearAuxViewBySpec: (as)->

    this.removeChild(as.auxView)
    as.fnDone?(as.auxView)

    @auxViewSpecs = _.without(@auxViewSpecs, as)

    this

  # ----------------------------------------------------------------------------------------------------------------
  clearAuxView: (auxView)->

    if (as = _.find(@auxViewSpecs, (as)=>as.auxView is auxView))?
      this.clearAuxViewBySpec(as)

    this
    
# ==================================================================================================================
# Represents a set of views that form the basis of an animation sequence
# Designed to be subclassed. Consumed/used by AvatarAnimationSequence.
# Are created and disposed as needed.
#
class AvatarAnimationSequencePoseSet

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (@animationSequence)->

    this

  # ----------------------------------------------------------------------------------------------------------------
  initialize: ()->

    this

  # ---------------------------------------------------------------------------------------------------------------- 
  hasAnotherPose: ()->

    false

  # ----------------------------------------------------------------------------------------------------------------
  # Should always return a pose, wrapping if necessary, etc
  #
  getNextPose: ()->

    null

# ==================================================================================================================
# For use by animation sequences based on a static set of poses (views)
#
class AvatarAnimationSequenceStaticPoseSet extends AvatarAnimationSequencePoseSet

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (animationSequence, @poses)->

    super animationSequence

    this

  # ----------------------------------------------------------------------------------------------------------------
  initialize: ()->

    super

    @poseIndex = -1  

  # ----------------------------------------------------------------------------------------------------------------
  hasAnotherPose: ()->
    @poseIndex < (_.size(@poses)-1)

  # ----------------------------------------------------------------------------------------------------------------
  getNextPose: ()->
    pose = null

    if not this.hasAnotherPose()
      this.initialize()

    @poseIndex++
    pose = @poses[@poseIndex]

    pose

# ==================================================================================================================
# Orchestrates poses, organized as PoseSet instances, to render animation. Created/disposed as needed by AvatarStage
#
class AvatarAnimationSequence

  gInstances = []
  gInstanceCount = 0

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (@avatarStage, @avatar, @options, @poseSet)->

    @counter = ++gInstanceCount

    gInstances.push this

    @deferral = null

    @kind = this.constructor.name

    @startPosition = null
    @currentPose = null
    @currentPosition = null

    @startDelay = null
    this.setDefaultDuration(this.getAvatar().getWalkDuration())
    @fnRepeatWhile = null
    @fnCompleted = null
    @hideWhenCompleted = false
    @chainedInstance = null

    @animating = false

    @destroyed = false

    this

  # ----------------------------------------------------------------------------------------------------------------
  getDumpStr: ()->

    "kind=#{this.constructor.name} avatar=#{@avatar.getDumpStr()} isDestroyed=#{this.isDestroyed()} isAnimating=#{this.isAnimating()} ##{@counter} frame=#{@frameCount} deferral=#{@deferral} on stage=#{this.getAvatarStage().isSequenceOnStage(this)}"

  # ----------------------------------------------------------------------------------------------------------------
  initialize: ()->

    @frameCount = -1

    this

  # ----------------------------------------------------------------------------------------------------------------
  getAvatar: ()-> @avatar

  # ----------------------------------------------------------------------------------------------------------------
  getAvatarStage: ()-> @avatarStage

  # ----------------------------------------------------------------------------------------------------------------
  setStartDelay: (startDelay)->
    @startDelay = startDelay

  # ----------------------------------------------------------------------------------------------------------------
  setFnRepeatWhile: (fnRepeatWhile)->
    @fnRepeatWhile = fnRepeatWhile

  # ----------------------------------------------------------------------------------------------------------------
  setFnCompleted: (fnCompleted)->
    @fnCompleted = fnCompleted

  # ----------------------------------------------------------------------------------------------------------------
  setHideWhenCompleted: (flag)->
    @hideWhenCompleted = flag

  # ----------------------------------------------------------------------------------------------------------------
  chainAnimation: (chainedInstance)->
    @chainedInstance = chainedInstance

  # ----------------------------------------------------------------------------------------------------------------
  setDefaultDuration: (defaultDuration)->
    @defaultDuration = defaultDuration

  # ----------------------------------------------------------------------------------------------------------------
  getDefaultDuration: ()-> @defaultDuration

  # ----------------------------------------------------------------------------------------------------------------
  getDynamicDuration: ()-> null

  # ----------------------------------------------------------------------------------------------------------------
  getCurrentPosition: ()-> @currentPosition

  # ----------------------------------------------------------------------------------------------------------------
  setCurrentPosition: (p)->

    @currentPosition = p
    this.getCurrentPose()?.setPosition(p)

    p
  
  # ----------------------------------------------------------------------------------------------------------------
  getCurrentPose: ()-> @currentPose

  # ----------------------------------------------------------------------------------------------------------------
  setCurrentPose: (pose)->

    @currentPose = pose

  # ----------------------------------------------------------------------------------------------------------------
  showPose: (pose = this.getCurrentPose())->

    if pose?
      this.getAvatarStage().addPose(pose)

    this

  # ----------------------------------------------------------------------------------------------------------------
  removePose: (pose = this.getCurrentPose())->

    if pose?
      if pose is this.getCurrentPose()
        this.setCurrentPose(null)

      this.getAvatarStage().removePose(pose)

    this

  # ----------------------------------------------------------------------------------------------------------------
  getOptions: ()-> @options

  # ----------------------------------------------------------------------------------------------------------------
  getOption: (property)->

    @options[property]

  # ----------------------------------------------------------------------------------------------------------------
  getFrameCount: ()->
    
    @frameCount

  # ----------------------------------------------------------------------------------------------------------------
  getStartPosition: ()-> @startPosition

  # ----------------------------------------------------------------------------------------------------------------
  computeStartPosition: ()->

    position = @startPosition

    if not position?
      position = this.getCurrentPosition()

    if not position?
      position = this.getAvatarStage().computeAvatarCoordinates(this.getAvatar(), this.getOptions())

    if not position?
      new Hy.UI.Position(0, 0)

    position

  # ----------------------------------------------------------------------------------------------------------------
  animateStart: (startPosition = this.computeStartPosition())->

    this.getAvatarStage().addSequenceToStage(this)

    this.animate(startPosition)

    this

  # ----------------------------------------------------------------------------------------------------------------
  animate: (startPosition = this.computeStartPosition())->

    if this.isDestroyed()
      Hy.Trace.debug("AvatarAnimationSequence::animate (DESTROYED #{this.getDumpStr()})")
      return this

    this.initialize()

    this.setCurrentPosition(@startPosition = startPosition)

    @poseSet.initialize()

    this.setIsAnimating()

    if @startDelay? and @startDelay > 0
      @deferral = Hy.Utils.Deferral.create(@startDelay, ()=>this.animate_())
    else
      this.animate_()

    this

  # ----------------------------------------------------------------------------------------------------------------
  setIsDestroyed: (destroyed)->

    @destroyed = destroyed

  # ----------------------------------------------------------------------------------------------------------------
  isDestroyed: ()-> @destroyed

  # ----------------------------------------------------------------------------------------------------------------
  setIsAnimating: ()->
    @animating = true

  # ----------------------------------------------------------------------------------------------------------------
  clearIsAnimating: ()->
    @animating = false

  # ----------------------------------------------------------------------------------------------------------------
  isAnimating: ()-> @animating

  # ----------------------------------------------------------------------------------------------------------------
  pauseAnimation: ()->

    @deferral?.clear()
    @deferral = null

    this

  # ----------------------------------------------------------------------------------------------------------------
  resumeAnimation: ()->

    if this.isAnimating()  
      this.animate_()

    this

  # ----------------------------------------------------------------------------------------------------------------
  stopAnimation: ()->

    this.pauseAnimation()
    this.clearIsAnimating()

    this

  # ----------------------------------------------------------------------------------------------------------------
  destroyAnimation: ()->

    Hy.Trace.debug "AvatarAnimationSequence::destroyAnimation (#{this.getDumpStr()} # sequences=#{_.size(gInstances)})"

    if not this.isDestroyed()

      this.stopAnimation()
      this.setIsDestroyed(true)
      this.removePose()

      this.getAvatarStage().setVisibleByAvatar(this.getAvatar(), false)

      this.getAvatarStage().removeSequenceFromStage(this)
    
      gInstances = _.without(gInstances, this)

    this

  # ----------------------------------------------------------------------------------------------------------------
  @findByKind: (kind)->

    AvatarAnimationSequence.findByProperty("kind", kind)

  # ----------------------------------------------------------------------------------------------------------------
  @findByAvatar: (avatar)->

    AvatarAnimationSequence.findByProperty("avatar", avatar)

  # ----------------------------------------------------------------------------------------------------------------
  @findByAvatarStage: (avatarStage)->

    AvatarAnimationSequence.findByProperty("avatarStage", avatarStage)

  # ----------------------------------------------------------------------------------------------------------------
  # "Private" methods
  # ----------------------------------------------------------------------------------------------------------------

  # ----------------------------------------------------------------------------------------------------------------
  @findByProperty: (property, value)->
    _.select(gInstances, (i)=>i[property] is value)

  # ----------------------------------------------------------------------------------------------------------------
  isCompleted: ()->

    not @poseSet.hasAnotherPose()   
    
  # ----------------------------------------------------------------------------------------------------------------
  animate_: ()->

    if this.isDestroyed()
#      Hy.Trace.debug("AvatarAnimationSequence::animate_ (DESTROYED #{this.getDumpStr()})")
      return this

    @deferral = null

    this.getAvatarStage().setVisibleByAvatar(this.getAvatar(), true)

    if this.isCompleted()

      this.stopAnimation()

      if @hideWhenCompleted
        this.removePose()

      fnCompleted = @fnCompleted # we make a copy in case this instance is destroyed
      repeat = if @fnRepeatWhile? then @fnRepeatWhile() else false
      chainedInstance = @chainedInstance

#      Hy.Trace.debug "AvatarAnimationSequence::animate_ (#{if fnCompleted? then "COMPLETED FUNCTION" else ""} #{if repeat then "REPEAT" else ""} #{if chainedInstance? then "CHAINED" else ""} #{this.getDumpStr()})"
    
      if fnCompleted?
        Hy.Utils.Deferral.create(0, ()=>fnCompleted(this))

      # repeat takes precedence over chainedInstance
      if repeat
        @deferral = Hy.Utils.Deferral.create(0, ()=>this.animate())
      else if chainedInstance?
        @deferral = Hy.Utils.Deferral.create(0, ()=>chainedInstance.animate(this.getCurrentPosition()))

      this.getAvatarStage().setVisibleByAvatar(this.getAvatar(), not @hideWhenCompleted)

      if @hideWhenCompleted and not repeat
        this.destroyAnimation()

    else

      @frameCount++

#      Hy.Trace.debug "AvatarAnimationSequence::animate (Animating #{this.getDumpStr()})"

      this.transitionPose()
    
      @deferral = Hy.Utils.Deferral.create(this.computeDuration(), ()=>this.animate_())

    this

  # ----------------------------------------------------------------------------------------------------------------
  computeDuration: ()->

    duration = this.getDynamicDuration()

    if not duration?
      duration = this.getDefaultDuration()

      if not duration?
        duration = 0

    duration

  # ----------------------------------------------------------------------------------------------------------------  
  transitionPose: (position=null)->

    currentPose = this.getCurrentPose()
    nextPose = @poseSet.getNextPose()

    this.setCurrentPose(nextPose)

    this.setCurrentPosition(if position? then position else this.getCurrentPosition())

    this.showPose(nextPose)

    nextPose.setUIProperty("zIndex", 200)

    if currentPose?
      this.removePose(currentPose)

    nextPose.setUIProperty("zIndex", 150)

    this
    
# Animations in which the avatar doesn't change its position
# ==================================================================================================================
class AvatarAnimationSequenceInPlace extends AvatarAnimationSequence

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (avatarStage, avatar, options, poseSet)->

    super avatarStage, avatar, options, poseSet

    this

# ==================================================================================================================
# Safe for animated and non-animated avatars alike
#
class AvatarAnimationSequenceDefault extends AvatarAnimationSequenceInPlace

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (avatarStage, avatar, options)->

    poses = []

    poses.push avatar.getDefaultPose()

    super avatarStage, avatar, options, new AvatarAnimationSequenceStaticPoseSet(this, poses)

    this

# ==================================================================================================================
class AvatarAnimationSequenceWaitNervously extends AvatarAnimationSequenceInPlace

  kMinInitialDuration =  1 * 4000
  kRandomDurationSeed = 20 * 1000
  kMinDuration        =  3 * 1000

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (avatarStage, avatar, options)->

    poseNames = ["twitch"]

    poses = []

    poses.push avatar.getDefaultPose()

    for poseName in poseNames
      for pose in avatar.getSequencePoses(poseName)
        poses.push pose

    super avatarStage, avatar, options, new AvatarAnimationSequenceStaticPoseSet(this, poses)

    this.setFnRepeatWhile(()=>true)

    @didMinWait = false
 
    this

  # ----------------------------------------------------------------------------------------------------------------
  getDynamicDuration: ()->

    maxSpin = 10
    spinCount = 0

    if @didMinWait
      duration = 0
      while duration < kMinDuration
        if ++spinCount is maxSpin
          duration = kMinDuration
        else
          duration = Hy.Utils.Math.random(kRandomDurationSeed)
        null
    else
      duration = kMinInitialDuration
      @didMinWait = true   

    duration

# ==================================================================================================================
class AvatarAnimationSequenceHide extends AvatarAnimationSequenceInPlace

  kDuration = 500

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (avatarStage, avatar, options)->
    
    super avatarStage, avatar, options, new AvatarAnimationSequenceStaticPoseSet(this, avatar.getSequencePoses("twitch"))

    this.setDefaultDuration(kDuration)
    this.setHideWhenCompleted(true)

    this

# ==================================================================================================================
class AvatarAnimationSequenceAnswered extends AvatarAnimationSequenceInPlace

  kDuration = 300

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (avatarStage, avatar, options)->

    poses = []

#    for p in avatar.getSequencePoses("turn")
#      poses.push p

    poses.push avatar.getDefaultPose()

    super avatarStage, avatar, options, new AvatarAnimationSequenceStaticPoseSet(this, poses)

    this.setDefaultDuration(kDuration)

    this

# ==================================================================================================================
class ViewCache

  gViewSpecs = []

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (@viewCreateFn = null)->

    this

  # ----------------------------------------------------------------------------------------------------------------
  # "public" functions
  # ----------------------------------------------------------------------------------------------------------------

  # ----------------------------------------------------------------------------------------------------------------
  getView: (options = null)->

    if not (viewSpec = this.findUnusedView())?
      viewSpec = this.createViewSpec(options)

    this.setInUse(viewSpec)

    viewSpec.view

  # ----------------------------------------------------------------------------------------------------------------
  doneWithView: (view)->

    if (vs = this.findViewSpecByView(view))?
      this.setInUse(vs, false)

    this

  # ----------------------------------------------------------------------------------------------------------------
  # "private" functions
  # ----------------------------------------------------------------------------------------------------------------

  # ----------------------------------------------------------------------------------------------------------------
  createViewSpec: (options = null)->

    if (view = @viewCreateFn?(options))?
      view.hide()

    gViewSpecs.push (viewSpec = {view: view, inUse: false})

    viewSpec

  # ----------------------------------------------------------------------------------------------------------------
  setInUse: (viewSpec, flag = true)->

    viewSpec.inUse = flag

    viewSpec

  # ----------------------------------------------------------------------------------------------------------------
  findUnusedView: ()->
    _.find(gViewSpecs, (vs)=>not vs.inUse)

  # ----------------------------------------------------------------------------------------------------------------
  findViewSpecByView: (view)->
    _.find(gViewSpecs, (vs)=>vs.view is view)


# ==================================================================================================================
class AvatarAnimationSequenceShowCorrectness extends AvatarAnimationSequenceInPlace

  gScoreLabelCache = null

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (avatarStage, avatar, options)->

#    poseNames = if options._showCorrectness then ["twitch", "correct"] else ["incorrect"]
    poseNames = if options._showCorrectness then ["twitch", "blank"] else ["incorrect"]


    poses = []

    for poseName in poseNames
      for pose in avatar.getSequencePoses(poseName)
        poses.push pose

    super avatarStage, avatar, options, new AvatarAnimationSequenceStaticPoseSet(this, poses)

    if options._showCorrectness
      this.setFnCompleted((sequence)=>sequence.showCorrectness()) 

    this

  # ----------------------------------------------------------------------------------------------------------------
  initialize: ()->

    super

    this.initializeScoreLabelCache()

    this

  # ----------------------------------------------------------------------------------------------------------------
  initializeScoreLabelCache: ()->

    if not gScoreLabelCache?
      gScoreLabelCache = new ViewCache((options)=>this.createScoreLabel())

    this

  # ----------------------------------------------------------------------------------------------------------------

  createScoreLabel: ()->

    options = 
      height: 30
      width: 40
      top: 20
      font: Hy.UI.Fonts.mergeFonts(Hy.UI.Fonts.specMinisculeNormal, {fontSize:40})
      textAlign: "center"
      color: Hy.UI.Colors.black
      backgroundColor: Hy.UI.Colors.white
#      borderColor: Hy.UI.Colors.green
#      borderWidth: 1
      zIndex: 1000
      text: ""

    scoreLabel = new Hy.UI.LabelProxy(options)

    scoreLabel

  # ----------------------------------------------------------------------------------------------------------------
  showCorrectness: ()->

    scoreLabel = gScoreLabelCache.getView()

    # Set score, and if our player was the top scorer, set color to something noticable
    scoreLabel.setUIProperty("text", if this.getOption("_showCorrectness") then this.getOption("_score") else "?")
    scoreLabel.setUIProperty("color", if this.getOption("_topScorer") then Hy.UI.Colors.red else Hy.UI.Colors.black)

    this.getCurrentPose().addAuxView(scoreLabel, false, null, (v)=>gScoreLabelCache.doneWithView(v))

    this

# ==================================================================================================================
class AvatarAnimationSequenceShowCorrectness2 extends AvatarAnimationSequenceInPlace

  gCorrectnessViews = null

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (avatarStage, avatar, options)->

#    poseNames = if options._showCorrectness then ["happy", "correct"] else ["sad", "incorrect"]
    poseNames = if options._showCorrectness then ["twitch", "correct"] else ["incorrect"]

    poses = []

    for poseName in poseNames
      for pose in avatar.getSequencePoses(poseName)
        poses.push pose

    super avatarStage, avatar, options, new AvatarAnimationSequenceStaticPoseSet(this, poses)

    this.setFnCompleted((sequence)=>sequence.showCorrectness()) # Not used currently

    this

  # ----------------------------------------------------------------------------------------------------------------
  initialize: ()->

    super

    this.initializeCorrectnessView()

    this

  # ----------------------------------------------------------------------------------------------------------------
  initializeCorrectnessView: ()->

    if not gCorrectnessViews?
      gCorrectnessViews = new CorrectnessViews()

    this

  # ----------------------------------------------------------------------------------------------------------------
  showCorrectness: ()->

    if not @correctnessView?
      @correctnessView = gCorrectnessViews.assignAvailableView(this.getOption("_showCorrectness"))
      this.getCurrentPose().addAuxView(@correctnessView, false, null, (v)=>gCorrectnessViews.doneWithView(v))

    @correctnessView.show()

    this



# ==================================================================================================================
# Reverting this due to wierness on the Scoreboard Panel
class AvatarAnimationSequenceShowScore extends AvatarAnimationSequenceWaitNervously #AvatarAnimationSequenceDefault

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (avatarStage, avatar, options)->

    super avatarStage, avatar, options

    this

  # ----------------------------------------------------------------------------------------------------------------
  transitionPose: ()->
    super

    this.addScore()

    this

  # ----------------------------------------------------------------------------------------------------------------
  destroyAnimation: ()->

    if @scoreView?
      this.getAvatarStage().removeChild(@scoreView)

    super

    this
    
  # ----------------------------------------------------------------------------------------------------------------
  addScore: ()->

    if not @scoreView?

      avatarHeight = @avatarStage.getAvatarSet().getHeight()
      avatarWidth = @avatarStage.getAvatarSet().getWidth()
      top = this.getCurrentPosition().getTop()
      left = this.getCurrentPosition().getLeft()

      options = {}

      switch @avatarStage.getScoreOrientation()
        when "vertical"
          options.width = avatarWidth
          options.top = 0
          options.left = left
        when "horizontal"
          options.height = avatarHeight
          options.left = left + avatarWidth
          options.top = top

#      options.borderWidth = 1
#      options.borderColor = Hy.UI.Colors.white

      @scoreView = new Score(options, this.getOption("_score"))
      
      this.getAvatarStage().addChild(@scoreView)

    this


# ==================================================================================================================
Hyperbotic.Avatars = 
  AvatarSet: AvatarSet
  AvatarStage: AvatarStage
  AvatarStageWithScores : AvatarStageWithScores


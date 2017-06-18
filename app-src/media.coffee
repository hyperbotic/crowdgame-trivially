# ==================================================================================================================
class VideoPlayerProxy extends Hy.UI.ViewProxy

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (options)->

    super options

    @completed = false

    this.setup()

    this

  # ----------------------------------------------------------------------------------------------------------------
  viewOptions: ()->

    defaultOptions = 
      backgroundColor: Hy.UI.Colors.black
      scalingMode: Titanium.Media.VIDEO_SCALING_MODE_FILL
#      sourceType: Titanium.Media.VIDEO_SOURCE_TYPE_FILE
      top: 0
      left: 0
      bottom: 0
      right: 0
      zIndex: 201

    defaultOptions

  # ----------------------------------------------------------------------------------------------------------------
  createView: (options)->

    Ti.Media.createVideoPlayer(options)

  # ----------------------------------------------------------------------------------------------------------------
  setPlayOptions: ()->
#      if Hy.Config.platformAndroid
#        defaultOptions.mediaControlStyle = Titanium.Media.VIDEO_CONTROL_DEFAULT
#      else
#        if parseFloat(Titanium.Platform.version) >= 3.2
#          defaultOptions.mediaControlStyle = Titanium.Media.VIDEO_CONTROL_NONE
#        else
#          defaultOptions.movieControlMode = Titanium.Media.VIDEO_CONTROL_NONE

#      defaultOptions.mediaControlStyle = Titanium.Media.VIDEO_CONTROL_NONE
#      defaultOptions.initialPlaybackTime = Number(0.9)

    this.getView().movieControlMode = Titanium.Media.VIDEO_CONTROL_NONE 
    this.getView().autoplay = false
    this.getView().touchEnabled = false

    this


  # ----------------------------------------------------------------------------------------------------------------
  setup: ()->

    # I don't expect any of these to work, or at least not reliably
    this.getView().addEventListener("load", (e)=>this.movieEventHandler(e))
    this.getView().addEventListener("preload", (e)=>this.movieEventHandler(e))
    this.getView().addEventListener("complete", (e)=>this.movieEventHandler(e))
    this.getView().addEventListener("playbackState", (e)=>this.movieEventHandler(e))

#    this.getView().mediaControlStyle = Titanium.Media.VIDEO_CONTROL_NONE
#    this.getView().mediaControlMode = Titanium.Media.VIDEO_CONTROL_NONE

#    if parseFloat(Titanium.Platform.version) >= 3.2
#      this.getView().mediaControlStyle = Titanium.Media.VIDEO_CONTROL_NONE

#    if Ti.Platform.osname is "ipad"
#      this.getView().width = 400
#      this.getView().height = 300

    this

  # ----------------------------------------------------------------------------------------------------------------
  movieEventHandler: (evt)->

    Hy.Trace.debug("MovieViewProxy::eventHandler (event=#{evt.type})")

    switch evt.type
      when "completed"
        @completed = true
        reason = switch evt.reason
          when Titanium.Media.VIDEO_FINISH_REASON_PLAYBACK_ENDED
            "Playback Ended"
          when Titanium.Media.VIDEO_FINISH_REASON_PLAYBACK_ERROR
            "Playback Ended"
          when Titanium.Media.VIDEO_FINISH_REASON_USER_EXITED
            "Playback Ended"
          else
            "??"
        Hy.Trace.debug("MovieViewProxy::eventHandler (Playback completed: #{reason})")

      when "playbackState"
        state = switch evt.playbackState
          when Titanium.Media.VIDEO_PLAYBACK_STATE_INTERRUPTED
            "VIDEO_PLAYBACK_STATE_INTERRUPTED"
          when Titanium.Media.VIDEO_PLAYBACK_STATE_PAUSED
            "VIDEO_PLAYBACK_STATE_PAUSED"
          when Titanium.Media.VIDEO_PLAYBACK_STATE_PLAYING
            "VIDEO_PLAYBACK_STATE_PLAYING"
          when Titanium.Media.VIDEO_PLAYBACK_STATE_SEEKING_BACKWARD
            "VIDEO_PLAYBACK_STATE_SEEKING_BACKWARD"
          when Titanium.Media.VIDEO_PLAYBACK_STATE_SEEKING_FORWARD
            "VIDEO_PLAYBACK_STATE_SEEKING_FORWARD"
          when Titanium.Media.VIDEO_PLAYBACK_STATE_STOPPED
            "VIDEO_PLAYBACK_STATE_STOPPED"
        Hy.Trace.debug("MovieViewProxy::eventHandler (Playback State: #{state})")

    this

  # ----------------------------------------------------------------------------------------------------------------
  setURL: (url)->
    this.getView().setUrl(@url = url)
    this

  # ----------------------------------------------------------------------------------------------------------------
  setDuration: (duration)->
    @duration = duration

  # ----------------------------------------------------------------------------------------------------------------
  setFnCompleted: (fnCompleted)->
   @fnCompleted = fnCompleted

  # ----------------------------------------------------------------------------------------------------------------
  play: ()->

    this.setPlayOptions()

    duration = this.getView().duration
    initialPlaybackTime = this.getView().initialPlaybackTime
    endPlaybackTime = this.getView().endPlaybackTime

    # "Setting this property to true before the movie player's view is visible will have no effect."
    this.show()
    this.getView().fullscreen = true

    # Because we don't seem to be receiving any completed events
    if @duration?
      Hy.Utils.Deferral.create(@duration, ()=>this.movieCompleted())

    this.getView().play()
    
    this

  # ----------------------------------------------------------------------------------------------------------------
  stop: ()->
    this.getView().stop()

    this

  # ----------------------------------------------------------------------------------------------------------------
  release: ()->
    this.getView().release()

    this
  # ----------------------------------------------------------------------------------------------------------------
  movieCompleted: ()->

   # this.stop() #HACK

    @fnCompleted?()

    this

# ==================================================================================================================
class VideoPlayer extends Hy.UI.ViewProxy

  gInstances = []
  gVideoPlayer = null

  # ----------------------------------------------------------------------------------------------------------------
  @findByURL: (url)->
     _.detect(gInstances, (v)=>v.videoOptions._url is url)

  # ----------------------------------------------------------------------------------------------------------------
  @create: (videoOptions, fnCompleted = null)->

    videoOptions._url = "assets/video/#{videoOptions._url}"

    if not (video = VideoPlayer.findByURL(videoOptions._url))?
      video = new VideoPlayer(videoOptions, fnCompleted)

    video

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (@videoOptions, @fnCompleted = null)->

    gInstances.push this

    defaultContainerOptions =
      top: 0
      left: 0
      bottom: 0
      right: 0
      zIndex: 200
      backgroundColor: Hy.UI.Colors.black
  #    backgroundImage: Hy.UI.Backgrounds.stageNoCurtain
   
    super defaultContainerOptions

    @readyToPlay = false

    this

  # ----------------------------------------------------------------------------------------------------------------
  getVideoPlayer: ()->

    defaultVideoPlayerOptions = {}

    if not gVideoPlayer?
      gVideoPlayer = new VideoPlayerProxy(defaultVideoPlayerOptions)

    gVideoPlayer

  # ----------------------------------------------------------------------------------------------------------------
  prepareToPlay: (fnCompleted = @fnCompleted)->

    player = this.getVideoPlayer()

    if (parent = player.getParent())?
      parent.removeChild(player)

    player.setURL(@videoOptions._url)
    player.setDuration(@videoOptions._duration)

    f = ()=>
      this.stop()
      fnCompleted?()
      null

    player.setFnCompleted(f)

    this.addChild(player)

    @readyToPlay = true

    this

  # ----------------------------------------------------------------------------------------------------------------
  play: ()->

    if @readyToPlay         
      this.getVideoPlayer().play()

    this

  # ----------------------------------------------------------------------------------------------------------------
  stop: ()->

    player = this.getVideoPlayer()

#    this.removeChild(player) #HACK
  
    @readyToPlay = false

    this

  # ----------------------------------------------------------------------------------------------------------------
  release: ()->

    player = this.getVideoPlayer()

    player.stop()
    player.release()
    
    this

  # ----------------------------------------------------------------------------------------------------------------
  setVideoProperty: (name, value)->

    this.getVideoPlayer().setUIProperty(name, value)

    this

  # ----------------------------------------------------------------------------------------------------------------
  getVideoProperty: (name)->

    this.getVideoPlayer().getUIProperty(name)

# ==================================================================================================================
class SoundManager

  gInstance = null

  soundsInfo = [
    {key: 'silence',   url: 'silence.wav'}
    {key: 'clock01sA', url: 'clock1.wav'}
    {key: 'clock01sB', url: 'clock2.wav'}
    {key: 'clock01sC', url: 'clock3.wav'}
    {key: 'clock01sD', url: 'clock4.wav'}
    {key: 'clock01sE', url: 'clock5.wav'}
    {key: 'bell',      url: '000597941-Bell.wav'}
    {key: 'plop1',     url: '000617670-Plop1.wav'}
    {key: 'plop2',     url: '000949675-Plop2.wav'}
    {key: 'plop3',     url: '000949683-Plop3.wav'}
    {key: 'test',      url: '1000Hz-5sec.mp3'}
    {key: 'flitter',   url: 'flitter.wav'}
  ]

  eventMap = [
    {eventName: "gameStart",          soundName: "plop3"}
    {eventName: "challengeCompleted", soundName: "bell"}
    {eventName: "remotePlayerJoined", soundName: "flitter"}
    {eventName: "countDown_0",        soundName: "clock01sA"}
    {eventName: "countDown_1",        soundName: "clock01sB"}
    {eventName: "countDown_2",        soundName: "clock01sC"}
    {eventName: "countDown_3",        soundName: "clock01sD"}
    {eventName: "countDown_4",        soundName: "clock01sE"}
    {eventName: "hiddenChord",        soundName: "bell"}
    {eventName: "test",               soundName: "test"}
  ]

  # ----------------------------------------------------------------------------------------------------------------
  @init: ()->
    if not gInstance?
      gInstance = new SoundManager()

    gInstance

  # ----------------------------------------------------------------------------------------------------------------
  @get: ()-> gInstance

  # ----------------------------------------------------------------------------------------------------------------
  constructor: ()->

    # http://developer.appcelerator.com/question/157210/local-sound-files-not-playing-on-ios-7device-sdk-313-but-works-fine-in-simulator
    #
    # Should be "Ambient"
    # (Apple guidlines:
    #  https://developer.apple.com/library/ios/documentation/userexperience/conceptual/mobilehig/TechnologyUsage/TechnologyUsage.html#//apple_ref/doc/uid/TP40006556-CH18-SW3
    #
#    Ti.Media.setAudioSessionMode(Ti.Media.AUDIO_SESSION_MODE_PLAYBACK);
    Ti.Media.setAudioSessionMode(Ti.Media.AUDIO_SESSION_MODE_AMBIENT);

    this.initSounds()
  
    this
  # ----------------------------------------------------------------------------------------------------------------
  initSounds: ()->

    @sounds = {}
    for soundInfo in soundsInfo
      @sounds[soundInfo.key] = Ti.Media.createSound({url: "assets/sound/#{soundInfo.url}"})

    @soundOption = Hy.Options.sound

    # try to deal with sound system delay in playing first sound
    Hy.Trace.debug "ConsoleApp::initSound (Playing blank sound)"
    sound = this.getSound('silence', false)
    sound?.play()
    sound?.stop()
    Hy.Trace.debug "ConsoleApp::initSound (Ending blank sound)"

    this
  # ----------------------------------------------------------------------------------------------------------------
  soundsOn: ()->
    @soundOption.getValue() is "on"

  # ----------------------------------------------------------------------------------------------------------------
  getSound: (key, check=true)->
    sound = if not check || this.soundsOn() then @sounds[key] else null
    sound

  # ----------------------------------------------------------------------------------------------------------------
  findEvent: (eventName)->
    _.detect(eventMap, (m)=>m.eventName is eventName)

  # ----------------------------------------------------------------------------------------------------------------
  playEvent: (eventName, check = true)->
    if (event = this.findEvent(eventName))?
      if (sound = this.getSound(event.soundName, check))?
        sound.play()
    else
      Hy.Trace.debug("SoundManager::playEvent (COULD NOT FIND SOUND FOR REQUESTED EVENT #{eventName})")
    this

# ==================================================================================================================
Hyperbotic.Media =
  VideoPlayer: VideoPlayer
  SoundManager: SoundManager



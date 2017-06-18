# ==================================================================================================================
# Represents a download attempt
class DownloadEvent extends Hy.Network.HTTPEvent

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (@obj, @downloadStatus)->
    super

    this

  # ----------------------------------------------------------------------------------------------------------------
  dumpStr: ()->
    super + " display=#{@obj.display} status=#{@downloadStatus}"

# ==================================================================================================================
# Provides higher-level interface for downloading one or more files at a time

class DownloadManager

  kStatusOKSoFar = 1
  kStatusFailed  = 2
  kStatusSuccess = 3

  # ----------------------------------------------------------------------------------------------------------------
  constructor: (@reference, @fn_setup, @fn_done, @display)->

    @events = []
    this.startDownload()

    this

  # ----------------------------------------------------------------------------------------------------------------
  startDownload: ()->

    eventSpecs = this.invokeSetup()

    if eventSpecs?
      for spec in eventSpecs
        this.enqueueEvent spec

    if _.size(@events) is 0
      this.invokeDone()

    return null

  # ----------------------------------------------------------------------------------------------------------------
  invokeSetup: ()->

    eventSpecs = null

    if @fn_setup?
      Hy.Trace.debug "DownloadManager::invokeSetup (ENTER setup function #{@display})"
      eventSpecs = @fn_setup(@reference)
      Hy.Trace.debug "DownloadManager::invokeSetup (EXIT setup function #{@display} #eventSpecs=#{_.size(eventSpecs)})"

    return eventSpecs
    
  # ----------------------------------------------------------------------------------------------------------------
  enqueueEvent: (eventSpec)=>

    f = (event, status)=>this.invokeCallback(event, status)

    event = new DownloadEvent(eventSpec, kStatusOKSoFar)
    event.setFnPost(f)
    event.setURL(eventSpec.URL)

    @events.push event

    if not event.enqueue()
      event.downloadStatus = kStatusFailed
      Hy.Trace.debug "DownloadManager::enqueueEvent (ERROR could not enqueue event #{@display} #{e.obj.display})"

    null

  # ----------------------------------------------------------------------------------------------------------------
  areWeDoneYet: ()->

    done = false

    remaining = _.select(@events, (e)=>e.downloadStatus is kStatusOKSoFar)

    if _.size(remaining) is 0
      done = true

    Hy.Trace.debug "DownloadManager::areWeDoneYet (#events=#{_.size(@events)} Remaining=#{_.size(remaining)})"
  
    return done

  # ----------------------------------------------------------------------------------------------------------------
  dumpEvents: ()->
    for event in @events
      Hy.Trace.debug "DownloadManager.dumpEvents (#{event.dumpStr()})"

  # ----------------------------------------------------------------------------------------------------------------
  invokeCallback: (event, status)->

    Hy.Trace.debug "DownloadManager.invokeCallback (#{event.obj.display} #{if status then "SUCCESS" else "FAIL"})"

    f = (event)=>
#      Hy.Trace.debug "DownloadManager::invokeCallback (ENTER #{event.dumpStr()} callback=#{event.obj.callback?})"

      stat = true

      if event.obj.callback?
        stat = event.obj.callback(@reference, event, event.obj) # trying to hide class DownloadEvent

      event.downloadStatus = if stat then kStatusSuccess else kStatusFailed

      if this.areWeDoneYet()
        this.invokeDone()

      null

    if status
      Hy.Utils.PersistentDeferral.create 0, ()=>f(event)
    else
      event.downloadStatus = kStatusFailed
      if this.areWeDoneYet()
        this.invokeDone()

    null
    
  # ----------------------------------------------------------------------------------------------------------------
  invokeDone: ()->

    Hy.Trace.debug "DownloadManager::invokeDone"

    f = (status)=>
      Hy.Trace.debug "DownloadManager::invokeDone (ENTER #{@display})"
      if @fn_done?
        @fn_done(@reference, status)
      null

    status = []
    for e in @events
      status.push {object: e.obj, status: e.downloadStatus is kStatusSuccess}

    Hy.Utils.PersistentDeferral.create 0, ()=>f(status)

    null

# ==================================================================================================================
# assign to global namespace:

if not Hy.Network?
  Hy.Network = {}

Hy.Network.DownloadManager = DownloadManager

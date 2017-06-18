# ==================================================================================================================
Hy.Config =

  AppId: "??"

  platformAndroid: false

  Production: false

  kMaxRemotePlayers : 11

  Dynamics:
    panicAnswerTime: 3
    revealAnswerTime: 3
    maxNumQuestions: 50 # Max number of questions that can be played at a time

  Version:

    copyright: "??"
    Console:
      kConsoleMajorVersion : 2
      kConsoleMinorVersion : 6
      kConsoleMinor2Version : 5

    Remote:
      kMinRemoteMajorVersion    : 1
      kMinRemoteMinorVersion    : 0

    isiOS4Plus: ()->
      result = false
      # add iphone specific tests
      if Ti.Platform.name is 'iPhone OS'
        version = Ti.Platform.version.split "."
        major = parseInt(version[0])
        # can only test this support on a 3.2+ device
        result = major >= 4
      result

  Bonjour:
    serviceType: '_cg_trivially._tcp'
    domain: 'local.'
    port: 40401
    mode: Ti.Network.READ_WRITE_MODE
    hostName: Ti.Network.INADDR_ANY

  Commerce:
    kFAKEPURCHASED       : true # 2.7, 2017-06-10

    kReceiptDirectory    : Ti.Filesystem.applicationDataDirectory + "/receipts"
    kPurchaseLogFile     : Ti.Filesystem.applicationDataDirectory + "/purchases.txt"
    kReceiptTimeout      : 60 * 1000
    kPurchaseTimeout     : 2 * 60 * 1000
    kRestoreTimeout      : 30 * 1000

    StoreKit:
      kUseSandbox :  false
      kVerifyReceipt: true

  PlayerNetwork:
    kHelpPage  : "??"
    ActivityMonitor:
      kRemotePingInterval: 30 * 1000       # This is here just for reference. See main.coffee.
      kCheckInterval   : (60*1000) + 10    # How often we check the status of connections. 
      kThresholdActive : (60*1000) + 10    # A client is "active" if we hear from it at least this often. 
                                           #  This is set to a value that's more than
                                           #  double the interval that clients are actually sending pings at, so that a client can
                                           #  miss a ping but still be counted as "active"
                                           #  
      kThresholdAlive  :  120*1000 + 10    # A client is dead if we don't hear from it within this timeframe.
                                           # We set it to greater than 4 ping cycles.
                                           #

    RunsInOwnThread: false                  # Whether player network runs in its own thread.

    HTTPServerRunsInOwnThread: true       # Whether or not the HTTP Server runs in its own thread. If false, runs in the same
                                           # thread as PlayerNetwork.

  NetworkService:
    kQueueImmediateInterval   :  1 * 1000
    kQueueBackgroundInterval  : 10 * 1000
    kDefaultEventTimeout      : 20 * 1000 # changed from 10 to 20 for 2.5.0

  Rendezvous:
    URL                      : "??"
    URLDisplayName           : "?"
    API                      : "??"
    MinConsoleUpdateInterval : 5 * 60 * 1000 # 5 minutes

  Update:
    kUpdateBaseURL       : "??"

    # Changed protocol for naming the update manifest, as of 2.3: 
    # Now there's one manifest per shipped version of the app
    #
    kUpdateCheckInterval : 10*60*1000 # 10 minutes - changed for 2.0

    kRateAppReminderFileName : Titanium.Filesystem.applicationDataDirectory + "/AppReminderLog"

  Trace:
    messagesOn       : false
    memoryLogging    : false
    uiTrace          : false
    # HACK, as "applicationDirectory" seems to be returning a path with "Applications" at the end
    LogFileDirectory : Titanium.Filesystem.applicationDataDirectory + "../tmp" 
    MarkerFilename: Titanium.Filesystem.applicationDataDirectory + "../tmp" + "/MARKER.txt"

  Content:
    kContentMajorVersionSupported  : "003"
    kUsageDatabaseName             : "CrowdGame_Trivially_Usage_database"
    kUsageDatabaseVersion          : "001"
                                     # This is the "documents" directory
    kUpdateDirectory               : Ti.Filesystem.applicationDataDirectory
    kThirdPartyContentDirectory    : Ti.Filesystem.applicationDataDirectory + "/third-party"
    kShippedDirectory              : Ti.Filesystem.resourcesDirectory + "/data"
    kDefaultIconDirectory          : Ti.Filesystem.resourcesDirectory + "/data"
    kInventoryInterval             : 60 * 1000
    kInventoryTimeout              : 30 * 1000

    kContentPackMaxNameLength               :  50
    kContentPackMaxLongDescriptionLength    : 175
    kContentPackMaxIconSpecLength           :  30
    kContentPackMaxQuestionLength           : 120
    kContentPackMaxAnswerLength             :  55
    kContentPackMaxAuthorVersionInfoLength  :  10
    kContentPackMaxAuthorContactInfoLength  :  (64 + 1 + 255) #http://askville.amazon.com/maximum-length-allowed-email-address/AnswerViewer.do?requestId=1166932
    kContentPackWithHeaderMaxNumHeaderProps :  20

    kThirdPartyContentPackMinNumRecords     :   5
    kThirdPartyContentPackMaxNumRecords     : 200

    kAppStoreProductInfo_CustomTriviaPackFeature_1: "custom_trivia_pack_feature_1"

    kHelpPage  : "??"

    kContentPackMaxBytes                    : -1
    kThirdPartyContentPackMaxBytes          : 1000 * 1024 # 100k

    kThirdPartyContentBuyText: "buy"
    kThirdPartyContentNewText: "new"
    kThirdPartyContentInfoText: "info"

  Analytics: 
    
    active                        : true
    Namespace                     : "Hy.Analytics"
    Version                       : "1.0"
    Google:
      accountID                   : "??"

  Support:
    email                         : "??"
    contactUs                     : "??"

  Avatars:
    kShippedDirectory : Ti.Filesystem.resourcesDirectory + "assets/avatars"

    kMaxNumAvatars    : 12 # kMaxRemotePlayers + 1 (for Console Player)

    critters:
      name     : "critters"
      animated : false
      height   : 80
      width    : 80
      padding  : 1

    gameshow:
      name     : "gameshow"
      animated : true
      height   : 115
      width    : 80
      padding  : 5

  UI:
    kTouchAndHoldDuration: 900
    kTouchAndHoldDurationStarting : 300
    kTouchAndHoldDismissDuration: 2000 # Amount of time the menu stays up after touch event has fired

Hy.Config.Update.kUpdateFilename = "trivially-update-manifest--v-#{Hy.Config.Version.Console.kConsoleMajorVersion}-#{Hy.Config.Version.Console.kConsoleMinorVersion}-#{Hy.Config.Version.Console.kConsoleMinor2Version}.json"

if not Hy.Config.Production
  Hy.Config.Trace.messagesOn                      = true
  Hy.Config.Trace.memoryLogging                   = true
  Hy.Config.Trace.uiTrace                         = true

  Hy.Config.Commerce.StoreKit.kUseSandbox         = true

  Hy.Config.Update.kUpdateCheckInterval = 3 * 60 * 1000

  Hy.Config.Analytics.Namespace         = "Hy.Analytics"
  Hy.Config.Analytics.Version           = "1.0"

  Hy.Config.PlayerNetwork.HTTPServerRunsInOwnThread = false
  Hy.Config.PlayerNetwork.RunsInOwnThread = false

  # Really important to unset this prior to shipping
  Hy.Config.Commerce.kFAKEPURCHASED = true 

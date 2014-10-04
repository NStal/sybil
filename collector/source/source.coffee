Initializer = require "./initializer.coffee"
                                            
Updater = require "./updater.coffee"
Authorizer = require "./authorizer.coffee"
Errors = require "./errors.coffee"
EventEmitter = (require "events").EventEmitter
console = console = env.logger.create __filename
# implements
# ::detectStream(uri)
# return an stream object that will emit stream in future.
# 
# @type: collectorName
# @properties: collector specified source meta this should
# @authorized: if is authorized
# @authorizeInfo: used for authorization
# @hasError: set if Error clear on success
#
# also to implements the Updater/Authorizer/Initializer if needed
# Event
class Source extends EventEmitter
    # Detect source from a single URI
    # We may detect several stream from a single URI, and
    # may of them may be network related.
    # To make it fast, we make it a lazy stream, sources are
    # streamed when detected so there is no need to waiting.
    @detectStream = (uri)->
        return @delayStream()
    # A little helper for Sources that can create source immediately
    # and dont' want to write a lazy stream.
    @delayStream = (datas = [])->
        stream = new EventEmitter()
        process.nextTick ()->
            for data in datas
                stream.emit "data",data
            stream.emit "end"
        return stream
    Initializer:Initializer
    Authorizer:Authorizer
    Updater:Updater
    constructor:(@info = {})->
        # if @info has guid
        # than it's loaded from database
        # or we are now trying to develop a new one
        super()
        @name = @info.name
        @type = @info.type or @info.collectorName
        @uri  = @info.uri
        @guid = @info.guid
        @properties = @info.properties or {}

        @maxNetworkErrorRetry = 3
        @authorizer = new @Authorizer(this);
        @updater = new @Updater(this);
        @initializer = new @Initializer(this);
        @authorizer.on "panic",@onAuthorizerPanic.bind(this)
        @updater.on "panic",@onUpdaterPanic.bind(this)
        @initializer.on "panic",@onInitializerPanic.bind(this)
        
        @authorizer.on "requireLocalAuth",()=>
            # requireLocalAuth state updates
            console.debug "#{@uri} requires local auth"
            @emit "modify"
            @emit "requireLocalAuth"
        @authorizer.on "requireHumanRecognition",(info)=>
            @pinCodeInfo = info
            @emit "requirePinCode",info
        @updater.on "modify",()=>
            @emit "modify"
        @authorizer.on "authorized",()=>
            @clearError()
            @emit "modify"
            @emit "authorized"
        @updater.on "update",()=>
            @lastUpdate = new Date()
        @updater.on "archive",(archive)=>
            @emit "archive",archive
        @updater.on "fetch",()=>
            @clearError()
        @initializer.on "initialized",()=>
            @clearError()
            @emit "initialized"
    setLocalAuth:(username,secret)->
        @authorizer.give "localAuth",username,secret
    setPinCode:(pinCode)->
        @authorizer.give "pinCode",pinCode
    start:()->
        if not @guid
            throw new Error "can't start without initialize the source"
        if @info.requireLocalAuth
            console.debug "#{@guid} requires reAuth at start"
            @updater.nextFetchInterval = 0
            @authorizer.reAuth ()=>
                @updater.give "startSignal"
        else 
            @updater.give "startSignal"
    stop:()->
        @updater.stop()
    toSourceModel:()->
        @requireLocalAuth = @authorizer.isWaitingFor("localAuth")
        @requirePinCode = @authorizer.isWaitingFor("pinCode")
        return {
            name:@name
            ,guid:@guid
            ,uri:@uri
            ,collectorName:@type
            ,type:@type
            ,@requireLocalAuth
            ,@requirePinCode
            ,authorized:@authorizer.authorized
            # properties is for collector at init
            # while meta is for other module
            # so other module should only modify meta but can read properties
            # while collector should only read and modify properties to prevent
            # lock issue
            ,properties:@properties or {} 
            ,authorizeInfo:@authorizer.authorizeInfo
            # last time the source are fetch attempted and had some archive found
            ,lastUpdate:@lastUpdate
            # last time the source being fetched
            # no matter does it have updates or not.
            ,lastFetch:@updater.lastFetch
            # we can adjust the fetch interval at next reboot
            # detailed algorithm please view ./updater.coffee
            ,nextFetchInterval:@updater.nextFetchInterval or 1
            ,lastErrorDescription:@lastErrorDescription
            ,lastError:@lastError
            
        }
    logError:(error,description)->
        @lastError = error
        @lastErrorDescription = description
        console.debug error,description
        @emit "modify"
    clearError:(error,description)->
        @lastError = null
        @lastErrorDescription = null
    onAuthorizerPanic:(error,state,silent)->
        
        @logError error,"error at authorizer of state: #{state}"
        if error instanceof Errors.AuthorizationFailed
            # auth fail ask user to try again
            # no error reporting
            @authorizer.recover()
            @authorizer.reset()
            @authorizer.start()
        else if error instanceof Errors.NetworkError
            @authorizer.recover() 
            # retry?
            @authorizer.networkRetry = @authorizer.networkRetry or 0 
            @authorizer.networkRetry++
            if @authorizer.networkRetry > @maxNetworkErrorRetry
                @authorizer.networkRetry = 0
                @authorizer.standBy()
                @emit "authorizationFailed"
            else
                # no need to give startSignal at recover
                @authorizer.start()
        else if not silent
            throw new Errors.UnkownError("unknown error at authorizing state:#{state}",via:error)
        else
            return false
        return true
    forceUpdate:(callback = ()->)->
        # Note: forceUpdate SHOULD have impact on nextFetchInterval.
        # But the impact must be LIMITED.
        # Interval should only decrease but not increase.
        # Let's see why:
        # 
        # User may force update at any time, if there are no updates, the interval
        # will grow longer by default.
        # If user force update several times at a
        # short period without and updates,
        # the interval will grow to an unreasonable large value.
        # So we don't allow increase in force fetch.
        # 
        # On the other hand, if there are some updates during the force update,
        # interval will decrease, and there is no harm. They won't always have
        # new content, even they do, it's reasonable to update at a high frequency.

        
        # do some check and take some action
        # before just waiting for update
        nextFetchInterval = @updater.nextFetchInterval
        if @updater.state is "void"
            if @updater.isWaitingFor "startSignal"
                @updater.give "startSignal"
            else
                callback new Errors.LogicError "source at void state but not waiting for start signal, it must be stop by someone else. Start it by forceUpdate is dangerous, I refuse to do so."
                return
            
        else if @updater.state is "waitAuth"
            callback new Errors.AuthorizationFailed "you should promise a valid authorizer state before call forceUpdate, currently updater is at waitAuth state"
            return
        else if @updater.state is "wait"
            console.debug "force update #{@uri} by clear current next timer and invoke now"
            clearTimeout @updater.nextTimer
            @updater.setState "fetching"
        # for other state just waiting for fetching or error is OK
        # the above state also share the waiting codes
        fetchHandler = ()=>
            # see comments at begin of the force update method
            if @updater.nextFetchInterval > nextFetchInterval
                @updater.nextFetchInterval = nextFetchInterval
            clear()
            callback()
        errorHandler = (err)->
            clear()
            callback err
        clear = ()=>
            @updater.removeListener "fetch",fetchHandler
            @updater.removeListener "panic",errorHandler
        @updater.once "fetch",fetchHandler
        @updater.once "panic",errorHandler
            
    onInitializerPanic:(error,state)->
        
        @logError error,"error at initializer of state: #{state}"
        # Initialize is a one time business
        # success or fail, no excuse ,no retry.
        # Only one exception, when it requires auth
        if error instanceof Errors.AuthorizationFailed
            @initializer.recover()
            @initializer.reset()
            @initializer.standBy()
            console.debug "try start auth"
            @authorizer.tryStartAuth ()=>
                @initializer.give "startSignal"
        else
            console.debug "initializer panic at #{state}",error
            @initializer.recover()
            @emit "initializeFailed"
        return true
    onUpdaterPanic:(error,state,silent)->
        @logError error,"error at updater of state: #{state}"
        console.debug "updater panic at #{state}",error
        if error instanceof Errors.AuthorizationFailed
            console.debug "####panic update for auth!"
            @authorizer.reAuth ()=>
                @updater.recover()
                @updater.nextFetchInterval = 0
                @updater.start()
        else if error instanceof Errors.NetworkError
            @updater.recover()
            @updater.later()
            @updater.start()
        else if error instanceof Errors.ParseError
            @updater.recover()
            @updater.later()
            @updater.start()
        else if error instanceof Errors.UnkownError
            console.debug "recieve unkown error at state: #{state}"
            console.debug "error: ",error
            console.debug "we temperarily consider it as net work error"
            @updater.recover()
            @updater.later()
            @updater.start()
        else if not silent
            throw new Errors.UnkownError("unkown error at state:#{state}",{via:error})
        else
            return false
        return true
module.exports = Source
Source.Errors = Errors
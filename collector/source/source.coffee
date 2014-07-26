Initializer = require "./initializer.coffee"
                                            
Updater = require "./updater.coffee"
Authorizer = require "./authorizer.coffee"
Errors = require "./errors.coffee"
EventEmitter = (require "events").EventEmitter
# implements
# ::detect(uri,callback)
# detect some sources from uri
# 
# @type: collectorName
# @properties: collector specified source meta
# @authorized: if is authorized
# @authorizeInfo: used for authorization
# @hasError: set if Error clear on success
#
# also to implements the Updater/Authorizer/Initializer if needed
# Event
class Source extends EventEmitter
    # detect source from a single URI
    # make it fast.
    @detect = (uri,callback)->
        callback null,[]
    @detectStream = (uri)->
        stream = new EventEmitter()
        process.nextTick ()->
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
        
        @updater = new @Updater(this);
        @authorizer = new @Authorizer(this);
        @initializer = new @Initializer(this);
        @authorizer.on "requireLocalAuth",()=>
            console.log "do we require local auth???"
            @on "requireLocalAuth",()=>
                console.log "!@#!#!@#!@"
            @needAuth = true
            @emit "change"
            @emit "requireLocalAuth"
        @authorizer.on "requireHumanRecognition",(info)=>
            @needPinCode = true
            @pinCodeInfo = info
            @emit "requirePinCode",info
        # carefully onchange manually change
        # state if it's at void
        @updater.on "requireAuth",()=>
            @authorizer.once "authorized",()=>
                @updater.start()
            if @authorizer.state is "void"
                @authorizer.reset()
                @authorizer.start()
        @updater.on "modify",()=>
            @emit "modify"
        # always save authorized infos after authorized
        @authorizer.on "authorized",()=>
            @emit "modify"

        @updater.on "update",()=>
            @lastUpdate = new Date()
        @updater.on "archive",(archive)=>
            @emit "archive",archive
        @updater.on "exception",(e)=>
            @lastException = JSON.stringify(e)
            @lastExceptionDate = new Date()
        @initializer.on "requireAuth",()=>
            @authorizer.once "authorized",()=>
                @initializer.start()
            console.log "authorizer?",@authorizer.state
            if @authorizer.state is "void"
                @authorizer.reset()
                @authorizer.start()
        @initializer.on "initialized",()=>
            @emit "initialized"
    setLocalAuth:(username,secret)->
        if @needAuth
            @authorizer.localAuth username,secret
            @needAuth = false
    setPinCode:(pinCode)->
        if @needPinCode
            @authorizer.setPinCode pinCode
            @needPinCode = false
    start:()->
        if not @guid
            throw new Error "can't start without initialize the source"
        @updater.start()
    stop:()->
        @updater.stop()
    toSourceModel:()->
        return {
            name:@name
            ,guid:@guid
            ,uri:@uri
            ,collectorName:@type
            ,type:@type
            ,authorized:@authorizer.authorized
            # properties is for collector at init
            # while meta is for other module
            # so other module should only modify meta but can read properties
            # while collector should only read and modify properties to prevent
            # lock issue
            ,properties:@properties or {} 
            ,authorizeInfo:@authorizer.authorizeInfo
            ,hasError:@hasError
            ,lastUpdate:@lastUpdate
            ,lastFetch:@updater.lastFetch
            ,nextFetchInterval:@updater.nextFetchInterval or 1
            ,lastException:@lastException
            ,lastExceptionDate:@lastExceptionDate
        }
module.exports = Source
Source.Errors = Errors
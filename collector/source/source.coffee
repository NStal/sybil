Initializer = require "./initializer.coffee"

Updater = require "./updater.coffee"
Authorizer = require "./authorizer.coffee"
Errors = require "./errors.coffee"
EventEmitter = (require "events").EventEmitter
States = sybilRequire "common/states.coffee"
console = console = env.logger.create __filename
# Network is complicated and standards are so powerless in the real world.
# When it comes to a crawler, the difficulty doubles for me to build
# a stable one.
# So I write these modules using a very very clear state machine.
# Whenever a exception shows up,
# I can faced, hunt it down, or at least
# I know when to die.
# But I only write them once.
# Any type of source should reuse the state machine and only
# implement some basic action, without doing error handlings.

# At least implements for the children class.
# Source.detectStream(uri)
#
# Also need to implement Updater/Initializer.
# And optionaly implements an Authorizer if needed.
#
class Source extends States
    # Detect source from a single URI
    # We may detect several stream from a single URI, and
    # many of them may be network related.
    # So to make it responsive and usable, I give it a lazy stream,
    # sources ares treamed when detected so there is no need to hang and wait.
    @detectStream = (uri)->
        return @delayStream()
    # A little helper for Sources that want to create source immediately
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
    toSourceModel:()->
        return {
            name:@name
            ,guid:@guid
            ,uri:@uri
            ,collectorName:@type
            ,type:@type
            ,requireLocalAuth:@authorizer.isWaitingFor("localAuth")
            ,requireCaptcha:@authorizer.isWaitingFor("captcha")
            ,captcha:@authorizer.getCaptchaInfo()
            ,initialzeInfo:@initializer.data.initializeInfo
            ,authorized:@authorizer.data.authorized or false
            ,authorizeInfo:@authorizer.data.authorizeInfo or {}
            ,properties:@data.properties or {}
            # Last time the source are fetched
            # and had some archive found
            ,lastUpdate:new Date(@updater.data.lastUpdate)
            # Last time the source are trying to fetch something,
            # no matter does it have any result or not.
            ,lastFetch:new Date(@updater.data.lastFetch)
            # we can adjust the fetch interval at next reboot
            # detailed algorithm please view ./updater.coffee
            ,nextFetchInterval:@updater.data.nextFetchInterval or 1
            ,lastErrorDescription:@data.lastErrorDescription
            # LastError do NOT represent current source state
            # but only a hint for a source's general state.
            # This may be a source panic or sub-module's complaint.
            # Thus may only be used as displaying material or
            # a general infer for debug.
            ,lastError:@data.lastError or null
            ,lastErrorDate:@data.lastErrorDate or null
            ,lastErrorState:@data.lastErrorState or null
            ,panic:@data.panicError or null
        }
    logError:(err)->
        @data.lastError = err
        @data.lastErrorDate = new Date()
        @data.lastErrorState = @state
        @emit "modify"
    clearError:()->
        @data.lastError = null
        @data.lastErrorDate = null
        @data.lastErrorState = null
        @emit "modify"
    constructor:(@info = {})->
        # @info are the data stored of the current source
        # from last shut down, or just empty which means
        # this is a newly created uninitialized source.

        # If @info has guid
        # than it's loaded from database or at least valid.
        # else we are now trying to make a new one,
        # see @isInitialized() for detail
        @name ?= @info.name
        # collectorName is backward compatability
        # will be deleted at release
        @type ?= @info.type or @info.collectorName
        @uri  ?= @info.uri
        @guid ?= @info.guid
        # when initialize and authorizing, and we encounter
        # a network error we will give it a second chance before
        # we panic
        @maxNetworkErrorRetry = 2



        # All source are consist of the three parts below.
        # At least initializer and updater is should be provided.
        # The authorizer will not be involved unless any of the
        # sub module panic at AuthorizationFailed.
        @authorizer = new @Authorizer(this)
        @authorizer.source = this
        @updater = new @Updater(this)
        @updater.source = this
#        @data.nextFetchInterval = @source.info.nextFetchInterval or @data.nextFetchInterval
#        # see @atWait method for detail explaination
#        @data.lastFetch = @source.info.lastFetch and (new Date(@source.info.lastFetch)).getTime() or @data.lastFetch
#        now = Date.now()
#        @data.leftInterval = @data.nextFetchInterval - (now - @data.lastFetch)
#        if @data.leftInterval <= 0
#            console.debug "left interval too small: #{@data.leftInterval}. set to 1"
#            @data.leftInterval = 1
#        console.log @data.leftInterval,@data.nextFetchInterval,"updater interval"
        @initializer = new @Initializer(this)
        @initializer.source = this
        # Prepare is done.
        # The wheel of fate is turning.
        # (Just annouce that the state machine is ready to go...)

        super()

        @data.properties = @info.properties or {}
        @standBy()
    reset:()->
        console.log "reset #{@uri}"
        @authorizer.reset()
        @initializer.reset()
        @updater.reset()
        super()
    standBy:()->
        @waitFor "startSignal",@_start.bind(this)
    start:()->
        @give "startSignal"
    _start:()->
        if @isInitialized()
            @recoverStateFromInfo()
        else
            @setState "initializing"
    isInitialized:()->
        return !!@guid
    recoverStateFromInfo:()->

        # Maybe we should restore the exactly authorizer
        # and initializer state in future. But only restore
        # the updater and let it to trigger the authorizer if
        # needed is much easier, and likely to be enough.
        # so we only restore the data
        # authorizeInfo,authorized,initializeInfo,initialized
        @authorizer.data.authorized = @info.authorized
        @authorizer.data.authorizeInfo = @info.authorizeInfo
        @initializer.data.initialized = true
        @initializer.data.initializeInfo = @info.initializeInfo

        # We didn't have a STOP state for a source, thus
        # we directly jump to prepareUpdate
        # If we add a STOP state for the source
        # , I may wait for a `startUpdateSignal`
        # , and ask for maker to give a startUpdateSignal to start it
        # , just saying.
        @setState "prepareUpdate"
    atInitializing:()->
        @initializer.reset()
        @initializer.standBy()
        # we may have some authorize info
        @initializer.setData {authorizeInfo:@authorizer.data.authorizeInfo or {}}
        @clear ()=>
            @initializer.stopListenBy this
        @initializer.listenBy this,"initialized",()=>
            @clear()
            @emit "modify"
            @guid = @initializer.data.guid or "#{@type}_#{@uri}"
            @name = @initializer.data.name or @uri
            @setState "initialized"
        @initializer.listenBy this,"panic",(err,state)=>
            @clear()
            @logError err
            if err instanceof Errors.AuthorizationFailed
                @setState "authorizing"
                return
            else
                # For most error in initialize error we just panic.
                # They should be handled by source creator.
                @error err
                return
        @initializer.give "startSignal"
    atInitialized:()->
        # Initialize process are usually triggered by
        # user subscribe action. User may need to confirm it.
        # So I wait for `startUpdateSignal`
        @waitFor "startUpdateSignal",()=>
            @setState "prepareUpdate"
        @emit "initialized"
        @emit "modify"
    atAuthorizing:()->
        @authorizer.reset()
        @authorizer.standBy()
        @clear ()=>
            @authorizer.stopListenBy this
        @authorizer.listenBy this,"wait/localAuth",()=>
            @waitFor "localAuth",(username,secret)=>
                @authorizer.give "localAuth",username,secret
        @authorizer.listenBy this,"wait/captcha",()=>
            @waitFor "captcha",(captcha)=>
                @authorizer.give "captcha",captcha
        @authorizer.listenBy this,"authorized",()=>
            @clear()
            @emit "modify"
            @emit "authorized"
            if @initializer.panicError instanceof Errors.AuthorizationFailed
                @initializer.recover()
                @initializer.data.authorizeInfo = @authorizer.data.authorizeInfo or {}
                @setState "initializing"
                return
            else if @updater.panicError instanceof Errors.AuthorizationFailed
                @updater.recover()
                @updater.data.authorizeInfo =  @authorizer.data.authorizeInfo or {}
                @updater.setState "fetching"
                @setState "updating"
                return
            else
                @error new Errors.LogicError "authorized but neither updater nor initializer in authorization failed panic, must be logic error"
        @authorizer.listenBy this,"panic",(err,state)=>
            @clear()
            @logError err
            # When we get panic at authorizer, there are two possibility.
            # 1. Wrong username/secret.
            # 2. Logic/Network error.
            #
            # It seems make sence if we simple go to `authorizing` state.
            # Since it will trigger reauth again for situation 1.
            # And during the reauth the network error will be test again.
            #
            # On the other hand we can leave the choice to the upper statemachine
            # to decide what to do. And as a result we will have a AuthorizationFailed panic
            # and hang.
            #
            # At this point of time, the upper statemachine is likely to be a frontend related
            # one. which is quite unpredictable. So I will just retry the authorizing.
            #
            @setState "authorizing"
            # I don't panic for now
            return

#            if err instanceof Errors.AuthorizationFailed
#                # Maybe maker will abondon this source
#                # or they may try to change the password and try again
#                @error err
#                return
#            else
#                # For other none AuthorizationFailed  error from authorizer
#                # it is appear to outside world as an AuthorizationFailed
#                @error new Errors.AuthorizationFailed("authorizer failed to authorize, see @via for detail",{via:err})
            return
        @authorizer.give "startSignal"
    atPrepareUpdate:()->
        @updater.reset()
        nextFetchInterval = @info.nextFetchInterval or @updater.data.nextFetchInterval
        lastFetch = new Date(@info.lastFetch or 0).getTime() or @updater.data.lastFetch
        leftInterval = nextFetchInterval - (Date.now() - lastFetch)
        lastUpdate = @info.lastUpdate
        if leftInterval < 1
            leftInterval = 1
        @updater.setData {
            nextFetchInterval
            ,lastFetch
            ,lastUpdate
            ,leftInterval
            ,authorizeInfo:@authorizer.data.authorizeInfo
            ,initializeInfo:@initializer.data.initializeInfo
            ,prefetchArchiveBuffer:@initializer.data.prefetchArchiveBuffer  or []
        }
        @updater.standBy()
        @updater.once "init/archives",(archives)=>
            for archive in archives
                @emit "archive",archive
        @updater.give "startSignal"
        @setState "updating"
    atUpdating:()->
        # Respawn, so we reset all state and waitings, but
        # preserve @updater.data which may be set at "prepareUpdate"
        # or by updater herself during the last updating states
        @clear ()=>
            @updater.stopListenBy this
        @updater.listenBy this,"archive",(archive)=>
            @emit "archive",archive
        @updater.listenBy this,"fetch",()=>
            @clearError()
        @updater.listenBy this,"update",()=>
            @emit "update"
        @updater.listenBy this,"modify",()=>
            @emit "modify"
        @updater.listenBy this,"panic",(err)=>
            @clear()
            @logError err
            if err instanceof Errors.AuthorizationFailed
                @setState "authorizing"
                return
            else
                @setState "judgeUpdater"

    atJudgeUpdater:()->
        {error:err,state} = @updater.recover()
        console.error "updater error at #{state}",err
        if not err
            @error new Errors.LogicError "judging updater while no error"
        else if err instanceof Errors.AuthorizationFailed
            @error new Erros.LogicError "authorization error should goto authorizer state without recover, not into judgeUpdater state"
        else if err instanceof Errors.NetworkError
            # Due to net work error we postpone the next fetching
            @updater.later()
            @updater.setState "sleep"
            @setState "updating"
        else if err instanceof Errors.Timeout
            # Timeout should more likely due to sort of
            # network error.
            @updater.later()
            @updater.setState "sleep"
            @setState "updating"
        else if err instanceof Errors.ParseError
            # Maybe broken network transfering
            # No need to delaying just try again.
            #
            # There are also rare case (maybe not that rare)
            # that the programmer failed to handle some certain state.
            # In this case the ParserError may throw at the first fetch
            # attemp. And the sleep time is 1ms. I will adjust it to
            # min interval instead.
            if @updater.data.nextFetchInterval < 10
                # sooner will decrease the next interval
                # not none less than min interval defined by the updater
                @updater.sooner()
            @updater.setState "sleep"
            @setState "updating"
        else
            # Some unexpected errors, shouldn't be
            # The only way to recover from a logic panic safely (sort of)
            # is to completely reset the state machine, just a side note.
            @error new Errors.LogicError "unexpected error when judge updater panic, see via for detail",{via:err,state:state}
        return
    # Some manual interfere the state machine with various strick check
    # to make sure it works well.
    debug:(option)->
        super(option)
        @updater.debug(option)
        @authorizer.debug(option)
        @initializer.debug(option)
    forceUpdate:(callback = ()-> )->
        if @state is "panic"
            callback new Errors.LogicError "Fail to force update we are in unrecoverable panic",{@state,@panicError,@panicState}
            return
        if @state isnt "updating"
            callback new Errors.LogicError "Force updating only allowed when source is at updating state, current state is #{@state}"
            return
        if @data.isForceUpdating
            callback new Errors.Duplication("already force updating")
            return

        @data.forceUpdateId = {random:Math.random().toString()}
        clear = ()=>
            if @data.forceUpdateId
                @updater.stopListenBy @data.forceUpdateId
            @data.isForceUpdating = false
            @data.forceUpdateId = null
        @data.isForceUpdating = true
        nextFetchInterval = null
        @updater.listenBy @data.forceUpdateId,"panic",(err)=>
            clear()
            callback err
        @updater.listenBy @data.forceUpdateId,"fetch",()=>
            clear()
            callback()
        if @updater.state is "sleep"
            # `@forceUpdate` should reduce the sleep time if update occurs,
            # but won't increase the sleep time if no updates.
            # For updated case, we are more likely to get new update recently
            # , this is why we reduce the sleep time when updates
            # , and this is also the default behavior in regular updating process.
            # For no update case, we usually increase the sleep time,
            # since it is more likely to be no update recently in future.
            # But when it comes to `@forceUpdate`, things changed.
            # User may manually call `@forceUpdate` several times at a
            # short period, In this case, no updates may give no valuable hint
            # to updater except the very first forceUpdate.
            # If we increase the sleep time at this case, the interval
            # may becomes unpredictable large. This is very bad.
            # So we don't increase it, which will have
            # very little impact on our updating result.
            nextFetchInterval = @updater.data.nextFetchInterval
            clearTimeout @data.nextTimer
            @updater.setState "prepareFetch"
            return
        # Since `@state` is `updating` and
        # `@updater.state` isnt `sleep`
        # , `@updater` must during the fetch
        if @updater.state not in ["fetching","prepareFetch"]
            clear()
            callback new Errors.LogicError "a correct updater should be in fetching or prepareFetch state, other state should be impossible to access (SYNC) or shouldnt be. Current state is #{@updater.state}"
module.exports = Source
Source.Errors = Errors

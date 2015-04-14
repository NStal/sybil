console = global.env.logger.create(__filename)
EventEmitter = (require "events").EventEmitter
console = env.logger.create __filename
Errors = require "./source/errors"
# SourceManager keeps all sources that are already initialized.
# SourceManager should report archive when source emits any.
# SourceManager should emits "source/modify" when any source get modified.
# Modified should be emit when any meta data of source changed, say,
# fetchIntervals , lastErrors , lastUpdate etc.
class SourceManager extends EventEmitter
    constructor:()->
        @sources = []
    add:(source)->
        exists = @sources.some (old)->
            if old.guid is source.guid
                return true
            return false
        if exists
            console.debug "source of guid:#{source.guid} exists, won't add"
            return false
        @sources.push source
        source.on "archive",(archive)=>
            console.log "gbet archive",archive.guid
            @emit "source/archive",source,archive
            @emit "archive",archive
        source.on "modify",()=>
            @emit "source/modify",source.toSourceModel()
        source.on "wait/localAuth",()=>
            @emit "source/requireLocalAuth",source.toSourceModel()
        source.on "wait/captcha",()=>
            @emit "source/requireCaptcha",source.toSourceModel()
        source.on "wait",()=>
            @emit "source/modify",source.toSourceModel()
        source.on "authorized",()=>
            @emit "source/authorized",source.toSourceModel()
        source.on "panic",()=>
            @emit "source/modify",source.toSourceModel()
            @emit "source/panic",source.toSourceModel()
        # for recovered source it should be waiting for start signal
        if source.isWaitingFor "startSignal"
            source.give "startSignal"
        # For newly detected source should always
        # be at initialized state and waiting for a startUpdateSignal
        if source.isWaitingFor "startUpdateSignal"
            source.give "startUpdateSignal"
        return true
    remove:(source)->
        @sources = @sources.filter (target)->return target isnt source
        source.reset()
        source.removeAllListeners()
    forceUpdateSource:(guid,callback)->
        found = @sources.some (source)->
            if source.guid is guid
                source.forceUpdate callback
                return true
            return false
        if not found
            callback new Errors.NotExists("source of guid #{guid} not found")
    setSourceCaptcha:(guid,captcha,callback)->
        found = @sources.some (source)->
            if source.guid is guid
                if source.isWaitingFor "captcha"
                    source.give "captcha",captcha
                    callback null
                else
                    callback Errors.InvalidAction "source is not waiting for a captcha"
                return true
            return false
        if not found
            callback new Errors.NotExists("source of guid #{guid} not found")

    setSourceLocalAuth:(guid,username,secret,callback)->
        found = @sources.some (source)->
            if source.guid is guid
                if source.isWaitingFor "localAuth"
                    source.give "localAuth",username,secret
                    callback null
                else
                    callback Errors.InvalidAction "source is not waiting for a `localAuth`"
                return true
            return false
        if not found
            callback new Errors.NotExists("source of guid #{guid} not found")
    # Using the source inside SourceManager to update
    # the given model.
    # Why do I do this?
    #
    # Some properties like Source.unreadCount which is important
    # for user experience but has nothing to do with the collector.
    # Collector don't maintain a unread count, because it has no knowledge of
    # the old archives. So it's not reasonable
    # to use Collector.Source as a source model cache.
    #
    # But some latest error will only be precisely available at Collector.Source such as
    # latest error or lastFetch time. This kinds of properties are import to frontend
    # as well.
    #
    # So I provide a expandSourceInfo method to update the information of a given model from
    # database by  the knowledge in SourceManager.Source.
    expandSourceInfo:(model)->
        for source in @sources
            if source.uri is model.uri
                m = source.toSourceModel()
                for prop of m
                    if m.hasOwnProperty prop
                        model[prop] = m[prop]
                return model
        return model
module.exports = SourceManager

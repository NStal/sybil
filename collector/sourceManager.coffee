console = global.env.logger.create(__filename)
EventEmitter = (require "events").EventEmitter
console = env.logger.create __filename
Errors = require "./source/errors.coffee"
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
            return
        @sources.push source
        source.on "archive",(archive)=>
            @emit "archive",archive
        source.on "modify",()=>
            @emit "source/modify",source.toSourceModel()
        source.on "requireLocalAuth",()=>
            @emit "source/requireLocalAuth",source.toSourceModel()
        source.on "authorized",()=>
            @emit "source/authorized",source.toSourceModel()
        source.updater.start()
    remove:(source)->
        @sources = @sources.filter (target)->return target isnt source
        source.stop()
        source.removeAllListeners()
    forceUpdateSource:(guid,callback)->
        found = @sources.some (source)->
            if source.guid is guid
                source.forceUpdate callback
                return true
            return false
        if not found
            callback new Errors.NotExists("source of guid #{guid} not found")
    setSourceLocalAuth:(guid,username,secret,callback)->
        found = @sources.some (source)->
            if source.guid is guid
                source.setLocalAuth username,secret
                callback null
                return true
            return false
        if not found
            callback new Errors.NotExists("source of guid #{guid} not found")
        
module.exports = SourceManager

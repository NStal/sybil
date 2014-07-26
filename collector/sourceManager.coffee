console = global.env.logger.create(__filename)
EventEmitter = (require "events").EventEmitter
console = env.logger.create __filename
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
        source.updater.start()
    remove:(source)->
        @sources = @sources.filter (target)->return target isnt source
        source.stop()
        source.removeAllListeners()

module.exports = SourceManager

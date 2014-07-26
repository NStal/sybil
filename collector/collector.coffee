EventEmitter = (require "events").EventEmitter
SourceManager = require "./sourceManager.coffee"
SourceSubscribeManager = require "./sourceSubscribeManager.coffee"
SourceList = require "./sourceList.coffee"
# All event emit from this module should be json serializable
# Consider this module are sort of edge interface of the
# collector system.
class Collector extends EventEmitter
    constructor:()->
        super()
        @sourceManager = new SourceManager()
        @sourceSubscribeManager = new SourceSubscribeManager()
        @sourceSubscribeManager.on "subscribe",(source)=>
            @sourceManager.add source
            @emit "subscribe",source.toSourceModel()
    loadSource:(sourceInfo)->
        # load and create source instance from information
        # previously saved to database or something like that
        Source = SourceList.Map[sourceInfo.type or sourceInfo.collectorName]
        if not Source
            console.error "Source type not supported"
            return null
        source = new Source sourceInfo
        console.log "Load source #{source.guid}"
        @sourceManager.add source
    removeSource:(guid)->
        for source in @sourceManager.sources
            if source.guid is guid
                @sourceManager.remove source
                return source
        return null
    
module.exports = Collector
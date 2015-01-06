EventEmitter = (require "events").EventEmitter
SourceManager = require "./sourceManager.coffee"
SourceSubscribeManager = require "./sourceSubscribeManager.coffee"
SourceList = (require "./sourceList.coffee")
# All event emit from this module should be json serializable
# Consider this module are sort of edge interface of the
# collector system.
#
# Collector contains: SourceManager and SourceSubscribeManager
# SourceSubscribeManager are responsible for source being subscribe.
# Sources at first initializing from user request under SourceSubscribeManager's control.
# After being initialized Source are handover to the SourceManager.
# Source restored from last shutdown via database will also directly go to SourceManager.
class Collector extends EventEmitter
    constructor:()->
        super()
        @sourceManager = new SourceManager()
        @sourceSubscribeManager = new SourceSubscribeManager()
        @sourceSubscribeManager.on "source",(source)=>
            # ensure JSON serializable
            added = @sourceManager.add source
            if not added
                @emit "exists",source.toSourceModel()
            else
                @emit "subscribe",source.toSourceModel()
        @sourceMap = SourceList.getMap()
#        @debug()
    setCustomSourceFolder:(folder)->
        SourceList.loadSourcesInFolder folder
        @sourceMap = SourceList.getMap()
    loadSource:(sourceInfo)->
        # load and create source instance from information
        # previously saved to database or something like that
        Source = @sourceMap[sourceInfo.type or sourceInfo.collectorName]
        if not Source
            console.error "Source type not supported"
            return null
        if Source.create
            source = Source.create(sourceInfo);
        else
            source = new Source sourceInfo
        console.log "Load source #{source.guid}"
        @sourceManager.add source
    removeSource:(guid)->
        for source in @sourceManager.sources
            if source.guid is guid
                @sourceManager.remove source
                return source
        return null
    debug:()->
        Source = require("./source/source.coffee")
        Source::_isDebugging = true
        Source::Authorizer::_isDebugging = true
        Source::Updater::_isDebugging = true
        Source::Initializer::_isDebugging = true
        SourceSubscribeManager.SubscribeAdapter::_isDebugging = true
module.exports = Collector

# recieves backend events to see if we need to update correspoding models
Model = require "model"
App = require "app"

class ModelSyncManager extends Leaf.EventEmitter
    constructor:()->
        super()
        App.initialLoad ()=>
            @setupSyncHandlers()
            @setMessageCenter App.messageCenter
    setMessageCenter:(mc)->
        if @mc
            @mc.stopListenBy this
        @mc = mc
        @mc.listenBy this,"event/source",(source)=>
            @emit "source",new Model.Source(source)
        @mc.listenBy this,"event/archive",(archive)=>
            @emit "archive",new Model.Archive(archive)
        @mc.listenBy this,"event/archive/listChange",(info)=>
            console.debug "recieve event","listChange",info
            @emit "listChange",info
    setupSyncHandlers:()->
        # not all event are recieved via backends
        # some event like read and unread are directly fired
        # by certain builtin model API callbacks logic
        # this is for performance reason
        # we may open an new connection to recieve events
        # and use a uniform way to do this.. in future
        @on "archive",(archive)=>
            for source in Model.Source.sources.models
                if source.guid is archive.sourceGuid
                    source.unreadCount += 1
        @on "archive/read",(archive)=>
            for source in Model.Source.sources.models
                if source.guid is archive.sourceGuid
                    source.unreadCount -= 1
        @on "archive/unread",(archive)=>
            for source in Model.Source.sources.models
                if source.guid is archive.sourceGuid
                    source.unreadCount += 1
module.exports = ModelSyncManager
# recieves backend events to see if we need to update correspoding models
App = require "/app"
Model = App.Model

class ModelSyncManager extends Leaf.EventEmitter
    constructor:()->
        super()
        App.afterInitialLoad ()=>
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
        @mc.listenBy this,"event/source/requireLocalAuth",(source)=>
            console.debug "recieve require localauth",source
            results = Model.Source.sources.find({guid:source.guid})
            if results.length is 0
                return
            results[0].sets(source)
            @emit "source/requireLocalAuth",results[0]
        @mc .listenBy this,"event/source/authorized",(source)=>
            console.debug "recieve authorized",source
            results = Model.Source.sources.find({guid:source.guid})
            if results.length is 0
                return
            results[0].sets(source)
            @emit "source/authorized",results[0]

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

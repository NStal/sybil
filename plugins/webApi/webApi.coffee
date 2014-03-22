express = require "express";
EventEmitter = (require "events").EventEmitter;
MessageCenter = (require "message-center").MessageCenter;
ws = require "ws"
WebSocket = ws
http = require "http"

console = require("../../common/logger.coffee").create("web-api")
sortArchive = (archives,what)->
    console.log "sort called!"
    archives.forEach (archive)->
        if archive.createDate
            return
        archive.createDate = archive.fetchDate or new Date(0)
    archives.sort (b,a)->
        return a.createDate.getTime() - b.createDate.getTime()

class WebApiServer extends EventEmitter
    constructor:(sybil,@settings)->
        # I can get data from sybil directly
        # every sybil interaction should be done via method
        # so sybil can watch what's happend and setup/optimize things
        @sybil = sybil
        @host = @settings.get("host") or @sybil.settings.webApiHost or "localhost"
        @httpPort = @settings.get("port") or @sybil.settings.webApiPort or 3007
        @setupHttpServer()
        @setupWebsocketApi()
        @sybil.on "archive",@pushArchive.bind this
        @sybil.on "source",@pushSource.bind this
        @sybil.on "readLater",@pushReadLater.bind this
        @sybil.on "unreadLater",@pushUnreadLater.bind this
        @sybil.on "archive/listChange",@pushListChange.bind this
        @sybil.on "friend/add",@pushFriendAdd.bind this
        @sybil.on "friend/remove",@pushFriendRemove.bind this
        @messageCenters = []
    createMessageCenter:()->
        mc = new MessageCenter()
        @setupMessageCenter(mc)
        @messageCenters.push mc
        @emit "messageCenter",mc
        return mc
    destroyMessageCenter:(mc)->
        mc.removeAllListeners()
        mc.unsetConnection()

        @emit "destroyMessageCenter",mc
        @messageCenters = @messageCenters.filter (item)->item isnt mc
        return true
    setupWebsocketApi:()->
        @websocketServer = new ws.Server({server:@httpServer})
        @websocketServer.on "connection",(connection)=>
            console.log "webApi get connection"
            mc = @createMessageCenter()
            mc.setConnection(connection)
            connection.on "close",()=>
                console.debug "connection close from client"
                @destroyMessageCenter(mc)
    setupHttpServer:()-> 
        @app = express()
        @app.use express.static(require("path").join(__dirname,"../../client/static"))
        console.debug "API server static file serve at",require("path").join(__dirname,"../client/static")
        @httpServer = http.createServer(@app)
        
        console.log @httpPort,@host,"listen"
        @httpServer.listen(@httpPort,@host)
    setupMessageCenter:(messageCenter)->
        messageCenter.registerApi "getConfig",(name,callback)=>
            @sybil.getConfig name,(err,config)=>
                callback err,config
        messageCenter.registerApi "saveConfig",(query,callback)=>
            @sybil.saveConfig query.name,query.data,(err)=>
                callback err
        messageCenter.registerApi "getCustomWorkspaces",(_,callback)=>
            @sybil.getCustomWorkspaces (err,workspaces)->
                callback err,workspaces
        messageCenter.registerApi "saveCustomWorkspace",(query,callback)=>
            @sybil.saveCustomWorkspace query.name,query.data,(err)->
                callback err
        messageCenter.registerApi "getCustomArchives",(query,callback)=>
            query.query.viewRead = query.viewRead or false
            @sybil.getCustomArchives query.query,(err,archives)=>
                if err
                    console.error err
                    err = "db error"
                    callback err
                    return
                sort = query.sort or "latest"
                if sort is "sybil"
                    true
                else if sort is "oldest"
                    true
                else
                    # default by latest
                    sortArchive(archives)
                if not query.viewRead
                    archives = archives.filter (item)->not item.hasRead
                console.log query,archives.length
                offset = query.offset or null
                count = query.count or 20
                if offset is null
                    offsetIndex = 0
                else
                    for item,index in archives
                        if item.guid is offset
                            offsetIndex = index+1
                            break
                if not offsetIndex
                    offsetIndex = 0
                callback err,archives.slice(offsetIndex,offsetIndex+count)
        messageCenter.registerApi "getSource",(guid,callback)=>
            @sybil.getSource guid,(err,source)->
                callback err,source
        messageCenter.registerApi "getSources",(_,callback)=>
            @sybil.getSources (err,sources)->
                if err
                    console.error err
                    err = "db error"
                callback err,sources
        messageCenter.registerApi "setArchiveDisplayContent",(data,callback)=>
            if not data.content or not data.guid
                callback "invalid parameter"
                return
            @sybil.setArchiveDisplayContent data.guid,data.content,(err,archive)=>
                callback err,archive
        messageCenter.registerApi "getTagArchives",(query,callback)=>
            @sybil.getTagArchives query.name,(err,archives)->
                if err
                    console.error err
                    err = "db error"
                    callback err
                    return
                sort = query.sort or "latest"
                if sort is "sybil"
                    true
                else if sort is "oldest"
                    true
                else
                    # default by latest
                    sortArchive(archives)
                if not query.viewRead
                    archives = archives.filter (item)->not item.hasRead
                console.log query,archives.length
                offset = query.offset or null
                count = query.count or 20
                if offset is null
                    offsetIndex = 0
                else
                    for item,index in archives
                        if item.guid is offset
                            offsetIndex = index+1
                            break
                if not offsetIndex
                    offsetIndex = 0
                callback err,archives.slice(offsetIndex,offsetIndex+count)
        messageCenter.registerApi "getSourceArchives",(query,callback)=>
            @sybil.getSourceArchives query.guid,(err,archives)-> 
                if err
                    console.error err
                    err = "db error"
                sort = query.sort or "latest"
                if sort is "sybil"
                    true
                else if sort is "oldest"
                    true
                else
                    # default by latest
                    sortArchive(archives)
                if not query.viewRead
                    archives = archives.filter (item)->not item.hasRead
                console.log query,archives.length
                offset = query.offset or null
                count = query.count or 20
                if offset is null
                    offsetIndex = 0
                else
                    for item,index in archives
                        if item.guid is offset
                            offsetIndex = index+1
                            break
                if not offsetIndex
                    offsetIndex = 0
                callback err,archives.slice(offsetIndex,offsetIndex+count)
        messageCenter.registerApi "addTagToSource",(data,callback)=>
            if not data.guid or not data.name
                callback "invalid parameter"
                return
            @sybil.addTagToSource data.guid,data.name,(err,item)=>
                callback err,item
        messageCenter.registerApi "removeTagFromSource",(data,callback)=>
            if not data.guid or not data.name
                callback "invalid parameter"
                return
            @sybil.removeTagFromSource data.guid,data.name,(err,item)=>
                callback err,item
        
        messageCenter.registerApi "likeArchive",(guid,callback)=>
            @sybil.likeArchive guid,(err)=>
                callback err
        messageCenter.registerApi "unlikeArchive",(guid,callback)=>
            @sybil.unlikeArchive guid,(err)=>
                callback err
        messageCenter.registerApi "markAllArchiveAsRead",(guid,callback)=>
            @sybil.markAllArchiveAsRead guid,(err)=>
                callback err
        messageCenter.registerApi "markArchiveAsRead",(guid,callback)=>
            @sybil. markArchiveAsRead guid,(err)=>
                callback err
        messageCenter.registerApi "markArchiveAsUnread",(guid,callback)=>
            @sybil.markArchiveAsUnread guid,(err)=>
                callback err
        messageCenter.registerApi "changeArchiveList",(info = {},callback)=>
            @sybil.moveArchiveToList info.id,info.listName,(err)=>
                callback err
        messageCenter.registerApi "unreadLaterArchive",(guid,callback)=>
            @sybil.unreadLaterArchive guid,(err,archive)=>
                callback err,archive
        messageCenter.registerApi "readLaterArchive",(guid,callback)=>
            @sybil.readLaterArchive guid,(err,archive)=>
                callback err,archive
        messageCenter.registerApi "getReadLaterArchives",(_,callback)=>
            @sybil.getReadLaterArchives (err,archives)=>
                callback err,archives
        messageCenter.registerApi "getSourceHint",(uri,callback)=>
            @sybil.getSourceHint uri,(err,available)->
                if err
                    console.error err
                    err = "server error"
                callback err,available
        messageCenter.registerApi "unsubscribe",(guid,callback)=>
            @sybil.unsubscribe guid,(err)->
                callback err
        messageCenter.registerApi "subscribe",(source,callback)=>
            console.log source
            @sybil.subscribe source,(err,available)->
                callback err,available
        messageCenter.registerApi "search",(query,callback)=>
            input = query.input
            count = query.count or 100
            offset = query.offset or 0
            @sybil.search input,(err,archives)->
                console.log "get search result #{archives.length}"
                console.log "return #{offset}:=>#{count}"
                archives = archives.slice(offset,offset+count)
                callback err,archives
        messageCenter.registerApi "share",(guid,callback)=>
            @sybil.shareArchive guid,(err)->
                callback err
        messageCenter.registerApi "unshare",(guid,callback)=>
            @sybil.unshareArchive guid,(err)->
                callback err
        
        messageCenter.registerApi "getFriends",(_,callback)=>
            @sybil.getFriends (err,friends)=>
                callback err,friends
        messageCenter.registerApi "addFriend",(friend,callback)=>
            @sybil.addFriend friend,(err)=>
                callback err
        messageCenter.registerApi "removeFriend",(hash,callback)=>
            @sybil.removeFriend hash,(err)=>
                callback err
        messageCenter.registerApi "moveArchiveToList",(option={},callback)=>
            if not option.guid
                callback "invalid parameter"
                return
            @sybil.moveArchiveToList option.guid,(option.listName or null),(err)=>
                callback err
        messageCenter.registerApi "getShareArchiveByNodeHashes",(data = {},callback)=>
            hashes = data.hashes or []
            option = data.option or {}
            @sybil.getShareArchiveByNodeHashes hashes,option,(err,archives)=>
                callback err,archives
        messageCenter.registerApi "addList",(listName,callback)=>
            @sybil.addList listName,(err,list)=>
                callback err,list
        messageCenter.registerApi "removeList",(listName,callback)=>
            @sybil.removeList listName,(err)=>
                callback err
        messageCenter.registerApi "getLists",(_,callback)=>
            @sybil.getLists (err,lists)=>
                callback err,lists
        messageCenter.registerApi "getList",(name,callback)=>
            @sybil.getLists (err,lists = [])=>
                found = lists.some (list)->list.name is name
                if err or not lists or not found
                    callback "not found"
                    return 
                @sybil.getCustomArchives {properties:{listName:name},viewRead:true},(err,archives)->
                    callback null,{name:"read later",archives:archives}
        messageCenter.registerApi "getSourceStatistic",(guid,callback)=>
            @sybil.getSourceStatistic guid,(err,result)->
                if err
                    callback err
                    return
                callback null,result
    pushReadLater:(archive)->
        @boardCastEvent "readLater",archive
    pushUnreadLater:(archive)->
        @boardCastEvent "unreadLater",archive
    pushArchive:(archive)->
        @boardCastEvent "archive",archive
    pushSource:(source)->
        console.log "push source!!"
        @boardCastEvent "source",source
    pushListChange:(info)->
        @boardCastEvent "archive/listChange",info
    pushFriendAdd:(friend)->
        @boardCastEvent "friend/add",friend
    pushFriendRemove:(friend)->
        @boardCastEvent "friend/remove",friend
    boardCastEvent:(name,info)->
        for mc in @messageCenters
            try
                mc.fireEvent(name,info)
            catch e
                console.error "fail to fire event"
exports.WebApiServer = WebApiServer
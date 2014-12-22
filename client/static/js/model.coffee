App = require("app")
async = require("lib/async")
class Model extends Leaf.Model
    constructor:()->
        super()

Leaf.EventEmitter.mixin Model
class AllSourceCollection extends Leaf.Collection
    constructor:()->
        super()
        @setId "guid"
    sync:(callback = ()-> true)->
        App.messageCenter.invoke "getSources",{},(err,sources = [])=>
            if err
                console.error err
                callback err
                return
            # prevent block
            coherency = 10
            async.eachLimit sources,coherency,((source,done)=>
                @add new Source(source)
                setTimeout (()->done()),0
            ),(err)=>
                callback null
class Source extends Model
    @sources = new AllSourceCollection()
    fields:[
        "name"
        ,"guid"
        ,"unreadCount"
        ,"tags"
        ,"uri"
        ,"collectorName"
        ,"description"
        ,"totalArchive"
        ,"statistic"
        ,"type"
        ,"lastError"
        ,"lastErrorDescription"
        ,"requireLocalAuth"
        ,"requireCaptcha"
        ,"captcha"
        ,"lastUpdate"
        ,"lastFetch"
        ,"panic"
        ,"nextFetchInterval"]
    constructor:(data)->
        super()
        @declare 
        @data = data or {}
        @data.type = "source"
        return Source.sources.add this
    markAllAsRead:(callback = ()->true)->
        App.messageCenter.invoke "markAllArchiveAsRead",@data.guid,(err)=>
            callback(err)
    queryStatisticInfo:(callback=()->true)->
        if @data.statistic
            callback()
            return
        App.messageCenter.invoke "getSourceStatistic",@guid,(err,info)=>
            if err
                callback err
                return
            @data = {
                totalArchive:info.totalArchive or []
                ,statistic:info.statistic or []
            }
            callback(null)
    unsubscribe:(callback = ()->true )->
        App.messageCenter.invoke "unsubscribe",@guid,(err)=>
            if err
                console.error "fail to unsubscribe #{@guid}",err
                callback err
                return
            console.log "unsubscribed #{@name} #{@guid}"
            @destroy()
            callback()
    destroy:()->
        @emit "destroy"
        @isDestroyed = true
    rename:(name,callback = ()->true)->
        @preset "name",name
        App.messageCenter.invoke "renameSource",{guid:@guid,name:name},(err)=>
            if err
                @undo()
            else
                @confirm()
            callback err
    forceUpdate:(callback)-> 
        App.messageCenter.invoke "forceUpdateSource",@guid,(err)=>
            if err
                callback err
                return
            App.messageCenter.invoke "getSource",@guid,(err,source)=>
                console.debug "update source to hehe ",source
                @sets source
                callback(null)
    describe:(description,callback = ()->true)->
        @preset "description",description
        App.messageCenter.invoke "setSourceDescription",{guid:@guid,description:description},(err)=>
            if err
                @undo()
            else
                @confirm()
            callback err
class SourceFolder extends Model
    @loadFolderStore = (callback)->
        App.persistentDataStoreManager.load "sourceFolderConfig",(err,store)->
            callback err,store
    constructor:(data)->
        super()
        @declare ["name","collapse","type","children"]
        @sets data
        @data.type = "folder"
        @data.id = @data.id or Date.now().toString()+Math.random().toString().substring(2,13)
    toJSON:()->
        children = (item.toJSON({filter:["name","guid","uri","type"]}) for item in @children)
        return {
            name:@name
            ,collapse:@collapse
            ,type:"folder"
            ,children:children
        }
            
class Archive extends Model
    @getByCustom = (option,callback)->
        App.messageCenter.invoke "getCustomArchives",option,(err,archives)->
            if err
                callback err
                return
            result =(new Archive(archive) for archive in archives)
            callback null,result

    constructor:(data)->
        super()
        @declare ["name","originalLink","content","displayContent","title","hasRead","star","guid","createDate","sourceGuid","sourceName","like","share","listName","meta"]
        @sets data
        @data.meta = @data.meta or {}
    changeList:(name,callback)->
        console.debug "call change list"
        App.messageCenter.invoke "moveArchiveToList",{guid:@guid,listName:name},(err)=>
            @listName = name
            callback err
    markAsShare:(callback)->
        App.messageCenter.invoke "share",@guid,(err)=>
            if not err
                @share = true
            callback err
    markAsUnshare:(callback)->
        App.messageCenter.invoke "unshare",@guid,(err)=>
            if not err
                @share = false
            callback err
    markAsRead:(callback)->
        App.messageCenter.invoke "markArchiveAsRead",@guid,(err)=>
            if not err
                if not @hasRead
                    @hasRead = true
                    App.modelSyncManager.emit "archive/read",this
            callback err
    markAsUnread:(callback)->
        App.messageCenter.invoke "markArchiveAsUnread",@guid,(err)=>
            if not err
                if @hasRead
                    @hasRead = false
                    App.modelSyncManager.emit "archive/unread",this
            callback err
    likeArchive:(callback)->
        App.messageCenter.invoke "likeArchive",@guid,(err)=>
            if not err
                @like = true
            callback(err)
    unlikeArchive:(callback)->
        App.messageCenter.invoke "unlikeArchive",@guid,(err)=>
            if not err
                @like = false
            callback(err)
    readLaterArchive:(callback)->
        @changeList "read later",(err)=>
            if err
                callback err
                return
            @listName = "read later"
            callback()
    unreadLaterArchive:(callback)->
        if @listName isnt "read later"
            callback "not in read later list"
            return
        @changeList null,(err)=>
            if err
                callback err
                return
            @listName = null
            callback()
    getFirstValidProfile:()->
        if !@meta or !@meta.shareRecords
            return null
        for item in @meta.shareRecords
            console.log item.profile
            if item.profile and item.profile.email and item.profile.nickname
                return {
                    hash:md5(item.profile.email.trim())
                    ,nickname:item.profile.nickname
                }
        return null

class AllArchiveListCollection extends Leaf.Collection
    constructor:()->
        super()
        @setId "name"
        @on "add",(list)=>
            App.modelSyncManager.emit "archiveList/add",list
class ArchiveList extends Model
    @lists = new AllArchiveListCollection()
    @sync = (callback = ->)->
        App.messageCenter.invoke "getLists",{},(err,lists)=>
            if err
                callback err
                return
            lists = lists.map (list)->new ArchiveList(list)
            callback(null,lists)
    @create = (name,callback = ()->true )->
        if not name or not name.trim()
            callback "invalid name"
            return
        App.messageCenter.invoke "createList",name.trim(),(err)->
            if err
                callback err
                return
            return callback null,new ArchiveList({name:name})
    constructor:(data)->
        super()
        @declare ["name","count"]
        @data = data
        @defaults {count:0}
        if not @name
            throw new Error "invalid list data"
        App.modelSyncManager.on "listChange",(info)=>
            if info.from is @name
                @remove new Archive(info.archive)
            else if info.to is @name
                info.archive.listName = @name
                @add new Archive(info.archive)
        return ArchiveList.lists.add this
    getArchives:(option = {},callback)->
        count = option.count or 20
        offset = option.offset or 0
        App.messageCenter.invoke "getList",{name:@name,count:count,offset:offset},(err,listInfo = {})=>
            if not listInfo or not listInfo.archives
                callback err,null
                return
            callback err,listInfo.archives.map (info)-> new Archive info
    delete:(callback)->
        # Not done need for other list
        ArchiveList.list = ArchiveList.list.filter (item)->item isnt this
        callback null
        Model.emit "archiveList/delete",this
    add:(archive)->
        this.count++;
        console.debug @name,"emit add archive"
        @emit "add",archive
    remove:(archive)->
        this.count--;
        @emit "remove",archive
        
        

Model.Source = Source
Model.SourceFolder = SourceFolder
Model.Archive = Archive
Model.ArchiveList = ArchiveList
module.exports = Model
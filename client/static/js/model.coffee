class Source extends Leaf.EventEmitter
    @sources = []
    # create source will add source to Source.sources and check unique
    @createOrUpdate = (data)->
        _source = new Source(data)
        for source in Source.sources
            if source.guid is _source.guid
                source.set(_source)
                return
        Source.sources.push _source
        Model.emit "source/add",_source
        return source
    @getOrCreate = (data)->
        source = @getByGuid(data.guid)
        if source
            return source
        return @createOrUpdate(data)
    @remove = (which)-> 
        for source,index in Source.sources
            if source is which
                Source.sources.splice(index,1)
                which.emit "remove"
                return true
        return false
    @getByGuid = (guid)->
        for source in @sources
            if source.guid is guid
                return source
        return null
    @sync = ()->
        App.messageCenter.invoke "getSources",{},(err,sources = [])=>
            if err
                throw err
            for source in sources
                @createOrUpdate(source)
            
    constructor:(data)->
        super()
        @set(data)
        Model.on "archive",(archive)=>
            if archive.sourceGuid is @guid
                console.debug "archive"
                @unread()
        Model.on "archive/read",(archive)=>
            if archive.sourceGuid is @guid
                @read()
        Model.on "archive/unread",(archive)=>
            if archive.sourceGuid is @guid
                @unread()
    queryStatisticInfo:(callback=()->true)->
        App.messageCenter.invoke "getSourceStatistic",@guid,(err,info)=>
            if err
                callback err
                return
            @totalArchive = info.totalArchive or []
            @statistic = info.statistic or []
            @emit "change"
            callback(null)
    set:(@data)->
        @guid = @data.guid
        @name = @data.name
        @unreadCount = @data.unreadCount
        @tags = @data.tags or []
        @uri = @data.uri
        @collectorName = @data.collectorName
        @description = @data.description
        
        @emit "change"
    toJSON:()->
        return @data
    read:()->
        @unreadCount-- 
        if @unreadCount < 0
            @unreadCount = 0
        @emit "change"
    unread:()->
        @unreadCount++
        @emit "change"
    removeTag:(name,callback)->
        if name not in @tags
            callback "not found"
            return
        App.messageCenter.invoke "removeTagFromSource",{guid:@guid,name:name},(err)=>
            if err
                callback err
                return
            @tags = @tags.filter (item)->item isnt name
            @emit "change"
            Tag.addSource this
            callback null
    unsubscribe:(callback)->
        App.messageCenter.invoke "unsubscribe",@guid,(err)=>
            if err
                console.error "fail to unsubscribe #{@guid}",err
                callback err
                return
            console.log "unsubscribed #{@name} #{@guid}"
            Source.remove(this)
            callback()
    addTag:(name,callback)->
        if name in @tags
            callback "dumplicated tag"
            return
        SybilWebUI.messageCenter.invoke "addTagToSource",{guid:@guid,name:name},(err,source)=>
            if err
                callback err
                return
            if name in @tags
                callback null
                return
            @tags.push name
            @emit "change"
            Tag.addSource this
            callback null
    markAllAsRead:(callback = ()->true)->
        App.messageCenter.invoke "markAllArchiveAsRead",@guid,(err)=>
            callback(err)
    
                
class Config extends Leaf.EventEmitter
    @configs = []
    @load = (callback)->
        App.messageCenter.invoke "getConfig","configIndex",(err,configs)=>
            if err
                throw err
            if not (configs instanceof Array)
                configs = []
            async.map configs,((name,done)=>
                App.messageCenter.invoke "getConfig",name,(err,data)=>
                    if err
                        done err
                    else
                        #  sync db config with local config
                        data = data or {}
                        for item in @configs
                            if item.name is name
                                for prop of data
                                    item.data[prop] = data[prop]
                                return done(null,null)
                        done(null,new Config(name,data))
                ),(err,configs)=>
                    if err
                        if callback
                            callback err
                        else
                            throw err
                    @isReady = true
                    configs = configs.filter (item)->item
                    @configs.push.apply @configs,configs
                    Model.emit "config/ready"
                    if @_saveOnLoad
                        @_saveIndex ()=>
                            @save()
    @save = (name,callback)->
        if not @isReady
            console.debug "won't save #{name} when config not load yet"
            return
        if name
            configsToSave = @configs.filter (item)->item.name is name
        else
            configsToSave = @configs
        # use this tricky logic to save for all or a single config
        # with the same logic (both as array)
        async.each configsToSave,((config,done)=>
            App.messageCenter.invoke "saveConfig",{name:config.name,data:config.toJSON()},(err)->
                done err
            ),(err)=>
                if err
                    if callback
                        callback err
                    else
                        throw err
    @getConfig = (name,defaultConfig)->
        for item in @configs
            if item.name is name
                return item
        if defaultConfig and typeof defaultConfig isnt "object"
            throw "invalid defaultConfig"
        if not @isReady
            @_saveOnLoad = true
        return @createConfig(name,defaultConfig and defaultConfig or {})
    @createConfig = (name,data,callback)->
        if not name
            err = "config need a name"
            if callback
                callback err
            else
                throw err
        if name is "configName"
            err = "invalid config name, conflict with 'configName'"
            if callback
                callback err
            else
                throw err
            return
        for item in @configs
            if item.name is name
                err =  "already exists"
                if callback
                    callback err
                else
                    throw err
                return
        config = new Config(name,data)
        @configs.push config
        @_saveIndex (err)=>
            if err
                if callback
                    callback err
            @save config.name,callback
        return config
    @_saveIndex = (callback)->
        if not @isReady
            if callback
                callback "config not ready"
            return
        App.messageCenter.invoke "saveConfig",{name:"configIndex",data:(item.name for item in @configs)},(err)->
            callback err
            
    constructor:(name,@data = {})->
        @name = name
    toJSON:()->
        return @data
    save:(callback)->
        Config.save @name,callback
    set:(key,value)->
        @data[key] = _.cloneDeep value
        @save()
    get:(key,defaultValue)->
        return (_.cloneDeep @data[key]) or defaultValue
class ArchiveList extends Leaf.EventEmitter
    @lists = []
    @sync = (callback = ->)->
        App.messageCenter.invoke "getLists",{},(err,lists)=>
            if err
                callback err
                return
            for list in lists
                match = @lists.some (item)->
                    return item.name is list.name
                if not match
                    @create list
            callback()
    @create = (data)->
        archive = new ArchiveList(data)
        for list in ArchiveList.lists
            if list.name is name
                throw "already exists"
        ArchiveList.lists.push archive
        console.debug "archiveList add!"
        Model.emit "archiveList/add",archive
    constructor:(@data)->
        super()
        @name = @data.name
        @count = @data.count or 0
        if not @name
            throw "invalid list data"
        Model.on "archive/listChange",(info)=>
            if info.archive.listName is @name
                @remove new Archive(info.archive)
            else if info.listName is @name
                info.archive.listName = @name
                @add new Archive(info.archive)
    getArchives:(callback)->
        App.messageCenter.invoke "getList",@name,(err,listInfo = {})->
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
        @emit "add",archive
    remove:(archive)->
        this.count--;
        @emit "remove",archive
        
        
class Tag extends Leaf.EventEmitter
    @tags = []
    @addSource = (source)->
        if not source.tags or source.tags.length is 0
            Tag.homelessSourceTag.addSource source
            return
        for tagName in source.tags
            hasTag = false
            for tag in @tags
                if tag.name is tagName
                    tag.addSource source
                    tag.emit "change"
                    hasTag = true
                    break
            if not hasTag
                tag =  Tag.create(tagName)
                tag.addSource source
                tag.emit "change"
        Model.emit "tag/change"
    @create:(data)->
        newTag = new Tag(data)
        for tag in Tag.tags
            if tag.name is newTag.name
                return
        Tag.tags.push newTag
        return newTag
    constructor:(name)->
        super()
        @sources = []
        @name = name
    addSource:(_source)->
        for source in @sources
            if source.guid is _source.guid
                return false
        @sources.push _source
        _source.on "change",()=>
            if @name is "untagged" and (not _source.tags or _source.tags.length is 0)
                @emit "change"
                return
            if @name not in _source.tags
                for source,index in @sources
                    if source is _source 
                        @sources.splice(index,1)
                        break
            @emit "change"
        @emit "change"
        return true
class Archive extends Leaf.EventEmitter
    @getFromSource = (option,callback)->
        App.messageCenter.invoke "getSourceArchives",option,(err,archives)->
            if err
                callback err
                return
            result =(new Archive(archive) for archive in archives)
            callback null,result
    @getByTag = (option,callback)->
        App.messageCenter.invoke "getTagArchives",option,(err,archives)->
            if err
                callback err
                return
            result =(new Archive(archive) for archive in archives)
            callback null,result
    @getByCustom = (option,callback)->
        console.debug "send by custom",option
        App.messageCenter.invoke "getCustomArchives",option,(err,archives)->
            console.debug "return by custom",err,archives
            if err
                callback err
                return
            result =(new Archive(archive) for archive in archives)
            callback null,result
    @getByShareHashes = (option = {},callback)->
        App.messageCenter.invoke "getShareArchiveByNodeHashes",{hashes:option.hashes,option:{count:option.count or 30,offset:option.offset or 0}},(err,archives = [])=>
            if err
                callback err
                return
            archives = archives.map (data)->
                return new Archive data
            callback null,archives
    constructor:(@data)-> 
        super() 
        @originalLink = @data.originalLink
        @content = @data.content
        @displayContent = @data.displayContent
        @title = @data.title
        @hasRead = @data.hasRead
        @star = @data.star
        @guid = @data.guid
        @createDate = new Date(@data.createDate) 
        @sourceGuid = @data.sourceGuid
        @sourceName = @data.sourceName
        @like = @data.like
        @share = @data.share
        @listName = @data.listName or null
        @meta = @data.meta or {}
            
    changeList:(name,callback)->
        App.messageCenter.invoke "moveArchiveToList",{guid:@guid,listName:name},(err)->
            callback err
    markAsShare:(callback)->
        App.messageCenter.invoke "share",@guid,(err)=>
            if not err
                @share = true
                @emit "change"
            callback err
    markAsUnshare:(callback)->
        App.messageCenter.invoke "unshare",@guid,(err)=>
            if not err
                @share = false
                @emit "change"
            callback err
    markAsRead:(callback)->
        App.messageCenter.invoke "markArchiveAsRead",@guid,(err)=>
            if not err
                if not @hasRead
                    @hasRead = true
                    Model.emit "archive/read",this
            callback err
    markAsUnread:(callback)->
        App.messageCenter.invoke "markArchiveAsUnread",@guid,(err)=>
            if not err
                if @hasRead
                    Model.emit "archive/unread",this
                    @hasRead = false
            callback err
    likeArchive:(callback)->
        App.messageCenter.invoke "likeArchive",@guid,(err)=>
            if not err
                @like = true
                @emit "change"
            callback(err)
    unlikeArchive:(callback)->
        App.messageCenter.invoke "unlikeArchive",@guid,(err)=>
            if not err
                @like = false
                @emit "change"
            callback(err)
    readLaterArchive:(callback)->
        @changeList "read later",(err)=>
            if err
                callback err
                return
            @listName = "read later"
            @emit "change"
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
            @emit "change"
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
class P2pNode extends Leaf.EventEmitter
    @nodes = []
    @sync = ()->
        App.messageCenter.invoke "getP2pNode",{},(err,nodes)=>
            if err
                return
            # note here we don't filter out node that not return by this call
            for node in nodes
                @addOrUpdate(node)
    @addOrUpdate = (node)->
        # update node if exists
        # create node if not
        if P2pNode.nodes.some((oldNode)=>
            if oldNode.publicKey is node.publicKey
                if node.online
                    oldNode.init node
                else
                    @remove(oldNode)
                return true
            )
            console.debug "find node"
        else
            if node.online 
                P2pNode.add new P2pNode(node)
    @add = (node)->
        @nodes.push node
        Model.emit "node/add",node
    @remove = (node)->
        index = @nodes.indexOf(node)
        if index >= 0 
            @nodes.splice(index,1)
            node.emit "delete"
            Model.emit "node/delete",node
            return node
        return null
    constructor:(data)->
        super()
        @init(data)
    isFriend:()->
        for item in Friend.friends
            if item.publicKey is @publicKey
                return true
        return false
    init:(data)->
        console.debug "create profile",data
        @data = data
        @publicKey = @data.publicKey
        @hash = @data.hash
        @profile = data.profile or {}
        if @profile and @profile.email and not @profile.emailHash
            @profile.emailHash = md5(@profile.email.toString().trim())
        @emit "change",this
class Friend extends Leaf.EventEmitter
    @friends = []
    @sync = ()->
        App.messageCenter.invoke "getFriends",{},(err,friends = [])=>
            if err
                console.debug err,"fail to get friends"
                return
            for friend in friends
                @addOrUpdate friend
    @addOrUpdate = (friend)->
        console.log "get firend data",friend
        if not @friends.some((oldFriend)->
            if oldFriend.hash is friend.hash
                oldFriend.init friend
                return true
            )
            @add new Friend(friend)
    @add = (friend)->
        @friends.push friend
        Model.emit "friend/add",friend
    @removeByHash = (hash)->
        for item,index in @friends
            if item.keyHash is hash
                @friends.splice(index,1)
                return true
        return false
    @remove = (friend)->
        index = @friends.indexOf(friend)
        if index >= 0
            @friends.splice(index,1)
        friend.emit "delete"
        Model.emit "friend/delete",friend
    @addFriendFromNode = (node,callback = ()->true)->
        # I'm not sure if fill information of friend from
        # front end is a good way, but let's do it for now
        console.log "add friend from node"
        info = {keyHash:node.hash,nickname:node.profile.nickname,email:node.profile.email,publicKey:node.publicKey.toString()}
        App.messageCenter.invoke "addFriend",info,(err,friend)->
            callback(err,friend)
    constructor:(data = {})->
        super()
        @init(data)
    init:(@data)->
        @keyHash = @data.keyHash
        @nickname = @data.nickname or "anonymous"
        @email = @data.email or ""
        @emailHash = md5(@email)
        @publicKey = @data.publicKey or ""
        @emit "change",this
        @status = "offline"
        for item in P2pNode.nodes
            if item.publicKey is @publicKey
                @status = "online"
                break
    remove:(callback = ()->true)->
        App.messageCenter.invoke "removeFriend",@keyHash,(err)=>
            if err
                callback err
                return
            Friend.remove this
            callback null
class Workspace extends Leaf.EventEmitter
    @workspaces = []
    @sync = (callback)->
        callback = callback or ()->true
        App.messageCenter.invoke "getCustomWorkspaces",{},(err,workspaces)=>
            if workspaces.length is 0
                @addWorkspace new Workspace {name:"default",members:[]}
            for workspace in workspaces
                @addWorkspace new Workspace(workspace)
            Model.emit "workspace/sync"
            

            callback err
    @addWorkspace = (newWorkspace)->
        has = false
        for workspace in @workspaces
            if workspace.name is newWorkspace.name
                throw "add dumplicated workspace #{workspace.name}"
                has = true
                break
        if not has
            @initWorkspace newWorkspace
    @initWorkspace:(newWorkspace)->
        @workspaces.push newWorkspace
        newWorkspace.on "change",()=>
            Model.emit "workspace/change",newWorkspace
                    
    constructor:(data)->
        super()
        @set(data)
    set:(@data)->
        @name = @data.name
        @members = []
        for item in @data.members
            @members.push WorkspaceMember.fromJSON(item)
        @emit "change"
    add:(member)->
        for item in @members
            if item is member
                return false
        @members.push member
        return member
    remove:(member)->
        for item,index in @members
            if item is member
                @members.splice(index,1)
                return true
        return false
    save:(callback = ()->true)->
        App.messageCenter.invoke "saveCustomWorkspace",{name:@name,data:@toJSON()},(err)->
            if err
                callback(err)
                return
            callback()
    toJSON:()->
        return {name:@name,members:(member.toJSON() for member in @members)}
class WorkspaceMember extends Leaf.EventEmitter
    @fromJSON = (json)->
        if json.type is "source"
            WorkspaceMemberSource.fromJSON(json)
        else if json.type is "group"
            WorkspaceMemberGroup.fromJSON(json)
        else if json.type is "tag"
            WorkspaceMemberTag.fromJSON(json)
    constructor:()->
        super()
        this
class WorkspaceMemberSource extends WorkspaceMember
    constructor:(@data)->
        super()
        @type = "source"
        @guid = @data.guid
        @name = @data.name
        @source = Source.getByGuid @guid
        if @source
            @source.on "change",()=>
                @emit "change"
    @fromJSON = (json)->
        return new WorkspaceMemberSource(json)
    toJSON:()->
        return {type:"source",guid:@guid,name:@name}
    toQuery:()->
        return {
            sourceGuids:[@guid]
            ,tags:[]
        }
class WorkspaceMemberTag extends WorkspaceMember
    @fromJSON = (json)->
        return new WorkspaceMemberTag(json)
    constructor:(info)->
        super()
        @type = "tag"
        @tagName = info.tagName
        @name = @tagName
        @syncTag()
    syncTag:()->
        for tag in Tag.tags
            if tag.name is @tagName
                @tag = tag
                @emit "change"
                return
        @emit "empty"
    toJSON:()->
        return {type:"tag",tagName:@tagName}
    toQuery:()->
        return {
            sourceGuids:[]
            ,tags:[@tagName]
        }
class WorkspaceMemberGroup extends WorkspaceMember
    @fromJSON:(json)->
        group = new WorkspaceMemberGroup(json.name or "untitles")
        for item in json.items or []
            if item.type is "source"
                group.add new WorkspaceMemberSource(item)
            else if item.type is "tag"
                group.add new WorkspaceMemberTag(item)
            else
                throw "contain invalid data #{JSON.stringify(item)}"
        return group
    constructor:(name)->
        super()
        @name = name
        @type = "group"
        @items = []
    add:(member)->
        if not (member instanceof WorkspaceMember)
            throw "member group can only add member or source or tag"
        if member instanceof WorkspaceMemberGroup
            throw "member group can't contain any other group, at least for now"
        @items.push member
    toJSON:()->
        return {
            type:@type
            ,name:@name or "untitled group"
            ,items:(item.toJSON() for item in @items)
        }
    toQuery:()->
        result = {
            sourceGuids:[]
            ,tags:[]
        }
        for item in @items
            query = item.toQuery()
            for sourceGuid in query.sourceGuids
                if sourceGuid not in result.sourceGuids
                    result.sourceGuids.push sourceGuid
            for tag in query.tags
                if tag not in result.tags
                    result.tags.push tag
        return result
Tag.homelessSourceTag = Tag.create("untagged")


Model = new Leaf.EventEmitter
Model.initEventListener = ()->
    App.on "connect",()->
        Model.Workspace.sync()
        Model.ArchiveList.sync()
        Model.P2pNode.sync()
        Model.Source.sync()
        Model.Friend.sync()
        Model.Config.load()
        console.debug "connected"
    App.messageCenter.on "event/source",(source)->
        console.debug "get source event",source
        Model.Source.createOrUpdate(source)
    App.messageCenter.on "event/archive",(archive)->
        Model.emit "archive",new Archive(archive)
    App.messageCenter.on "event/archive/listChange",(info)->
        if not info or not info.archive
            console.error "invalid archive list change event",info
            return
        Model.emit "archive/listChange",info
    App.messageCenter.on "event/node/change",(node)->
        console.log "node change",node
        Model.P2pNode.addOrUpdate node
    App.messageCenter.on "event/friend/add",(friend)->
        Model.Friend.addOrUpdate friend
    App.messageCenter.on "event/friend/remove",(friend)->
        Model.Friend.removeByHash friend.keyHash
Model.on "source/add",(source)->
    Tag.addSource source
Model.on "node/add",(node)->
    for friend in Friend.friends
        if friend.publicKey is node.publicKey
            console.debug "online,=="
            friend.status = "online"
            friend.emit "online"
Model.on "node/delete",(node)->
    for friend in Friend.friends
        console.debug "offline ?",friend.publicKey,node.publicKey
        if friend.publicKey is node.publicKey
            console.debug "offline--"
            friend.status = "offline"
            friend.emit "offline"
    
Model.Tag = Tag
Model.Source = Source
Model.Model = Model
Model.Archive = Archive
Model.Workspace = Workspace
Model.WorkspaceMember = WorkspaceMember
Model.Config = Config
Model.ArchiveList = ArchiveList
Model.P2pNode = P2pNode
Model.Friend = Friend
window.Model = Model

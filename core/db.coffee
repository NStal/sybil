mongodb = require "mongodb"
EventEmitter = (require "events").EventEmitter
async = require "async"
ObjectID = (require "mongodb").ObjectID
config = require("../settings.coffee")
dbServer = new mongodb.Server config.dbHost,config.dbPort,config.dbOption
collectionNames = ["archive","source","workspace","clientConfig","p2pNode","shareRecord","collectorConfig","friend"]

console = require("../common/logger.coffee").create("Database")
dbConnector = new mongodb.Db(config.dbName,dbServer,{safe:false})
module.exports = new EventEmitter()
exports = module.exports
module.exports.isReady = false
Collections = {}
module.exports.Collections = Collections
toBase64 = (string)->
    return new Buffer(string).toString("base64")
toMD5 = (string)->
    return (require "crypto").createHash("md5").update(new Buffer(string)).digest("hex")
    
exports.init = (callback)->
    dbConnector.open (err,db)->
        if err or not db
            console.error "fail to connect to mongodb"
            console.error err
            process.exit(1)
        dbConnector.db = db
        exports.loadCollections collectionNames,(err,collections)->
            if err 
                if callback
                    callback err
                return
            db.collections = collections
            exports.isReady = true
            console.log "db ready"
            exports.emit "ready"
            if callback then callback null
exports.loadCollections = (collectionNames,callback)->
    async.map collectionNames,((collectionName,done)->
        dbConnector.db.collection collectionName,(err,col)->
            if err
                done err
            else
                done null,col
            return true
        ), (err,results)->
            if err
                console.error "fail to prefetch Collections"
                process.exit(1)
                return
            collections = {}
            for name,index in collectionNames
                Collections[name] = results[index]
            callback null,Collections
exports.ready = (callback)->
    if exports.isReady
        callback()
    else
        exports.once "ready",callback
exports.registerCollection = (collectionNames,callback)->
    if not exports.isReady
        callback "not ready"
        return

exports.saveArchive = (archive,callback)->
    if not archive.guid
        callback "archive need a guid"
        return
    archive._id = toMD5(archive.guid)
    archive.hasRead = false
    Collections.archive.insert archive,{safe:true},(err,item)->
        if err
            if err.code is 11000
                callback "duplicate"
            else
                callback err
            return
        if not item.hasRead
            Collections.source.findAndModify {guid:archive.sourceGuid},{},{$inc:{unreadCount:1}},{safe:true},(err,source)-> 
                callback null,item
        else
            callback null,item
    
exports.saveSource = (source,callback)->
    source._id = toMD5 source.guid
    Collections.source.insert source,{safe:true},(err,item)->
        if err
            if err.code is 11000
                callback "duplicate"
            else
                callback err
            return
        callback null,item[0]
exports.removeSource = (guid,callback)->
    Collections.source.remove {guid:guid},{safe:true},(err,item)->
        callback err,item
exports.removeTagFromSource = (guid,tagName,callback)->
    Collections.source.findAndModify {guid:guid},{},{$pull:{tags:tagName}},(err,item)->
        if err
            callback err
            return
        if not item
            callback "not found"
            return
        callback null,item
exports.addTagToSource = (guid,tagName,callback)->
    Collections.source.findAndModify {guid:guid},{},{$push:{tags:tagName}},(err,item)->
        if err
            callback err
            return
        if not item
            callback "not found"
            return
        callback null,item
exports.getSource = (guid,callback)->
    Collections.source.findOne {guid:guid},(err,item)->
        if err 
            callback "db error"
            return
        if not item
            callback "not found"
            return
        callback null,item
exports.getSources = (callback)->
    cursor = Collections.source.find {}
    cursor.toArray (err,arr)->
        if err
            callback err
            return
        callback null,arr
exports.getSourceArchives = (guid,callback)->
    cursor = Collections.archive.find {sourceGuid:guid}
    cursor.toArray (err,arr)->
        if err
            callback err
            return
        callback null,arr
exports.getTagArchives = (name,callback)->
    if name is "untagged"
        cursor = Collections.source.find {$or:[{tags:{$exists:false}},{tags:{$size:0}}]}
    else
        cursor = Collections.source.find {tags:name}
    cursor.toArray (err,arr)->
        if err
            callback err
            return
        ids = (item.guid for item in arr)
        cursor = Collections.archive.find {sourceGuid:{$in:ids}}
        cursor.toArray (err,arr)->
            if err
                callback err
                return
            callback null,arr
            return
exports.updateUnreadCount = (query,callback)->
    cursor = Collections.source.find(query)
    cursor.toArray (err,arr)->
        if err
            callback err
            return
        (require "async").eachSeries arr,((source,done)->
            Collections.archive.find({sourceGuid:source.guid,hasRead:false}).count (err,count)->
                
                Collections.source.update {_id:source._id},{$set:{unreadCount:count}},{safe:true},(err)->
                    done() 
            ),(err)->
                callback err
exports.setArchiveDisplayContent = (guid,content,callback)->
    Collections.archive.findAndModify {guid:guid},{$set:{displayContent:content or null}},{safe:true},(err,archive)->
        callback err,archive
    

exports.getArchiveStream = (callback)->
    stream = new EventEmitter()
    dbStream = Collections.archive.find({}).stream()
    dbStream.on "data",(data)->
        stream.emit "data",data
    dbStream.on "close",(data)->
        stream.emit "close"
    stream.close = ()->
        dbStream.close()
    callback null,stream
    
exports.likeArchive = (guid,callback)->
    Collections.archive.findAndModify {guid:guid},{},{$set:{like:true}},{safe:true},(err,archive)->
        console.log "like archive",archive
        callback err,archive
exports.unlikeArchive = (guid,callback)->
    Collections.archive.update {guid:guid},{$set:{like:false}},{safe:true},(err,archive)->
        callback err,archive
exports.markArchiveAsRead = (guid,callback)->
    Collections.archive.findAndModify {guid:guid,hasRead:false},{},{$set:{hasRead:true}},{safe:true},(err,archive)->
        if err
            callback err
            return
        if not archive
            callback "read archive not found"
            return
        Collections.source.update {guid:archive.sourceGuid},{$inc:{unreadCount:-1}},{safe:true},(err,archive)->
            callback null,archive
exports.markAllArchiveAsRead = (guid,callback)->
    Collections.archive.update {sourceGuid:guid},{$set:{hasRead:true}},{multi:true,safe:true},(err)->
        if err
            callback(err)
            return
        Collections.source.update {guid:guid},{$set:{unreadCount:0}},{safe:true},(err)->
            callback err
exports.markArchiveAsUnread = (guid,callback)->
    Collections.archive.findAndModify {guid:guid,hasRead:true},{},{$set:{hasRead:false}},{safe:true},(err,archive)->
        if err
            callback err
            return
        if not archive
            callback "unread archive not found"
            return
        Collections.source.update {guid:archive.sourceGuid},{$inc:{unreadCount:1}},{safe:true},(err,source)->
            callback null,archive
exports.moveArchiveToList = (guid,listName,callback)->
    if not guid
        callback "move archive to list need a guid"
        return
    Collections.archive.findAndModify {guid:guid},{},{$set:{listName:listName}},{safe:true},(err,archive)=>
        if err
            callback err
            return
        if not archive
            callback "archive not found"
            return
        console.log "modifed in db",guid
        exports._ensureList ()=>
            console.log "ensure list and found ___",found
            found = @archiveList.some (list)->
                if list.name is listName
                    list.count = list.count or 0
                    list.count++
                    return true
                return false
            console.log "ensure list and found",found
            # if has listName we create that list
            if listName and not found
                @archiveList.push {name:listName,count:1}
            found = @archiveList.some (list)->
                if list.name is archive.listName
                    list.count = list.count or 0
                    list.count--;
                    if list.count < 0
                        list.count = 0
                    return true
                return false
            if not found
                # what ever...
                null
            exports._saveLists()
            callback null,archive
exports.getLists = (callback)->
    if @archiveList instanceof Array
        process.nextTick ()=>
            callback null,@archiveList
        return
    exports.getConfig "archiveList",(err,lists)=>
        if err
            callback err
            return
        if not lists or (not (lists instanceof Array))
            lists = [{name:"read later",count:0}]
        @archiveList = lists
        callback null,lists
        
exports._saveLists = ()->
    if not @archiveList instanceof Array
        return
    exports.saveConfig "archiveList",@archiveList,(err)->
        return
exports._ensureList = (callback)->
    console.log "enter ensure list"
    if not @archiveList
        console.log "not archive"
        exports.getLists ()->
            callback()
    else
        console.log "has archvie"
        callback()
exports.addList = (listName,callback)->
    if not listName
        callback "invalid list name"
        return
    exports._ensureList ()=>
        for list in @archiveList
            if list.name is listName
                callback "already exists"
                return
        list = {name:listName,count:0}
        @archiveList.push list
        @_saveLists()
        callback null,list
exports.removeList = (listName,callback)->
    if not listName
        callback "invalid listname"
        return
    exports._ensureList ()=>
        find = @archiveList.some (list,index)->
            if list.name is listName
                @archiveList.splice(index,1)
                exports._saveLists()
                callback(null)
                return true
            return false 
        if not find
            callback "not found"
            return

exports.readLaterArchive = (guid,callback)->
    Collections.archive.findAndModify {guid:guid,$or:[{readLater:false},{readLater:{$exists:false}}]},{},{$set:{readLater:true}},(err,item)->
        if err
            callback err
            return
        if not item
            callback "unread later item not found"
            return
        callback null,item
exports.unreadLaterArchive = (guid,callback)->
    Collections.archive.findAndModify {guid:guid,readLater:true},{},{$set:{readLater:false}},(err,item)->
        if err
            callback err
            return
        if not item
            callback "read later item not found"
            return
        callback null,item
exports.getReadLaterArchives = (callback)->
    cursor = Collections.archive.find({readLater:true})
    cursor.toArray (err,archives)->
        callback err,archives
exports.getCustomWorkspaces = (callback)->
    cursor = Collections.workspace.find {}
    cursor.toArray (err,workspaces)->
        callback err,workspaces
exports.saveCustomWorkspace = (name,data,callback)->
    Collections.workspace.update {name:name},data,{upsert:true,safe:true},(err)->
        callback err
exports.shareArchive = (guid,callback)->
    Collections.archive.findAndModify {guid:guid},{},{$set:{share:true,shareDate:new Date()}},{safe:true},(err)->
        if err
            callback err
            return
        callback()
exports.unshareArchive = (guid,callback)->
    Collections.archive.findAndModify {guid:guid},{},{$set:{share:false}},{safe:true},(err)->
        if err
            callback err
            return
        callback()
exports.getShareArchive = (option={},callback)->
    count = option.count or 50
    cursor = Collections.archive.find {share:true},{limit:count}
    cursor.sort({shareDate:-1,createDate:-1})
    cursor.toArray (err,arr)->
        callback err,arr
exports.getShareArchiveByNodeHashes = (hashes,option = {},callback)->
    cursor = Collections.shareRecord.find {keyHash:{$in:hashes}}
    cursor.toArray (err,records = [])->
        if err
            callback err
            return
        links = records.map (item)->item.originalLink
        query = {sourceGuid:"p2pShare_public",originalLink:{$in:links}}
        if option.unread
            query.hasRead = false
        cursor = Collections.archive.find query
        cursor.toArray (err,arr = [])->
            callback err,arr
            return
exports.getCustomArchives = (query,callback)->
    finalQuery = {$or:[]}
    tagQuery = null
    if query.sourceGuids instanceof Array and query.sourceGuids.length > 0
        finalQuery.$or.push {sourceGuid:{$in:query.sourceGuids}}
    if query.keywords instanceof Array and query.keywords.length > 0
        # Note:check keywords here
        keywords = []
        for word in query.keywords
            if typeof word isnt "string"
                callback "invalid keyword parameter"
                return
            keywords.push new RegExp(word,"i")
        finalQuery.content = {$all: keywords}
    # transform user input directly to RegExp is unsafe
    # think of a better way latter
    # now use this to escape
    # http://stackoverflow.com/questions/3446170/escape-string-for-use-in-javascript-regex
    escapeRegExp = (str)->
      return str.replace(/[\-\[\]\/\{\}\(\)\*\+\?\.\\\^\$\|]/g, "\\$&")
    if query.inurl
        finalQuery.sourceUrl = new RegExp(query.inurl.replace(/\./,"\\."),"i")
    if query.title
        finalQuery.title = new RegExp(escapeRegExp(query.title),"i")
    # Note: I don't know if doing this will introduce any security issue
    # But it's really convinient. Perform some check if it is a problem in future
    if finalQuery.$or.length is 0
        delete finalQuery.$or
    if query.properties
        for prop of query.properties
            finalQuery[prop] = query.properties[prop]
            
    cursor = Collections.archive.find finalQuery,{limit:query.limit or 10000,skip:query.offset or 0}
    # here maybe some performance issue one day
    # but we are designed for single user
    # so it may not be a problem here
    cursor.toArray (err,arr)->
        callback err,arr
exports.getConfig = (name,callback)->
    Collections.clientConfig.findOne {name:name},(err,config)->
        callback err,config and config.data or null
exports.saveConfig = (name,config,callback)->
    Collections.clientConfig.update {name:name},{$set:{data:config}},{upsert:true,safe:true},(err)->
        callback err
# p2p db interface here
exports.saveP2pNode = (node,callback = ()->true)->
    node = new P2pNode(node)
    if not node.check()
        callback "invalid p2pnode"
        return
    Collections.p2pNode.update {hash:node.hash},node.toJSON(),{upsert:true,safe:true},(err)->
        callback err,node
exports.getP2pNodeByHash = (hash,callback)->
    Collections.p2pNode.findOne {_id:hash},(err,item)=>
        if err
            callback err
            return
        if not item
            callback null,null
            return
        callback null,new P2pNode(item).toJSON()
exports.addShareRecord = (record = {},callback)->
    keyHash = record.keyHash
    originalLink = record.originalLink
    Collections.shareRecord.findOne {keyHash:keyHash,originalLink:originalLink},(err,item)->
        if err or not item
            Collections.shareRecord.update {keyHash:keyHash,originalLink:originalLink},record,{upsert:true,safe:true},(err)->
                callback err
        else
            callback "exists"
exports.getShareRecordsByHash = (hash,callback)->
    cursor = Collections.shareRecord.find {hash:hash}
    cursor.toArray (err,array)->
        callback err,array
exports.getShareRecordsByLink = (link,callback)->
    cursor = Collections.shareRecord.find {originalLink:link}
    cursor.toArray (err,array)->
        callback err,array
exports.getShareRecordsByLinks = (links,callback)->
    cursor = Collections.shareRecord.find {originalLink:{$in:links}}
    cursor.toArray (err,array)->
        callback err,array
        
exports.addFriend = (friend,callback)->
    friend = new Friend(friend)
    if not friend.check()
        callback(new Error "invalid friend data")
    Collections.friend.findOne {_id:friend.keyHash},(err,item)=>
        if err
            callback err
            return
        if item
            callback new Error "exists"
            return
        Collections.friend.update {_id:friend.keyHash},friend.toJSON(),{upsert:true},(err)=>
            callback err,friend.toJSON()
exports.getFriends = (callback)->
    Collections.friend.find().toArray (err,friends)->
        callback err,friends
exports.removeFriend = (hash,callback)->
    Collections.friend.remove {keyHash:hash},(err,item)->
        callback err,item


# end p2p db interface
exports.close = ()->
    dbConnector.close()
exports.loadCollectorConfig = (name,callback)->
    Collections.collectorConfig.findOne {name:name},(err,item)=>
        callback(err,item)
exports.saveCollectorConfig = (name,data,callback)->
    Collections.collectorConfig.update {name:name},data,{safe:true,upsert:true},(err)=>
        callback(err)    
# models goes here
#


# Archive is almost the same as /collector/collector.coffee::Archive
# The model in db hold extra user information then the Archive in collector
# such as like hasread tags or list info
class Archive
    constructor:(data)->
        for prop of data
            @[prop] = data[prop]
    toJSON:()->
        json = {
            guid:@guid
            ,collectorName:@collectorName
            ,createDate:@createDate
            ,fetchDate:@fetchDate
            ,authorName:@authorName
            ,authorAvatar:@authorAvatar
            ,authorLink:@authorLink
            ,originalLink:@originalLink
            ,sourceName:@sourceName
            ,sourceUrl:@sourceUrl
            ,sourceGuid:@sourceGuid
            ,title:@title
            ,content:@content
            ,displayContent:@displayContent or null
            ,contentType:@contentType
            ,attachments:@attachments
            ,hasRead:@hasRead
            ,share:@share
            ,tags:@tags or []
            ,like:@like
            ,meta:@meta or {}
            ,listName:@listName or null
        }

class Source extends EventEmitter
    constructor:(data)->
        for prop of data
            @[prop] = data[prop]
    toJSON:()->
        return {
            name:@name
            ,guid:@guid
            ,meta:@meta
            ,uri:@uri
            ,collectorName:@collectorName
            ,unreadCount:@unreadCount or null
        }
class P2pNode
    constructor:(data)->
        for prop of data
            @[prop] = data[prop]
    check:()->
        if not @hash or not @publicKey
            return false
        return true
    toJSON:()->
        return {
            address:@address or null
            ,publicKey:@publicKey.toString()
            ,hash:@hash
            ,lastConnection:new Date(@lastConnection)
            # I may remove profile then add a profile collection in future
            # since it's better to seperate the P2p layer with the application logic
            ,profile:@profile
            ,_id:@hash
        }
class Friend 
    constructor:(data)->
        for prop of data
            @[prop] = data[prop]
    check:()->
        if not @keyHash or not @publicKey or not @nickname or not @email
            return false
        return true
    toJSON:()->
        return {
            keyHash:@keyHash
            ,nickname:@nickname
            ,email:@email
            ,publicKey:@publicKey.toString()
            ,_id:@keyHash
        }            
exports.Archive = Archive
exports.Source = Source

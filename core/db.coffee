mongodb = require "mongodb"
EventEmitter = (require "events").EventEmitter
async = require "async"
ObjectID = (require "mongodb").ObjectID
ErrorDoc = require("error-doc")
config = require("../settings")
console = global.env.logger.create(__filename)
module.exports = new EventEmitter()
exports = module.exports

Errors = ErrorDoc.create()
    .define("Duplication")
    .define("NotReady")
    .define("NotFound")
    .define("InvalidParameter")
    .generate()
exports.Errors = Errors
toMD5 = (string)->
    return (require "crypto").createHash("md5").update(new Buffer(string)).digest("hex")

Collections = {}
collectionNames = ["archive","source","workspace","clientConfig","p2pNode","shareRecord","collectorConfig","friend"]
module.exports.isReady = false
module.exports.Collections = Collections

dbServer = new mongodb.Server config.dbHost,config.dbPort,config.dbOption
dbConnector = new mongodb.Db(config.dbName,dbServer,{safe:false})

exports.init = (callback = ()->)->
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
            callback null
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
        callback new Errors.NotReady()
        return

exports.saveArchive = (archive,callback)->
    if not archive.guid
        callback new Errors.NotFound()
        return
    archive._id = toMD5(archive.guid)
    archive.hasRead = false
    Collections.archive.insert archive,{safe:true},(err,item)->
        if err
            if err.code is 11000
                callback new Errors.Duplication()
            else
                callback err
            return
        if not item.hasRead
            Collections.source.findAndModify {guid:archive.sourceGuid},{},{$inc:{unreadCount:1}},{safe:true},(err,source)->
                callback null,item
        else
            callback null,item
exports.updateSource = (source,callback = ()-> )->
    Collections.source.findAndModify {guid:source.guid},{},{$set:source},{safe:true},(err,doc)->
        if err
            callback err
            return
        callback err,doc

exports.saveSource = (source,callback)->
    source._id = toMD5 source.guid
    Collections.source.insert source,{safe:true},(err,item)->
        if err
            if err.code is 11000
                callback new Errors.Duplication
            else
                callback err
            return
        exports.updateUnreadCount {guid:source.guid},()->
            Collections.source.findOne {guid:source.guid},(err,source)->
                callback err,source
exports.removeSource = (guid,callback)->
    Collections.source.remove {guid:guid},{safe:true},(err,item)->
        callback err,item
exports.removeTagFromSource = (guid,tagName,callback)->
    Collections.source.findAndModify {guid:guid},{},{$pull:{tags:tagName}},(err,item)->
        if err
            callback err
            return
        if not item
            callback new Errors.NotFound()
            return
        callback null,item

exports.addTagToSource = (guid,tagName,callback)->
    Collections.source.findAndModify {guid:guid},{},{$push:{tags:tagName}},(err,item)->
        if err
            callback err
            return
        if not item
            callback new Errors.NotFound()
            return
        callback null,item
exports.getSource = (guid,callback)->
    Collections.source.findOne {guid:guid},(err,item)->
        if err
            callback new Errors.NotFound()
            return
        if not item
            callback new Errors.NotFound()
            return
        callback null,item
exports.getSources = (callback)->
    cursor = Collections.source.find {}
    cursor.toArray (err,arr)->
        if err
            callback err
            return
        callback null,arr

exports.renameSource = (guid,name,callback)->
    Collections.source.findAndModify {guid:guid},{},{$set:{name:name}},{safe:true},(err)->
        callback err
exports.setSourceDescription = (guid,description,callback)->
    Collections.source.findAndModify {guid:guid},{},{$set:{description:description}},{safe:true},(err)->
        callback err
exports.getSourceArchiveCount = (guid,callback)->
    Collections.archive.find({sourceGuid:guid}).count (err,count)->
        callback err,count
exports.getSourceStatistic = (guid,callback)->
    howLong = 30 #30days
    delta = 30 * 24 * 60 * 60 * 1000
    after = new Date(Date.now() - delta)
    cursor = Collections.archive.find({sourceGuid:guid,createDate:{$gte:after}},{createDate:true},{limit:1000})
    cursor.toArray (err,arr)->
        if err
            callback err
            return
        result = []
        for index in [0...30]
            result.push 0
        for item in arr
            secondsOfDay = 24 * 60 * 60 * 1000
            if item.createDate
                result[parseInt((item.createDate.getTime() - after.getTime()) / secondsOfDay)]++
        statistic = result
        exports.getSourceArchiveCount guid,(err,count)->
            if err
                callback err
                return
            callback null,{totalArchive:count,statistic:statistic}
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
exports.updateUnreadCount = (query = {},callback)->
    cursor = Collections.source.find(query)
    cursor.toArray (err,arr)->
        if err
            callback err
            return
        (require "async").eachLimit arr,4,((source,done)->
            Collections.archive.find({sourceGuid:source.guid,hasRead:false}).count (err,count)->

                Collections.source.update {_id:source._id},{$set:{unreadCount:count}},{safe:true},(err)->
                    done()
            ),(err)->
                callback err
exports.setArchiveDisplayContent = (guid,content,callback)->
    Collections.archive.findAndModify {guid:guid},{},{$set:{displayContent:content or null}},{safe:true},(err,archive)->
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
            callback new Errors.NotFound "read archive not found"
            return
        Collections.source.update {guid:archive.sourceGuid},{$inc:{unreadCount:-1}},{safe:true},(err)->
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
            callback new Errors.NotFound "unread archive not found"
            return
        Collections.source.update {guid:archive.sourceGuid},{$inc:{unreadCount:1}},{safe:true},(err,source)->
            callback null,archive
exports.moveArchiveToList = (guid,listName,callback)->
    if not guid
        callback new Errors.InvalidParameter "move archive to list need a guid"
        return
    Collections.archive.findAndModify {guid:guid},{},{$set:{listName:listName,listModifyDate:new Date()}},{safe:true},(err,archive)=>
        if err
            callback err
            return
        if not archive
            callback new Errors.InvalidParameter "archive not found"
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
exports.createList = (listName,callback)->
    if not listName
        callback new Errors.InvalidParameter "invalid list name"
        return
    exports._ensureList ()=>
        for list in @archiveList
            if list.name is listName
                callback new Errors.Duplication()
                return
        list = {name:listName,count:0}
        @archiveList.push list
        @_saveLists()
        callback null,list
exports.removeList = (listName,callback)->
    if not listName
        callback new Errors.InvalidParameter "invalid listname"
        return
    exports._ensureList ()=>
        find = @archiveList.some (list,index)=>
            if list.name is listName
                @archiveList.splice(index,1)
                exports._saveLists()
                callback(null)
                return true
            return false
        if not find
            callback new Errors.NotFound()
            return

exports.readLaterArchive = (guid,callback)->
    Collections.archive.findAndModify {guid:guid,$or:[{readLater:false},{readLater:{$exists:false}}]},{},{$set:{readLater:true,listModifyDate:new Date()}},(err,item)->
        if err
            callback err
            return
        if not item
            callback new Errors.NotFound "unread later item not found"
            return
        callback null,item
exports.unreadLaterArchive = (guid,callback)->
    Collections.archive.findAndModify {guid:guid,readLater:true},{},{$set:{readLater:false}},(err,item)->
        if err
            callback err
            return
        if not item
            callback new Errors.NotFound "read later item not found"
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
exports.getArchiveByGuid = (guid,callback)->
    if not guid
        callback(null,null)
        return
    Collections.archive.findOne {guid:guid},(err,item)->
        callback err,item
exports.getCustomArchives = (query,callback)->
    # NEEEEED refactor...
    console.log "initl",query
    finalQuery = {$or:[]}
    tagQuery = null
    if query.sourceGuids instanceof Array and query.sourceGuids.length > 0
        if query.sourceGuids.length is 1
            finalQuery.$or.push {sourceGuid:query.sourceGuids[0]}
        else
            finalQuery.$or.push {sourceGuid:{$in:query.sourceGuids}}
    if query.keywords instanceof Array and query.keywords.length > 0
        # Note:check keywords here
        keywords = []
        for word in query.keywords
            if typeof word isnt "string"
                callback new Errors.InvalidParameter "invalid keyword parameter"
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
    if not query.viewRead
        finalQuery.hasRead = false
    # Note: I don't know if doing this will introduce any security issue
    # But it's really convinient. Perform some check if it is a problem in future
    if finalQuery.$or.length is 0
        delete finalQuery.$or
    else if finalQuery.$or.length is 1
        for prop of finalQuery.$or[0]
            finalQuery[prop] = finalQuery.$or[0][prop]
        delete finalQuery.$or
    if query.properties
        for prop of query.properties
            finalQuery[prop] = query.properties[prop]
    exports.getArchiveByGuid query.splitter or null,(err,item)=>
        if err
            callback err
            return
        query.sort ?= {createDate:-1}
        if query.splitter and item
            sortFields = Object.keys query.sort
            for field in sortFields
                op = null
                # -1 => 142s 140s 135s
                if query.sort[field] < 0
                    op = "$lte"
                else if query.sort[field] > 0
                    op = "$gte"
                action = {}
                # we only support direct field like archive.createDate
                # NOT nested like archive.author.name.

                action[op] = item[field]
                finalQuery[field] = action


        cursor = Collections.archive.find finalQuery
        cursor.sort query.sort

        limit = query.limit or query.count or 200
        if query.splitter
            limit += 1
        cursor.limit limit

        cursor.skip query.offset or 0
        console.log finalQuery,query,"DBCustom"
        # here maybe some performance issue one day
        # but we are designed for single user
        # so it may not be a problem here
        items = []
        # to avoid some one has the createDate same with splitter
        # to be droped, I have to $gte not $gt
        # so I will manually filter it myself.
        # But make count +1
        cursor.toArray (err,arr)->
            # remove splitter
            console.log query.count,"and actually",
            if query.splitter
                for item,index in arr
                    if item.guid is query.splitter
                        arr.splice(index,1)
                        break
            console.log finalQuery,err,arr and arr.length or null,"???"
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
        callback new Errors.InvalidParameter "invalid p2pnode"
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
            callback new Errors.Duplication
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

# Archive is almost the same as /collector/collector::Archive
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
            ,description:@description or null
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

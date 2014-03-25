# this is the entry of sybil
console = require("../common/logger.coffee").create("Core")
class Sybil extends (require "events").EventEmitter
    Database = require("./db.coffee")
    constructor:()->
        Collector = require "../collector/collector.coffee"
        @collectorClub = new Collector.CollectorClub()
        @pluginCenter = new (require "./pluginCenter.coffee").PluginCenter(this)
        @settingManager = new (require("./settingManager.coffee")).SettingManager()
        @archiveProcessQueue = (require "async").queue(@handleArchive.bind(this),1)
        @initTasks = new (require "node-tasks")("dbInit","collectorInit")
    init:()->
        # 1.load global settings
        # 2.init database connection
        # 3.init collectors
        # 4.init plugins (won't check)
        @settings = require("../settings.coffee")
        settingPath = @settings.pluginSettingsPath or require("path").join(__dirname,"../settings/")
        @settingManager.setDefaultSettingFolder settingPath
        fs = require("fs")
        if not fs.existsSync(settingPath)
            fs.mkdirSync(settingPath)
        @collectorClub.on "archive",(archive)=>
            #console.log "archive",archive.guid
            @archiveProcessQueue.push archive
        @collectorClub.once "ready",()=>
            @initTasks.done("collectorInit")
        Database.init()
        Database.ready ()=>
            @initTasks.done("dbInit")
            # now collectors rely on db model
            collectors = @settings.collectors
            for name in collectors
                @collectorClub.addAndStart(name)
        @initTasks.on "done",()=>
            @emit "init"
            @pluginCenter.loadPlugin.apply @pluginCenter,@settings.plugins or ["webApi","#externalProxy","#runtimeShell","p2p","resourceProxy"]
            
    # here comes all the sybil apis
    handleArchive:(archive,done)->
        # make sure it's not a nested object
        # ... OK may not enough
        if archive.toJSON and typeof archive.toJSON is "function"
            archive = archive.toJSON()
        if not Database.isReady
            console.error "Fatal, can't handle archive when database is not ready"
            setTimeout (()=>
                @archiveProcessQueue.push archive
                done()
                ),1000
            return false
        Database.saveArchive archive,(err,saved)=> 
            if err and err isnt "duplicate"
                console.error "db error",err,"fail to save archive",archive.guid
                done()
                return
            else if err and err is "duplicate"
                #console.debug "duplicated"
                done()
                return
            console.debug "new archive",archive.title
            @emit "archive",archive
            done()
    # though this functions perform just like
    # interact with db directly
    # but will make some difference in the future
    getConfig:(name,callback)->
        Database.getConfig name,(err,config)->
            callback err,config
    saveConfig:(name,config,callback)->
        if not name
            callback "invalid config"
            return
        Database.saveConfig name,config,(err)->
            callback err
    getSource:(guid,callback)->
        Database.getSource guid,(err,source)->
            callback err,source
    getSources:(callback)->
        Database.getSources (err,sources)->
            callback err,sources
    renameSource:(guid,name,callback)->
        Database.renameSource guid,name,(err)->
            callback err
    setSourceDescription:(guid,description,callback)->
        Database.setSourceDescription guid,description,(callback)->
            callback err
    getSourceStatistic:(guid,callback)->
        Database.getSourceStatistic guid,(err,result)->
            callback err,result
    getSourceArchives:(guid,callback)->
        Database.getSourceArchives guid,(err,archives)=>
            @completeArchivesMeta archives,(err,archives)=>
                callback err,archives
    getTagArchives:(name,callback)->
        Database.getTagArchives name,(err,archives)=>
            @completeArchivesMeta archives,(err,archives)=>
                callback err,archives
    getSourceHint:(uri,callback)->
        @collectorClub.testURI uri,(err,available)->
            callback err,available
    setArchiveDisplayContent:(guid,content,callback)->
        Database.setArchiveDisplayContent guid,content,(err,archive)->
            callback err,archive
    likeArchive:(guid,callback)->
        Database.likeArchive guid,(err,archive)->
            callback err,archive
    unlikeArchive:(guid,callback)->
        Database.unlikeArchive guid,(err,archive)->
            callback err,archive
    shareArchive:(guid,callback)->
        Database.shareArchive guid,(err,archive)=>
            if not err
                @emit "share",archive
            callback err,archive
    unshareArchive:(guid,callback)->
        Database.unshareArchive guid,(err)->
            callback err
    getShareArchiveByNodeHashes:(hashes,option,callback)->
        Database.getShareArchiveByNodeHashes hashes,option,(err,archives)->
            callback err,archives
    getShareArchive:(option,callback)->
        Database.getShareArchive option,(err,archives)=>
            @completeArchivesMeta archives,(err,archives)=>
                callback err,archives
    markAllArchiveAsRead:(sourceGuid,callback)->
        Database.markAllArchiveAsRead sourceGuid,(err)->
            callback err
    markArchiveAsRead:(guid,callback)->
        Database.markArchiveAsRead guid,(err,archive)->
            callback err,archive
    markArchiveAsUnread:(guid,callback)->
        Database.markArchiveAsUnread guid,(err,archive)->
            callback err,archive
    addTagToSource:(guid,tag,callback)->
        Database.addTagToSource guid,tag,(err,item)->
            callback err,item
    removeTagFromSource:(guid,tag,callback)->
        Database.removeTagFromSource guid,tag,(err,item)->
            callback err,item
    moveArchiveToList:(archiveGuid,listName,callback)->
        console.log "start move archive",archiveGuid,listName
        Database.moveArchiveToList archiveGuid,listName,(err,archive)=>
            console.log "move",archiveGuid,listName
            @emit "archive/listChange",{archive:archive,listName:listName}
            callback err
    getLists:(callback)->
        Database.getLists (err,lists)->
            callback err,lists
    addList:(listName,callback)->
        Database.addList listName,(err,list)->
            callback err,list
    removeList:(listName,callback)->
        Database.removeList listName,(err)->
            callback err
    readLaterArchive:(guid,callback)->
        Database.readLaterArchive guid,(err,archive)=>
            @emit "readLater",archive
            callback err,archive
    unreadLaterArchive:(guid,callback)->
        Database.unreadLaterArchive guid,(err,archive)->
            @emit "unreadLater",archive
            callback err,archive
    getReadLaterArchives:(callback)->
        Database.getReadLaterArchives (err,archives)=>
            if err
                callback err
                return
            @completeArchivesMeta archives,(err,archives)=>
                callback err,archives
    getCustomArchives:(query,callback)->
        Database.getCustomArchives query,(err,archives)=>
            @completeArchivesMeta archives,(err,archives)=>
                callback err,archives
    subscribe:(source,callback)->
        @collectorClub.subscribe source.uri,source.name,(err,source)=>
            if err and err isnt "duplicated"
                callback err
                return
            if source
                source = source.toJSON()
                Database.saveSource source,(err,_)=>
                    if err
                        callback err
                        return
                    Database.updateUnreadCount {guid:source.guid},(err)=>
                        Database.getSource source.guid,(err,source)=>
                            callback err,source
                            @emit "source",source
            else
                callback "programmer error"
    unsubscribe:(guid,callback)->
        @collectorClub.unsubscribe guid,(err)=>
            Database.removeSource guid,callback
    getCustomWorkspaces:(callback)->
        Database.getCustomWorkspaces (err,workspaces)->
            callback err,workspaces
    saveCustomWorkspace:(name,data,callback)->
        Database.saveCustomWorkspace name,data,(err)->
            callback err
    completeArchivesMeta:(archives,callback)->
        links = archives.map (archive)->archive.originalLink
        Database.getShareRecordsByLinks links,(err,records)->
            if err
                callback err
                return
            for archive in archives 
                archive.meta = archive.meta or {}
                archive.meta.shareRecords = archive.meta.shareRecords or []
                for record in records
                    if record.originalLink is archive.originalLink
                        archive.meta.shareRecords.push record
            callback null,archives
    getFriends:(callback)->
        Database.getFriends (err,friends)->
            callback err,friends
    addFriend:(friend,callback)-> 
        Database.addFriend friend,(err,friend)=>
            if not err
                @emit "friend/add",friend
            callback err
    removeFriend:(hash,callback)->
        Database.removeFriend hash,(err,friend)=>
            if not err and friend
                @emit "friend/remove",friend
            callback err,friend
    search:(query,callback)->
        # search is a key feature and complicated work
        # The performance is considered as an important factor
        # thus it's hard to build seperately with database
        # which means I will directly interact with database(mongodb)
        # and change algorithem when database changed
        if typeof query isnt "string"
            callback "invalid query type"
            return
        conditions = (require "../common/searchQueryParser").parse(query)
        keywords =(word.value for word in  conditions.filter (item)->item.type is "keyword")
        inurl = null
        title = null
        for c in conditions
            if c.type is "inurl"
                inurl = c.value
            if c.type is "title"
                title = c.value
        Database.getCustomArchives {keywords:keywords,inurl:inurl,title:title},(err,archives)->
            # scoring
            archives.forEach (archive)->
                score = (archive.fetchDate or new Date()).getTime()
                modifier = 1
                if archive.like
                    modifier++
                if archive.share
                    modifier++
                archive.score = score * modifier
            archives.sort (a,b)->
                return b.score - a.score
            callback(err,archives)


sybil = new Sybil()
sybil.init()
sybil.on "init",()->
    Database = require "./db.coffee"
    Database.updateUnreadCount {},(err)->
        if err
            console.error err
            return
        console.log "sync unread count"
        # sync db and collectors
        sources = sybil.collectorClub.getSources()
        Database.getSources (err,dbSources)=>
            console.log "sync db with collectors"
            if err
                throw err
            (require "async").each dbSources,((dbSource,done)=>
                for source in sources 
                    if source.guid is dbSource.guid
                        done()
                        return
                console.log "add missing source #{dbSource.guid}"
                sybil.collectorClub.subscribe dbSource.uri,dbSource.collectorName,(err)=>
                    if err
                        console.log "fail to sync source",dbSource
                    console.log "force sync source",dbSource.name
                    done()
                ),(err)=>
                    sybil.isReady = true
                    console.log "sybil is ready"
                    sybil.emit "ready"
        
#    sybil.subscribe {uri:"http://revlonpc.blog.fc2.com/?xml",name:"rss"},(err,hints)=>
#        if err and err isnt "duplicated"
#            console.error err
#            return
#        if err and err is "duplicated"
#            console.error "duplicated"
#        console.log hints
process.title = "sybil"
process.on "uncaughtException",(err)->
    console.error err
    console.error err.stack
    console.error "fatal error"
    if not sybil.settings.preventCrash
        console.error "uncaughtException not acceptable"
        console.error "exit"
        process.exit(1)
module.exports = sybil
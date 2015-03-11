# this is the entry of sybil
console = require("../common/logger.coffee").create(__filename)
pathModule = require "path"
fs = require("fs")

# Setup some global vars to prevent relative requires
# which is hard to manipulate, but also be careful don't
# introduce too many of them.
# setup global environments
require "./env.coffee"

CollectorController = require "./collectorController.coffee"
Collector = require "../collector/collector.coffee"
class Sybil extends (require "events").EventEmitter
    Database = require("./db.coffee")
    constructor:()->
        @sourceList = require "../collector/sourceList.coffee"
        @collector = new Collector()
        @collector.setCustomSourceFolder pathModule.join global.env.root,"customSources"
        @collectorController = new CollectorController(@collector)
        @pluginCenter = new (require "./pluginCenter.coffee").PluginCenter(this)
        @pluginSettingManager = new (require("./settingManager.coffee")).SettingManager()
        @archiveProcessQueue = (require "async").queue(@handleArchive.bind(this),1)
        @collectorController.on "archive",(archive)=>
            @archiveProcessQueue.push archive
        @collectorController.on "subscribe",(source)=>
            console.log "subscribe source",source
            @emit "source",source
    init:()->

        @initTasks = new (require "node-tasks")("init/db","init/collector","init/plugins")
        # some dirty works here
        # 1. load global settings
        # 2. init database connection
        # 3. init collectors
        # 4. init plugins (won't check)
        # and
        # 5. listen events.

        @settings = global.env.settings

        @pluginSettingManager.setDefaultSettingFolder @settings.pluginSettingsPath
        if not fs.existsSync(@settings.pluginSettingsPath)
            fs.mkdirSync(settings.pluginSettingsPath)
        # 2.
        Database.init()
        Database.ready ()=>
            @initTasks.done("init/db")
            @emit "database/ready"
            # 3.
            @collectorController.initCollector ()=>
                @initTasks.done "init/collector"
            # 4.
            @pluginCenter.loadPlugins @settings.plugins or ["webApi"],(err)=>
                @initTasks.done "init/plugins"
        @initTasks.on "done",()=>
            @emit "init"
            @isReady = true
            @emit "ready"

    handleArchive:(archive,done)->
        # make sure it's a serialized
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
            if err and not (err instanceof Database.Errors.Duplication)
                console.error "db error",err,"fail to save archive",archive.guid
                done()
                return
            else if err and err instanceof Database.Errors.Duplication
                #console.debug "duplicated"
                done()
                return
            console.debug "new archive",archive.title
            @emit "archive",archive
            done()

    # though most of these functions perform just like
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
            delete source.properties
            callback err,source
    getSources:(callback)->
        Database.getSources (err,sources)->
            for source in sources
                delete source.properties
            callback err,sources
    renameSource:(guid,name,callback)->
        Database.renameSource guid,name,(err)->
            callback err
    setSourceDescription:(guid,description,callback)->
        Database.setSourceDescription guid,description,(err)->
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
        Database.markArchiveAsUnread guid,(err,archive)=>
            callback err,archive
            if err
                console.error err
            if not err and archive
                @emit "unread",{guid:guid,sourceGuid:archive.sourceGuid}
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
            @emit "archive/listChange",{archive:archive,listName:listName,to:listName,from:archive.listName}
            callback err
    getLists:(callback)->
        Database.getLists (err,lists)->
            callback err,lists
    createList:(listName,callback)->
        Database.createList listName,(err,list)->
            callback err,list
    removeList:(listName,callback)->
        Database.removeList listName,(err)->
            callback err
    readLaterArchive:(guid,callback)->
        Database.readLaterArchive guid,(err,archive)=>
            @emit "readLater",archive
            callback err,archive
    unreadLaterArchive:(guid,callback)->
        Database.unreadLaterArchive guid,(err,archive)=>
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
            @completeArchivesMeta archives or [],(err,archives)=>
                callback err,archives
    completeArchivesMeta:(archives = [],callback)->
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
    search:(query,option,callback)->
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
        Database.getCustomArchives {viewRead:true,keywords:keywords,inurl:inurl,title:title},(err,archives)->
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

process.title = "sybil"
process.on "uncaughtException",(err)->
    console.error err
    console.error err.stack
    console.error "fatal error"
    if not sybil.settings.preventCrash
        console.error "uncaughtException not acceptable"
        console.error "quit"
        # Usually we wait the stderr to be flushed and then quit the program.
        # To flush it, we write a "exit" string to it and wait
        # this string to be flushed, which also indicates that
        # all previous content has been flushed.
        process.stderr.write "exit",()->
            process.exit(1)
        # on the other hand, in case the fs is blocked, thus blocked the program to exit,
        # we force it to exit after some time, to prevent broken data.
        setTimeout (()->
            process.exit(1)
            ),1000
module.exports = sybil

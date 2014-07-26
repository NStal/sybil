# Define Collector Interface
# Collector is config model NOT a job model
# when it's collecting it make create job for it's children
# but when interact we only setup configs for a collector
EventEmitter = (require "events").EventEmitter;
sybilSettings = require "../settings.coffee"
console = require("../common/logger.coffee").create("Collector")
class Collector extends EventEmitter
    constructor:()->
        super()
    loadConfig:()->
# Collector themselves do the hard job
# handle the crappy net work connection and bad policies
# thus their logic is quite heavy and varies.
# So we have a manager here that tring to build
# a more friendly and uniform way to interact with collector.
# And there for reduce the further burden of collector's logic code.
class CollectorManager extends EventEmitter
    constructor:(@collector)->
        super()
        @collector.on "archive",(item)=>
            @emit "archive",item
        @collector.on "ready",()=>
            @collector.start()
            @ready = true
            @emit "ready"
    start:()->
        @collector.start()
    stop:()->
        @collector.stop()
    subscribe:(info,callback)->
        callback "not implemented"
        return
    unsubscribe:(info,callback)->
        callback "not implemented"
        return
    getSources:()->
        return
    info:(query)->
        return
    # test if the URI can be collector by this manager
    testURI:(uri,callback)->
        callback null,[]
        return
# CollectorClub just hold all collector and emit or dispatch event to their manager
class CollectorClub extends EventEmitter
    constructor:()->
        @managers = []
    addAndStart:(name,callback)->
        if name[0] is "#"
            console.log "skip collector #{name}"
            if callback then callback(null)
            return
        try
            someCollector = require("./#{name}.coffee")
        catch e
            console.error e
            console.error e.stack
            throw new Error "Collector #{name} not exists"
        collector = new someCollector.Collector(name)
        manager = new someCollector.Manager(collector)
        @addManager(manager)
    addManager:(manager)->
        manager.on "archive",(archive)=>
            @emit "archive",archive
        manager.on "ready",()=>
            # fire ready when every body is ready
            # that means it maybe fire several times if
            # a new manager is added after other managers
            # have been ready
            for item in @managers
                if not item.ready
                    return
            @emit "ready"
        @managers.push manager
    getSources:()->
        sources = []
        for manager in @managers
            _sources = manager.getSources()
            sources.push.apply sources,_sources
        return sources
    subscribe:(uri,name,callback)->
        target = null
        for manager in @managers
            if manager.name is name
                target = manager
                break
        if not target
            callback new Error "collector not found"
            return
        target.subscribe uri,(err,source)->
            callback err,source
    unsubscribe:(guid = "",callback)->
        target = null
        name = guid.substring(0,guid.indexOf("_"))
        for manager in @managers
            if manager.name is name
                target = manager
                break
        if not target
            callback new Error "collector not found"
            return
        target.unsubscribe guid,(err)->
            callback err
    testURI:(uri,callback)->
        (require "async").map @managers,((manager,done)-> 
            manager.testURI uri,(err,availables)->
                console.log "testURI result #{manager.name} #{err}"
                if err
                    done(null,null)
                    return
                if not availables
                    done(null,null)
                else
                    console.log availables
                    done(null,({name:manager.name,uri:_uri} for _uri in availables))
            ),(err,result)->
                if err
                    callback err
                    return
                result = result.filter (item)->item
                results = []
                for _ in result
                    if _ instanceof Array
                        results.push.apply results,_
                    else
                        results.push _
                callback null,results
                
# Config is designed to be a temperory storage object
# for collector to store configs like social accounts, RSS source
# It load data from presistance storage, and save to them when exits.
# When collector change data in config, it change the data SYNC and then
# returns immediately and after that invoke async call
# to save data to real storage media(db,fs whatever).
# So the storage is not promised to be reached
# But it should provide a save method with a callback to make sure it's stored.
# 
# get method should always copy the data.
# If needed, may provide a getReference method to return reference.
#
# UPDATE: it's hard to writeFile async because when write process stop on middle of the writing
# the file is broken, so I use sync method to fake async callback
class Config extends EventEmitter
    constructor:(@name)->
        super()
        @data = {}
    load:(callback)->
        return
    save:(callback)->
        return
    get:()->
        return
    set:()->
        return
Database = require("../core/db.coffee")
class MongodbStorageConfig extends Config
    mongodb = require "mongodb"
    dbClient = mongodb.MongoClient
    constructor:(@name)->
        super @name
        @collectionName = "collectorConfig"
        @data = {}
        @delayTime = 300
        @_delaySaveCallbacks = []
    load:(callback = ()->true )->
        if not Database.isReady
            callback "database not ready"
            return
        Database.loadCollectorConfig @name,(err,data)=>
            if err
                callback err
                return
            @data = data or {}
            callback null,@data
        
    _delaySave:(callback = ()->true)->
        @_delaySaveCallbacks.push callback
        clearTimeout @_delayTimer
        @_delayTimer = setTimeout (()=>
            callbacks = @_delaySaveCallbacks
            @_delaySaveCallbacks = []
            @_save (err)=>
                for callback in callbacks
                    callback(err)
            ),@delayTime
    save:(callback = ()->true)->
        @_delaySave(callback)
    _save:(callback = ()->true )->
        if not Database.isReady
            callback "database not ready"
            return
        Database.saveCollectorConfig @name,@data,(err)=>
            callback err
            return
    set:(key,value)->
        helper = require "./helper.coffee"
        @data[key] = helper.clone(value)
        @save()
    get:(key,fallback)->
        helper = require "./helper.coffee"
        return helper.clone(@data[key]) or fallback or null
    setReference:(key,value)->
        @data[key] = value
        @save()
    getReference:(key,fallback)->
        if @data[key]
            return @data[key]
        else
            @data[key] = fallback or null
            @save()
        return @data[key]

class FileStorageConfig extends Config
    @configFolder = "./configs/"
    constructor:(@name)->
        super(@name) 
        path = require "path"
        @configPath = path.join FileStorageConfig.configFolder,@name+".config.json"
        @data = {}
    load:(callback)->
        fs = require "fs"
        isExists = fs.existsSync @configPath
        if not isExists
            @saveSync()
            callback null,{}
            return
        fs.readFile @configPath,(err,data)=>
            if err
                # IO error but exists
                # This must be something bad
                callback err
                return
            try
                result = JSON.parse(data.toString())
            catch e
                error = new Error("Parse Error")
                error.code = "Bad Config"
                callback error
                return
            @data = result
            callback null,result
    saveSync:()->
        fs = require "fs"
        fs.writeFileSync @configPath,JSON.stringify((@data or {}),null,4)
    save:(callback)->
        @saveSync()
        if callback
            callback()
        return
        fs = require "fs"
        fs.writeFile @configPath,JSON.stringify(@data or {},null,4),(err)->
            if err
                if callback
                    callback err
                console.error err
                console.debug "fail to write config"
                return
    set:(key,value)->
        helper = require "./helper.coffee"
        @data[key] = helper.clone(value)
        process.nextTick ()=>
            @save()
    get:(key)->
        helper = require "./helper.coffee"
        return helper.clone(@data[key])
    setReference:(key,value)->
        @data[key] = value
        process.nextTick ()=>
            @save()
    getReference:(key)->
        return @data[key]

# Archive properties
# metas:
# @guid           how to refer to this archive
# @collectorName  which collector get this 
# @createDate     when was the archive  originally created by it's author
# @fetchDate      when was the archive get fetched
# @authorName     the author name of the archive
# @authorAvatar   the author avatar
# @authorLink     link point to the author ,usually a  httplink
# @originalLink   link point to the archive say http://weibo/username/mid or http://blog.com/1234/
# @sourceName     where do we get it "weibo","www.someblog.com"
# @sourceUrl      link point to the source
# @sourceGuid     which source create you?
# 
# content:
# @content        the content of the archive
# @contentType    html/text/image/audio
# @attachments    attachments, maybe images
# @searchable     the pure text part that used in search of this archive
class Archive
    validate:()->
        if @createDate and not @createDate instanceof Date
            return false
        if @fetchDate and not @fetchDate instanceof Date
            return false
        if not @content and not @title
            return false
        if not @sourceGuid
            return false
        if @invalid
            return false
        return true
    toJSON:()->
        return {
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
            ,displayContent:@displayContent
            ,searchable:@searchable and @searchable.toString() or @content
            ,contentType:@contentType
            ,attachments:@attachments
            ,meta:@meta or null
        }

class Source extends EventEmitter
    constructor:()->
    	super()
    toJSON:()->
        return {
            name:@name
            ,guid:@guid
            ,meta:@meta
            ,uri:@uri
            ,collectorName:@collectorName
            ,unreadCount:@unreadCount or null
        }
                
exports.Source = Source    
exports.Collector = Collector
exports.CollectorManager = CollectorManager
exports.CollectorClub = CollectorClub
exports.CollectionConfig = MongodbStorageConfig
exports.Archive = Archive

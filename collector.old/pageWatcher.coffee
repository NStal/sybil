Collector = require("./collector.coffee")
FeedParser = require "feedparser"
EventEmitter = (require "events").EventEmitter
Iconv = (require "iconv").Iconv
helper = require "./helper.coffee"
phantom = require "./phantom.coffee"
sybilSettings = require "../settings.coffee"
class PagePartArchive extends EventEmitter
    constructor:(@data,watcher)->
        @title = null
        @content = @data.html
        @contentType = "html"
        @createDate = new Date()
        @guid = @data.guid or (require "crypto").createHash("md5").update(@content).digest("hex")
        @collectorName = "pageWatcher"
        @originalLink = @data.url
        @sourceName = @data.sourceName or null
        @sourceUrl = @data.url
        @sourceGuid = watcher.guid
    load:(callback)->
        callback(null,this)
class PageWatcher extends EventEmitter
    constructor:(@raw,@option = {})->
        @uri = (raw.uri or "").trim()
        if @uri.indexOf("rwp://") isnt 0
            throw "not a valid uri"
        try
            infoBase64 = @uri.substring(6)
            @info = @raw.info or JSON.parse(unescape(new Buffer(infoBase64,"base64").toString()))
        catch e
            throw "not a valid uri"
        @url = @info.url
        @guid = "pageWatcher_#{@uri}"
        @minInterval = @option.minInterval or 1 * 1000 #* 60
        @maxInterval = @option.maxInterval or 12 * 60 * 60 * 1000 
        @failCount = parseInt(@raw.failCount) or 0
        @fetchFrequency = @raw.fetchFrequency or 1
        @lastUpdate = new Date(@raw.lastUpdate)
        @nextInterval = @raw.nextInterval or 0
        @lastArchiveIds = @raw.lastArchiveIds or []
        @isStop = true
    
    save:()->
        @raw.uri = @uri
        @raw.info = @info
        @raw.url = @url
        @raw.fetchFrequency = @fetchFrequency or 1
        @raw.nextInterval = @nextInterval
        @raw.failCount = @failCount or 0
        @raw.lastUpdate = @lastUpdate.getTime() or 0
        @raw.lastArchiveIds = @lastArchiveIds or []
        @emit "configUpdate"
    start:()->
        if not @isStop
            return
        @isStop = false
        work = (callback)=>
            if @isStop
                return
            @fetch (err)=>
                if err
                    @increaseInterval()
                    @state = "fail"
                setTimeout work,@nextInterval
        work()
    increaseInterval:()->
        if @nextInterval < @minInterval
            @nextInterval = @minInterval
        else
            @nextInterval = Math.min @maxInterval,@nextInterval*2
        @save()
    decreaseInterval:()->
        @nextInterval = Math.max @minInterval,@nextInterval/2
        if @nextInterval < @minInterval
            @nextInterval = @minInterval
        @save()
    stop:()->
        clearTimeout @timer
        @isStop = true
    check:(callback)->
        ids = @lastArchiveIds.slice(0)
        @fetch (err,updates,problem)=>
            @lastArchiveIds = ids
            if err or updates.length is 0
                callback(err or "fail to find content")
                return
            callback()
    fetch:(callback)->
        run = false
        phantom.html @info.url,(err,content)=>
            if err
                callback err
                return
            $ = require "jquery"
            problem = []
            try
                page = $(content.toString())
            catch e
                callback "fail to parse html",e
                return
            page.find(@info.containerPath)
            containers = page.find(@info.containerPath)
            if containers[@info.index]
                container = containers[@info.index]
            else
                container = containers[0]
            if not container
                callback "container not found"
                return
            childrenQueries = @info.childrenPathes.map (item)=>
                return item.replace(@info.containerPath,"").substring(2)
            children = []
            childrenQueries.forEach (query)=>
                $(container).find(query).each ()->
                    children.push this
            children = children.map (item)->item.outerHTML
            archives = (new PagePartArchive({html:html,url:@info.url},this) for html in children)
            hasUpdate = false
            for archive in archives
                if archive.guid not in @lastArchiveIds
                    hasUpdate = true
                    @lastArchiveIds.push archive.guid
                    @emit "archive",archive
            if hasUpdate
                @decreaseInterval()
            else
                @increaseInterval()
                    
            callback null,archives,problem
    toJSON:()->
        return {
            @uri
        }
    
        
class PageWatcherCollector extends Collector.Collector
    constructor:(name)->
        super
        @name = name or "pageWatcher"
        @config = new Collector.CollectionConfig(@name)
        @watchers = []
        @watchOption = {}
        @config.load (err)=>
            if err
                throw err
                return
            @_init()
    _init:()->
        @config.set("name",@name)
        @watchOption.proxy = sybilSettings.get "proxy"
        @watchOption.maxInterval = 12 * 60 * 60 * 1000
        @watchOption.minInterval = 1 * 60 * 1000
        watchers = @config.get("watchers",[])
        for watcher in watchers
            try
                watcher = new PageWatcher(watcher)
                # attach some extra info here
                @watchers.push watcher
            catch e
                console.error "If I get here there must be some broken information in watcher data base, say incompatible rwp protocol"
        @emit "ready"
    startWatcher:(watcher)->
        watcher.on "configUpdate",()=>
            @config.save()
        watcher.on "archive",(archive)=>
            @emit "archive",archive
        watcher.start()
    start:()->
        for watcher in @watchers
            @startWatcher(watcher)
    stop:()->
        for watcher in @watchers
            watcher.stop()
    addAndStartWatcherByURI:(uri,callback)->
        for item in @watchers
            if uri is item.uri
                callback "duplicated",item
                return
        watcher = new PageWatcher({uri:uri})
        watcher.check (err)=>
            if err
                if callback
                    callback err
                return
            @config.getReference("watchers",[]).push watcher.raw
            @watchers.push watcher
            @startWatcher(watcher)
            watcher.save()
            callback null,watcher
        
class PageWatcherManager extends Collector.CollectorManager
    constructor:(@collector)->
        super @collector
        @name = @collector.name
    _watcherToSource:(watcher)->
        source = new Collector.Source()
        info = watcher.info or {}
        source.name = info.name or info.title or info.url
        source.collectorName = @name
        source.guid = watcher.guid
        source.uri = watcher.uri
        source.meta = {}
        return source
    getSources:()->
        return (@_watcherToSource(watcher) for watcher in @collector.watchers)
    subscribe:(uri,callback)->
        @collector.addAndStartWatcherByURI uri,(err,watcher)=>
            if watcher
                callback err,@_watcherToSource(watcher)
            else
                callback err
    unsubscribe:(guid,callback)->
        uri = guid.replace "#{@name}_",""
        found = false
        @collector.watchers.filter (item)=>
            if item.uri is uri
                found = true
                item.stop()
                _watchers = @collector.config.getReference("watchers",[])
                for info,index in _watchers
                    if info.uri is _watchers.uri
                        _watchers.splice(index,1)
                        break
                return false 
            return true
        if found
            @collector.config.save()
            callback()
            return
        callback "not found"
    testURI:(uri,callback)->
        if uri.indexOf("rwp://") isnt 0
            callback "invalid uri"
            return
        watcher = new PageWatcher({uri:uri})
        watcher.check (err)->
            console.log "check result..."
            callback err
        
# Rss hold rss information
# say update frequency, encoding, error count
# and history/logs
exports.Collector = PageWatcherCollector
exports.Manager = PageWatcherManager
exports.PageWatcher = PageWatcher
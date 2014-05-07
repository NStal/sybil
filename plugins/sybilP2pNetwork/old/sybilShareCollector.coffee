EventEmitter = require("events").EventEmitter
Collector = require("../../collector/collector.coffee")
Timer = require("../../common/timer.coffee")
console = require("../../common/logger.coffee").create("P2p/SybilShareCollector")
Database = require("../../core/db.coffee")
Collector = require("../../collector/collector.coffee")
sybil = require("../../core/sybil.coffee")

class SybilShareCollectorManager extends Collector.CollectorManager
    constructor:(@collector)->
        super(@collector)
        @sourceInfo = {
            name:"public p2p shares"
            ,guid:"p2pShare_public"
            ,meta:null
            ,uri:"sybil://p2p/public"
            ,collectorName:"p2pShare"
        }
        @collector.start()
        # make share there are a p2p share collection
        Database.getSource "p2pShare_public",(err,source)=>
            if not source
                Database.saveSource @sourceInfo,(err)=>
                    @ready = true
                    @emit "ready"
                    return
                return
            @ready = true
            @emit "ready"
    testURI:(uri,callback)->
        callback null,[]
    getSource:()->
        return [@sourceInfo]
class SybilShareCollector extends Collector.Collector
    constructor:()->
        super()
        @nodes = []
        @isStart = true
        sybil.on "share",()=>
            console.debug "Fire share event"
            for node in @nodes
                node.messageCenter.fireEvent "sybilReader/share",{}
    start:()->
        @isStart = true
        for node in @nodes
            if node.collectorWorker
                node.collectorWorker.start()
    stop:()->
        @isStart = false
        for node in @nodes
            if node.collectorWorker
                node.collectorWorker.isStop()
    addNode:(node)->
        node.collectorWorker = new CollectorWorker(node)
        node.collectorWorker.on "archive",(archive)=>
            @emit "archive",archive.toJSON()
        node.collectorCleanup = ()=>
            node.removeListener "close",node.collectorCleanup
            node.collectorWorker = null
            @nodes = @nodes.filter (item)->
                return item isnt node
        node.on "close",node.collectorCleanup
        if @isStart
            node.collectorWorker.start(0)
        else
            node.collectorWorker.stop()
        @nodes.push node
    removeNode:(node)->
        if node not in @nodes
            return
        node.release()
        node.collectorCleanup()
    
# collector worker
# 1. fetch share at certain rate
# 2. if no updates then lower the rate util the max interval
# 3. if has updates then higher the rate util min interval
# 4. hold the updated archives originalLink. By doing so, the first time
#    I won't be able to know if there are any updates
#    but second time, I will. To maintain an acceptable
#    fetch rate, it's enough. The duplicate problem will be handled
#    at upper layer
class CollectorWorker extends EventEmitter
    constructor:(node)->
        @node = node
        @close = @close.bind(this)
        @node.on "close",@close
        @timer = new Timer()
        @timer.setMin(1000 * 60 * 5)
        @timer.setMax(1000 * 60 * 60 * 2)
        @timer.setInterval(1000 * 15)
        @archiveLinks = []
        @maxCheckArchiveLength = 400
        @timer.on "tick",()=>
            @queryShare()
        # I can be informed to query a share
        @node.messageCenter.on "event/sybilReader/share",()=>
            console.debug "recieve share event"
            @queryShare()
    start:(delay = 0)->
        # nolonger use timer
        return
        if delay > 0
            @timer.startAfter(delay)
        else
            @timer.resume()
    stop:()->
        @timer.pause()
    queryShare:()->
        if @isQuery
            return
        if @isClose
            return
        @isQuery = true
        console.log "query shares from #{@node.address.toString()}"
        console.log "current timer is #{@timer.interval}"
        @node.messageCenter.invoke "sybilReader/getShare",{},(err,archives)=>
            @isQuery = false
            if err
                return
            if archives instanceof Array
                archives.reverse()
            else
                archives = []
            hasNewArchive = false
            for data in archives
                try
                    archive = new P2pArchive(data)
                catch e
                    continue
                if archive.originalLink not in @archiveLinks
                    hasNewArchive = true
                    @archiveLinks.unshift archive.originalLink
                    record = new ShareRecord(@node,archive)
                    do (archive,record)=>
                        Database.addShareRecord record.toJSON(),(err)=>
                            if not err
                                @emit "archive",archive
                                return
                            if err is "exists"
                                return
                            console.error err
            if @archiveLinks.length > @maxCheckArchiveLength
                @archiveLinks = @archiveLinks.slice(0,parseInt(@maxCheckArchiveLength/2))
            if hasNewArchive
                @timer.shorter(1.5)
            else
                @timer.longer(1.5)
    close:()->
        if @isClose
            return
        @node.removeListener "close",@close
        @isClose = true
        @timer.stop()
        @stop()
        @emit "close"
class ShareRecord
    constructor:(node,archive)->
        @archive = archive
        @node = node
    toJSON:()->
        return {
            originalLink:@archive.originalLink
            ,keyHash:@node.publicKey.getHash()
            ,date:new Date()
            ,profile:@node.profile
        }
class P2pArchive extends Collector.Archive
    constructor:(@data)->
        super()
        @title = @data.title
        @content = @data.content
        @contentType = @data.contentType
        @createDate = @data.createDate or new Date()
        @fetchDate = new Date()
        @collectorName = "p2pShare"
        @authorName = @data.authorName or null
        @authorAvatar = @data.authorAvatar or null
        @authorLink = @data.authorLink or null
        @originalLink = @data.originalLink or null
        @sourceName = "p2pShare"
        @sourceUrl = @data.sourceUrl
        @sourceGuid = @data.sourceGuid
        @meta = @data.meta or {}
        if not @data.originalLink
            @isValid = false
            throw new Error "archive has no originalLink"
        @guid = "p2pShare_"+@data.originalLink
        @sourceGuid = "p2pShare_public"
        if not @content and not @title
            throw new Error "archive has no title and content"
    
module.exports = SybilShareCollector
module.exports.Manager = SybilShareCollectorManager
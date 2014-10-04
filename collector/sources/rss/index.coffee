Source = require "../../source/source.coffee"
rssUtil = require "./rssUtil.coffee"
Tasks = require "node-tasks"
global.env.settings
EventEmitter = (require "events").EventEmitter
console = global.env.logger.create(__filename)
#Errors = errorDoc.create()
#    .inherit rssUtil.Errors
#    .generate()
#exports.Errors = Errors

class RSS extends Source
    @detectStream = (uri)->
        stream = new EventEmitter()
        tasks = new Tasks("checkAsRss","checkAsHTML")
        sources = []
        @detectAsHTML uri,(err,result)=>
            result = result or []
            result.forEach (item)->
                stream.emit "data",item
            tasks.done "checkAsHTML"
        @detectAsRss uri,(err,result)=>
            if result
                stream.emit "data",result
            tasks.done "checkAsRss"
        tasks.once "done",()=>
            stream.emit "end"
        return stream
    @detectAsHTML = (uri,callback)->
        rssUtil.detectRssEntry uri,(err,links)->
            if err
                callback err
                return
            result = links.map (link)->
                return new RSS {uri:link}
            callback null,result
    @detectAsRss = (uri,callback)->
        rssUtil.fetchRss {uri:uri,noQueue:true},(err,info)->
            if err
                callback err
                return
            source = new RSS {uri:uri}
            source.initializer.setInitializeInfo(info)
            callback null,source
    @create = (info)->
        return new RSS(info)
    constructor:(info)->
        super(info)
        @type = "rss"
        @properties = {}
        @authorized = true
        @authorizeInfo = null
        @hasError = null

class Updater extends Source::Updater
    constructor:(@source)->
        super(@source)
    fetchAttempt:()->
        console.debug "try fetching rss: #{@source.guid} at #{@nextFetchInterval}"
        rssUtil.fetchRss {uri:@source.uri},(err = null,info = {})=>
            if err
                @error new Source.Errors.NetworkError("fail to fetch archive for #{@source.guid}")
                return
            @rawFetchedArchives = info.archives or []
            @setState "fetchAttempted"
    parseRawArchive:(raw)->
        if not raw.guid and not raw.link and not raw.title
            throw new Error("no guid provide for archve")
        return result = {
            title:raw.title
            ,content:raw.description
            ,contentType:"html"
            ,createDate:raw.date or new Date()
            ,fetchDate:new Date()
            ,guid:"rss_" + raw.guid || raw.link || raw.title
            ,type:"rss"
            ,collectorName:"rss"
            ,authorName:raw.author
            ,originalLink:raw.link
            ,sourceName:@source.name
            ,sourceGuid:@source.guid
            ,sourceUrl:@source.uri
            ,meta:{}
        }

class Initializer extends Source::Initializer
    constructor:(@source)->
        super(@source)
        @initialized = @source.guid?
    atInitializing:()->
        rssUtil.fetchRss {uri:@source.uri},(err,info)=>
            if err
                @error new Source.Errors.NetworkError("fail to fetch initialize info for rss #{@source.uri}")
                return
            @setInitializeInfo info
    setInitializeInfo:(info)->
        @source.name = info.name
        @source.guid = "rss_"+@source.uri
        @source.updater.prefetchArchiveBuffer = info.archives or []
        @initialized = true
        @setState "initialized"
    
# we currently don't support rss auth
# so just don't implement it
class Authorizer extends Source::Authorizer
    constructor:(source)->
        super(source)
RSS::Updater = Updater
RSS::Initializer = Initializer
RSS::Authorizer = Authorizer

module.exports = RSS
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
        if not /(http:\/\/)|(https:\/\/)|(feed:\/\/)/.test uri
            return null
        stream = new EventEmitter()
        tasks = new Tasks("checkAsRss","checkAsHTML")
        sources = []
        @detectAsHTML uri,(err,result)=>
            result = result or []
            result.forEach (item)->
                stream.emit "data",item
            console.debug "as html done"
            tasks.done "checkAsHTML"
        @detectAsRss uri,(err,result)=>
            if result
                stream.emit "data",result
            console.debug "as rss done"
            tasks.done "checkAsRss"
        tasks.once "done",()=>
            console.debug "really done!"
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
        timeout = 20 * 1000
        rssUtil.fetchRss {uri:uri,noQueue:true,timeout:timeout},(err,info)->
            if err
                callback err
                return
            source = new RSS {uri:uri}
            #source.initializer.setInitializeInfo(info)
            callback null,source
    @create = (info)->
        return new RSS(info)
    constructor:(info)->
        super(info)
        @type = "rss"
        @properties = {}

class Updater extends Source::Updater
    constructor:(@source)->
        super(@source)
    atFetching:(sole)->
        console.debug "try fetching rss: #{@source.guid} at #{@nextFetchInterval}"
        rssUtil.fetchRss {uri:@source.uri},(err = null,info = {})=>
            @_fetchHasCheckSole = true
            if not @checkSole sole
                return
            if err
                @error new Source.Errors.NetworkError("fail to fetch archive for #{@source.guid}")
                return
            @data.rawFetchedArchives = info.archives or []
            @setState "fetched"
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
            ,author:{
                name:raw.author
            }
            ,originalLink:raw.link
            ,sourceName:@source.name
            ,sourceGuid:@source.guid
            ,sourceUrl:@source.uri
            ,meta:{}
        }

class Initializer extends Source::Initializer
    constructor:(@source)->
        super(@source)
        @data.initialized = @source.guid?
    atInitializing:(sole)->
        rssUtil.fetchRss {uri:@source.uri},(err,info)=>
            if not @checkSole sole
                return
            if err
                @error new Source.Errors.NetworkError("fail to fetch initialize info for rss #{@source.uri}")
                return
            @setInitializeInfo info
    setInitializeInfo:(info)->
        @data.name = info.name
        @data.guid = "rss_"+@source.uri
        @data.prefetchArchiveBuffer = info.archives or []
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

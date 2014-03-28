Collector = require("./collector.coffee")
FeedParser = require "feedparser"
EventEmitter = (require "events").EventEmitter
Iconv = (require "iconv").Iconv
helper = require "./helper.coffee"
httpUtil = require "../common/httpUtil.coffee"
sybilSettings = require "../settings.coffee"
console = require("../common/logger.coffee").create("CollectorRSS")
timeout = 10 * 1000;
class RssArchive extends Collector.Archive
    constructor:(@data,rss)->
        super()
        @title = @data.title
        @content = @data.description
        @contentType = "html"
        @createDate = new Date(@data.date)
        @fetchDate = new Date()
        if not @data.guid
            throw new Error "no guid"
            @invalid = true
        if not @content and not @title
            throw new Error "archive has no title and content"
        @guid = "rss_"+@data.guid
        @collectorName = "rss"
        @authorName = @data.author
        @originalLink = @data.link
        @sourceName = rss.name
        @sourceUrl = rss.url
        @sourceGuid = "rss_"+rss.url
    load:(callback)->
        # load image or something
        callback(null,this)
# Rss hold rss information
# say update frequency, encoding, error count
# and history/logs
class Rss extends EventEmitter
    # not use for now
    # but these encodings are known to be (must be) supported
    @validEncoding = ["utf-8","gb2312","utf8","gbk","gb18030","bg5"]
    constructor:(@raw,option={})->
        @name = @raw.name or "unfetched"
        @url = @raw.url
        if not @url
            throw new Error "Rss information need url"
        # state can be "uncheck","check","fail","hang"
        # uncheck: we don't check it yet
        # check: we have validate it last time
        # fail: we fail to check it last time due to 'their' fault
        # hang: we fail to check it due to my fault,
        #       this only happens when my proxy is not available
        #       maybe it's down or my proxy code is wrong
        #       or GFW is upgraded
        # 
        @state = @raw.state or "uncheck"
        @encoding = @raw.encoding or null
        @failCount = parseInt(@raw.failCount) or 0
        @description = @raw.description or null
        @fetchFrequency = @raw.fetchFrequency or 1
        @lastUpdate = new Date(@raw.lastUpdate)
        @lastArchiveIds = @raw.lastArchiveIds or []
        @lastError = @raw.lastError
        @option = option
        @proxy = @option.proxy or null
        @minInterval = @option.minInterval or 2 * 60 * 1000
        @maxInterval = @option.maxInterval or 12 * 60 * 60 * 1000 
        @nextInterval = @raw.nextInterval or 0
        @isStop = true
    start:()->
        @isStop = false
        if @timer
            throw "If you get here, it means there are timer for fetch instance loop not cleared when start a rss fetch instance. And this must be something wrong."
        # for uncheckd/invalid rss we do a initialize check
        # When it's not checked, it may be fail/hang last time
        # or newly added rss.
        # whatever it is we give it a change to prove herself 
        check = (callback)=>
            @check (err)=>
                if not err
                    @state = "checked"
                    callback()
                    return
                switch err
                    when "invalid url","not available","invalid xml","invalid rss"
                        @state = "fail"
                        callback()
                    when "proxy not available"
                        @state = "hang"
                        callback()
                        console.debug "proxy not available"
                    else throw "unexpect error when check rss validation, if you see it, your code is incorrect"
            return
        work = (callback)=>
            @fetch (err)=>
                if err
                    # something is wrong
                    @increaseInterval()
                    @state = "fail"
                # if everything goes right
                # @fetch will handle the interval correctly
                callback()
        
        next = ()=>
            if @isStop
                clearTimeout @timer
                @timer = null
                return
            if @state isnt "checked"
                check ()=>
                    if @state is "checked"
                        next()
                    else
                        @increaseInterval()
                        @timer = setTimeout next,@nextInterval
            else
                work ()=>
                    # no matter it success or fail
                    # leave it to next round
                    @timer = setTimeout next,@nextInterval
        
        if @state isnt "checked"
            # it's checked last time
            # run next to check immediately
            next()
        else
            # in future we will calculate the interval from next fetch
            # and using nextInterval to minus that
            # but not now
            @timer = setTimeout next,0
            
            
    useProxy:()->
        @needProxy = true
    # check will automatically setup informations
    check:(callback)->
        if @url.indexOf("http://") isnt 0 and @url.indexOf("https://") isnt 0
            callback("invalid url")
            return
        httpUtil.httpGet {url:@url,timeout:timeout},(err,res,body)=>
            if err
                console.debug "check fail #{@url} #{err.toString()} now through proxy #{@proxy}"
                httpUtil.httpGet {url:@url,proxy:@proxy,timeout:timeout},(_err,_res,body)=>
                    if _err
                        if _err is "target not available"
                            callback("not available")
                        else
                            console.error _err
                            callback("proxy not available")
                        return
                    else
                        @useProxy()
                    checkRes _res,body
                return
            checkRes res,body
        checkRes = (res,body)=>
            bodyBuffer = body
            body = body.toString().trim()
            firstLine = body.substring(0,body.indexOf(">")).trim()
            if firstLine.indexOf("<?xml") isnt 0 and firstLine.indexOf("<rss") isnt 0
                callback("invalid xml")
                return
            encodingReg = /encoding=\"[0-9a-z]+\"/ig
            match = firstLine.match encodingReg
            console.log match,res.headers["content-type"]
            if not match
                if res.headers["content-type"] and res.headers["content-type"].toLowerCase().indexOf("charset=") > 0
                    contentType = res.headers["content-type"].toLowerCase()
                    for item in contentType.split(";")
                        if not item
                            continue
                        kv = item.split("=")
                        if kv[0].trim() is "charset"
                            @encoding = kv[1]
                            
                # else if res.headers["content-type"] and res.headers["content-type"].indexOf("")
                # add detect latter
                # but this is less reliable than the xml declare
                # since most rss generator handles xml correctly
                if not @encoding
                    @encoding = "utf-8"
            else
                @encoding = match[0].replace("encoding=\"","").replace("\"","").toLowerCase()
            console.log @encoding,"~~~"
            if @encoding in ["gbk","gb2312"]
                @encoding = "gb18030"
            if @encoding not in ["utf-8","utf8"]
                try 
                    data = (new Iconv(@encoding,"utf-8//TRANSLIT//IGNORE")).convert(bodyBuffer)
                catch e
                    console.error e,"at",@url
                    console.error "fail to decode with with #{@encoding}"
                    callback("invalid encoding")
                    return
            else
                data = bodyBuffer
            parser = new FeedParser()
            parser.on "meta",(meta)=>
                @updateMeta(meta)
            archives = []
            parser.on "readable",()=>
                while data = parser.read()
                    archives.push(data)
                return
            parser.on "error",()=>
                callback("invalid rss")
            parser.on "end",()=>
                callback(null,archives)
            parser.write(data)
            parser.end()
    fetch:(callback)->
        option = {url:@url,timeout:timeout}
        if @needProxy
            option.proxy = @proxy
        httpUtil.httpGet option,(err,res,body)=>
            if err
                callback err
                return 
            if @encoding and @encoding not in ["utf8","utf-8"]
                try
                    converter = new Iconv(@encoding,"utf8//TRANSLIT//IGNORE")
                    bodyString = converter.convert(body).toString("utf8")
                catch e
                    console.error e
                    console.error "fail to encode with",@url
                    callback "encoding error"
                    return
            else
                bodyString = body.toString("utf8")
            @handleRssBody bodyString,(err)=> 
                callback err
    handleRssBody:(body,callback)->        
        archiveIds = []
        articles = []
        lastUpdate = new Date()
        parser = new FeedParser()
        parser.on "meta",(meta)=>
            @updateMeta meta
        
        parser.on "readable",()=>
            while article = parser.read()
                articles.push article
        parser.on "error",(err)->
            callback err
        parser.on "end",()=>
            noUpdates = true
            for article,index in articles
                try 
                    archive = new RssArchive(article,this)
                catch e
                    console.error e
                    console.debug "Invalid archive",article
                    continue
                if noUpdates and archive.guid not in @lastArchiveIds
                    noUpdates = false
                if article.date and article.date.getTime() > @lastUpdate.getTime()
                    # buffer latest in this fetch
                    if article.date.getTime() > lastUpdate.getTime()
                        lastUpdate = article.date
                archiveIds.push archive.guid
                archive.load (err,item)=>
                    if err
                        console.error err 
                        console.error "Archive load error I haven't write any test here, if you see this message, this is a good chance to complete the correct error handle logic. Basically, it may fail due to sina.com is down or network error but event it fails to load, it can still be a quite complete archive, I'd still emit a 'archive' event."
                    if item and item.validate()
                        @emit "archive",item 
                    else
                        throw new Error "Invalid Archive, if saidly we get here, it indicates that the program logic is wrong, if we get correct data the archive should always be valid, so either the broken raw data get passed our poor validation check, or the RssArchive constructor are wrong the data is: #{JSON.stringify(item.toJSON(),null,4)}"
                        
            if noUpdates
                @increaseInterval()
            else
                @decreaseInterval()
            if @lastUpdate.getTime() < lastUpdate.getTime()
                @lastUpdate = lastUpdate
                @save()
            if archiveIds.length > 0
                @lastArchiveIds = archiveIds
            callback()
        parser.end(body)
    stop:()->
        # not the stop isnt really stop
        # the request the is on the way will not be aborted
        # and call start imediately after stop
        # may cause issue , don't do it
        if @timer
            clearTimeout @timer
            @timer = null
        @isStop = true
    updateMeta:(meta)->
        @name = meta.title
        @description = meta.description
        @save()
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
    save:()->
        @raw.encoding = @encoding
        @raw.url = @url
        @raw.state = @state
        @raw.name = @name
        @raw.description = @description
        @raw.fetchFrequency = @fetchFrequency or 1
        @raw.nextInterval = @nextInterval
        @raw.failCount = @failCount or 0
        @raw.lastUpdate = @lastUpdate.getTime() or 0
        @raw.lastArchiveIds = @lastArchiveIds or []
        @raw.needProxy = @needProxy
        @raw.lastError = @lastError
        @emit "configUpdate"
    toJSON:()->
        json = {}
        json.encoding = @encoding
        json.url = @url
        json.state = @state
        json.name = @name
        json.descript = @description
        json.fetchFrequency = @fetchFrequency
        json.failCount = @failCount or 0
        return json

class RssCollector extends Collector.Collector
    constructor:(name)->
        super()
        @name = name or "rss"
        @config = new Collector.CollectionConfig(@name)
        @rsses = []
        @config.load (err)=>
            if err
                throw err
                return
            @_init()
        @rssOption = {}
    getRssInformationByUrl:(link)->
        for rss in @rsses
            if rss.url is link
                return rss.toJSON()
    startRss:(rss)->
        rss.on "configUpdate",()=>
            @config.save()
        rss.start()
        rss.on "archive",(item)=>
            @emit "archive",item.toJSON()
    addAndStartRssByLink:(link,callback)->
        for rss in @rsses
            if rss.url is link
                callback "duplicated",rss
                return
        rssInfo = {url:link}
        rss = new Rss(rssInfo,@rssOption)
        rss.check (err,archives)=>
            if err
                if callback then callback err 
                return
            @config.getReference("rsses",[]).push(rssInfo)
            @rsses.push rss
            @config.save()
            @startRss(rss)
            count=0
            for archive,index in archives
                try 
                    rssArchive = new RssArchive(archive,rss)
                catch e
                    console.error e
                    console.debug "Invalid archive",archive
                    callback "broken archive"
                    return
                @emit "archive",rssArchive
                count++
            callback(null,rss,count)
        # note we only accept xml link by now
        # not able to auto detect rss
    _init:()->
        @config.set("name","rss")
        @rssOption.proxy = sybilSettings.get "proxy"
        @rssOption.maxInterval = 12 * 60 * 60 * 1000
        @rssOption.minInterval = 2 * 60 * 1000
        rsses = @config.getReference("rsses",[])
        for rss in rsses
            try
                @rsses.push new Rss(rss,@rssOption)
            catch e
                console.error "If get here, it's likely that the rss information is broken, please check configs"
        @emit "ready"

    start:()->
        for rss in @rsses
            @startRss rss
    
    stop:()->
        for rss in @rsses
            rss.stop()

class RssCollectorManager extends Collector.CollectorManager
    constructor:(@collector)->
        super(@collector)
        @name = @collector.name
    _rssToSource:(rss)->
        source = new Collector.Source()
        source.name = rss.name or rss.url
        source.guid = "rss_"+rss.url
        source.collectorName = "rss"
        source.uri = rss.url
        source.meta = rss.toJSON()
        return source
    getSources:()->
        sources = []
        for rss in @collector.rsses
            sources.push @_rssToSource(rss)
        return sources
    subscribe:(uri,callback)->
        @collector.addAndStartRssByLink uri,(err,rss,count)=>
            # may err and rss both exists
            # when it's duplicated
            if rss
                result = @_rssToSource rss
                callback err,result
            else
                callback err
    unsubscribe:(guid,callback)->
        url = guid.replace "#{@name}_",""
        found = false
        @collector.rsses = @collector.rsses.filter (rss)=>
            if rss.url is url
                rss.stop()
                found = true
                _rsses = @collector.config.getReference("rsses",[])
                for info,index in _rsses
                    if info.url is url
                        _rsses.splice(index,1)
                        break
                return false
            return true
        if found
            @collector.config.save()
            callback()
            return
        callback "not found"
    testURI:(uri,callback)->
        availables = []
        Tasks = require "node-tasks"
        tasks = new Tasks("checkAsRss","checkAsHTML")
        tasks.on "done",()->
            result = []
            availables.forEach (uri)->
                if uri not in result
                    result.push uri
            callback(null,result)
        try
            rss = new Rss({url:uri},{proxy:sybilSettings.get "proxy"})
        catch e
            tasks.done("checkAsRss")
        rss.check (err)->
            if not err
                availables.push uri
            tasks.done("checkAsRss")
        $ = require "jquery"
        testAsHTML = (res,content,_callback)->
            try
                html = $(content.toString())
                links = html.find("link").filter () -> this.rel is "alternate" and (this.type is "application/rss+xml" or this.type is "application/atom+xml")
#                for item in html.find("link")
#                    console.log "LINK:",item.rel,item.type
#                for link in links
#                    console.log link.rel,link.type

                availables.push.apply availables,((require "url").resolve(uri,link.href) for link in links)
            catch e
                
                null
                #console.log "fail to test as html"
                #console.log e

            _callback()
        httpUtil.httpGet {url:uri,noQueue:true,timeout:timeout},(err,res,content)->
            if err or not content
                httpUtil.httpGet {url:uri,noQueue:true,timeout:timeout,proxy:sybilSettings.get "proxy"},(err,res,content)->
                    if err or not content
                        tasks.done("checkAsHTML")
                        return
                    testAsHTML res,content,()->
                        tasks.done("checkAsHTML")
                return
            testAsHTML res,content,()->
                tasks.done("checkAsHTML")

exports.RssCollector = RssCollector
exports.Collector = RssCollector
exports.Manager = RssCollectorManager
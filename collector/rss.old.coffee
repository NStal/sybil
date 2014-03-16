Collector = require("./collector.coffee")
FeedParser = require "feedparser"
EventEmitter = (require "events").EventEmitter
Iconv = (require "iconv").Iconv
helper = require "./helper.coffee"
class RssArchive extends Collector.Archive
    constructor:(@data,rss)->
        super()
        @title = @data.title
        @content = @data.description
        @contentType = "html"
        @createDate = new Date(@data.date)
        @fetchDate = new Date()
        if not @data.guid
            throw new "no guid"
            @invalid = true
        if not @content and not @title
            throw new "archive has no title and content"
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
class Rss extends EventEmitter
    @validEncoding = ["utf-8","gb2312","utf8","gbk"]
    constructor:(@raw)->
        @name = @raw.name
        @url = @raw.url
        @state = @raw.state or "uncheck"
        @encoding = @raw.encoding or null
        @failCount = parseInt(@raw.failCount) or 0
        @description = @raw.description or ""
        @fetchFrequency = @raw.fetchFrequency or 1
        @lastUpdate = new Date(@raw.lastUpdate)
        if not @url
            throw new Error "Rss information need url"
    save:()->
        @raw.encoding = @encoding
        @raw.url = @url
        @raw.state = @state
        @raw.name = @name
        @raw.description = @description
        @raw.fetchFrequency = @fetchFrequency or 1
        @raw.failCount = @failCount or 0
        @raw.lastUpdate = @lastUpdate.getTime() or 0
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
    setInstance:(instance)->
        # we can listen for error or update in instance.
        # and change information like frequency or encoding.
        @collectInstance = instance
        instance.on "encoding",(encoding)=>
            if encoding.toLowerCase() not in Rss.validEncoding
                @state = "invalid encoding"
            else
                @encoding = encoding.toLowerCase()
            @save()
        instance.on "validation",(state)=>
            @state = state
            if state not in  ["checked","need proxy"]
                console.error state
                # use some random, errors don't repeat at same time
                @fetchFrequency = Math.min(instance.nextInterval*(4+Math.random())+1,instance.maxInterval)
                @emit "fail",state
            @save()
        instance.on "meta",(meta)=>
            @name = meta.title
            @description = meta.description
            @save()
        instance.on "error",(err)=>
            @failCount++
            @state = "uncheck"
            @save()
        instance.on "fetchFrequencyChange",(time)=>
            @fetchFrequency = time
            @save()
class RssCollector extends Collector.Collector
    constructor:(name)->
        super()
        @name = name or "rss"
        @config = new Collector.CollectionConfig(@name)
        @rsses = []
        @collectInstances = []
        @config.load (err)=>
            if err
                throw err
                return
            @_init()
    getRssInformationByUrl:(link)->
        for rss in @rsses
            if rss.url is link
                return rss.toJSON()
    addAndStartRss:(link,callback)->
        for rss in @rsses
            if rss.url is link
                callback "duplicated",rss
                return
        rssInfo = {url:link}
        rss = new Rss(rssInfo)
        tester = new RssCollectInstance(rss,{proxy:@config.get("proxy")})
        tester.check (err)=>
            if err
                if callback then callback err 
                return
            @config.getReference("rsses").push(rssInfo)
            @rsses.push rss
            @config.save()
            @startRssInstance(rss)
            callback(null,rss)
        # note we only accept xml link
        # not able to auto detect rss
    removeRssByLink:(link)->
        rsses = @config.getReference("rsses")
        rsses = rsses.filter (item)->return item.url isnt link
        @config.setReference("rsses",rsses)

        @rsses = @rsses.filter (item)->
            if item.url is link
                if item.collectInstance
                    item.collectInstance.stop()
                return false
            return true
    _init:()->
        @config.set("name","rss")
        rsses = @config.getReference("rsses") or []
        for rss in rsses
            try
                @rsses.push new Rss(rss)
            catch e
                console.error "If get here, it's likely that the rss information is broken, please check configs"
        @emit "ready"

    start:()->
        for rss in @rsses
            @startRssInstance rss
    
    stop:()->
        for instance in @startRssInstance
            instance.stop()
    startRssInstance:(rss)->
        rss.on "configUpdate",()=>
            @config.save()
        instance =  new RssCollectInstance(rss,{proxy:@config.get("proxy")})
        @collectInstances.push instance
        instance.on "archive",(item)=>
            @emit "archive",item.toJSON()
        instance.start()
class RssCollectInstance extends EventEmitter
    constructor:(rss,option = {})-> 
        @rss = rss
        @rss.setInstance(this)
        @proxy = option.proxy
        @lastArchiveIds = []
        @maxInterval = 12 * 60 * 60 * 1000
        @minInterval = 2 * 60 * 1000
        @nextInterval = parseInt(rss.fetchFrequency) or @minInterval
        @nextInterval = Math.min(@maxInterval,@nextInterval)
        if @rss.state not in ["checked","need proxy"]
            @nextInterval = 0
    stop:()->
        # not the stop isnt really stop
        # the request the is on the way will not be aborted
        # and call start imediately after stop
        # may cause issue , don't do it
        if @timer
            clearTimeout timer
        @isStop = true
    start:()->
        @isStop = false
        if @timer
            clearTimeout @timer
        fetch = (callback)=> 
            @fetch (err,data)=>
                if err
                    @emit "error",err
                    # no need to stop on a single error
                callback(err,data)
        run = ()=>
            next = ()=>
                if @isStop
                    return
                if @timer
                    clearTimeout @timer
                @timer = setTimeout run,@nextInterval
            if @rss.state not in ["checked","need proxy"]
                @check (err)=>
                    if err
                        @nextInterval = Math.max(@nextInterval*4,@maxInterval)
                        # do time panelty and next round
                        next()
                    else
                        # recovered!
                        @fetch (err,data)=>
                            next()
                return
            else
                fetch (err,data)=>
                    # any way go next round
                    next()
        setTimeout run,@nextInterval
    check:(callback)->
        if @rss.url.indexOf("http://") isnt 0 and @rss.url.indexOf("https://") isnt 0
            @emit "validation","invalid url"
            callback("invalid url")
            return
        request = require("request")
        helper.httpGet {url:@rss.url},(err,res,body)=>
            if err
                helper.httpGet {url:@rss.url,proxy:@proxy},(_err,_res,body)=>
                    if _err 
                        @emit "validation","network error"
                        callback("network error")
                        console.error _err,@rss.url
                        return
                    else
                        @emit "validation","need proxy"
                    checkRes _res,body,"need proxy"
                return
            checkRes(res,body,"checked")
        checkRes = (res,body,successMessage)=>
            bodyBuffer = body
            body = body.toString().trim()
            firstLine = body.substring(0,body.indexOf(">")).trim()
            if firstLine.indexOf("<?xml") isnt 0
                console.error firstLine,"body:",body
                @emit "validation","invalid xml"
                callback("invalid xml")
                return
            encodingReg = /encoding=\"[0-9a-z]+\"/ig
            match = firstLine.match encodingReg
            if not match
                if res.headers["content-encoding"]
                    encoding = res.headers["content-encoding"].toLowerCase()
                    @emit "encoding",encoding
                # else if res.headers["content-type"] and res.headers["content-type"].indexOf("")
                # add detect latter
                # but this is less reliable than the xml declare
                # since most rss generator handles xml correctly
                else
                    encoding = "utf-8"
                    @emit "encoding",encoding
            else
                encoding = match[0].replace("encoding=\"","").replace("\"","")
                @emit "encoding",encoding
            @emit "validation",successMessage
            if encoding not in ["utf-8","utf8"]
                data = (new Iconv(encoding,"utf-8")).convert(bodyBuffer)
            else
                data = bodyBuffer
            parser = new FeedParser()
            parser.on "meta",(meta)=>
                @emit "meta",meta
            parser.on "readable",()=>
                while parser.read()
                    return
            parser.on "error",()=>
                callback("invalid rss")
            parser.on "end",()=>
                callback()
            parser.write(data)
            parser.end()
    fetch:(callback)->
        # be careful not shadow the require param
        buffers = []
        option = {url:@rss.url}
        if @rss.state is "need proxy"
            option.proxy = @proxy
        helper.httpGet option,(err,res,body)=>
            if err
                callback err
                return
            if @rss.encoding and @rss.encoding not in ["utf8","utf-8"]
                try
                    converter = new Iconv(@rss.encoding,"utf8")
                    bodyString = converter.convert(body).toString("utf8")
                catch e
                    console.error e
                    callback new Error "encoding error"
                    return
            else
                bodyString = body.toString("utf8")
            @handleRssBody bodyString,(err)=> 
                callback err
    handleRssBody:(body,callback)->
        parser = new FeedParser()
        parser.on "meta",(meta)=>
            @emit "meta",meta
        
        archiveIds = []
        articles = []
        parser.on "readable",()=>
            while article = parser.read()
                articles.push article
            
        parser.on "error",(err)->
            callback err
        parser.on "end",()=>
            for article,index in articles
                try 
                    archive = new RssArchive(article,@rss)
                catch e
                    console.error e
                    console.log "tail to add archive",article
                    continue
                if (article.date and article.date.getTime() <= @rss.lastUpdate.getTime()) or archive.guid in @lastArchiveIds
                    console.log "reach lastupdate",index,@rss.url
                    if index is 0
                        #no update
                        @nextInterval = Math.min(@maxInterval,@nextInterval*1.5)
                    else
                        @nextInterval = Math.max(@minInterval,@nextInterval/4)
                    @emit "fetchFrequencyChange",@nextInterval
                    break
                if article.date and article.date.getTime() > @rss.lastUpdate.getTime()
                    @rss.lastUpdate = article.date
                archiveIds.push archive.guid
                archive.load (err,item)=>
                    if err
                        console.error err 
                        console.error "Archive load error I haven't write any test here, if you see this message, this is a good chance to complete the correct error handle logic. Basically, it may fail due to sina.com is down or network error but event it fails to load, it can still be a quite complete archive, I'd still emit a 'archive' event."
                    if item and item.validate()
                        @emit "archive",item 
                    else
                        throw new Error("Invalid Archive, if saidly we get here, it indicates that the program logic is wrong, if we get correct data the archive should always be valid, so either the broken raw data get passed our poor validation check, or the RssArchive constructor are wrong the data is: #{JSON.stringify(item.toJSON(),null,4)}")
            if archiveIds.length > 0
                @lastArchiveIds = archiveIds
            callback()
        parser.end(body)
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
        @collector.addAndStartRss uri,(err,rss)=>
            # may err and rss both exists
            # when it's duplicated
            if rss
                callback err,@_rssToSource rss
            else
                callback err
    testURI:(uri,callback)->
        try
            rss = new Rss({url:uri})
        catch e
            callback "invalid url"
        instance = new RssCollectInstance(rss,{proxy:@collector.config.get("proxy")})
        instance.on "error",(err)->
            return
        instance.check (err)->
            callback(err)

exports.RssCollector = RssCollector
exports.Collector = RssCollector
exports.Manager = RssCollectorManager
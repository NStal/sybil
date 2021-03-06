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
# and history/logs
class Rss extends EventEmitter
    @validEncoding = ["utf-8","gb2312","utf8","gbk"]
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
        
    start:()->
        @isStop = false
        if @timer
            throw "If you get here, it means there are timer for fetch instance loop not cleared when start a rss fetch instance. And this must be something wrong."
        # for uncheckd/invalid rss we do a initialize check
        # When it's not checked, it may be fail/hang last time
        # or newly added rss.
        # whatever it is we give it a change to prove herself
        
        
        check = (callback)->
            @check (err)=>
                if not err
                    callback()
                    return
                switch err
                    when "invalid url","not available","invalid xml","invalid rss"
                        @state = "fail"
                        callback()
                    when "proxy not available"
                        @state = "hang"
                        callback()
                        console.warn "proxy not available"
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
        helper.httpGet {url:@rss.url},(err,res,body)=>
            if err
                helper.httpGet {url:@rss.url,proxy:@proxy},(_err,_res,body)=>
                    if _err
                        if _err is "target not available"
                            callback("not available")
                        else
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
            if firstLine.indexOf("<?xml") isnt 0
                console.error firstLine,"body:",body
                callback("invalid xml")
                return
            encodingReg = /encoding=\"[0-9a-z]+\"/ig
            match = firstLine.match encodingReg
            if not match
                if res.headers["content-encoding"]
                    @encoding = res.headers["content-encoding"].toLowerCase()
                # else if res.headers["content-type"] and res.headers["content-type"].indexOf("")
                # add detect latter
                # but this is less reliable than the xml declare
                # since most rss generator handles xml correctly
                else
                    @encoding = "utf-8"
            else
                @encoding = match[0].replace("encoding=\"","").replace("\"","")
            if encoding not in ["utf-8","utf8"]
                data = (new Iconv(encoding,"utf-8")).convert(bodyBuffer)
            else
                data = bodyBuffer
            parser = new FeedParser()
            parser.on "meta",(meta)=>
                @updateMeta(meta)
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
        option = {url:@url}
        if @needProxy
            option.proxy = @proxy
        helper.httpGet option,(err,res,body)=>
            if err
                callback err
                return 
            if @encoding and @encoding not in ["utf8","utf-8"]
                try
                    converter = new Iconv(@encoding,"utf8")
                    bodyString = converter.convert(body).toString("utf8")
                catch e
                    console.error e
                    callback "encoding error"
                    return
            else
                bodyString = body.toString("utf8")
            @handleRssBody bodyString,(err)=> 
                callback err
    handleRssBody:(body,callback)->        
        archiveIds = []
        articles = []
        parser = new FeedParser()
        parser.on "meta",(meta)=>
            @updateMeta meta
        
        parser.on "readable",()=>
            while article = parser.read()
                articles.push article
        parser.on "error",(err)->
            callback err
        parser.on "end",()=>            
            for article,index in articles
                try 
                    archive = new RssArchive(article,this)
                catch e
                    console.error e
                    console.log "Invalid archive",article
                    continue
                if (article.date and article.date.getTime() <= @lastUpdate.getTime()) or archive.guid in @lastArchiveIds
                    console.log "reach lastupdate",index,@url
                    if index is 0
                        #no update
                        @increaseInterval()
                    else
                        #has update
                        @decreaseInterval()
                    break
                if article.date and article.date.getTime() > @lastUpdate.getTime()
                    @lastUpdate = article.date
                archiveIds.push archive.guid
                archive.load (err,item)=>
                    if err
                        console.error err 
                        console.error "Archive load error I haven't write any test here, if you see this message, this is a good chance to complete the correct error handle logic. Basically, it may fail due to sina.com is down or network error but event it fails to load, it can still be a quite complete archive, I'd still emit a 'archive' event."
                    if item and item.validate()
                        @emit "archive",item 
                    else
                        throw new "Invalid Archive, if saidly we get here, it indicates that the program logic is wrong, if we get correct data the archive should always be valid, so either the broken raw data get passed our poor validation check, or the RssArchive constructor are wrong the data is: #{JSON.stringify(item.toJSON(),null,4)}"
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
            clearTimeout timer
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
    decreaseInterval:()->
        @nextInterval = Math.max @minInterval,@nextInterval/2
        if @nextInterval < @minInterval
            @nextInterval = @minInterval
    save:()->
        @raw.encoding = @encoding
        @raw.url = @url
        @raw.state = @state
        @raw.name = @name
        @raw.description = @description
        @raw.fetchFrequency = @fetchFrequency or 1
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

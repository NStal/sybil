urlModule = require "url"
errorDoc = require "error-doc"
Iconv = (require "iconv").Iconv
FeedParser = require "feedparser"
httpUtil = require "../../../common/httpUtil.coffee"
console = env.logger.create(__filename)

cheerio = require "cheerio"
proxy = global.env.settings.get "proxy"
Errors = errorDoc.create()
    .inherit httpUtil.Errors
    .define "InvalidRssFormat"
    .define "InvalidURL"
    .define "InvalidEncoding"
    .generate()
exports.Errors =Errors

exports.detectRssEntry = (url,callback)->
    urlObject = urlModule.parse url
    if urlObject.protocol not in ["http:","https:","feed:"]
        callback new Errors.InvalidURL("#{url} is not a valid url")
        return
    timeout = 30 * 1000
    httpUtil.httpGet {url:url,timeout:timeout},(err,res,body)=>
        if err
            httpUtil.httpGet {url:url,timeout:timeout},(err,res,body)=>
                if err
                    callback err
                    return
                checkRes res,body
            return
        checkRes res,body
    
    checkRes = (res,body)->
        links = []
        try
            $ = cheerio.load(body.toString())
            $("link").each ()->
                jq = $ this
                rel = jq.attr "rel"
                type = jq.attr "type"
                href = jq.attr "href"
                if rel is "alternate" and (type is "application/rss+xml" or type is "application/atom+xml")
                    links.push href
            links = links.map (href)->
                return urlModule.resolve url,href
        catch e
            callback null,[]
            return
        callback null,links

exports.fetchRss = (url,callback)->
    urlObject = urlModule.parse url
    useProxy = null
    useEncoding = null
    timeout = 30 * 1000
    if urlObject.protocol not in ["http:","https:","feed:"]
        callback new Errors.InvalidURL("unsupport prototcol #{urlObject.protocol}")
        return
    httpUtil.httpGet {url:url,timeout:timeout},(err,res,body)=>
        if err
            console.debug "direct check fail #{url} #{JSON.stringify(err)} now through proxy #{proxy}"
            err = null
            httpUtil.httpGet {url:url,timeout:timeout},(err,res,body)=>
                if err
                    console.debug "check fail #{url} through proxy #{proxy}"
                    callback err
                    return
                useProxy = proxy
                checkRes res,body
            return
        checkRes res,body
    
    checkRes = (res,body)=>
        bodyBuffer = body
        body = body.toString().trim()
        firstLine = body.substring(0,body.indexOf(">")).trim()
        if firstLine.indexOf("<?xml") isnt 0 and firstLine.indexOf("<rss") isnt 0
            callback(new Errors.InvalidRssFormat("invalid xml"))
            return
        encodingReg = /encoding=\"[0-9a-z]+\"/ig
        match = firstLine.match encodingReg
        if not match
            # not matching encoding from xml
            # now we use header check
            # this is less reliable than the xml declare
            # since most rss generator handles xml correctly

            if res.headers["content-type"] and res.headers["content-type"].toLowerCase().indexOf("charset=") > 0
                contentType = res.headers["content-type"].toLowerCase()
                for item in contentType.split(";")
                    if not item
                        continue
                    kv = item.split("=")
                    if kv[0].trim() is "charset"
                        useEncoding = kv[1]
                        
            
            # add detect latter
            if not useEncoding
                useEncoding = "utf-8"
        else
            useEncoding = match[0].replace("encoding=\"","").replace("\"","").toLowerCase()
        # some sites don't correctly declare gbk sets
        # but since gb18030 is the superset of gbk and gb2312
        # use it by default
        if useEncoding in ["gbk","gb2312"]
            useEncoding = "gb18030"
        if useEncoding not in ["utf-8","utf8"]
            try 
                data = (new Iconv(useEncoding,"utf-8//TRANSLIT//IGNORE")).convert(bodyBuffer)
            catch e
                console.error e,"at",url
                console.error "fail to decode with with #{useEncoding}"
                callback(new Errors.InvalidEncoding("fail to decode using #{useEncoding}"))
                return
        else
            data = bodyBuffer
        parser = new FeedParser()
        meta = {}
        parser.on "meta",(m)=>
            meta = m
        archives = []
        parser.on "readable",()=>
            while data = parser.read()
                archives.push(data)
            return
        parser.on "error",(err)=>
            console.error "parse error",err,"at",url
            callback(new Errors.InvalidRssFormat("parse error",{via:err}))
        parser.on "end",()=>
            result = {
                archives:archives
                ,proxy:useProxy
                ,encoding:useEncoding
                ,name:meta.title
                ,description:meta.description
                ,url:url
            }
            callback(null,result)
        parser.write(data)
        parser.end()

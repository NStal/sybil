async = require "async"
httpGetQueue = async.queue ((job,done)->
    exports._httpGet job.option,(err)->
        if job.done
            console.trace()
            return
        job.done = true
        done()
        job.callback.apply {},arguments
    ),50
exports.httpGet = (option,callback)->
    if option.noQueue
        exports._httpGet option,callback
        return
    httpGetQueue.push {option:option,callback:callback}
exports._httpGet = (option,callback)->
    url = option.url
    proxy = option.proxy or null
    useStream = option.useStream or false
    if typeof option.maxRedirect isnt "number"
        option.maxRedirect = 2
    else
        if option.maxRedirect < 0
            callback "max redirect reach"
            return
    timeout = option.timeout or 1000 * 30
    req = null
    isTimeout = false
    timer = setTimeout (()->
        isTimeout = true
        if req and req.abort
            req.abort()
            callback "network timeout"
        ),timeout
    _callback = callback
    callback = (err,res,data)->
        clearTimeout timer
        _callback err,res,data
        _callback = ()->
    if not proxy
        if url.indexOf("https") is 0
            scheme = require "https"
        else if url.indexOf("http") is 0
            scheme = require "http"
        else
            callback new Error "Invalid Request"
            return
        buffers = []
        headers = option.headers or {}
        if not headers["User-Agent"]
            headers["User-Agent"] = exports.defaultAgent
        _urlObject = (require "url").parse(url)
        urlObject = {}
        urlObject.path = _urlObject.path
        urlObject.hostname = _urlObject.hostname
        urlObject.port = _urlObject.port
        urlObject.method = "GET"
        urlObject.headers = headers
        req = scheme.request urlObject,(res)=>
            clearTimeout timer
            if res.headers["location"]
                newUrl = require("url").resolve(url,res.headers["location"])
                option.url = newUrl
                option.maxRedirect-=1
                __callback = callback
                callback = ()->true
                exports._httpGet option,__callback
                return
            if res.headers["content-encoding"]
                _enc = res.headers["content-encoding"].toLowerCase().trim()
                if _enc is "gzip"
                    pipeline = (require "zlib").createGunzip()
                else if _enc is "deflate"
                    pipeline = (require "zlib").createInflate()
                else
                    res.close()
                    callback "unknown encoding #{_enc}"
                    return
                res.pipe(pipeline)
            else
                pipeline = res
            # return a stream instead the content
            if useStream
                callback null,res,pipeline
                return
            pipeline.on "readable",()->
                while data = pipeline.read()
                    buffers.push data
            pipeline.on "error",(err)->
                callback err
            pipeline.on "end",()->
                buffer = Buffer.concat buffers
                callback null,res,buffer
        req.on "error",(err)->
            if isTimeout
                callback "network timeout"
                return
            callback err
        req.end()
    if proxy
        host = proxy.host
        port = proxy.port
        if not host or not port
            callback "invalid proxy option"
            return
        headers = option.headers or {}
        
        if not headers["User-Agent"]
            headers["User-Agent"] = exports.defaultAgent
        headers["real-path"] = new Buffer(url).toString("base64")
        buffers = []
        req = require("http").request {
            hostname:host
            ,port:port
            ,method:"GET"
            ,headers:headers
            ,path:"/"
            },(res)->
                clearTimeout timer
                if res.statusCode is 591
                    callback "target not available"
                    return
                if res.headers["location"]
                    newUrl = require("url").resolve(url,res.headers["location"])
                    option.maxRedirect-=1
                    option.url = newUrl
                    __callback = callback
                    callback = ()->true
                    exports._httpGet option,__callback
                    return
                if res.headers["content-encoding"]
                    _enc = res.headers["content-encoding"].toLowerCase().trim()
                    if _enc is "gzip"
                        pipeline = (require "zlib").createGunzip()
                    else if _enc is "deflate"
                        pipeline = (require "zlib").createInflate()
                    else
                        res.close()
                        callback "unknown encoding #{_enc}"
                        return
                    res.pipe(pipeline)
                else
                    pipeline = res
                if useStream
                    callback null,res,pipeline
                    return
                pipeline.on "readable",()->
                    while data = pipeline.read()
                        buffers.push data
                pipeline.on "error",(err)->
                    callback err
                pipeline.on "end",()->                    
                    buffer = Buffer.concat buffers
                    callback null,res,buffer
        req.on "error",(err)->
            if isTimeout
                callback "network timeout"
                return
            callback err
        req.end()
exports.defaultAgent = "Sybil Reader/0.0.1"

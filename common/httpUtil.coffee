# option
# url        : url to fetch
# proxy      : what kind of proxy to use string like phttp://localhost:3223/
# timeout    : timeout
# headers    : custom headers
# useStream  : return a stream instead of downloaded content
# maxRedirect: max redirect for 30X
# acceptCache: return Object {cache:true} when recieve not modified
# noQueue    : send request event the queue is full

async = require "async"
ProxyAgent = require "proxy-agent"
urlModule = require "url"
zlib = require "zlib"
httpGetQueue = async.queue ((job,done)->
    exports._httpGet job.option,(err)->
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
        option.maxRedirect = 3
    else
        if option.maxRedirect < 0
            callback "max redirect reach"
            return
    timeout = option.timeout or 1000 * 30
    
    _callback = callback
    callback = (err,res,data)->
        
        _callback err,res,data
        # call callback twice don't throw error
        _callback = ()->
    scheme = exports._prepareScheme(option)
    if not scheme
        callback "invalid protocol"
        return
    agent = exports._prepareAgent(option)
    headers = option.headers or {}
    if not headers["User-Agent"]
        headers["User-Agent"] = exports.defaultAgent

    _urlObject = urlModule.parse(url)
    requestOption = {}
    requestOption.path = _urlObject.path
    requestOption.hostname = _urlObject.hostname
    requestOption.port = _urlObject.port
    requestOption.method = "GET"
    requestOption.headers = headers
    requestOption.agent = agent
    req = scheme.request requestOption,(res)=>
        if res.headers["location"]
            newUrl = require("url").resolve(url,res.headers["location"])
            option.url = newUrl
            option.maxRedirect-=1
            exports._httpGet option,callback
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
            
        buffers = []
        pipeline.on "readable",()->
            while data = pipeline.read()
                buffers.push data
        pipeline.on "error",(err)->
            callback err
        pipeline.on "end",()->                    
            buffer = Buffer.concat buffers
            callback null,res,buffer
    req.on "error",(err)->
        # Note:
        # errer after recieve header but useStream
        # will fail silently
        # which means you are responsible for completeness check
        # also when timeout it error will be ECONNRESET when not content recieved
        # the ECONNRESET will also be suppressed by timeout
        callback err
    req.setTimeout timeout,()->
        callback "network timeout"
        req.abort()
    req.end()
exports._prepareScheme = (option)->
    scheme = null
    if not option.proxy
        url = option.url
        if url.indexOf("https") is 0
            scheme = require "https"
        else if url.indexOf("http") is 0
            scheme = require "http"
        else if url.indexOf("feed://") is 0
            scheme = require "http"
    else
        scheme = require "http"
    # for proxied request we all use http scheme and others are left to agents
    return scheme


exports._prepareAgent = (option)->
    if not option.proxy
        return null
    if option.proxy.indexOf("phttp://") is 0
        return require("./phttp-proxy-agent")(option.proxy);
    try
        return ProxyAgent(option.proxy)
    catch e
        return null
        
exports.defaultAgent = "Sybil Reader/0.0.1"
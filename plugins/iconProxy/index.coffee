httpUtil = require "../../common/httpUtil"
urlModule = require "url"
pathModule = require "path"
States = sybilRequire "common/states"
crypto = require "crypto"
fs = require "fs"
# This file is a mess.
# I will refactor it later or never.
Errors = require("error-doc").create()
.define("FileError")
.define("NetworkError")
.define("FetchError")
.define("FatalError")
.define("ServerError")
.generate()

# Try fetch the icon if possible
# 1. If failed try go with the default best proxy
# 2. If failed again. mark as failed

exports.requires = ["webApi"]
exports.register = (dep,callback)->
    class IconResponser extends States
        @resourceFolder = pathModule.resolve dep.resourceFolder
        @defaultIconPath = pathModule.resolve @resourceFolder,"default-icon.ico"
        @tempFolder = dep.tempFolder
        @blackList = []
        constructor:(@req,@res)->
            super()
            @debug()
            @url = @req.param("url")
            @iconUrl = urlModule.resolve @url,"/favicon.ico"
            @fileName = crypto.createHash("md5").update(@iconUrl).digest("hex") + ".icon"
            @filePath = pathModule.resolve IconResponser.tempFolder,@fileName
            @proxies = dep.settings.proxies or global.env.settings.proxies or []
            @data.proxyIndex = -1
            @rescue "fetchIcon",Errors.NetworkError,(error)=>
                if @proxies[@data.proxyIndex+1]
                    console.log "Proxy fetch failed try next proxy",JSON.stringify @proxies[@data.proxyIndex+1]
                    @data.proxyIndex += 1
                    @setState "fetchIcon"
                else
                    @setState "updateFailedIconCache"
            @rescue "updateFailedIconCache",Error,(error)=> @setState "returnDefaultIcon"
            @rescue "fetchIcon",Errors.FetchError,(error)=> @setState "updateFailedIconCache"
            @rescue "updateCache",Errors.FileError,(error)=> @setState "updateFailedIconCache"
            @rescue "returnDefaultIcon",Errors.FileError,(error)=>
                @data.serverError = error
                @setState "returnServerError"
            @rescue "returnCache",Errors.FileError,(error)=>@setState "returnDefaultIcon"
        _responseIconBinary:(buffer)->
            @res.end(buffer)
        start:()->
            if @state is "void"
                @setState "checkCache"
        atPanic:()->
            @emit "error",new Errors.FatalError "fatal error",via:@panicError
        atCheckCache:(sole)->
            # This icon url has been blacklist due to a failed
            if @iconUrl in IconResponser.blackList
                @setState "returnDefaultIcon"
                return
            fs.exists @filePath,(exists)=>
                if @stale sole
                    return
                if exists
                    @setState "returnCache"
                else
                    @setState "fetchIcon"
        atFetchIcon:(sole)->
            httpUtil.httpGet {url:@iconUrl,timeout:2500,proxy:@proxies[@data.proxyIndex] or null,noQueue:true},(err,res,buffer)=>
                if @stale sole
                    return
                if err
                    @error new Errors.NetworkError
                    return
                if res.statusCode is 200
                    @data.iconBinary = buffer
                    @setState "updateCache"
                else
                    @error new Errors.FetchError("icon response isnt 200")
        atUpdateCache:(sole)->
            fs.writeFile @filePath,@data.iconBinary,(err)=>
                if @stale sole
                    return
                if err
                    @error new Errors.FileError "fail to update cache #{@filePath}",{via:err}
                    return
                @setState "returnIconBinary"
        atUpdateFailedIconCache:(sole)->
            if @stale sole
                return
            fs.readFile IconResponser.defaultIconPath,(err,buffer)=>
                if @stale sole
                    return
                if err
                    @error new Errors.FileError "fail to get read default icon",{via:err}
                    return
                @data.iconBinary = buffer
                @setState "updateCache"
                return
        atReturnDefaultIcon:(sole)->
            IconResponser.blackList.push @iconUrl
            if IconResponser.defaultIconBuffer
                @data.iconBinary = IconResponser.defaultIconBuffer
                @setState "returnIconBinary"
            else
                fs.readFile IconResponser.defaultIconPath,(err,buffer)=>
                    if @stale sole
                        return
                    if err
                        @error new Errors.FileError "fail to get read default icon",{via:err}
                        return
                    @data.iconBinary = buffer
                    @setState "returnIconBinary"
                    return
        atReturnCache:(sole)->
            fs.readFile @filePath,(err,buffer)=>
                if @stale sole
                    return
                if err
                    @error new Errors.FileError "fail to read cache #{@filePath}",{via:err}
                    return
                @data.iconBinary = buffer
                @setState "returnIconBinary"
        atReturnIconBinary:(sole)->
            DAYms = 1000 * 60 * 60 * 24
            days = 14
            @res.setHeader "Expires", new Date(Date.now() + DAYms * days).toGMTString()
            @res.setHeader "Cache-Control",  "max-age=#{DAYms/1000 * days}, public"
            @res.end @data.iconBinary
            @emit "done"
        atReturnServerError:()->
            @res.statusCode = "503"
            @res.end JSON.stringify new Errors.ServerError "server error fatal",{via:@data.serverError}
            @emit "done"
    if not dep.webApi
        callback "need webApi to implement"
        return
    server = dep.webApi.app
    server.get "/plugins/iconProxy",(req,res)->
        iconer = new IconResponser(req,res)
        iconer.start()
        iconer.on "error",(err)->
            console.error "fatal error",err
            res.statusCode = 503
            res.end()
    callback null,{}

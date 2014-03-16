http = require("https")
httpUtil = require("../common/httpUtil.coffee")
theOldReaderHost = "theoldreader.com"
getAuthToken = (email,password,callback)->
    data = "client=SybilReader&accountType=HOSTED_OR_GOOGLE&service=reader&Email=#{email}&Passwd=#{password}"
    data = new Buffer(data)
    
    req = http.request {method:"POST",host:theOldReaderHost,path:"/accounts/ClientLogin",headers:{"Content-Length":data.length,"Content-Type":"application/x-www-form-urlencoded"}},(res)->
        buffers = []
        res.on "data",(data)->
            buffers.push data
        res.on "end",()->
            result = (Buffer.concat buffers).toString()
            kvs = result.split("\n")
            for kv in kvs
                [k,v] = kv.split("=")
                if k.toLowerCase() is "auth"
                    callback null,v
                    return
            callback "not found"
    req.on "error",(err)->
        callback err
        callback = ()->false
    req.end(data)

getUserProfile = (token,callback)->
    req = http.request {method:"GET",host:theOldReaderHost,path:"/reader/api/0/user-info",headers:{"Authorization":"GoogleLogin auth=#{token}"}},(res)->
        buffers = []
        res.on "data",(data)->
            buffers.push data
        res.on "error",(err)->
            callback err
            callback = ()->false
        res.on "end",()->
            result = (Buffer.concat buffers).toString()
            try
                result = JSON.parse(result)
                callback null,result
            catch e
                callback e
    req.on "error",(err)->
        callback err
        callback = ()->false
    req.end()
getFeeds = (token,callback)->
    httpUtil.httpGet {url:"https://theoldreader.com/reader/api/0/unread-count?output=json",headers:{"Authorization":"GoogleLogin auth=#{token}"}},(err,res,content)->
        json = JSON.parse(content.toString())
        callback null,json.unreadcounts
getFeed = (token,route,callback)->
    httpUtil.httpGet {url:"https://theoldreader.com/reader/atom/#{route}?output=json",headers:{"Authorization":"GoogleLogin auth=#{token}"}},(err,res,content)->
        json = JSON.parse(content.toString())
        callback null,json
getArchive = (token,id,callback)->
    data = "i=#{id}"
    data = new Buffer(data)    
    req = http.request {method:"POST",host:theOldReaderHost,path:"/reader/api/0/stream/items/contents?output=json",headers:{"Content-Length":data.length,"Content-Type":"application/x-www-form-urlencoded","Authorization":"GoogleLogin auth=#{token}"}},(res)->
        buffers = []
        res.on "data",(data)->
            buffers.push data
        res.on "end",()->
            result = (Buffer.concat buffers).toString()
            callback null,JSON.parse(result)
    req.on "error",(err)->
        callback err
        callback = ()->false
    req.end(data)
getAuthToken "nstalmail@gmail.com","lenFriedBK201",(err,token)->
    console.error err,token
    getUserProfile token,(err,profile)->
        getFeeds token,(err,feeds)->
            getFeed token,feeds[20].id,(err,result)->
                getArchive token,result.items[0].id,(err,archive)->
                    console.log "!!!",archive.items[0].summary.content

        
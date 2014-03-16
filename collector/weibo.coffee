Collector = require("./collector.coffee")
EventEmitter = (require "events").EventEmitter
request = require("request")

class WeiboAccount extends EventEmitter
    constructor:(@data)->
        super()
        @code = @data.code
        @accessToken = @data.accessToken

        if not @code
            throw new Error "Invalid Account"
        if not @accessToken
            throw new Error "Invalid Access Token"
        @code = @data.code
    toJSON:()->
        return {
            @code
        }
    
# will fetch the weibo images or something like that
class WeiboArchive extends Collector.Archive
    constructor:(data)->
        super()
        if not data.id
            @invalid = true
        
        @guid = "weibo_"+data.id
        @collectorName = "weibo"
        @createDate = new Date(data.created_at)
        @fetchDate = new Date()
        @authorName = data.user and data.user.name
        @authorAvatar = data.user.profile_image_url
        @authorLink = data.user.domain and "http://weibo.com/"+data.user.domain
        @sourceName = "weibo"
        @sourceUrl = "http://weibo.com"
        @content = data.text or ""
        @contentType = "text"
        @attachments = []
        if data.original_pic
            @attachments.push {type:"image",format:"url",value:data.original_pic}
    load:(callback)->
        # maybe create original link latter
        # http://open.weibo.com/qa/index.php?qa=11914&qa_1=%E6%80%8E%E6%A0%B7%E5%87%91%E6%8B%BC%E5%BE%AE%E5%8D%9A%E5%9C%B0%E5%9D%80-%E4%BE%8B%E5%A6%82http-weibo-com-1776646097-zi4crzp2r
        # 
        callback null,this
        
class WeiboCollector extends Collector.Collector
    constructor:(name)->
        super()
        @name = name or "weibo"
        @config = new Collector.CollectionConfig(@name)
        @accounts = []
        @collectInstances = []
        @config.load (err)=>
            if err
                throw err
                return
            @_init()
            
    _init:()->
        @config.set("name","weibo collector")
        essentials = ["appKey","appSecret","callbackUrl"]
        for item in essentials
            if not @config.get(item)
                err = new Error;
                err.message = "weibo collector need #{item} to run"
                @emit "error",err
        accounts = @config.get("accounts") or []
        for account in accounts
            try
                @accounts.push new WeiboAccount(account)
            catch e
                console.error "If you get here, it's likly that the account information of weibo is broken or the logic code for checking account information is failed."
                @emit "error",e
                return
        @emit "ready"
    start:()->
        for account in @accounts
            instance = new WeiboCollectInstance({
                account:account
                ,appKey:@config.get("appKey")
                ,appSecret:@config.get("appSecret")
            })
            instance.on "archive",(archive)=>
                @emit "archive",archive
            instance.on "error",(err)=>
                console.error "weibo collect instance error",err
            @collectInstances.push instance
        for instance in @collectInstances
            console.log "start"
            instance.start()
    stop:()->
        if @collectInstances.length > 0
            for instance in @collectInstances
                instance.stop()
   


class WeiboCollectInstance extends EventEmitter
    constructor:(option)->
        @option = option
        @timer = null
        @interval = option.interval or 1000 * 60 * 2
        @lastWeiboIds = []
        urlParam = {
            query:{
                access_token:option.account.accessToken
                ,count:100
            }
            ,host:"api.weibo.com"
            ,pathname:"/2/statuses/home_timeline.json"
            ,protocol:"https"
        }
        @fetchUrl = require("url").format(urlParam)
    start:()->
        if @timer
            clearTimeout @timer
        run = ()=>
            @fetch (err,data)=> 
                if err
                    @emit "error",err
                    # no need to stop on a single error
                else
                    @handleWeibos(data)
                @timer = setTimeout (()=>
                    run()
                ),@interval
        @timer = null
        run()
    handleWeibos:(weibos)->
        weiboIds = []
        for weibo,index in weibos
            archive = new WeiboArchive(weibo)
            if archive.guid in @lastWeiboIds
                console.log "conflict at index",index
                if weiboIds.length > 0
                    @lastWeiboIds = weiboIds
                return
            weiboIds.push archive.guid
            
            archive.load (err,item)=>
                if err
                    console.error err
                    console.error "Archive load error I haven't write any test here, if you see this message, this is a good chance to complete the correct error handle logic. Basically, it may fail due to sina.com is down or network error but event it fails to load, it can still be a quite complete archive, I'd still emit a 'archive' event."
                if item and item.validate()
                    @emit "archive",item
                else
                    throw new Error("Invalid Archive, if saidly we get here, it indicates that the program logic is wrong, if we get correct data the archive should always be valid, so either the broken raw data get passed our poor validation check, or the WeiboArchive constructor are wrong the data is: #{JSON.stringify(item.toJSON(),null,4)}")
                    return
        if weiboIds.length > 0
            @lastWeiboIds = weiboIds
    fetch:(callback)->
        request.get @fetchUrl,(err,res,body)=>
            if err
                callback err
                return
            try
                result = JSON.parse(body.toString())
            catch e
                callback new Error "Parse Error with:"+body
                return
            weibos = result.statuses
            if weibos not instanceof Array
                callback new Error "Invalid Weibo Statuses,May be return with an Error or Sina has change it's format so the response text is:"+body+".if you found other meaningful error say authorization failed which indicates that we should update access_token, please add code at weibo.coffee"
                return
            callback null,weibos            
    stop:()->
        if @timer
            clearTimeout @timer
            @timer = null
            
class WeiboCollectorManager extends Collector.CollectorManager
    constructor:(@collector)->
        super(@collector)
    getSources:()->
        sources = []
        for account in @collector.accounts
            sources = new Collector.Source()
            source.name = "weibo@"+account.code
            source.guid = "weibo_"+account.code
            source.type = "weibo"
            source.meta = account.toJSON()
exports.WeiboCollector = WeiboCollector
exports.Collector = WeiboCollector
exports.Manager = WeiboCollectorManager

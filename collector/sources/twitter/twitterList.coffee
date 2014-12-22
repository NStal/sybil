cheerio = require "cheerio"
Source = require "../../source/source.coffee"
urlModule = require "url"
EventEmitter = (require "events").EventEmitter
http = require "http"
twitterUtil = require "./twitterUtil.coffee"
ErrorDoc = require "error-doc"
console = console = env.logger.create __filename
Errors =  Source.Errors

class TwitterList extends Source
    constructor:(info = {})->
        @jar = new CookieJar()
        super info
        if info.properties and info.properties.jar
            for cookie in info.properties.jar
                @jar.setCookieSync cookie,"https://twitter.com/"
        @type = "twitter"
        @client = new twitterUtil.TwitterRequestClient()
        @reg = new RegExp("twitter.com/([^/]+)/lists/([^/]+)$","i")
        @mobileUserAgent = "Mozilla/5.0 (Linux; Android 4.2.1; en-us; Nexus 5 Build/JOP40D) AppleWebKit/535.19 (KHTML, like Gecko) Chrome/18.0.1025.166 Mobile Safari/535.19"
    getCSRFToken:(url,callback)->
        @client.request {
            url:url
            ,headers:{
                "user-agent":@mobileUserAgent
            }
            ,jar:@jar
        },(err,res,content)=>
            if err
                callback new Errors.NetworkError("fail to get csrf token due to network error",{via:err})
                return
            $ = cheerio.load content.toString()
            code = $("[name='csrf_id']").attr("content")
            if not code or code.toString().length isnt 20
                console.debug content.toString()
                callback new Errors.ParseError("invalid code",{code:code})
                return
            callback null,code
    toSourceModel:()->
        json = super()
        json.properties.jar = @jar.getSetCookieStringsSync("https://twitter.com/")
        return json
    @test = (uri)->
        return (new RegExp("twitter.com/([^/]+)/lists/([^/]+)$","i")).test(uri)
    
class TwitterListUpdater extends Source::Updater
    constructor:(@source)->
        super(@source)
        @timeout = 60 * 1000
        @minFetchInterval = 10 * 1000
        @userAgent = "Mozilla/5.0 (Linux; Android 4.2.1; en-us; Nexus 5 Build/JOP40D) AppleWebKit/535.19 (KHTML, like Gecko) Chrome/18.0.1025.166 Mobile Safari/535.19"
        
    atFetching:(sole)->
        if not @data.authorizeInfo.cookie
            @error new Errors.AuthorizationFailed("twitter initialize need authorize")
            return
        path = urlModule.parse(@source.uri).path
        pageUrl = urlModule.resolve "https://mobile.twitter.com/",path
        
        @source.getCSRFToken pageUrl,(err,code)=>
            
            @_fetchHasCheckSole = true
            if not @checkSole sole
                return
            if err
                @error err
                return
            requestUrl = "https://mobile.twitter.com/api/list_statuses"
            reg = new RegExp("twitter.com/([^/]+)/lists/([^/]+)$","i")
            match = @source.uri.match reg
            user = match[1]
            list = match[2]

            option = {
                url:requestUrl
                ,headers:{
                    "cookie":@source.jar.getCookieStringSync(requestUrl)
                    ,"user-agent":@userAgent
                    ,"referer":@source.uri
                } 
                ,method:"POST"
                ,timeout:15 * 1000
                ,data:{
                    slug:list
                    ,id:user
                    ,m5_csrf_tkn:code
                }
            }
            console.debug "initial request"
            @source.client.request option,(err,res,content)=>
                if not @checkSole sole
                    return
                if err
                    @error new Errors.NetworkError("fail to initialize",{via:err})
                    return
                
                content = content.toString()
                if res.headers["location"]
                    @error new Errors.AuthorizationFailed "recieve redirect maybe authorization outdated"
                    return
                try
                    data = JSON.parse content.toString()
                catch e
                    # he we may get broken json or none json
                    # for broken json it's a Network Error
                    # for none json, twitter unlike to return none json for any
                    # API so I suppose it's a network error as well
                    @error new Errors.ParseError("try get list status but return none json data. likeldue to network error",{content:content,via:e})
                    return
                if not data or not (data instanceof Array)
                    @error new Errors.AuthorizationFailed("lauching data not array likely to be authorization failed",{data:data})
                    return
                @data.rawFetchedArchives = data
                @setState "fetched"
    parseRawArchive:(data)->
        raw = data
        user = data.user
        originalLink = "https://twitter.com/#{user.screen_name}/status/#{raw.id}"
        title = user.screen_name
        content = twitterUtil.renderDisplayContent({archive:data})
        displayContent = content
        result =  {
            guid:"#{@source.type}_#{originalLink}"
            ,collectorName:@source.type
            ,type:@source.type
            ,createDate:new Date(raw.created_at) # it's hard to parse
            ,fetchDate:new Date()
            ,author:{
                name:user.screen_name
                ,avatar:user.profile_image_url
                ,link:user.profile_url
            }
            ,originalLink:originalLink
            ,sourceName:@source.name
            ,sourceUrl:"https://twitter.com/"
            ,sourceGuid:@source.guid
            ,title:title
            ,content:content
            ,displayContent:displayContent
            ,contentType:"html"
            ,attachments:[]
            ,meta:{
                raw:JSON.stringify({raw:raw,user:user})
            }
        }
        return result
            
class TwitterListInitializer extends Source::Initializer
    constructor:(@source)->
        super(@source)
        @userAgent = "Mozilla/5.0 (Linux; Android 4.2.1; en-us; Nexus 5 Build/JOP40D) AppleWebKit/535.19 (KHTML, like Gecko) Chrome/18.0.1025.166 Mobile Safari/535.19"
    atInitializing:(sole)->
        if not @data.authorizeInfo.cookie
            @error new Errors.AuthorizationFailed("twitter initialize need authorize")
            return
        path = urlModule.parse(@source.uri).path
        pageUrl = urlModule.resolve "https://mobile.twitter.com/",path
        console.debug "start csrf"
        @source.getCSRFToken pageUrl,(err,code)=>
            if not @checkSole sole
                return
            if err
                @error err
                return
            requestUrl = "https://mobile.twitter.com/api/list_statuses"
            reg = new RegExp("twitter.com/([^/]+)/lists/([^/]+)$","i")
            match = @source.uri.match reg
            user = match[1]
            list = match[2]

            option = {
                url:requestUrl
                ,headers:{
                    "cookie":@source.jar.getCookieStringSync(requestUrl)
                    ,"user-agent":@userAgent
                    ,"referer":@source.uri
                }
                ,timeout:30 * 1000
                ,data:{
                    slug:list
                    ,id:user
                    ,m5_csrf_tkn:code
                }
                ,method:"POST"
            }
            @source.client.request option,(err,res,content)=>
                if not @checkSole sole
                    return
                if err
                    @error new Errors.NetworkError("fail to initialize",{via:err})
                    return
                
                content = content.toString()
                if res.headers["location"] or content.length < 2 * 1024
                    @error new Errors.AuthorizationFailed("get redirect header or content is too small")
                    return
                result = @parseInitContent content
                if not result
                    @error new Errors.ParseError("fail to parse init content")
                    return
                    
                @data.guid = "twitterList_"+@source.uri
                @data.name = "Twitter list \"#{list}\" via #{user}"
                @data.prefetchArchiveBuffer = result.archives
                @setState "initialized"
    parseInitContent:(content)->
        try
            data = JSON.parse content
        catch e
            console.debug e
            return null
        if data not instanceof Array
            return null
        return {
            archives:(archive for archive in data)
        }
                
# Authorizer should provide @cookie
# should stored to @source.properties.cookie
querystring = require "querystring"
tough = require "tough-cookie"
https = require "https"
http = require "http"
urlModule = require "url"
Cookie = tough.Cookie
CookieJar = tough.CookieJar
httpUtil = global.env.httpUtil
class TwitterListAuthorizer extends Source::Authorizer
    constructor:(@source)->
        super(@source)
        @jar = @source.jar 
        @timeout = 1000 * 60
    atPrelogin:(sole)->
        @data.requireCaptcha = false
        preLoginUrl = "https://twitter.com/"
        option = {}
        option.url = preLoginUrl
        option.method = "GET"
        option.timeout = @timeout
        option.jar = @jar
        option.headers = {
            Referer:preLoginUrl
            ,"user-agent":null
        }
        @source.client.request option,(err,res,content)=>
            if not @checkSole sole
                return
            if err
                @error new Errors.NetworkError("fail to prelogin",{via:err})
                return
            content = content.toString()
            $ = cheerio.load content
            try
                data = JSON.parse $("#init-data").attr("value")
            catch e
            
                data = {}
            if not data.formAuthenticityToken
                @error new Errors.ParseError("fail to get prelogin data")
                return
                # check pin code in fureture here
            @data.preloginData = data
            @setState "prelogined"
    atLogining:(sole)->
        postData = {
            "session[username_or_email]":@data.username
            ,"session[password]":@data.secret
            ,remember_me:1
            ,return_to_ssl:"true"
            ,redirect_after_login:"/"
            ,authenticity_token:@data.preloginData.formAuthenticityToken
        }
        loginUrl = "https://twitter.com/sessions"
        option = {url:loginUrl}
        option.method = "POST"
        option.data = postData
        option.jar = @jar
        option.headers = {
            "Referer":loginUrl
            ,"User-Agent":""
        }
        console.debug "try login atttemp"
        @source.client.request option,(err,res,content)=>
            if not @checkSole sole
                return
            if err
                @error new Errors.NetworkError("fail to get prelogin data",{via:err})
                return
            
            content = content.toString()
            @data.postSessionResult = content
            if @data.postSessionResult.indexOf("error") > 0
                @error new Errors.AuthorizationFailed("invalid authentication info")
                return
                
            @data.authorized = true
            @data.cookie = @jar.getCookieStringSync("https://twitter.com")
            @data.authorizeInfo = {cookie:@data.cookie}
            @setState "authorized"
TwitterList::Updater = TwitterListUpdater
TwitterList::Initializer = TwitterListInitializer
TwitterList::Authorizer = TwitterListAuthorizer

module.exports = TwitterList
cheerio = require "cheerio"
Source = require "../../source/source.coffee"
urlModule = require "url"
EventEmitter = (require "events").EventEmitter
http = require "http"
twitterUtil = require "./twitterUtil.coffee"
ErrorDoc = require "error-doc"
Errors =  Source.Errors

console = console = env.logger.create __filename

class Twitter extends Source
    constructor:(info = {})->
        super info
        @type = "twitter"
        @client = new twitterUtil.TwitterRequestClient()
    @test = (uri)->
        return (new RegExp("twitter.com/?$","i")).test uri
        
class Updater extends Source::Updater
    constructor:(@source)->
        super(@source)
        @timeout = 60 * 1000
        @minFetchInterval = 10 * 1000
        @userAgent = "Mozilla/5.0 (Linux; Android 4.2.1; en-us; Nexus 5 Build/JOP40D) AppleWebKit/535.19 (KHTML, like Gecko) Chrome/18.0.1025.166 Mobile Safari/535.19"
    fetchAttempt:()->
        if not @source.authorizer.authorizeInfo.cookie
            @error new Errors.AuthorizationFailed("twitter require authorization")
            return
        requestUrl = "https://mobile.twitter.com/"
        option = {
            url:requestUrl
            ,headers:{
                
                "cookie":@source.authorizer.authorizeInfo.cookie
                ,"user-agent":@userAgent
            }
            ,timeout:@timeout
        }
        @source.client.request option,(err,res,content)=>
            if err
                @error new Errors.NetworkError("fail to fetch")
                return
            content = content.toString()
            if res.headers["location"] or content.length < 3 * 1024
                @error new Errors.AuthorizationFailed("recieve redirect or content too less likely to be")
                return

            $ = cheerio.load content.toString()
            try
                data = JSON.parse $("#launchdata").html()
            catch e
                data = null
            if not data
                @error new Errors.ParseError("fail to parse launchdata")
                return
            users = data.twitter_objects.users
            @rawFetchedArchives = ({archive:data.twitter_objects["tweets"][id],users:users} for id of data.twitter_objects["tweets"])
            @setState "fetchAttempted"
    parseRawArchive:(data)->
        raw = data.archive
        users = data.users
        user = users[raw.userId] or {}
        originalLink = "https://twitter.com/#{user.screen_name}/status/#{raw.id}"
        title = user.screen_name
        content = raw.text
        displayContent = twitterUtil.renderDisplayContent(data)
        result =  {
            guid:"#{@source.type}_#{originalLink}"
            ,collectorName:@source.type
            ,type:@source.type
            ,createDate:new Date(raw.created_at) # it's hard to parse
            ,fetchDate:new Date()
            ,authorName:user.screen_name
            ,authorAvatar:user.profile_image_url
            ,authorLink:"{raw.user.profile_url}"
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
            
class Initializer extends Source::Initializer
    constructor:(@source)->
        super(@source)
        @userAgent = "Mozilla/5.0 (Linux; Android 4.2.1; en-us; Nexus 5 Build/JOP40D) AppleWebKit/535.19 (KHTML, like Gecko) Chrome/18.0.1025.166 Mobile Safari/535.19"
    atInitializing:()->
        if not @source.authorizer.authorizeInfo.cookie
            @error new Errors.AuthorizationFailed("twitter initialize need authorize")
            return
        console.log "initializing..."
        requestUrl = "https://mobile.twitter.com/"
        console.log "with cookie",@source.authorizer.authorizeInfo.cookie
        option = {
            url:requestUrl
            ,headers:{
                "cookie":@source.authorizer.authorizeInfo.cookie
                ,"user-agent":@userAgent
            }
            ,timeout:15 * 1000
            ,method:"GET"
        }
        @source.client.request option,(err,res,content)=>
            if err
                @error new Errors.NetworkError("fail to initialize",{via:err})
                return
            content = content.toString()
            if res.headers["location"] or content.length < 2 * 1024
                @error new Errors.AuthorizationFailed("recieve redirect to too less content");
                return
            result = @parseInitContent content
            if not result
                @error new Errors.ParseError "fail to parse init content"
                return
            @source.guid = "twitter_#{result.id}"
            @source.name = "#{result.name}'s Twitter Timeline"
            @source.updater.prefetchArchiveBuffer = result.archives
            @setState "initialized"
    parseInitContent:(content)->
        $ = cheerio.load content.toString()
        try
            data = JSON.parse $("#launchdata").html()
        catch e
            console.debug e
            return null
            
        users = data.twitter_objects.users
        return {
            name:data.profile.name
            ,id:data.profile.id
            ,avatar:data.profile.profile_image_url
            ,archives:({archive:data.twitter_objects["tweets"][id],users:users} for id of data.twitter_objects["tweets"])
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
class Authorizer extends Source::Authorizer
    constructor:(@source)->
        super(@source)
        @jar = new CookieJar()
        @timeout = 1000 * 60
    prelogin:()->
        @requirePinCode = false
        preLoginUrl = "https://twitter.com/"
        option = {}
        option.url = preLoginUrl
        option.method = "GET"
        option.timeout = @timeout
        option.jar = @jar
        option.headers = {
            Referer:preLoginUrl
            ,"user-agent":null
            ,Cookie:@jar.getCookieStringSync(preLoginUrl)
        }
        @source.client.request option,(err,res,content)=>
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
                @error new Errors.UnkownError("fail to get prelogin data")
                return
                # check pin code in fureture here
            @preloginData = data
            @setState "prelogined"
    loginAttempt:()->
        postData = {
            "session[username_or_email]":@username
            ,"session[password]":@secret
            ,remember_me:1
            ,return_to_ssl:"true"
            ,redirect_after_login:"/"
            ,authenticity_token:@preloginData.formAuthenticityToken
        }
        loginUrl = "https://twitter.com/sessions"
        option = {url:loginUrl}
        option.method = "POST"
        option.data = postData
        option.headers = {
            "Referer":loginUrl
            ,"User-Agent":""
            ,"Cookie":@jar.getCookieStringSync(loginUrl)
            ,"Content-Type":"application/x-www-form-urlencoded"
        }
        option.jar = @jar
        console.debug "try login atttemp"
        @source.client.request option,(err,res,content)=>
            if err
                @error new Errors.NetworkError("fail to conduct login attempt due to network error");
                return
            console.debug "prelogin attempt"
            content = content.toString()
            @postSessionResult = content
            buffers = []
            @checkLogin()
    checkLogin:()->
        if @postSessionResult.indexOf("error") > 0
            @authorized = false
            @error new Errors.AuthorizationFailed("invalid authentication info")
            return
        @authorized = true
        @cookie = @jar.getCookieStringSync("https://twitter.com")
        @authorizeInfo = {@cookie}
        @setState "authorized"
Twitter::Updater = Updater
Twitter::Initializer = Initializer
Twitter::Authorizer = Authorizer

module.exports = Twitter
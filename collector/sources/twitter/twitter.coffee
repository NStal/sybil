cheerio = require "cheerio"
Source = require "../../source/source"
urlModule = require "url"
EventEmitter = (require "events").EventEmitter
http = require "http"
twitterUtil = require "./twitterUtil"
ErrorDoc = require "error-doc"
Errors =  Source.Errors
tough = require "tough-cookie"
CookieJar = tough.CookieJar

console = console = env.logger.create __filename

class Twitter extends Source
    constructor:(info = {})->
        @jar = new CookieJar()
        super info
        if info.properties and info.properties.jar
            for cookie in info.properties.jar
                @jar.setCookieSync cookie,"https://twitter.com/"
        @type = "twitter"
        @client = new twitterUtil.TwitterRequestClient({jar:@jar})
    toSourceModel:()->
        json = super()
        json.properties.jar = @jar.getSetCookieStringsSync("https://twitter.com/")
        return json
    @test = (uri)->
        return uri is "twitter" or (new RegExp("twitter.com/?$","i")).test uri

class TwitterUpdater extends Source::Updater
    constructor:(@source)->
        super(@source)
        @timeout = 60 * 1000
        @minFetchInterval = 10 * 1000

    atFetching:(sole)->
        if not @data.authorizeInfo.cookie
            @error new Errors.AuthorizationFailed("twitter initialize need authorize")
            return
        pageUrl = "https://mobile.twitter.com/"

        @source.client.getCSRFToken pageUrl,(err,code)=>
            @_fetchHasCheckSole = true
            if not @checkSole sole
                return
            if err
                @error err
                return
            requestUrl = "https://mobile.twitter.com/api/timeline"
            option = {
                url:requestUrl
                headers:{
                   "referer":"https://mobile.twitter.com/"
                }
                method:"POST"
                timeout:15 * 1000
                data:{
                    m5_csrf_tkn:code
                }
            }
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

class TwitterInitializer extends Source::Initializer
    constructor:(@source)->
        super(@source)
    atInitializing:(sole)->
        if not @data.authorizeInfo or not @data.authorizeInfo.cookie
            @error new Errors.AuthorizationFailed("twitter initialize need authorize")
            return
        @source.client.getCSRFToken "https://mobile.twitter.com/",(err,code)=>

            requestUrl = "https://mobile.twitter.com/api/profile"
            option = {
                url:requestUrl
                ,headers:{
                    referer:"https://mobile.twitter.com/"
                }
                ,timeout:15 * 1000
                ,method:"POST"
                ,data:{
                    m5_csrf_tkn:code
                }
            }
            @source.client.request option,(err,res,content)=>
                if not @checkSole sole
                    return
                if err
                    @error new Errors.NetworkError("fail to initialize",{via:err})
                    return
                if res.statusCode isnt 200
                    console.debug "code",code
                    console.debug "response",content.toString()
                    @error new Errors.AuthorizationFailed("fail to get user profile");
                    return
                result = @parseInitContent content
                if not result
                    @error new Errors.ParseError "fail to parse init content"
                    return
                @data.guid = "twitter_#{result.id}"
                @data.name = "#{result.name}'s Twitter Timeline"
                @data.prefetchArchiveBuffer = result.archives
                @setState "initialized"
    parseInitContent:(content)->
        try
            data = JSON.parse content
        catch e
            console.debug e
            return null
        return {
            name:data.profile.name
            ,id:data.profile.id
            ,avatar:data.profile.profile_image_url
            ,archives:[]
        }

# Authorizer should provide @cookie
# should stored to @source.properties.cookie
querystring = require "querystring"
https = require "https"
http = require "http"
urlModule = require "url"
Cookie = tough.Cookie
httpUtil = global.env.httpUtil
class TwitterAuthorizer extends Source::Authorizer
    constructor:(@source)->
        super(@source)
        @timeout = 1000 * 60
    atPrelogin:(sole)->
        @data.requireCaptcha = false
        preLoginUrl = "https://twitter.com/"
        option = {}
        option.url = preLoginUrl
        option.method = "GET"
        option.timeout = @timeout
        option.headers = {
            referer:preLoginUrl
            "user-agent":"Custom"
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
                @error new Errors.UnkownError("fail to get prelogin data")
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
        option.headers = {
            "referer":"https://twitter.com/"
            ,"content-type":"application/x-www-form-urlencoded"
            ,"user-agent":"custom"
        }
        @source.client.request option,(err,res,content)=>
            if not @checkSole sole
                return
            if err
                @error new Errors.NetworkError("fail to conduct login attempt due to network error",{via:err});
                return
            content = content.toString()
            @data.postSessionResult = content
            buffers = []
            @_checkLogin()
    _checkLogin:()->

        if @data.postSessionResult.indexOf("error") > 0
            console.debug @data.postSessionResult
            @data.authorized = false
            @error new Errors.AuthorizationFailed("invalid authentication info")
            return
        @data.authorized = true
        @data.cookie = @source.jar.getCookieStringSync("https://twitter.com")
        @data.authorizeInfo = {cookie:@data.cookie}
        @setState "authorized"
Twitter::Updater = TwitterUpdater
Twitter::Initializer = TwitterInitializer
Twitter::Authorizer = TwitterAuthorizer

module.exports = Twitter

# state
# init: nothing has done will try ask user secret
# localAuthed: username and secret is given try prelogin
# prelogined: prelogin data fetched
# prepared: after prelogin no pincode is needed or already go throught the pin code recognize process, next step is post login
# pinReady: pin code image is downloaded and
# posted: login posted, check success or retcode to do the correct things

Source = require "../../source/source.coffee"
EventEmitter = (require "events").EventEmitter
querystring = require "querystring"
createError = require "create-error"
tough = require "tough-cookie"
https = require "https"
http = require "http"
urlModule = require "url"
cheerio = require "cheerio"
Cookie = tough.Cookie
CookieJar = tough.CookieJar
ErrorDoc = require "error-doc"
Errors = exports.Errors = Source.Errors
exports.fetch = (info = {},callback)->
    cookie = info.cookie
    timeout = info.timeout or 30 * 1000
    url = "http://m.weibo.cn/searchs/searchFeed?&feature=0&uicode=20000060&rl=1&ext=plt%3A490&page=1" 
    option = urlModule.parse url
    option.method = "GET"
    option.headers = {
        "Cookie":cookie
    }
    req = http.request option,(res)->
        buffers = []
        res.on "data",(data)->
            buffers.push data
        res.on "end",()->
            try
                result = JSON.parse (Buffer.concat buffers).toString()
            catch e
                callback new Errors.ParseError("fail to parse result vai #{e}",{via:e})
                return
            if result.ok isnt 1
                callback new Errors.AuthorizationFailed("result.ok isnt 1")
                return
            callback null,result.mblogList or []
    hasTimeout = false
    req.on "error",(err)=>
        if hasTimeout
            callback new Errors.Timeout "max timeout #{timeout} exceed"
        else
            callback new Errors.NetworkError()
    req.setTimeout timeout,()=>
        hasTimeout = true
        req.abort()
    req.end()


exports.renderDisplayContent = (raw)=>
    $text = cheerio.load "<p class='tweet'>#{raw.text}</p>"
    $text("a").each ()->
        href = $text(this).attr("href")
        $text(this).attr("href",urlModule.resolve("http://weibo.com/",href))
    pics = raw.pic_ids or []
    pics.forEach (id)->
        $text(".tweet").append "<img src='http://ww1.sinaimg.cn/mw1024/#{id}'/>"
    if raw.retweeted_status
        retweet = exports.renderDisplayContent raw.retweeted_status 
        $text(".tweet").append retweet
    return $text.html()
## Source

You can implement a `Source` to turn anything into RSS-like. The life circle and error handling of a `Source` is predefined and shared, you only have to implement a few interface to get a quite stable and user responsive `Source`. 

Stable means a reasonable crawling interval, and some elegant error handling/retries.

User responsive means that the user can be fully aware of the crawler state, and can sometimes manually interfere the `Source`'s life circel. Say, I may want to force a `Source` to update herself, because I'm convinced that there must be some updates.

## Write a `Sources`

All the example code can be found at `example/` folder of the project. And feel free to try anything in the `playground/`.

Source related code are writen in a statemachine way, you can read the detail at [https://github.com/NStal/node-states](https://github.com/NStal/node-states).

As I mentioned above, `Source` has its life circle and error handlings. I will cover them latter, but for now we should have it in mind that we are only implementing a small part of the circle. Keep with this idea will make the example code make much more sense.

OK let's make a `Source`.

First make a directory at `playground/pixiv/`. Create a file `index.coffee` with following content. Again, all code can be found at `example/`.

```coffee-script
# `sybilRequire` require modules related to the root of the sybil proejct
Source = sybilRequire "collector/source/source.coffee"
class Pixiv extends Source
    constructor:(info)->
        @type = "pixiv"
        super(info)

class PixivInitializer extends Source::Initializer

class PixivAuthorizer extends Source:Authorizer

class PixivUpdater extends Source::Updater

Pixiv::Initializer = PixivIntializer
Pixiv::Authorizer = PixivAuthorizer
Pixiv::Updater = PixivUpdater
module.exports = Pixiv
```

Note we use `sybilRequire` to import a sybil module relate to the sybil project root. `sybilRequire` is a global variable provide by the `"core/env.coffee"`. We will import that file in our test file latter.

We are going to make a `Source` that index the famous doujin-art site [pixiv](http://pixiv.net).

`Source` are divided into three part, `Initializer`, `Authorizer`, `Updater`.

### `Initializer`

When we first subscribe a `Source`, we have to interact with initializer. Initializer is responsible for validate the source and invoke `Authorizer` if needed.

I want to make `Pixiv` collecting user's favorite doujin-authors art with a given pixiv account. So it should'nt work without authorizing. So our initializer may be like this.

```coffee-script
class PixivInitializer extends Source::Initializer
    atInitializing:()->
        if not @data.authorizeInfo or not @data.authorizeInfo.cookie
            @error Source.Errors.AuthorizationFailed("Pixiv require authorize")
            return
        
```

Note that we try to accessing `@data.authorizeInfo` to access authorize info, and errors. There are many things to explain here.

1. We store all data used in the life circle to `@data` object. So we can easily reset it and restart the life circle without mix up the data of previous life circle.  `node.js` is proven to be very weak against duplicated or unwanted async callback, which will cause unpredictable errors and be very very hard to hunt down. `@data` is one of my effort to avoid such problem. You can checkout the ideas at [https://github.com/NStal/node-states](https://github.com/NStal/node-states)

2. `@data.authorizeInfo` will be set by `class Pixiv` automatically, and is provided by `PixivAuthorizer`.If no authorizer provided or authorization not invoked, @data.authorizeInfo is promised to be a empty object `{}`.

3. `@error(err)` will bring the `PixivInitializer` to a `"panic"` state, and lifecircle will halt forever util the panic is recovered. The panic recovering is done by the parent module, in this case the `Pixiv`. Sybil treat errors very strict. When writing `Source`, you should always set errors defined in `Source.Errors` at `/collector/source/errors.coffee`. During initializing, a `AuthorizationFailed` will make `Pixiv` go through `PixivAuthorizer` then restart `Initializer`. Any other error will cause initialization failed, and will have user notified. Retry or not is left for user decision.

Now, we know the `PixivInitializer` can't get things done without `authorizeInfo`, so we come to complete the authorizer first.

### Authorizer

```coffee-script

tough = require "tough-cookie"
urlModule = require "url"
httpUtil = global.env.httpUtil

class PixivAuthorizer extends Source::Authorizer
    constructor:(@source)->
        super(@source)
        @jar = new tough.CookieJar()
        @timeout = 1000 * 10
    # Very lucky pixiv don't check csrf token or captcha at login
    # so we do not need a prelogin here you can skip it.
    # If your source need a captcha or a CSRF token, you can checkout
    # /collector/source/authorizer.coffee
    # Authorizer::atPrelogin/Authorizer::atPrelogined
    atLogining:(sole)->
        if not @data.username or not @data.secret
            @error new Source.Errors.AuthorizationFailed("Pixiv authentication requires a valid username and password")
            return
        loginUrl = "http://www.pixiv.net/login.php"
        params = {
            mode:"login"
            return_to:"/"
            pixiv_id:@data.username
            pass:@data.secret
            skip:1
        }
        # Set cookie jar
        # We use tough-cookie, hope you like it
        # https://github.com/goinstant/tough-cookie
        # By pass the jar as option, httpUtil
        # will automatically update cookies in the jar
        option = {
            url:loginUrl
            jar:@jar
            headers:{
                "Referer":"http://www.pixiv.net/"
                "Origin":"http://www.pixiv.net"
                "User-Agent":@UA
                "Accept":"text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8"
            }
            data:params
            timeout:@timeout
        }
        # You can use nodejs builtin http module as well.
        # Here we using the sybil builin httpUtil.
        httpUtil.httpPost option,(err,res,content)=>
            if not @checkSole sole
                return
            if err
                @error new Source.Errors.NetworkError("net work error at login",{via:err})
                return
            if not res.headers["set-cookie"]
                @error new Source.Errors.AuthorizationFailed("No cookie set, likely invalid username or password")
                return
            cookie = @jar.getCookieStringSync loginUrl
            # set authorize info here so `Pixiv` may pass it
            # to other modules that need it.
            @data.authorizeInfo = {cookie:cookie}
            @setState "authorized"

```

Sybil will handle user input of username and secret for you , you use them to do the authentication, that's it. Any error during authorizing will retry the entire authorizing process, which means user will be prompt for username/secret again.

Besides the comments, here are some breif explain about the above code.

1. Not every `Source` can work with only username and secret, some of them may require CSRF token, some even need to complete a captcha. All this actions should be happend before `atLogining`. They actually should be done `atPrelogin`, you can check the details at [/collector/source/authorizer.coffee](../../collector/source/authorizer.coffee)

2. After each async call, we invoked a `@checkSole sole`. This is another effort to eliminate the duplicate/invalid callback problems in nodejs we have mentions before. `sole` is the params you can recieve from an `atXXX` method. `@checkSole sole` will try to check the sole against the current `sole` of the state machine. If it does't match, just return immediately. In case the life circle changed or state machine are reset/stoped, sole will be changed, then sole's don't match, at last no duplicate callbacks will run then.

3. At last we call `@setState "authorized"`, to go to the next state `"authorized"`.This is how `Source` shares most of its codes, we set the @data and notify the state change. Data transfer between state machine are done by parent.


Authorizer is done, now time to complete our initializer.

```coffee-script
class PixivInitializer extends Source::Initializer
    atInitializing:(sole)->
        if not @data.authorizeInfo or not @data.authorizeInfo.cookie
            @error new Source.Errors.AuthorizationFailed("Pixiv require authorize")
            return
        # get authorize info try authorize
        # we do the validation by check the username exists
        option = {
            url:"http://www.pixiv.net/mypage.php"
            headers:{
                cookie:@data.authorizeInfo.cookie
            }
        }
        # more information for httpUtil please checkout /common/httpUtil.coffee
        httpUtil.httpGet option,(err,res,content)=>
            if not @checkSole sole
                return
            if err
                @error new Source.Errors.NetworkError("Fail to initialize due to network",{via:err})
                return
            # I use cheerio to do the DOM parsing.
            # https://github.com/cheeriojs/cheerio
            $ = cheerio.load content.toString()
            name = $("#page-mypage > div.ui-layout-west > section._unit.my-profile-unit > a > h1").text() or ""
            name = name.trim()
            if not name
                @error new Source.Errors.AuthorizationFailed("No username found likely due to network error")
                return
            # If you don't set guid, the default guid
            # for the source will be "#{@source.type}_#{@source.uri}"
            @data.guid = "pixiv_fav_#{name}"
            # Name that will be seen by user in GUI.
            @data.name = "#{name}'s favorate pixiv"
            # finally..
            @setState "initialized"
```

The code and comments above are quite self explained. Just make sure you have read them through.

Now we are going to implement an `Updater`.

### Updater
An `Updater` is reponsible for updating the source periodically. When it fails due to various reasons, we should either retry after certain amount of time or inform the user about the situation. 

`Updater` should implement 2 interfaces, `@atFetching` and `@parseRawArchive`. you should generally fetch the archives during `@atFetching` and save them to `@data.rawFetchedArchives` as a array. `@parseRawArchive` should parse them one by one into a [sybil archive](./archive.md). you can also read the source code in [collector/sources/] to see the live example.

```coffee-script
class PixivUpdater extends Source::Updater
    atFetching:(sole)->
        if not @data.authorizeInfo or not @data.authorizeInfo.cookie
            @error new Source.Errors.AuthorizationFailed("pixiv updater require authorize")
            return
        index = 1
        favUrl = "http://www.pixiv.net/bookmark_new_illust.php?p=#{index}"
        option = {
            url:favUrl
            headers:{
                cookie:@data.authorizeInfo.cookie
            }
        }
        httpUtil.httpGet option,(err,res,content)=>
            @_fetchHasCheckSole = true
            if not @checkSole sole
                return
            if err
                @error new Source.Errors.NetworkError("fail to get fav image due to network error",{via:err})
                return
            $ = cheerio.load content.toString()
            $images = $("#wrapper > div.layout-body > div > ul > li")
            results = []
            try
                $images.each ()->
                    node$  = $ this
                    title = node$.find("a.work > h1").text()
                    src = node$.find("a.work > div > img").attr("src")
                    user$ = node$.find "a.user.ui-profile-popup"
                    username = user$.attr("data-user_name")
                    userId = user$.attr("data-user_id")
                    userLink = user$.attr("href")
                    link = node$.find("a.work").attr("href")
                    urlData = urlModule.parse(link,true)
                    results.push {
                        title:title
                        link:link
                        illustId:urlData.query.illust_id
                        preview:src
                        username:username
                        userId:userId
                        userLink:userLink
                    }
            catch e
                @error new Source.Errors.ParseError "parse error after update",{via:e}
                return
            results = results.filter (item)->
                return item.illustId
            @data.rawFetchedArchives = results
            @setState "fetched"
    parseRawArchive:(archive)->
        # I will sanitize every thing at frontend by my best.
        # So you may not worry about XSS or something like that.

        siteUrl = "http://www.pixiv.net/"
        # resolve relative links

        if archive.link
            archive.link = urlModule.resolve siteUrl,archive.link
        if archive.userLink
            archive.userLink = urlModule.resolve siteUrl,archive.userLink

        content = "<a href='#{archive.link}'><img src='#{archive.preview}'/></a>"
        return {
            guid:"#{@source.type}_#{archive.link}"
            type:@source.type
            createDate:new Date()
            fetchDate:new Date()
            author:{
                name:archive.username
                link:archive.userLink
            }
            originalLink:archive.link
            sourceName:@source.name
            sourceUrl:@source.uri
            sourceGuid:@source.guid
            title:archive.username
            content:content
            contentType:"text/html"
            attachments:[]
            meta:{
                raw:archive
            }
        }
```

### Detecting.

There are only one small step to make this `Source` work. We need to know when user want to subscribe a `Pixiv` source. Here is how we do it.

```
class Pixiv extends Source
    @detectStream = (uri = "")->
        stream = new EventEmitter()
        process.nextTick ()->
            if uri.toLowerCase() is "pixiv" or new RegExp("pixiv.net","i").test(uri)
                stream.emit "data",new Pixiv()
            stream.emit "end"
        return stream

```
Every `Source` can be decide by a peace of string. May be an http link or some private scheme. Like `"http://blog.nstal.me/"`,`"feed://blog.nstal.me/entry.xml"`,`"http://twitter.com/"`,`"twitter"`

The `@detectStream` is a static method of a Source class that detect the source from that string.
1. How does it works?

Given a string type user input, if it's `"pixiv"` or something like `"http://pixiv.net/"`, then we consider the user want to subscribe the Pixiv source.

2. Why not just test and return a Pixiv instance.

Not every `Source` can decide if a string is a valid source identifider, and not every user input create only one `Source`.

Consider the RSS case, given a url "http://blog.nstal.me/hello", this url may be an atom-xml, or a html contains some RSS metas or without, or not even a available link. `@detectStream` must be make request to decide.

Also the RSS case, one link may create several Source. A standard wordpress blog entry will contain the blog rss and a comment rss as well. Is this case, multiple Sources can be returned.

3. Why return a EventEmitter , why not provide a callback, like other async actions?

It's for user experience. We may detect several `Source` from a single input after some decision. If one decision takes 1sec, another takes 10sec, then I have to wait for 10sec to get 2 results. But if you return a `EventEmitter`, I can notify user at 1sec and 10sec about the result when you emit a `"data"` event on it. This is every important for people in some place and I live in one of those places.

### Test it.

We can always install a plugin and test it using the human interface, but it's kind of annoying if we are at the beginning of the development. You can using a test helper to do the basic checks.

``` coffee-script
# Import the environment modules.
require "../../core/env.coffee"
# After import the env.coffee we can use sybilRequire
# to do the 'absolute' require with `sybilRequire`.
# We also using sybilRequire in `pixiv/index.coffee`. this allow
# our custom source to work no matter where the code source file is.
SourceBasicTester = sybilRequire("test/lib/sourceTester").SourceBasicTester

Pixiv = require("./index.coffee")
tester = new SourceBasicTester({Source:Pixiv})

# In normal test process we should only recieve on `"requireLocalAuth"` event
# unless we give an invalid username or password.
hasRequire = false
tester.on "requireLocalAuth",(handler)->
    if hasRequire
        console.log "local auth failed"
        process.exit(0)
    hasRequire = true
    # we use username/password in the environment.
    # you can set it shell using `export username=<username>`.
    handler(process.env.username,process.env.password)

tester.test()
```


### Instal it.

Make a symlink or copy from /example/pixiv to /customSources/pixiv , and restart the sybil.

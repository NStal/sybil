#weibo = require "../collector/weibo.coffee"
#collector = new weibo.WeiboCollector()
#collector.on "archive",(archive)->
#    console.log "get archive",archive
#collector.on "ready",()->
#    collector.start()

rss = require "../collector/rss2.coffee"
collector = new rss.RssCollector()
collector.on "archive",(archive)->
    console.log "get archive",archive.title
collector.on "ready",()->
    collector.start()

setTimeout (()->
    collector.addAndStartRssByLink("http://feeds.feedburner.com/JavascriptJabber",(err,rss)=>
        if err
            console.error err
            return
        console.log "add rss #{rss}"
        )
    ),2000

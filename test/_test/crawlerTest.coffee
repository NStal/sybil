rssFetcher = require "../crawler/rssFetcher.coffee"
fetcher = new rssFetcher.RssFetcher("http://bitinn.net/category/asides/feed/")
fetcher.fetch (err,info)->
    if err
        throw err
    console.log "meta",info.meta
    #console.log "articles",info.articles and info.articles.length
    #console.log "article",info.articles[0]
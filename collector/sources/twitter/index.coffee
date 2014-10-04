Source = require "../../source/source.coffee"
Errors =  Source.Errors
Twitter = require "./twitter.coffee"
TwitterList = require "./twitterList.coffee"
cheerio = require "cheerio"
console = console = env.logger.create __filename
Sources = [TwitterList,Twitter]
EventEmitter = (require "events").EventEmitter
class TwitterSource
    @Errors = Errors
    @create = (info)->
        for TwitterSource in Sources
            if TwitterSource.test info.uri
                return new TwitterSource(info)
        return null
    @detectStream = (uri)->
        stream = new EventEmitter()
        process.nextTick ()->
            for TwitterSource in Sources
                if TwitterSource.test uri
                    console.log "tests",TwitterSource.name
                    stream.emit "data", new TwitterSource({uri:uri})
                    stream.emit "end"
                    return
            stream.emit "end"
        return stream
    constructor:(info)->
        for Source in Sources
            if Source.test info.uri
                return new Source(info)
        console.error "broken info",info
        return
module.exports = TwitterSource

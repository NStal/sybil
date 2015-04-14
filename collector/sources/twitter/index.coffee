Source = require "../../source/source"
Errors =  Source.Errors
Twitter = require "./twitter"
TwitterList = require "./twitterList"
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
        sources = []
        for TwitterSource in Sources
            if TwitterSource.test uri
                console.log "tests",TwitterSource.name
                sources.push new TwitterSource({uri:uri})
        if sources.length is 0
            return null
        return Source.delayStream sources
    constructor:(info)->
        for Source in Sources
            if Source.test info.uri
                return new Source(info)
        console.error "broken info",info
        return
module.exports = TwitterSource

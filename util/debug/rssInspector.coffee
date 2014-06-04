settings = require("../../settings.coffee")
program = require("commander")
moment = require("moment")
program
    .option("-k, --keyword [keyword]","inspect rss contain keyword")
    .option("-l, --list","list all rss basic informations")
    .option("-t, --type [type]","rss type default is 'rss'")
    .option("-c, --config [config path]","use other config file than default")
    .option("-d, --database [database url]","something like mongo://host:port/dbname")
    .parse(process.argv);

printRssDetail = (rss,option = {})->
    console.log "RSS: #{rss.name}"
    console.log "Last Update: #{moment(rss.lastUpdate).fromNow()}"
    console.log "Interval: #{moment.duration(rss.nextInterval or 0).humanize()}"
    console.log rss
    console.log "EOR"
if not program.keyword and not program.list
    program.outputHelp()
    process.exit(0)
exit = (code)->
    process.exit(code or 0)
settings.parseConfig(program.config or "")
if program.database
    obj = require("url").parse program.database
    settings.dbName = obj.path.replace("/","")
    settings.dbHost = obj.hostname
    settings.dbPort = obj.port
db = require("../../core/db.coffee")
db.init()
db.ready ()=>
    type = program.type or "rss"
    db.Collections.collectorConfig.findOne {name:type},(err,rssInfos)->
        if program.list
            for rss in rssInfos.rsses
                console.log "#{rss.name}   |  #{rss.url}"
            exit()
        if program.keyword
            reg = new RegExp(program.keyword,"i")
            for rss in rssInfos.rsses
                if reg.test(rss.name) or reg.test(rss.url)
                    printRssDetail rss
            exit()
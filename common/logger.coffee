# a dirty module to dump
logPath = "./log"
moment = require "moment"
file = null
exports.setLogPath = (name)->
    logPath = name
    console.log "pipe log to #{name}"
    file = (require "fs").createWriteStream(logPath,{ flags: 'a' })
    #process.stdout.pipe(file)
    process.stderr.pipe(file)
exports.useColor = false
exports.create = (name)->
    return new Console(name)
# format should be
# 2013-09-03 19:32:40 [module-name] LOG:information [EOL]
class Console
    constructor:(@name)->
        @assert = console.assert.bind(console)
        @time = console.time.bind(console)
        @timeEnd = console.timeEnd.bind(console)
    log:(args...)->
        args.unshift(moment(new Date()).format("YYYY-MM-DD hh:mm:ss"),"LOG:[#{@name}]")
        args.push "[EOL]"
        console.log.apply console,args
    error:(args...)->
        args.unshift(moment(new Date()).format("YYYY-MM-DD hh:mm:ss"),"ERROR:[#{@name}]")
        args.push "[EOL]"
        console.error.apply console,args
    debug:(args...)->
        args.unshift(moment(new Date()).format("YYYY-MM-DD hh:mm:ss"),"DEBUG:[#{@name}]")
        args.push "[EOL]"
        console.error.apply console,args
    
        
        
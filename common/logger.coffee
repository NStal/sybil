# a dirty module to dump
logPath = "./log"
moment = require "moment"
pathModule = require "path"
fs = require "fs"
file = null
exports.setLogPath = (name)->
    logPath = name
    console.log "pipe log to #{name}"
    file = (require "fs").createWriteStream(logPath,{ flags: 'a' })
    #process.stdout.pipe(file)
    process.stderr.pipe(file)
exports.useColor = false
exports.create = (name)->
    name = name.replace(exports.root or "","")
    return new Console(name)
exports.setRoot = (root)->
    exports._root = root
# source map buffers
# format should be
# 2013-09-03 19:32:40 [file:line] LOG:information [EOL]

class SMBuffer
    constructor:()->
        @sms = {}
    getSourceMap:(path)->
        if @sms[path]
            return @sms[path]
        coffee = require("coffee-script")
        try
            code = (fs.readFileSync path).toString()
        catch e
            return null
        {sourceMap} = coffee.compile(code,{sourceMap:true,filename:path})
        @sms[path] = sourceMap
        return sourceMap


class Console
    @smBuffer = new SMBuffer()
    constructor:(@sourcePath)->
        @assert = console.assert.bind(console)
        @time = console.time.bind(console)
        @timeEnd = console.timeEnd.bind(console)
        @trace = console.trace.bind(console)
        @origin = console
    _getStackMessage:(callee,sourcePath)->
        b = Error.prepareStackTrace
        Error.prepareStackTrace = (_, stack) -> stack

        e = new Error()
        Error.captureStackTrace e, callee
        s = e.stack or []
        Error.prepareStackTrace = b
        target = null
        if @sourcePath
            for item,index in s
                if item.getFileName() is @sourcePath
                    target = item
                    break
            if not target
                target  = s[1]
        else
            target = s[1]
        if not target
            return ""
        file = target.getFileName()
        line = target.getLineNumber()
        col = target.getColumnNumber()
        if (pathModule.extname file) is ".coffee"
            map = Console.smBuffer.getSourceMap(file)
            if map
                answer = map.sourceLocation([line,col])
                if not answer
                    console.log "fail trace #{file}:L#{line}:C#{col}"
                [line,col] = answer or [line,col]
        if exports._root
            if file.indexOf(exports._root) is 0
                file = file.replace(exports._root,"")
        return "#{file}:#{line}:#{col}"
    log:(args...)->
        message = @_getStackMessage(arguments.callee,@sourcePath)
        args.unshift(moment(new Date()).format("YYYY-MM-DD hh:mm:ss"),"LOG:[#{message or @sourcePath}]")
        args.push "[EOL]"
        console.log.apply console,args
    error:(args...)->
        message = @_getStackMessage(arguments.callee,@sourcePath)
        args.unshift(moment(new Date()).format("YYYY-MM-DD hh:mm:ss"),"ERROR:[#{message or @sourcePath}]")
        args.push "[EOL]"
        console.error.apply console,args
    debug:(args...)->

        message = @_getStackMessage(arguments.callee,@sourcePath)
        args.unshift(moment(new Date()).format("YYYY-MM-DD hh:mm:ss"),"DEBUG:[#{message or @sourcePath}]")
        args.push "[EOL]"
        console.error.apply console,args

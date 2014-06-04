child_process = require "child_process"
settings = require("../settings.coffee")
exports.restart = ()->
    args = process.argv.slice(2)
    root = module
    while root.parent
        root = root.parent
    scriptPath = root.filename
    args.unshift scriptPath
    intepreter = process.argv[0]
    child_process.spawn intepreter,args,{env:process.env,detached:true,cwd:process.cwd(),stdio:["ignore",1,2]}
    process.exit(0)

exports.stop = (code)->
    process.exit(code or 0)

exports.exist = (pid)->
    try
        return process.kill(pid,0)
    catch e
        # if permission denied then some one must be running there (in usual case)
        return e.code is 'EPERM'
exports.background = (callback = ()->true)->
    if process.stdin and process.stdin.isTTY
        callback(true)
        exports.restart()
        process.exit(0)
    else
        callback(false)
        return
exports.ensureDeath = (pid)->
    # try my best to kill the process
    try
        while process.kill(pid,"SIGKILL")
            true
    catch e
        return
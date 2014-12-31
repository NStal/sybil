child_process = require "child_process"
settings = require("../settings.coffee")
exports.restart = ()->
    args = process.argv.slice(2)
    root = module
    while root.parent
        root = root.parent
    scriptPath = root.filename
    args.unshift scriptPath
    if process.env.SYBIL_COFFEE
        pathModule = require "path"
        intepreter = pathModule.resolve process.env.SYBIL_COFFEE
    else
        intepreter = process.argv[0]

    child_process.spawn intepreter,args,{env:process.env,detached:true,cwd:process.cwd(),stdio:["ignore",1,2]}
#    setTimeout (()->
#        process.exit(0)),0
    process.exit(0)
exports.stop = (code)->
    process.exit(code or 0)

exports.exist = (pid)->
    try
        return process.kill(pid,0)
    catch e
        # if permission denied then some one must be running there (in usual case)
        return e.code is 'EPERM'
exports.background = ()->
    exports.restart()
exports.ensureDeath = (pid)->
    # try my best to kill the process
    try
        while process.kill(pid,"SIGKILL")
            true
    catch e
        return

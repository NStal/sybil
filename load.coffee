commander = require "commander"
States = require "logicoma"
fs = require "fs"
os = require "os"
pathModule = require "path"
MongoServerManager = require "mongo-server-manager"
SybilInstance = require "/home/wuminghan/workspace/sybil-core/sybil-instance"
child_process = require "child_process"
program = commander
    .option("--debug","set debug mode")
    .parse(process.argv)
Errors = (require "error-doc").create()
    .define("DatabaseError")
    .generate()
DbRelativeConfig = {
    dbPath:"./db"
    host:"127.0.0.1"
    port:12309
    pidPath:"./db/mongod.lock"
    logPath:"./db/log"
    cwd:"./"
}
openUrl = (url)->
    if os.platform() is "linux"
        exec = "xdg-open"
    else if os.platform() is "darwin"
        exec = "open"
    child_process.spawn exec,[url],{detached:true,stdio:["ignore",1,2]}
class Loader extends States
    constructor:()->
        super()
        if program.debug
            console.log "enable debug mode"
            @debug()
        @root = "./"
        @root = pathModule.resolve @root
        @coffeePath = "./bin/coffee"
        @coffeePath = pathModule.resolve @root,@coffeePath
        @mongodPath = "./bin/mongod"
        @mongodPath = pathModule.resolve @root,@mongodPath
        @dbConfig = {
            host:DbRelativeConfig.host
            port:DbRelativeConfig.port
            cwd:pathModule.resolve @root,DbRelativeConfig.cwd
            dbPath:pathModule.resolve @root,DbRelativeConfig.dbPath
            pidPath:pathModule.resolve @root,DbRelativeConfig.pidPath
            logPath:pathModule.resolve @root,DbRelativeConfig.logPath
        }
        @openWebUI = true
    createUserConfig:( callback = ()-> )->
        cp = require("child_process").spawn(@coffeePath,["./guide/cli.coffee"])
        cp.on "exit",(code)->
            if code isnt 0
                callback new Errors "config creater return with none zeror",{code:code}
            else
                callback()
        cp.stdout.pipe process.stdout
        cp.stderr.pipe process.stderr
        process.stdin.pipe cp.stdin
    resolve:(path)->
        pathModule.resolve @root,path
    atPanic:()->
        console.error "fail to load sybil at state #{@panicState}"
        console.error @panicError
        process.exit(0)
    atStart:()->
        @setState "checkUserConfig"
    atCheckUserConfig:()->
        if fs.existsSync @resolve "./settings.user.json"
            @sybil = SybilInstance.createInstance @root,{stdio:["pipe","pipe","pipe"],args:["fork"]}

            console.log "create sybil instance"
            try
                @sybil.loadSettings()
            catch e
                console.error
                @error new Errors "fail to load setting file",{via:e}
                return
            @mongo = MongoServerManager.createInstance {
                host:@sybil.settings.dbHost or @dbConfig.host
                port:@sybil.settings.dbPort or @dbConfig.port
                pidPath:@dbConfig.pidPath
                dbPath:@dbConfig.dbPath
                logPath:@dbConfig.logPath
                binPath:@mongodPath
                stdout:process.stdout
                stderr:process.stderr
                cwd:@dbPath
            }
            @setState "checkDatabase"
        else
            @setState "createUserConfig"
    atCreateUserConfig:(sole)->
        @createUserConfig (err)=>
            if err
                console.error err
                console.error "fail to create user config, and try again."
                @setState "createUserConfig"
                return
            @setState "checkUserConfig"
    atCheckDatabase:(sole)->
        @mongo.isDaemonUp (err,pid)=>
            if @stale sole
                return
            if err or not pid
                @setState "ensureDatabase"
                return
            @mongo.isOnline (err,result)=>
                if not result
                    @setState "ensureDatabase"
                else
                    @setState "checkSybilInstance"
    atEnsureDatabase:(sole)->
        @mongo.stop (err)=>
            # try my best to stop it
            @setState "startDatabase"
    atStartDatabase:(sole)->
        @mongo.start (err)=>
            if @stale sole
                return
            if err
                @error Errors.DatabaseError("fail to start database",{via:err})
                return
            @setState "checkDatabase"
    atCheckSybilInstance:(sole)->
        @sybil.isDaemonUp (err,pid)=>
            if not pid
                @setState "ensureSybilInstance"
                return
            if @openWebUI
                @setState "checkWebUI"
            else
                @setState "done"
    atEnsureSybilInstance:()->
        # stop at my best
        @sybil.stop (err)=>
            @sybil.start (err)=>
                if err
                    @error err
                    return
                @setState "checkSybilInstance"

    atCheckWebUI:()->
        @sybil.waitServiceReady (err)=>
            if err
                console.error err
                @error new Error "fail to load web UI"
                return
            isUnix = os.platform() in ["linux","darwin"]
            url = @sybil.getWebUIAddress() + "#{@debug and "?debug=true" or ""}"
            if isUnix and process.env["DISPLAY"]
                openUrl url
            else
                console.log "no display detected, we are likely on a headless server"
                console.log "You can open #{url} to access the sybil."
                console.log "For external access other than localhost, the default username/password is sybil/libsy"
                console.log """
                you can set
                    "safeGatewayUsername":"your user name",
                    "safeGatewayPassword":"your password",
                """
                console.log "at #{pathModule.join @root,"./settings.user.json"}"
            @setState "done"
    atDone:()->
        console.log "loader complete"
        # don't exit the process
        # sybil may run at none fork mode

loader = new Loader()
console.log "start"
loader.setState("start")

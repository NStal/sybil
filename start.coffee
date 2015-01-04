# prepare settings, setup logs/pid/background states
# and finally load sybil, so neat.
fs = require "fs"

http = require "http"
http.globalAgent.maxSockets = 100 * 100;
https = require "https"
https.globalAgent.maxSockets = 100* 100;
settings = require("./settings.coffee")
pathModule = require "path"
logger = require("./common/logger.coffee")
try
    settings.parseConfig("./settings.user.json")
catch e
    console.error e
    console.error "fail to parse user config"
    console.error "panic"
    process.exit(1)

if process.argv[2] is "debug"
    settings.debug = true
if process.argv[2] is "settings"
    console.log settings[process.argv[3]] or ""
    process.exit(0)
logger.useColor = settings.logWithColor
logger.root = settings.root
# setup log redirections if log path is defined
try
    process.chdir __dirname
catch
    console.error "fail to change dir to",dirname
# do we have any clone running (and murder it :( )
pm = require("./common/processManager.coffee")
pidPath = settings.pidPath or "./pid"
if fs.existsSync(pidPath)
    pid = parseInt(fs.readFileSync(pidPath))
    if not isNaN pid
        pm.ensureDeath(pid)

# ensure it's running in background ( or suicide and respawn)
if not settings.debug and process.stdin and process.stdin.isTTY
    console.log "fork to background"
    if pidPath and fs.existsSync pidPath
        fs.unlinkSync pidPath
    pm.background()

if settings.logPath and not settings.debug
    logStream = fs.createWriteStream(settings.logPath,{flags:"a"});
    process.__defineGetter__ "stdout",()->logStream
    process.__defineGetter__ "stderr",()->logStream
if setttings.tempFolder
    if not fs.existsSync settings.tempFolder
        console.error "temp folder not available" pathModule.resolve settings.tempFolder
        process.exit(1)
# save pid
fs.writeFileSync(pidPath,process.pid)

# finally, start it!
require("./core/sybil.coffee")

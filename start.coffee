# prepare settings, setup logs/pid/background states
# and finally load sybil, so neat.
fs = require "fs"

http = require "http"
http.globalAgent.maxSockets = 200;
https = require "https"
https.globalAgent.maxSockets = 200;
settings = require("./settings.coffee")
logger = require("./common/logger.coffee")
try
    settings.parseConfig("./settings.user.json")
catch e
    console.error e
    console.error "fail to parse user config"
    console.error "panic"
    process.exit(1)

logger.useColor = settings.logWithColor
# setup log redirections if log path is defined
if process.argv[2] is "debug"
    settings.debug = true
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
if not settings.debug
    pm.background (aboutToDie)->
        if aboutToDie
            console.log "folk to background"

if settings.logPath and not settings.debug 
    logStream = fs.createWriteStream(settings.logPath,{flags:"a"});
    process.__defineGetter__ "stdout",()->logStream
    process.__defineGetter__ "stderr",()->logStream

# save pid
fs.writeFileSync(pidPath,process.pid)
require("./core/sybil.coffee")
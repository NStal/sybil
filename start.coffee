require("coffee-script")
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
#logger.setLogPath settings.logPath
require("./core/sybil.coffee")
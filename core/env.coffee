pathModule = require "path"

global.env = global.env || {}
global.env.logger = require "../common/logger"
global.env.logger.setRoot pathModule.resolve __dirname,"../"
global.env.settings = require "../settings"
global.env.httpUtil = require "../common/httpUtil"
pathModule = require "path"
root = pathModule.resolve __filename,"../../"
global.env.root = root

global.sybilRequire = (path)=>
    return require pathModule.join root,path

global.env = global.env || {}
global.env.logger = require "../common/logger.coffee"
global.env.settings = require "../settings.coffee"
global.env.httpUtil = require "../common/httpUtil.coffee"
pathModule = require "path"
root = pathModule.resolve __filename,"../../"
global.env.root = root

global.sybilRequire = (path)=>
    console.log pathModule.join root,path
    return require pathModule.join root,path

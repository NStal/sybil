module.exports = {
    processTitle:"sybil"
    dbName:"dbName"
    dbHost:"localhost"
    dbPort:"12309"
    dbPath:"./db"
    dbPidPath:"./db/mongod.pid"
    dbLogPath:"./db/mongod.log"
    dbOption:{}
    collectors:["rss","#pageWatcher"]
    proxies:[]
    # plugin name start with # won't be load, this can be used as a handy toggler
    plugins:[
        "webApi"
        "#sybilP2pNetwork"
        "resourceProxy"
        "#p2pWebApi"
        "safeGateway"
        "settingWebApi"
        "#runtimeShell"
        
    ]
    get:(name)->
       return dynamic[name] or null
    nickname:"anonymous"
    email:""
    webApiHost:"localhost"
    safeGatewayIp:"auto"
    webApiPort:3107
    privateKeyPath:"./rsa.key"
    pidPath:"./pid"
    hubServerHost:"localhost"
    hubServerPort:57612
    nodeServerHost:"localhost"
    nodeServerPort:57620
    nodeClientPort:5000
    logPath:"./sybil.log"
    logWithColor:false
    p2pSharePullInterval:5 * 60 * 1000
    pluginSettingsPath:require("path").join(__dirname,"./settings/")
    root:__dirname
}

dynamic = {}
dynamic.__defineGetter__ "proxy",() ->
    return module.exports.proxies[0] or null

dynamic.__defineGetter__ "server",() ->
    return module.exports.serverList[0]
parseConfig = (path)->
    # todo add check here
    if not path
        path = (require "path").join __dirname,"./settings.user.json"
    userSettings = JSON.parse (require "fs").readFileSync(path,"utf8")
    for prop of userSettings
        module.exports[prop] = userSettings[prop]
module.exports.parseConfig = parseConfig
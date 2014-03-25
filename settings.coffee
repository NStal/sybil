module.exports = {
    processTitle:"sybil"
    dbName:"dbName"
    dbHost:"localhost"
    dbPort:"12309"
    dbOption:{}
    collectors:["rss","#pageWatcher"]
    proxies:[]
    # plugin name start with # won't be load, this can be used as a handy toggler
    plugins:[
        "webApi"
        "sybilP2pNetwork"
        "resourceProxy"
        "p2pWebApi"
        "safeGateway"
        "settingWebApi"
        "#externalProxy"      # as a reverse proxy to allow remote access
        "#runtimeShell"
        
    ]
    get:(name)->
       return dynamic[name] or null
    nickname:"moe moe Q"
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
}

dynamic = {}
dynamic.__defineGetter__ "proxy",() ->
    return module.exports.proxies[0]

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
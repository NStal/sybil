settings = require("../../settings.coffee")
exports.register = (dep,callback)->
    sybilP2pNetwork = require("./main.coffee")
    keyString = require("fs").readFileSync(settings.privateKeyPath,"utf8").toString()
    RSA = require("../../common/rsa.coffee")
    privateKey = new RSA.RSAPrivateKey(keyString)
    profile = {
        email:settings.email
        nickname:settings.nickname
    }
    option = {
        hubServers:[{host:settings.hubServerHost,port:settings.hubServerPort}]
        ,nodeServers:[{host:settings.nodeServerHost,port:settings.nodeServerPort}]
        ,nodeClientPort:settings.nodeClientPort or 5000
    }
    sybilP2pNetwork.setup privateKey,profile,option,()->
        console.log "p2p server is ready"
        callback null,sybilP2pNetwork
exports.requires = []
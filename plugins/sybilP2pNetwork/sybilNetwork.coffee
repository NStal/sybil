Lord = require("./network/lord");
KadDomain = require("./network/kad/domain")
StandardConnectionProvider = require("./network/connection/standardConnectionProvider")
# 1. Contains a kad domain thus can look up a publicKey
# 2. Recover random connections from a array of addresses
# 3. Can add connection accept nodes as callback
class SybilNetwork extends Lord
    constructor:(@key,option = {})->
        super @key
        @kadDomain = new KadDomain()
        @addDomain @kadDomain
        standardHost = option.standardHost || "0.0.0.0"
        standardPort = option.standardPort || 5237
        @standardConnectionProvider = new StandardConnectionProvider(standardPort,standardHost)
        @connectionManager.addConnectionProvider @standardConnectionProvider
    start:()->
        @standardConnectionProvider.startListening()
        @emit "ready"
        
module.exports = SybilNetwork
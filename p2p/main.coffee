Lord = require("./network/lord.coffee")
NodeProvider = require("./network/nodeProvider.coffee")
Domain = require("./network/domain.coffee")

# support direct p2p connection and hub like center server connection.
#dcNodeProvider = new NodeProvider.DirectConnectionProvider()
hubNodeProvider = new NodeProvider.HubProvider()
hubNodeProvider.addServer("sybil.nstal.me",57611)

sybilDomain = new SybilDomain("sybil reader")


lord = new Lord()
#lord.addNodeProvider dcNodeProvider
lord.addNodeProvider hubNodeProvider
lord.addDomain sybilDomain

sybilDomain.onNode = (node)->
    node.messageCenter.registerApi "sybilReader/entry",(data,callback)->
        callback null
    node.messageCenter.registerApi "sybilReader/getShare",(data,callback)->
        
    

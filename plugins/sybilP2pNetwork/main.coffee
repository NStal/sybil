Lord = require("./network/lord.coffee")
NodeProvider = require("./network/nodeProvider.coffee")
Domain = require("./network/domain.coffee")
Database = require("../../core/db.coffee")
console = console = require("../../common/logger.coffee").create("SybilP2pMain")
SybilShareCollector = require("./sybilShareCollector.coffee")
sybil = require("../../core/sybil.coffee")


sybilDomain = new Domain("sybilReader")
sybilShareCollector = new SybilShareCollector()

sybilDomain.handleNode = (node)->
    console.log "handle node inside sybil"
    node.messageCenter.registerApi "sybilReader/entry",(data,callback)->
        if not node.isAuthed
            callback "authorization failed"
            return
        sybilDomain.addNode node
        callback null
    node.messageCenter.invoke "sybilReader/entry",{},(err)->
        if err
            return
        sybilDomain.addNode node
sybilDomain.onAddNode = (node)->
    console.debug "get a sybil bros!"
    sybilShareCollector.addNode node
    node.messageCenter.registerApi "sybilReader/getShare",(data,callback)->
        count = data.count or 50
        Database.getShareArchive {count:count},(err,archives)->
            if err
                callback "unkown error"
                return
            callback null,archives
    
sybilP2pNetwork = {}
module.exports = sybilP2pNetwork
sybilP2pNetwork.setup = (privateKey,profile,options = {},callback)->
    lord = new Lord(privateKey,profile)
    hubNodeProvider = new NodeProvider.HubProvider()
    directNodeProvider = new NodeProvider.DirectConnectionProvider(options.nodeClientPort)

    sybilP2pNetwork.lord = lord
    sybilP2pNetwork.sybilDomain = sybilDomain
    sybilP2pNetwork.sybilShareCollector = sybilShareCollector
    sybilP2pNetwork.hubNodeProvider = hubNodeProvider 

    lord.once "ready",()->
        console.debug "lord is ready"
        options.servers = options.servers or []
        for server in options.hubServers 
            hubNodeProvider.addServer(server.host,server.port)
        lord.addNodeProvider hubNodeProvider
        for server in options.nodeServers
            directNodeProvider.addServer server.host,server.port
        lord.addNodeProvider directNodeProvider
        
        lord.addDomain sybilDomain
        
        sybilP2pNetwork.lord = lord
        sybilP2pNetwork.hubNodeProvider = hubNodeProvider
        sybilP2pNetwork.sybilShareCollector = sybilShareCollector
        sybilP2pNetwork.sybilShareManager = new SybilShareCollector.Manager(sybilShareCollector)
        sybil.collectorClub.addManager sybilP2pNetwork.sybilShareManager
        callback sybilP2pNetwork

        setInterval lord.discover.bind(lord),60 * 1000
        setTimeout lord.discover.bind(lord),1000
        watch = ()->
            console.log "current node count:",lord.nodes.length
        setInterval watch,1000 * 60
    lord.once "error",()->
        callback err
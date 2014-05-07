kademlia = require("node-kademlia")
Kad = kademlia.Kad
class KadNetwork extends Kad



class KadNode extends kademlia.Node
    constructor:(sybilNode)->
        if sybilNode.kadNode
            return sybilNode.kadNode
        var hashBuffer = new Buffer(sybilNode.publicKey.getHash(),"hex")
        var id = new kademlia.NodeId(hashBuffer);
        super id,{node:sybilNode}
        
        @sybilNode = sybilNode
        @_setupMessageCenter()
        @sybilNode.kadNode = this
        @maxNearestSearchCount = 50
        return this
    _setupMessageCenter:()->
        @sybilNode.channel.registerApi "kademlia/nearest",@getNearestNodeInfo.bind(this)
    getNearestNodeInfo:(option = {},callback = ()->true )->
        var count = option.count or 20;
        if count > maxNearestSearchCount
            count = maxNearestSearchCount
        if Buffer.isBuffer option.target
            callback "Invalid Request"
            return
        if option.target.length is @id.length
            callback "Unsupported Target Id"
            return
        infos = @nearest option.target,count
        for {distance:distance,node:node} in infos
            kadNode = node
            
exports.KadNetwork = KadNetwork
exports.KadNode = KadNode
exports.KadId = kademlia.NodeId
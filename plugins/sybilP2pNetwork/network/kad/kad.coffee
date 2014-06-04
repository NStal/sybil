kademlia = require("node-kademlia")
Kad = kademlia.Kad
class KadNetwork extends Kad
    constructor:(@idBuffer,@domain)->
        @kadNodes = []
        @maxNearestSearchCount = 50
    getNearestNodeInfo:(option = {})->
        count = option.count or 20
        if count > @maxNearestSearchCount
            count = @maxNearestSearchCount
        if Buffer.isBuffer option.target
            callback "Invalid Request"
            return
        if option.target.length isnt @id.length
            callback "Unsupported Target Id"
            return
        infos = @nearest option.target,count
        results = []
        for {distance,node} in infos
            results.push {
                disntace:distance
                ,addresses:node.sybilNode.channel.getAddresses()
                ,id:node.id
            }
        return results

class KadNode extends kademlia.Node
    constructor:(sybilNode)->
        if sybilNode.domainInfo and sybilNode.domainInfo.kad and sybilNode.domainInfo.kad.kadNode
            return sybilNode.domainInfo.kad.kadNode
        hashBuffer = sybilNode.publicKey.getHash("binary")
        id = new kademlia.NodeId(hashBuffer);
        super id,{node:sybilNode}
        @sybilNode = sybilNode
        return this
        
            
exports.KadNetwork = KadNetwork
exports.KadNode = KadNode
exports.KadId = kademlia.NodeId
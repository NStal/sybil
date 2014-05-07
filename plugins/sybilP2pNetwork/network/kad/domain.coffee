Domain = require("../domain.coffee")
KadNetwork = require("./kad").KadNetwork
KadNode = require("./kad").KadNode
class KadDomain extends Domain
    constructor:(option = {})->
        super()
        @idLength = option.idLength or 
        @network = new KadNetwork()
    handleNode:(node)->
        if node.domainInfo.kad
            return
        if not node.key
            return
        keyHash = node.key.getHash("binary")
        nodeId = new nodeId(keyHash)
        kadNode = new KadNode(node)
        node.domainInfo.kad =
            domain:this
            kadNode:kadNode
        @_tryAddNodeToNetwork node
    _tryAddNodeToNetwork:(node)->
        # node should be already initialized
        
module.exports = KadDomain


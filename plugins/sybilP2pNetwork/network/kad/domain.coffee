Domain = require("../domain.coffee")
KadNetwork = require("./kad").KadNetwork
KadNode = require("./kad").KadNode
Key = require("../key")
class KadDomain extends Domain
    @Error = {
        InvalidId:"InvalidId"
    }
    constructor:(@key,option = {})->
        super()
        console.assert @key instanceof Key.MasterKey
        @key.getPublicKey (err,publicKey)=>
            if err
                @emit "error",err
                return
            @publicKey = publicKey
            @idBuffer = @publicKey.getHash("binary")
            @idLength = @idBuffer.length
            @network = new KadNetwork(@idBuffer,this)
            @emit "ready"
    handleNode:(node)->
        if not @network
            return
        if node.domainInfo.kad
            return
        if not node.key
            return
        @_attachNode node
    search:(id,callback)->
        # an standard kad search
        if not Buffer.isBuffer id or id.length isnt @idBuffer.length
            callback KadDomain.InvalidId
            return
            
    _attachNode:(node)->
        keyHash = node.key.getHash("binary")
        nodeId = new nodeId(keyHash)
        node.domainInfo.kad = {} 
        kadNode = new KadNode(node)
        node.domainInfo.kad.kadNode = kadNode
        node.domainInfo.kad.domain = this
        @network.add kadNode
        node.listenBy this,"close",()=>
            @_detachNode node
        channel = node.channel
        channel.registerApi "getNearestNodeInfo",(option,callback)=>
            info = @network.getNearestNodeInfo option
            callback null,info
        @addNode node
    _detachNode:(node)->
        @removeNode node
        return
module.exports = KadDomain


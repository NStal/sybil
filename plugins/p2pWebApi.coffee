exports.requires = ["webApi","sybilP2pNetwork"]
extractNodeInfo = (node)->
    publicKey = node.publicKey and node.publicKey.toString() or null
    hash = node.publicKey and node.publicKey.getHash() or null
    profile = node.profile or {}
    console.log profile
    info =  {
        publicKey:publicKey
        ,hash:hash
        ,keyHash:hash
        ,profile:profile
        ,id:node.id
        ,online:not node.isClose
    }
    console.log info
    return info
exports.register = (deps,callback)->
    p2pNetwork = deps.sybilP2pNetwork
    domain = p2pNetwork.sybilDomain
    lord = p2pNetwork.lord
    messageCenters = []
    domain.on "node",(node)->
        # only provide authed node
        fireUpdate = ()=>
            for mc in messageCenters
                mc.fireEvent "node/change",extractNodeInfo node
        node.on "close",fireUpdate
        node.on "auth",fireUpdate
        node.on "update",fireUpdate
        node.on "profile",fireUpdate
    deps.webApi.on "destroyMessageCenter",(mc)->
        for item,index in messageCenters
            if item is mc
                messageCenters.splice(index,1)
                return
    deps.webApi.on "messageCenter",(mc)->
        messageCenters.push mc
        mc.registerApi "getP2pNode",(option,callback)->
            result = []
            for node in domain.nodes
                # only provide authed node
                result.push extractNodeInfo node
            callback null,result
    callback null,{}

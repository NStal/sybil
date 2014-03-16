# Lord is the sybil network gateway that collecting/looking up other node in the sybil
# network, and do what upper application layer suggest.
#
# Lord will handle the node connection/disconnection , publicKey authorization
# , node discover. Lord don't remember anything, application layer is responsible
# to hint the Lord when to add node, what node to add, what node to block
#
EventEmitter = (require "events").EventEmitter
Tasks = require("node-tasks")
Profile = require("./profile.coffee")
console = require("../../../common/logger.coffee").create("P2p/Lord")
RSA = require("../../../common/rsa.coffee")
class Lord extends EventEmitter
    constructor:(privateKey,@profile = {})->
        @nodes = []
        @domains = []
        @nodeProviders = []
        @handleNode = @handleNode.bind(this)
        @privateKey = privateKey
        @pingInterval = 60 * 1000
        @privateKey.extractPublicKey (err,pubkey)=>
            if err
                @emit "error",err
                return
            @publicKey = pubkey
            @emit "ready"
        @publicKeyMap = {}
    setPrivateKey:(key)->
        @privateKey = key
    authNode:(node,callback)->
        console.log "try auth node #{node.address.toString()}"
        node.messageCenter.invoke "getAuthToken",{key:@publicKey.toString()},(err,token)=>
            if err
                callback err
                return
            signature = @privateKey.sign new Buffer(token.toString())
            console.log "get auth token of #{node.address.toString()}"
            node.messageCenter.invoke "auth",{signature:signature},(err)=>
                if err
                    callback err
                    return
                console.log "auth with #{node.address.toString()}"
                node.messageCenter.invoke "setProfile",@profile,(err)=>
                    if err
                        callback err
                        return
                    console.log "setProfile of #{node.address.toString()}"
    handleNode:(node)->
        @nodes.push node
        console.log "get to node #{node.address.toString()}"
        node.once "close",()=>
            if node.pingChecker
                clearTimeout node.pingCheker
                node.pingCheker = null
            for item,index in @nodes
                if item is node
                    @nodes.splice(index,1)
                    return
        @setupNodeMessageCenter(node)
        ping = ()->
            node.messageCenter.invoke "ping",(err,result)->
                if err or result isnt "pong"
                    node.close()
        node.pingCheker = setInterval ping,@pingInterval
        @authNode node,(err)->
            if err and not node.isClose
                console.debug err
                console.debug "fail to auth node and close it"
                node.close()
                return
            node.isRemoteAuthed = true
        node.once "auth",()=>
            @addAuthedNode(node)
    addAuthedNode:(node)->
        pk = node.publicKey.toString("hex")
        oldNode =  @publicKeyMap[pk]
        if oldNode
            if @firstAddressIsBetterOrSame(oldNode.getAddress(),node.getAddress())
                # same prirotity but the old node is always has a bigger create date
                # which usually means more stable, so we use the old node
                node.close()
                return
            else
                oldNode.close()
        @publicKeyMap[pk] = node
        node.once "close",()=>
            if @publicKeyMap[pk] is node
                delete @publicKeyMap[pk]
    firstAddressIsBetterOrSame:(a1,a2)->
        url = require("url")
        u1 = url.parse(a1.toString())
        u2 = url.parse(a2.toString())
        # first using sybil:
        # can't be better
        if u1.protocol is "sybil:"
            return true
        # second use sybil: and first not sybil:
        # second is better
        if u2.protocol is "sybil:"
            return false
        # unkown, using the first by default
        return true
    addDomain:(domain)->
        @domains.push domain
        for node in @nodes
            domain.handleNode
    removeDomain:(domain)->
        for item,index in @domains
            if item is domain
                @domains.splice index,1
                return true
        return false
    addNodeProvider:(provider)->
        provider.on "node",@handleNode
        @nodeProviders.push provider
    removeNodeProvider:(provider)->
        provider.removeListener("node",@handleNode)
    setupNodeMessageCenter:(node)->
        node.messageCenter.registerApi "ping",(data,callback)->
            callback(null,"pong")
        node.messageCenter.registerApi "getAuthToken",(data = {},callback)=>
            if not data.key
                callback "missing public key"
                return
            if not node.token
                node.token = (Math.random()).toString()
            try
                console.log data.key
                node.publicKey = new RSA.RSAPublicKey(data.key)
                if node.publicKey.toString("hex") is @publicKey.toString("hex")
                    node.close()
            catch e
                node.publicKey = null
                console.error e
                callback "invalid public key"
                return
            console.debug "get token request"
            callback null,node.token
        node.messageCenter.registerApi "getAuthState",(_,callback)->
            callback null,{isAuthed:node.isAuthed}
        node.messageCenter.registerApi "setProfile",(data = {},callback)->
            if not node.isAuthed
                callback "authorization failed"
                return
            profile = Profile.parse(data)
            if not profile
                callback "invalid profile data"
                return
            node.profile = profile
            node.emit "profile"
            callback null
            
                
        node.messageCenter.registerApi "auth",(data = {},callback)=>
            console.debug "get auth request"
            if node.isAuthed
                callback "already authorized"
                return
            if not node.token
                callback "no auth token found"
                return
            if not node.publicKey
                callback "no public key provided"
                return
            signature = data.signature
            if typeof signature isnt "string"
                console.error signature,typeof signature
                callback "invalid signature"
                return
            try
                isVerified = node.publicKey.verify new Buffer(node.token.toString()),signature
            catch e
                console.error e
                callback "invalid signatrue"
                return
        
            if isVerified
                node.isAuthed = true
                
                node.emit "auth",node
                for domain in @domains
                    domain.handleNode node
                callback null
            else
                node.isAuthed = false
                callback "verification failed"
        node.messageCenter.registerApi "getNodes",(option = {},callback)->
            # we don't need to be authed to get nodes
            count = option.count or 1000
            nodes = @nodes.filter (node)->node.isAuthed
            addresses = nodes.map (node)->node.getAddress()
            addresses = address.filter (item)->item
            callback null,addresses.slice(0,count)
    discover:(callback = ()->true)->
        if @isDiscovering
            callback "already discovering"
            return
        # prevent double discovering
        console.log "lord -- deiscovering"
        @isDiscovering = true
        require("async").each @nodeProviders,((nodeProvider,done)->
            # we assume that there won't be any same node provider
            console.log "with node provider",nodeProvider.name
            nodeProvider.discover ()->
                console.log("done discover with",nodeProvider.name)
                done()
        ),()=>
            @isDiscovering = false
            console.debug "discover done"
            callback()
        # NOT DONE
    clearNodeMessageCenter:(node)->
        node.messageCenter.removeAllListener()
    clear:()->
        for nodeProvider in @nodeProviders
            nodeProvider.close()
module.exports = Lord;

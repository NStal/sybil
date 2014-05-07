console = require("../../../common/logger.coffee").create("P2p/Lord")
EventEmitter = require("eventex").EventEmitter
MessageCenter = require "message-center"
Node = require("./node")
Procedure = require("./procedure")
Key = require("./key")
ConnectionManager = require("./connection/manager")
async = require("async")
class Lord extends EventEmitter
    constructor:(@key)->
        console.assert @key instanceof Key.MasterKey

        super()
        @nodes = []
        @domains = []

        @connectionManager = new ConnectionManager(this);
        
        # There are possible to have connection outside the management of lord
        # but any incoming connection should under management of lord
        # and distribute only by lord. And as long as the lord is in charge of
        # any connection, the Node/Channel that connection belongs to is also
        # considered a shared resource (say for domains).
        # On the other hand, any connection other than
        # 
        # 'incoming' hints that the connections are not build for specific reason
        # Though it's not necessarily really a incoming connection via listen.
        @connectionManager.listenBy this,"connection/incoming",this.bridge

    bridge:(connection,callback = ()-> true)-> 
        # Touch State:
        # An auther to try to get authed
        
        # any reason it's already Linked (has a chanel and node)
        # so just callback successfully
        if not connection
            throw new Error "invalid connection"
            return
        if connection.channel and connection.channel.node
            callback null,connection.channel.node
            return
        connection.messageCenter.setConnection connection
        connection.once "close",()=>
            connection.messageCenter.unsetConnection()
        auther = new Procedure.ConnectionAuther(this,connection);
        # procedure end due to complete or failed or timeout
        auther.once "end",()=>
            if auther.connection.publicKey and auther.isReady
                @mergeBridgedConnection auther.connection,(err,node)=>
                    callback err,node
            else
                callback auther.lastError or new Error "fail to bridge"
                auther.disconnect()
        auther.gainTrust (err)->
            if err
                auther.disconnect()
    addDomain:(domain)->
        if domain not in @domains
            domain.setLord this
            @domains.push domain
    removeDomain:(domain)->
        for item,index in @domains
            if item is domain
                domain.unsetLord()
                @domains.splice(index,1)
                return
    mergeBridgedConnection:(connection,callback = ()->true )->
        if not connection.publicKey
            throw new Error "invalid connection"
        for node in @nodes
            if node.key.equal connection.publicKey
                node.mergeConnection connection
                callback null,node
                return
        node = new Node(this,connection.publicKey,{connections:[connection]})
        @emit "node",node
        @_handleNode node
        node.once "destroy",()=>
            for item,index in @nodes
                if item is node
                    @nodes.splice(index,1)
                    return
        @nodes.push node
        callback null,node
    _handleNode:(node)=>
        for domain in @domains
            domain.handleNode node
    addRandomConnections:(addresses = [],callback = ()-> true)->
        count = 0
        async.eachLimit addresses,1,((address,done)=>
            @connectionManager.createConnection address,(err,connection)=>
                if err
                    done()
                    return
                @bridge connection,(err)=>
                    if err
                        done()
                        return 
                    count++
                    done()
            ),(err)->
                callback null,count
module.exports = Lord

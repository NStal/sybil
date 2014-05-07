child_process = require("child_process")
RSA = require "../../common/rsa.coffee"
serverPort = 10243
Server = {}
Ann = {}
Bob = {}
NodeModule = require("../../p2p/node.coffee")
CenterServer = require("../../../sybil-center-server/centerServer.coffee").CenterServer
CenterServerInterface = require("../../p2p/centerServerInterface.coffee").CenterServerInterface
VirtualConnectionNodeProvider = require("../../p2p/centerServerInterface.coffee").VirtualConnectionNodeProvider

describe "test all p2p functions with real instance",()->
    it "create center server",(done)->
        Server.server = new CenterServer(serverPort)
        Server.server.listen()
        done()
    it "create RSA for Ann",(done)->
        RSA.generatePrivateKey (err,key)->
            Ann.privateKey = key
            RSA.extractPublicKey key,(err,pub)->
                Ann.publicKey = pub
                done(err)
    it "create interface for Ann and Bob",(done)->
        Ann.inf = new CenterServerInterface("localhost",serverPort)
        Ann.inf.connectToServer()
        Ann.inf.on "ready",()->
            console.log "ann connected"
            Bob.inf = new CenterServerInterface("localhost",serverPort)
            Bob.inf.connectToServer()
            Bob.inf.on "ready",()->
                done()
    it "create Domain and setup node provider for Bob",(done)->
        Bob.domain = require(require("path").join(__dirname,"../../p2p/p2pNodeServer.coffee")).Server
        Bob.nodeProvider = new VirtualConnectionNodeProvider(Bob.inf)
        Bob.domain.addNodeProvider Bob.nodeProvider
        done()
    it "getAddress of Bob",(done)->
        Bob.inf.messageCenter.invoke "getAddress",null,(err,address)->
            console.assert address
            Bob.address = address
            done()
    it "Connect ann to bob should add a node",(done)->
        Ann.inf.createVirtualConnection Bob.address,(err,connection)->
            if err
                throw err
            Ann.connectionToBob = connection
            Ann.BobNode = new NodeModule.Node(connection)
            console.assert Bob.domain.nodes.length is 1
            done()
    it "Request auth token from Bob",(done)->
        
        Ann.BobNode.messageCenter.invoke "getAuthToken",{key:Ann.publicKey.toString()},(err,token)->
            console.assert token
            Ann.tokenOfBob = token
            done()
    it "request auth",(done)->
        signature = Ann.privateKey.sign(new Buffer(Ann.tokenOfBob))
        Ann.BobNode.messageCenter.invoke "auth",{signature:signature},(err)->
            console.assert not err
            done()
    it "request auth state should return without error",(done)->
        Ann.BobNode.messageCenter.invoke "getAuthState",null,(err,state)->
            console.log err,state
            console.assert state
            console.assert state.auth is true
            done()
    
        
describe "Test virtual node connections",()->
    CenterServer = require("../../../sybil-center-server/centerServer.coffee").CenterServer
    CenterServerInterface = require("../../p2p/centerServerInterface.coffee").CenterServerInterface
    serverPort = 10243
    Server = {}
    Ann = {}
    Bob = {}
    it "create center server",(done)->
        Server.server = new CenterServer(serverPort)
        Server.server.listen()
        done()
    it "create interfaces for a client",(done)->
        Ann.inf = new CenterServerInterface("localhost",serverPort)
        Ann.inf.connectToServer()
        Ann.inf.on "ready",()->
            done()
    it "create another interface for a client",(done)->
        Bob.inf = new CenterServerInterface("localhost",serverPort)
        Bob.inf.connectToServer()
        Bob.inf.on "ready",()->
            done()
    it "get address of a client",(done)->
        Ann.inf.messageCenter.invoke "getAddress",null,(err,address)->
            console.assert address
            Ann.address = address
            done()
    it "get address of another client",(done)->
        Bob.inf.messageCenter.invoke "getAddress",null,(err,address)->
            console.assert address
            Bob.address = address
            done()
    it "Ann Connect to Bob",(done)->
        Bob.inf.once "connection",(connection)->
            Bob.virtualConnectionFromAnn = connection
        Ann.inf.createVirtualConnection Bob.address,(err,connection)->
            if err
                throw err
            Ann.virtualConnectionToBob = connection
            if not Bob.virtualConnectionFromAnn
                throw "fail to recieve connection"
            done()
    it "Ann say hello to Bob",(done)->
        word = "hello bob!"
        Bob.virtualConnectionFromAnn.once "message",(message)->
            if not message
                throw "no message get"
            console.assert message is word
            done()
        Ann.virtualConnectionToBob.send word
    it "Bob say hello to Ann",(done)->
        word = "hello Ann!"
        Ann.virtualConnectionToBob.once "message",(message)->
            if not message
                throw "no message get"
            console.assert message is word
            done()
        Bob.virtualConnectionFromAnn.send word
    it "Ann initate closed connection bob should get informed",(done)->
        Bob.virtualConnectionFromAnn.on "close",()->
            Bob.virtualConnectionFromAnn.close()
            Ann.virtualConnectionToBob.close()
            done()            
        Ann.virtualConnectionToBob.close()
    it "Bob try to connect to ann again",(done)->
        Ann.inf.once "connection",(connection)->
            Ann.virtualConnectionFromBob = connection
        Bob.inf.createVirtualConnection Ann.address,(err,connection)->
            if err
                throw err
            Bob.virtualConnectionToAnn = connection
            if not Ann.virtualConnectionFromBob
                throw "fail to recieve connection"
            Bob.virtualConnectionToAnn.close()
            Ann.virtualConnectionToBob.close()
            done()
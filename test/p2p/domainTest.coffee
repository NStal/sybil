NodeModule = require("../../p2p/node.coffee")
Domain = NodeModule.Domain
Node = NodeModule.Node
CenterServer = require("../../../sybil-center-server/centerServer.coffee").CenterServer
CenterServerInterface = require("../../p2p/centerServerInterface.coffee").CenterServerInterface
VirtualConnectionNodeProvider = require("../../p2p/centerServerInterface.coffee").VirtualConnectionNodeProvider
async = require "async"
Tasks = require "node-tasks"
serverPort = 10243
wait = 100
Server = {}
Ann = {name:"Ann"}
Bob = {name:"Bob"}
Cici = {name:"Cici"}
Nodes = [Ann,Bob,Cici]
describe "domain test",()->
    it "start center server",(done)->
        Server = new CenterServer(serverPort)
        Server.listen()
        done()
    it "create domain for every body",(done)->
        Nodes.forEach (node)->
            node.domain = new Domain()
        done()
    it "create interface(nodeProvider) for every body",(done)->
        async.forEach Nodes,((node,finish)->
            node.inf = new CenterServerInterface("localhost",serverPort)
            node.inf.connectToServer()
            node.inf.once "ready",()->
                finish()
            node.domain.addNodeProvider new VirtualConnectionNodeProvider(node.inf)
            ),(err)->
                done(err)
    it "Ann findSome nodes",(done)->
        Ann.domain.discover()
        check = ()->
            console.assert Ann.domain.nodes.length is 2
            console.assert Bob.domain.nodes.length is 1
            console.assert Cici.domain.nodes.length is 1
            done()
        setTimeout check,wait
    it "Bob findSome nodes",(done)->
        Bob.domain.discover()
        check = ()->
            console.assert Ann.domain.nodes.length is 2
            console.assert Bob.domain.nodes.length is 2
            console.assert Cici.domain.nodes.length is 2
#            console.log Ann.domain.nodes.length
#            console.log Bob.domain.nodes.length
#            console.log Cici.domain.nodes.length
            done()
        setTimeout check,wait
    it "test p2p invoke",(done)->
        Nodes.forEach (node)->
            node.domain.listenInvoke "repeatAfterMe",(from,message,callback,next)->
                callback(null,node.name+":"+message)
        target = Ann.domain.nodes[0]
        address = target.connection.address
        Who = null
        if Bob.inf.address.value is address.value
            Who =  Bob
        else
            Who = Cici
        msg = "hello wolrd"
        target.messageCenter.invoke "repeatAfterMe",msg,(err,res)->
            console.log "response with",err,res,"by",Who.name
            console.assert res is Who.name+":"+msg
            done()
    it "test p2p event",(done)->
        get = 0
        Nodes.forEach (node)->
            node.domain.listenEvent "tellMeSomething",(from,message,next)->
                console.log "get",message
                get++
        check = ()->
            if get is 2
                done()
            else
                done new Error "not every body get it"
        setTimeout check,wait
        msg = "KEYWORD"
        Ann.domain.boardCast "tellMeSomething",msg
    it "test layered p2p events",(done)->
        task = new Tasks("testEvent","testEventAlphabet")
        Ann.domain.listenEvent "*",(from,message,next)->
            from.message = "begin"
            next()
        Ann.domain.listenEvent "getLayeredResponse",(from,message,next)->
            from.message+="1"
            next()
        Ann.domain.listenEvent "getLayeredResponse",(from,message,next)->
            from.message+= "2"
            next()
        Ann.domain.listenEvent "getLayeredResponseAlphabet",(from,message,next)->
            from.message+="A"
            next()
        Ann.domain.listenEvent "getLayeredResponseAlphabet",(from,message,next)->
            from.message+="B"
            next()
        Ann.domain.listenEvent "*",(from,message,next)->
            from.message+= "end"
            next()
        Ann.domain.listenEvent "getLayeredResponse",(from,message,next)->
            console.log from.message
            console.assert from.message is "begin12end"
            task.done("testEvent")
        Ann.domain.listenEvent "getLayeredResponseAlphabet",(from,message,next)->
            console.log from.message
            console.assert from.message is "beginABend"
            task.done("testEventAlphabet")
        task.on "done",()->
            done()
        Bob.domain.boardCast "getLayeredResponse","~"
        Bob.domain.boardCast "getLayeredResponseAlphabet","~"
    it "test layered p2p invokes",(done)->
        task = new Tasks("testInvoke","testInvokeAlphabet")
        Ann.domain.listenInvoke "*",(from,message,callback,next)->
            from.message = "begin"
            next()
        Ann.domain.listenInvoke "getLayeredResponse",(from,message,callback,next)->
            from.message+="1"
            next()
        Ann.domain.listenInvoke "getLayeredResponse",(from,message,callback,next)->
            from.message+= "2"
            next()
        Ann.domain.listenInvoke "getLayeredResponseAlphabet",(from,message,callback,next)->
            from.message+="A"
            next()
        Ann.domain.listenInvoke "getLayeredResponseAlphabet",(from,message,callback,next)->
            from.message+="B"
            next()
        Ann.domain.listenInvoke "*",(from,message,callback,next)->
            from.message+= "end"
            next()
        Ann.domain.listenInvoke "getLayeredResponse",(from,message,callback,next)->
            console.assert from.message is "begin12end"
            callback null,from.message
        Ann.domain.listenInvoke "getLayeredResponseAlphabet",(from,message,callback,next)->
            console.assert from.message is "beginABend"
            callback null,from.message
        task.on "done",()->
            done()
        for node in Bob.domain.nodes
            if node.connection.address.value is Ann.inf.address.value
                console.log "get it"
                Bob.Ann = node
                break
        Bob.Ann.messageCenter.invoke "getLayeredResponse",null,(err,data)->
            task.done("testInvoke")
        Bob.Ann.messageCenter.invoke "getLayeredResponseAlphabet",null,(err,data) ->
            task.done("testInvokeAlphabet")
        
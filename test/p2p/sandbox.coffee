SybilNetwork = require("../../plugins/sybilP2pNetwork/sybilNetwork")
fs = require("fs")
rsaString = fs.readFileSync("test.rsa.key","utf8")
rsaString2 = fs.readFileSync("test2.rsa.key","utf8")
Key = require("../../plugins/sybilP2pNetwork/network/key")
S1 = {}
S2 = {}
describe "sanbox",()->
    it "create 2 private key from file",(done)->
        counter = 0
        _done = ()=>
            counter++
            if counter is 2
                done()
        Key.MasterKey.fromPEM rsaString,(err,key)->
            console.assert not err,"create master key from rsa string should success"
            S1.key = key
            _done()
        Key.MasterKey.fromPEM rsaString2,(err,key)->
            console.assert not err,"create master key from rsa string should success"
            S2.key = key
            _done()
    it "create sand box",(done)->
        counter = 0
        _done = ()=>
            counter++
            if counter is 2
                done()
        S1.network = new SybilNetwork(S1.key,{standardHost:"0.0.0.0",standardPort:5237})
        S1.network.once "ready",()=>
            _done()
        S1.network.start()
        
        S2.network = new SybilNetwork(S2.key,{standardHost:"0.0.0.0",standardPort:5238})
        S2.network.once "ready",()=>
            _done()
        S2.network.start()
    it "create connection from S1 to S2",(done)->
        S1.network.addRandomConnections ["sybil://localhost:5238/"],(err,count)->
            console.assert not err
            console.assert count is 1
            setTimeout (()=>
                console.assert S1.network.nodes.length is 1
                console.assert S2.network.nodes.length is 1
                done()
                ),10
    it "create invalid connection",(done)->
        S1.network.addRandomConnections ["sybil://localhost:5239/"],(err,count)->
            console.assert count is 0
            done()
    
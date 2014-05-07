httpUtil = require("../../common/httpUtil.coffee")
http = require("http")
server = null
httpProxyUrl = "http://localhost:7072/"
socksProxyUrl = "http://localhost:7070/"
phttpProxyUrl = "phttp://nstal.me:12222/"
before ()->
    server = http.createServer (req,res)->
        if req.url is "/timeout"
            return
        res.write("get")
        res.end()
        return
    server.listen 12345
describe "basic function test",()->
    it "basic http connection test",(done)->
        httpUtil.httpGet {url:"http://localhost:12345/abc"},(err,res,content)->
            console.assert content.toString() is "get"
            done()
    it "test timeout",(done)->
        httpUtil.httpGet {url:"http://localhost:12345/timeout",timeout:2000},(err,res,content)->
            console.assert err
            console.assert err is "network timeout"
            done()
    it "basic http stream",(done)->
        httpUtil.httpGet {url:"http://localhost:12345/abc",useStream:true},(err,res,stream)->
            stream.on "data",(data)->
                console.assert data.toString() is "get"
                done()
    it "test immediate request",(done)->
        httpUtil.httpGet {url:"http://localhost:12345/abc",noQueue:true},(err,res,content)->
            console.assert content.toString() is "get"
            done()
    it "test with http proxy",(done)->
        httpUtil.httpGet {url:"http://www.youtube.com/",proxy:"http://localhost:7072"},(err,res,content)->
            console.assert not err
            done()
    it "test with socks proxy",(done)->
        httpUtil.httpGet {url:"http://www.youtube.com/",proxy:"socks://localhost:7070"},(err,res,content)->
            console.assert not err
            done()
    it "test with phttp proxy",(done)->
        httpUtil.httpGet {url:"http://www.youtube.com/",proxy:phttpProxyUrl},(err,res,content)->
            console.assert not err
            done()

after ()->
    server.close()
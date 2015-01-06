require "../../core/env"
describe "test sock5 proxy",()->
    it "test socks5 proxy connection",(done)->
        global.env.httpUtil.httpGet {url:"http://twitter.com/",proxy:"socks5://lili:7071",noQueue:true},(err,res,content)->
            if not err
                done()
            else
                throw err
    it "test socks5 proxy connection refused should return error",(done)->
        global.env.httpUtil.httpGet {url:"http://twitter.com/",proxy:"socks5://lili:3022",noQueue:true},(err,res,content)->
            if err
                console.log err
                done()
            else
                throw new Errors "proxy connection refused should return error"

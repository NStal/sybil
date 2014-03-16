exports.register = (module,callback)->
    sybil = require "../../core/sybil.coffee"
    repl = require "repl"
    net = require "net"
    server = net.createServer (conn)->
        shell = repl.start({
            prompt: "sybil core shell >"
            input:conn
            output:conn
            useGlobal:true
        })
        shell.context.sybil = sybil
        shell.on "exit",()->
            conn.end()
    server.listen(18233)
    callback(null,server)
exports.requires = []
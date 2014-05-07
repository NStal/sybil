fs = require "fs"
command = "openssl"
crypto = require("crypto")
child_process = require "child_process"
exports.generatePrivateKey = (callback)->
    genProcess = child_process.spawn command,["genrsa"]
    buffers = []
    genProcess.stdout.on "data",(data)->
        buffers.push data
    genProcess.on "close",(code)->
        if code isnt 0
            callback new Error "fail to call openssl"
            return
        data = Buffer.concat buffers
        callback null,new RSAPrivateKey(data.toString())
    #genProcess.stderr.pipe process.stderr
    
exports.extractPublicKey = (privateKey,callback)->
    pubProcess = child_process.spawn command,["rsa","-pubout"]
    callbacked = false
    
    buffers = []
    pubProcess.stdout.on "data",(data)->
        buffers.push data
    pubProcess.on "close",(code)->
        if code isnt 0
            callback new Error "fail to call openssl"
            return
        callback null,new RSAPublicKey((Buffer.concat buffers).toString("utf8"))
    
    pubProcess.stdin.end privateKey.toString()

exports.isRSAPrivatePEM = (string)->
    return exports.checkPEM(string,"RSA PRIVATE KEY")
exports.isRSAPublicPEM = (string)->
    return exports.checkPEM(string,"PUBLIC KEY")
exports.checkPEM = (string,type)->
        
    lines = string.split("\n").map (item)->item.trim()
    lines = lines.filter (item)->item
    beginMark = new RegExp("^---+\\s*BEGIN\\s#{type}\\s*---+","i")
    endMark = new RegExp("---+\\s*END\\s#{type}\\s*---+$","i")
    if not beginMark.test lines[0]
        return false
    if not endMark.test lines[lines.length-1]
        return false
    return true
    
class RSAPrivateKey
    constructor:(@key)->
        @key = @key.toString().trim()
        if not @check()
            throw new Error("invalid pem format")
    toString:(type)->
        if type is "hex"
            return @key.toString().replace(/-.*-/ig,"").trim()
        return @key.toString().trim()#.replace(/-.*-/ig,"")
    check:()->
        return exports.checkPEM(@key,"RSA PRIVATE KEY")
    extractPublicKey:(callback)->
        exports.extractPublicKey @key,(err,pubkey)->
            if err
                callback err
            callback null,new RSAPublicKey(pubkey)
    sign:(data)->
        sign = crypto.createSign("RSA-SHA256")
        sign.update data
        return sign.sign(@key)
    getHash:(encoding)->
        return (require "crypto").createHash("md5").update(@toString("hex")).digest(encoding or "hex")
class RSAPublicKey
    constructor:(@key)->
        @key = @key.toString().trim()
        if not @check()
            throw new Error("invalid pem format")
    toString:(type)->
        if type is "hex"
            return @key.toString().replace(/-.*-/ig,"").trim()
        return @key.toString().trim()#.replace(/-.*-/ig,"")
    check:()->
        return exports.checkPEM(@key,"PUBLIC KEY")
    verify:(data,signature)->
        verify = crypto.createVerify("RSA-SHA256")
        verify.update data
        try
            return verify.verify @key,signature
        catch e
            return false
    getHash:(encoding)->
        return (require "crypto").createHash("md5").update(@toString("hex")).digest(encoding or "hex")
class RSAIdentifier
    @create = ()->
        exports.generatePrivateKey (err,key)->
            privateKey = new RSAPrivateKey(key)
            privateKey.extractPublicKey (err,key)->
                publicKey = new RSAPublicKey(key)
                
    @fromFile = (path)->
        privateKey = new RSAPrivateKey(fs.readFileSync path,"utf8")
        publickKey = new RSAPublicKey(fs.readFileSync path+".pub","utf8")
        return new RSAIdentifier(privateKey,publicKey)
    constructor:(@privateKey,@publickKey)->
        true
    # won't overwrite it
    saveTo:(path)->
        if fs.existsSync(path) or fs.existsSync(path+".pub")
            return false
exports.RSAIdentifier = RSAIdentifier
exports.RSAPrivateKey = RSAPrivateKey
exports.RSAPublicKey  = RSAPublicKey



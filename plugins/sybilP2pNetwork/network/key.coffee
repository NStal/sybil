RSA = require "../../../common/rsa.coffee"
class MasterKey
    @Keys = {}
    @fromPEM = (pem,callback)->
        for keyType of @Keys
            Key = @Keys[keyType]
            if Key.test pem
                Key.fromPEM pem,callback
                return
        callback new Error "Unkown PEM format"
        return
        # from a pem contains master key
    constructor:()->
        @isValid = false
    sign:(buffer,callback)->
    verify:(buffer,signature,callback)->
    getPublicKey:(callback)->
    getPublicPEM:(callback)->
    getPEM:(callback)->
    getHash:()->
class PublicKey
    @Keys = {}
    @fromPEM = (pem,callback)->
        for keyType of @Keys
            Key = @Keys[keyType]
            if Key.test pem
                Key.fromPEM pem,callback
                return
        callback new Error "Unkown PEM format"
        return
    constructor:()->
        @isValid = false
    verify:(buffer,signature,callback)->
    getPEM:(callback)->
    getHash:()->
    equal:(puk)->
        if typeof puk is "string"
            return puk is @toString()
        else
            return puk.toString() is @toString()


class RSAMasterKey extends MasterKey
    MasterKey.Keys.RSAMasterKey = RSAMasterKey
    @test = RSA.isRSAPrivatePEM
    @fromPEM = (pem,callback)->
        if not @test pem
            callback new Error "invalid PEM"
        mk = new RSAMasterKey()
        mk.setPEM pem
        callback null,mk
    constructor:()->
        super()
    setPEM:(pem)->
        @isValie = true
        @pem = pem
        @rsaPrivateKey = new RSA.RSAPrivateKey(pem);
    sign:(data,callback)->
        signature = @rsaPrivateKey.sign data
        callback null,signature
    verfiy:(buffer,signature,callback)->
        callback new Error "not implemented"
    getPEM:(callback)->
        return @rsaPrivateKey.toString()
    getPublicPEM:(callback)->
        @getPublicKey (err,puk)->
            callback null,puk.toString()
    getPublicKey:(callback)->
        if @puk
            callback null,@puk
            return
        @rsaPrivateKey.extractPublicKey (err,rsapuk)=>
            if err
                callback err
                return
            puk = new RSAPublicKey()
            puk.rsaPublicKey = rsapuk
            puk.isValid = true
            @puk = puk
            callback null,puk
    getHash:(enc)->
        return @rsaPrivateKey.getHash(enc)
    toString:()->
        return @pem
class RSAPublicKey extends PublicKey
    PublicKey.Keys.RSAPublicKey = RSAPublicKey
    @test = RSA.isRSAPublicPEM
    @fromPEM = (pem,callback)->
        if not @test pem
            callback new Error "invalid PEM"
            return
        puk = new RSAPublicKey()
        puk.isValid = true
        rsapuk = new RSA.RSAPublicKey(pem)
        puk.pem = pem
        puk.rsaPublicKey = rsapuk
        callback null,puk
    constructor:()->
        super()
    verify:(buffer,signature,callback)->
        result = @rsaPublicKey.verify buffer,signature
        callback null,result
    getPEM:()->
        return @rsaPublicKey.toString()
    getHash:(enc)->
        return @rsaPublicKey.getHash(enc)
    toString:()->
        return @rsaPublicKey.toString()
exports.MasterKey = MasterKey
exports.PublicKey = PublicKey

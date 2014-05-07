RSA = require "../../common/rsa.coffee"
privateKey = null
publicKey = null
describe "rsa test",()->
    it "genrate new rsa",(done)->
        RSA.generatePrivateKey (err,key)->
            privateKey = key
            console.log "private key",key.toString()
            done err
    it "extract public key",(done)->
        RSA.extractPublicKey privateKey,(err,pubkey)->
            publicKey = pubkey
            console.log "pubkey key",pubkey.toString()
            done err
    it "test sign",(done)->
        data = "hello"
        signature = privateKey.sign(new Buffer(data))
        console.assert Buffer.isBuffer signature
        result = publicKey.verify(new Buffer(data),signature)
        console.assert result
        done()
        
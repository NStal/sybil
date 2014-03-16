rsa = require "../common/rsa.coffee"
privateKey = null
publicKey = null
encryptData = null
decryptData = null
rawData = "hello world"
rsa.generatePrivateKey (err,key)->
    if err
        throw err
    privateKey = key
    rsa.generatePublicKey privateKey,(err,key)->
        if err
            throw err
        publicKey = key
        rsa.encrypt rawData,publicKey,(err,encryptData)->
            if err
                throw err
            encryptData = encryptData
            rsa.decrypt encryptData,privateKey,(err,result)->
                if err
                    throw err
                console.log "result",result.toString(),result.toString() is rawData


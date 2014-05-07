RSA = require("../../common/rsa.coffee")
RSA.generatePrivateKey (err,key)->
    if err
        console.error err
        process.exit(0)
        return
    console.log(key.toString().trim())
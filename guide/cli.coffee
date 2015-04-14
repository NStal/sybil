readline = require("readline")



fs = require "fs"
rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});
userSettings = {}
settings = require("../settings")
exit = (code)->
    console.log "good bye"
    process.exit(code or 0)
asking = (question,callback)->
    again = ()->asking question,callback
    rl.question question,(a)->
        callback a,again
withDefault = (question,defaultValue,callback)->
    rl.question "#{question} (#{defaultValue}):",(answer)->
        if not answer.trim()
            callback defaultValue
        else
            callback answer.trim()
yesOrNo = (question,defaultValue,callback)->
#    if defaultValue is "y"
#        query = question+"<Y/n>"
#        defaultValue = "y"
#    else if defaultValue is "n"
#        query = question+"<y/N>"
#        defaultValue = "n"
#    else
    query = question+"<y/n>"
    defaultValue = null
    rl.question "#{query}",(answer)->
        answer = answer.trim().toLowerCase()
        if not answer and not defaultValue
            yesOrNo question,defaultValue,callback
            return
        if answer not in ["y","n"]
            yesOrNo question,defaultValue,callback
            return
        callback answer
welcome = ()->
    settingsExists = (require "fs").existsSync (require "path").join(__dirname,"../settings.user.json")
    if settingsExists
        yesOrNo "An old settings.user.json file exists would you like to continue?","n",(answer)->
            answer = answer.toLowerCase().trim()
            if answer is "" or answer is "n"
                exit(0)
            settings.parseConfig((require "path").join(__dirname,"../settings.user.json"))
            if answer is "y"
                fs.writeFileSync((require "path").join(__dirname,"../settings.user.json"),"{}")
                startConfig()
            return
    else
        startConfig()

startConfig = ()->
    try
        userSettings = JSON.parse(fs.readFileSync((require "path").join(__dirname,"../settings.user.json"),"utf8"))
    catch error
        userSettings = {}
    console.log "setup database"
    withDefault "database name","sybil",(answer)->
        userSettings.dbName = answer.trim()
        setupP2p()
#setupWebApi = ()->
#            userSettings.webApiPort = 3107
#        withDefault "web interface host","localhost",(answer)->
#            userSettings.webApiHost = answer.trim()
#          setupP2p()
setupP2p = ()->
    yesOrNo "would you like to enable experimental p2p api?","y",(answer)->
        if answer is "n"
            genRSA()
        else
            userSettings.hubServerHost = "sybil.nstal.me"
            userSettings.nodeServerHost = "sybil.nstal.me"
            asking "nickname(used in p2p sharing):",(answer,again)->
                if not answer.trim()
                    again()
                    return
                userSettings.nickname = answer.trim()
                asking "email(used in p2p sharing):",(answer,again)->
                    if not answer.trim()
                        again()
                        return
                    userSettings.email = answer
                    genRSA()
genRSA = ()->
    if not fs.existsSync "RSAIdentifier"
        yesOrNo "no rsa key found, would you like to create one now?(used in p2p sharing)","y",(answer)->
            if answer is "n"
                complete()
            else
                RSA = require("../common/rsa")
                RSA.generatePrivateKey (err,key)->
                    if err
                        console.error "fail to generate rsa key"
                        console.error "please make sure you have openssl installed"
                    else
                        path = require "path"
                        fs.writeFileSync path.join(__dirname,"../",settings.privateKeyPath or "./rsa.key"),key.toString()
                    complete()
complete = ()->
    console.log "everything is done, save to settings.user.json"
    fs.writeFileSync((require "path").join(__dirname,"../settings.user.json"),JSON.stringify(userSettings,null,4))
    console.log "done"
    process.exit(0)
console.log "This is the sybil setup guide"
welcome()

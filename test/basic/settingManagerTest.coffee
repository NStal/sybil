SettingManager = require("../../core/settingManager.coffee")
fs = require("fs")

describe "basic test",()->
    sm = new SettingManager()
    settings = sm.createSettings("testSetting","./testSetting.conf.json")
    settings.define "host","string"
    settings.define "port","int",SettingManager.Validator.intValidator
    fs.writeFileSync("./testSetting.conf.json",JSON.stringify({
        host:"localhost"
        ,port:3107
        ,ghost:"ghost"
    }))
    it "test restore",(done)->
        settings.restore ()->
            console.log settings.get("host"),"~"
            console.assert settings.get("host") is "localhost"
            console.assert settings.get("port") is 3107
            done()
    it "test validator",(done)->
        try
            settings.set("port","abcde")
        catch e
            done()
            return
        throw Error "fail"
    it "test set valid value",(done)->
        settings.set("port",12345)
        done()
    it "test preserve invalid config value",(done)->
        settings.save ()->
            console.assert JSON.parse(fs.readFileSync("./testSetting.conf.json")).ghost  is "ghost"
            done()
            
exports.requires = ["webApi"]
exports.register = (deps,done)->
    webApi = deps.webApi
    sybil = deps.sybil
    webApi.on "messageCenter",(mc)->
        console.error "here"
        mc.registerApi "getSettings",(_,callback)->
            result = {}
            for group in sybil.pluginSettingManager.settingGroup
                info = {}
                length = 0
                for name of group.entrys
                    entry = group.entrys[name]
                    info[entry.name] = {name:entry.name,type:entry.type,description:entry.description,value:entry.value}
                    length += 1
                if length is 0
                    continue
                result[group.name] = info
            callback null,result
        mc.registerApi "validateSettingEntry",(data,callback)->
            settingName = data.setting
            entryName = data.entry
            value = data.value
            found = pluginSettingManager.settingGroup.some (setting)->
                if setting.name is settingName
                    try
                        validation = setting.validate entryName,value
                        callback null,validation
                        return true
                    catch e
                        callback "invalid entry"
                    return true
            if not found
                callback "setting not found"
                return
        mc.registerApi "updateSettingEntry",(data,callback)->
            console.log "update setting entry",data
            settingName = data.setting
            entryName = data.entry
            value = data.value
            found = pluginSettingManager.settingGroup.some (setting)->
                if setting.name is settingName
                    try
                        setting.set entryName,value
                        callback null
                        return true
                    catch e
                        callback "invalid entry"
                    return true
            if not found
                callback "setting not found"
                return
    done null,null
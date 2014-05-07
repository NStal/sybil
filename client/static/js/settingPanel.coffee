App = require "app"
async = require "lib/async"
class SettingPanel extends Leaf.Widget
    constructor:()->
        super $(".setting-panel")[0]
        @hide()
        @groups = Leaf.Widget.makeList @UI.settingGroups
        @adjust()
        App.initialLoad ()=>
            @sync()
    show:()->
        @node$.show()
        @adjust()
    adjust:()->
        @left = ($(document.body).width()-@node$.width())/2
        @top = ($(document.body).height()-@node$.height())/2
        @node$.css({top:@top,left:@left})

    hide:()->
        @node$.hide()
    activeGroup:(group)->
        if @currentGroup
            @currentGroup.deactive()
        @currentGroup = group
        @currentGroup.active()
        @UI.settingEntrys$.empty()
        @UI.groupTitle$.text group.name
        for entry in group.entrys
            entry.appendTo @UI.settingEntrys
    addGroup:(group)->
        @groups.push group
        group.on "select",()=>
            @activeGroup group
    _setOptions:(options)->
        @groups.length = 0
        for group of options
            group = new SettingGroup(group,options[group]);
            @addGroup group
    sync:(callback = ()->true )->
        App.messageCenter.invoke "getSettings",{},(err,result)=>
            if err
                callback err
                return
            @_setOptions(result)
            callback null
    onClickResetButton:()->
        if not @currentGroup
            return
        for entry in @currentGroup.entrys
            entry.reset()
    onClickApplyButton:()->
        if not @currentGroup
            return
        async.each @currentGroup.entrys,((entry,done)=>
            entry.validate (err,result)->
                if err or not result
                    done err
                    return
                entry.update (err)->
                    done (err)
            ),(err)=>
                if err
                    App.showError err
    onClickCancelButton:()->
        @onClickResetButton()
        @hide()
class SettingGroup extends Leaf.Widget
    constructor:(@name,@info)->
        super "<div></div>"
        @node$.addClass "group"
        @entrys = []
        for name of @info
            data = @info[name]
            if data.type is "int"
                Entry = IntEntry
            else
                Entry = StringEntry
            entry = new Entry this,name,data
            entry.setValue data.value
            @entrys.push entry
        @node$.text @name
    active:()->
        @node$.addClass "active"
    deactive:()->
        @node$.removeClass "active"
    onClickNode:()->
        @emit "select"
class SettingEntry extends Leaf.Widget
    constructor:(template)->
        super template
        if @name
            @UI.name$.text @name
        if @UI.input
            @UI.input$.on "keyup",()=>
                @delayValidate()
    delayValidate:()->
        if @delayValidateTimer
            clearTimeout @delayValidateTimer
            @delayValidateTimer = null
        @delayValidateTimer = setTimeout @validate.bind(this),100
    validate:(callback = ()->true)->
        value = @getValue()
        App.messageCenter.invoke "validateSettingEntry",{setting:@group.name,entry:@name,value:value},(err,result)=>
            console.debug err,result
            if err
                callback err
                return
            if not result.valid
                @isValid = true
                @error result.error or "invalid value"
            else
                @correct()
            if result
                callback null,result
            else
                callback null,result
    update:(callback = ()->true)->
        console.debug "update into validate"
        @validate (err,result)=>
            console.debug "validate return"
            if err
                console.error err
                callback err
                return
            if not result.valid
                console.debug "invalid",result 
                callback "invalid"
                return
            validValue = result.value
            console.debug "invoke update"
            App.messageCenter.invoke "updateSettingEntry",{setting:@group.name,entry:@name,value:validValue},(err)=>
                if err
                    console.error err
                    callback err
                    return
                @correct()
                @setValue validValue
                callback()
    getValue:()->
        return @UI.input$.val().trim()
    setValue:(value)->
        @value = value
        @UI.input$.val(value)
    reset:()->
        value = @value or ""
        @UI.input$.val(value)
        @validate()
    error:(message)->
        @UI.errorMessage$.text(message)
    correct:()->
        @UI.errorMessage$.text("")
class IntEntry extends SettingEntry
    constructor:(@group,@name,@info)->
        super App.templates["int-entry"]
class StringEntry extends SettingEntry
    constructor:(@group,@name,@info)-> 
        super App.templates["int-entry"]
    
        
module.exports = SettingPanel
async = require("/lib/async")
App = require("/app")
SubscribeAssistant = require "/sourceUtil/subscribeAssistant"
tm = require "/templateManager"

tm.use "sourceUtil/addSourcePopup"

class AddSourcePopup extends Leaf.Widget
    constructor:()->
        super App.templates.sourceUtil.addSourcePopup
        @node$.hide()

    onClickSubmit:()->
        uris = @UI.input.value.trim().split(/\s+/).map (item)->item.trim()
        uris = uris.filter (item)->item
        uris.forEach (uri)->
            new SubscribeAssistant(uri)
        @UI.input.value = ""
        @hide()
    onClickCancel:()->
        @UI.input.value = ""
        @hide()
    show:()->
        @node$.show()
        @UI.input$.focus()
    hide:()->
        @node$.hide()

module.exports = AddSourcePopup

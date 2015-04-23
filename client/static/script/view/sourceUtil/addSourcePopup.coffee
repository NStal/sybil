async = require("/component/async")
App = require("/app")
SubscribeAssistant = require "/view/sourceUtil/subscribeAssistant"
tm = require "/common/templateManager"

tm.use "view/sourceUtil/addSourcePopup"

class AddSourcePopup extends Leaf.Widget
    constructor:()->
        super App.templates.view.sourceUtil.addSourcePopup
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

async = require("lib/async")
App = require("app")
SubscribeAssistant = require "/sourceUtil/subscribeAssistant"
class AddSourcePopup extends Leaf.Widget
    constructor:()->
        super(App.templates["add-source-popup"])
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
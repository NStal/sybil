App = require("app")
CubeLoadingHint = require "/widget/cubeLoadingHint"
class OfflineHinter extends Leaf.Widget
    constructor:()->
        @include CubeLoadingHint
        super $(".offline-hinter")[0]
        @hide()
        App.connectionManager.on "connect",()=>
            @hide()
        App.connectionManager.on "disconnect",()=>
            @show()
    show:()->
        @node$.addClass "show"
    hide:()->
        @node$.removeClass "show"
module.exports = OfflineHinter

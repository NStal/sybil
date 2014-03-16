class OfflineHinter extends Leaf.Widget
    constructor:()->
        super $(".offline-hinter")[0]
        App.connectManager.on "connect",()=>
            @hide()
        App.connectManager.on "disconnect",()=>
            @show()
    show:()->
        @node$.addClass "show"
    hide:()->
        @node$.removeClass "show"
window.OfflineHinter = OfflineHinter
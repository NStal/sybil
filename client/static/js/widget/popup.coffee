App = require "/app"
class Popup extends Leaf.Widget
    @zIndex = 500
    constructor:(template)->
        super template
        @mask = document.createElement("div")
        @mask.style.zIndex = Popup.zIndex++
        @mask$ = $(@mask)
        @mask$.addClass("mask")
        @mask$.css({"position":"absolute",height:"100%",width:"100%",top:0,left:"0","background-color":"rgba(0,0,0,0.6)"})
        @mask.onclick = ()=>
            @hide()
        @zIndex = Popup.zIndex++
    hide:()->
        @mask$.remove()
        @remove()
        App.history.remove this

    show:()->
        @appendTo document.body
        @mask$.appendTo document.body
        @node.style.zIndex = @zIndex
        App.history.push this,()=>
            @hide()
module.exports = Popup

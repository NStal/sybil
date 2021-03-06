class Popup extends Leaf.Widget
    @zIndex = 1000000
    constructor:(template)->
        super template
        @mask = document.createElement("div")
        @mask.style.zIndex = Popup.zIndex++
        @mask$ = $(@mask)
        @mask$.addClass("mask")
        @mask$.css({"position":"absolute",height:"100%",width:"100%",top:0,left:"0","background-color":"rgba(0,0,0,0.3)"})
        @mask.onclick = ()=>
            @hide()
        @zIndex = Popup.zIndex++
    hide:()->
        @mask$.remove()
        @remove()
    show:()->
        @appendTo document.body
        @mask$.appendTo document.body
        @node.style.zIndex = @zIndex
module.exports = Popup
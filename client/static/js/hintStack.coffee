class HintStack extends Leaf.Widget
    constructor:()->
        super "<div></div>"
        @node$.css {
            position:"absolute"
            ,bottom:0
            ,right:0
            ,width:"100%"
        }
        @list = Leaf.Widget.makeList @node
        document.body.appendChild @node
    push:(widget)->
        @list.push widget
        widget.listenBy this,"hide",@remove
    remove:(widget)->
        @list.removeItem widget
        widget.stopListenBy this

class HintStack.HintBox extends Leaf.Widget
    constructor:(option)->
        super(option)
module.exports = HintStack

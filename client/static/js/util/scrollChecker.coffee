class ScrollChecker extends Leaf.EventEmitter
    constructor:(node)->
        super()
        if node
            @attach node
    attach:(node)->
        if not node
            throw new Error "scroll check need to attach to HTMLElement"
        if @node
            @detach(@node)
        @node = node
        @timer = setInterval @check.bind(this),300
        @lastValue = @node.scrollTop
    detach:(node)->
        if @node is node or not node
            clearTimeout @timer
            @node = null
        @lastValue = null
    check:()->
        if not @node
            return
        value = @node.scrollTop
        if @lastValue isnt null
            if value isnt @lastValue
                if value > @lastValue
                    @emit "scrollDown"
                else if value < @lastValue
                    @emit "scrollUp"
                @emit "scroll"
                if @node.offsetHeight + @node.scrollTop >= @node.scrollHeight
                    @emit "scrollBottom"
                if @node.scrollTop is 0
                    @emit "scrollTop"
        @lastValue = value
module.exports = ScrollChecker
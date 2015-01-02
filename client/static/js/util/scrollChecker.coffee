class ScrollChecker extends Leaf.EventEmitter
    constructor:(node)->
        super()
        if node
            @attach node
        @fire = @fire.bind(this)
        @eventDriven = false
    attach:(node)->
        if not node
            throw new Error "scroll check need to attach to HTMLElement"
        if @node
            @detach(@node)
        @node = node
        if @eventDriven
            @node.addEventListener "scroll",@fire
            return
        @timer = setInterval @check.bind(this),300
        @lastValue = @node.scrollTop
    fire:()->
        @emit "scroll"
    detach:(node)->
        if @node is node or not node
            clearTimeout @timer
            @node.removeEventListener "scroll",@fire
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

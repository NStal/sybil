ScrollChecker = require "/util/scrollChecker"
class EndlessListRenderer extends Leaf.EventEmitter
    constructor:(@scrollable,@createMethod)->
        super()
        @renderCompromiseFix = 600
        @bottomPadding = 300
        @packs = []
        @datas = []
        @wrapper = document.createElement "div"
        @buffer = document.createElement "div"
        @buffer$ = $ @buffer
        @wrapper$ = $ @wrapper
        @wrapper.appendChild @buffer

        @bufferList = Leaf.Widget.makeList(@buffer)
        @bufferList.on "child/add",(widget)->
            widget.isRealized = true
            widget.pack.isRealized = true
        @bufferList.on "child/remove",(widget)->
            widget.pack.isRealized = false
        @reset()
        @scrollChecker = new ScrollChecker @scrollable
        @scrollChecker.eventDriven = true
        @scrollChecker.on "scroll",()=>
            @adjustBufferList()
        @scrollable.appendChild @wrapper
    indexOf:(item)->
        if item instanceof Leaf.Widget
            return item.pack.index
        else if item instanceof Pack
            return item.index
        return item.__index or null
    reset:()->
        @start = -1
        @end = -1
        @wrapper.style.minHeight = "0";
        @bufferList.length = 0
        @top = 0
        @packs.length = 0
        @wrapper$.css {width:"100%",minHeight:0}
        @buffer$.css {width:"100%",top:0,position:"absolute",left:0}
    add:(datas...)->
        packs = datas.map (data)=>
            new Pack data,@createMethod
        @addPack packs...
        for data,index in datas
            data.__index = index + @datas.length
        @datas.push datas...
    getPackByHeight:(height)->
        for index in [@packs.length - 1 .. 0]
            item = @packs[index]
            if item.bottom > height and item.top < height
                return item
        return item
    addPack:(packs...)->
        console.debug "add packs",packs
        for pack,index in packs
            pack.index = index + @packs.length
        @packs.push packs...
        @adjustBufferList()
    adjustBufferList:()->
        if @_hint and @buffer.contains @_hint
            @buffer.removeChild @_hint
        viewPort = @getViewPort(@renderCompromiseFix)
        # recalculate the item in buffers
        # and clear them from the start if before bottom before the top
        for index in [@start..@end]
            if index < 0
                continue
            item = @packs[index]
            item.calculateSize()
        @reflowAfter(@start)
        # choose a packs
        start = null
        end = null
        for item,index in @packs
            if not item.size
                console.debug "nobody has size",index,@packs.length
                break
            if item.bottom > viewPort.top and item.top < viewPort.bottom
                if start is null
                    start = index
                end = index
        intersect = (a0,a1,b0,b1)->
            left = Math.max a0,b0
            right = Math.min a1,b1
            if right - left < 0
                return [-1,-1]
            return [left,right]
        between = (start,end,number)->
            return number <= end and number >= start
        start ?= -1
        end ?= -1
        [shareStart,shareEnd] = intersect start,end,@start,@end
        # bug warning
        # repeat twice, one for before one for after
        toRemove = []
        for item,index in @bufferList
            if not between(shareStart,shareEnd,item.pack.index)
                toRemove.push item
        for item in toRemove
            @bufferList.removeItem(item)
        befores = []
        afters = []
        for index in [start..end]
            if index < 0
                break
            pack = @packs[index]
            if index < shareStart
                befores.push pack.widget
            else if index > shareEnd
                afters.push pack.widget
        if befores.length > 0
            @bufferList.splice(0,0,befores...)
        if afters.length > 0
            @bufferList.splice(@bufferList.length,0,afters...)

        if @bufferList.length isnt 0 and @bufferList.length isnt end - start + 1
            console.debug @bufferList.length,start,end
            throw new Error "invalid splice action"
        @start = start
        @end = end
        # after scan through  all sized item
        if @bufferList.length > 0
            @top = @bufferList[0].pack.top
            @buffer$.css {top:@top}
        bufferViewPort = @getBufferViewPort()
        # add more packs to here
        if bufferViewPort.bottom < viewPort.bottom
            toAddStart = null
            toAddEnd = @end
            for index in [(@end + 1)...@packs.length]
                pack = @packs[index]
                if not pack
                    break
                pack.realize()
                @bufferList.push pack.widget
                pack.calculateSize()
                pack.top = bufferViewPort.bottom
                pack.bottom = pack.top + pack.size.height
                bufferViewPort.bottom = pack.bottom
                if toAddStart is null
                    toAddStart = index
                toAddEnd = index
                if viewPort.bottom < bufferViewPort.bottom
                    break
            if @start is -1 and toAddStart
                @start = toAddStart
            @end = toAddEnd
        @wrapper.style.minHeight = "#{bufferViewPort.bottom + @bottomPadding}px"
        if @_hint
            @buffer.appendChild @_hint
        if bufferViewPort.bottom < viewPort.bottom
            @emit "requireMore"
        @emit "reflow"
    setHint:(node)->
        if @_hint and @buffer.contains(@_hint) and @_hint isnt node
            @buffer.removeChild @_hint
        if node is @_hint
            return
        @_hint = node
        @buffer.appendChild(node)
    reflowAfter:(after)->
        if after < 0
            return
        next = null
        for index in [after...@packs.length]
            item = @packs[index]
            if not item.size
                return
            if next isnt null
                item.top = next
            else
                next = item.top or 0
            next += item.size.height
            item.bottom = next
    getBufferViewPort:()->
        height = @buffer$.height()
        top = @top
        bottom = @top + height
        return {top,bottom,height}
    getViewPort:(fix = 0)->
        top = @scrollable.scrollTop
        height = $(@scrollable).height()
        bottom = top + height
        top -= fix
        bottom += fix
        if top < 0
            top = 0
        height = bottom - top
        return {top,height,bottom}
class Pack extends Leaf.EventEmitter
    constructor:(@data,@createMethod)->
    realize:()->
        @widget = @createMethod(@data)
        @widget.pack = this
        return @widget
    destroy:()->
        @widget = null
    calculateSize:()->
        if not @widget?.node?.parentElement
            return
        @size = @widget.node.getBoundingClientRect()

module.exports = EndlessListRenderer

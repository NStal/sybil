ScrollChecker = require "/util/scrollChecker"
class EndlessListRenderer extends Leaf.EventEmitter
    constructor:(@scrollable,@createMethod)->
        super()
        @renderCompromiseFix = 10
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
        @lastScroll = 0
        @scrollChecker.on "scroll",()=>
            @viewPortBuffer = null
            @adjustBufferList()
            @emit "viewPortChange"
            @saveTrace()
        @scrollable.appendChild @wrapper
        @resizeChecker = new ResizeChecker(@buffer)
        @resizeChecker.on "resize",()=>
            @reflow(@start or 0)
            @restoreTrace()
            @emit "resize"
        @resizeChecker.start()
        @destroyInterval = 200
    destroyStale:()->
        bufferRange = 3
        count = 5
        counter = 0
        maxDestroyATime = 4
        if @start > bufferRange
            _count = count
            while _count > 0
                pack = @packs[@start - bufferRange - _count]
                if pack and pack.widget
                    if pack.isRealized
                        continue
                    pack.destroy()

                    counter += 1
                    if counter > maxDestroyATime
                        clearTimeout @destroyStaleTimer
                        @destroyStaleTimer = setTimeout @destroyStale.bind(this),@destroyInterval
                        return
                _count -= 1
        while @end + count + bufferRange < @packs.length and count > 0
            count -= 1
            pack = @packs[@end + count + bufferRange]
            if pack and pack.widget and pack.isRealized
                continue
            pack.destroy()
            counter += 1
            if counter > maxDestroyATime
                clearTimeout @destroyStaleTimer
                @destroyStaleTimer = setTimeout @destroyStale.bind(this),@destroyInterval
                return
    indexOf:(item)->
        if item instanceof Leaf.Widget
            return item.pack.index
        else if item instanceof Pack
            return item.index
        if typeof item.__index is "number"
            return item.__index
        return -1
    trace:(item)->
        index = @indexOf(item)
        if index < 0
            return false
        @tracingPack = @packs[index]
        @saveTrace()
    saveTrace:()->
        if not @tracingPack
            return
        scrollTop = @scrollable.scrollTop
        top = @tracingPack.top
        @traceHistory = {
            top,scrollTop
        }
    restoreTrace:()->
        if not @traceHistory or not @tracingPack or typeof @tracingPack.top isnt "number"
            return
        scrollTop = @tracingPack.top + @traceHistory.scrollTop - @traceHistory.top
        @scrollable.scrollTop = scrollTop
    reset:()->
        @start = -1
        @end = -1
        @wrapper.style.minHeight = "0";
        @bufferList.length = 0
        @top = 0
        @tracingPack = null
        @traceHistory = null
        @datas.length = 0
        for pack in @packs
            pack.destroy()
        @packs.length = 0
        @wrapper$.css {width:"100%",minHeight:0}
        @buffer$.css {width:"100%",top:0,position:"absolute",left:0}
        @unlockContainer()
        clearTimeout @destroyStaleTimer
    add:(datas...)->
        packs = datas.map (data)=>
            new Pack data,@createMethod
        for data,index in datas
            data.__index = index + @datas.length
        @datas.push datas...
        @addPack packs...
    getPackByHeight:(height)->
        if @packs.length is 0
            return null
        for index in [@packs.length - 1 .. 0]
            item = @packs[index]
            if item.bottom > height and item.top < height
                return item
        return item
    addPack:(packs...)->
        for pack,index in packs
            pack.index = index + @packs.length
        @packs.push packs...
        @adjustBufferList()
    adjustBufferList:()->
        @unlockContainer()
        if @_hint and @buffer.contains @_hint
            @buffer.removeChild @_hint
        viewPort = @getViewPort(@renderCompromiseFix)
        # recalculate the item in buffers
        # and clear them from the start if before bottom before the top
        @reflow(@start)
        # choose a packs
        start = null
        end = null

        # find what items are within the viewPort
        for item,index in @packs
            if not item.size
                break
            if item.bottom >= viewPort.top and item.top <= viewPort.bottom
                if start is null
                    start = index
                end = index
        # make it -1 it not any within
        start ?= -1
        end ?= -1
        # force more item than just fit within the view port
        fix = 1
        if start isnt -1
            start -= fix
        if end isnt -1
            end += fix
        # `endBetterBe` is our goal.
        # But we may not have that many item in packs buffer.
        # We will be asking for more data is endBetterBe isnt @end latter.
        endBetterBe = end
        if end >= @packs.length
            end = @packs.length - 1
        if start < 0 and end isnt - 1
            start = 0
        intersect = (a0,a1,b0,b1)->
            left = Math.max a0,b0
            right = Math.min a1,b1
            if right - left < 0
                return [-1,-1]
            return [left,right]
        between = (start,end,number)->
            return number <= end and number >= start
        [shareStart,shareEnd] = intersect start,end,@start,@end
        # Keep [@start..@end] is synced with the @buffer contents
        toRemove = []
        for item,index in @bufferList
            if not between(shareStart,shareEnd,item.pack.index)
                toRemove.push item
        for item in toRemove
            @bufferList.removeItem(item)
            item.pack.destroy()
        befores = []
        afters = []
        for index in [start..end]
            if index < 0
                break
            pack = @packs[index]
            if index < shareStart
                befores.push pack.realize()
            else if index > shareEnd
                afters.push pack.realize()
        if befores.length > 0
            @bufferList.splice(0,0,befores...)
        if afters.length > 0
            for item in afters
                @bufferList.push item
#            @bufferList.splice(@bufferList.length,0,afters...)
        @start = start
        @end = end
        # after scan through  all sized item
        if @bufferList.length > 0
            @top = @bufferList[0].pack.top
            @buffer$.css {top:@top}
        # Up to here we have done the sync
        # But we may still not match the goal
        # to extend bufferViewPort to meet the viewPort.
        # Then we will invoke a `requireMore` event
        # to tel our master to give our more data.


        bufferViewPort = @getBufferViewPort()
        # Try to add some pack in packs that are no considered
        # before, because they are not added before, they don't have size.
        # Let me add them now.
        #
        for pack,index in @packs[@end+1...@packs.length]
            if bufferViewPort.bottom > viewPort.bottom and @end > endBetterBe
                break
            @bufferList.push pack.realize()
            pack.calculateSize()
            pack.top = bufferViewPort.bottom
            bufferViewPort.bottom += pack.size.height
            @end += 1
        # reflow to get the proper item size again
        @reflow shareEnd > 0 and shareEnd or 0,{noCalculate:true}
        if @_hint
            @buffer.appendChild @_hint
        @resizeChecker.acknowledge @buffer.offsetHeight

        @wrapper.style.minHeight = "#{bufferViewPort.bottom + @bottomPadding}px"
        @lockContainer()
        # every thing is done!
        if bufferViewPort.bottom <= viewPort.bottom or endBetterBe > @end
            @emit "requireMore"
#        clearTimeout @destroyStaleTimer
#        @destroyStaleTimer = setTimeout @destroyStale.bind(this),@destroyInterval
        @emit "reflow",@start,@end
    lockContainer:()->
        return
        if @buffer.isLocked
            return
        @buffer.isLocked = true
        height = @buffer.scrollHeight + 2
        @buffer$.css {
            height:height
            overflow:"auto"
        }
    unlockContainer:()->
        return
        if not @buffer.isLocked
            return
        @buffer.isLocked = false
        @buffer$.css {
            height:"auto"
            overflow:"hidden"
        }
    setHint:(node)->
        if @_hint and @buffer.contains(@_hint) and @_hint isnt node
            @buffer.removeChild @_hint
        if node is @_hint
            return
        @_hint = node
        @buffer.appendChild(node)
    reflow:(after = 0,option = {})->
        if after < 0
            return
        before = @packs.length
        if before > @packs.length
            return
        next = null
        relock = false
        if @buffer.isLocked and not option.noCalculate
            relock = true
            @unlockContainer()
        for index in [after...before]
            item = @packs[index]
            if item.isRealized and not option.noCalculate
                item.calculateSize()
            if not item.size
                break
            if next isnt null
                item.top = next
            else
                next = item.top or 0
            next += item.size.height
            item.bottom = next
        if relock
            @lockContainer()
    getBufferViewPort:()->
        height = @buffer$.height()
        top = @top
        bottom = @top + height
        return {top,bottom,height}
    getViewPort:(fix = 0)->
        if @viewPortBuffer
            top = @viewPortBuffer.top
            height = @viewPortBuffer.height
            bottom = top + height
        else
            top = @scrollable.scrollTop
            height = $(@scrollable).height()
            bottom = top + height
            @viewPortBuffer = {
                top,height,bottom
            }
        top -= fix
        bottom += fix
        if top < 0
            top = 0
        height = bottom - top
        return {top,height,bottom}

    compareItemPosition:(item)->
        if typeof item is "Number"
            index = item
        else
            index = @indexOf(item)
        pack = @packs[index]
        if index < 0
            return null
        if not pack
            return null
        vp = @getViewPort()
        return {
            topBeforeViewPort:pack.top < vp.top
            bottomBeforeViewPort:pack.bottom < vp.bottom
            topAfterViewPort:pack.top > vp.bottom
            bottomAfterViewPort:pack.bottom  > vp.bottom
        }
class Pack extends Leaf.EventEmitter
    constructor:(@data,@createMethod)->
        @__defineSetter__ "top",(value)=>
            @_top = value
            if @widget
                @widget.node.setAttribute("top",value)
        @__defineGetter__ "top",()=>
            return @_top
        @__defineSetter__ "bottom",(value)=>
            @_bottom = value
            if @widget
                @widget.node.setAttribute("bottom",value)
        @__defineGetter__ "bottom",()=>
            return @_bottom
        @__defineSetter__ "index",(value)=>
            @_index = value
            if @widget
                @widget.node.setAttribute("index",value)
        @__defineGetter__ "index",()=>
            return @_index

    realize:()->
        # @createMethod can be creator or a Class Constructor
        @widget = new @createMethod(@data)
        @widget.pack = this
        @widget.node.setAttribute "index",@_index
        return @widget
    destroy:()->
        if @widget and @widget.destroy
            @widget.destroy()
        @widget = null
    calculateSize:()->
        if not @widget?.node?.parentElement
            return
        rect = @widget.node.getBoundingClientRect()
        @size = {height:rect.height,width:rect.width}
#        @widget.node.setAttribute "size",JSON.stringify [@size]

class ResizeChecker extends Leaf.EventEmitter
    constructor:(@node)->
        super()
        @checkInterval = 100
    start:()->
        if @isStart
            return
        @isStart = true
        @check()
    stop:()->
        if not @isStart
            return
        @isStart = false
        clearTimeout @checkTimer
    acknowledge:(height)->
        @lastSize = height
    check:()->
        height = @node.offsetHeight
        if @lastSize isnt height
            @emit "resize"
        @lastSize = height
        @checkTimer = setTimeout ()=>
            @check()
        ,@checkInterval


module.exports = EndlessListRenderer

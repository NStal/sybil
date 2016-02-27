App = require "/app"
tm = require "/common/templateManager"
SmartImage = require "/widget/smartImage"
Popup = require "/view/base/popup"
CubeLoadingHint = require "/widget/cubeLoadingHint"
ImageLoader = require "/component/imageLoader"
class Point
    constructor:(@x,@y)->
        return
    toString:()->
        return "p: #{@x},#{@y}"
# TouchManager to integrate the touch interface with the click interface

class TouchManager extends Leaf.Widget
    constructor:()->
        super()
        @acceptMouse = true
        @console = document.createElement("div")
        #document.body.appendChild @console
        @console.style.width = "100%"
        @console.style.height = "30px"
        @console.style.position = "absolute";
        @console.style.top = 0;
        @console.style.left = 0;
        @console.style.zIndex = 9999;
        @console.style.backgroundColor = "black"
        @console.style.color = "white"
        @console.style.opacity = "0.5"
        @console.style.pointerEvents = "none"
        @console.className = "console"
        @console.style.display = "none"
        @log = (msg...)->
            msg = msg.map (item)->
                JSON.stringify(item)
            @console.innerHTML = Date.now()+msg.join(",")

    attachTo:(target)->
        @reset()
        if target
            @currentTarget = target
        if @currentTarget
            @currentTarget.addEventListener "touchstart",@handleTouchStart.bind(this)
            @currentTarget.addEventListener "touchenter",@handleTouchEnter.bind(this)
            @currentTarget.addEventListener "touchleave",@handleTouchLeave.bind(this)
            @currentTarget.addEventListener "touchcancel",@handleTouchCancel.bind(this)
            @currentTarget.addEventListener "touchend",@handleTouchEnd.bind(this)
            @currentTarget.addEventListener "touchmove",@handleTouchMove.bind(this)
            if @acceptMouse

                @currentTarget.addEventListener "touchstart",@_transformMouseToTouch @handleTouchStart.bind(this)
                @currentTarget.addEventListener "touchenter",@_transformMouseToTouch @handleTouchEnter.bind(this)
                @currentTarget.addEventListener "touchleave",@_transformMouseToTouch @handleTouchLeave.bind(this)
                @currentTarget.addEventListener "touchcancel",@_transformMouseToTouch @handleTouchCancel.bind(this)
                @currentTarget.addEventListener "touchend",@_transformMouseToTouch @handleTouchEnd.bind(this)
                @currentTarget.addEventListener "touchmove",@_transformMouseToTouch @handleTouchMove.bind(this)
    reset:()->
        if @currentTarget
            @currentTarget.removeEventListener("touchstart")
            @currentTarget.removeEventListener("touchend")
            @currentTarget.removeEventListener("touchleave")
            @currentTarget.removeEventListener("touchcancel")
            @currentTarget.removeEventListener("touchend")
            @currentTarget.removeEventListener("touchmove")
    _transformMouseToTouch:(fn)->
        return (e)->
            e.touches = [e]
            fn(e)
    _averagePosition:(list)->
        x = 0
        y = 0
        for item in list
            x+=item.clientX
            y+=item.clientY
        return new Point(x/list.length,y/list.length)
    _distance:(a,b)->
        return Math.sqrt((a.clientX-b.clientX)*(a.clientX-b.clientX)+
        (a.clientY-b.clientY)*(a.clientY-b.clientY))
    _touchDistance:(touches)->
        if touches.length < 2
            return null
        return @_distance touches[0],touches[1]
    _touchToPoint:(t)->
        return new Point(t.clientX,t.clientY)
    handleTouchStart:(e)->
        e.preventDefault()
        e.stopImmediatePropagation()
        @lastPoint = @_averagePosition(e.touches)
        if e.touches.length is 1
            @startPoint = _touchToPoint
        if e.touches.length > 1
            @lastDistance = @_distance(e.touches[0],e.touches[1])
    handleTouchEnter:(e)->
#        @log "enter"
    handleTouchLeave:(e)->
#        @log "leave"
    handleTouchMove:(e)->
        p = @_averagePosition(e.touches)
        #@log "move","x:#{p.x - @lastPoint.x} , y:#{p.y - @lastPoint.y}"
        x = p.x - @lastPoint.x
        y = p.y - @lastPoint.y
        @emit "move",{x:x,y:y}
        if e.touches.length > 1
            distance = @_distance(e.touches[0],e.touches[1])
#            @log "resize",distance/@lastDistance
            try
                @emit "scale",{},distance/@lastDistance
            catch e
                true
            @lastDistance = distance
        @lastPoint = p
    handleTouchCancel:(e)->
#        @log "cancel"
    handleTouchEnd:(e)->
        e.stopImmediatePropagation()
        e.preventDefault()
        if e.touches.length > 0
            @lastPoint = @_averagePosition(e.touches)
        if e.touches.length > 1
            @lastDistance = @_distance(e.touches[0],e.touches[1])
#        @log "end",e.touches.length

# File provider interface for gallyer displayer to get file from
class FileProvider extends Leaf.EventEmitter
    constructor:(srcs)->
        super()
        @files = []
        for src,index in srcs
            @files.push {src,index}
    at:(index)->
        return @files[index] or null
    next:(file)->
        return @at file.index + 1
    previous:(file)->
        return @at file.index - 1
class ImageBuffer extends TouchManager
    @setLoader = (loader)->
        @loader = loader
    constructor:(@displayer)->
        ImageBuffer.loader ?= new ImageLoader()
        super()
        @attachTo @UI.image
        @resize()
        @on "imageDoubleClick",()=>
            @toggleFitBorder()
            @center()
    resize:()->
        @width = @displayer.node$.width()
        @height = @displayer.node$.height()
    setFile:(@file)->
        @VM.state = "loading"
        ImageBuffer.loader.cache @file.src,(err)=>
            if err
                @VM.state = "fail"
            else
                @VM.state = "ready"
            @UI.image.src = @file.src
            @onload()
    onload:()->
        @resize()
        @originalSize = new Point(@UI.image.naturalWidth or 1,@UI.image.naturalHeight or 1)

        @ratio = @originalSize.y/@originalSize.x
        @imagePosition = {
            top:0
            ,left:0
            ,width:@originalSize.x
            ,height:@originalSize.y
        }
        @_p = {
            top:0
            ,left:0
            ,width:@originalSize.x
            ,height:@originalSize.y
        }
        @setInitialSize()
    setInitialSize:()->
        if @originalSize.x > @width
            @imagePosition.width = @width
        else
            @imagePosition.width =Math.max(@originalSize.x,@width/2)
        @fitMinBorder()
        @center()
        @adjust()
        @applyImagePositionImmediate()
    fitMinBorder:()->
        if @imagePosition.width > @width
            @imagePosition.width = @width
        @imagePosition.height = @imagePosition.width*@ratio
        if @imagePosition.height > @height
            @imagePosition.height = @height
        @imagePosition.width = @imagePosition.height/@ratio

    center:()->
        @setRelativePosition(new Point(@imagePosition.width/2,@imagePosition.height/2)
            ,new Point(@width/2,@height/2))
    toggleFitBorder:()->
        if @imagePosition.height is @height * @heightFix
            @fitWidth()
        else
            @fitHeight()
    fitHeight:()->
        @heightFix ?= 2
        @imagePosition.height = @height * 2
        @imagePosition.width = @height/@ratio * 2
    fitWidth:()->
        @imagePosition.width = @width
        @imagePosition.height = @width*@ratio
    setRelativePosition:(rp,offset)->
        # rp is relative point at the image
        @imagePosition.left = offset.x - rp.x
        @imagePosition.top = offset.y - rp.y
    scale:(rp,scale)->
        nrp = new Point(rp.x * scale,rp.y * scale)
        @imagePosition.width *= scale
        @imagePosition.height *= scale
        @setRelativePosition(nrp,new Point(@imagePosition.left+rp.x,@imagePosition.top+rp.y))

    adjust:()->
        @swipeOffset = @swipeOffset or $("body").width()*1/4
        if @imagePosition.width < @width
            offset = @imagePosition.left + @imagePosition.width/2 - @width/2
            if offset > @swipeOffset
                @displayer.slideToPrevious()
            else if offset < - @swipeOffset
                @displayer.slideToNext()

        else
            if @imagePosition.left + @imagePosition.width < @width - @swipeOffset
                @displayer.slideToNext()
            else if @imagePosition.left > @swipeOffset
                @displayer.slideToPrevious()
        if @imagePosition.width < @width && @imagePosition.height < @height
            @fitMinBorder()
            @center()
            return
        if @imagePosition.width >= @width
            if @imagePosition.left > 0
                @imagePosition.left = 0
                #return
            else if @imagePosition.left + @imagePosition.width < @width
                @imagePosition.left = @width - @imagePosition.width
                #return
        if @imagePosition.height >= @height
            if @imagePosition.top > 0
                @imagePosition.top = 0
                #return
            else if @imagePosition.top + @imagePosition.height < @height
                @imagePosition.top = @height - @imagePosition.height
                #return
        if @imagePosition.height < @height
            if @imagePosition.top < 0
                @imagePosition.top = 0
                #return
            if @imagePosition.top + @imagePosition.height > @height
                @imagePosition.top = @height - @imagePosition.height
                #return
    active:()->
        @isActive = true
        if @timer
            return
        @timer = setInterval @update.bind(this),10
    deactive:()->
        @isActive = false
        clearInterval @timer
        @timer = null
    _reach:()->
        equal = (a,b)->Math.abs(a-b)<0.1
        for prop of @_p
            if not equal(@_p[prop],@imagePosition[prop])
                return false
        return true
    update:()->
        if not @isActive
            return
        speed = 0.5
        closer = (a,b)->
            return (b - a)*speed
        if @_reach() and not @isTouching
            @deactive()
        for prop of @_p
            @_p[prop] += closer(@_p[prop],@imagePosition[prop])
        @applyImagePosition()
    applyImagePositionImmediate:()->
        for prop of @imagePosition
            @_p[prop] = @imagePosition[prop]
        @applyImagePosition()
    applyImagePosition:()->
        rx = @_p.width/@UI.image.naturalWidth
        ry = @_p.height/@UI.image.naturalHeight
        @UI.image$.css({
            transform:"translate3d(#{@_p.left}px,#{@_p.top}px,0) scale3d(#{rx},#{ry},1)"
            transformOrigin:"top left"
#            ,width:@_p.width
#            ,height:@_p.height
#            ,top:@_p.top
#            ,left:@_p.left
        })
    handleTouchStart:(e)->
        e.preventDefault();
        e.stopImmediatePropagation();
        @console.style.display = "block";
        @lastPoint = @_averagePosition(e.touches)
        @active()
        @isTouching = true
        if e.touches.length > 1
            @lastDistance = @_touchDistance(e.touches)
        @lastStartLength = e.touches.length
        if e.touches.length is 1
            @handleInitialStart(e)
    handleInitialStart:(e)->
        @distance = 0
        @checkOpenTimer = setTimeout (()=>
            if @distance < 30
                @displayer.toggleToolbar()
        ),700
    handleTouchEnd:(e)->
        super(e)
        if e.touches.length > 0
            @lastPoint = @_averagePosition(e.touches)
        if e.touches.length > 1
            @lastDistance = @_touchDistance(e.touches)
        if e.touches.length is 0
            @isTouching = false
            @lastStartLength = 0
            @adjust()
            @handleTouchFinal()
        clearTimeout @checkOpenTimer
    handleTouchFinal:()->
        if not @lastStartDate
            @lastStartDate = Date.now()
        dbClickMax = 300
        dbClickMin = 100
        difference = Date.now() - @lastStartDate
        if difference < dbClickMax && difference > dbClickMin
            @lastStartDate -= 0
            #@log "imageDL",difference
            @emit "imageDoubleClick"
        @lastStartDate = Date.now()
    handleTouchMove:(e)->
        currentPoint = @_averagePosition(e.touches)
        @imagePosition.top += currentPoint.y - @lastPoint.y
        @imagePosition.left += currentPoint.x - @lastPoint.x
        dx = @lastPoint.x-currentPoint.x
        dy = @lastPoint.y-currentPoint.y
        distance = Math.sqrt dx*dx+dy*dy
        if not @distance
            @distance = 0
        @distance += distance
        @lastPoint = currentPoint
        if e.touches.length > 1 and @lastDistance > 0
            distance = @_touchDistance(e.touches)
            scale
            ap = @_averagePosition(e.touches)
            ap.x -= @imagePosition.left
            ap.y -= @imagePosition.top
            scale = distance/@lastDistance
            #@log scale
            @scale ap,scale
            @lastDistance = distance

class GalleryDisplayer extends Leaf.Widget
    constructor:(template)->
        super template
        @buffers = Leaf.Widget.makeList @UI.buffers
        @resize()
        @node$.css({
            "perspective":"1000px"
            transformStyle: "preserve-3d"
        })
    ImageBuffer:ImageBuffer
    setFileProvider:(fp,index)->
        if @fileProvider
            @fileProvider.stopListenBy this
        @fileProvider = fp
        # file provider may partially changed some of the old file
        # may still there.
        # My strategies are try to set file index at 5
        # if 5 not exists then at 6 7 3 4
        @fileProvider.on "refresh",()=>
            if not @isShown
                return
            # the buffer may be 3 4 5(current) 6 7
            # make it [5 6 7 3 4]
            after = []
            before = []
            target = before
            current = @getCurrentBuffer()
            for buffer in @buffers
                if buffer is current
                    target = after
                target.push buffer.src
            srcs = [].concat after,before
            for src in srcs
                file = @fileProvider.getFileBySrcs src
                if not file
                    continue
                @clear()
                @setFileByIndex(file.index)
                return
        @initBuffers index or 0
    getCurrentBuffer:()->
        return @buffers[@currentBufferCursor]
    resize:()->
        @width = @node$.width()
        @height = @node$.height()
        console.debug "update width",@width,@height
        for buffer in @buffers
            buffer.resize()
    # setup -3 ~ index ~ +3 buffers (@bufferCount = 3)
    initBuffers:(fileIndex)->
        @resize()
        @clear()
        @bufferCount ?= 3
        # init buffer
        buffers = []
        currentFile = @fileProvider.at fileIndex
        @currentBufferCursor = 0
        @buffers.push @createBuffer(currentFile)

        # Try my best to buffer the next 3 files
        # their may not be next three so,
        # I will break if not any more available
        # Note, I should always using provider.next(file)/.previous(file)
        # to get the next file.
        # Since some specific file may be jumped by the file provider.
        # Get it by index is not that promising

        cursor = currentFile
        for after in [1..@bufferCount]
            cursor = @fileProvider.next cursor
            if not cursor
                break
            @buffers.push @createBuffer cursor
        cursor = currentFile
        for before in [@bufferCount..1]
            cursor = @fileProvider.previous cursor
            if not cursor
                break
            @buffers.unshift @createBuffer cursor
            # add currentBufferCursor by 1
            @currentBufferCursor += 1
        @setupBufferPositions()
    setupBufferPositions:(option = {})->
        for buffer,index in @buffers
            console.debug @width,"is my width"
            css = {
                transform:"translateX(#{(index-@currentBufferCursor)*@width}px)"
                left:0
            }
            if index not in [@currentBufferCursor - 1 .. @currentBufferCursor + 1]
                buffer.node$.hide()
            else
                buffer.node$.show()
            # ignore option.time use transition for now
            if not option.time or true
                buffer.node$.css(css)
            else
                buffer.node$.animate(css,option.time)
        if current = @getCurrentBuffer()
            @emit "display",current.file
    clear:()->
        @buffers.length = 0
        @currentBufferCursor = -1
    createBuffer:(file)->
        ImageBuffer.prototype.template = @templates.imageBuffer
        buffer = new @ImageBuffer(this)
        buffer.setFile file

        return buffer
    _adjustBuffers:()->
        # push/unshift more buffer if not enough
        # remove buffer if too much
        last = @buffers[@buffers.length - 1]
        first = @buffers[0]
        after = @buffers.length - @currentBufferCursor - 1
        before = @currentBufferCursor
        if before < @bufferCount and first
            cursor = first.file
            for index in [1..@bufferCount - before]
                cursor = @fileProvider.previous(cursor)
                if not cursor
                    break
                @buffers.unshift @createBuffer cursor
                @currentBufferCursor += 1
        else if before > @bufferCount
            while before > @bufferCount
                before -= 1
                @buffers.shift()
                @currentBufferCursor -= 1

        if after < @bufferCount and last
            cursor = last.file
            for index in [1..@bufferCount - after]
                cursor = @fileProvider.next(cursor)
                if not cursor
                    break
                @buffers.push @createBuffer cursor
        else if after > @bufferCount
            while after - @bufferCount > 0
                after -= 1
                @buffers.pop()

    slideToNext:()->
        if @currentBufferCursor is @buffers.length - 1
            # already last one
            return false
        @_slideToIndex @currentBufferCursor + 1
        return true
    slideToPrevious:()->
        if @currentBufferCursor is 0
            # already the first one
            return false
        @_slideToIndex @currentBufferCursor-1
        return true
    _slideToIndex:(index)->
        if index < 0 or index >= @buffers.length
            throw new Error "slide to index #{index} is out of range of #{@buffers.length}"
        if @buffers[@currentBufferCursor]
            @buffers[@currentBufferCursor].deactive()
        @currentBufferCursor = index
        if @getCurrentBuffer()
            @getCurrentBuffer().active()
        @_adjustBuffers()
        @setupBufferPositions({time:140})
    setFileByIndex:(index)->
        file = @fileProvider.at(index)
        if not file
            throw new Error "file doesn't contain index #{index}"
        @currentFile = file
        @initBuffers(index)

class StatefulImageBuffer extends ImageBuffer
    constructor:(args...)->
        @include CubeLoadingHint
        super args...
GalleryDisplayer::ImageBuffer = StatefulImageBuffer

tm.use "view/imageDisplayer"
class ImageDisplayer extends Popup
    constructor:()->
        @include SmartImage
        @include CubeLoadingHint
        super App.templates.view.imageDisplayer
        @gallery = new GalleryDisplayer(@node)
        ImageBuffer.setLoader App.imageLoader

        @UI.buffers.addEventListener "touchstart",(e)=>
            e.stopImmediatePropagation()
            e.preventDefault()
            @hide()
    setSrcs:(srcs,index)->
        fileProvider = new FileProvider(srcs)
        @gallery.setFileProvider fileProvider,index or 0
    setSrc:(src)->
        @setSrcs [src]
    onClickNode:()->
        @hide()
module.exports = ImageDisplayer

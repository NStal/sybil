Model = require "/model"
App = require "/app"
ScrollChecker = require "/util/scrollChecker"
SwipeChecker = require "/util/swipeChecker"
async = require "/lib/async"
BufferedEndlessArchiveLoader = require "/procedure/bufferedEndlessArchiveLoader"
CubeLoadingHint = require "/widget/cubeLoadingHint"
ArchiveDisplayer = require "/baseView/archiveDisplayer"
Flag = require "/util/flag"
tm = require "/templateManager"
tm.use "sourceView/archiveList"
class ArchiveList extends Leaf.Widget
    constructor:(template)->
        @include CubeLoadingHint
        super(template or App.templates.sourceView.archiveList)

        # load query options
        @sort = "latest"
        @viewRead = false
        @loadCount = 10

        # mark reads on scroll
        @scrollChecker = new ScrollChecker @UI.containerWrapper
        @archiveListItems = Leaf.Widget.makeList @UI.container

        @archiveListController = new ArchiveListController(this)
        @sourceUpdateChecker = new SourceUpdateChecker(this)
        @initSubWidgets()
        App.userConfig.on "change/previewMode",@applyPreviewMode.bind(this)
        App.userConfig.init "useResourceProxyByDefault",false
        App.userConfig.init "enableResourceProxy",true
    applyPreviewMode:()=>
        if not @archiveInfo
            return
        globalPreviewMode = App.userConfig.get("previewMode",false)
        infoPreviewMode = App.userConfig.get("previewModeFor"+@archiveInfo.name,globalPreviewMode)

        @disableMarkAsRead = true
        if @previewMode? and @previewMode is infoPreviewMode
            @disableMarkAsRead = false
            return
        @previewMode = infoPreviewMode
        if infoPreviewMode
            @node$.addClass("preview-mode")
            @emit "previewMode",true
        else
            @node$.removeClass("preview-mode")

            @emit "previewMode",false
        @disableMarkAsRead = false

    load:(info)->
        @clear()
        @archiveInfo = info
        @UI.emptyHint$.hide()
        @UI.loadingHint.hide()
        @archiveListController.load(info)
        @render()
        @emit "load"
    render:()->
        @UI.title$.show()
        @UI.sourceName$.text @archiveInfo.name
        @applyPreviewMode()
        if @viewRead
            @UI.toggleViewAll$.text("view unread")
        else
            @UI.toggleViewAll$.text("view all")
    clear:()->
        if @archiveLoader
            @archiveLoader.stopListenBy this
        @archiveLoader = null
        @UI.containerWrapper.scrollTop = 0
        @UI.emptyHint$.show()
        @UI.title$.hide()

    onClickMarkAllAsRead:()->
        async.eachLimit @archiveInfo.sourceGuids,3,((guid,done)=>
            source = Model.Source.sources.get(guid)
            if not source
                console.error source,guid
                done()
                return;
            source.markAllAsRead (err)->
                if err
                    console.error(err)
                    done()
                    return
                source.unreadCount = 0
                done()
            ),(err)=>
                console.log "complete mark all as read"
                @load @archiveInfo
    onClickToggleViewAll:()->
        if @viewRead
            @viewRead = false
            @load(@archiveInfo)
        else
            @viewRead = true
            @load(@archiveInfo)
        @render()
    onClickPreviewMode:()->
        if not @archiveInfo
            return
        previewMode = App.userConfig.get "previewModeFor"+@archiveInfo.name,false
        App.userConfig.set "previewModeFor"+@archiveInfo.name,not previewMode
        @applyPreviewMode()

tm.use "sourceView/archiveListItem"
class ArchiveListItem extends ArchiveDisplayer
    constructor:(archive)->
        super App.templates.sourceView.archiveListItem
        @setArchive archive
        @isShown = true
        if not App.isMobile
            @node$.addClass "rich"
        @node.addEventListener "overflowchanged",()=>
            @onResize()
        @node.addEventListener "scroll",()=>
            @onResize()
#        @node$.find("img").on "load",@onResize.bind(this)
    onResize:()->
        @sizeDirty = true
        @emit "resize"
    onClickContent:()->
        if @lockRead
            return
        @markAsRead()
        return true
    onClickTitle:(e)->
        window.open @archive.originalLink
        e.stopPropagation()
        e.preventDefault()
        e.stopImmediatePropagation()
        return false
    onClickHeader:(e)->
        @node$.toggleClass("collapse")
        @resize()
        @onResize()
        @markAsRead()
        @node$.css {height:"auto"}
        @onResize()
    resize:()->
        @size = {
            width:@node$.outerWidth()
            height:@node.scrollHeight + 2
        }
        @sizeDirty = false
        @node.setAttribute "size-info",JSON.stringify(@size)
        @node$.css {overflow:"auto",height:@size.height}
    setPosition:(pos)->
        @position = pos
        @node$.css {top:pos}
    getPosition:()->
        return @position
    getNextPosition:()->
        @size ?= {}
        return @position + (@size.height or 0)
    show:()->
        if @isShown
            return
        @isShown = true
        @node$.show()
    hide:()->
        if not @isShown
            return
        @isShown = false
        @node$.hide()

    markAsRead:()->
        if @lockRead
            return
        if @isMarking
            return
        if @archive.hasRead
            return
        @isMarking = true
        @archive.markAsRead (err)=>
            if err
                console.error err
                return
            @isMarking = false
    # UI top alias for markas unread
    onClickKeepUnread:(e)->
        if e
            e.preventDefault()
            e.stopPropagation()
        @onClickMarkAsUnread()
    render:()->
        super()
        if @lockRead
            @node$.addClass("lock-read")
        else
            @node$.removeClass("lock-read")
        if @archive.hasRead
            @node$.addClass("read")
        else
            @node$.removeClass("read")
    onClickMarkAsUnread:()->
        # just lock it to prevent read don't actually update it
        # if I do so, the unread count will just inc 1
        @lockRead = true
        @emit "change"
        if @archive.hasRead is false
            @render()
            return
        @archive.markAsUnread (err)=>
            if err
                console.error err
                return
            @render()

# Control list level behavior, most of them
# should have something to do with the scroller.
tm.use "sourceView/archiveListController"
class ArchiveListController extends Leaf.Widget
    constructor:(archiveList)->
        super  App.templates.sourceView.archiveListController
        @context = archiveList
        @formatter = new ArchiveListFormatter(@context,this)

        @swipeChecker = new SwipeChecker(@node)
        @swipeChecker.on "swipeleft",(e)=>
            @node$.addClass "left-mode"
        @swipeChecker.on "swiperight",(e)=>
            e.preventDefault()
            e.stopImmediatePropagation()
            @node$.removeClass "left-mode"
        @context.scrollChecker.listenBy this,"scroll",()=>
            @formatter.updateFocus()
            visible = @formatter.getFirstVisible()
            if visible
                index = visible.index or 0

            index -= 20
            if index < 0
                index = 0
            @formatter.reflowAfter(index)

            @checkLoadMore()
            if not @context.disableMarkAsRead
                @markAsReadBeforeFocus()
        @archiveBuffer = new BufferedEndlessArchiveLoader()
        @archiveBuffer.on "startLoading",()=>
            console.debug "startLoading"
            if not @archiveBuffer.isDrain()
                @context.UI.loadingHint$.show()
                @context.UI.emptyHint$.hide()
        @archiveBuffer.on "endLoading",()=>
            console.debug "endLoading..."
            @context.UI.loadingHint$.hide()
            if @archiveBuffer.isDrain()
                @context.UI.emptyHint$.show()
        @formatter.on "focus",(focus)=>
            if focus is @currentFocus
                return
            if @currentFocus
                @currentFocus.blur()
                @currentFocus.stopListenBy this
            @currentFocus = focus
            @currentFocus.listenBy this,"change",()=>
                @render()
            @currentFocus.focus()
            @render()
    load:(info)->
        @context.UI.container$.css {minHeight:"0px"}
        @isLoading = false
        @archiveInfo = info
        @archiveBuffer.reset()
        @context.UI.emptyHint$.hide()
        @archiveBuffer.init({
            query:{sourceGuids:@archiveInfo.sourceGuids}
            sort:@context.sort
            viewRead:@context.viewRead
        })
        @context.archiveListItems.length = 0
        @checkLoadMore()
    checkLoadMore:()->
        if @isLoading
            return
        if @archiveBuffer.isDrain()
            @context.UI.emptyHint$.show()
            return
        last = @formatter.getLastVisible()
        renderBufferSize = 3
        if last and @formatter.length() - last.index > renderBufferSize
            @formatter.updateFocus()
            return
        @isLoading = true
        @archiveBuffer.oneMore (err,item)=>
            @isLoading = false
            if err
                @context.UI.loadingHint$.hide()
                console.error err
                return
            console.debug "checkLoadMoreItem",err,item
            if not item
                console.debug "NO MORE"
            if not item
                @context.UI.emptyHint$.show()
                @context.UI.loadingHint$.hide()
                return
            @formatter.appendArchive item
            @checkLoadMore()
    markAsReadBeforeFocus:()->
        if not @currentFocus
            return
        for index in [0..@currentFocus.index]
            item = @formatter.at index
            if item and not item.archive.hasRead
                item.markAsRead()
    scrollToItem:(item)->
        if not item
            return
        [top,bottom] = @formatter.getViewPort()
        fixLine = @formatter.getFixLine()
        padding = 5
        if item.size.height > fixLine - top
            @context.UI.containerWrapper.scrollTop = item.position - padding
        else
            console.log "fix"
            fix = (fixLine - top) - item.size.height/2
            @context.UI.containerWrapper.scrollTop = item.position - fix - padding
    scrollTo:(top)->
        @context.UI.containerWrapper.scrollTop = top
    getScrollTop:()->
        return @context.UI.containerWrapper.scrollTop
    onClickExpandOption:()->
        @showOptionFlag ?= new Flag().attach(@VM,"showOption").unset()
        @showOptionFlag.toggle()
    render:()->
        if not @currentFocus
            return
        archive = @currentFocus.archive
        @Data.keepUnread = @currentFocus.lockRead
        @Data.liked = archive.like
        @Data.shared = archive.share
    onClickPrevious:()->
        # try scroll to top of the current item
        # only scroll to previous item when beginning of the
        # current item is visible
        focus = @currentFocus
        adjust = 5
        [top,bottom] = @formatter.getViewPort()
        if focus.getPosition() > top
            target = @formatter.at focus.index - 1
        else
            target = focus
        if target
            @scrollToItem target
    onClickNext:()->
        if @currentFocus is @formatter.last()
            @context.UI.containerWrapper.scrollTop = @currentFocus.node.offsetTop + @getFocus().node.offsetHeight
            return
        next = @formatter.at @currentFocus.index + 1
        if next
            console.log "scroll to",next.index,"from",@currentFocus.index
            @scrollToItem next
        else
            App.toast "No more : )"
    onClickGoBottom:()->
        if not @currentFocus
            return
        @scrollToItem @currentFocus
        bottom = @currentFocus.node.offsetTop + @currentFocus.node.offsetHeight
        top = @context.UI.containerWrapper.scrollTop
        height = @context.UI.containerWrapper$.height()
        if bottom > top + height
            forward = bottom - (top + height)
            @context.UI.containerWrapper.scrollTop += forward
    onClickLike:()->
        if @currentFocus
            @currentFocus.onClickLike()
    onClickShare:()->
        if @currentFocus
            @currentFocus.onClickShare()
    onClickKeepUnread:()->
        if @currentFocus
            @currentFocus.onClickKeepUnread()

class ArchiveListFormatter extends Leaf.EventEmitter
    constructor:(@context,@controller)->
        super()
        @context.archiveListItems.listenBy this,"child/add",(child)=>
            child.listenBy this,"resize",()=>
                if child.isShown
                    child.resize()
                    @reflowAfter child.index - 1
        @context.archiveListItems.listenBy this,"child/remove",(child)=>
            child.stopListenBy this
        @context.on "previewMode",(preview)=>
            for item in @context.archiveListItems
                item.node$.css {height:"auto"}
                item.sizeDirty = true
            if @context.archiveListItems.length > 0
                @reflowAfter(0)
    appendArchive:(archive)->
        item = new ArchiveListItem archive
        viewPort = @getViewPort()
        item.index = @context.archiveListItems.length
        item.node$.css {width:"100%",position:"absolute",zIndex:item.index/1000}
        prev = @context.archiveListItems[item.index - 1]
        if prev
            item.setPosition(prev.getNextPosition())
        else
            item.setPosition(0)
        @context.archiveListItems.push item
        item.resize()
        @context.UI.container$.css {minHeight:item.getNextPosition()}
        [top,bottom] = @getViewPort()
        if item.getPosition() > bottom
            item.hide()
    length:()->
        return @context.archiveListItems.length
    at:(index)->
        return  @context.archiveListItems[index] or null
    last:()->
        return @context.archiveListItems[@context.archiveListItems.length - 1] or null
    getFirstVisible:()->
        [top,bottom] = @getViewPort()
        for item in @context.archiveListItems
            if item.getPosition() + item.size.height > top
                return item
        return null
    getLastVisible:()->
        [top,bottom] = @getViewPort()
        hasVisible = false
        for item in @context.archiveListItems
            if item.getPosition() < bottom
                visible = item
                hasVisible = true
            else if hasVisible
                return item
        return null
    updateFocus:()->
        @currentFocus = null
        for item,index in @context.archiveListItems
            head = item.getPosition()
            foot = head + item.size.height
            # At beginning we will focus on the top item in the view port.
            # When scroll more, we are more like to focus on the center item in the view port.
            # This algo make sure we eventually focus on center item,
            # but won't jump the first item and won't skip any item.
            # Because fix = top*0.7 is continuous from (0~half viewport).
            # This is what fixline do.
            if foot > @getFixLine()
                @currentFocus = item
                break
        @currentFocus ?= @last()
        if @currentFocus
            @emit "focus",@currentFocus
        return @currentFocus
    getFixLine:()->
        [top,bottom] = @getViewPort()
        half = (bottom - top)/2
        top = @controller.getScrollTop()
        fix = top * 0.7
        fixMax = half - 100
        return (top + Math.min(fixMax,fix))
    getPreviousItem:()->
        return @at @currentFocus.index - 1
    getNextItem:()->
        return @at @currentFocus.index + 1

    reflowAfter:(item)->
        # calculate relative scrollTop/focusItem and restore it after reflow
        @saveRelativeLocation()
        firstVisible = null
        if item instanceof ArchiveListItem
            after = item.index
        else if typeof item is "number"
            after = item
        else
            after = 0
        if after < 0
            after = 0
        [top,bottom] = @getViewPort()
        height = bottom - top
        lastShow = null
        for index in [after...@context.archiveListItems.length]
#            if index is after
#                continue
            prev = @at index - 1
            current = @at index
#            if not current
#                console.log "index",index,"???"
            if prev
                current.setPosition prev.getNextPosition()
            else
                current.setPosition(0)
            if current.sizeDirty
                if current.isShown
                    current.resize()
                else
                    current.show()
                    current.resize()
                    current.hide()
            dim = [current.getPosition,current.getPosition() + current.size.height]

            renderBufferSize = 2
            # for long archive renderBufferSize may works well
            # for short archive expand:600 may works well
            if @inViewPort(current,{expand:600})
                lastShow = current.index
                if not current.isShown
                    current.show()
                    firstVisible ?= current
            else if typeof lastShow is "number" and current.index - lastShow < renderBufferSize
                if not current.isShown
                    current.show()
            else if current.isShown
                current.hide()
        if @last()
            max = @last().size.height + @last().getPosition() + 80
            @context.UI.container$.css {minHeight:max}
        @restoreRelativeLocation()
        if firstVisible
            @reflowAfter firstVisible
#    applyHintPosition:()->
#        last = @last()
#        if last
#            top = last.getNextPosition()
#        else
#            top = 0
#        @context.UI.emptyHint$.css {position:absolute,left:0,top:top}
#        @context.UI.loadingHint$.css {position:absolute,left:0,top:top}

    saveRelativeLocation:()->
        return
        item = @updateFocus()
        offset = @controller.getScrollTop() - item.getPosition()
        @_relativeLocation = {
            offset,item
        }
    restoreRelativeLocation:()->
        return
        if not @_relativeLocation
            return
        dest = @_relativeLocation.item.getPosition() + @_relativeLocation.offset
        @controller.scrollTo dest
    getViewPort:()->
        height = @context.UI.containerWrapper$.height()
        top = @context.UI.containerWrapper.scrollTop
        return [top,top+height]
    inViewPort:(item,option = {})->
        [head,foot] = [item.getPosition(),item.getPosition() + item.size.height]
        [top,bottom] = @getViewPort()
        if option.expand > 0
            expand = option.expand
            top -= expand
            bottom += expand

#        console.log "view port hehe",head,foot,top,bottom,item.index
        return head < bottom and foot > top




class SourceUpdateChecker extends Leaf.Widget
    constructor:(@context)->
        super(@context.UI.refreshHint)
        @init()
    onClickNode:()->
        @context.load(@context.archiveInfo)
    onClickHideRefreshHint:(e)->
        if e
            e.capture()
        @hideUpdateHint()
    init:()->
        @context.on "load",()=>
            @hideUpdateHint()
        App.modelSyncManager.on "archive",(archive)=>
            if @context.archiveInfo and archive.sourceGuid in @context.archiveInfo.sourceGuids
                @showUpdateHint()
    showUpdateHint:()->

        @refreshHintShowInterval ?= 1000 * 15
        @context.UI.refreshHint$.addClass("show")
        if @_updateHintTimer
            @_updateHintTimer = null
            clearTimeout @_updateHintTimer
        @_updateHintTimer = setTimeout @hideUpdateHint.bind(this),@refreshHintShowInterval
    hideUpdateHint:()->
        clearTimeout @_updateHintTimer
        @_updateHintTimer = null
        @UI.refreshHint$.removeClass("show")

#window.ArchiveListItem = ArchiveListItem
#window.ArchiveList = ArchiveList
module.exports = ArchiveList

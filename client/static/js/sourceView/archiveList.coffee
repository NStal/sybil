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
        if infoPreviewMode
            @node$.addClass("preview-mode")
        else
            @node$.removeClass("preview-mode")
        @disableMarkAsRead = false

    load:(info)->
        @clear()
        @archiveInfo = info
        @UI.emptyHint$.hide()
        @UI.loadingHint.hide()
        @render()
        @archiveListController.load(info)
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
    onNoMore:()->
        @UI.emptyHint$.show()

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
        @node$.find("img").on "load",()=>
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
        @markAsRead()
    resize:()->
        @size = {
            width:@node$.outerWidth()
            height:@node$.outerHeight()
        }
        @sizeDirty = false
        @node.setAttribute "size-info",JSON.stringify(@size)
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
        console.debug "mark as unread"
        @archive.markAsUnread (err)=>
            if err
                console.error err
                return
            console.debug "mark as unread done->render"
            console.debug @lockRead,@archive.hasRead,"is the state"
            @render()

# Control list level behavior, most of them
# should have something to do with the scroller.
tm.use "sourceView/archiveListController"
class ArchiveListController extends Leaf.Widget
    constructor:(archiveList)->
        super  App.templates.sourceView.archiveListController
        @archiveList = archiveList
        @formatter = new ArchiveListFormatter(@archiveList,this)

        @swipeChecker = new SwipeChecker(@node)
        @swipeChecker.on "swipeleft",(e)=>
            @node$.addClass "left-mode"
        @swipeChecker.on "swiperight",(e)=>
            e.preventDefault()
            e.stopImmediatePropagation()
            @node$.removeClass "left-mode"
        @archiveList.scrollChecker.listenBy this,"scroll",()=>
            @formatter.updateFocus()
#            console.log "reflow by current",@formatter.currentFocus
            @formatter.reflowAfter(@formatter.getFirstVisible())

            @checkLoadMore()
            if not @archiveList.disableMarkAsRead
                @markAsReadBeforeFocus()
        @archiveBuffer = new BufferedEndlessArchiveLoader()
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
        @isLoading = false
        @archiveInfo = info
        @archiveBuffer.reset()
        @archiveBuffer.init({
            query:{sourceGuids:@archiveInfo.sourceGuids}
            sort:@archiveList.sort
            viewRead:@archiveList.viewRead
        })
        @archiveList.archiveListItems.length = 0
        @checkLoadMore()
    checkLoadMore:()->
        if @isLoading
            return
        if @archiveBuffer.isDrain()
            return
        last = @formatter.getLastVisible()
        if last and @formatter.length() - last.index > 2
            @formatter.updateFocus()
            return
        @isLoading = true
        @archiveBuffer.oneMore (err,item)=>
            console.log "one more"
            @isLoading = false
            if err
                console.error err
                return
            if not item
                @archiveBuffer.isDrain()
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
            @archiveList.UI.containerWrapper.scrollTop = item.position - padding
        else
            console.log "fix"
            fix = (fixLine - top) - item.size.height/2
            @archiveList.UI.containerWrapper.scrollTop = item.position - fix - padding
    scrollTo:(top)->
        @archiveList.UI.containerWrapper.scrollTop = top
    getScrollTop:()->
        return @archiveList.UI.containerWrapper.scrollTop
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
            @archiveList.UI.containerWrapper.scrollTop = @currentFocus.node.offsetTop + @getFocus().node.offsetHeight
            return
        next = @formatter.at @currentFocus.index + 1
        if next
            console.log "scroll to",next.index,"from",@currentFocus.index
            @scrollToItem next
    onClickGoBottom:()->
        if not @currentFocus
            return
        @scrollToItem @currentFocus
        bottom = @currentFocus.node.offsetTop + @currentFocus.node.offsetHeight
        top = @archiveList.UI.containerWrapper.scrollTop
        height = @archiveList.UI.containerWrapper$.height()
        if bottom > top + height
            forward = bottom - (top + height)
            @archiveList.UI.containerWrapper.scrollTop += forward
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
    appendArchive:(archive)->
        item = new ArchiveListItem archive
        viewPort = @getViewPort()
        item.index = @context.archiveListItems.length
        item.node$.css {width:"100%",position:"absolute",zIndex:item.index}
        prev = @context.archiveListItems[item.index - 1]
        if prev
            item.setPosition(prev.getNextPosition())
        else
            item.setPosition(0)
        @context.archiveListItems.push item
        item.resize()
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
            if @inViewPort current,{expand:height}
                if not current.isShown
                    current.show()
                    firstVisible ?= current
            else if current.isShown
                current.hide()
        if @last()
            max = @last().size.height + @last().getPosition() + 200
            @context.UI.container$.css {minHeight:max}
        @restoreRelativeLocation()
        if firstVisible
            @reflowAfter firstVisible
    saveRelativeLocation:()->
        item = @updateFocus()
        offset = @controller.getScrollTop() - item.getPosition()
        @_relativeLocation = {
            offset,item
        }
    restoreRelativeLocation:()->
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
    constructor:(@archiveList)->
        super(@archiveList.UI.refreshHint)
        @init()
    onClickRefreshHint:()->
        @load(@archiveInfo)
    onClickHideRefreshHint:(e)->
        if e
            e.capture()
        @hideUpdateHint()
    init:()->
        @archiveList.on "load",()=>
            @hideUpdateHint()
        App.modelSyncManager.on "archive",(archive)=>
            if @archiveList.archiveInfo and archive.sourceGuid in @archiveList.archiveInfo.sourceGuids
                @showUpdateHint()
    showUpdateHint:()->

        @refreshHintShowInterval ?= 1000 * 15
        @archiveList.UI.refreshHint$.addClass("show")
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

Model = require "/model"
App = require "/app"
ScrollChecker = require "/util/scrollChecker"
SwipeChecker = require "/util/swipeChecker"
async = require "/lib/async"
EndlessArchiveLoader = require "/procedure/endlessArchiveLoader"
CubeLoadingHint = require "/widget/cubeLoadingHint"
ArchiveDisplayer = require "/baseView/archiveDisplayer"
Flag = require "/util/flag"
tm = require "/templateManager"
tm.use "sourceView/archiveList"
class ArchiveList extends Leaf.Widget
    constructor:(template)->
        @include CubeLoadingHint
        super(template or App.templates.sourceView.archiveList)
        @_appendQueue = async.queue(((item,done)=>
            @archiveListItems.push item
            if @archiveListItems.length is 1
                @emit "firstBlood"
            setTimeout((()=>
                done()
                ),4)
            ),1)

        # not implemented
        @sort = "latest"

        # should we view readed archive?
        @viewRead = false
        # for endlessl oad archive
        @loadCount = 10

        # mark reads on scroll
        @scrollChecker = new ScrollChecker @UI.containerWrapper
        @scrollChecker.listenBy this,"scroll",@onScroll
        @archiveListItems = Leaf.Widget.makeList @UI.container

        @archiveListController = new ArchiveListController(null,this)
        @initSubWidgets()
        App.modelSyncManager.on "archive",(archive)=>
            if @archiveInfo and archive.sourceGuid in @archiveInfo.sourceGuids
                @showUpdateHint()
        App.userConfig.on "change/previewMode",@applyPreviewMode.bind(this)
        App.userConfig.init "useResourceProxyByDefault",false
        App.userConfig.init "enableResourceProxy",true
    applyPreviewMode:()=>
        if not @archiveInfo
            return
        globalPreviewMode = App.userConfig.get("previewMode",false)
        infoPreviewMode = App.userConfig.get("previewModeFor"+@archiveInfo.name,globalPreviewMode)

        @disableMarkAsRead = true
        @archiveListController.saveLocation()
        if infoPreviewMode
            @node$.addClass("preview-mode")
        else
            @node$.removeClass("preview-mode")

        @archiveListController.restoreLocation()
        @disableMarkAsRead = false

    load:(info)->
        @clear()
        @archiveInfo = info
        query = {}
        query.sourceGuids = info.sourceGuids
        @_createArchiveLoader(query)
        @UI.emptyHint$.hide()
        @UI.loadingHint.hide()
        @archiveListItems.length = 0
        @render()
        @emit "load"
        @hideUpdateHint()
        @more()
    showUpdateHint:()->
        @refreshHintShowInterval ?= 1000 * 15
        @UI.refreshHint$.addClass("show")
        if @_updateHintTimer
            @_updateHintTimer = null
            clearTimeout @_updateHintTimer
        @_updateHintTimer = setTimeout @hideUpdateHint.bind(this),@refreshHintShowInterval
    hideUpdateHint:()->
        clearTimeout @_updateHintTimer
        @_updateHintTimer = null
        @UI.refreshHint$.removeClass("show")
    onClickRefreshHint:()->
        @load(@archiveInfo)
        @hideUpdateHint()
    onClickHideRefreshHint:(e)->
        if e
            e.capture()
        @hideUpdateHint()
    _createArchiveLoader:(query)=>
        if @archiveLoader
            @archiveLoader.stopListenBy this
        @archiveLoader = new EndlessArchiveLoader()
        @archiveLoader.reset({query:query,viewRead:@viewRead,sort:@sort,count:@loadCount})
        @archiveLoader.listenBy this,"archive",@appendArchive
        @archiveLoader.listenBy this,"noMore",@onNoMore
        @archiveLoader.listenBy this,"startLoading",()=>@UI.loadingHint.show()
        @archiveLoader.listenBy this,"endLoading",()=>@UI.loadingHint.hide()
        return @archiveLoader
    appendArchive:(archive)=>
        @UI.emptyHint$.hide()
        item = new ArchiveListItem(archive)
        @_appendQueue.push item
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
    more:(callback = ()->)->
        if not @archiveLoader
            callback("not ready")
            return
        if @archiveLoader.noMore
            callback("no more")
            return
        @archiveLoader.more (err)=>
            if err
                if err is "isLoading"
                    callback "loading"
                    return
                App.showError err
                callback "fail"
                return
            callback()
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
    onClickViewUnread:()->
        if not @viewRead then return
    onClickPreviewMode:()->
        console.debug "inside pm"
        if @archiveInfo
            console.log "pm in!"
            previewMode = App.userConfig.get "previewModeFor"+@archiveInfo.name,false
            console.log "pm ","previewModeFor"+@archiveInfo.name,previewMode
            App.userConfig.set "previewModeFor"+@archiveInfo.name,not previewMode
            @applyPreviewMode()
    onScroll:()->
        return
        # Maybe I should give the controll of this behavior
        # to @archiveListController.
        divider = @UI.containerWrapper.scrollTop
        divider += $(window).height()/3
        # if for some reason someone want to disable it.
        if @disableMarkAsRead
            return
        for item in @archiveListItems
            top = item.node.offsetTop
            bottom = item.node.offsetTop + item.node.clientHeight

            #console.log divider,top,bottom
            if divider > top and not item.archive.hasRead
                item.markAsRead()
                console.log "mark as read",item.archive.guid
tm.use "sourceView/archiveListItem"
class ArchiveListItem extends ArchiveDisplayer
    constructor:(archive)->
        super App.templates.sourceView.archiveListItem
        @setArchive archive
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
    fix:()->
        if @isFix
            return
        @isFix = true
        height = @node.clientHeight
        height = @node.offsetHeight
#        console.log @node$.height(),@node.clientHeight,@node.offsetHeight
        @node$.css {height:height,overflow:"hidden",visibility:"hidden"}
    unfix:()->
        if not @isFix
            return
        @isFix = false
        @node$.css {height:"auto",visibility:"visible"}
    onClickHeader:(e)->
        @node$.toggleClass("collapse")
        @markAsRead()
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

# Control some list level behavior, most of them
# should have something to do with the scroller.
tm.use "sourceView/archiveListController"
class ArchiveListController extends Leaf.Widget
    constructor:(template,archiveList)->
        super template or App.templates.sourceView.archiveListController
        @archiveList = archiveList
        @swipeChecker = new SwipeChecker(@node)
        @swipeChecker.on "swipeleft",(e)=>
            @node$.addClass "left-mode"
        @swipeChecker.on "swiperight",(e)=>
            e.preventDefault()
            e.stopImmediatePropagation()
            @node$.removeClass "left-mode"
        @archiveList.scrollChecker.listenBy this,"scroll",()=>
            @checkLoadMore()
            @updateFocus()
            if not @archiveList.disableMarkAsRead
                @markAsReadBeforeFocus()
        @locationStacks = []
        @archiveList.on "firstBlood",()=>
            @updateFocus()
        @archiveList.on "load",()=>
            @locationStacks = []
    checkLoadMore:()->
        if @archiveList.archiveListItems.length - 5 >= 0
            last = @archiveList.archiveListItems[@archiveList.archiveListItems.length - 5]
        else
            last = @archiveList.archiveListItems[0]
        if not last
            return
        if last.node.offsetTop < @archiveList.UI.containerWrapper.scrollTop
            @archiveList.more (err)->
                console.debug "load more",err
    at:(index)->
        return  @archiveList.archiveListItems[index] or null
    getFocus:()->
        if @focusIndex
            return @at @focusIndex
        else
            return @at 0
    updateFocusIndex:()->
        currentIndex = @getCurrentItemIndex()
        current = @at currentIndex
        height = @archiveList.UI.containerWrapper$.height()
        top = current.node.offsetTop
        bottom = top + current.node.offsetHeight
        scrollTop = @archiveList.UI.containerWrapper.scrollTop
        visible = bottom - scrollTop

        # If first item is short item.
        # we focus at least it's header is not visible
        if visible < height/2 and scrollTop - top > 5 and @at currentIndex + 1
            @focusIndex = currentIndex + 1
        else
            @focusIndex = currentIndex
    updateFocus:()->
        @updateFocusIndex()
        current = @getFocus()
        if not current
            return
        if current is @currentFocus
            return
        if @currentFocus
            @currentFocus.blur()
            @currentFocus.stopListenBy this
        @currentFocus = current
        console.debug "listen",@currentFocus
        @currentFocus.listenBy this,"change",()=>
            @render()
        @currentFocus.focus()
        for item,index in @archiveList.archiveListItems
            if Math.abs(index - @focusIndex) <= 2
                item.unfix()
            else
                item.fix()
        @render()
    markAsReadBeforeFocus:()->
        for index in [0..@focusIndex]
            item = @at index
            if item and not item.archive.hasRead
                item.markAsRead()
    onClickPrevious:()->
        # try scroll to top of the current item
        # only scroll to previous item when beginning of the
        # current item is visible
        focus = @getFocus()
        adjust = 5
        if @isItemTopVisible focus,adjust
            @scrollToItem @getPreviousItem()
        else
            @scrollToItem focus
    onClickNext:()->
        if @isLast @getFocus()
            @archiveList.UI.containerWrapper.scrollTop = @getFocus().node.offsetTop + @getFocus().node.offsetHeight
            return
        @scrollToItem @getNextItem()
    scrollToItem:(item)->
        if not item
            return
        top = item.node.offsetTop
        @archiveList.UI.containerWrapper.scrollTop = top
    isItemTopVisible:(item,adjust = 0)->
        top = @archiveList.UI.containerWrapper.scrollTop
        console.log item.node.offsetTop + adjust > top
        return item.node.offsetTop + adjust > top
    getCurrentItemIndex:()->
        top = @archiveList.UI.containerWrapper.scrollTop
        currentItem = @archiveList.archiveListItems[0]
        currentIndex = 0
        for item,index in @archiveList.archiveListItems
            if item.node.offsetTop > top
                break
            currentItem = item
            currentIndex = index
        return currentIndex
    getPreviousItem:()->
        return @at @focusIndex - 1
    getNextItem:()->
        return @at @focusIndex + 1
    isLast:(item)->
        return @archiveList.archiveListItems[@archiveList.archiveListItems.length - 1] is item
    saveLocation:()->
        focus = @getFocus()
        if focus
            @locationStacks.push focus
    restoreLocation:()->
        item = @locationStacks.pop()
        if item
            @scrollToItem item
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
    onClickGoBottom:()->
        if not @currentFocus
            return
        @scrollToItem @currentFocus
        bottom = @currentFocus.node.offsetTop + @currentFocus.node.offsetHeight
        top = @archiveList.UI.containerWrapper.scrollTop
        height = @archiveList.UI.containerWrapper$.height()
        console.debug top,height,bottom
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


#window.ArchiveListItem = ArchiveListItem
#window.ArchiveList = ArchiveList
module.exports = ArchiveList

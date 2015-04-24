App = require "/app"
Model = App.Model
ScrollChecker = require "/component/scrollChecker"
SwipeChecker = require "/component/swipeChecker"
async = require "/component/async"
BufferedEndlessArchiveLoader = require "/procedure/bufferedEndlessArchiveLoader"
CubeLoadingHint = require "/widget/cubeLoadingHint"
ArchiveDisplayer = require "/view/base/archiveDisplayer"
EndlessListRenderer = require "/component/endlessListRenderer"
Flag = require "/component/flag"
tm = require "/common/templateManager"
tm.use "view/sourceScene/archiveList"
class ArchiveList extends Leaf.Widget
    constructor:(template)->
        @include CubeLoadingHint
        super(template or App.templates.view.sourceScene.archiveList)

        # load query options
        @sort = "latest"
        @viewRead = false
        @loadCount = 10

        # mark reads on scroll
        @scrollChecker = new ScrollChecker @UI.containerWrapper

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

tm.use "view/sourceScene/archiveListItem"
class ArchiveListItem extends ArchiveDisplayer
    constructor:(archive)->
        super App.templates.view.sourceScene.archiveListItem
        @setArchive archive
        @isShown = true
        if not App.isMobile
            @node$.addClass "rich"
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
        @markAsRead()
        @node$.css {height:"auto"}
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
        @archive.lockRead = true
        @emit "change"
        if @archive.hasRead is false
            @render()
            return
        @archive.markAsUnread (err)=>
            if err
                console.error err
                return
            @render()
    destroy:()->
        super()
        @unsetArchive()
# Control list level behavior, most of them
# should have something to do with the scroller.
tm.use "view/sourceScene/archiveListController"
class ArchiveListController extends Leaf.Widget
    constructor:(@context)->
        super  App.templates.view.sourceScene.archiveListController
        @scrollable = @context.UI.containerWrapper
        @renderer = new EndlessListRenderer @scrollable,(archive)=>
            return new ArchiveListItem(archive)
        @archiveBuffer = new BufferedEndlessArchiveLoader()
        @swipeChecker = new SwipeChecker(@node)
        @swipeChecker.on "swipeleft",(e)=>
            @node$.addClass "left-mode"
        @swipeChecker.on "swiperight",(e)=>
            e.preventDefault()
            e.stopImmediatePropagation()
            @node$.removeClass "left-mode"
        @renderer.listenBy this,"reflow",(start,end)=>
            @updateFocusItem()
        @renderer.listenBy this,"resize",(start,end)=>
            @updateFocusItem()
        @context.disableMarkAsRead = true
        @renderer.listenBy this,"viewPortChange",()=>
            @updateFocusItem()
            if not @context.disableMarkAsRead
                if not @currentFocus
                    return
                current = @renderer.indexOf(@currentFocus)
                for archive,index in @renderer.datas
                    if index > current
                        return
                    if archive.hasRead
                        continue
                    if archive.lockRead
                        continue
                    archive.markAsRead ()->
        @renderer.listenBy this,"requireMore",()=>
            @loadMore()
        @archiveBuffer.on "startLoading",()=>
            if not @archiveBuffer.isDrain()
                @renderer.setHint @context.UI.hint
                @context.UI.loadingHint$.show()
                @context.UI.emptyHint$.hide()
        @archiveBuffer.on "endLoading",()=>
            @context.UI.loadingHint$.hide()
            if @archiveBuffer.isDrain()
                @context.UI.emptyHint$.show()
    updateFocusItem:()->
#        if @lastUpdateFocus
#            last = @lastUpdateFocus
#            @lastUpdateFocus = Date.now()
#            minInterval = 10
#            if Date.now() - last < minInterval
#                return


        height = @getFocusHeight()
        pack = @renderer.getPackByHeight(height)
        if not pack?.isRealized
            return
        if @currentFocus is pack.widget
            return
        if @currentFocus
            @currentFocus.blur()
            @currentFocus.stopListenBy this
        @currentFocus = pack.widget
        @currentFocus.listenBy this,"change",()=>
            @render()
        @currentFocus.focus()
        @renderer.trace pack
        @render()
    load:(info)->
        @renderer.reset()
        @isLoading = false
        @archiveInfo = info
        @archiveBuffer.reset()
        @context.UI.emptyHint$.hide()
        @archiveBuffer.init({
            query:{sourceGuids:@archiveInfo.sourceGuids}
            sort:@context.sort
            viewRead:@context.viewRead
        })
        @loadMore()

    loadMore:()->
        if @isLoading
            return
        if @archiveBuffer.isDrain()
            @context.UI.emptyHint$.show()
            return

        @isLoading = true
        @archiveBuffer.more 5,(err,archives)=>
            @isLoading = false
            if err
                @context.UI.loadingHint$.hide()
                console.error err
                return
            if not archives or archives.length is 0
                console.debug "NO MORE"
                @context.UI.emptyHint$.show()
                @context.UI.loadingHint$.hide()
                return
            for item in archives
                @renderer.add item
    getFocusHeight:()->

        # At beginning we will focus on the top item in the view port.
        # When scroll more, we are more like to focus on the center item in the view port.
        # This algo make sure we eventually focus on center item,
        # but won't jump the first item and won't skip any item.
        # Because fix = top*0.7 is continuous from (0~half viewport).
        # This is what fixline do.
        # algorithem to calculate the best position for the list item
        {top,height,bottom} = @renderer.getViewPort()
        fix = top * 0.7
        fixMax = height/3
        return (top + Math.min(fixMax,fix))
    getFocusHeightFix:()->
        {top,height,bottom} = @renderer.getViewPort()
        fix = top * 0.7
        fixMax = height/3
        return Math.min(fixMax,fix)
    getScrollTop:()->
        return @context.UI.containerWrapper.scrollTop
    scrollItemToFocus:(item)->
        # scroll item to the focus position
        if typeof item is "number"
            index = item
        else
            index = @renderer.indexOf(item)
        pack = @renderer.packs[index]
        if not pack or not pack.size
            return
        padding = 0
        scrollTop = pack.top
        vp = @renderer.getViewPort()
        if vp.height/2 > pack.size.height
            fix = @getFocusHeightFix()
            scrollTop -= fix - padding - pack.size.height/2
        @renderer.scrollable.scrollTop = scrollTop
        @renderer.saveTrace()
    scrollItemBottomToFocus:(item)->
        if typeof item is "number"
            index = item
        else
            index = @renderer.indexOf(item)
        pack = @renderer.packs[index]
        if not pack or not pack.size
            return

        scrollTop = pack.top
        vp = @renderer.getViewPort()
        if vp.height > pack.size.height
            @scrollItemToFocus(item)
            return
        if not pack.size
            console.debug item,"??"
        scrollTopEx = pack.size.height - vp.height
        scrollTop += scrollTopEx
#        if scrollTopEx < scrollTop
#            scrollTop = scrollTopEx


        @renderer.scrollable.scrollTop = scrollTop
        @renderer.saveTrace()
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
        if not @currentFocus
            return
        index = @renderer.indexOf(@currentFocus)
        if index <= 0
            index = 1
        @scrollItemToFocus index - 1
    onClickNext:()->
        if not @currentFocus
            return
        index = @renderer.indexOf(@currentFocus)
        @scrollItemToFocus index + 1
    onClickGoBottom:()->
        if not @currentFocus
            return
        index = @renderer.indexOf(@currentFocus)
        @scrollItemBottomToFocus index
    onClickLike:()->
        if @currentFocus
            @currentFocus.onClickLike()
    onClickShare:()->
        if @currentFocus
            @currentFocus.onClickShare()
    onClickKeepUnread:()->
        if @currentFocus
            @currentFocus.onClickKeepUnread()

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

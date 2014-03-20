class ArchiveList extends Leaf.Widget
    constructor:(template)->
        super(template or App.templates["archive-list"])
        @_appendQueue = async.queue(((item,done)=>
            if item._queueId isnt @_queueTaskId
                done()
                return
            setTimeout((()=>
                if item._queueId is @_queueTaskId
                    @appendArchiveListItem(item)
                done()
                ),10)
            ),1)
        @_queueTaskId = 0
        @archiveListItems = []
        @sort = "latest"
        @viewRead = false
        @offset = null
        @count = 20
        @scrollCheckTimer = setInterval (()=>
            if not @UI.containerWrapper then return
            if typeof @lastScrollTop is "number" and @lastScrollTop isnt @UI.containerWrapper.scrollTop
                @onScroll()
            @lastScrollTop = @UI.containerWrapper.scrollTop
            ),300
        
        App.userConfig.on "change/previewMode",@applyPreviewMode.bind(this)
        App.userConfig.init "useResourceProxyByDefault",false
        App.userConfig.init "enableResourceProxy",true
        
    applyPreviewMode:()=>
        if not @archiveInfo
            return
        globalPreviewMode = App.userConfig.get("previewMode",false)
        infoPreviewMode = App.userConfig.get("previewModeFor"+@archiveInfo.name,globalPreviewMode)
        if infoPreviewMode
            @node$.addClass("preview-mode")
        else
            @node$.removeClass("preview-mode")
    load:(info)->
        @clear()
        @UI.emptyHint$.hide()
        @archiveInfo = info
        @render()
        @moreArchive()
    render:()->
        @UI.title$.show()
        @UI.sourceName$.text @archiveInfo.name
        @applyPreviewMode()
        if @viewRead
            @UI.toggleViewAll$.text("view unread")
        else
            @UI.toggleViewAll$.text("view all")
    clear:()->
        # so the rest task in the queue won't be append
        # becase the id changed
        @_queueTaskId++
        @loadedGuids = []
        @isLoadingMore = false
        @noMore = false
        @offset = null
        for item in @archiveListItems
            item.remove()
        @archiveListItems.length = 0
        @UI.containerWrapper.scrollTop = 0
        @UI.emptyHint$.show()
        @UI.title$.hide()
    moreArchive:()->
        if @noMore
            return
        if @isLoadingMore
            return
        if not @archiveInfo
            return
        @isLoadingMore = true
        last = @archiveListItems[@archiveListItems.length-1]
        if last and last.archive
            @offset = last.archive.guid
        else
            @offset = undefined
        sourceGuids = @archiveInfo.sourceGuids
        _taskId = @_queueTaskId
        query = {}
        query.sourceGuids = sourceGuids
        console.log query
        @UI.loadingHint$.show()
        Model.Archive.getByCustom {query:query,viewRead:@viewRead,sort:@sort,offset:@offset,count:@count},(err,archives)=>
            @UI.loadingHint$.hide()
            @isLoadingMore = false
            # if it's cleared during the request
            if _taskId isnt @_queueTaskId
                console.debug("already loading archives");
                return
            if err or not (archives instanceof Array)
                console.error err or "no archive!"
                console.trace()
                return
            if archives.length is 0
                @onNoMore()
                return
            for archive in archives
                archiveListItem = new ArchiveListItem(archive)
                @appendListItemQueue(archiveListItem)
    appendListItemQueue:(item)->
        item._queueId  = @_queueTaskId
        @_appendQueue.push item
    onNoMore:()->
        console.log "noMore!",@offset,@count
        @noMore = true
        @UI.emptyHint$.show()
    appendArchiveListItem:(item)->
        @UI.emptyHint$.hide()
        if item.archive.guid in @loadedGuids
            # likely to be duplicated
            return
        @loadedGuids.push item.archive.guid
        item.appendTo @UI.container
        item.on "read",(data)=>
            App.emit "read",data
        item.on "unread",(data)=>
            App.emit "unread",data
        @archiveListItems.push item
    onClickMarkAllAsRead:()->
        async.eachLimit @archiveInfo.sourceGuids,3,((guid,done)=>
            source = Model.Source.getByGuid(guid)
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
                source.emit("change")
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
        if @UI.containerWrapper.scrollHeight - @UI.containerWrapper.scrollTop - @UI.containerWrapper.clientHeight < @UI.containerWrapper.clientHeight/2
            @moreArchive()
        divider = @UI.containerWrapper.scrollTop
        divider += $(window).height()/3
        for item in @archiveListItems
            top = item.node.offsetTop
            bottom = item.node.offsetTop + item.node.clientHeight
            
            #console.log divider,top,bottom
            if divider > top and not item.archive.hasRead
                item.markAsRead()
                console.log "mark as read",item.archive.guid
class ArchiveListItem extends ArchiveDisplayer
    constructor:(@archive)->
        super App.templates["archive-list-item"]
        @setArchive @archive
    onClickContent:()->
        if @lockRead
            return
        @archive.markAsRead (err)=>
            if err
                console.error err
                return
            @render()
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
            @render()
            @isMarking = false
    # UI top alias for markas unread
    onClickKeepUnread:(e)->
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

window.ArchiveListItem = ArchiveListItem
window.ArchiveList = ArchiveList
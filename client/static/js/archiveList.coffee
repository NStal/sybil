Model = require("model")
App = require "app"
ScrollChecker = require "util/scrollChecker"
async = require "lib/async"
EndlessArchiveLoader = require("procedure/endlessArchiveLoader")
class ArchiveList extends Leaf.Widget
    constructor:(template)->
        super(template or App.templates["archive-list"])
        @_appendQueue = async.queue(((item,done)=>
            @archiveListItems.push item
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
        @archiveListItems.on "child/remove",(child)=>
            child.destroy()
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
        @archiveInfo = info
        query = {}
        query.sourceGuids = info.sourceGuids
        @_createArchiveLoader(query);
        @UI.emptyHint$.hide()
        @UI.loadingHint$.hide()
        @archiveListItems.length = 0;
        @render()
        @more()
    _createArchiveLoader:(query)=>
        if @archiveLoader
            @archiveLoader.stopListenBy this
        @archiveLoader = new EndlessArchiveLoader() 
        @archiveLoader.reset({query:query,viewRead:@viewRead,sort:@sort,count:@loadCount})
        @archiveLoader.listenBy this,"archive",@appendArchive
        @archiveLoader.listenBy this,"noMore",@onNoMore
        @archiveLoader.listenBy this,"startLoading",()=>@UI.loadingHint$.show()
        @archiveLoader.listenBy this,"endLoading",()=>@UI.loadingHint$.hide()
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
        # so the rest task in the queue won't be append
        # becase the id changed
        if @archiveLoader
            @archiveLoader.destroy()
        @archiveLoader = null
        @UI.containerWrapper.scrollTop = 0
        @UI.emptyHint$.show()
        @UI.title$.hide()
    more:()->
        if not @archiveLoader
            return
        if @archiveLoader.noMore
            return
        @archiveLoader.more (err)=>
            if err
                if err is "isLoading"
                    return
                App.showError err
                return
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
        if @UI.containerWrapper.scrollHeight - @UI.containerWrapper.scrollTop - @UI.containerWrapper.clientHeight < @UI.containerWrapper.clientHeight/2
            @more()
        divider = @UI.containerWrapper.scrollTop
        divider += $(window).height()/3
        for item in @archiveListItems
            top = item.node.offsetTop
            bottom = item.node.offsetTop + item.node.clientHeight
            
            #console.log divider,top,bottom
            if divider > top and not item.archive.hasRead
                item.markAsRead()
                console.log "mark as read",item.archive.guid
        
class ArchiveListItem extends require("archiveDisplayer")
    constructor:(archive)->
        super App.templates["archive-list-item"]
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
        
#window.ArchiveListItem = ArchiveListItem
#window.ArchiveList = ArchiveList
module.exports = ArchiveList
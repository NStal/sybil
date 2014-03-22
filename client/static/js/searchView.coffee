class SearchView extends View
    constructor:()->
        @searchList = new SearchList()
        @archiveDisplayer = new ArchiveDisplayer(App.templates["archive-displayer"])
        @archiveDisplayer.node$.hide()
        @searchList.on "select",(archive)=>
            console.log "select",archive
            @archiveDisplayer.setArchive(archive);
            @archiveDisplayer.node$.show();
            @node$.addClass("show-displayer");
        super($(".search-view")[0],"search view")
        # mobile
        checker = new SwipeChecker(@node);
        checker.on "swiperight",(ev)=>
            @node$.removeClass("show-displayer");
        checker.on "swipeleft",(ev)=>
            @node$.addClass("show-displayer");
    show:()->
        super()
        @node$.removeClass("show-displayer");

class SearchList extends Leaf.Widget
    constructor:()->
        super App.templates["search-list"]
        @resultList = Leaf.Widget.makeList @UI.resultList
        @count = 30
        @offset = 0
        @_queueTaskId = 0
        @UI.searchKeywordInput$.keydown (e)=>
            if e.which is Leaf.Key.enter
                @onClickSearchButton()
                return false
        @_searchId = 0
        @_pushInterval = 10
        @appendQueue = async.queue ((item,done)=>
            if item.id isnt @_searchId
                done()
                return
            listItem = new SearchListItem(item.archive)
            listItem.onClickNode = ()=>
                @emit "select",listItem.archive
            
            listItem.onMouseoverNode = ()=>
                @emit "select",listItem.archive
            @resultList.push listItem 
            setTimeout done,@_pushInterval
            ),1
        @node.onscroll = ()=>
            @onScroll()
        @_noMore = true
        @__defineSetter__ "noMore",(value)=>
            if value and value isnt @_noMore
                @UI.noMoreHint$.show()
            else
                @UI.noMoreHint$.hide()
            @_noMore = value
        @__defineGetter__ "noMore",()=>
            return @_noMore
            
        @_isLoading = false
        @__defineSetter__ "isLoading",(value)=>
            if value and value isnt @_isLoading
                @UI.loadingHint$.show()
            else
                @UI.loadingHint$.hide()
            @_isLoading = value
            console.debug "change loading",value
        
        @__defineGetter__ "isLoading",(value)=>
            return @_isLoading
        @isLoading = false
        @scrollTarget = @node
    onScroll:()->
        console.log @scrollTarget.scrollHeight - @scrollTarget.scrollTop - @scrollTarget.clientHeight,@scrollTarget.clientHeight/2
        if @scrollTarget.scrollHeight - @scrollTarget.scrollTop - @scrollTarget.clientHeight < @scrollTarget.clientHeight/2
            @more()
    applySearch:(query)->
        @query = query
        @offset = 0
        @noMore = false
        @isLoading = false
        @_queueTaskId++
        @resultList.length = 0
        @more()
    more:()->
        if not @query
            return
        if @noMore
            return
        if @isLoading
            return
        @isLoading = true
        App.messageCenter.invoke "search",{input:@query,count:@count or 10,offset:@offset or 0},(err,archives)=>
            console.debug archives.length,@count,@offset,@query
            @isLoading = false
            if err
                App.showError err
                return
            if archives.length is 0
                @noMore = true
                return
            @offset += archives.length
            for archive in archives
                item = new Model.Archive(archive)
                @appendQueue.push {archive:item,id:@_searchId}
    onClickSearchButton:()->
        query = @UI.searchKeywordInput.value.trim()
        @applySearch(query)

class SearchListItem extends Leaf.Widget
    constructor:(@archive)->
        super App.templates["search-list-item"]
        @archive.on "change",()=>
            @render()
        @render()
    render:()->
        @UI.title$.text(@archive.title)
        @UI.preview$.text(@_htmlToPreview @archive.content);
        if not @archive.createDate
            time = (new Date(0)).getTime()
        else
            time = @archive.createDate.getTime()
        now = Date.now()
        tilNow = now - time
        minute = 1000 * 60
        hour = minute * 60
        day = hour * 24
        month = day * 30
        year = day * 365
        text = ""
        if tilNow < minute
            text = "seconds ago"
        else if tilNow < hour
            text = "minutes ago"
        else if tilNow < day
            text = "hours ago"
        else if tilNow < month
            text = "days ago"
        else if tilNow < month * 2
            text = "weeks ago"
        else if tilNow < year
            text = "months ago"
        else 
            text = "years ago"
        @UI.time$.text text
        if not @archive.like
            @UI.like$.hide()
        else
            @UI.like$.show()
    _htmlToPreview:(html,count)->
        @_tempDiv = @_tempDiv or document.createElement("div")
        @_tempDiv.innerHTML = html
        return $(@_tempDiv).text().substring(0,count or 200)+"..."
window.SearchView = SearchView
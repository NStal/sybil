App = require "/app"
Model = require "/model"
View = require "/view"
ArchiveDisplayer = require "/baseView/archiveDisplayer"
SwipeChecker = require "/util/swipeChecker"
EndlessSearchArchiveLoader = require "/procedure/endlessSearchArchiveLoader"
async = require "/lib/async"
CubeLoadingHint = require "/widget/cubeLoadingHint"
tm = require "/templateManager"
class SearchView extends View
    constructor:()->
        @searchList = new SearchList()
        @archiveDisplayer = new ArchiveDisplayer(App.templates.baseView.archiveDisplayer)
        @archiveDisplayer.node$.hide()
        @searchList.on "select",(archive)=>
            console.log "select",archive
            @archiveDisplayer.setArchive(archive)
            console.debug "~~~",@archiveDisplayer.node.scrollTop
            @archiveDisplayer.node.scrollTop = 0
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

tm.use "searchView/searchList"
class SearchList extends Leaf.Widget
    constructor:()->
        @include CubeLoadingHint
        super App.templates.searchView.searchList
        @resultList = Leaf.Widget.makeList @UI.resultList
        @UI.searchKeywordInput$.keydown (e)=>
            if e.which is Leaf.Key.enter
                @onClickSearchButton()
                return false
        @_searchId = 0
        @_pushInterval = 4
        @appendQueue = async.queue ((archive,done)=>
            listItem = new SearchListItem(archive)
            listItem.onClickNode = ()=>
                console.debug "select",listItem.archive
                @emit "select",listItem.archive
            listItem.onMouseoverNode = ()=>
                @emit "select",listItem.archive
            @resultList.push listItem
            setTimeout done,@_pushInterval
            ),1
        @node.onscroll = ()=>
            @onScroll()
        @scrollTarget = @node
        @viewRead = true
        @loadCount = 20
    onScroll:()->
        console.log @scrollTarget.scrollHeight - @scrollTarget.scrollTop - @scrollTarget.clientHeight,@scrollTarget.clientHeight/2
        if @scrollTarget.scrollHeight - @scrollTarget.scrollTop - @scrollTarget.clientHeight < @scrollTarget.clientHeight/2
            @more()
    applySearch:(query)->
        @query = query
        @offset = 0
        @resultList.length = 0
        if @searcher
            @searcher.stopListenBy this
        @searcher = new EndlessSearchArchiveLoader();
        @searcher.reset {query:query,viewRead:@viewRead,count:@loadCount}
        @searcher.listenBy this,"archive",@appendArchive
        @searcher.listenBy this,"noMore",@onNoMore
        @more()
    more:()->
        if not @query
            return
        if not @searcher
            return
        if @searcher.noMore
            return
        if @searcher.isLoading
            return
        @UI.loadingHint.show()
        @searcher.more (err,archives)=>
            @UI.loadingHint.hide()
            if err
                App.showError err
                return
    appendArchive:(archive)->
        console.debug archive,"to append"
        @UI.noMoreHint$.hide()
        @appendQueue.push archive
    onNoMore:()->
        @UI.noMoreHint$.show()
    onClickSearchButton:()->
        query = @UI.searchKeywordInput.value.trim()
        @applySearch(query)

tm.use "searchView/searchListItem"
class SearchListItem extends Leaf.Widget
    constructor:(@archive)->
        super App.templates.searchListItem
        @archive.listenBy this,"change",@render
        @render()
    render:()->
        @UI.title$.text(@archive.title)
        @UI.preview$.text(@_htmlToPreview @archive.content);
        if not @archive.createDate
            time = (new Date(0)).getTime()
        else
            console.log @archive.createDate
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
module.exports = SearchView

App = require "/app"
Model = App.Model
Scene = require "/scene"
ArchiveDisplayer = require "/view/base/archiveDisplayer"
SwipeChecker = require "/component/swipeChecker"
EndlessSearchArchiveLoader = require "/procedure/endlessSearchArchiveLoader"
async = require "/component/async"
CubeLoadingHint = require "/widget/cubeLoadingHint"
tm = require "/common/templateManager"

tm.use "view/searchScene/scene"
class SearchScene extends Scene
    constructor:()->
        @searchList = new SearchList()
        @archiveDisplayer = new ArchiveDisplayer(App.templates.baseView.archiveDisplayer)
        @archiveDisplayer.node$.hide()
        @searchList.on "select",(archive)=>
            @archiveDisplayer.setArchive(archive)
            @archiveDisplayer.node.scrollTop = 0
            @archiveDisplayer.node$.show();
            @node$.addClass("show-displayer");
        super App.templates.view.searchScene.scene,"search scene"
        # mobile
        checker = new SwipeChecker(@node);
        checker.on "swiperight",(ev)=>
            @node$.removeClass("show-displayer");
        checker.on "swipeleft",(ev)=>
            @node$.addClass("show-displayer");
    show:()->
        super()
        @node$.removeClass("show-displayer");

tm.use "view/searchScene/searchList"
class SearchList extends Leaf.Widget
    constructor:()->
        @include CubeLoadingHint
        super App.templates.view.searchScene.searchList
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
        @UI.noMoreHint$.hide()
        @appendQueue.push archive
    onNoMore:()->
        @UI.noMoreHint$.show()
    onClickSearchButton:()->
        query = @UI.searchKeywordInput.value.trim()
        @applySearch(query)

tm.use "view/searchScene/searchListItem"
class SearchListItem extends Leaf.Widget
    constructor:(@archive)->
        super App.templates.view.searchScene.searchListItem
        @archive.listenBy this,"change",@render
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
module.exports = SearchScene

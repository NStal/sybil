SwipeChecker = require("/util/swipeChecker")
SourceList = require("sourceList")
ArchiveList = require("archiveList")
SourceDetail = require("sourceDetail")

class SourceView extends require("/view")
    constructor:()->
        @sourceList = new SourceList()
        @archiveList = new ArchiveList()
        @sourceList.on "select",(info)=>
            @archiveList.load info
            @node$.removeClass "show-list"
        @sourceDetail = new SourceDetail()
        super $(".source-view")[0],"source view"
        @node$.addClass "show-list"
        checker = new SwipeChecker(this.node)
        checker.swipeFloor = $(window).width()/4
        checker.on "swiperight",(ev)=>
            @node$.addClass "show-list"
        checker.on "swipeleft",(ev)=>
            @node$.removeClass "show-list"
        @UI.sourceListOverlay$.click ()=>
            @node$.removeClass "show-list"
        @km = new Leaf.KeyEventManager(window)
        @km.on "keydown",(e)=>
            use = true
            if e.which is Leaf.Key.p and e.altKey
                @archiveList.archiveListController.onClickPrevious()
            else if e.which is Leaf.Key.n and e.altKey
                @archiveList.archiveListController.onClickNext()
            else if e.which is Leaf.Key.b and e.altKey
                @archiveList.archiveListController.onClickGoBottom()
            else
                use = false
            if use
                e.capture()
    onSwitchTo:()->
        @km.active()
        @isActive = true
        @sourceList.reflow()
    onSwitchOff:()->
        @km.deactive()
        @isActive = false
module.exports = SourceView

App = require "/app"
SwipeChecker = require("/component/swipeChecker")
SourceList = require("./sourceList")
ArchiveList = require("./archiveList")
SourceDetail = require("./sourceDetail")
tm = require "/common/templateManager"

tm.use "view/sourceScene/scene"
class SourceScene extends require("/view/base/scene")
    constructor:()->
        @sourceList = new SourceList()
        @archiveList = new ArchiveList()
        @sourceList.on "select",(info)=>
            @archiveList.load info
            @node$.removeClass "show-list"
        @sourceDetail = new SourceDetail()
        super App.templates.view.sourceScene.scene,"source scene"
        @showList()
        checker = new SwipeChecker(this.node)
        checker.swipeFloor = $(window).width()/4
        checker.on "swiperight",(ev)=>
            @showList()
        checker.on "swipeleft",(ev)=>
            @hideList()
        @UI.sourceListOverlay$.click ()=>
            @hideList()
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
    showList:()->
        @showListIdentifier ?= {}
        @node$.addClass "show-list"
        App.history.push @showListI,()=>
            @hideList()
    hideList:()->
        @node$.removeClass "show-list"
        App.history.remove @showListIdentifier
    onSwitchTo:()->
        @km.active()
        @isActive = true
        @sourceList.reflow()
    onSwitchOff:()->
        @km.deactive()
        @isActive = false
module.exports = SourceScene

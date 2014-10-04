SwipeChecker = require("util/swipeChecker")
SourceList = require("sourceList")
ArchiveList = require("archiveList")
SourceDetail = require("sourceDetail")
class SourceView extends require("view")
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
        checker.on "swiperight",(ev)=>
            @node$.addClass "show-list"
        checker.on "swipeleft",(ev)=>
            @node$.removeClass "show-list"
        @UI.sourceListOverlay$.click ()=>
            @node$.removeClass "show-list"
module.exports = SourceView
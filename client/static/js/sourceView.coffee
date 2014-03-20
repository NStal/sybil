class SourceView extends View
    constructor:()->
        @sourceList = new SourceList()
        @archiveList = new ArchiveList()
        @sourceList.on "select",(info)=>
            @archiveList.load info
        super $(".source-view")[0],"source view"
        @node.ontouchstart = (e)=>
            @lastStartDate = Date.now()
            @lastStartEvent = e
        @node.ontouchmove = (e)=>
            @lastMoveEvent = e
            if not @lastMoveEvent or not @lastStartEvent
                return
            #alert Math.abs(@lastStartEvent.touches[0].clientX - @lastMoveEvent.touches[0].clientX) > 50
            if Math.abs(@lastStartEvent.touches[0].clientY - @lastMoveEvent.touches[0].clientY) > Math.abs( @lastStartEvent.touches[0].clientY - @lastMoveEvent.touches[0].clientY)
                @lastStartEvent.preventDefault()
                @lastMoveEvent.preventDefault()
        Hammer(@node).on "swiperight",(ev)=>
            ev.preventDefault()
            @node$.addClass "show-list"
        Hammer(@node).on "swipeleft",(ev)=>
            ev.preventDefault()
            @node$.removeClass "show-list"
        @UI.sourceListOverlay$.click ()=>
            @node$.removeClass "show-list"
window.SourceView = SourceView
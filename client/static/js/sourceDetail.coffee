class SourceDetail extends Leaf.Widget
    constructor:()->
        super App.templates["source-detail"]
        @render = @render.bind(this)
    setSource:(source)->
        if @source
            @source.removeListener("change",this.render)
        @source = source
        @source.on("change",this.render);
        @render()
        @source.queryStatisticInfo (err)=>
            console.error err
            console.error @source.statistic,@source.totalArchive
    render:()->
        @UI.name$.text @source.name
        @UI.uri$.text @source.uri
        @UI.type$.text @source.collectorName
        @UI.archives$.text "unread/total #{@source.unreadCount}/#{@source.totalArchive or '?'}"
    show:()->
        @node$.show()
    hide:()->
        @node$.hide()
    onClickClose:()->
        @hide()
window.SourceDetail = SourceDetail
        
class SourceDetail extends Leaf.Widget
    constructor:()->
        @sourceStatistic = new SourceStatistic()
        super App.templates["source-detail"]
        @render = @render.bind(this)
        @appendTo document.body
#        window.onmousemove = (e)=>
#            @position = [e.clientX,e.clientY]
#        @node$.on "mousemove",(e)=>
#            e.stopImmediatePropagation()
#            e.preventDefault()
    setSource:(source)->
        if @source
            @source.removeListener("change",this.render)
        @source = source
        @source.on("change",this.render);
        @render()
        @source.queryStatisticInfo()
    render:()->
        @UI.name$.text @source.name
        @UI.uri$.text @source.uri
        @UI.type$.text @source.collectorName
        @UI.archives$.text "#{@source.unreadCount}/#{@source.totalArchive or '?'}"
        @onClickCancelDescriptionButton()
        if @source.statistic
            @sourceStatistic.load @source.statistic
            result = 0
            for item in @source.statistic
                result += item
            perweek = result/@source.statistic.length*7
            if perweek < 1
                perweek = perweek.toPrecision(2)
            else
                perweek = parseInt(Math.ceil perweek)
            console.debug "???"
            @UI.frequency$.text "#{perweek} post per week"
    show:()->
        if SourceDetail.currentDetail
            SourceDetail.currentDetail.hide()
        SourceDetail.currentDetail = this
        @left = ($(document.body).width()-@node$.width())/2
        @top = ($(document.body).height()-@node$.height())/2
        @node$.css({top:@top,left:@left})
        @node$.show()
        @sourceStatistic.resize()
        @render()
    hide:()->
        @node$.hide()
    onClickClose:()->
        @hide()
    onClickNameEditButton:()->
        name = prompt("would you like to rename #{@source.title}",@source.title).trim()
        if not name
            return
        @source.rename name
    onClickDescriptionEditButton:()->
        @UI.description$.hide()
        @UI.descriptionEditor$.show()
        @UI.descriptionInput$.val(@source.description or "")
    onClickSubmitDescriptionButton:()->
        value = @UI.descriptionInput$.val()
        @source.describe value,()->
            @onClickCancelDescriptionButton()
            @UI.descriptionEditor$.hide()
            @UI.description$.show()
    onClickCancelDescriptionButton:()->
        @UI.descriptionEditor$.hide()
        @UI.description$.show()
        
        
class SourceStatistic extends Leaf.Widget
    constructor:()->
        super "<canvas></canvas>"
        @context = @node.getContext("2d")
        #setInterval @render.bind(this),100
    resize:()->
        @node.width = @node$.width()
        @node.height = @node$.height()
        @width = @node.width
        @height = @node.height
    load:(info)->
        @info = info
        @render()
    render:()->
        if not @info
            return
        console.log "start render",@info,@width,@height
        max = Math.max.apply Math,@info
        maxHeight = @height* (max/(max+5))
        @context.clearRect(0,0,@width,@height)
        @color = "rgba(0,0,0,0.5)"
        step = @width / (@info.length + 1)
        offset = parseInt(step/2)
        @context.fillStyle = @color
        for count in @info 
            console.log "render with info",count
            #@context.rect offset,0,offset+step/2,count*maxHeight/max
            @context.beginPath()
            @context.rect parseInt(offset),@height-parseInt(count*maxHeight/max),parseInt(step/2),parseInt(count*maxHeight/max)
            @context.fill()
            @context.closePath()
            offset += step
        
window.SourceDetail = SourceDetail
        
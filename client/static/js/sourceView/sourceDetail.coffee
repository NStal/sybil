App = require "/app"
Popup = require "/widget/popup"
moment = require "/lib/moment"
tm = require "/templateManager"

tm.use "sourceView/sourceDetail"
class SourceDetail extends Popup
    constructor:()->
        @sourceStatistic = new SourceStatistic()
        super App.templates.sourceView.sourceDetail
    setSource:(source)->
        if @source
            @source.stopListenBy this
        @source = source
        @source.listenBy this,"change",this.render
        @reset()
        @render()
        @source.queryStatisticInfo()
    reset:()->
        @renderData.refreshStyle = ""
    render:()->
        @renderData = {
            "errorDescription":@source.lastError and JSON.stringify(@source.lastError) or @source.lastErrorDescription or "None"
            "lastUpdate":@source.lastUpdate and moment(@source.lastUpdate).fromNow() or "Never"
            "lastFetch":@source.lastFetch and moment(@source.lastFetch).fromNow() or "Never"
            "fetchInterval":@source.nextFetchInterval and moment.duration(@source.nextFetchInterval).humanize() or "Never"
        }
        @UI.name$.text @source.name
        @UI.uri$.text @source.uri
        @UI.uri$.attr "href",@source.uri
        @UI.type$.text @source.collectorName
        @UI.archives$.text "#{@source.unreadCount}/#{@source.totalArchive or '?'}"
        @UI.descriptionContent$.text @source.description or "none"
        @onClickCancelDescriptionButton()
        if App.userConfig.get "enableResourceProxy/#{@source.guid}"
            @UI.enableResourceProxy.checked = true
        else
            @UI.enableResourceProxy.checked = false
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
            @UI.frequency$.text "#{perweek} post per week"
    onClickEnableResourceProxy:()->
        if App.userConfig.get "enableResourceProxy/#{@source.guid}"
            @UI.enableResourceProxy.checked = false
            App.userConfig.set "enableResourceProxy/#{@source.guid}",false
        else
            @UI.enableResourceProxy.checked = true
            App.userConfig.set "enableResourceProxy/#{@source.guid}",true
    show:()->
        if SourceDetail.currentDetail
            SourceDetail.currentDetail.hide()
        super()
        SourceDetail.currentDetail = this
        @left = ($(document.body).width()-@node$.width())/2
        @top = ($(document.body).height()-@node$.height())/2
        @node$.css({top:@top,left:@left})
        @node$.show()
        @sourceStatistic.resize()
        @render()
    hide:()->
        super()
        @node$.hide()
    onClickClose:()->
        @hide()
    onClickForceUpdateButton:()->
        source = @source
        console.debug "source update"
        @renderData.refreshStyle = "fa-spin"
        source.forceUpdate (err)=>
            console.debug "source update done hehe?",err,"??"

            @renderData.refreshStyle = ""
            if source isnt @source
                # current source has changed, ignore the result
                return
            if err
                @source.lastError = err
                @source.lastErrorDescription = err.message
            else
                App.toast "refreshed"
                return
    onClickNameEditButton:()->
        name = prompt("would you like to rename #{@source.name}",@source.name).trim()
        if not name
            return
        @source.rename name
    onClickDescriptionEditButton:()->
        @UI.description$.hide()
        @UI.descriptionEditor$.show()
        @UI.descriptionInput$.val(@source.description or "")
    onClickSubmitDescriptionButton:()->
        value = @UI.descriptionInput$.val()
        @source.describe value,()=>
            @onClickCancelDescriptionButton()
            @UI.descriptionEditor$.hide()
            @UI.description$.show()
    onClickCancelDescriptionButton:()->
        @UI.descriptionEditor$.hide()
        @UI.description$.show()

#class SourceRuningState extends Leaf.Widget

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
        max = Math.max.apply Math,@info
        maxHeight = @height* (max/(max+5))
        @context.clearRect(0,0,@width,@height)
        @color = "rgba(255,255,255,0.8)"
        step = @width / (@info.length + 1)
        offset = parseInt(step/2)
        @context.fillStyle = "#d9d9d9"
        for count in @info
            #@context.rect offset,0,offset+step/2,count*maxHeight/max
            @context.beginPath()
            @context.rect parseInt(offset),@height-parseInt(count*maxHeight/max),parseInt(step/2),parseInt(count*maxHeight/max)
            @context.fill()
            @context.closePath()
            offset += step

#window.SourceDetail = SourceDetail
module.exports = SourceDetail

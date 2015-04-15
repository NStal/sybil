App = require "/app"
tm = require "/templateManager"
SmartImage = require "/widget/smartImage"
class ContentImage extends SmartImage
    @getSize:()->
        if $(window).width() < 746
            return  "thumb"
        return "medium"
    constructor:(el,params)->
        super(el,params)
        @expose "originalSrc"
        @expose "thumbSrc"
        @expose "mediumSrc"
        @expose "size"
        for prop of params
            @node[prop] = params[prop]

    onSetMediumSrc:(src)->
        @mediumSrc = src
        @updateDisplay()
    onClickNode:()->
        App.emit "originalImage",@originalSrc or @src
    onSetOriginalSrc:(src)->
        @originalSrc = src
        @updateDisplay()
    onSetMediumSrc:(src)->
        @mediumSrc = src
        @updateDisplay()
    onSetThumbSrc:(src)->
        @thumbSrc = src
        @updateDisplay()
    updateDisplay:()->
        if @isDestroyed
            return
        @size ?= ContentImage.size ?= ContentImage.getSize()
        if @size is "thumb"
            @node.src = @thumbSrc or @mediumSrc or @originalSrc or @src
        else if ContentImage.size is "original"
            @node.src = @originalSrc or @mediumSrc or @thumbSrc or @src
        else if ContentImage.size is "medium"
            @node.src = @mediumSrc or @originalSrc or @thumbSrc or @src
        else
            @node.src = @mediumSrc or @thumbSrc or @originalSrc or @src

    onClickNode:()->
        App.imageDisplayer.setSrc(@originalSrc or @src or @mediumSrc or @thumbSrc)
        App.imageDisplayer.show()
module.exports = ContentImage

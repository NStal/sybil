App = require "/app"
tm = require "/templateManager"
SmartImage = require "/widget/smartImage"
class ContentImage extends SmartImage
    constructor:(el,params)->
        @expose "originalSrc"
        @expose "thumbSrc"
        super(el,params)
    onClickNode:()->
        App.emit "originalImage",@originalSrc or @src
    onSetOriginalSrc:(src)->
        @originalSrc = src
        @updateDisplay()
    onSetThumbSrc:(src)->
        @thumbSrc = src
        @updateDisplay()
    updateDisplay:()->
        ContentImage.size ?= ContentImage.getSize()
        if ContentImage.size is "thumb"
            @node.src = @thumbSrc or @originalSrc or @src
        else if ContentImage.size is "original"
            @node.src = @originalSrc or @thumbSrc or @src
        else
            @node.src = @thumbSrc or @originalSrc or @src

module.exports = ContentImage

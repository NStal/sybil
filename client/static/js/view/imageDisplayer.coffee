App = require "/app"
tm = require "/templateManager"
SmartImage = require "/widget/smartImage"
Popup = require "/widget/popup"
CubeLoadingHint = require "/widget/cubeLoadingHint"
tm.use "imageDisplayer"
class ImageDisplayer extends Popup
    constructor:()->
        @include SmartImage
        @include CubeLoadingHint
        super App.templates.imageDisplayer
        @UI.image.on "state",(state)=>
            if state is "loading"
                @VM.imageState = "loading"
            else if state is "fail"
                @VM.imageState = "failed"
            else
                @VM.imageState = "ready"
        @UI.image.onclick = ()=>
            @hide()
    setSrc:(src)->
        @UI.image.src = src
    onClickNode:()->
        @hide()
    onClickImage:()->
        @hide()
module.exports = ImageDisplayer

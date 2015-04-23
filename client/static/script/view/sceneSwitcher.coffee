App = require "/app"
tm = require "/common/templateManager"
async = require "/component/async"
Scene = require "/view/base/scene"

tm.use "view/sceneSwitcher"
class SceneSwitcher extends Leaf.Widget
    constructor:()->
        super App.templates.view.sceneSwitcher
        @currentScene = null
        @sceneItems = []
        @hideListener = @hideListener.bind(this)
        @hide()
    switchTo:(name,option = {})->
        has = false
        for scene in Scene.scenes when scene.name is name
            if @currentScene and @currentScene.name is name
                return
            oldScene = @currentScene
            @currentScene = scene

            oldScene?.remove()
            @currentScene.after this

            if oldScene and oldScene.onSwitchOff
                oldScene.onSwitchOff()
            scene.show()
            @emit "sceneChange",scene
            @VM.title = name
            if scene.onSwitchTo
                scene.onSwitchTo()
            if not option.noHistory and oldScene
                oldName = oldScene.name
                App.history.push this,()=>
                    @switchTo oldName,{noHistory:true}
            return
        if not has
            throw new Error "scene #{name} not found"
    onClickTitle:(e)->
        e.stopImmediatePropagation()
        e.preventDefault()
        @syncScenes()
        if @isShow
            @hide()
        else
            @show()
    hideListener:(e)->
        e.stopImmediatePropagation()
        e.preventDefault()
        @hide()
        return false
    show:()->
        window.addEventListener "click",@hideListener
        @isShow = true
        # actually height is still controlled by css
        # 80px max height per item is generall more than the per item height
        @VM.showSelector = true
        @VM.caretClass = "fa-caret-down"
        @showIdentifier ?= {}
        App.history.push @showIdentifier,()=>
            @hide()
    hide:()->
        window.removeEventListener "click",@hideListener
        @isShow = false
        @VM.showSelector = false
        @VM.caretClass = "fa-caret-right"
        App.history.remove @showIdentifier
    syncScenes:()->
        # Do a complete sync with Scene.scenes an @sceneItems
        # They are different data type so sync take some steps
        for myScene in @sceneItems
            myScene.__match = "not match"
        for scene in Scene.scenes
            has = false
            # in @sceneItems?
            for myScene in @sceneItems
                if scene.name is myScene.name
                    has = true
                    myScene.__match = "match"
                    break
            # in Scene.scenes not in @sceneItems
            # so create it
            if not has
                @addScene(scene.name)
        # Those in sceneItems but not found in Scene.scenes should be removed
        @sceneItems = @sceneItems.filter (item)->item.__match isnt "not match"
    addScene:(name)->
        sceneItem = new SceneSelectItem(name)
        @sceneItems.push sceneItem
        sceneItem.appendTo @UI.sceneSelector
        sceneItem.on "select",()=>
            @switchTo sceneItem.name
            @hide()
#    onClickAddSourceButton:()->
#        App.addSourcePopup.show()
#    onClickSettingButton:()->
#        App.settingPanel.show()

class SceneSelectItem extends Leaf.Widget
    constructor:(@name)->
        super document.createElement "li"
        @node$.text(@name)
    onClickNode:(e)->
        e.stopImmediatePropagation()
        e.preventDefault()
        @emit "select"
module.exports = SceneSwitcher

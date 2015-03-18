App = require "app"
class View extends Leaf.Widget
    @views = []
    constructor:(template,name)->
        super template
        @name = name
        View.views.push this
        @isShow = true
    show:()->
        if @isShow
            return
        @isShow = true
        @node$.show()
        @emit "show"
    hide:()->
        if not @isShow
            return
        @isShow = false
        @node$.hide()
        @emit "hide"
class ViewSwitcher extends Leaf.Widget
    constructor:()->
        super $(".view-switcher")[0]
        @currentView = null
        @viewItems = []
        @hideListener = @hideListener.bind(this)
        @hide()
    switchTo:(name)->
        has = false
        for view in View.views when view.name is name
            if @currentView and @currentView.name is name
                return
            if @currentView
                @currentView.hide()
            oldView = @currentView
            @emit "viewChange",view
            @currentView = view
            if oldView and oldView.onSwitchOff
                oldView.onSwitchOff()
            view.show()
            @VM.title = name
            if view.onSwitchTo
                view.onSwitchTo()
            return
        if not has
            throw new Error "view #{name} not found"
    onClickTitle:(e)->
        e.stopImmediatePropagation()
        e.preventDefault()
        @syncViews()
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
    hide:()->
        window.removeEventListener "click",@hideListener
        @isShow = false
        @VM.showSelector = false
        @VM.caretClass = "fa-caret-right"
    syncViews:()->
        # Do a complete sync with View.views an @viewItems
        # They are different data type so sync take some steps
        for myView in @viewItems
            myView.__match = "not match"
        for view in View.views
            has = false
            # in @viewItems?
            for myView in @viewItems
                if view.name is myView.name
                    has = true
                    myView.__match = "match"
                    break
            # in View.views not in @viewItems
            # so create it
            if not has
                @addView(view.name)
        # Those in viewItems but not found in View.views should be removed
        @viewItems = @viewItems.filter (item)->item.__match isnt "not match"
    addView:(name)->
        viewItem = new ViewSelectItem(name)
        @viewItems.push viewItem
        viewItem.appendTo @UI.viewSelector
        viewItem.on "select",()=>
            @switchTo viewItem.name
            @hide()
    onClickAddSourceButton:()->
        App.addSourcePopup.show()
    onClickSettingButton:()->
        App.settingPanel.show()

class ViewSelectItem extends Leaf.Widget
    constructor:(@name)->
        super document.createElement "li"
        @node$.text(@name)
    onClickNode:(e)->
        e.stopImmediatePropagation()
        e.preventDefault()
        @emit "select"

module.exports  = View
module.exports.ViewSwitcher = ViewSwitcher

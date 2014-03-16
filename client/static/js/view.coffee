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
    switchTo:(name)->
        has = false
        for view in View.views when view.name is name
            if @currentView and @currentView.name is name
                return
            if @currentView
                @currentView.hide()
            @currentView = view 
            view.show()
            @UI.title$.text(name)
            @emit "viewChange",view
            return
        if not has
            throw "view #{name} not found"
    onClickTitle:()->
        @syncViews()
        if @isShow
            @hide()
        else
            @show()
    show:()-> 
        @isShow = true
        @UI.viewSelector$.slideDown(100)
        @UI.directionIcon$.removeClass("fa-caret-right")
        @UI.directionIcon$.addClass("fa-caret-down")
    hide:()-> 
        @isShow = false
        @UI.viewSelector$.slideUp(100)
        @UI.directionIcon$.addClass("fa-caret-right") 
        @UI.directionIcon$.removeClass("fa-caret-down")
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
class ViewSelectItem extends Leaf.Widget
    constructor:(@name)->
        super document.createElement "li"
        @node$.text(@name)
    onClickNode:()->
        @emit "select"

window.ViewSwitcher = ViewSwitcher
window.View = View
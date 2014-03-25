#class TextGhost
#    constructor:(target,text)->
#        @setTarget target
#        @setText text
#        return
#    setTarget:(target)->
#        @target = target
#        @target.cloneNode(false)
#    setText:(text)->
#        @text
#    getLineHeight:()->
#        overhead = $(@target).height()
#        @target.innerHTML = "A"
#        lineHeight = $(@target).height() - overhead
#    fit:()->
#        
#    render:(text)->
#        return info

#class GlobalOverlay extends Leaf.Widget
#    constructor:()->
#
App.on "connect",()->
    App.settingPanel.test()
App.on "structureReady",()->
            
    
    setTimeout (()->
#        App.viewSwitcher.switchTo "p2p view"
#        App.userConfig.set "enableResourceProxy",true
#        App.userConfig.set "useResourceProxyByDefault",true
#        App.viewSwitcher.switchTo "list view"
#        App.viewSwitcher.switchTo "search view"
    
#        App.searchView.searchList.UI.searchKeywordInput.value = "nodejs"
#        App.searchView.searchList.onClickSearchButton()
        
        ),100


# Enhancement goes here
# Remember the last view and recovers it

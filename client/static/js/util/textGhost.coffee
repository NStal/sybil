class TextGhost
    constructor:(target,text)->
        @setTarget target
        @setText text
        return
    setTarget:(target)->
        @target = target
        @ghost = @target.cloneNode(false)
        @ghost.style = @target.style
    setText:(text)->
        @text
    getLayoutInfo:()->
        height = @ghost.style.height
        @ghost.style.height = "auto"
        overhead = $(@ghost).height()
        @ghost.innerHTML = "A"
        lineHeight = $(@target).height() - overhead
        @ghost.style.height = height
        return {overhead:overhead,lineHeight:lineHeight}
    getTextByLine:(text)->
        text = text or @text or ""
        count = text.length
        min = 0
        max = count
        info = @getLayoutInfo()
    fit:()->
        
    render:(text)->
        return info
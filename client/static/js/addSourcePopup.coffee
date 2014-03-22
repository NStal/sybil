class AddSourcePopup extends Leaf.Widget
    constructor:()->
        super(App.templates["add-source-popup"])
        @terminal = new Terminal(@UI.terminal)
        @node$.hide()
    show:()->
        @inflate()
        @node$.slideDown(100)
    hide:()->
        @node$.slideUp(100)
    shrink:()->
        @node$.addClass("monitor-mode")
    inflate:()->
        @node$.removeClass("monitor-mode")
    clear:()->
        if @currentAdder
            @currentAdder.destroy()
        @UI.input.value = ""
        @terminal.clear()
    onClickSubmit:()->
        if @isAdding
            return
        @shrink()
        @terminal.clear()
        uris = @UI.input.value.trim().split(/\s+/).map (item)->item.trim()
        uris = uris.filter (item)->item
        sourceAdder = new SourceAdder(App.messageCenter,@terminal)
        @isAdding = true
        @currentAdder = sourceAdder
        sourceAdder.addSources uris,(err)=>
            @isAdding = false
            if err is "abort"
                @terminal.error "abort"
                return
            if err
                @terminal.singleSelection [
                    {
                        text:"retry"
                        callback:()=>
                            @onClickSubmit()
                    }
                    {
                        text:"cancel"
                        callback:()=>
                            @clear()
                            @hide()
                    }
                ]
                return
            else
                @terminal.singleSelection [
                    {
                        text:"ok"
                        callback:()=>
                            @clear()
                            @hide()
                    }
                ]
            
    onClickCancel:()->
        @hide()
    onKeydownInput:(e)->
        if e.which is Leaf.Key.enter
            @onClickSubmit()
            return false
class SourceAdder extends Leaf.EventEmitter
    constructor:(@messageCenter,@terminal)->
        @controllers = []
    addSources:(uris,callback)->
        if @mode is "carefully" 
            async.eachSeries uris,((uri,done)=>
                @addSourceCarefully uri,(err)=>
                    done(err)
                ),(err)->
                    callback err
            return 
        fails = []
        successes = []
        async.forEachLimit uris,5,((uri,done)=>
            if not @messageCenter
                done "abort"
                return
            @addSource uri,(err)=>
                if err
                    fails.push uri
                else
                    successes.push uri
                done()
            ),(err)=>
                if err is "abort"
                    callback "abort"
                    return
                for fail in fails
                    @terminal.error "fail to add #{fail}"
                if fails.length > 0
                    @terminal.warn "COMPLETE with some fail cases"
                else
                    @terminal.ok "COMPLETE"
                callback()
    addSource:(uri,callback)->
        hintToString = (hint)->
            return hint.uri
        @terminal.log "try add uri",uri
        if not @messageCenter
            callback "abort"
            return
        @controllers.push @messageCenter.invoke "getSourceHint",uri,(err,available)=>
            if err
                @terminal.error "error detecting source from #{uri}"
                @terminal.error err.toString()
                callback(err)
                return
            if available.length is 0
                @terminal.error "can't detect any source from '#{uri}'"
                callback("detect fail")
                return
            if available.length > 1
                @terminal.warn "multiple source detect from single url"
                @terminal.warn "add first one #{hintToString(available[0])}"
                @terminal.warn "if you do need a choice here please use master mode"
            source = available[0]
            if not @messageCenter
                callback "abort"
                return
            @controllers.push @messageCenter.invoke "subscribe",source,(err,result)=>
                if err
                    if err is "duplicate"
                        @terminal.warn "source #{hintToString(source)} already exsits"
                        @terminal.log "skip #{hintToString(source)}"
                        callback() 
                    else
                        @terminal.error err.toString()
                        @terminal.error "fail to add source #{hintToString(source)}"
                        callback(err)
                    return
                
                @terminal.ok "successfully add #{hintToString(source)}"
                callback()
    addSourceCarefully:(uri,callback)=>
        App.messageCenter.invoke "getSourceHint",uri,(err,available)=>
            if err 
                @terminal.error "error detecting source from #{uri}"
                @terminal.error err.toString()
    destroy:(callback = ()->true)->
        @messageCenter = null
        @terminal = null
        for controller in @controllers
            controller.clear("abort")
            
        
class Terminal extends Leaf.Widget
    class Text extends Leaf.Widget
        constructor:(text,className)->
            super("<span></span>")
            @node$.text(text)
            if className
                @node$.addClass(className)
    class Button extends Leaf.Widget
        constructor:(text,callback)->
            super("<button></button>")
            @callback = callback
            @node$.text(text)
        onClickNode:()->
            if @isDisable
                return
            @callback()
        disable:()->
            @isDisable = true
            @node$.attr("disabled",true)
    constructor:(template)->
        super template
    _push:(widgets...)->
        for widget in widgets
            widget.appendTo this
        @node$.append(document.createElement("br"))
        @node.scrollTop = @node.scrollHeight
    clear:()->
        @node$.empty()
    error:(args...)->
        @_push new Text(args.join(" "),"terminal-error")
    warn:(args...)->
        @_push new Text(args.join(" "),"terminal-warn")
    log:(args...)->
        @_push new Text(args.join(" "),"terminal-normal")
    ok:(args...)->
        @_push new Text(args.join(" "),"terminal-ok")
    good:(args...)->
        @_push new Text(args.join(" "),"terminal-ok")
    wait:()->
    endwait:()->
    singleSelection:(selections)->
        buttons = []
        for selection in selections
            do (selection)=>
                buttons.push new Button selection.text,()=>
                    for button in buttons
                        button.disable()
                    @log("choose #{selection.text}")
                    selection.callback()
        @_push.apply(this,buttons)
    multiSelect:(selections,callback)->
        callback null,selections
window.AddSourcePopup = AddSourcePopup
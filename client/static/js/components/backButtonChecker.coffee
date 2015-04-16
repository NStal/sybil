class BackButtonChecker extends Leaf.EventEmitter
    constructor:(@history)->
        super()
        return
    active:()->
        if @isActive
            return
        @isActive = true
        @removeBack()
        @insertBack()
    deactive:()->
        if not @isActive
            return
        @isActive = false
        @removeBack()
    insertBack:()->
        @history.push this,()=>
            console.log "back!!!"
            @emit "back"
            if @isActive
                @insertBack()
    removeBack:()->
        @history.remove this

module.exports = BackButtonChecker

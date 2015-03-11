class ImageLoader extends Leaf.EventEmitter
    class ImageLoaderWorker extends Leaf.States
        constructor:()->
            super()
            @timeout = 1000 * 20
        load:(@src)->
            # need manually reset

            @isReserved = false
            if @state isnt "void"
                return
            @setState "loading"
        reserve:()->
            @isReserved = true
        reset:()->
            if @data.img
                @data.img.removeAttribute "src"
            @removeAllListeners()
            super()
        atLoading:()->
            @data.timeStart = Date.now()
            img = document.createElement("img")
            img.src = @src
            @clear ()=>
                img.removeEventListener("load",onload)
                img.removeEventListener("error",onerror)
                if @isWaitingFor "giveup"
                    @stopWaiting "giveup"
                @data.isPending = false
                clearTimeout @data.timer
            onload = ()=>
                @clear()
                @setState "ready"
            onerror = ()=>
                @clear()
                @setState "fail"
            @data.timer = setTimeout ()=>
                # is pending means anyone can
                # abort me at they will if resource get tied.
                @data.isPending = true
                @waitFor "giveup",()=>
                    @clear()
                    @data.failError = new Error "give up due to timeup to #{@timeout} and someone else is waiting to load"
                    @setState "abort"
                @emit "pending"
            ,@timeout

            img.addEventListener "load",onload
            img.addEventListener "error",onerror
            @data.img = img
        atReady:()->
            result = @data.img
            @data.img = null
            @emit "finish",null,result
        atFail:()->
            @emit "finish",@data.failError or new Error "fail to load image"
        atAbort:()->
            @setState "fail"
        isPending:()->
            return @data.isPending
        isAvailable:()->
            return @state in ["ready","fail","void"]
        isIdle:()->
            return @isAvailable() or @isPending()
    constructor:()->
        # for chrome max coherency is 6.
        # for leave on for other resource.
        super()
        @queue = []
        @workers = []
        @caches = {}
        @fails = {}
        @coherency = 0
        @setCoherency(5)
    setCoherency:(count = 5)->
        @_initWorkers(5)
    _initWorkers:(count)->
        if count is @coherency
            return
        @coherency = count
        while @coherency > @workers.length
            @workers.push new ImageLoaderWorker()
        @_next()
    _onWorkerIdle:(worker)->
        # incase the coherency change
        if @workers.length > @coherency
            @workers = @workers.filter (item)->item isnt worker
        @_next()
    _next:()->
        if @queue.length is 0
            return
        for worker in @workers
            if worker.isAvailable() and not worker.isReserved
                info = @queue.shift()
                @_load worker,info
                @_next()
                return
        for worker in @workers
            if worker.isPending() and not worker.isReserved
                worker.reserve()
                worker.give "giveup"
                info = @queue.shift()
                @_load worker,info
                @_next()
                return
    _load:(worker,info)->
        console.log "_load",info.src
        worker.reserve()
        if worker.isPending()
            worker.give("giveup")
        worker.reset()
        worker.once "pending",()=>

            @_onWorkerIdle(worker)
        worker.once "finish",(err,img)=>
            if not err
                @caches[info.src] = true
            else
                @fails[info.src] = err
            @_onWorkerIdle(worker)
            info.callback err,img
        if info.option
            if info.option.giveup
                worker.timeout = info.option.giveup
        worker.info = info
        worker.load info.src
    isBusy:()->
        for item in @workers
            if item.isAvailable() or item.isPending()
                return false
        return true
    hasCache:(src)->
        return @caches[src]
    hasFail:(src)->
        return @fails[src]
    hurry:(src)->
        for info,index in @queue
            if info.src is src
                @queue.splice(index,1)
                @queue.unshift(info)
                return
        return
    now:(src)->
        for info,index in @queue
            if info.src is src
                @queue.splice(index,1)
                latest = 0
                justStartWorker = null
                # find a worker is just start
                for worker in @workers
                    if worker.data and worker.data.timeStart > latest
                        justStartWorker = worker
                        latest = worker.data.timeStart
                # put the delayed job at the begin of the queue
                delayInfo = worker.info
                @queue.unshift(delayInfo)
                console.log "unshift",delayInfo.src
                worker.reset()
                @_load(worker,info)

                return
        return
    load:(option,callback)->
        src = option.src or option
        info = {src,option,callback,type:"load"}
        if option.hurry
            @queue.unshift info
        else
            @queue.push info
        @_next()
    cache:(option,callback)->
        src = option.src or option
        if @caches[src]
            callback()
        @load option,(err,img)->callback(err)
    clear:()->
        for worker in @workers
            worker.reset()
            if worker.info and worker.info.callback
                worker.info.callback new Error "clear"
        for item in @queue
            item.callback new Error "clear"
        @queue = []

module.exports = ImageLoader

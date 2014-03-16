class Timer extends (require "events").EventEmitter
    constructor:(option = {})->
        @max = 1000
        @min = 0
        @setInterval option.interval or 1000
        @min =  option.min or @interval
        @max = option.max or @interval
        @isStop = true
        if @min > @max
            throw new Error "Timer: min is bigger than max"
        @left = option.left or 0
        if not option.pause
            @startAfter(@left)
    startAfter:(left)->
        @left = left
        @resume()
    setInterval:(interval = 0)->
        @interval = interval
        if @min > @interval
            @min = @interval
        if @max < @interval
            @max = @interval
    setMax:(max)->
        @max = max
    setMin:(min)->
        @min = min
    next:()->
        if @isStop
            return
        @emit "tick",this
        @timer = setTimeout @next.bind(this),typeof @left is "number" and @left or @interval
        @left = null
        @date = Date.now()
    # difference between stop and pause is that
    # stop will clear the passed time and resume/start it will
    # start at a new interval
    # but pause will save the time remained
    # and go from there at resume(not start)
    pause:()->
        @isStop = true
        if @date
            @left = Math.max(0,Date.now()-@date)
        else
            @left = null
        @stop()
    stop:()->
        clearTimeout @timer
        @timer = null
        @isStop = true
    resume:()->
        if not @isStop
            return
        @isStop = false
        @next()
    start:()->
        if not @isStop
            return
        @isStop = false
        @left = null
        @next()
    decrease:(n = 0)->
        @interval = Math.max(@interval - n,@min)
    increase:(n = 0)->
        @interval = Math.min(@interval + n,@max)
    shorter:(n = 2)->
        @interval = Math.max(@interval / n,@min)
    longer:(n = 2)->
        @interval = Math.min(@interval * n,@max)
        
module.exports = Timer
module.exports.Timer = Timer
module.exports.Ticker = Timer
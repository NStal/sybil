class SwipeChecker extends Leaf.EventEmitter
    constructor:(@node)->
        super()
        @node.ontouchstart = (e)=>
            @onstart(e)
        @node.ontouchend = (e)=>
            @onend(e)
        @node.ontouchmove = (e)=>
            @onmove(e)
    onstart:(e)->
        @startPoint = [e.touches[0].clientX,e.touches[0].clientY]
        @startDate = Date.now()
        #alert @startPoint.join(",")
    onend:(e)->
        if not @endPoint
            return
        #alert @endPoint.join(",")
        swipeFloor = 50
        if e.touches.length is 0
            endDate = Date.now()
            
            #alert "detect less than 1000"
            #alert "date="+(endDate-@startDate)
            if endDate - @startDate < 1000
                #alert "less than 1000"
                if @startPoint[0] - @endPoint[0] > swipeFloor
                    @emit "swipeleft"
                else if @startPoint[0] - @endPoint[0] < -swipeFloor
                    @emit "swiperight"
        @endPoint = null
                
                
    onmove:(e)->
        @endPoint = [e.touches[0].clientX,e.touches[0].clientY]
        
        if Math.abs(@endPoint[0]-@startPoint[0]) > Math.abs(@endPoint[1]-@startPoint[1])
            e.preventDefault()
window.SwipeChecker = SwipeChecker


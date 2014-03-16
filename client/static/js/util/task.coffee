class Tasks extends Leaf.EventEmitter
    constructor:(tasks...)->
        @tasks = []
        for task in tasks
            @tasks.push {name:task,done:false}
    check:()->
        if @hasDone
            return
        for item in @tasks
            if not item.done
                return
        @hasDone = true
        @emit "done"
    done:(name)->
        for task in @tasks
            if task.name is name
                task.done = true
                @check()
                return
        throw "unknown task #{name}"
    reset:()->
        @hasDone = false
        for task in @tasks
            task.done = false
window.Tasks = Tasks
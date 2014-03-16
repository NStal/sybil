App.Language = {
    fullDateFormatString:"dddd, MMMM Do YYYY"
    thisManyPeopleHasShareIt_i:"%s people shares it"
    andThisMorePeopleHasShareIt_i:"and %s people shares it"
    sharesIt:"shares it"
}
moment.lang(navigator.language)
App.textFormat = (args...)->
    App.textFormatUnsafe.apply(null,args)
App.textFormatUnsafe = (args...)->
    text = args.shift()
    for value in args
        text = text.replace("%s",value)
    return text
    


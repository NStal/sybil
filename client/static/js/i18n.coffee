moment = require("lib/moment")
Language = {}
format = (args...)->
    return formatUnsafe.apply(null,args)
    
lts = {
    fullDateFormatString:"dddd, MMMM Do YYYY"
    thisManyPeopleHasShareIt_i:"%s people shares it"
    andThisMorePeopleHasShareIt_i:"and %s people shares it"
    sharesIt:"shares it"
}
for prop of lts
    do (prop)->
        Language[prop] = (args...)->
            format.apply this,([].concat lts[prop],args)
moment.lang(navigator.language)
format = (args...)->
    formatUnsafe.apply(null,args)
formatUnsafe = (args...)->
    text = args.shift()
    for value in args
        text = text.replace("%s",value)
    return text
module.exports = Language
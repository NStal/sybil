mongodb = require("mongodb")
MongoClient = mongodb.MongoClient

exports.setSettings = (settings)->
    @settings = settings
exports.dropDatabase = (callback)->
    MongoClient.connect "mongodb://#{@settings.dbHost or 'localhost'}:#{@settings.dbPort or 12309}/#{@settings.dbName}",(db)->
        db.dropDatabase(callback)
        
class Profile
    constructor:(data)->
        @email = data.email
        @nickname = data.nickname
    toJSON:()->
        return {
            email:@email
            ,nickname:@nickname
        }
Profile.parse = (data = {})->
    if not data.email or not data.nickname
        return null
    # todo check email format here
    # todo check nickname here
    return new Profile(data)
module.exports = Profile
class Archive
    validate:()->
        if @createDate and not @createDate instanceof Date
            return false
        if @fetchDate and not @fetchDate instanceof Date
            return false
        if not @content and not @title
            return false
        if not @sourceGuid
            return false
        if @invalid
            return false
        return true
    toJSON:()->
        return {
            guid:@guid
            ,collectorName:@collectorName
            ,createDate:@createDate
            ,fetchDate:@fetchDate
            ,authorName:@authorName
            ,authorAvatar:@authorAvatar
            ,authorLink:@authorLink
            ,originalLink:@originalLink
            ,sourceName:@sourceName
            ,sourceUrl:@sourceUrl
            ,sourceGuid:@sourceGuid
            ,title:@title
            ,content:@content
            ,displayContent:@displayContent
            ,searchable:@searchable and @searchable.toString() or @content
            ,contentType:@contentType
            ,attachments:@attachments
            ,meta:@meta or null
        }
module.exports = Archive
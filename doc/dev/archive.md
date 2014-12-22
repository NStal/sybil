# What's archive

Archive is the basic storage unit of sybil. A tweet, a post, an article, or even a webpage , all of them can be an `Archive`.

When stored as JSON object, `Archive` has following properties

```javascript
{
    // `guid` of the archives
    // usually built like #{source_guid}_#{archive_id}.
    // `archive_id` is something relate to the source.
    // `archive_id` can be a tweeter id, or a blog post id
    // defined by the provider.
    // By built with this rule, we reduced probability of conflict,
    // and make it human friendly as well.
    guid:"rss_http://example.com/index.xml_rssId1923"
    // `type` `guid` and `name` of the corresponding source. 
    ,type:@type
    ,sourceGuid:"rss_http://example.com/index.xml"
    ,sourceName:@sourceName
    // `createDate` When the archive is actually created by content provider
    // `fetchDate` When the archive is actually been fetch to sybil
    // In `createDate` is not provided, just use `fetchDate`
    ,createDate:@createDate
    ,fetchDate:@fetchDate
    // `author` some content provider may provide an author information
    ,author:{
        name:"NStal"
        ,avatar:"https://avatars3.githubusercontent.com/u/1177112?v=3&s=140"
        // Link to the author profile if any
        ,link:"https://github.com/NStal"
    }
    // Original url of the archive say the blog post address.
    ,originalLink:"http://github.com/NStal/sybil"
    // Url used to subscribe the source of this archive
    ,sourceUrl:"http://github.com/"
    ,title:"Introduction to sybil project archive"
    // `content` and `contentType` are togather define
    // the content of the archive.
    // If contentType is "image/jpeg" the content may be a
    // Buffer or image url. But this feature is not well support
    // by the client side, and make cause issue to database.
    // So just use "text/html".
    ,content:"<div>Introduction to sybil project archive BLURBLURBLUR</div>"
    ,contentType:"text/html"
    // `displayContent` is the content actually seen by user
    // It can only be the `text/html` type.
    // If this field is present, its content will be shown to user
    // instead of the `content`. This field is used for custom plugins.
    // Custom plugins may use extra request to gain more information to
    // decorate the raw content for certain type of Archive.
    ,displayContent:null
    // Content that visible to sybil built in search engine.
    // Should better have html tags removed. No need to include title
    ,searchable:"No need to include title"
    // attachments are not fully support by the frontend
    ,attachments:[{
        name:"image"
        ,type:"image/jpeg"
        ,url:"path to image"
    },{
        name:"video"
        ,type:"video/mpeg4"
        ,url:"path to video"
    }]
    // property reserved for extension or plugin use
    ,meta:{}
}```

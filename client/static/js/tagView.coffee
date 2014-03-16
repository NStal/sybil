class TagView extends View
    constructor:()->
        @tagList = new TagList()
        @tagArchiveList = new TagArchiveList()
        @tagList.tagArchiveList = @tagArchiveList
        super $(".tag-view")[0],"tag view"
window.TagView = TagView
    
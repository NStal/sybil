class CustomView extends View
    constructor:()->
        @customSourceList = new CustomSourceList()
        @customArchiveList = new CustomArchiveList()
        @customSourceList.customArchiveList = @customArchiveList
        @workspaces = []
        super $(".custom-view")[0],"custom view" 
window.CustomView = CustomView
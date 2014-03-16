class ManageView extends View
    cosntructor:()->
        @customSourceList = new CustomSourceList()
        @customArchiveList = new CustomArchiveList()
        @customSourceList.customArchiveList = @customArchiveList
        super $(".custom-view")[0],"custom view"
// Generated by CoffeeScript 1.8.0
(function() {
  var TagView,
    __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

  TagView = (function(_super) {
    __extends(TagView, _super);

    function TagView() {
      this.tagList = new TagList();
      this.tagArchiveList = new TagArchiveList();
      this.tagList.tagArchiveList = this.tagArchiveList;
      TagView.__super__.constructor.call(this, $(".tag-view")[0], "tag view");
    }

    return TagView;

  })(View);

  window.TagView = TagView;

}).call(this);

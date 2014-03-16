// Generated by CoffeeScript 1.7.1
(function() {
  var SourceView,
    __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

  SourceView = (function(_super) {
    __extends(SourceView, _super);

    function SourceView() {
      this.sourceList = new SourceList();
      this.archiveList = new ArchiveList();
      this.sourceList.on("select", (function(_this) {
        return function(info) {
          return _this.archiveList.load(info);
        };
      })(this));
      SourceView.__super__.constructor.call(this, $(".source-view")[0], "source view");
      this.node.ontouchstart = (function(_this) {
        return function(e) {
          _this.lastStartDate = Date.now();
          return _this.lastStartEvent = e;
        };
      })(this);
      this.node.ontouchmove = (function(_this) {
        return function(e) {
          _this.lastMoveEvent = e;
          if (!_this.lastMoveEvent || !_this.lastStartEvent) {
            return;
          }
          if (Math.abs(_this.lastStartEvent.touches[0].clientX - _this.lastMoveEvent.touches[0].clientX) > 30) {
            _this.lastStartEvent.preventDefault();
            return _this.lastMoveEvent.preventDefault();
          }
        };
      })(this);
      Hammer(document.body).on("swiperight", (function(_this) {
        return function(ev) {
          ev.preventDefault();
          return _this.node$.addClass("show-list");
        };
      })(this));
      Hammer(document.body).on("swipeleft", (function(_this) {
        return function(ev) {
          ev.preventDefault();
          return _this.node$.removeClass("show-list");
        };
      })(this));
      this.UI.sourceListOverlay$.click((function(_this) {
        return function() {
          return _this.node$.removeClass("show-list");
        };
      })(this));
    }

    return SourceView;

  })(View);

  window.SourceView = SourceView;

}).call(this);

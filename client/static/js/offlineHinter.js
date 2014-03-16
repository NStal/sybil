// Generated by CoffeeScript 1.7.1
(function() {
  var OfflineHinter,
    __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

  OfflineHinter = (function(_super) {
    __extends(OfflineHinter, _super);

    function OfflineHinter() {
      OfflineHinter.__super__.constructor.call(this, $(".offline-hinter")[0]);
      App.connectManager.on("connect", (function(_this) {
        return function() {
          return _this.hide();
        };
      })(this));
      App.connectManager.on("disconnect", (function(_this) {
        return function() {
          return _this.show();
        };
      })(this));
    }

    OfflineHinter.prototype.show = function() {
      return this.node$.addClass("show");
    };

    OfflineHinter.prototype.hide = function() {
      return this.node$.removeClass("show");
    };

    return OfflineHinter;

  })(Leaf.Widget);

  window.OfflineHinter = OfflineHinter;

}).call(this);

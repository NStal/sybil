// Generated by CoffeeScript 1.8.0
(function() {
  var App, Toaster, tm,
    __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

  tm = require("/templateManager");

  tm.use("toaster");

  App = require("/app");

  Toaster = (function(_super) {
    __extends(Toaster, _super);

    function Toaster() {
      Toaster.__super__.constructor.call(this, App.templates.toaster);
      this.showInterval = 3000;
    }

    Toaster.prototype.show = function(content) {
      this.content = content;
      this.UI.content$.text(content);
      this.node$.addClass("show");
      clearTimeout(this.hideTimer);
      return this.hideTimer = setTimeout((function(_this) {
        return function() {
          return _this.hide();
        };
      })(this), this.showInterval);
    };

    Toaster.prototype.hide = function() {
      return this.node$.removeClass("show");
    };

    return Toaster;

  })(Leaf.Widget);

  module.exports = Toaster;

}).call(this);

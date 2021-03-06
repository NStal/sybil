// Generated by CoffeeScript 1.8.0
(function() {
  var App, HintStack,
    __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

  App = require("/app");

  HintStack = (function(_super) {
    __extends(HintStack, _super);

    function HintStack() {
      HintStack.__super__.constructor.call(this, "<div class='hint-stack'></div>");
      this.node$.css({
        position: "absolute",
        bottom: 0,
        right: 0,
        width: "100%"
      });
      this.list = Leaf.Widget.makeList(this.node);
      document.body.appendChild(this.node);
    }

    HintStack.prototype.push = function(widget) {
      console.debug("push", widget);
      this.list.push(widget);
      widget.listenBy(this, "hide", this.remove);
      return widget.listenBy(this, "show", this.display);
    };

    HintStack.prototype.remove = function(widget) {
      console.debug("remove", widget);
      this.list.removeItem(widget);
      return widget.stopListenBy(this);
    };

    HintStack.prototype.display = function(widget) {
      return widget.node$.show();
    };

    return HintStack;

  })(Leaf.Widget);

  HintStack.HintStackItem = (function(_super) {
    __extends(HintStackItem, _super);

    function HintStackItem(template) {
      HintStackItem.__super__.constructor.call(this, template);
      if (!App.hintStack) {
        App.hintStack = new HintStack();
      }
      App.hintStack.push(this);
    }

    HintStackItem.prototype.show = function() {
      return this.emit("show", this);
    };

    HintStackItem.prototype.hide = function() {
      this.node$.slideUp(300);
      return setTimeout(((function(_this) {
        return function() {
          return _this.emit("hide", _this);
        };
      })(this)), 500);
    };

    HintStackItem.prototype.attract = function() {
      this.node$.animate({
        bottom: 10
      });
      return this.node$.animate({
        bottom: 0
      });
    };

    return HintStackItem;

  })(Leaf.Widget);

  module.exports = HintStack;

}).call(this);

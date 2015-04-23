// Generated by CoffeeScript 1.8.0
(function() {
  var ScrollChecker,
    __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

  ScrollChecker = (function(_super) {
    __extends(ScrollChecker, _super);

    function ScrollChecker(node) {
      ScrollChecker.__super__.constructor.call(this);
      if (node) {
        this.attach(node);
      }
      this.fire = this.fire.bind(this);
      this.eventDriven = false;
    }

    ScrollChecker.prototype.attach = function(node) {
      if (!node) {
        throw new Error("scroll check need to attach to HTMLElement");
      }
      if (this.node) {
        this.detach(this.node);
      }
      this.node = node;
      if (this.eventDriven) {
        this.node.addEventListener("scroll", this.fire);
        return;
      } else {
        this.timer = setInterval(this.check.bind(this), 100);
      }
      return this.lastValue = this.node.scrollTop;
    };

    ScrollChecker.prototype.fire = function() {
      return this.emit("scroll");
    };

    ScrollChecker.prototype.detach = function(node) {
      if (this.node === node || !node) {
        clearTimeout(this.timer);
        this.node.removeEventListener("scroll", this.fire);
        this.node = null;
      }
      return this.lastValue = null;
    };

    ScrollChecker.prototype.check = function() {
      var lastValue, value;
      if (!this.node) {
        return;
      }
      value = this.node.scrollTop;
      lastValue = this.lastValue;
      this.lastValue = value;
      if (this.lastValue !== null) {
        if (value !== lastValue) {
          if (value > lastValue) {
            this.emit("scrollDown");
          } else if (value < lastValue) {
            this.emit("scrollUp");
          }
          this.emit("scroll");
          if (this.node.offsetHeight + this.node.scrollTop >= this.node.scrollHeight) {
            this.emit("scrollBottom");
          }
          if (this.node.scrollTop === 0) {
            return this.emit("scrollTop");
          }
        }
      }
    };

    return ScrollChecker;

  })(Leaf.EventEmitter);

  module.exports = ScrollChecker;

}).call(this);

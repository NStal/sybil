// Generated by CoffeeScript 1.8.0
(function() {
  var SwipeChecker,
    __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

  SwipeChecker = (function(_super) {
    __extends(SwipeChecker, _super);

    function SwipeChecker(node) {
      this.node = node;
      SwipeChecker.__super__.constructor.call(this);
      this.node.ontouchstart = (function(_this) {
        return function(e) {
          return _this.onstart(e);
        };
      })(this);
      this.node.ontouchend = (function(_this) {
        return function(e) {
          return _this.onend(e);
        };
      })(this);
      this.node.ontouchmove = (function(_this) {
        return function(e) {
          return _this.onmove(e);
        };
      })(this);
    }

    SwipeChecker.prototype.onstart = function(e) {
      this.startPoint = [e.touches[0].clientX, e.touches[0].clientY];
      return this.startDate = Date.now();
    };

    SwipeChecker.prototype.onend = function(e) {
      var endDate, interval, swipeFloor;
      if (!this.endPoint) {
        return;
      }
      swipeFloor = this.swipeFloor || 80;
      if (e.touches.length === 0) {
        endDate = Date.now();
        interval = endDate - this.startDate;
        if (interval < (this.maxSwipeTime || 500) && interval > (this.minSwipeTime || 20)) {
          if (this.startPoint[0] - this.endPoint[0] > swipeFloor) {
            this.emit("swipeleft", e);
          } else if (this.startPoint[0] - this.endPoint[0] < -swipeFloor) {
            this.emit("swiperight", e);
          }
        }
      }
      return this.endPoint = null;
    };

    SwipeChecker.prototype.onmove = function(e) {
      this.endPoint = [e.touches[0].clientX, e.touches[0].clientY];
      if (Math.abs(this.endPoint[0] - this.startPoint[0]) - Math.abs(this.endPoint[1] - this.startPoint[1]) > 1) {
        return e.preventDefault();
      }
    };

    return SwipeChecker;

  })(Leaf.EventEmitter);

  module.exports = SwipeChecker;

}).call(this);

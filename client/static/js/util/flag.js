// Generated by CoffeeScript 1.8.0
(function() {
  var Flag,
    __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

  module.exports = Flag = (function(_super) {
    __extends(Flag, _super);

    function Flag(_turnOn, _turnOff) {
      this._turnOn = _turnOn;
      this._turnOff = _turnOff;
      Flag.__super__.constructor.call(this);
      if (this._turnOn == null) {
        this._turnOn = function() {};
      }
      if (this._turnOff == null) {
        this._turnOff = function() {};
      }
      this.value = null;
      this.yes = this.set;
      this.no = this.unset;
    }

    Flag.prototype.reverse = function() {
      return this._reverse = !this._reverse;
    };

    Flag.prototype.attach = function(obj, name) {
      this._turnOn = function() {
        return obj[name] = true && !this._reverse;
      };
      this._turnOff = function() {
        return obj[name] = false || this._reverse && true;
      };
      return this;
    };

    Flag.prototype.bind = function(context) {
      this.context = context;
      return this;
    };

    Flag.prototype.set = function(turnOn) {
      if (typeof turnOn === "function") {
        this._turnOn = turnOn;
        return;
      }
      if (this.value) {
        return this;
      }
      this.value = true;
      this._turnOn.call(this.context);
      this.emit("set");
      return this;
    };

    Flag.prototype.unset = function(turnOff) {
      if (typeof turnOff === "function") {
        this._turnOff = turnOff;
        return;
      }
      if (!this.value && this.value !== null) {
        return this;
      }
      this.value = false;
      this._turnOff.call(this.context);
      this.emit("unset");
      return this;
    };

    Flag.prototype.toggle = function() {
      if (this.value) {
        return this.no();
      } else {
        return this.yes();
      }
    };

    return Flag;

  })(Leaf.EventEmitter);

}).call(this);

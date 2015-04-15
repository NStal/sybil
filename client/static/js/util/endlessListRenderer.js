// Generated by CoffeeScript 1.8.0
(function() {
  var EndlessListRenderer, Pack, ResizeChecker, ScrollChecker,
    __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
    __slice = [].slice;

  ScrollChecker = require("/util/scrollChecker");

  EndlessListRenderer = (function(_super) {
    __extends(EndlessListRenderer, _super);

    function EndlessListRenderer(scrollable, createMethod) {
      this.scrollable = scrollable;
      this.createMethod = createMethod;
      EndlessListRenderer.__super__.constructor.call(this);
      this.renderCompromiseFix = 10;
      this.bottomPadding = 300;
      this.packs = [];
      this.datas = [];
      this.wrapper = document.createElement("div");
      this.buffer = document.createElement("div");
      this.buffer$ = $(this.buffer);
      this.wrapper$ = $(this.wrapper);
      this.wrapper.appendChild(this.buffer);
      this.bufferList = Leaf.Widget.makeList(this.buffer);
      this.bufferList.on("child/add", function(widget) {
        widget.isRealized = true;
        return widget.pack.isRealized = true;
      });
      this.bufferList.on("child/remove", function(widget) {
        return widget.pack.isRealized = false;
      });
      this.reset();
      this.scrollChecker = new ScrollChecker(this.scrollable);
      this.scrollChecker.eventDriven = true;
      this.lastScroll = 0;
      this.scrollChecker.on("scroll", (function(_this) {
        return function() {
          _this.viewPortBuffer = null;
          _this.adjustBufferList();
          _this.emit("viewPortChange");
          return _this.saveTrace();
        };
      })(this));
      this.scrollable.appendChild(this.wrapper);
      this.resizeChecker = new ResizeChecker(this.buffer);
      this.resizeChecker.on("resize", (function(_this) {
        return function() {
          _this.reflow(_this.start || 0);
          _this.restoreTrace();
          return _this.emit("resize");
        };
      })(this));
      this.resizeChecker.start();
      this.destroyInterval = 200;
    }

    EndlessListRenderer.prototype.destroyStale = function() {
      var bufferRange, count, counter, maxDestroyATime, pack, _count;
      bufferRange = 3;
      count = 5;
      counter = 0;
      maxDestroyATime = 4;
      if (this.start > bufferRange) {
        _count = count;
        while (_count > 0) {
          pack = this.packs[this.start - bufferRange - _count];
          if (pack && pack.widget) {
            if (pack.isRealized) {
              continue;
            }
            pack.destroy();
            counter += 1;
            if (counter > maxDestroyATime) {
              clearTimeout(this.destroyStaleTimer);
              this.destroyStaleTimer = setTimeout(this.destroyStale.bind(this), this.destroyInterval);
              return;
            }
          }
          _count -= 1;
        }
      }
      while (this.end + count + bufferRange < this.packs.length && count > 0) {
        count -= 1;
        pack = this.packs[this.end + count + bufferRange];
        if (pack && pack.widget && pack.isRealized) {
          continue;
        }
        pack.destroy();
        counter += 1;
        if (counter > maxDestroyATime) {
          clearTimeout(this.destroyStaleTimer);
          this.destroyStaleTimer = setTimeout(this.destroyStale.bind(this), this.destroyInterval);
          return;
        }
      }
    };

    EndlessListRenderer.prototype.indexOf = function(item) {
      if (item instanceof Leaf.Widget) {
        return item.pack.index;
      } else if (item instanceof Pack) {
        return item.index;
      }
      if (typeof item.__index === "number") {
        return item.__index;
      }
      return -1;
    };

    EndlessListRenderer.prototype.trace = function(item) {
      var index;
      index = this.indexOf(item);
      if (index < 0) {
        return false;
      }
      this.tracingPack = this.packs[index];
      return this.saveTrace();
    };

    EndlessListRenderer.prototype.saveTrace = function() {
      var scrollTop, top;
      if (!this.tracingPack) {
        return;
      }
      scrollTop = this.scrollable.scrollTop;
      top = this.tracingPack.top;
      return this.traceHistory = {
        top: top,
        scrollTop: scrollTop
      };
    };

    EndlessListRenderer.prototype.restoreTrace = function() {
      var scrollTop;
      if (!this.traceHistory || !this.tracingPack || typeof this.tracingPack.top !== "number") {
        return;
      }
      scrollTop = pack.top + this.traceHistory.scrollTop - this.traceHistory.top;
      return this.scrollable.scrollTop = scrollTop;
    };

    EndlessListRenderer.prototype.reset = function() {
      var pack, _i, _len, _ref;
      this.start = -1;
      this.end = -1;
      this.wrapper.style.minHeight = "0";
      this.bufferList.length = 0;
      this.top = 0;
      this.tracingPack = null;
      this.traceHistory = null;
      this.datas.length = 0;
      _ref = this.packs;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        pack = _ref[_i];
        pack.destroy();
      }
      this.packs.length = 0;
      this.wrapper$.css({
        width: "100%",
        minHeight: 0
      });
      this.buffer$.css({
        width: "100%",
        top: 0,
        position: "absolute",
        left: 0
      });
      this.unlockContainer();
      return clearTimeout(this.destroyStaleTimer);
    };

    EndlessListRenderer.prototype.add = function() {
      var data, datas, index, packs, _i, _len, _ref;
      datas = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
      packs = datas.map((function(_this) {
        return function(data) {
          return new Pack(data, _this.createMethod);
        };
      })(this));
      for (index = _i = 0, _len = datas.length; _i < _len; index = ++_i) {
        data = datas[index];
        data.__index = index + this.datas.length;
      }
      (_ref = this.datas).push.apply(_ref, datas);
      return this.addPack.apply(this, packs);
    };

    EndlessListRenderer.prototype.getPackByHeight = function(height) {
      var index, item, _i, _ref;
      if (this.packs.length === 0) {
        return null;
      }
      for (index = _i = _ref = this.packs.length - 1; _ref <= 0 ? _i <= 0 : _i >= 0; index = _ref <= 0 ? ++_i : --_i) {
        item = this.packs[index];
        if (item.bottom > height && item.top < height) {
          return item;
        }
      }
      return item;
    };

    EndlessListRenderer.prototype.addPack = function() {
      var index, pack, packs, _i, _len, _ref;
      packs = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
      for (index = _i = 0, _len = packs.length; _i < _len; index = ++_i) {
        pack = packs[index];
        pack.index = index + this.packs.length;
      }
      (_ref = this.packs).push.apply(_ref, packs);
      return this.adjustBufferList();
    };

    EndlessListRenderer.prototype.adjustBufferList = function() {
      var afters, befores, between, bufferViewPort, end, endBetterBe, fix, index, intersect, item, pack, shareEnd, shareStart, start, toRemove, viewPort, _i, _j, _k, _l, _len, _len1, _len2, _len3, _len4, _m, _n, _ref, _ref1, _ref2, _ref3, _ref4;
      this.unlockContainer();
      if (this._hint && this.buffer.contains(this._hint)) {
        this.buffer.removeChild(this._hint);
      }
      viewPort = this.getViewPort(this.renderCompromiseFix);
      this.reflow(this.start);
      start = null;
      end = null;
      _ref = this.packs;
      for (index = _i = 0, _len = _ref.length; _i < _len; index = ++_i) {
        item = _ref[index];
        if (!item.size) {
          break;
        }
        if (item.bottom >= viewPort.top && item.top <= viewPort.bottom) {
          if (start === null) {
            start = index;
          }
          end = index;
        }
      }
      if (start == null) {
        start = -1;
      }
      if (end == null) {
        end = -1;
      }
      fix = 1;
      if (start !== -1) {
        start -= fix;
      }
      if (end !== -1) {
        end += fix;
      }
      endBetterBe = end;
      if (end >= this.packs.length) {
        end = this.packs.length - 1;
      }
      if (start < 0 && end !== -1) {
        start = 0;
      }
      intersect = function(a0, a1, b0, b1) {
        var left, right;
        left = Math.max(a0, b0);
        right = Math.min(a1, b1);
        if (right - left < 0) {
          return [-1, -1];
        }
        return [left, right];
      };
      between = function(start, end, number) {
        return number <= end && number >= start;
      };
      _ref1 = intersect(start, end, this.start, this.end), shareStart = _ref1[0], shareEnd = _ref1[1];
      toRemove = [];
      _ref2 = this.bufferList;
      for (index = _j = 0, _len1 = _ref2.length; _j < _len1; index = ++_j) {
        item = _ref2[index];
        if (!between(shareStart, shareEnd, item.pack.index)) {
          toRemove.push(item);
        }
      }
      for (_k = 0, _len2 = toRemove.length; _k < _len2; _k++) {
        item = toRemove[_k];
        this.bufferList.removeItem(item);
        item.pack.destroy();
      }
      befores = [];
      afters = [];
      for (index = _l = start; start <= end ? _l <= end : _l >= end; index = start <= end ? ++_l : --_l) {
        if (index < 0) {
          break;
        }
        pack = this.packs[index];
        if (index < shareStart) {
          befores.push(pack.realize());
        } else if (index > shareEnd) {
          afters.push(pack.realize());
        }
      }
      if (befores.length > 0) {
        (_ref3 = this.bufferList).splice.apply(_ref3, [0, 0].concat(__slice.call(befores)));
      }
      if (afters.length > 0) {
        for (_m = 0, _len3 = afters.length; _m < _len3; _m++) {
          item = afters[_m];
          this.bufferList.push(item);
        }
      }
      this.start = start;
      this.end = end;
      if (this.bufferList.length > 0) {
        this.top = this.bufferList[0].pack.top;
        this.buffer$.css({
          top: this.top
        });
      }
      bufferViewPort = this.getBufferViewPort();
      _ref4 = this.packs.slice(this.end + 1, this.packs.length);
      for (index = _n = 0, _len4 = _ref4.length; _n < _len4; index = ++_n) {
        pack = _ref4[index];
        if (bufferViewPort.bottom > viewPort.bottom && this.end > endBetterBe) {
          break;
        }
        this.bufferList.push(pack.realize());
        pack.calculateSize();
        pack.top = bufferViewPort.bottom;
        bufferViewPort.bottom += pack.size.height;
        this.end += 1;
      }
      this.reflow(shareEnd > 0 && shareEnd || 0, {
        noCalculate: true
      });
      if (this._hint) {
        this.buffer.appendChild(this._hint);
      }
      this.resizeChecker.acknowledge(this.buffer.offsetHeight);
      this.wrapper.style.minHeight = "" + (bufferViewPort.bottom + this.bottomPadding) + "px";
      this.lockContainer();
      if (bufferViewPort.bottom <= viewPort.bottom || endBetterBe > this.end) {
        this.emit("requireMore");
      }
      return this.emit("reflow", this.start, this.end);
    };

    EndlessListRenderer.prototype.lockContainer = function() {
      var height;
      return;
      if (this.buffer.isLocked) {
        return;
      }
      this.buffer.isLocked = true;
      height = this.buffer.scrollHeight + 2;
      return this.buffer$.css({
        height: height,
        overflow: "auto"
      });
    };

    EndlessListRenderer.prototype.unlockContainer = function() {
      return;
      if (!this.buffer.isLocked) {
        return;
      }
      this.buffer.isLocked = false;
      return this.buffer$.css({
        height: "auto",
        overflow: "hidden"
      });
    };

    EndlessListRenderer.prototype.setHint = function(node) {
      if (this._hint && this.buffer.contains(this._hint) && this._hint !== node) {
        this.buffer.removeChild(this._hint);
      }
      if (node === this._hint) {
        return;
      }
      this._hint = node;
      return this.buffer.appendChild(node);
    };

    EndlessListRenderer.prototype.reflow = function(after, option) {
      var before, index, item, next, relock, _i;
      if (after == null) {
        after = 0;
      }
      if (option == null) {
        option = {};
      }
      if (after < 0) {
        return;
      }
      before = this.packs.length;
      if (before > this.packs.length) {
        return;
      }
      next = null;
      relock = false;
      if (this.buffer.isLocked && !option.noCalculate) {
        relock = true;
        this.unlockContainer();
      }
      for (index = _i = after; after <= before ? _i < before : _i > before; index = after <= before ? ++_i : --_i) {
        item = this.packs[index];
        if (item.isRealized && !option.noCalculate) {
          item.calculateSize();
        }
        if (!item.size) {
          break;
        }
        if (next !== null) {
          item.top = next;
        } else {
          next = item.top || 0;
        }
        next += item.size.height;
        item.bottom = next;
      }
      if (relock) {
        return this.lockContainer();
      }
    };

    EndlessListRenderer.prototype.getBufferViewPort = function() {
      var bottom, height, top;
      height = this.buffer$.height();
      top = this.top;
      bottom = this.top + height;
      return {
        top: top,
        bottom: bottom,
        height: height
      };
    };

    EndlessListRenderer.prototype.getViewPort = function(fix) {
      var bottom, height, top;
      if (fix == null) {
        fix = 0;
      }
      if (this.viewPortBuffer) {
        top = this.viewPortBuffer.top;
        height = this.viewPortBuffer.height;
        bottom = top + height;
      } else {
        top = this.scrollable.scrollTop;
        height = $(this.scrollable).height();
        bottom = top + height;
        this.viewPortBuffer = {
          top: top,
          height: height,
          bottom: bottom
        };
      }
      top -= fix;
      bottom += fix;
      if (top < 0) {
        top = 0;
      }
      height = bottom - top;
      return {
        top: top,
        height: height,
        bottom: bottom
      };
    };

    EndlessListRenderer.prototype.compareItemPosition = function(item) {
      var index, pack, vp;
      if (typeof item === "Number") {
        index = item;
      } else {
        index = this.indexOf(item);
      }
      pack = this.packs[index];
      if (index < 0) {
        return null;
      }
      if (!pack) {
        return null;
      }
      vp = this.getViewPort();
      return {
        topBeforeViewPort: pack.top < vp.top,
        bottomBeforeViewPort: pack.bottom < vp.bottom,
        topAfterViewPort: pack.top > vp.bottom,
        bottomAfterViewPort: pack.bottom > vp.bottom
      };
    };

    return EndlessListRenderer;

  })(Leaf.EventEmitter);

  Pack = (function(_super) {
    __extends(Pack, _super);

    function Pack(data, createMethod) {
      this.data = data;
      this.createMethod = createMethod;
      this.__defineSetter__("top", (function(_this) {
        return function(value) {
          _this._top = value;
          if (_this.widget) {
            return _this.widget.node.setAttribute("top", value);
          }
        };
      })(this));
      this.__defineGetter__("top", (function(_this) {
        return function() {
          return _this._top;
        };
      })(this));
      this.__defineSetter__("bottom", (function(_this) {
        return function(value) {
          _this._bottom = value;
          if (_this.widget) {
            return _this.widget.node.setAttribute("bottom", value);
          }
        };
      })(this));
      this.__defineGetter__("bottom", (function(_this) {
        return function() {
          return _this._bottom;
        };
      })(this));
      this.__defineSetter__("index", (function(_this) {
        return function(value) {
          _this._index = value;
          if (_this.widget) {
            return _this.widget.node.setAttribute("index", value);
          }
        };
      })(this));
      this.__defineGetter__("index", (function(_this) {
        return function() {
          return _this._index;
        };
      })(this));
    }

    Pack.prototype.realize = function() {
      this.widget = new this.createMethod(this.data);
      this.widget.pack = this;
      this.widget.node.setAttribute("index", this._index);
      return this.widget;
    };

    Pack.prototype.destroy = function() {
      if (this.widget && this.widget.destroy) {
        this.widget.destroy();
      }
      return this.widget = null;
    };

    Pack.prototype.calculateSize = function() {
      var rect, _ref, _ref1;
      if (!((_ref = this.widget) != null ? (_ref1 = _ref.node) != null ? _ref1.parentElement : void 0 : void 0)) {
        return;
      }
      rect = this.widget.node.getBoundingClientRect();
      return this.size = {
        height: rect.height,
        width: rect.width
      };
    };

    return Pack;

  })(Leaf.EventEmitter);

  ResizeChecker = (function(_super) {
    __extends(ResizeChecker, _super);

    function ResizeChecker(node) {
      this.node = node;
      ResizeChecker.__super__.constructor.call(this);
      this.checkInterval = 100;
    }

    ResizeChecker.prototype.start = function() {
      if (this.isStart) {
        return;
      }
      this.isStart = true;
      return this.check();
    };

    ResizeChecker.prototype.stop = function() {
      if (!this.isStart) {
        return;
      }
      this.isStart = false;
      return clearTimeout(this.checkTimer);
    };

    ResizeChecker.prototype.acknowledge = function(height) {
      return this.lastSize = height;
    };

    ResizeChecker.prototype.check = function() {
      var height;
      height = this.node.offsetHeight;
      if (this.lastSize !== height) {
        this.emit("resize");
      }
      this.lastSize = height;
      return this.checkTimer = setTimeout((function(_this) {
        return function() {
          return _this.check();
        };
      })(this), this.checkInterval);
    };

    return ResizeChecker;

  })(Leaf.EventEmitter);

  module.exports = EndlessListRenderer;

}).call(this);

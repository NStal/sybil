// Generated by CoffeeScript 1.8.0
(function() {
  var App, CubeLoadingHint, FileProvider, GalleryDisplayer, ImageBuffer, ImageDisplayer, ImageLoader, Point, Popup, SmartImage, StatefulImageBuffer, TouchManager, tm,
    __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
    __slice = [].slice,
    __indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; };

  App = require("/app");

  tm = require("/common/templateManager");

  SmartImage = require("/widget/smartImage");

  Popup = require("/view/base/popup");

  CubeLoadingHint = require("/widget/cubeLoadingHint");

  ImageLoader = require("/component/imageLoader");

  Point = (function() {
    function Point(x, y) {
      this.x = x;
      this.y = y;
      return;
    }

    Point.prototype.toString = function() {
      return "p: " + this.x + "," + this.y;
    };

    return Point;

  })();

  TouchManager = (function(_super) {
    __extends(TouchManager, _super);

    function TouchManager() {
      TouchManager.__super__.constructor.call(this);
      this.acceptMouse = true;
      this.console = document.createElement("div");
      this.console.style.width = "100%";
      this.console.style.height = "30px";
      this.console.style.position = "absolute";
      this.console.style.top = 0;
      this.console.style.left = 0;
      this.console.style.zIndex = 9999;
      this.console.style.backgroundColor = "black";
      this.console.style.color = "white";
      this.console.style.opacity = "0.5";
      this.console.style.pointerEvents = "none";
      this.console.className = "console";
      this.console.style.display = "none";
      this.log = function() {
        var msg;
        msg = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
        msg = msg.map(function(item) {
          return JSON.stringify(item);
        });
        return this.console.innerHTML = Date.now() + msg.join(",");
      };
    }

    TouchManager.prototype.attachTo = function(target) {
      this.reset();
      if (target) {
        this.currentTarget = target;
      }
      if (this.currentTarget) {
        this.currentTarget.addEventListener("touchstart", this.handleTouchStart.bind(this));
        this.currentTarget.addEventListener("touchenter", this.handleTouchEnter.bind(this));
        this.currentTarget.addEventListener("touchleave", this.handleTouchLeave.bind(this));
        this.currentTarget.addEventListener("touchcancel", this.handleTouchCancel.bind(this));
        this.currentTarget.addEventListener("touchend", this.handleTouchEnd.bind(this));
        this.currentTarget.addEventListener("touchmove", this.handleTouchMove.bind(this));
        if (this.acceptMouse) {
          this.currentTarget.addEventListener("touchstart", this._transformMouseToTouch(this.handleTouchStart.bind(this)));
          this.currentTarget.addEventListener("touchenter", this._transformMouseToTouch(this.handleTouchEnter.bind(this)));
          this.currentTarget.addEventListener("touchleave", this._transformMouseToTouch(this.handleTouchLeave.bind(this)));
          this.currentTarget.addEventListener("touchcancel", this._transformMouseToTouch(this.handleTouchCancel.bind(this)));
          this.currentTarget.addEventListener("touchend", this._transformMouseToTouch(this.handleTouchEnd.bind(this)));
          return this.currentTarget.addEventListener("touchmove", this._transformMouseToTouch(this.handleTouchMove.bind(this)));
        }
      }
    };

    TouchManager.prototype.reset = function() {
      if (this.currentTarget) {
        this.currentTarget.removeEventListener("touchstart");
        this.currentTarget.removeEventListener("touchend");
        this.currentTarget.removeEventListener("touchleave");
        this.currentTarget.removeEventListener("touchcancel");
        this.currentTarget.removeEventListener("touchend");
        return this.currentTarget.removeEventListener("touchmove");
      }
    };

    TouchManager.prototype._transformMouseToTouch = function(fn) {
      return function(e) {
        e.touches = [e];
        return fn(e);
      };
    };

    TouchManager.prototype._averagePosition = function(list) {
      var item, x, y, _i, _len;
      x = 0;
      y = 0;
      for (_i = 0, _len = list.length; _i < _len; _i++) {
        item = list[_i];
        x += item.clientX;
        y += item.clientY;
      }
      return new Point(x / list.length, y / list.length);
    };

    TouchManager.prototype._distance = function(a, b) {
      return Math.sqrt((a.clientX - b.clientX) * (a.clientX - b.clientX) + (a.clientY - b.clientY) * (a.clientY - b.clientY));
    };

    TouchManager.prototype._touchDistance = function(touches) {
      if (touches.length < 2) {
        return null;
      }
      return this._distance(touches[0], touches[1]);
    };

    TouchManager.prototype._touchToPoint = function(t) {
      return new Point(t.clientX, t.clientY);
    };

    TouchManager.prototype.handleTouchStart = function(e) {
      e.preventDefault();
      e.stopImmediatePropagation();
      this.lastPoint = this._averagePosition(e.touches);
      if (e.touches.length === 1) {
        this.startPoint = _touchToPoint;
      }
      if (e.touches.length > 1) {
        return this.lastDistance = this._distance(e.touches[0], e.touches[1]);
      }
    };

    TouchManager.prototype.handleTouchEnter = function(e) {};

    TouchManager.prototype.handleTouchLeave = function(e) {};

    TouchManager.prototype.handleTouchMove = function(e) {
      var distance, p, x, y;
      p = this._averagePosition(e.touches);
      x = p.x - this.lastPoint.x;
      y = p.y - this.lastPoint.y;
      this.emit("move", {
        x: x,
        y: y
      });
      if (e.touches.length > 1) {
        distance = this._distance(e.touches[0], e.touches[1]);
        try {
          this.emit("scale", {}, distance / this.lastDistance);
        } catch (_error) {
          e = _error;
          true;
        }
        this.lastDistance = distance;
      }
      return this.lastPoint = p;
    };

    TouchManager.prototype.handleTouchCancel = function(e) {};

    TouchManager.prototype.handleTouchEnd = function(e) {
      e.stopImmediatePropagation();
      e.preventDefault();
      if (e.touches.length > 0) {
        this.lastPoint = this._averagePosition(e.touches);
      }
      if (e.touches.length > 1) {
        return this.lastDistance = this._distance(e.touches[0], e.touches[1]);
      }
    };

    return TouchManager;

  })(Leaf.Widget);

  FileProvider = (function(_super) {
    __extends(FileProvider, _super);

    function FileProvider(srcs) {
      var index, src, _i, _len;
      FileProvider.__super__.constructor.call(this);
      this.files = [];
      for (index = _i = 0, _len = srcs.length; _i < _len; index = ++_i) {
        src = srcs[index];
        this.files.push({
          src: src,
          index: index
        });
      }
    }

    FileProvider.prototype.at = function(index) {
      return this.files[index] || null;
    };

    FileProvider.prototype.next = function(file) {
      return this.at(file.index + 1);
    };

    FileProvider.prototype.previous = function(file) {
      return this.at(file.index - 1);
    };

    return FileProvider;

  })(Leaf.EventEmitter);

  ImageBuffer = (function(_super) {
    __extends(ImageBuffer, _super);

    ImageBuffer.setLoader = function(loader) {
      return this.loader = loader;
    };

    function ImageBuffer(displayer) {
      this.displayer = displayer;
      if (ImageBuffer.loader == null) {
        ImageBuffer.loader = new ImageLoader();
      }
      ImageBuffer.__super__.constructor.call(this);
      this.attachTo(this.UI.image);
      this.resize();
      this.on("imageDoubleClick", (function(_this) {
        return function() {
          _this.toggleFitBorder();
          return _this.center();
        };
      })(this));
    }

    ImageBuffer.prototype.resize = function() {
      this.width = this.displayer.node$.width();
      return this.height = this.displayer.node$.height();
    };

    ImageBuffer.prototype.setFile = function(file) {
      this.file = file;
      this.VM.state = "loading";
      return ImageBuffer.loader.cache(this.file.src, (function(_this) {
        return function(err) {
          if (err) {
            _this.VM.state = "fail";
          } else {
            _this.VM.state = "ready";
          }
          _this.UI.image.src = _this.file.src;
          return _this.onload();
        };
      })(this));
    };

    ImageBuffer.prototype.onload = function() {
      this.resize();
      this.originalSize = new Point(this.UI.image.naturalWidth || 1, this.UI.image.naturalHeight || 1);
      this.ratio = this.originalSize.y / this.originalSize.x;
      this.imagePosition = {
        top: 0,
        left: 0,
        width: this.originalSize.x,
        height: this.originalSize.y
      };
      this._p = {
        top: 0,
        left: 0,
        width: this.originalSize.x,
        height: this.originalSize.y
      };
      return this.setInitialSize();
    };

    ImageBuffer.prototype.setInitialSize = function() {
      if (this.originalSize.x > this.width) {
        this.imagePosition.width = this.width;
      } else {
        this.imagePosition.width = Math.max(this.originalSize.x, this.width / 2);
      }
      this.fitMinBorder();
      this.center();
      this.adjust();
      return this.applyImagePositionImmediate();
    };

    ImageBuffer.prototype.fitMinBorder = function() {
      if (this.imagePosition.width > this.width) {
        this.imagePosition.width = this.width;
      }
      this.imagePosition.height = this.imagePosition.width * this.ratio;
      if (this.imagePosition.height > this.height) {
        this.imagePosition.height = this.height;
      }
      return this.imagePosition.width = this.imagePosition.height / this.ratio;
    };

    ImageBuffer.prototype.center = function() {
      return this.setRelativePosition(new Point(this.imagePosition.width / 2, this.imagePosition.height / 2), new Point(this.width / 2, this.height / 2));
    };

    ImageBuffer.prototype.toggleFitBorder = function() {
      if (this.imagePosition.height === this.height * this.heightFix) {
        return this.fitWidth();
      } else {
        return this.fitHeight();
      }
    };

    ImageBuffer.prototype.fitHeight = function() {
      if (this.heightFix == null) {
        this.heightFix = 2;
      }
      this.imagePosition.height = this.height * 2;
      return this.imagePosition.width = this.height / this.ratio * 2;
    };

    ImageBuffer.prototype.fitWidth = function() {
      this.imagePosition.width = this.width;
      return this.imagePosition.height = this.width * this.ratio;
    };

    ImageBuffer.prototype.setRelativePosition = function(rp, offset) {
      this.imagePosition.left = offset.x - rp.x;
      return this.imagePosition.top = offset.y - rp.y;
    };

    ImageBuffer.prototype.scale = function(rp, scale) {
      var nrp;
      nrp = new Point(rp.x * scale, rp.y * scale);
      this.imagePosition.width *= scale;
      this.imagePosition.height *= scale;
      return this.setRelativePosition(nrp, new Point(this.imagePosition.left + rp.x, this.imagePosition.top + rp.y));
    };

    ImageBuffer.prototype.adjust = function() {
      var offset;
      this.swipeOffset = this.swipeOffset || $("body").width() * 1 / 4;
      if (this.imagePosition.width < this.width) {
        offset = this.imagePosition.left + this.imagePosition.width / 2 - this.width / 2;
        if (offset > this.swipeOffset) {
          this.displayer.slideToPrevious();
        } else if (offset < -this.swipeOffset) {
          this.displayer.slideToNext();
        }
      } else {
        if (this.imagePosition.left + this.imagePosition.width < this.width - this.swipeOffset) {
          this.displayer.slideToNext();
        } else if (this.imagePosition.left > this.swipeOffset) {
          this.displayer.slideToPrevious();
        }
      }
      if (this.imagePosition.width < this.width && this.imagePosition.height < this.height) {
        this.fitMinBorder();
        this.center();
        return;
      }
      if (this.imagePosition.width >= this.width) {
        if (this.imagePosition.left > 0) {
          this.imagePosition.left = 0;
        } else if (this.imagePosition.left + this.imagePosition.width < this.width) {
          this.imagePosition.left = this.width - this.imagePosition.width;
        }
      }
      if (this.imagePosition.height >= this.height) {
        if (this.imagePosition.top > 0) {
          this.imagePosition.top = 0;
        } else if (this.imagePosition.top + this.imagePosition.height < this.height) {
          this.imagePosition.top = this.height - this.imagePosition.height;
        }
      }
      if (this.imagePosition.height < this.height) {
        if (this.imagePosition.top < 0) {
          this.imagePosition.top = 0;
        }
        if (this.imagePosition.top + this.imagePosition.height > this.height) {
          return this.imagePosition.top = this.height - this.imagePosition.height;
        }
      }
    };

    ImageBuffer.prototype.active = function() {
      this.isActive = true;
      if (this.timer) {
        return;
      }
      return this.timer = setInterval(this.update.bind(this), 10);
    };

    ImageBuffer.prototype.deactive = function() {
      this.isActive = false;
      clearInterval(this.timer);
      return this.timer = null;
    };

    ImageBuffer.prototype._reach = function() {
      var equal, prop;
      equal = function(a, b) {
        return Math.abs(a - b) < 0.1;
      };
      for (prop in this._p) {
        if (!equal(this._p[prop], this.imagePosition[prop])) {
          return false;
        }
      }
      return true;
    };

    ImageBuffer.prototype.update = function() {
      var closer, prop, speed;
      if (!this.isActive) {
        return;
      }
      speed = 0.5;
      closer = function(a, b) {
        return (b - a) * speed;
      };
      if (this._reach() && !this.isTouching) {
        this.deactive();
      }
      for (prop in this._p) {
        this._p[prop] += closer(this._p[prop], this.imagePosition[prop]);
      }
      return this.applyImagePosition();
    };

    ImageBuffer.prototype.applyImagePositionImmediate = function() {
      var prop;
      for (prop in this.imagePosition) {
        this._p[prop] = this.imagePosition[prop];
      }
      return this.applyImagePosition();
    };

    ImageBuffer.prototype.applyImagePosition = function() {
      var rx, ry;
      rx = this._p.width / this.UI.image.naturalWidth;
      ry = this._p.height / this.UI.image.naturalHeight;
      return this.UI.image$.css({
        transform: "translate3d(" + this._p.left + "px," + this._p.top + "px,0) scale3d(" + rx + "," + ry + ",1)",
        transformOrigin: "top left"
      });
    };

    ImageBuffer.prototype.handleTouchStart = function(e) {
      e.preventDefault();
      e.stopImmediatePropagation();
      this.console.style.display = "block";
      this.lastPoint = this._averagePosition(e.touches);
      this.active();
      this.isTouching = true;
      if (e.touches.length > 1) {
        this.lastDistance = this._touchDistance(e.touches);
      }
      this.lastStartLength = e.touches.length;
      if (e.touches.length === 1) {
        return this.handleInitialStart(e);
      }
    };

    ImageBuffer.prototype.handleInitialStart = function(e) {
      this.distance = 0;
      return this.checkOpenTimer = setTimeout(((function(_this) {
        return function() {
          if (_this.distance < 30) {
            return _this.displayer.toggleToolbar();
          }
        };
      })(this)), 700);
    };

    ImageBuffer.prototype.handleTouchEnd = function(e) {
      ImageBuffer.__super__.handleTouchEnd.call(this, e);
      if (e.touches.length > 0) {
        this.lastPoint = this._averagePosition(e.touches);
      }
      if (e.touches.length > 1) {
        this.lastDistance = this._touchDistance(e.touches);
      }
      if (e.touches.length === 0) {
        this.isTouching = false;
        this.lastStartLength = 0;
        this.adjust();
        this.handleTouchFinal();
      }
      return clearTimeout(this.checkOpenTimer);
    };

    ImageBuffer.prototype.handleTouchFinal = function() {
      var dbClickMax, dbClickMin, difference;
      if (!this.lastStartDate) {
        this.lastStartDate = Date.now();
      }
      dbClickMax = 300;
      dbClickMin = 100;
      difference = Date.now() - this.lastStartDate;
      if (difference < dbClickMax && difference > dbClickMin) {
        this.lastStartDate -= 0;
        this.emit("imageDoubleClick");
      }
      return this.lastStartDate = Date.now();
    };

    ImageBuffer.prototype.handleTouchMove = function(e) {
      var ap, currentPoint, distance, dx, dy, scale;
      currentPoint = this._averagePosition(e.touches);
      this.imagePosition.top += currentPoint.y - this.lastPoint.y;
      this.imagePosition.left += currentPoint.x - this.lastPoint.x;
      dx = this.lastPoint.x - currentPoint.x;
      dy = this.lastPoint.y - currentPoint.y;
      distance = Math.sqrt(dx * dx + dy * dy);
      if (!this.distance) {
        this.distance = 0;
      }
      this.distance += distance;
      this.lastPoint = currentPoint;
      if (e.touches.length > 1 && this.lastDistance > 0) {
        distance = this._touchDistance(e.touches);
        scale;
        ap = this._averagePosition(e.touches);
        ap.x -= this.imagePosition.left;
        ap.y -= this.imagePosition.top;
        scale = distance / this.lastDistance;
        this.scale(ap, scale);
        return this.lastDistance = distance;
      }
    };

    return ImageBuffer;

  })(TouchManager);

  GalleryDisplayer = (function(_super) {
    __extends(GalleryDisplayer, _super);

    function GalleryDisplayer(template) {
      GalleryDisplayer.__super__.constructor.call(this, template);
      this.buffers = Leaf.Widget.makeList(this.UI.buffers);
      this.resize();
      this.node$.css({
        "perspective": "1000px",
        transformStyle: "preserve-3d"
      });
    }

    GalleryDisplayer.prototype.ImageBuffer = ImageBuffer;

    GalleryDisplayer.prototype.setFileProvider = function(fp, index) {
      if (this.fileProvider) {
        this.fileProvider.stopListenBy(this);
      }
      this.fileProvider = fp;
      this.fileProvider.on("refresh", (function(_this) {
        return function() {
          var after, before, buffer, current, file, src, srcs, target, _i, _j, _len, _len1, _ref;
          if (!_this.isShown) {
            return;
          }
          after = [];
          before = [];
          target = before;
          current = _this.getCurrentBuffer();
          _ref = _this.buffers;
          for (_i = 0, _len = _ref.length; _i < _len; _i++) {
            buffer = _ref[_i];
            if (buffer === current) {
              target = after;
            }
            target.push(buffer.src);
          }
          srcs = [].concat(after, before);
          for (_j = 0, _len1 = srcs.length; _j < _len1; _j++) {
            src = srcs[_j];
            file = _this.fileProvider.getFileBySrcs(src);
            if (!file) {
              continue;
            }
            _this.clear();
            _this.setFileByIndex(file.index);
            return;
          }
        };
      })(this));
      return this.initBuffers(index || 0);
    };

    GalleryDisplayer.prototype.getCurrentBuffer = function() {
      return this.buffers[this.currentBufferCursor];
    };

    GalleryDisplayer.prototype.resize = function() {
      var buffer, _i, _len, _ref, _results;
      this.width = this.node$.width();
      this.height = this.node$.height();
      console.debug("update width", this.width, this.height);
      _ref = this.buffers;
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        buffer = _ref[_i];
        _results.push(buffer.resize());
      }
      return _results;
    };

    GalleryDisplayer.prototype.initBuffers = function(fileIndex) {
      var after, before, buffers, currentFile, cursor, _i, _j, _ref, _ref1;
      this.resize();
      this.clear();
      if (this.bufferCount == null) {
        this.bufferCount = 3;
      }
      buffers = [];
      currentFile = this.fileProvider.at(fileIndex);
      this.currentBufferCursor = 0;
      this.buffers.push(this.createBuffer(currentFile));
      cursor = currentFile;
      for (after = _i = 1, _ref = this.bufferCount; 1 <= _ref ? _i <= _ref : _i >= _ref; after = 1 <= _ref ? ++_i : --_i) {
        cursor = this.fileProvider.next(cursor);
        if (!cursor) {
          break;
        }
        this.buffers.push(this.createBuffer(cursor));
      }
      cursor = currentFile;
      for (before = _j = _ref1 = this.bufferCount; _ref1 <= 1 ? _j <= 1 : _j >= 1; before = _ref1 <= 1 ? ++_j : --_j) {
        cursor = this.fileProvider.previous(cursor);
        if (!cursor) {
          break;
        }
        this.buffers.unshift(this.createBuffer(cursor));
        this.currentBufferCursor += 1;
      }
      return this.setupBufferPositions();
    };

    GalleryDisplayer.prototype.setupBufferPositions = function(option) {
      var buffer, css, current, index, _i, _j, _len, _ref, _ref1, _ref2, _results;
      if (option == null) {
        option = {};
      }
      _ref = this.buffers;
      for (index = _i = 0, _len = _ref.length; _i < _len; index = ++_i) {
        buffer = _ref[index];
        console.debug(this.width, "is my width");
        css = {
          transform: "translateX(" + ((index - this.currentBufferCursor) * this.width) + "px)",
          left: 0
        };
        if (__indexOf.call((function() {
          _results = [];
          for (var _j = _ref1 = this.currentBufferCursor - 1, _ref2 = this.currentBufferCursor + 1; _ref1 <= _ref2 ? _j <= _ref2 : _j >= _ref2; _ref1 <= _ref2 ? _j++ : _j--){ _results.push(_j); }
          return _results;
        }).apply(this), index) < 0) {
          buffer.node$.hide();
        } else {
          buffer.node$.show();
        }
        if (!option.time || true) {
          buffer.node$.css(css);
        } else {
          buffer.node$.animate(css, option.time);
        }
      }
      if (current = this.getCurrentBuffer()) {
        return this.emit("display", current.file);
      }
    };

    GalleryDisplayer.prototype.clear = function() {
      this.buffers.length = 0;
      return this.currentBufferCursor = -1;
    };

    GalleryDisplayer.prototype.createBuffer = function(file) {
      var buffer;
      ImageBuffer.prototype.template = this.templates.imageBuffer;
      buffer = new this.ImageBuffer(this);
      buffer.setFile(file);
      return buffer;
    };

    GalleryDisplayer.prototype._adjustBuffers = function() {
      var after, before, cursor, first, index, last, _i, _j, _ref, _ref1, _results, _results1;
      last = this.buffers[this.buffers.length - 1];
      first = this.buffers[0];
      after = this.buffers.length - this.currentBufferCursor - 1;
      before = this.currentBufferCursor;
      if (before < this.bufferCount && first) {
        cursor = first.file;
        for (index = _i = 1, _ref = this.bufferCount - before; 1 <= _ref ? _i <= _ref : _i >= _ref; index = 1 <= _ref ? ++_i : --_i) {
          cursor = this.fileProvider.previous(cursor);
          if (!cursor) {
            break;
          }
          this.buffers.unshift(this.createBuffer(cursor));
          this.currentBufferCursor += 1;
        }
      } else if (before > this.bufferCount) {
        while (before > this.bufferCount) {
          before -= 1;
          this.buffers.shift();
          this.currentBufferCursor -= 1;
        }
      }
      if (after < this.bufferCount && last) {
        cursor = last.file;
        _results = [];
        for (index = _j = 1, _ref1 = this.bufferCount - after; 1 <= _ref1 ? _j <= _ref1 : _j >= _ref1; index = 1 <= _ref1 ? ++_j : --_j) {
          cursor = this.fileProvider.next(cursor);
          if (!cursor) {
            break;
          }
          _results.push(this.buffers.push(this.createBuffer(cursor)));
        }
        return _results;
      } else if (after > this.bufferCount) {
        _results1 = [];
        while (after - this.bufferCount > 0) {
          after -= 1;
          _results1.push(this.buffers.pop());
        }
        return _results1;
      }
    };

    GalleryDisplayer.prototype.slideToNext = function() {
      if (this.currentBufferCursor === this.buffers.length - 1) {
        return false;
      }
      this._slideToIndex(this.currentBufferCursor + 1);
      return true;
    };

    GalleryDisplayer.prototype.slideToPrevious = function() {
      if (this.currentBufferCursor === 0) {
        return false;
      }
      this._slideToIndex(this.currentBufferCursor - 1);
      return true;
    };

    GalleryDisplayer.prototype._slideToIndex = function(index) {
      if (index < 0 || index >= this.buffers.length) {
        throw new Error("slide to index " + index + " is out of range of " + this.buffers.length);
      }
      if (this.buffers[this.currentBufferCursor]) {
        this.buffers[this.currentBufferCursor].deactive();
      }
      this.currentBufferCursor = index;
      if (this.getCurrentBuffer()) {
        this.getCurrentBuffer().active();
      }
      this._adjustBuffers();
      return this.setupBufferPositions({
        time: 140
      });
    };

    GalleryDisplayer.prototype.setFileByIndex = function(index) {
      var file;
      file = this.fileProvider.at(index);
      if (!file) {
        throw new Error("file doesn't contain index " + index);
      }
      this.currentFile = file;
      return this.initBuffers(index);
    };

    return GalleryDisplayer;

  })(Leaf.Widget);

  StatefulImageBuffer = (function(_super) {
    __extends(StatefulImageBuffer, _super);

    function StatefulImageBuffer() {
      var args;
      args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
      this.include(CubeLoadingHint);
      StatefulImageBuffer.__super__.constructor.apply(this, args);
    }

    return StatefulImageBuffer;

  })(ImageBuffer);

  GalleryDisplayer.prototype.ImageBuffer = StatefulImageBuffer;

  tm.use("view/imageDisplayer");

  ImageDisplayer = (function(_super) {
    __extends(ImageDisplayer, _super);

    function ImageDisplayer() {
      this.include(SmartImage);
      this.include(CubeLoadingHint);
      ImageDisplayer.__super__.constructor.call(this, App.templates.view.imageDisplayer);
      this.gallery = new GalleryDisplayer(this.node);
      ImageBuffer.setLoader(App.imageLoader);
      this.UI.buffers.addEventListener("touchstart", (function(_this) {
        return function(e) {
          e.stopImmediatePropagation();
          e.preventDefault();
          return _this.hide();
        };
      })(this));
    }

    ImageDisplayer.prototype.setSrcs = function(srcs, index) {
      var fileProvider;
      fileProvider = new FileProvider(srcs);
      return this.gallery.setFileProvider(fileProvider, index || 0);
    };

    ImageDisplayer.prototype.setSrc = function(src) {
      return this.setSrcs([src]);
    };

    ImageDisplayer.prototype.onClickNode = function() {
      return this.hide();
    };

    return ImageDisplayer;

  })(Popup);

  module.exports = ImageDisplayer;

}).call(this);

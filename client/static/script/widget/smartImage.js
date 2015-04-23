// Generated by CoffeeScript 1.8.0
(function() {
  var App, ImageLoader, SmartImage, tm,
    __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

  App = require("/app");

  ImageLoader = require("/component/imageLoader");

  tm = require("/common/templateManager");

  tm.use("widget/smartImage");

  SmartImage = (function(_super) {
    __extends(SmartImage, _super);

    SmartImage.setLoader = function(loader) {
      return this.loader = loader;
    };

    function SmartImage(el, params) {
      var prop;
      if (params == null) {
        params = {};
      }
      SmartImage.__super__.constructor.call(this, App.templates.widget.smartImage);
      this.expose("src");
      this.expose("loadingSrc");
      this.expose("errorSrc");
      this.expose("fallbackSrcs");
      this.expose("on");
      this.expose("state");
      this.node.state = "void";
      this.fallbacks = [];
      for (prop in params) {
        this.node[prop] = params[prop];
      }
    }

    SmartImage.prototype.onSetFallbackSrcs = function(fallbacks) {
      if (fallbacks == null) {
        fallbacks = [];
      }
      if (typeof fallbacks === "string") {
        fallbacks = fallbacks.split(",");
      } else if (fallbacks instanceof Array) {
        fallbacks = fallbacks.filter(function(item) {
          return typeof item === "string";
        });
      }
      return this.fallbacks = fallbacks;
    };

    SmartImage.prototype.onSetState = function(state) {
      this.state = state;
      return this.emit("state", state);
    };

    SmartImage.prototype.onSetLoadingSrc = function(src) {
      if (src === this.loadingSrc) {
        return;
      }
      this.loadingSrc = src;
      if (this.node.state === "loading") {
        return this.UI.image.src = src;
      }
    };

    SmartImage.prototype.onSetErrorSrc = function(src) {
      if (src === this.errorSrc) {
        return;
      }
      this.errorSrc = src;
      if (this.node.state === "fail") {
        return this.UI.image.src = src;
      }
    };

    SmartImage.prototype.onSetSrc = function(src) {
      if (src === this.src) {
        return;
      }
      this.src = src;
      return this.trySrc(src);
    };

    SmartImage.prototype.trySrc = function(src) {
      if (this.loadingSrc) {
        this.UI.image.src = this.loadingSrc;
      } else {
        this.UI.image.removeAttribute("src");
      }
      this.node.state = "loading";
      this.currentLoadingSrc = src;
      return SmartImage.loader.cache(src, (function(_this) {
        return function(error) {
          _this.currentLoadingSrc = null;
          if (error) {
            if (error instanceof ImageLoader.Errors.Abort) {
              console.debug("manually abort smart image loading", src);
              return;
            }
            if (_this.fallbacks.length > 0) {
              _this.node.state = "fallback";
              _this.trySrc(_this.fallbacks.shift());
              return;
            }
            _this.node.state = "fail";
            if (_this.errorSrc) {
              _this.UI.image.src = _this.errorSrc;
            }
            return;
          }
          _this.node.state = "succuess";
          return _this.UI.image.src = src;
        };
      })(this));
    };

    SmartImage.prototype.destroy = function() {
      this.isDestroyed = true;
      if (this.currentLoadingSrc) {
        SmartImage.loader.stop(this.currentLoadingSrc);
        return this.currentLoadingSrc = null;
      }
    };

    return SmartImage;

  })(Leaf.Widget);

  module.exports = SmartImage;

}).call(this);

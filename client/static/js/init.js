// Generated by CoffeeScript 1.8.0
(function() {
  var context;

  context = new LeafRequire();

  context.setConfig("./require.json", function(err) {
    if (err) {
      throw err;
    }
    if (window.location.toString().indexOf("?debug") > 0) {
      context.debug = true;
      context.enableCache = false;
    }
    return context.load(function() {
      return console.log("sybil loaded at version " + context.version);
    });
  });

  window.SybilMainContext = context;

}).call(this);

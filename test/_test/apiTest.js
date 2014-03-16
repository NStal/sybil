(function() {
  var request,
    _this = this;

  request = require("request");

  request.get("http://localhost:3001/api/rss", function(err, res, body) {
    console.log("done");
    return console.log(body);
  });

}).call(this);

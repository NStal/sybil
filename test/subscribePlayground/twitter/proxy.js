var http = require('https');
var proxy = require('proxy-agent');

// HTTP, HTTPS, or SOCKS proxy to use
var proxyUri = "socks://localhost:7777/";

var opts = {
  method: 'GET',
  host: 'twitter.com',
    protocol:"https:",
  path: '/',
  // this is the important part!
  agent: proxy(proxyUri,true)
};

// the rest works just like any other normal HTTP request
http.get(opts, onresponse);

function onresponse (res) {
  console.log(res.statusCode, res.headers);
  res.pipe(process.stdout);
}

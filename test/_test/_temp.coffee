$ = require "jquery"
page = $ (require "fs").readFileSync "./loaded","utf8"
query = "BODY > DIV.z > DIV.large.left > DIV.z-l.f-list > DIV#list_bangumi_dynamic.vidbox > DIV.bgmbox > UL > LI.new"
query = "BODY > DIV.z > DIV.large.left > DIV.z-l.f-list > DIV#list_bangumi_dynamic.vidbox > DIV.bgmbox > UL > LI"
something = page.find query
console.log something.length
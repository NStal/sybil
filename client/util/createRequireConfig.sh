#!/bin/bash
version=`./util/updateVersion.sh`
[ -z $version ] && version="unkown"
echo create require.json for $version
leafjs-require ./static/js/ -r ./js/ -o ./static/require.json --excludes ./static/js/lib/jquery.js,./static/js/lib/leaf-require.js,./static/js/lib/leaf.js --set-version $version

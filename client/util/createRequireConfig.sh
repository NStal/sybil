#!/bin/bash
version=`./util/updateVersion.sh`
[ -z "$version" ] && version="unkown" && exit 1

echo create require.json for $version
leafjs-require ./static/script/ -r ./script/ -o ./static/require.json --excludes ./static/script/lib/jquery.js,./static/script/lib/leaf-require.js,./static/script/lib/leaf.js --set-version $version

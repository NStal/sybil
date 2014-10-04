#!/bin/bash
version=`./util/updateVersion.sh`
[ -z $version ] && version="unkown"
echo create require.json for $version
leafjs-require ./static/js/ -r ./js/ -o ./static/require.json --main main.js --excludes ./lib/ --set-version $version

echo "build for ubuntu"
. ./functions.sh
cd ..
dir="./ubuntu/"
ensureDir $dir
transfer package.json $dir
transfer settings.coffee $dir
transfer settings.user.json $dir
transfer core $dir
transfer plugins $dir
transfer webApi $dir
transfer client $dir
transfer collector $dir
transfer common $dir
transfer p2p $dir
transfer README.md $dir
transfer test $dir
transfer util $dir
transfer guide $dir
transfer ./release-util/install-ubuntu.sh $dir
echo "done"

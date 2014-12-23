#!/bin/bash
filename=$1
time=`date "+%Y-%m-%d-%Hhour-%Mmin-%Ssec"`
path="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
[ -z $filename ] && filename=$time.tar.gz
backupPathBase=$path/../../backup
backupPathTemp=$backupPathBase/temp
projectPath=$path/../../
echo $backupPath
db=`coffee $projectPath/start.coffee settings dbName`
dbPort=`coffee $projectPath/start.coffee settings dbPort`
dbHost=`coffee $projectPath/start.coffee settings dbHost`
[ -z $db ] && db=sybil
[ -z $dbPort ] && dbPort=27017
[ -z $dbHost ] && dbHost=localhost
[ -d $backupPathBase ] || mkdir -p $backupPathBase
[ -d $backupPathTemp ] || mkdir -p $backupPathTemp
echo "backup from mongo://$dbHost:$dbPort/$db"
mongodump --host $dbHost --port $dbPort --db $db --out $backupPathTemp
cp $path/../../settings.user.json $backupPathTemp/
cp $path/../../rsa.key $backupPathTemp/
pushd $backupPathBase
tar -zcvf $filename  --directory=./temp .
popd

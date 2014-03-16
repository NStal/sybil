#!/bin/bash
time=`date "+%Y-%m-%d-%Hhour-%Mmin-%Ssec"`
path="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
backupPathBase=$path/../../backup
backupPathTemp=$backupPathBase/temp
echo $backupPath
db=$SYBIL_DB_NAME
dbPort=$SYBIL_DB_PORT
dbHost=$SYBIL_DB_HOST
[ -z $db ] && db=sybil
[ -z $dbPort ] && dbPort=27017
[ -z $dbHost ] && dbHost=localhost
[ -d $backupPathBase ] || mkdir -p $backupPathBase
[ -d $backupPathTemp ] || mkdir -p $backupPathTemp
mongodump --host $dbHost --port $dbPort --db $db --out $backupPathTemp
cp $path/../../settings.user.json $backupPathTemp/
cp $path/../../rsa.key $backupPathTemp/
pushd $backupPathBase
tar -zcvf $time.tar.gz --directory=./temp .
popd

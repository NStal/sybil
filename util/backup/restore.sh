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
filePath=$1
[ -z $filePath ] && echo "usage restore.sh <path/to/unpacked/backup/files>" && exit
mongorestore --host $dbHost --port $dbPort --db $db $filePath
cp $filePath/settings.user.json $path/../../settings.user.json -rf

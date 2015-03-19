#!/bin/bash
while read type value; do
  case "$type" in
    main) main=$value;;
    sub) sub=$value;;
    "") ;; # blank line
    *) echo >&2 "$0: unrecognized config directive '$command'";;
  esac
done < version

#echo "fail to update version no main specified"
[ -z "$main" ] && exit 1
sub=$(( $sub + 1 ))
echo main $main > version
echo sub $sub >> version 
echo $main.$sub

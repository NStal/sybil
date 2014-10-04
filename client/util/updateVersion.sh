#!/bin/bash
while read type value; do
  case "$type" in
    main) main=$value;;
    sub) sub=$value;;
    "") ;; # blank line
    *) echo >&2 "$0: unrecognized config directive '$command'";;
  esac
done < version

sub=$(( $sub + 1 ))
echo main $main > version
echo sub $sub >> version 
echo $main.$sub

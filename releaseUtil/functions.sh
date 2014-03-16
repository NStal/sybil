panic(){
    echo $1
    exit 1
}

ensureDir(){
    [ ! -d $1 ] && mkdir -p $1 > /dev/null
    [ ! -d $1 ] && panic "can create dir $1"
}

transfer(){
    rsync -avPziouL --delete $1 $2
}

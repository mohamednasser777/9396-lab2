#!/bin/bash
if [ $# -ne 3 ]
then
    echo "usage: $0 <dir> <maldir> <interval>" >&2
    exit 1
fi
dir=$1
maldir=$2
time_interval=$3

if [ ! -d "$dir" ]; then
  echo "not a directory: $dir" >&2
  exit 1
fi

if [ ! -d "$maldir" ]; then
  echo "not a directory: $maldir" >&2
  exit 1
fi

case "$time_interval" in
    ''|*[!0-9]*|0)
        echo "interval must be a positive integer" >&2
        exit 1
        ;;
esac
while true
do
    
    ls -l "$dir" > directory-info.new
    if [ -f directory-info.last ] && cmp -s directory-info.last directory-info.new
    then
        sleep "$time_interval"
        continue
    fi
    
    for file in "$dir"/*
    do 
        if [ ! -f "$file" ] 
        then
          continue
        fi    
   
        is_malicious=0

        case "$file" in
            *.exe|*.bat|*.vbs|*.scr|*.ps1) is_malicious=1 ;; 
        esac
        if [ "$is_malicious" -eq 0 ] 
        then  
            if grep -iaEq "virus|trojan|malware|worm|ransomware" "$file" 2>/dev/null
            then 
                is_malicious=1
            fi
        fi

        if [ "$is_malicious" -eq 1 ]
        then
            echo "$(basename "$file") is malicious and it is DELETED"
            if cp "$file" "$maldir/"
            then
                rm "$file"
            fi
        fi

    done 
     
    ls -l "$dir" > directory-info.last
    sleep "$time_interval"
done
    
    
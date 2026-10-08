#!/bin/bash
if [ $# -ne 2 ] 
then
    echo "usage: $0 <dir> <maldir>" >&2
    exit 1
fi

dir=$1
maldir=$2

if [ ! -d "$dir" ] 
then
  echo "not a directory: $dir" >&2
  exit 1
fi

if [ ! -d "$maldir" ]
then
  echo "not a directory: $maldir" >&2
  exit 1
fi

shopt -s nullglob

while true
do 
    files=("$maldir"/*)
    if [ ${#files[@]} -eq 0 ]
    then
        echo "No malicious files to review."
        exit 0
    fi

    
    for i in "${!files[@]}"; do
        echo "$((i + 1))) $(basename "${files[$i]}")"
    done

    while true
    do
        read -p "Enter the number of the file you want:" -r choice || exit 0
        
        case "$choice" in
            ''|*[!0-9]*)
                echo "please enter a number" >&2
                continue
                ;;
        esac

        if [ "$choice" -lt 1 ] || [ "$choice" -gt "${#files[@]}" ]
        then
            echo "out of range" >&2
            continue
        fi

        break
    done

    index=`expr $choice - 1`
    file="${files[$index]}"
    name=$(basename "$file")
    
    while true
    do
        echo "the file :$name is selected"
        echo "press 1 to restore this file back to it's directory"
        echo "press 2 to permenantly delete this file"
        echo "press 3 to go back to the list"
        echo "press 4 to quit"
        read -p "Enter number (1, 2, 3 or 4): " -r number || exit 0

        case "$number" in 
            1)
                cp "$file" "$dir/" && rm "$file"
                echo "Restored $name to $dir."
                break
                 ;;
            2)
                rm "$file"
                echo "$name permanently deleted."
                break
                ;;
            3)
                break
                ;;
            4)
                exit 0
                ;;
            *)
                echo "invalid option" >&2
                continue
                ;;
        esac
    done
done


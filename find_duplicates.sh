#!/usr/bin/env bash

shopt -s globstar

INTERACTIVE=false
SEARCH_DIR="$PWD"
# options:
# -i - remove interactivly
while getopts ":i" OPTION; do
	case "$OPTION" in
		i)
			INTERACTIVE=true
			;;
		*)
			echo Unknown option
			;;
	esac
done

shift $((OPTIND - 1))

if [ -n "$1" ]; then
	SEARCH_DIR="$1"
fi

function print_duplicates() {
	if [ -z "$USE_LIGHT_COLOR" ]; then
		USE_LIGHT_COLOR=false
	fi

	if [ "$USE_LIGHT_COLOR" = true ]; then
		printf "%b" "\e[0;32m"
		USE_LIGHT_COLOR=false
	else
		printf "%b" "\e[0;36m"
		USE_LIGHT_COLOR=true
	fi

	for ARG in "$@"; do
		echo "$ARG"
	done

	printf "%b" "\e[0m"
}

function ask_delete() {
	print_duplicates $1 $2
	END=false
	while [ "$END" = false ]; do
		read -p $'\e[1;32mDuplicates found. Delete first (f|1) second (s|2) or none (n|0)\e[0m ' -n 1
		echo ""
		case "$REPLY" in
			f|1)
				rm $1
				END=true
				;;
			s|2)
				rm $2
				END=true
				;;
			n|0)
				END=true
				;;
			*)
				echo -e "\e[0;31mInvalid answer\e[0m"
				;;
		esac
	done
}

declare -A files

for file in "${SEARCH_DIR}"/**/*; do
	if ! [ -f "$file" ]; then
		continue
	fi

	HASH=$(shasum "$file" | awk '{print $1}')

	if [ ${files[$HASH]+_} ]; then
		if [ "$INTERACTIVE" = "true" ]; then
			ask_delete ${files[$HASH]} $file
		else
			print_duplicates ${files[$HASH]} $file
		fi

	else
		files+=([$HASH]="$file")
	fi
done

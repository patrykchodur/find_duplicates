#!/usr/bin/env bash

shopt -s globstar

INTERACTIVE=false
SEARCH_DIR="$PWD"
HELP=false

function print_duplicates() {
	if [ -z "$USE_SECOND_COLOR" ]; then
		USE_SECOND_COLOR=false
	fi

	if [ "$USE_SECOND_COLOR" = true ]; then
		printf "%b" "\e[0;32m"
		USE_SECOND_COLOR=false
	else
		printf "%b" "\e[0;36m"
		USE_SECOND_COLOR=true
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

function print_usage() {
	echo "Usage:"
	echo "  $1 [-i] [directory] -- find duplicates in directory"
	echo "  $1 -h               -- display this help"
}

# options:
# -i - remove interactivly
# -h - help
while getopts "ih" OPTION; do
	case "$OPTION" in
		i)
			INTERACTIVE=true
			;;
		h)
			HELP=true
			;;
		*)
			print_usage $0
			exit 1
			;;
	esac
done

shift $((OPTIND - 1))

if [ -n "$1" ]; then
	SEARCH_DIR="$1"
fi


if [ "$HELP" = true ]; then
	print_usage $0
	exit 0
fi

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

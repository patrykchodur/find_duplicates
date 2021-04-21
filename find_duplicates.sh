#!/usr/bin/env bash

# check if used commands are available

ENVIORMENT_OK=true

if ! command -v shasum &>/dev/null; then
	ENVIORMENT_OK=false
	printf "%b" "\e[0;31mError: shasum not available\e[0;0m\n"
fi

if ! command -v awk &>/dev/null; then
	ENVIORMENT_OK=false
	printf "%b" "\e[0;31mError: awk not available\e[0;0m\n"
fi

if ! command -v shopt &>/dev/null; then
	ENVIORMENT_OK=false
	printf "%b" "\e[0;31mError: shopt not available\e[0;0m\n"
fi

if ! command -v declare &>/dev/null; then
	ENVIORMENT_OK=false
	printf "%b" "\e[0;31mError: declare not available\e[0;0m\n"
fi


if [ "$ENVIORMENT_OK" = false ]; then
	exit 1
fi


shopt -s globstar

INTERACTIVE=false
SEARCH_DIR="."
HELP=false

function is_number() {
	RE='^[0-9]+$'
	if ! [[ "$1" =~ "$re" ]] ; then
		return 1
	else
		return 0
	fi
}

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
	ARGS=( "$@" )
	print_duplicates "${ARGS[@]}"
	END=false
	while [ "$END" = false ]; do
		END=true

		read -p $'\e[1;32mDuplicates found. Enter numbers of files to delete (press enter for none)\e[0m '

		for NUMBER in $REPLY; do
			if ! is_number "$NUMBER" || [ "$NUMBER" -gt "${#ARGS[@]}" ] || [ "$NUMBER" -lt 1 ]; then
				echo -e "\e[0;31mInvalid answer: $NUMBER\e[0m"
				END=false
			fi
		done

		if [ "$END" = false ]; then
			continue
		fi

		for NUMBER in $REPLY; do
			NUMBER=$(( NUMBER - 1 ))
			rm "${ARGS[NUMBER]}"
		done
	done
}

function print_usage() {
	echo "Usage: $1 [OPTION]... [directory]"
	echo "   Find duplicated files and optionally delete them."
	echo "   If no directory is provided, current working directory will be used."
	echo
	echo "   Options:"
	echo "     -i         ask user to delete duplicated files"
	echo "     -h         display this help"
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


# list of file paths indexed using hash value
# every array element is string containing paths
declare -A files

function print_file_duplicates() {
	for file_list_string in "${files[@]}"; do
		eval "file_list=( ${file_list_string} )"
		if [ "${#file_list[@]}" -ne 1 ]; then
			print_duplicates "${file_list[@]}"
		fi
	done
}

function exit_abnormally() {
	echo
	print_file_duplicates
	exit 1
}

trap exit_abnormally SIGINT

for file in "${SEARCH_DIR}"/**/*; do
	if ! [ -f "$file" ]; then
		continue
	fi

	HASH=$(shasum "$file" | awk '{print $1}')

	files[$HASH]="${files[$HASH]} '$file'"
done

if [ "$INTERACTIVE" = true ]; then
	for file_list_string in "${files[@]}"; do
		eval "file_list=( ${file_list_string} )"
		if [ "${#file_list[@]}" -ne 1 ]; then
			ask_delete "${file_list[@]}"
		fi
	done
else
	print_file_duplicates
fi

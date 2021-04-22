#!/usr/bin/env bash

# check if used commands are available

ENVIORMENT_OK=true

function print_error() {
	printf "%b" "\e[0;31mError: $1\e[0;0m\n"
}

function print_warning() {
	printf "%b" "\e[0;33mWarning: $1\e[0;0m\n"
}

if ! command -v shasum &>/dev/null; then
	ENVIORMENT_OK=false
	print_error "shasum not available"
fi

if ! command -v awk &>/dev/null; then
	ENVIORMENT_OK=false
	print_error "awk not available"
fi

if ! command -v shopt &>/dev/null; then
	ENVIORMENT_OK=false
	print_error "shopt not available"
fi

if ! command -v declare &>/dev/null; then
	ENVIORMENT_OK=false
	print_error "declare not available"
fi


if [ "$ENVIORMENT_OK" = false ]; then
	exit 1
fi


shopt -s globstar

INTERACTIVE=false
SEARCH_DIR="."
HELP=false

function is_number() {
	if ! [[ "$1" =~ ^[0-9]+$ ]] ; then
		return 1
	else
		return 0
	fi
}

# Function takes names of duplicated files
# Variable $USE_NUMBERS should be set to either "true" or "false"
function print_duplicates_internal() {
	if [ -z "$USE_NUMBERS" ]; then
		echo "Warning: \$USE_NUMBERS not specified. Using default"
		USE_NUMBERS=false
	fi

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

	ITER=1
	for ARG in "$@"; do
		if [ "$USE_NUMBERS" = true ]; then
			echo "$ITER) $ARG"
		else
			echo "$ARG"
		fi
		ITER=$(( $ITER + 1 ))
	done

	printf "%b" "\e[0m"
	unset USE_NUMBERS
}

function print_duplicates() {
	USE_NUMBERS=false
	print_duplicates_internal "$@"
}

function print_duplicates_with_numbers() {
	USE_NUMBERS=true
	print_duplicates_internal "$@"
}

function ask_delete() {
	ARGS=( "$@" )
	print_duplicates_with_numbers "${ARGS[@]}"
	END=false
	while [ "$END" = false ]; do
		END=true

		read -p $'\e[1;32mDuplicates found. Enter numbers of files to delete (press enter for none)\e[0m '

		for NUMBER in $REPLY; do
			if ! is_number "$NUMBER" || [ "$NUMBER" -gt "${#ARGS[@]}" ] || [ "$NUMBER" -lt 1 ]; then
				print_error "Invalid answer: $NUMBER"
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

function print_file_duplicates_interactively() {
	for file_list_string in "${files[@]}"; do
		eval "file_list=( ${file_list_string} )"
		if [ "${#file_list[@]}" -ne 1 ]; then
			ask_delete "${file_list[@]}"
		fi
	done
}

function exit_abnormally() {
	echo
	print_warning "exiting abnormally. Printing found duplicates:"
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

# disable printing all files after ctrl-c
trap - SIGINT

if [ "$INTERACTIVE" = true ]; then
	print_file_duplicates_interactively
else
	print_file_duplicates
fi

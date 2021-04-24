#!/usr/bin/env bash

TTY_STDOUT=false
if [[ -t 1 ]]; then
	TTY_STDOUT=true
fi
TTY_STDERR=false
if [[ -t 2 ]]; then
	TTY_STDERR=true
fi

# basic error printing functions
function print_error() {
	if [ "$TTY_STDERR" = true ]; then
		printf "%b" "\e[0;31mError: $1\e[0;0m\n" >&2
	else
		printf "%b" "Error: $1\n" >&2
	fi
}

function print_warning() {
	if [ "$TTY_STDERR" = true ]; then
		printf "%b" "\e[0;33mWarning: $1\e[0;0m\n" >&2
	else
		printf "%b" "Warning: $1\n" >&2
	fi
}

function print_debug() {
	if [ "$TTY_STDERR" = true ]; then
		printf "%b" "\e[1;33mDebug: $1\e[0;0m\n" >&2
	else
		printf "%b" "Debug: $1\n" >&2
	fi
}


# check if used commands are available
ENVIORMENT_OK=true

if command -v openssl &>/dev/null; then
	USE_OPENSSL=true
else
	USE_OPENSSL=false
	if ! command -v shasum &>/dev/null; then
		ENVIORMENT_OK=false
		print_error "openssl or shasum not available"
	fi
fi

if ! command -v awk &>/dev/null; then
	ENVIORMENT_OK=false
	print_error "awk not available"
fi

if [[ "$(echo "$BASH_VERSION" | cut -b 1)" -lt 4 ]]; then
	ENVIORMENT_OK=false
	print_error "this script requires bash version 4 or above"
fi

if [ "$ENVIORMENT_OK" = false ]; then
	exit 1
fi

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
		print_warning "\$USE_NUMBERS not specified. Using default"
		USE_NUMBERS=false
	fi

	if [ -z "$USE_SECOND_COLOR" ]; then
		USE_SECOND_COLOR=false
	fi

	if [ "$TTY_STDOUT" = true ]; then
		if [ "$USE_SECOND_COLOR" = true ]; then
			printf "%b" "\e[0;32m"
			USE_SECOND_COLOR=false
		else
			printf "%b" "\e[0;36m"
			USE_SECOND_COLOR=true
		fi
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

	if [ "$TTY_STDOUT" = true ]; then
		printf "%b" "\e[0m"
	else
		printf "%b" "\n"
	fi

	unset USE_NUMBERS
}

ALWAYS_USE_NUMBER=false

function print_duplicates() {
	USE_NUMBERS="$ALWAYS_USE_NUMBER"
	print_duplicates_internal "$@"
}

function print_duplicates_with_numbers() {
	USE_NUMBERS=true
	print_duplicates_internal "$@"
}

function open_file() {
	SYSTEM_NAME="$(uname -s)"
	case "$SYSTEM_NAME" in
		Linux*) xdg-open "$1";;
		Darwin*) open "$1";;
		*) print_error "open not supported on platform $SYSTEM_NAME"
	esac
}

function ask_delete() {
	ARGS=( "$@" )
	print_duplicates_with_numbers "${ARGS[@]}"
	END=false
	while [ "$END" = false ]; do
		END=true

		read -p "Duplicates found. Enter numbers of files to delete, type 'o' to open, or press enter for no action " 2>&1

		if [[ "$REPLY" =~ ^[[:space:]]*o[[:space:]]*$ ]]; then
			END=false
			open_file "${ARGS[0]}"
			continue
		fi

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
	>&2 echo "Usage: $1 [OPTION]... [directory]"
	>&2 echo "   Find duplicated files and optionally delete them."
	>&2 echo "   If no directory is provided, current working directory will be used."
	>&2 echo
	>&2 echo "   Options:"
	>&2 echo "     -a         include hidden files and directories"
	>&2 echo "     -i         ask user to delete duplicated files"
	>&2 echo "     -n         always display file number"
	>&2 echo "     -p         display progress bar"
	>&2 echo "     -h         display this help"
}

# options:
# -i - remove interactivly
# -h - help

INTERACTIVE=false
SEARCH_DIR="."
HELP=false
PROGRESS_BAR=false
ALL_FILES=false

while getopts ":ainph" OPTION; do
	case "$OPTION" in
		a)
			ALL_FILES=true
			;;
		i)
			INTERACTIVE=true
			;;
		n)
			ALWAYS_USE_NUMBER=true
			;;
		p)
			PROGRESS_BAR=true
			;;
		h)
			HELP=true
			;;
		*)
			print_error "illegal option: -$OPTARG"
			print_usage $0
			exit 1
			;;
	esac
done

if [ "$HELP" = true ]; then
	print_usage $0
	exit 0
fi

# Prepare woring directory
shift $((OPTIND - 1))

if [ "$#" -eq 1 ]; then
	SEARCH_DIR="$1"
elif [ "$#" -gt 1 ]; then
	print_error "only one directory can be specified"
	print_usage $0
	exit 1
fi

if ! [ -d "$SEARCH_DIR" ]; then
	print_error "directory $SEARCH_DIR does not exists"
	print_usage $0
	exit 1
fi

if [ "$TTY_STDOUT" = false ] && [ "$INTERACTIVE" = true ]; then
	print_error "interactive mode is available only when using terminal output"
	print_usage $0
	exit 1
fi

if [ "$TTY_STDERR" = false ] && [ "$PROGRESS_BAR" = true ]; then
	print_error "progress bar is available only when using terminal output"
	print_usage $0
	exit 1
fi

# List of file paths indexed using hash value.
# Every array element is a string containing paths in single quotes ('').
declare -A FILES

function print_file_duplicates() {
	for FILE_LIST_STRING in "${FILES[@]}"; do
		eval "FILE_LIST=( $FILE_LIST_STRING )"
		if [ "${#FILE_LIST[@]}" -ne 1 ]; then
			print_duplicates "${FILE_LIST[@]}"
		fi
	done
}

function print_file_duplicates_interactively() {
	for FILE_LIST_STRING in "${FILES[@]}"; do
		eval "FILE_LIST=( ${FILE_LIST_STRING} )"
		if [ "${#FILE_LIST[@]}" -ne 1 ]; then
			ask_delete "${FILE_LIST[@]}"
		fi
	done
}

function exit_abnormally() {
	[ "$TTY_STDERR" = true ] && echo
	print_warning "exiting abnormally. Printing found duplicates:"
	[ "$TTY_STDERR" = false ] && echo
	print_file_duplicates
	exit 1
}

# Calculating all hashes can take some time, so the user may interrupt the process.
# The script will display already found duplicates in such case.
trap exit_abnormally SIGINT

function list_files() {
	if [[ "$ALL_FILES" = true ]]; then
		find "$1" -type f -print0
	else
		find "$1" -not -path '*/\.[^./]*' -type f -print0
	fi
}

# it has to be done the same way as main loop
FILES_NUMBER=0

while IFS= read -r -d '' FILE; do
	FILES_NUMBER=$((FILES_NUMBER + 1))
done < <(list_files "$SEARCH_DIR")

PROGRESS_ITER=0

function update_progress() {
	if [[ "$PROGRESS_BAR" = false ]] || [[ "$DONE_DISPLAYED" ]]; then
		return 0
	fi

	PROGRESS_PERCENT=$((PROGRESS_ITER * 100 / FILES_NUMBER))
	>&2 printf "%bProgress: %s%%" "\e[G" "$PROGRESS_PERCENT"

	if [[ "$PROGRESS_PERCENT" -eq 100 ]] && [[ -z "$DONE_DISPLAYED" ]]; then
		>&2 printf " Done!\n"
		DONE_DISPLAYED=true
	fi
}

while IFS= read -r -d '' FILE; do

	if [[ "$USE_OPENSSL" = true ]]; then
		HASH=$(openssl sha1 -r "$FILE" | awk '{print $1}')
	else
		HASH=$(shasum "$FILE" | awk '{print $1}')
	fi

	FILES[$HASH]="${FILES[$HASH]} '${FILE//\'/\'\\\'\'}'"

	PROGRESS_ITER=$((PROGRESS_ITER + 1))
	if [[ $((PROGRESS_ITER % 100)) -eq 0 ]]; then
		update_progress
	fi

done < <(list_files "$SEARCH_DIR")

update_progress

# Disable printing all files after ctrl-c
trap - SIGINT

if [ "$INTERACTIVE" = true ]; then
	print_file_duplicates_interactively
else
	print_file_duplicates
fi

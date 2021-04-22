#!/usr/bin/env bash

TTY_OUTPUT=false
if [ -t 1 ]; then
	TTY_OUTPUT=true
fi

# basic error printing functions
function print_error() {
	if [ "$TTY_OUTPUT" = true ]; then
		printf "%b" "\e[0;31mError: $1\e[0;0m\n"
	else
		printf "%b" "Error: $1\n"
	fi
}

function print_warning() {
	if [ "$TTY_OUTPUT" = true ]; then
		printf "%b" "\e[0;33mWarning: $1\e[0;0m\n"
	else
		printf "%b" "Warning: $1\n"
	fi
}

function print_debug() {
	if [ "$TTY_OUTPUT" = true ]; then
		printf "%b" "\e[1;33mDebug: $1\e[0;0m\n"
	else
		printf "%b" "Debug: $1\n"
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

	if [ "$TTY_OUTPUT" = true ]; then
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

	if [ "$TTY_OUTPUT" = true ]; then
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

function ask_delete() {
	ARGS=( "$@" )
	print_duplicates_with_numbers "${ARGS[@]}"
	END=false
	while [ "$END" = false ]; do
		END=true

		read -p "Duplicates found. Enter numbers of files to delete (press enter for none) "

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
	echo "     -n         always display file number"
	echo "     -p         display progress bar"
	echo "     -h         display this help"
}

# options:
# -i - remove interactivly
# -h - help

INTERACTIVE=false
SEARCH_DIR="."
HELP=false
PROGRESS_BAR=false

while getopts ":inph" OPTION; do
	case "$OPTION" in
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

if [ "$TTY_OUTPUT" = false ] && [ "$INTERACTIVE" = true ]; then
	print_error "interactive mode is available only when using terminal output"
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
	[ "$TTY_OUTPUT" = true ] && echo
	print_warning "exiting abnormally. Printing found duplicates:"
	[ "$TTY_OUTPUT" = false ] && echo
	print_file_duplicates
	exit 1
}

# Calculating all hashes can take some time, so the user may interrupt the process.
# The script will display already found duplicates in such case.
trap exit_abnormally SIGINT

shopt -s globstar

# it has to be done the same way as main loop
FILES_NUMBER=0

for FILE in "${SEARCH_DIR}"/**/*; do
	# saddly globstar will give directories too
	if ! [[ -f "$FILE" ]]; then
		continue
	fi
	FILES_NUMBER=$((FILES_NUMBER + 1))
done

PROGRESS_ITER=0

function update_progress() {
	if [[ "$PROGRESS_BAR" = false ]]; then
		return 0
	fi

	PROGRESS_RESOLUTION=20

	if [[ -z "$PROGRESS_DISPLAYED" ]]; then
		PROGRESS_DISPLAYED=0
		printf "Progress: "
	fi

	PROGRESS_TO_DRAW=$((PROGRESS_ITER * PROGRESS_RESOLUTION / FILES_NUMBER - PROGRESS_DISPLAYED))
	if [[ "$PROGRESS_TO_DRAW" -gt 0 ]]; then
		for i in $(seq "$PROGRESS_TO_DRAW"); do
			printf "#"
		done

		PROGRESS_DISPLAYED=$((PROGRESS_DISPLAYED + PROGRESS_TO_DRAW))

		if [[ "$PROGRESS_DISPLAYED" -eq "$PROGRESS_RESOLUTION" ]]; then
			printf " done!\n"
		fi
	fi
}

for FILE in "${SEARCH_DIR}"/**/*; do
	# saddly globstar will give directories too
	if ! [[ -f "$FILE" ]]; then
		continue
	fi

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

done

update_progress

# Disable printing all files after ctrl-c
trap - SIGINT

if [ "$INTERACTIVE" = true ]; then
	print_file_duplicates_interactively
else
	print_file_duplicates
fi

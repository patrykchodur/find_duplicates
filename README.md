# find\_duplicates

A simple utility to find duplicated files and optionally delete them.
It uses `sha-1` hashing algorythm to calculate hash of files.

## Requirements

This utility requires `bash` version 4 or higher and uses the following commands:

- `awk`
- `shasum` or `openssl`

The presence of required commands is checked at the beginning of the script, so if
any command is not available an error message is displayed.

## Usage

The program can run in two modes:

- regular - only printing duplicated files.
- interactive (`-i`) - user can specify whether to delete duplicated files or not.

A help message is displayed after using `-h` option.

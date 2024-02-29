#!/usr/bin/bash

# XTF - script for preprocessing logs from cryptocurrency exchange.
# First IOS project with premium functionality.
# Author: Ondřej Vomáčka (xvomaco00)

function print_help() {
	echo "PROGRAM"
	echo "	xtf - script for preprocessing logs from your cryptocurrency exchange."
	echo
	echo "USAGE"
	echo "	$0 [-h|--help] [FILTER] [COMMAND] USER LOG [LOG2] [...]"
	echo
	echo "OPTIONS"
	echo "	A COMMAND can be one of the following:"
	echo "		list – listing of records for the user."
  echo "		list-currency – listing of sorted list of occurring currencies."
  echo "		status – statement of actual account balances grouped and sorted by currency."
  echo "		profit – the customer's account statement with the fictitious return included."
	echo
	echo "	FILTER can be a combination of the following:"
	echo "		-a DATETIME – after: only records AFTER this date and time (without it) are considered."
	echo "			DATETIME is of format YYYY-MM-DD HH:MM:SS."
  echo "		-b DATETIME – before: only records BEFORE this date and time (without it) are considered."
  echo "			DATETIME is of format YYYY-MM-DD HH:MM:SS."
  echo "		-c CURRENCY – only records corresponding to a given currency are considered."
	echo
	echo "	-h and --help displays help with a short description of each command and option."
	echo
}

function print_error() {
	>&2 echo "$1"
}

# CONSTANTS

LIST_MODE=0
STATUS_MODE=1
PROFIT_MODE=2
LIST_CURRENCY_MODE=3

# VARIABLES

user=""
after=""
before=""
logFiles=()
currencies=()
mode=$LIST_MODE

# PARSE ARGUMENTS

for (( i=1; i<=$#; i++ )); do
	if [[ ${!i} = "-h" ]] || [[ ${!i} = "--help" ]]; then
		print_help
		exit 0
	elif [[ ${!i} == "list" ]]; then mode=$LIST_MODE
	elif [[ ${!i} == "list-currency" ]]; then mode=$LIST_CURRENCY_MODE
	elif [[ ${!i} == "status" ]]; then mode=$STATUS_MODE
	elif [[ ${!i} == "profit" ]]; then mode=$PROFIT_MODE
	elif [[ ${!i} == *".log"* ]] || [[ ${!i} == *".gz"* ]]; then logFiles+=("${!i}")
	elif [[ ${!i} == "-a" ]]; then
    i=$((i+1))
    after=${!i}
  elif [[ ${!i} == "-b" ]]; then
    i=$((i+1))
    before=${!i}
  elif [[ ${!i} == "-c" ]]; then
    i=$((i+1))
    currencies+=("${!i}")
	else
	  if [[ $user == "" ]]; then user=${!i}
	  else
	    print_error "ERROR: invalid $i. argument \"${!i}\"."
		  exit 1
	  fi
	fi
done

# VALIDATE ARGUMENTS

# Check if required arguments were provided
if [[ $# -lt 2 ]] || [[ $user == "" ]] || [[ ${#logFiles[@]} == 0 ]]; then
	print_error "ERROR: required arguments were not provided."
	print_error "Run \"$0 --help\" to show correct usage."
	exit 1
fi

# Check if log files exist and are readable
for file in "${logFiles[@]}"
do
  if [[ ! -f $file ]] || [[ ! -r $file ]]; then
    print_error "ERROR: file \"$file\" does not exist or is not readable."
    exit 1
  fi
done

# Check if after filter is valid date
dateFormat="+%Y-%m-%d %T"

date "$dateFormat" -d "$after" > /dev/null  2>&1
isDateInvalid=$?

if [[ $after != "" ]] && [[ $isDateInvalid == 1 ]]; then
  print_error "ERROR: invalid date format for after filter \"$after\"."
  exit 1
fi

# Check if before filter is valid date
date "$dateFormat" -d "$before" > /dev/null  2>&1
isDateInvalid=$?

if [[ $before != "" ]] && [[ $isDateInvalid == 1 ]]; then
  print_error "ERROR: invalid date format for before filter \"$before\"."
  exit 1
fi

# BUILD COMMAND

command=(zcat -f "${logFiles[@]}")

command+=("| grep \"^$user;\"")

if [[ ${#currencies[@]} != 0 ]]; then
  expression=""
  for currency in "${currencies[@]}"; do expression+="\;$currency;|"; done
  command+=("| grep -E \"$expression\"")
fi

if [[ $mode -ne $LIST_MODE ]]; then
  command+=("| sort -t \";\" -k 3")
fi

echo "${command[*]}"

logFormat="^.+;[0-9]{4}-[0-1][0-9]-[0-3][0-9] [0-2][0-9]:[0-5][0-9]:[0-5][0-9];.+;\-?[0-9]+\.?[0-9]*$"

while IFS= read -r line
do
  IFS=";"
  entry=()
  for i in $line; do entry+=("$i") ; done

  date "$dateFormat" -d "${entry[1]}" > /dev/null  2>&1
  isDateInvalid=$?

  if [[ ! $line =~ $logFormat ]] || [[ $isDateInvalid == 1 ]]; then
    print_error "ERROR: invalid data found: \"$line\"."
    exit 1
  fi
  echo "$line"
done < <(eval "${command[*]}")

exit 0

# Debug print
echo "Mode: $mode"
echo "User: $user"
echo "After: $after"
echo "Before: $before"

echo "Currencies:"
for currency in "${currencies[@]}"
do
	echo "	$currency"
done

echo "Log files:"
for str in "${logFiles[@]}"
do
	echo "	$str"
done

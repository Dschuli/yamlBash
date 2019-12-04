#!/bin/bash
#
# Bash script to replace a value of a key:value pair in a yaml file while 
# keeping original structure and comments.
#
# (Nested) Key elements should separated by ":", e.g. Key0:Key1:Key2.
# Key elements are treated as regex, so can e.g. be specified like "St.*". This will pick up any
#	key starting with "St" and might lead to more than one line being altered. 
#
# Currently only supports simple mappings/dictionaries, as e.g.
#	
# Key0:
#	Key1:
#   Key2:	xxxx
#		Key3:	to be replaced
#		Key4:
# Key5:
#
# and allows to e.g. replace/insert a value for Key3. Key parameter would be Key1:Key3.
# Current settings/restrictions:
# - Other forms of YAML structures and notations (e.g. lists, block or flow style), are not supported.
# - Value has to be a simple scalar or string  
# - Inserted values are not put into " or ', therefore no multiline strings
# - If the target key has sub-keys/nestings, those will not be altered 

set -euo pipefail									# inofficial strict mode -e options fails unexplicably (for me) at line 120
IFS=$'\n\t'

function msg() {
	echo "$@" 1>&2
}

function showHelp() {														# Help function
	msg "Help for ymf.sh:"
	msg "  Function: Replace value for a (nested) key identified by the 'key' parameter in a yaml file"
	msg "            while keeping structure and comments.
	msg
	msg "  (Required) Parameters are:"
	msg "     -k / --key		      Key name to be altered as above in the format Level0:Level1:Level2 ...."
	msg "     -v / --value        (New) value for the key"
	msg	"     -f / --file         File with the (new) value for the key" 
	msg "                         -v or -f have to be provided. -v takes precedence over -f"
	msg 
	msg "     -h / -- help / ?    Help"
	exit 0
}

keyValue=""														# Defaults
keyFile=""

# ***** Start of parameter processing *****************************************

if [ $# -eq 0 ]; then
	showHelp
fi

while [[ $# -gt 0 ]]; do

	key="$1"

		case $key in

			-k | --key)
				keyName="$2"
				shift # past argument
				shift # past value
			;;

			-v | --value)
				keyValue="$2"
				shift # past argument
				shift # past value
			;;

			-f | --file)
				keyFile="$2"
				shift # past argument
				shift # past value
			;;

			-h | --help | ?)
				showHelp	
			;;

			*)
				echo "Invalid option $key. Use -h / --help / ? for more information." 1>&2
				exit 0
			;;

		esac

	done

# ***** End of parameter processing *******************************************

IFS=':' read -ra keyLevels <<< "$keyName"

for x in "${keyLevels[@]}"; do
  if [ -z "$x" ]; then
		msg "Parts of the key parameter should not be empty.  See -h / --help for more information."
		exit 100
	fi
done


if [ -z "$keyValue" ] && [ -z "$keyFile" ]; then
	msg "You need to provide either a -v or a -f parameter. See -h / --help for more information."
	exit 100
fi

if [[ -n $keyValue ]]; then 
	hash=$keyValue
else
	if [ ! -f "$keyFile" ]; then											#Check that property file is valid
		echo msg "File with (new) value <$keyFile> does not exist."
		exit 100
	fi
	read -r hash < "$keyFile"
fi		

chgCount=0														#Counter/flag of changes made
level=0 															#Starting level
levelIndent=()

regexpLB="^\s*"												#Regex for leading blanks
lastLevel=$(( ${#keyLevels[@]}-1 ))		#Number of nesting levels in key

for i in "${!keyLevels[@]}"; do
  levelIndent+=(0)
	active+=(0)
done

levelIndent[0]=0

mapfile -t lines 													#Read input into array  										

for i in "${!lines[@]}"; do									#Process array via iterator

	line=${lines[i]}												#Get current line
	
	line2=${line%%#*}												#Remove comments

	[[ -z "${line2// }" ]] && continue			#Ignore empty/pure comment lines 

	[[ "$line2" =~ $regexpLB ]]							#Get indent of line
	ind=${#BASH_REMATCH}

	if [ $ind -lt ${levelIndent[$level]} ];then					             # Indent is smaller - so decrease level
		until [ "$level" -le 0 ]; do
			level=$(( level-1 ))
			[ $ind -ge ${levelIndent[$level]} ] && break                  # until new level found 
		done 
	fi

identRegex="^\s{"${levelIndent[$level]}}${keyLevels[$level]}":"

	if [[ "$line2" =~ $identRegex ]]; then
		if [ $level -eq $lastLevel ]; then			      									# Found the last key level
			if [[ "$line" =~ "#" ]]; then																	# Line contains a comment
				comment=${line#*#}																					# Get comment
				before=${line%#*}																						# Get free space before comment in input
				before=${before#*:}
				remainder=$((${#before}-${#hash}-1))
				if [ $remainder -le 0 ]; then																# Not enough space to acco0modate new property value
					hash="$hash #$comment"																		# add comment at end
				else
					hash="$hash$(printf "%*s" $remainder " ")#$comment"				# insert comment into free space
				fi
			fi
			key="${line2%%:*}"
			#indent=$(printf "%*s" "$ind" "")															# Create spaces for indenting 
			lines[i]="$key: ${hash}"			  				# Change line
			(( chgCount+=1 ))

			# ?? delete all remaining lines in block?

		else																					# Else increase level
			[[ $((i+1)) -eq ${#lines[@]} ]] && break			  # Unless its the last line
			(( level+=1 ))														  # Increase level #
			[[ "${lines[ (( i+1 )) ]}" =~ $regexpLB ]]	#	Get indent of next line as indent for the new level
			levelIndent[$level]=${#BASH_REMATCH}
		fi
	fi

done

echo "${lines[*]}"

msg "$chgCount line(s) of input was/were changed."


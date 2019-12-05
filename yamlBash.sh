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
# - Other forms of YAML structures and notations (e.g. lists, block or flow style) will not be changed, 
#   but left as-is.
# - Value has to be a simple scalar or string  
# - Inserted values are not put into " or ', therefore no multiline strings. Any apostrophes in the value parameter
#   will be applied as-is.
# - If the target key has sub-keys/nestings (additional lines with higher indent), those will be replaced
#   by the provided value parameter, leading to lines that will get deleted. 
#   Only comments on the same line a the key will be retained
# Todos:
# - If the provided value has a comment, it will replace any original comment.
# - When using a file as value parameter, it can contain a structure to be used as value of the key to be altered.
# 	In this case it can contain multiple lines (including comments), that will get added to the yaml file.
#   The indention of the lines will be normalized, where the first line indention is normaized to 0. In the target 
#   yaml file those lines lines will get indented at the key line level + 1 standard indention (derived from the 
#   first indention in the target file with a default of 2 spaces). Additional indention will be kept as in the value file.  

set -euo pipefail									# inofficial strict mode -e options fails unexplicably (for me) at line 120
IFS=$'\n\t'

traceLevel=0

function msg() {
	echo "$@" 1>&2
}

function trace() {
	if [ $traceLevel -eq 1 ]; then
		echo "$@" 1>&2
	fi 
}

function showHelp() {														# Help function
	msg "Help for ymf.sh:"
	msg "  Function: Replace value for a (nested) key identified by the 'key' parameter in a yaml file"
	msg "            while keeping structure and comments."
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
delCount=0														#Counter of deleted lines
addCount=0														#Counter of added lines
level=0 															#Starting level
levelIndent=()

regexpLB="^\s*"												#Regex for leading blanks
lastLevel=$(( ${#keyLevels[@]}-1 ))		#Number of nesting levels in key

for i in "${!keyLevels[@]}"; do
  levelIndent+=(0)
done

levelIndent+=(0)											#Add one level for a block after a change

mapfile -t lines 													#Read input into array  										

for i in "${!lines[@]}"; do								#Process array via iterator

	line=${lines[i]}												#Get current line
	
	line2=${line%%#*}												#Remove comments

	if [[ -z "${line2// }" ]]; then   			#Ignore empty/pure comment lines
		echo "$line"
		continue
	fi

	[[ "$line2" =~ $regexpLB ]]							#Get indent of line
	ind=${#BASH_REMATCH}

	if [ $ind -lt ${levelIndent[$level]} ];then					              # Indent is smaller - so decrease level
		until [ "$level" -le 0 ]; do
			level=$(( level-1 ))
			[ $ind -ge ${levelIndent[$level]} ] && break                  # until new level found 
		done 
	trace Decrease to level: $level Indent: ${levelIndent[$level]} Line: "$line2" 
	fi

if  [ $level -gt $lastLevel ]; then																	# if level is beyond last level - delete the line		
	trace Delete line: $level Indent: ${levelIndent[$level]} Line: "$line2"
	(( delCount+=1 ))
	continue															
fi 	 

	identRegex="^\s{"${levelIndent[$level]}}${keyLevels[$level]}":"

	if [[ "$line2" =~ $identRegex ]]; then
		trace "Hit at: $level Indent: ${levelIndent[$level]} Line: $line2" 
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
			echo "$key: ${hash}"																  				# Change line
			(( chgCount+=1 ))

		else																					
			echo "$line"
		fi
		[[ $((i+1)) -eq ${#lines[@]} ]] && break	  										# Unless its the last line
		[[ "${lines[ (( i+1 )) ]}" =~ $regexpLB ]]											#	Get indent of next line
		nextIndent=${#BASH_REMATCH}
		trace Check level: $level Level indent: ${levelIndent[$level]} nextIndent: $nextIndent nextLine: "${lines[ (( i+1 )) ]}"
		if [ $nextIndent -gt ${levelIndent[$level]} ]; then 						# If indent of next line is gt then current indent
			(( level+=1 ))																								# Increase level #, level gt then provided indicates that line should get deleted
			levelIndent[$level]=$nextIndent																# Store indent of the next level
			trace Increase level to : $level Indent: ${levelIndent[$level]} Line: "$line2" 
		fi
	else
		echo "$line"
		trace Just copy: $level Indent: ${levelIndent[$level]} Line: "$line2" 
	fi

done
msg "Done: Count of lines replaced/deleted/added: $chgCount/$delCount/$addCount"


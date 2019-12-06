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
# and allows to e.g. replace/insert a value for Key3. Key parameter would be Key1:Key2:Key3.
#
# Current settings/restrictions:
# - If the target key has sub-keys/maps (additional lines with higher indent), those will be replaced
#   by the provided value parameter, leading to lines that will get deleted. 
#   Only comments on the same line a the key will be retained
# - A key value provided by the -v parameter has to be a simple scalar or string and will get applied without. 
#   any transformation, e.g. required apostrophes etc have to be part of the provided value parameter.
# - When using the -f / --file parameter, the following applies:
#   - If the file contains a single line (trailing blank lines are ignored), the content of that line 
#     will be handeled like a -v parameter.
# 	- If the file has more than one line, the content will be treated as sub-mapping and the corresponding lines 
#     will get inserted as-is (including comments) after the target key, replacing any value/sub-mapping in the 
#     original yaml file. Indention of those new lines is adjusted to fit into the original structure as below:
#       Any (starting; line 1) indent in the value file will be removed and replaced by the next level of indent
#       of the target key. This additional indent will be detected in the original file. If nothing can be detected,
#       a default indent (set in the script; usually 2 spaces) will be used.   
# - Other forms of YAML structures and notations (e.g. lists, block or flow style) will not be changed, 
#   but left as-is.
# - No support for multi-line strings. 
# Todos:
# - When using a file as value parameter, it can contain a structure to be used as value of the key to be altered.
# 	In this case it contains multiple lines (including comments), that will get added to the yaml file.
#   The indention of the lines will be normalized, where the first line indention is normalized to 0. In the target 
#   yaml file those lines lines will get indented at the key line level + 1 standard indention (derived from the 
#   first indention in the target file with a default of 2 spaces). Additional indention will be kept as in the value file.  

set -euo pipefail
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
	msg "   Optional:"
	msg "     -c / --check        File(s) will be checked against the use of tab characters (YAML uses spaces) "
	msg "     -h / --help / ?     Help"      
	exit 0
}

keyValue=""														# Defaults
keyFile=""
checkTabs=0

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

			-c | --check)
				checkTabs=1
				shift # past argument
			;;


			-h | --help | ?)
				shift # past argument
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
	newValue[0]=$keyValue
else
	if [ ! -f "$keyFile" ]; then											#Check that property file is valid
		echo msg "File with (new) value <$keyFile> does not exist."
		exit 100
	fi
	mapfile -t newValue < <(sed -e :a -e '/^\n*$/{$d;N;};/\n$/ba' $keyFile) #Read file into arry with removed trailing blank lines
fi	

chgCount=0														#Counter of changed lines
delCount=0														#Counter of deleted lines
addCount=0														#Counter of added lines
level=0 															#Starting level
fileIndentSetting=0										#First non-zero indent will determine standard setting
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

if [[ "$line" =~ \t ]] && [[ $checkTabs -gt 0 ]]; then
	msg "Warning: line $(( $i+1 )) of the input contains tab characters. YAML files should only use spaces"
fi
	
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

			if [ ${#newValue[@]} -gt 1 ]; then 														# A block will get inserted - so key has to stand alone
				val=""
			else
				val=${newValue[0]}
			fi	
			
			if [[ "$line" =~ "#" ]] && [[ ! "$val" =~ "#" ]] ; then				# Line contains a comment - new value does not
				comment=${line#*#}																					# Get comment
				before=${line%#*}																						# Get free space before comment in input
				before=${before#*:}
				remainder=$((${#before}-${#val}-1))
				if [ $remainder -le 0 ]; then																# Not enough space to accomodate new value
					val="$val #$comment"																			# add comment directly after value
				else
					val="$val$(printf "%*s" $remainder " ")#$comment"					# insert comment into free space
				fi
			fi

			key="${line2%%:*}"
			echo "$key: $val"																					  	# write key:value line	
			(( chgCount+=1 ))																							# increase change counter

			if [ ${#newValue[@]} -gt 1 ]; then 													  # Add block lines
				[[ ${newValue[0]} =~ $regexpLB ]]														# Get indent of first line - will get removed from every line
				oldIndent=${#BASH_REMATCH}
				newIndent=$(printf "%*s" "$(( $ind+$fileIndentSetting ))" "")	# Create spaces for initial indent - current + 1 * standard
				vl=0
				for blockLine in "${newValue[@]}"; do												# Process all lines in newValue
					(( vl+=1 ))
					if [[ "$blockLine" =~ \t ]] && [[ $checkTabs -gt 0 ]]; then		# Check for tabs
						msg "Warning: Value file contains tab characters (Line $vl). YAML files should only use spaces"
					fi
					echo "$newIndent${blockLine:oldIndent}"										# Write blockline
					(( addCount+=1 ))
				done
			fi

		else																					
			echo "$line"
		fi
		
		# Handle level increase for each hit  
		[[ $((i+1)) -eq ${#lines[@]} ]] && break	  										# Unless its the last line
		[[ "${lines[ (( i+1 )) ]}" =~ $regexpLB ]]											#	Get indent of next line
		nextIndent=${#BASH_REMATCH}
		trace Check level: $level Level indent: ${levelIndent[$level]} nextIndent: $nextIndent nextLine: "${lines[ (( i+1 )) ]}"
		
		if [ $nextIndent -gt ${levelIndent[$level]} ]; then 						# If indent of next line is gt then current indent
			(( level+=1 ))																								# Increase level #, level gt then provided indicates that line should get deleted
			levelIndent[$level]=$nextIndent																# Store indent of the next level
			[ $fileIndentSetting -eq 0 ] && fileIndentSetting=$ind		  	# Set file standard level indent on first level increase
			trace Increase level to : $level Indent: ${levelIndent[$level]} Line: "$line2" 
		fi

	else
		echo "$line"
		trace Just copy: $level Indent: ${levelIndent[$level]} Line: "$line2" 
	fi

done
msg "Done: Count of lines replaced/deleted/added: $chgCount/$delCount/$addCount"

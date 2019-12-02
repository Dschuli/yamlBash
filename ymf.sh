#!/bin/bash
# *********** Improvement ideas
# ******* Optional parms for image and digest
# ******* Property nesting level flexibility - change will always affect the lowest level
#
# Bash script to replace a property in a yaml file while keeping all comments
# Currently its set to replace the 'digest' property in a block for a
# property passed as parameter within an 'image' property block
#

set -euo pipefail									# inofficial strict mode -e options fails unexplicably (for me) at line 120
IFS=$'\n\t'

function msg() {
	echo "$@" 1>&2
}

function showHelp() {														# Help function
	msg "Help for ymf.sh:"
	msg "  Function: Replace value for a property identified by the property parameter in a yaml file while keeping structure and comments. Property is currently hardcoded to be at Level 3 (sub-sub-property)"
	msg
	msg "  (Required) Parameters are:"
	msg "     -p / --property     Name of property to change as above in the format Level1:Level2:Level3"
	msg "     -v / --value        (New) value of property"
	msg	"     -f / --file         File with the (new) value of property" 
	msg "                         -v or -f have to be provided. -v takes precedence over -f"
	msg 
	msg "     -h / -- help / ?    Help"
	exit 0
}

propertyValue=""														# Defaults
propertyFile=""

# ***** Start of parameter processing *****************************************

if [ $# -eq 0 ]; then
	showHelp
fi

while [[ $# -gt 0 ]]; do

	key="$1"

		case $key in

			-p | --property)
				property="$2"
				shift # past argument
				shift # past value
			;;

			-v | --value)
				propertyValue="$2"
				shift # past argument
				shift # past value
			;;

			-f | --file)
				propertyFile="$2"
				shift # past argument
				shift # past value
			;;

			-h | --help | ?)
				showHelp	
			;;

			*)
				echo "Invalid option. Use -h / --help / ? for more information." 1>&2
				exit 0
			;;

		esac

	done

# ***** End of parameter processing *******************************************

IFS=':' read -ra propLevels <<< "$property"

if [[ ${#propLevels[@]} -ne 3 ]]; then
	msg "You need to provide 3 levels as property name.  See -h / --help for more information."
	exit 100
fi

for x in "${propLevels[@]}";do
	if [[ -z  "$x" ]]; then
		msg "Property levels should not be empty. See -h / --help for more information."
		exit 100
	fi
done

L1identifier="${propLevels[0]}"
L2identifier="${propLevels[1]}"
L3identifier="${propLevels[2]}"

if [ -z "$propertyValue" ] && [ -z "$propertyFile" ]; then
	msg "You need to provide either a -v or a -f parameter. See -h / --help for more information."
	exit 100
fi

if [[ -n $propertyValue ]]; then 
	hash=$propertyValue
else
	if [ ! -f "$propertyFile" ]; then											#Check that property file is valid
		echo msg "File with property value <$propertyFile> does not exist."
		exit 100
	fi
	read -r hash < "$propertyFile"
fi		

L1Indent=-1													# > -1 ... in such a block, else not
L2Indent=-1

regexp="^\s*"												#Regex for leading blanks

chgCount=0

while IFS= read -r line; do
	
	line2=${line%%#*}													# Remove comments

	if [[ -z "${line2// }" ]]; then						# Empty/pure comment lines - just echo to stdout
		echo "$line"
		continue
	fi
	
	[[ "$line2" =~ $regexp ]]									#Get line indent
	ind=${#BASH_REMATCH}

	if [ $L1Indent -ge 0 ]  && [ $L1Indent -eq "$ind" ]; then				  	# Close L1 block (and all lower L blocks) if indent is at block start
		L1Indent=-1
		L2Indent=-1
	fi

	if [ $L1Indent -eq -1 ]; then 																			# L1 block not open
		
		echo "$line"
		if [[ "$line2" =~ ^"${L1identifier}": ]]; then		 								# Open L1 block if line starts with the indentifier
			L1Indent=$ind
		fi

	else																																# L1 block open

		if [ $L2Indent -ge 0 ]  && [ $L2Indent -eq "$ind" ] ; then					#	Close L2 block if indent is at block start
			L2Indent=-1
		fi

		if [ $L2Indent -eq -1 ]; then 																		# L2 block is not open

			echo "$line"
			if [[ $line2 =~ \s*"${L2identifier}": ]]; then									# Open L2 block if line (trimmed) starts with the indentifier
				L2Indent=$ind
			fi

		else

			if [[ $line2 =~ \s*"${L3identifier}": ]]; then 									# Find line that starts (trimmed) with L3 identifier																		# Line contains a comment
				
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

				indent=$(printf "%*s" "$ind" "")																# Create spaces for indenting 

				echo "$indent""$L3identifier": "$hash"													# Write changed line
				chgCount+=1
			else
				echo "$line"
			fi

		fi

	fi

done

if [ $chgCount -gt 0 ]; then
	msg "Output was created successfully."
else
	msg "Output was created, but without any changes from input file."
fi

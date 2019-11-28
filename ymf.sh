#!/bin/bash
# *********** Improvement ideas
# ******* add potential commnet to altered line
# ******* non file property value option (string)
# ******* check if/how stdin could replace infile
# ******* Optional parms for image and digest
# ******* Property nesting L flexibility - change will always affect the lowest L
#
# Bash script to replace a property in a yaml file while keeping all comments
# Currently its set to replace the 'digest' property in a block for a
# property passed as parameter within an 'image' property block
#
# Parameter (positional):
#	1 .... input file
# 2 .... parent property name
# 3 .... (new) property value - passed as file
# 4 .... output file (has to be different from input file)

# set -euo pipefail
IFS=$'\n\t'

function msg() {
	echo "$@" 1>&2
}

function showHelp() {														# Help function
	msg "Help for ymf.sh:"
	msg "  Function: Replace value for property $L1identifier:propertyName:$L3identifier in a yaml file while keeping structure and comments."
	msg
	msg "  Required Parameters are:"
	msg "     -i / --input        Input file name"
	msg "     -p / --property     Name of property to change as above"
	msg "     -v / --value        Value of above property"
	msg "      or"
	msg "     -h / -- help / ?    Help"
	exit -1
}


L1identifier=image														# non parameter level identifiers
L3identifier=digest

# ***** Start of parameter processing *****************************************

if [ $# -eq 0 ]; then
	showHelp
fi

while [[ $# -gt 0 ]]; do

	key="$1"

		case $key in

			-i | --input)
				inputFile="$2"
				shift # past argument
				shift # past value
			;;

			-p | --property)
				L2identifier="$2"
				shift # past argument
				shift # past value
			;;

			-v | --value)
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

if [ ! -f $inputFile ]; then												#Check that inputfile is valid
	msg "Input file <$inputFile> not found."
	exit -1
fi

if [ ! -f $propertyFile ]; then											#Check that property file is valid
	echo msg "File with property value <$propertyFile> does not exist."
	exit -1
fi	

L1Indent=-1													# > -1 ... in such a block, else not
L2Indent=-1

chgCount=0

while IFS= read -r line; do
	
	line2=${line%%#*}													# Remove comments

	if [[ -z "${line2// }" ]]; then						# Empty/pure comment lines - just echo to stdout
		echo "$line"
		continue
	fi

	ind=`expr match "$line2" '^\s*'`								    								# Get indent of line

	if [ $L1Indent -ge 0 ]  && [ $L1Indent -eq $ind ]; then							# Close L1 block (and all lower L blocks) if indent is at block start
		L1Indent=-1
		L2Indent=-1
	fi

	if [ $L1Indent -eq -1 ]; then 																			# L1 block not open
		
		echo "$line"
		if [[ "$line2" =~ ^"${L1identifier}": ]]; then		 								# Open L1 block if line starts with the indentifier
			L1Indent=$ind
		fi

	else																																# L1 block open

		if [ $L2Indent -ge 0 ]  && [ $L2Indent -eq $ind ] ; then					#	Close L2 block if indent is at block start
			L2Indent=-1
		fi

		if [ $L2Indent -eq -1 ]; then 																		# L2 block is not open

			echo "$line"
			if [[ $line2 =~ \s*"${L2identifier}": ]]; then									# Open L2 block if line (trimmed) starts with the indentifier
				L2Indent=$ind
				read -r hash < $propertyFile
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

				indent=$(printf "%*s" $ind "")																# Create spaces for indenting 

				echo "$indent""$L3identifier": $hash													# Write changed line
				chgCount+=1
			else
				echo "$line"
			fi

		fi

	fi

done < $inputFile

if [ $chgCount -gt 0 ]; then
	msg "Output was created successfully."
else
	msg "Output was created, but without any changes from input file."
fi

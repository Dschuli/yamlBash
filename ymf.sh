#!/bin/bash
# *********** Improvement ideas
# ******* add potential commnet to altered line
# ******* non file property value option (string)
# ******* check if/how stin/stdout could replace in/outfile
# ******* Optional parms for image and digest
# ******* Property nesting level flexibility - change will always affect the lowest level
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

function showHelp() {
	echo Help for ymf.sh:
	echo "  "Function: Replace value for property $level1identifier:propertyName:$level3identifier in a yaml file while	keeping structure and comments
	echo
	echo "  "Required Parameters are:
	echo "  "-i / --input			Input file name
	echo "  "-o / --output		Output file name
	echo "  "-p / --property	Name of property to change as above
	echo "  "-v / --value			Value of above property
	echo "  " or
	echo "  "-h / -- help / ?	Help	
	exit -1
}


level1identifier=image
level2identifier=$2
level3identifier=digest

POSITIONAL=()

if [ $# -eq 0 ]; then
	showHelp
fi

while [[ $# -gt 0 ]]
	do
		key="$1"

		case $key in

				-i | --input)
					inputFile="$2"
					shift # past argument
					shift # past value
				;;

				-o | --output)
					outputFile="$2"
					shift # past argument
					shift # past value
				;;

				-p | --property)
					level2identifier="$2"
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
					echo Invalid option. Use -h / --help / ? for more information.
					exit 0
				;;
	
#				*)    # unknown option
#					POSITIONAL+=("$1") # save it in an array for later
#					shift # past argument
#				;;

		esac
	done

# set -- "${POSITIONAL[@]}" # restore positional parameters

# level1identifier=image
# level2identifier=$2
# level3identifier=digest

# inputFile=$1
# propertyFile=$3
# outputFile=$4

if [ ! -f $inputFile ]; then											#Check that inputfile is valid
	echo "Input file <$inputFile> not found."
	exit -1
fi

outDirName=$(dirname "${outputFile}")

if [ ! -d $outDirName ]; then											#Check that inputfile is valid
	echo "Path for <$outputFile> seems to be invalid."
	exit -1
fi

if [ ! -f $propertyFile ]; then											#Check that output file is valid
	echo "File with property value <$propertyFile> does not exist."
	exit -1
fi	

imgIndent=-1												# > -1 ... in such a block, else out
tagIndent=-1
declare -i chgCount=0

> $outputFile																#Clear updated file

while IFS= read -r line; do
	
	echo "$line" >> $outputFile			#Write to updated file

	line2=${line%%#*}								#Remove comments

	if [[ -z "${line2// }" ]] 			#Do not process empty/pure comment lines
		then continue
	fi


	ind=$(echo "$line2" | sed "s: : \n:g" | grep -c ^" ")    				#Get indent of line

	if [ $imgIndent -ge 0 ]  && [ $imgIndent -eq $ind ]; then				#close img and tag block
		imgIndent=-1
		tagIndent=-1
		#echo "******Image Off:" "$line2" $imgIndent
	fi

	if [ $imgIndent -eq -1 ] 						#is not in img block
		then

		if [[ "$line2" =~ ^"${level1identifier}": ]]; then		 		#No - then open block if line starts with the indentifier
			imgIndent=$ind
			#echo "******Image On:" "$line2" $imgIndent
		fi

	else																												#We are in a level 1 block
		if [ $tagIndent -ge 0 ]  && [ $tagIndent -eq $ind ] 			#close tag block
			then
				tagIndent=-1
				#echo "******Tag Off:" "$line2" $imgIndent
		fi

		if [ $tagIndent -eq -1 ] 						#is not in tag block
			then

			if [[ $line2 =~ "$2": ]] 		#No - then open tag block if line contains starts with tag identifier
				then 
				tagIndent=$ind
				read -r hash < $propertyFile
				#echo "******Tag On:" "$line2" $tagIndent
			fi

		else
			if [[ $line2 =~ ${level3identifier}: ]] 								#look for target line
				then 
				#echo "******Target found for:"  $hashFile "$line2"
				sed -i '$ d' $outputFile																				#Remove last line in updated file
				lead=$(printf "%*s" $ind "")
				echo "$lead""$level3identifier": $hash >> $outputFile					#and write the updated content
				chgCount+=1

			fi

		fi

	fi

done < $inputFile

if [ $chgCount -gt 0 ]; then
	echo "Updated file <$outputFile> was created successfully."
else
	echo "File <$outputFile> was created, but without any changes from input file."
fi

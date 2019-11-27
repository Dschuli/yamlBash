#!/bin/bash
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

level1identifier=image
level2identifier=$2
level3identifier=digest

hash=

imgIndent=-1												# > -1 ... in such a block, else out
tagIndent=-1

> $4																#Clear updated file

while IFS= read -r line; do
	
	echo "$line" >> $4			#Write to updated file

	line2=${line%%#*}								#Remove comments

	if [[ -z "${line2// }" ]] 			#Do not process empty/pure comment lines
		then continue
	fi


	ind=$(echo "$line2" | sed "s: : \n:g" | grep -c ^" ")    #Get indent of line

	if [ $imgIndent -ge 0 ]  && [ $imgIndent -eq $ind ] 				#close img and tag block
		then
			imgIndent=-1
			tagIndent=-1
			#echo "******Image Off:" "$line2" $imgIndent
	fi

	if [ $imgIndent -eq -1 ] 						#is not in img block
		then

		if [[ "$line2" =~ ^"${level1identifier}": ]] 		#No - then open img block if line starts with "image:"
			then 
			imgIndent=$ind
			#echo "******Image On:" "$line2" $imgIndent
		fi

	else																#in img block

		if [ $tagIndent -ge 0 ]  && [ $tagIndent -eq $ind ] 				#close tag block
			then
				tagIndent=-1
				#echo "******Tag Off:" "$line2" $imgIndent
		fi

		if [ $tagIndent -eq -1 ] 						#is not in tag block
			then

			if [[ $line2 =~ "$2": ]] 		#No - then open tag block if line contains starts with tag identifier
				then 
				tagIndent=$ind
				read -r hash < $3
				#echo "******Tag On:" "$line2" $tagIndent
			fi

		else
			if [[ $line2 =~ ${level3identifier}: ]] 								#look for target line
				then 
				#echo "******Target found for:"  $hashFile "$line2"
				sed -i '$ d' $4																				#Remove last line in updated file
				lead=$(printf "%*s" $ind "")
				echo "$lead""$level3identifier": $hash >> $4					#and write the updated content

			fi

		fi

	fi

done < $1

echo "Updated file was created successfully."

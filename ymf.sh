#!/bin/bash
# Test

imgIndent=-1												# > -1 ... in such a block, else out
tagIndent=-1

> updated-chart/production.values.yaml			#Clear updated file

while IFS= read -r line; do
	
	echo "$line" >> updated-chart/production.values.yaml			#Write to updated file

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

		if [[ "$line2" =~ ^image: ]] 		#No - then open img block if line starts with "image:"
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

			if [[ $line2 =~ cumbersell: ]] 		#No - then open tag block if line contains starts with tag identifier
				then 
				tagIndent=$ind
				read -r hash < cumbersell-init-db/digest
				#echo "******Tag On:" "$line2" $tagIndent
			fi

			if [[ $line2 =~ initDb: ]] 		#No - then open tag block if line contains starts with tag identifier
				then 
				tagIndent=$ind
				read -r hash < cumbersell-init-db/digest
				#echo "******Tag On:" "$line2" $tagIndent
			fi
		else
			if [[ $line2 =~ digest: ]] 		#look for target line
				then 
				#echo "******Target found for:"  $hashFile "$line2"
				sed -i '$ d' updated-chart/production.values.yaml												#Remove last line in updated file
				lead=$(printf "%*s" $ind "")
				echo "$lead""digest:" $hash >> updated-chart/production.values.yaml			#and write the updated content

			fi

		fi

	fi

done < production.values.yaml

echo "Updated file was created successfully."

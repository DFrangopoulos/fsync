#!/bin/bash

#Select Source/Target for Versioned Backup

target_dir=/home/dennis/MD5_testzone/
source_dir=/home/dennis/MD5_testzone_source/

#Escape paths for sed use later
target_dir_esc=$(echo $target_dir | sed 's/\//\\\//g')
source_dir_esc=$(echo $source_dir | sed 's/\//\\\//g')

#Verify validity of Source

find $source_dir -type f | sort > source_db
while read line 
do

        check=$( echo "$line" | grep " "| cut -d " " -f1)
       	if [ ! -z $check ]
        then
            	echo $line
                echo "Please follow dir/file naming conventions"
                exit 1 
        fi

done < source_db


#Generate target sorted file list with abs paths and target sorted file list with hash / relative paths
find $target_dir -type f | sort > target_db
> target_h_db
while read line
do
	sha1sum $line | sed "s/$(echo $target_dir_esc)//g" >> target_h_db
	echo "HASHED Target $line"
done < target_db

#Generate source sorted file list with abs paths and source sorted file list with hash / relative paths
#find $source_dir -type f | sort > source_db
> source_h_db
while read line 
do
	sha1sum $line | sed "s/$(echo $source_dir_esc)//g" >> source_h_db
	echo "HASHED Source $line"
done < source_db


echo "HASHING DONE ---- BEGIN COMPARISON"
fail_detect=0;
#START Comparison

while read line
do

	#from source_h_db extract name and hash
	hash=$(echo $line | cut -d " " -f1)
	file=$(echo $line | cut -d " " -f2)

	exists=0
	#for every line in target_h_db
	while read tline
	do
		#compare source_h_db name to target_h_db name (to find the file)
		tline_name=$(echo $tline | cut -d " " -f2)
		#Case : file exists in backup (check version)
		if [ $tline_name == $file ]
		then
			#Update existance
			exists=1

			#if there is a match compare hashes
			tline_hash=$(echo $tline | cut -d " " -f1)
			if [ $hash == $tline_hash ] 
			then
				#if there it matches file already exists in backup
				echo "FOUND $file"
			else
				#file in source if different from backup
				echo "MISMATCH $file"
				#Version in backup should be archived
				#Step 1: Get current time
				timeapp=$(date -u +"_old_%Y_%m_%d_%H_%M_%S")
				#Step 2: Create backup
				mv $(echo "$target_dir$file") $(echo "$target_dir$file$timeapp")
				#Step 3: Check if created
				if [ -e $(echo "$target_dir$file$timeapp") ]
                		then
					#If backup create successfully
                    			echo "CREATED $file$timeapp"
					#Copy over the new version
					cp -p $(echo "$source_dir$file") $(echo "$target_dir$file")
					if [ -e $(echo "$target_dir$file") ]
					then
						#Check Success
						echo "UPDATED $file"
					else
						echo "FAILED $file"
						fail_detect=1
					fi 
					
                		else
					#Notify if failed
                        		echo "FAILED $file$timeapp"
					fail_detect=1
                		fi

			fi
		
			 
		fi


	done < target_h_db
	
	#Case : File does not exist in backup (New file)
	if [ $exists -eq 0 ]
	then
		echo "MISSING $file"
		# File should be craeted

		#Step 1: Create parent directories
		dir_to_c=$(echo "$target_dir$file" | rev | cut -d "/" -f1 --complement | rev) 
		mkdir -p $dir_to_c
		#Step 2: Copy over file
		cp -p $(echo "$source_dir$file") $(echo "$target_dir$file")
		#Step 3: Check that file was copied
		if [ -e $(echo "$target_dir$file") ]
		then
			echo "CREATED $file"
		else
			echo "FAILED $file"
			fail_detect=1
		fi
		#Step4: Done
	fi

done < source_h_db

if [ $fail_detect -ne 0 ]
then
	echo "ERRORS HAVE OCCURED PLEASE READ LOGS"
else
	echo "BACKUP SUCCESSFUL"
fi

exit 0

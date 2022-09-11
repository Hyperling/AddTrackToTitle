#!/bin/bash
# 2022-08-30 Hyperling
# Put the files' Track in their Title so that Toyota Entune plays the songs in the right frikken order!!!
# At least with the 2019 RAV4, it acknowledges the Track#, but still sorts albums alphabetically for whatever reason.
# 
# Return Codes:
#  0) Success!
#  1) Parameter passed
#  2) Pre-requisite tool not installed
#  3) Failure to find music metadata
#  4) Failure to create fixed file
#  5) Fixed file is missing
#  6) Unknown operator
#


## Variables ##

PROG="`basename $0`"
DIR="`dirname $0`"
EXT=".mp3"
ADD="(Fixed)"
TIME="`which time`"
TRUE="T"
FALSE="F"
UNDO="$FALSE"


## Functions ##

function usage {
	cat <<- EOF
		Usage:
		  $PROG [-h] [-u]
		
		Parameters:
		  -h : Help, display the usage and exit succesfully.
		  -u : Undo, attempt to un-fix files which have had the normal script run against them.
		
		Place this file at the root of your music destined for a flash drive and run it without any parameters.
		It will dive through all folders and convert your MP3's to have the Track# in the Title.
		The process changes the filenames to contain (Fixed) so you know it's touched the file.
		Please be sure you only run this on a copy of your music, not the main source!

		This tool has a few pre-requisites you should make sure you have installed:
		  - exiftool
		  - ffmpeg

		Thanks for using $PROG!
	EOF
	exit $1
}

function error {
	num_chars=$(( 7 + ${#1} ))
	echo ""
	printf '*%.0s' $(seq 1 $num_chars)
	echo -e "\nERROR: $1"
	printf '*%.0s'  $(seq 1 $num_chars)
	echo -e "\n"
	usage $2
}


## Validations ##

# Check for parameters.
while getopts ":hu" opt; do
	case "$opt" in
		h) usage 0 
		;;
		u) UNDO="$TRUE" 
		;;
		*) error "Operator $OPTARG not recognized." 6 
		;;
	esac
done

# Ensure critical tools are available.
if [[ ! `which exiftool` ]]; then
	error "exiftool not found" 2
fi
if [[ ! `which ffmpeg` ]]; then
	error "exiftool not found" 2
fi
if [[ ! `which bc` ]]; then
	error "bc not found" 2
fi
if [[ ! `ls /usr/bin/time` ]]; then
	error "/usr/bin/time not found" 2
fi

# Make sure the user understands they're going to change their music's title.
typeset -l change
read -p "Please acknowledge you are OK with irreversibly modifying your music's metadata. [y/N] " change
if [[ $change != "y" ]]; then
	echo -e "\nThank you for your honesty. Come back when you feel more confident. :)\n"
	usage 0
fi

# Make sure the user has a backup of the music different than the folder they're running this in.
typeset -l backup
read -p 'Please ensure you have a backup. There is no warranty for this program! [y/N] ' backup
if [[ $backup != "y" ]]; then
	echo -e "\nThank you for your honesty. Please backup your music and come back soon. :)\n"
	usage 0
fi

printf 'User has provided permission to alter data.\nMoving forward in 5... '
sleep 1
printf '4... '
sleep 1
printf '3... '
sleep 1
printf '2... '
sleep 1
printf '1... \n'
sleep 1


## Main ##

# Loop through all files in and lower than the current directory.
count=0
total="`find $DIR -name "*${EXT}" -printf . | wc -c`"
avg_time=0
total_time=0
time_count=0
est_guess=0
time find $DIR -name "*${EXT}" | while read file; do
	count=$(( count + 1 ))
	
	echo -e "\n$file"

	# Skip file if it's already correct.
	if [[ "$UNDO" == "$FALSE" && "$file" == *"$ADD"* ]]; then
		echo "Already fixed, skipping."
		continue
	elif [[ "$UNDO" == "$TRUE" && "$file" != *"$ADD"* ]]; then
		echo "Already unfixed, skipping."
		continue
	fi

	# Retrieve and clean the Track#
	track=""
	# Get raw value
	track="`exiftool -Track "$file"`" 
	# Filter the header
	track="${track//Track   /}"
	track="${track//   : /}"
	# Remove disk designations
	track="${track%%/*}"
	# Remove any whitespace before/after
	track="`echo $track`"
	# Add a leading 0 to single digits.
	[[ ${#track} == 1 ]] && track="0$track"
	echo "Track=$track"

	# Retrieve and clean the Title
	title=""
	title="`exiftool -Title "$file"`"
	title="${title//Title   /}"
	title="${title//   : /}"
	title="`echo $title`"
	echo "Title=$title"
	
	# Skip file if title is already changed.
	if [[ "$UNDO" == "$FALSE" && "$title" == "$track"* ]]; then
		echo "Title already contains Track, skipping."
		continue
	elif [[ "$UNDO" == "$TRUE" && "$title" != "$track"* ]]; then
		echo "Title already missing Track, skipping."
		continue
	fi

	# Create the new file with the correct Title
	new_title=""
	new_file=""
	if [[ "$UNDO" == "$FALSE" ]]; then
		new_title="${track}. ${title}"
		new_file="${file//$EXT/$ADD$EXT}"
	else
		new_title="${title/${track}. }"
		new_file="${file//$ADD/}"
	fi
	if [[ ! -z "$track" && ! -z "$title" ]]; then
		echo "Creating '`basename "$new_file"`' with Title '$new_title'."
		AV_LOG_FORCE_NOCOLOR=1
		/usr/bin/time -f '%e' -o time.txt ffmpeg -nostdin -hide_banner -loglevel quiet -i "$file" -metadata "Title=$new_title" "$new_file"
		time=`cat time.txt`
		#rm time.txt
		ffstatus="$?"
		if [[ $ffstatus ]]; then
			echo "Success! Completed in $time seconds."
			time_count=$(( time_count + 1 ))
			total_time=$(echo "$total_time + $time" | bc -l)
			avg_time=$(echo "$total_time / $time_count" | bc -l)
		else
			error "Did something bad happen? ffmpeg returned $ffstatus." 4
		fi
	elif [[ -z "$track" && ! -z "$title" ]]; then
		echo "No Track# found, leaving Title alone."
		continue
	else
		error "File does not have Track or Title metadata. Are you sure you're running this on music?" 3
	fi

	# Confirm the new file exists and remove the old file if so
	if [[ -e "$new_file" ]]; then
		echo "Removing file..."
		rm -v "$file"
	else
		error "$new_file was not created successfully." 5
	fi
	
	# Give an estimate for time remaining. The magic number is to account for non-ffmpeg time.
	magic="1.2"
	est_guess_total="$( echo "est=(($total - $count) * $avg_time) * $magic; scale=0; est/1" | bc )"
	est_guess_secs="$( echo "est=$est_guess_total % 60; scale=0; est/1" | bc )"
	est_guess_mins="$( echo "est=($est_guess_total/60) % 60; scale=0; est/1" | bc )"
	est_guess_hours="$( echo "est=($est_guess_total/(60*60)); scale=0; est/1" | bc )"
	est_guess="$est_guess_hours hour(s) $est_guess_mins minute(s) $est_guess_secs second(s)"

	echo -e "\nFinished $count of $total. Estimated time remaining is $est_guess."
done

echo -e "\nProcess has completed. Enjoy having your songs in album-order!"

exit 0


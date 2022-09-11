# Fix Tracks For Toyota Entune

Bash script to add the Track# to the Title. 

At least in the 2019 Toyota RAV4, the media player sorts songs based on their alphanumeric Title rather than using the Track#. 

This process fixes the Title to be in the alphanumeric order of the album sequence.

[TBD: Create an Undo which takes (Fixed).mp3 files and removes the Track# from the Title.]

[TBD: Get total number of file which will be changed and keep track of where we are vs the total.]

[TBD: Track the amount of time ffmpeg is taking, keep as an average, and multiply by the amount of files remaining to give estimated remaining time. Output the time for each file as well.] 


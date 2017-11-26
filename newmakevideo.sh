#!/bin/bash

ver="4.xx"

# newmakevideo.sh modified by Ragnar Wisloeff
# Modified to archive timelapse photos which have been
# made into a video for the last 24 hours
#
# makevideo.sh written by Claude Pageau.
# Note - makevideo.sh variables in makevideo.conf
# To install/update avconv execute the following command in RPI terminal session
#
# sudo apt-get install libav-tools
#
# For more details see GitHub Wiki here
# https://github.com/pageauc/pi-timolo/wiki/Utilities

# get current working folder that this script was launched from
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $DIR

if [ -e newmakevideo.conf ] ; then
   source $DIR/newmakevideo.conf
else
   echo "INFO  - Attempting to download makevideo.conf from GitHub"
   echo "INFO  - Please Wait ...."
   wget https://raw.github.com/pageauc/pi-timolo/master/source/makevideo.conf

   if [ -e makevideo.conf ] ; then
      source $DIR/makevideo.conf
   else
      echo "ERROR  - $DIR/makevideo.conf File Not Found."
      echo "ERROR  - Could Not Import $0 variables"
      echo "ERROR  - Please Investigate or Download file from GitHub Repo"
      echo "ERROR  - https://github.com/pageauc/pi-timolo"
      exit 1
   fi
fi

# ------------- Start Script ------------------
if [ -e $DIR/$filename_utils_conf ]; then
    source $DIR/$filename_utils_conf
else
    echo "ERROR - Could Not Find Conf File $DIR/utils.conf"
    echo "ERROR - Please Investigate Problem"
    exit 1
fi

#  Script variables
tl_folder_working=$DIR"/makevideo_tmp"
tl_error_log_file=$DIR"/makevideo_error.log"
tl_source_files=$tl_folder_source/*$tl_files_ext  # Files wildcard that we are looking for

# Output videoname with prefix and date and time (minute only).
# Video can be specified as avi or mp4
tl_videoname=$tl_video_prefix$(date '+%Y%m%d-%H%M').mp4

clear
echo "$0 version $ver written by Claude Pageau, modified by RJW"
echo "============ TIMELAPSE VIDEO SETTINGS ===================================="
echo "tl_videoname           = $tl_videoname"
echo "tl_folder_source       = $tl_folder_source"
echo "tl_files_ext           = $tl_files_ext"
echo "tl_files_sort          = $tl_files_sort "
echo "tl_source_files        = $tl_source_files"
echo "tl_folder_destination  = $tl_folder_destination"
echo "tl_delete_source_files = $tl_delete_source_files"
echo "tl_share_copy_on       = $tl_share_copy_on"
echo "tl_share_destination   = $tl_share_destination"
echo "tl_move_to_archive     = $tl_move_to_archive"
echo "tl_archive_folder      = $tl_archive_folder"
echo "=========================================================================="
echo "Working ..."

# Check if source folder exists
if [ ! -d $tl_folder_source ] ; then
    echo "ERROR - Source Folder" $tl_folder_source "Does Not Exist"
    echo "ERROR - Check $0 Variable folder_source and Try Again"
    echo "ERROR - Source Folder $tl_folder_source Does Not Exist." >> $error_log_file
    exit 1
fi

# Check if source files exist
if ! ls $tl_source_files 1> /dev/null 2>&1 ; then
    echo "ERROR - No Source Files Found in" $tl_source_files
    echo "ERROR - Please Investigate and Try Again"
    exit 1
fi

# Create destination folder if it does note exist
if [ ! -d $tl_folder_destination ] ; then
    mkdir $tl_folder_destination
    if [ "$?" -ne 0 ]; then
        echo "ERROR - Problem Creating Destination Folder" $tl_folder_destination
        echo "ERROR - If destination is a remote folder or mount then check network, destination IP address, permissions, Etc"
        echo "ERROR - mkdir Failed - $tl_folder_destination Could NOT be Created." >> $error_log_file
        exit 1
    fi
fi

# Remove old working folder if it exists
if [ -d $tl_folder_working ] ; then
    echo "WARN  - Removing previous working folder" $tl_folder_working
#    sudo rm -R $tl_folder_working
    rm -R $tl_folder_working
fi

# Create a new temporary working folder to store soft links
# that are numbered sequentially in case source number has gaps
echo "STATUS- Creating Temporary Working Folder " $tl_folder_working
mkdir $tl_folder_working
if [ ! -d $tl_folder_working ] ; then
    echo "ERROR - Problem Creating Temporary Working Folder " $tl_folder_working
    echo "ERROR - mkdir Failed - $tl_folder_working Could NOT be Created." >> $error_log_file
    exit 1
fi

cd $tl_folder_working    # change to working folder
# Create numbered soft links in working folder that point to image files in source folder
echo "STATUS- Creating Image File Soft Links"
echo "STATUS-   From" $tl_folder_source
echo "STATUS-   To  " $tl_folder_working
a=0
ls $tl_files_sort $tl_source_files |
(
  # the first line will be the most recent file so ignore it
  # since it might still be in progress
  read the_most_recent_file
  # Skip this file in listing
  # create sym links in working folder for the rest of the files
  while read not_the_most_recent_file
  do
    new=$(printf "%05d.$tl_files_ext" ${a}) #05 pad to length of 4 max 99999 images
    ln -s ${not_the_most_recent_file} ${new}
    let a=a+1
  done
)
cd $DIR      # Return back to launch folder

echo "=========================================================================="
echo "Making Video ... "$tl_videoname
echo "=========================================================================="
/usr/bin/avconv -y -f image2 -r $tl_fps -i $tl_folder_working/%5d.$tl_files_ext -aspect $tl_a_ratio -s $tl_vid_size $tl_folder_destination/$tl_videoname
if [ $? -ne 0 ] ; then
  echo "ERROR - avconv Encoding Failed for" $tl_folder_destination/$tl_videoname
  echo "ERROR - Review avconv output for Error Messages and Correct Problem"
  echo "ERROR - avconv Encoding Failed for" $tl_folder_destination/$tl_videoname >> $error_log_file
  exit 1
else
  echo "=========================================================================="
  echo "STATUS- Video Saved to" $tl_folder_destination/$tl_videoname

  # If variable tl_move_to_archive is set to *true*
  # move the files just made into a video to archive
  if [ "$tl_move_to_archive" = true ] ; then
    # Check if the archive folder exists, if not create it
    if [ ! -d $tl_archive_folder ] ; then
      mkdir $tl_archive_folder
      if [ "$?" -ne 0 ]; then
          echo "ERROR - Problem Creating Archive Folder" $tl_archive_folder
          echo "ERROR - If destination is a remote folder or mount then check 
	  echo "ERROR -    network, destination IP address, permissions, etc"
          echo "ERROR - mkdir failed - $tl_archive_folder could not be created." >> $error_log_file
          exit 1
      fi
    fi

    # Create a date stamped archive folder for this run
    # 
    tl_archive_folder_current=$tl_archive_folder/$(date '+%Y-%m-%d')

    # It could be there already
    if [ ! -d $tl_archive_folder_current ]; then
      echo "STATUS- Creating archive folder " $tl_archive_folder_current
      mkdir $tl_archive_folder_current
      if [ ! -d $tl_archive_folder_current ] ; then
        echo "ERROR - Problem creating archive folder " $tl_archive_folder_current
        echo "ERROR - mkdir failed - $tl_archive_folder_current could be created" >> $error_log_file
        exit 1
      fi
    fi
  
    # All good, then move the files
    echo "STATUS - Copying timelapse photos to archive: "
    echo "STATUS -  archive is $tl_archive_folder_current ..."
    for f in $tl_folder_working/*jpg
      do
        photo=$(readlink -f $f)
        # use cp with -p switch and rm after 
        # as mv does not preserve timestamps of files
        cp -p $photo $tl_archive_folder_current/
        if [ $? -ne 0 ] ; then
          echo "ERROR - Could not copy file " $photo
          echo "ERROR -   to location " $tl_archive_folder_current
          echo "ERROR - Check for permissions or other possible problems"
          echo "ERROR - Could not copy file to archive location" $photo $tl_folder_working >> $error_log_file
          exit 1
        fi
        rm $photo
        if [ $? -ne 0 ] ; then
          echo "ERROR - Could not delete file after archiving " $photo
          echo "ERROR - Check for permissions or other possible problems"
          echo "ERROR - Could not delete source file following archiving" $photo >> $error_log_file
          exit 1
        fi
      done
      echo "STATUS - Finished copying source files to archive"
  fi

  if [ "$tl_delete_source_files" = true ] ; then
    echo "WARN  - Variable tl_delete_source_files="$tl_delete_source_files
    echo "WARN  - Deleting Source Files $tl_folder_source/*$tl_files"
    # Be Careful Not to Crash pi-timolo.py by deleting image file in progress
    ls -t $tl_source_files |
    (
      # the first line will be the most recent file so ignore it
      # since it might still be in progress
      read the_most_recent_file
      # Skip this file in listing since image may be in progress
      while read not_the_most_recent_file
      do
#        sudo rm $not_the_most_recent_file
        rm $not_the_most_recent_file
      done
    )
  fi


  echo "STATUS- Deleting Working Folder" $tl_folder_working
#  sudo rm -R $tl_folder_working
  rm -R $tl_folder_working
  if [ $? -ne 0 ] ; then
    echo "ERROR - Could not Delete Working Folder" $tl_folder_working
    echo "ERROR - Check for permissions or other possible problems"
    echo "ERROR - Could not Delete Working Folder" $tl_folder_working >> $error_log_file
    exit 1
  fi
fi

# Check if video file is to be copied to a network share
if [ "$tl_share_copy_on" = true ] ; then
  echo "STATUS- Copy Video File"
  echo "STATUS-   From" $tl_folder_destination/$tl_videoname
  echo "STATUS-   To  " $tl_share_destination

  if grep -qs "$tl_share_destination" /proc/mounts; then
    echo "STATUS- $tl_share_destination is Mounted."
  else
    echo "ERROR - Cannot Copy File to Share Folder"
    echo "ERROR - Failed to Copy" $tl_folder_destination/$tl_videoname "to" $tl_share_destination "Because It is NOT Mounted"
    echo "ERROR - Please Investigate Mount Problem and Try Again"
    echo "ERROR - Once Resolved You Will Need to Manually Transfer Previous Video Files"
    echo "ERROR - Failed to Copy" $tl_folder_destination/$tl_videoname "to" $tl_share_destination "Because It is NOT Mounted" >> $error_log_file
    exit 1
  fi

  cp $tl_folder_destination/$tl_videoname $tl_share_destination
  if [ $? -ne 0 ]; then
    echo "ERROR - Copy Failed $tl_folder_destination/$tl_videoname to" $tl_share_destination/$tl_videoname
    echo "ERROR - If destination is a remote folder or mount then check network, destination IP address, permissions, Etc"
    echo "ERROR - Copy Failed from" $tl_folder_destination/$tl_videoname "to" $tl_share_destination/$tl_videoname >> $error_log_file
    exit 1
  else
    if [ -e $tl_share_destination/$tl_videoname ] ; then
      echo "STATUS- Successfully Moved Video"
      echo "STATUS-   From" $tl_folder_destination/$tl_videoname
      echo "STATUS-   To  " $tl_share_destination/$tl_videoname
      echo "WARN  - Deleting Local Video File" $tl_folder_destination/$tl_videoname
#      sudo rm -f $tl_folder_destination/$tl_videoname
      rm -f $tl_folder_destination/$tl_videoname
      if [ -e $tl_folder_destination/$tl_videoname ] ; then
        echo "ERROR - Could Not Delete" $tl_folder_destination/$tl_videoname "After Copy To" $tl_share_destination/$tl_videoname
        echo "ERROR - Please investigate"
        echo "ERROR - Could Not Delete" $tl_folder_destination/$tl_videoname "After Copy To" $tl_share_destination/$tl_videoname >> $error_log_file
        exit 1
      fi
    else
      echo "ERROR - Problem copying $tl_folder_destination/$tl_videoname to $tl_share_destination/$tl_videoname"
      echo "ERROR - If destination is a remote folder or mount then check network, destination IP address, permissions, Etc"
      echo "ERROR - Copy Failed from" $tl_folder_destination/$tl_videoname "to" $tl_share_destination/$tl_videoname >> $error_log_file
      exit 1
    fi
  fi
fi
echo "STATUS- Processing Completed Successfully ..."
echo "=========================================================================="
echo "$0 Done"
#------------------ End do_timelapse_video Script ------------------------


#!/bin/bash
# ┌───────────────────────────────────────────────────────────────────────────┐
# │ Configuration                                                             │
# └───────────────────────────────────────────────────────────────────────────┘
#
# The complete path of the CRCON folder
# - If not set (ie : CRCON_folder_path=""), it will try to find and use
#   any "hll_rcon_tool" folder on disk.
# - If your CRCON folder name isn't 'hll_rcon_tool', you must set it here.
# - Some Ubuntu distros disable 'root' user,
#   you may have installed CRCON in "/home/ubuntu/hll_rcon_tool" then.
# default : "/root/hll_rcon_tool"
CRCON_folder_path=""

# Upload the compressed backup file to another machine
upload_backup="no"
sftp_host=123.123.123.123  # Your distant host IP
sftp_port=22  # Distant host SSH/SFTP port. Default : 22
sftp_dest="/root"  # Default : "/root"
sftp_user="root"  # Default : "root"
delete_after_upload="no"  # set to "yes" if you do not want a local backup
delete_after_upload_dontconfirm="no"  # Should we always consider the upload successful ?
#
# └───────────────────────────────────────────────────────────────────────────┘

is_CRCON_configured() {
  printf "%s└ \033[34m?\033[0m Testing folder : \033[33m%s\033[0m\n" "$2" "$1"
  if [ -f "$1/compose.yaml" ] && [ -f "$1/.env" ]; then
    printf "%s  └ \033[32mV\033[0m A configured CRCON install has been found in \033[33m%s\033[0m\n" "$2" "$1"
  else
    missing_env=0
    missing_compose=0
    wrong_compose_name=0
    deprecated_compose=0
    if [ ! -f "$1/.env" ]; then
      missing_env=1
      printf "%s  └ \033[31mX\033[0m Missing file : '\033[37m.env\033[0m'\n" "$2"
    fi
    if [ ! -f "$1/compose.yaml" ]; then
      missing_compose=1
      printf "%s  └ \033[31mX\033[0m Missing file : '\033[37mcompose.yaml\033[0m'\n" "$2"
      if [ -f "$1/compose.yml" ]; then
        wrong_compose_name=1
        printf "%s    └ \033[31m!\033[0m Wrongly named file found : '\033[37mcompose.yml\033[0m'\n" "$2"
      fi
      if [ -f "$1/docker-compose.yml" ]; then
        deprecated_compose=1
        printf "%s    └ \033[31m!\033[0m Deprecated file found : '\033[37mdocker-compose.yml\033[0m'\n" "$2"
      fi
    fi
    printf "\n\033[32mWhat to do\033[0m :\n"
    if [ $missing_env = 1 ]; then
      printf "\n - Follow the install procedure to create a '\033[37m.env\033[0m' file\n"
    fi
    if [ $missing_compose = 1 ]; then
      printf "\n - Follow the install procedure to create a '\033[37mcompose.yaml\033[0m' file\n"
      if [ $wrong_compose_name = 1 ]; then
        printf "\n   If your CRCON starts normally using '\033[37mcompose.yml\033[0m'\n"
        printf "   you should rename this file using this command :\n"
        printf "   \033[36mmv %s/compose.yml %s/compose.yaml\033[0m\n" "$1" "$1"
      fi
      if [ $deprecated_compose = 1 ]; then
        printf "\n   '\033[37mdocker-compose.yml\033[0m' was used by the deprecated (jul. 2023) 'docker-compose' command\n"
        printf "   You should delete it and use a '\033[37mcompose.yaml\033[0m' file\n"
      fi
    fi
    printf "\n"
    exit
  fi
}

clear
printf "┌─────────────────────────────────────────────────────────────────────────────┐\n"
printf "│ CRCON restart                                                               │\n"
printf "└─────────────────────────────────────────────────────────────────────────────┘\n\n"

this_script_dir=$(dirname -- "$( readlink -f -- "$0"; )";)
this_script_name=${0##*/}

# User must have root permissions
if [ "$(id -u)" -ne 0 ]; then
  printf "\033[31mX\033[0m This \033[37m%s\033[0m script must be run with full permissions\n\n" "$this_script_name"
  printf "\033[32mWhat to do\033[0m : you must elevate your permissions using 'sudo' :\n"
  printf "\033[36msudo sh ./%s\033[0m\n\n" "$this_script_name"
  exit
else
  printf "\033[32mV\033[0m You have 'root' permissions.\n"
fi

# Check CRCON folder path
if [ -n "$CRCON_folder_path" ]; then
  printf "\033[32mV\033[0m CRCON folder path has been set in config : \033[33m%s\033[0m\n" "$CRCON_folder_path"
  is_CRCON_configured "$CRCON_folder_path" ""
  crcon_dir="$CRCON_folder_path"
else
  printf "\033[31mX\033[0m You didn't set any CRCON folder path in config\n"
  printf "└ \033[34m?\033[0m Trying to detect a \033[33mhll_rcon_tool\033[0m folder\n"
  detected_dir=$(find / -name "hll_rcon_tool" 2>/dev/null)
  if [ -n "$detected_dir" ]; then
    is_CRCON_configured "$detected_dir" "  "
    crcon_dir="$detected_dir"
  else
    printf "  └ \033[31mX\033[0m No \033[33mhll_rcon_tool\033[0m folder could be found\n"
    printf "    └ \033[34m?\033[0m Trying to detect a CRCON install in current folder\n"
    is_CRCON_configured "$this_script_dir" "      "
    crcon_dir="$this_script_dir"
  fi
fi

# This script has to be in the CRCON folder
if [ ! "$this_script_dir" = "$crcon_dir" ]; then
  printf "\033[31mX\033[0m This script is not located in the CRCON folder\n"
  printf "  Script location : \033[33m%s\033[0m\n" "$this_script_dir"
  printf "  Should be here : \033[33m%s\033[0m\n" "$crcon_dir"
  printf "  \033[32mTrying to fix...\033[0m\n"
  cp "$this_script_dir/$this_script_name" "$crcon_dir"
  if [ -f "$crcon_dir/$this_script_name" ]; then
    printf "  \033[32mV\033[0m \033[37m%s\033[0m has been copied in \033[33m%s\033[0m\n\n" "$this_script_name" "$crcon_dir"
    printf "\033[32mWhat to do\033[0m : enter the CRCON folder and relaunch the script using this command :\n"
    printf "\033[36mrm %s && cd %s && sudo sh ./%s\033[0m\n\n" "$this_script_dir/$this_script_name" "$crcon_dir" "$this_script_name"
    exit
  else
    printf "\033[31mX\033[0m \033[37m%s\033[0m couldn't be copied in \033[33m%s\033[0m\n\n" "$this_script_name" "$crcon_dir"
    printf "\033[32mWhat to do\033[0m : Find your CRCON folder, copy this script in it and relaunch it from there.\n\n"
    exit
  fi
else
  printf "\033[32mV\033[0m This script is located in the CRCON folder\n"
fi

# Script has to be launched from CRCON folder
current_dir=$(pwd | tr -d '\n')
if [ ! "$current_dir" = "$crcon_dir" ]; then
  printf "\033[31mX\033[0m This script should be run from the CRCON folder\n\n"
  printf "\033[32mWhat to do\033[0m : enter the CRCON folder and relaunch the script using this command :\n"
  printf "\033[36mcd %s && sudo sh ./%s\033[0m\n\n" "$crcon_dir" "$this_script_name"
  exit
else
  printf "\033[32mV\033[0m This script has been run from the CRCON folder\n"
fi

printf "\033[32mV Everything's fine\033[0m Let's backup this CRCON !\n\n"

echo "┌──────────────────────────────────────┐"
echo "│ Stop CRCON                           │"
echo "└──────────────────────────────────────┘"
docker compose down
echo "└──────────────────────────────────────┘"
printf "Stop CRCON : \033[32mdone\033[0m.\n\n"

echo "┌──────────────────────────────────────┐"
echo "│ Backup CRCON                         │"
echo "└──────────────────────────────────────┘"
printf "Backup process started...\n"
cd ..
current_dir_parent=$(pwd | tr -d '\n')
backup_name="hll_rcon_tool_$(date '+%Y-%m-%d_%Hh%M').tar.gz"
tar -zcf "$backup_name" "$current_dir"
cd "$current_dir"
backup_file_size=$(numfmt --to=iec --format "%.2f" $(stat --printf="%s" "$current_dir_parent/$backup_name"))
echo "└──────────────────────────────────────┘"
printf "Backup CRCON : \033[32mdone\033[0m.\n\n"

echo "┌──────────────────────────────────────┐"
echo "│ Restart CRCON                        │"
echo "└──────────────────────────────────────┘"
docker compose up -d --remove-orphans
echo "└──────────────────────────────────────┘"
printf "Restart CRCON : \033[32mdone\033[0m.\n\n"
  
if [ "$upload_backup" = "yes" ]; then
  echo "┌──────────────────────────────────────┐"
  echo "│ Uploading backup to another machine  │"
  echo "└──────────────────────────────────────┘"
  upload_successfull="no"
  if [ -n "$sftp_port" ] && [ -n "$sftp_user" ] && [ -n "$sftp_dest" ]; then
    printf "\033[35m┌──────────────────────────────────────┐\033[0m\n"
    printf "\033[35m│ Enter your dest. host SSH password   │\033[0m\n"
    printf "\033[35m└──────────────────────────────────────┘\033[0m\n"
    scp -P $sftp_port "$current_dir_parent/$backup_name" $sftp_user@$sftp_host:$sftp_dest
    upload_successfull="yes"
    if [ $delete_after_upload = "yes" ]; then
      if [ $delete_after_upload_dontconfirm = "yes" ]; then
        rm "$current_dir_parent/$backup_name"
      else
        echo "You asked the local backup to be deleted"
        printf "This file size is %s\n\n" "$backup_file_size"
        read -p "Do you confirm the upload was successful ? (yes/no) " yn
        case $yn in
          [Yy]* ) echo "Deleting..."; rm "$current_dir_parent/$backup_name";;
          [Nn]* ) echo "Local backup will not be deleted";;
          * ) echo "Invalid input. Please answer yes or no.";;
        esac
      fi
      if [ -f "$current_dir_parent/$backup_name" ]; then
        local_deleted="no"
      else
        local_deleted="yes"
      fi
    else
      local_deleted="no"
    fi
  else
    upload_successfull="no"
    printf "\033[31mX\033[0m Invalid SFTP configuration\n"
    printf "\033[31mX\033[0m Local backup can't be uploaded\n"
    printf "\033[32mV\033[0m Local backup will not be deleted"
    local_deleted="no"
  fi
else
  local_deleted="no"
fi
printf "\n\n"

printf "┌──────────────────────────────────────┐\n"
printf "│ \033[32mBackup done\033[0m                          │\n"
printf "└──────────────────────────────────────┘\n"
if [ "$upload_backup" = "yes" ]; then
  if [ "$upload_successfull" = "yes" ]; then
    printf "Your backup file has been uploaded on\n"
    printf "\033[33m%s\033[0m, as \033[33m%s/\033[0m%s\n" "$sftp_host" "$sftp_dest" "$backup_name"
    printf "This file size is %s\n\n" "$backup_file_size"
    if [ "$local_deleted" = "yes" ]; then
      printf "The local backup file has been deleted\n\n"
    else
      printf "Your backup file has been saved here :\n"
      printf "\033[33m%s\033[0m\n" "$current_dir_parent/$backup_name"
      printf "This file size is %s\n\n" "$backup_file_size"
    fi
  else
    printf "\033[31mX\033[0m Your backup file couldn't be uploaded\n\n"
else
  printf "Your backup file has been saved here :\n"
  printf "\033[33m%s\033[0m\n" "$current_dir_parent/$backup_name"
  printf "This file size is %s\n\n" "$backup_file_size"
fi
printf "Wait for a full minute before using CRCON's interface.\n\n"

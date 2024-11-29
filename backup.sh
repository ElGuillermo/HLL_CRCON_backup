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
CRCON_folder_path="/root/hll_rcon_tool"

# Set to "yes" if you have modified any file that comes from CRCON repository
# First build will take ~3-4 minutes. Subsequent ones will take ~30 seconds.
# Default : "yes"
rebuild_before_restart="yes"

# Redis cache flush
# You should NOT enable this one until asked to do so !
# That will force CRCON to reread ~5 min of previous logs from the game server
# and resend past automod/votemap/admin/etc messages, punishes and kicks
# Default : "no"
redis_cache_flush="no"

# Delete logs before backup
# Default : "no"
delete_logs="no"

# Delete the obsolete Docker images, containers and build cache
# Pros : that will free a *lot* (several GBs) of disk space
# Cons : build procedure will be *minutes* longer
# Default : "no"
clean_docker_stuff="no"

# Upload the compressed backup file to another machine
sftp_host=  # no value = disable
sftp_port=22  # Default : 22
sftp_dest="/root"
sftp_user="root"
delete_after_upload="yes"
delete_after_upload_dontconfirm="no"  # Should we always consider the upload successful ?

# Storage informations
# Default : "no"
storage_info="no"
#
# └───────────────────────────────────────────────────────────────────────────┘

clear
printf "┌─────────────────────────────────────────────────────────────────────────────┐\n"
printf "│ CRCON restart                                                               │\n"
printf "└─────────────────────────────────────────────────────────────────────────────┘\n\n"

# User must have root permissions
this_script_name=${0##*/}
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
  crcon_dir=$CRCON_folder_path
  printf "\033[32mV\033[0m CRCON folder path has been set in config : \033[33m%s\033[0m\n" "$CRCON_folder_path"
else
  printf "\033[34m?\033[0m You didn't set any CRCON folder path in config\n"
  printf "  Trying to detect a \033[33mhll_rcon_tool\033[0m folder...\n"
  crcon_dir=$(find / -name "hll_rcon_tool" 2>/dev/null)
  if [ -n "$crcon_dir" ]; then
    printf "\033[32mV\033[0m CRCON folder detected in \033[33m%s\033[0m\n" "$crcon_dir"
  else
    printf "\033[31mX\033[0m No \033[33mhll_rcon_tool\033[0m folder could be found\n\n"
    printf "  - Maybe you renamed the \033[33mhll_rcon_tool\033[0m folder ?\n"
    printf "    (it will work the same, but you'll have to adapt every maintenance script)\n\n"
    printf "  If you followed the official install procedure,\n"
    printf "  your \033[33mhll_rcon_tool\033[0m folder should be found here :\n"
    printf "    - \033[33m/root/hll_rcon_tool\033[0m        (most Linux installs)\n"
    printf "    - \033[33m/home/ubuntu/hll_rcon_tool\033[0m (some Ubuntu installs)\n\n"
    printf "\033[32mWhat to do\033[0m :\nFind your CRCON folder, copy this script in it and relaunch it from there.\n\n"
    exit
  fi
fi

# Script has to be in the CRCON folder
this_script_dir=$(dirname -- "$( readlink -f -- "$0"; )";)
if [ ! "$this_script_dir" = "$crcon_dir" ]; then
  printf "\033[31mX\033[0m This script is not located in the CRCON folder\n"
  printf "  Script location : \033[33m%s\033[0m\n" "$this_script_dir"
  printf "  Should be here : \033[33m%s\033[0m\n" "$crcon_dir"
  printf "\033[32mFixing...\033[0m\n"
  cp "$this_script_dir/$this_script_name" "$crcon_dir"
  if [ -f "$crcon_dir/$this_script_name" ]; then
    printf "\033[32mV\033[0m \033[37m%s\033[0m has been copied in \033[33m%s\033[0m\n\n" "$this_script_name" "$crcon_dir"
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
  printf "\033[31mX\033[0m This \033[37m%s\033[0m script should be run from the CRCON folder\n\n" "$this_script_name"
  printf "\033[32mWhat to do\033[0m : enter the CRCON folder and relaunch the script using this command :\n"
  printf "\033[36mcd %s && sudo sh ./%s\033[0m\n\n" "$crcon_dir" "$this_script_name"
  exit
else
  printf "\033[32mV\033[0m This script has been run from the CRCON folder\n"
fi

# CRCON config check
if [ ! -f "$crcon_dir/compose.yaml" ] || [ ! -f "$crcon_dir/.env" ]; then
  printf "\033[31mX\033[0m CRCON doesn't seem to be configured\n"
  if [ ! -f "$crcon_dir/compose.yaml" ]; then
    printf "  \033[31mX\033[0m There is no '\033[37mcompose.yaml\033[0m' file in \033[33m%s\033[0m\n" "$crcon_dir"
  fi
  if [ ! -f "$crcon_dir/.env" ]; then
    printf "  \033[31mX\033[0m There is no '\033[37m.env\033[0m' file in \033[33m%s\033[0m\n" "$crcon_dir"
  fi
  printf "\n\033[32mWhat to do\033[0m : check your CRCON install in \033[33m%s\033[0m\n\n" "$crcon_dir"
  exit
else
  printf "\033[32mV\033[0m CRCON seems to be configured\n"
fi

printf "\033[32mV Everything's fine\033[0m Let's backup this CRCON !\n\n"

if [ $rebuild_before_restart = "yes" ]; then
  echo "┌──────────────────────────────────────┐"
  echo "│ Build CRCON                          │"
  echo "└──────────────────────────────────────┘"
  docker compose build
  echo "└──────────────────────────────────────┘"
  printf "Build CRCON : \033[32mdone\033[0m.\n\n"
fi

echo "┌──────────────────────────────────────┐"
echo "│ Stop CRCON                           │"
echo "└──────────────────────────────────────┘"
docker compose down
echo "└──────────────────────────────────────┘"
printf "Stop CRCON : \033[32mdone\033[0m.\n\n"

if [ $redis_cache_flush = "yes" ]; then
  echo "┌──────────────────────────────────────┐"
  echo "│ Redis cache flush                    │"
  echo "└──────────────────────────────────────┘"
  docker compose up -d redis
  docker compose exec redis redis-cli flushall
  docker compose down
  echo "└──────────────────────────────────────┘"
  printf "Redis cache flush : \033[32mdone\033[0m.\n\n"
fi

echo "┌──────────────────────────────────────┐"
echo "│ Backup CRCON                         │"
echo "└──────────────────────────────────────┘"
printf "Backup process started...\n"
cd ..
current_dir_parent=$(pwd | tr -d '\n')
backup_name="hll_rcon_tool_$(date '+%Y-%m-%d_%Hh%M').tar.gz"
tar -zcf "$backup_name" "$current_dir"
cd "$current_dir" || exit
backup_file_size=$(numfmt --to=iec --format "%.2f" $(stat --printf="%s" "$current_dir_parent/$backup_name"))
echo "└──────────────────────────────────────┘"
printf "Backup CRCON : \033[32mdone\033[0m.\n\n"

if [ $delete_logs = "yes" ]; then
  echo "┌──────────────────────────────────────┐"
  echo "│ Delete logs                          │"
  echo "└──────────────────────────────────────┘"
  rm -r "$crcon_dir"/logs/*.*
  # rm -r "$crcon_dir"/logs/old/*.*
  echo "└──────────────────────────────────────┘"
  printf "Delete logs : \033[32mdone\033[0m.\n"
fi

echo "┌──────────────────────────────────────┐"
echo "│ Restart CRCON                        │"
echo "└──────────────────────────────────────┘"
docker compose up -d --remove-orphans
echo "└──────────────────────────────────────┘"
printf "Restart CRCON : \033[32mdone\033[0m.\n\n"
  
if [ $clean_docker_stuff = "yes" ]; then
  echo "┌──────────────────────────────────────┐"
  echo "│ Clean Docker stuff                   │"
  echo "└──────────────────────────────────────┘"
  docker system prune -a -f
  # docker builder prune --all
  # docker buildx prune --all
  docker volume rm $(docker volume ls -qf dangling=true)
  echo "└──────────────────────────────────────┘"
  printf "Clean Docker stuff : \033[32mdone\033[0m.\n\n"
fi

# SFTP transfer is configured
if [ -n "$sftp_host" ]; then
  echo "┌──────────────────────────────────────┐"
  echo "│ Uploading backup to another machine  │"
  echo "└──────────────────────────────────────┘"
  # All SFTP parameters are present
  if [ -n "$sftp_port" ] && [ -n "$sftp_user" ] && [ -n "$sftp_dest" ]; then
    echo "Enter your '$sftp_user@$sftp_host' password"
    scp -P $sftp_port "$current_dir_parent/$backup_name" $sftp_user@$sftp_host:$sftp_dest
    # local backup should be deleted
    if [ $delete_after_upload = "yes" ]; then
      # No need to confirm
      if [ $delete_after_upload_dontconfirm = "yes" ]; then
        rm "$current_dir_parent/$backup_name"
        local_deleted="yes"
      # Confirmation is required
      else
        echo "You asked the local backup to be deleted"
        printf "This file size is %s\n\n" "$backup_file_size"
        read -p "Was the upload successful ? (yes/no) " yn
        case $yn in
          [Yy]* ) echo "Deleting..."; rm "$current_dir_parent/$backup_name"; local_deleted="yes";;
          [Nn]* ) echo "Local backup will not be deleted"; local_deleted="no";;
          * ) echo "Invalid input. Please answer yes or no.";;
        esac
      fi
    # local backup should not be deleted
    else
      local_deleted="no"
    fi
  # One or more SFTP parameters is missing
  else
    printf "\033[31mError\033[0m :\n  Invalid SFTP configuration\n"
    printf "\033[31mX\033[0m Local backup can't be uploaded\n"
    printf "\033[32mV\033[0m Local backup will not be deleted"
    local_deleted="no"
  fi
# SFTP transfer isn't configured
else
  local_deleted="no"
fi
printf "\n\n"

if [ $storage_info = "yes" ]; then
  echo "┌──────────────────────────────────────┐"
  echo "│ CRCON storage information            │"
  echo "└──────────────────────────────────────┘"
  { printf "CRCON total size     : "; du -sh "$crcon_dir" | tr -d '\n'; }
  printf "\n────────────────────────────────────────"
  { printf "\n └ Database          : "; du -sh "$crcon_dir"/db_data | tr -d '\n'; }
  db_command="docker exec -it hll_rcon_tool-postgres-1 psql -U rcon -d rcon -t -A -c "
  db_table_size="SELECT pg_size_pretty(pg_total_relation_size('public."
  db_rows_count="SELECT COUNT(*) FROM public."
  { printf "\n   └ audit_log       : "; ($db_command "$db_table_size""audit_log'));") | tr -d ' \t\r\n'; printf "\t("; ($db_command "$db_rows_count""audit_log";) | tr -d ' \t\r\n'; printf " rows)\n"; }
  { printf "   └ log_lines       : "; ($db_command "$db_table_size""log_lines'));") | tr -d ' \t\r\n'; printf "\t("; ($db_command "$db_rows_count""log_lines";) | tr -d ' \t\r\n'; printf " rows)\n"; }
  { printf "   └ player_names    : "; ($db_command "$db_table_size""player_names'));") | tr -d ' \t\r\n'; printf "\t("; ($db_command "$db_rows_count""player_names";) | tr -d ' \t\r\n'; printf " rows)\n"; }
  { printf "   └ player_sessions : "; ($db_command "$db_table_size""player_sessions'));") | tr -d ' \t\r\n'; printf "\t("; ($db_command "$db_rows_count""player_sessions";) | tr -d ' \t\r\n'; printf " rows)\n"; }
  { printf "   └ player_stats    : "; ($db_command "$db_table_size""player_stats'));") | tr -d ' \t\r\n'; printf "\t("; ($db_command "$db_rows_count""player_stats";) | tr -d ' \t\r\n'; printf " rows)\n"; }
  { printf "   └ players_actions : "; ($db_command "$db_table_size""players_actions'));") | tr -d ' \t\r\n'; printf "\t("; ($db_command "$db_rows_count""players_actions";) | tr -d ' \t\r\n'; printf " rows)\n"; }
  { printf "   └ steam_id_64     : "; ($db_command "$db_table_size""steam_id_64'));") | tr -d ' \t\r\n'; printf "\t("; ($db_command "$db_rows_count""steam_id_64";) | tr -d ' \t\r\n'; printf " rows)\n"; }
  { printf "   └ steam_info      : "; ($db_command "$db_table_size""steam_info'));") | tr -d ' \t\r\n'; printf "\t("; ($db_command "$db_rows_count""steam_info";) | tr -d ' \t\r\n'; printf " rows)\n"; }
  { printf " └ Logs              : "; du -sh "$crcon_dir"/logs | tr -d '\n'; }
  { printf "\n └ Redis cache       : "; du -sh "$crcon_dir"/redis_data | tr -d '\n'; }
  printf "\n└──────────────────────────────────────┘\n\n"
fi
printf "\n\n"

printf "┌──────────────────────────────────────┐\n"
printf "│ \033[32mBackup done\033[0m                          │\n"
printf "└──────────────────────────────────────┘\n"
if [ "$local_deleted" = "yes" ]; then
  printf "Your compressed backup file has been uploaded on\n"
  printf "\033[33m%s\033[0m, as \033[33m%s/\033[0m%s\n" "$sftp_host" "$sftp_dest" "$backup_name"
  printf "This file size is %s\n\n" "$backup_file_size"
  printf "The local backup file has been deleted\n\n"
else
  printf "Your compressed backup file has been saved here :\n"
  printf "\033[33m%s\033[0m\n" "$current_dir_parent/$backup_name"
  printf "This file size is %s\n\n" "$backup_file_size"
fi
printf "Wait for a full minute before using CRCON's interface.\n\n"

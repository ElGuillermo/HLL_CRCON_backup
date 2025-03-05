#!/bin/bash
# ┌───────────────────────────────────────────────────────────────────────────┐
# │ CRCON backup                                                              │
# └───────────────────────────────────────────────────────────────────────────┘
# The script will :
# - search for a valid CRCON configuration
# - stop the CRCON containers
# - make a compressed backup of the CRCON folder
# - restart the CRCON containers
# - (optional) upload the backup to a distant host
# - (optional) delete the local backup if the upload was successful

# Source: https://github.com/ElGuillermo/HLL_CRCON_backup
# Feel free to use/modify/distribute, as long as you keep this note in your code

# ┌───────────────────────────────────────────────────────────────────────────┐
# │ Configuration                                                             │
# └───────────────────────────────────────────────────────────────────────────┘

# The complete path of the CRCON folder
# - If not set (ie : CRCON_folder_path=""), it will try to find and use
#   any "hll_rcon_tool" folder on disk, then, if not found, the current folder
# - If your CRCON folder name isn't 'hll_rcon_tool', you must set it here.
# - Some Ubuntu distros disable 'root' user,
#   you may have installed CRCON in "/home/ubuntu/hll_rcon_tool" then.
# default : ""
# suggested : "/root/hll_rcon_tool"
CRCON_folder_path=""

# Upload the compressed backup file to another machine
upload_backup="no"
sftp_host=123.123.123.123             # Distant host IP
sftp_port=22                          # Distant host SSH/SFTP port. Default : 22
sftp_dest="/root"                     # Distant path. Default : "/root"
sftp_user="root"                      # Distant user. Default : "root"
delete_after_upload="no"              # "yes" if you do NOT want to keep a local backup
delete_after_upload_dontconfirm="no"  # Should we always consider the upload successful ?

# └───────────────────────────────────────────────────────────────────────────┘

# --- functions ---

# Set    : $SUDO="" if user is root
#          $SUDO="sudo" if he have sudo privileges
# Exit   : if user is not root and have no sudo privileges
check_privileges() {
    printf "\033[36m?\033[0m Checking current user permissions...\n"
    SUDO=""
    if [[ "$(id -u)" -eq 0 ]]; then
        printf "└ \033[32mV\033[0m You are running this script as root.\n"
        return 0
    fi
    printf "└ \033[31mX\033[0m You are not running this script as root.\n"
    if ! command -v sudo &>/dev/null; then
        printf "  └ \033[31mX\033[0m The sudo command is not installed. Unable to check privileges.\n\n"
        printf "Sorry : we can't go further :/ Exiting...\n\n"
        exit 1
    fi
    if sudo -n true 2>/dev/null; then
        printf "  └ \033[32mV\033[0m User '$(whoami)' has sudo privileges.\n"
        SUDO="sudo"
        return 0
    fi
    if LANG=C sudo -l 2>/dev/null | grep -Ez '(ALL[[:space:]]*:[[:space:]]*ALL)[[:space:]]*ALL' >/dev/null; then
        printf "  └ \033[32mV\033[0m User '$(whoami)' has sudo privileges.\n"
        SUDO="sudo"
        return 0
    fi
    printf "  └ \033[31mX\033[0m User '$(whoami)' does NOT have sudo privileges.\n"
    printf "      Please log in as a user with sudo access.\n\n"
    printf "Sorry : we can't go further :/ Exiting...\n\n"
    exit 1
}

# Input  : $1 (path to test)
# Return : the tested path if it's a valid CRCON configuration, an empty string otherwise
is_CRCON_configured() {
    if [ -f "$1/.env" ] && [ -f "$1/compose.yaml" ]; then
        echo "$1"
    else
        echo ""
    fi
}

# Input  : $CRCON_folder_path (path to the CRCON as set in configuration)
#          $current_dir (current directory)
# Set    : $CRCON_PATH (first valid CRCON path found, or an empty string if none)
#          $crcon_parent_dir (parent directory of the CRCON folder)
# Return : 0 if a valid CRCON configuration is found
#          1 otherwise
find_valid_CRCON() {
    printf "\033[36m?\033[0m Searching for a valid CRCON configuration...\n"
    paths=""
    [ -n "$CRCON_folder_path" ] && paths="$paths $CRCON_folder_path"
    paths="$paths $(pwd)"
    find / -type d -name "hll_rcon_tool" 2>/dev/null > /tmp/hll_folders
    while IFS= read -r dir; do
        paths="$paths $dir"
    done < /tmp/hll_folders
    for path in $paths; do
        result=$(is_CRCON_configured "$path")
        if [ -n "$result" ]; then
            printf "└ \033[32mV\033[0m CRCON is configured at \033[33m$result\033[0m\n"
            CRCON_PATH="$result"
            cd "$CRCON_PATH/.." || exit 1
            crcon_parent_dir=$(pwd)
            cd "$current_dir" || exit 1
            return 0
        fi
    done
    printf "└ \033[31mX\033[0m No valid CRCON configuration found.\n"
    CRCON_PATH=""
    return 1
}

# Input   : $CRCON_PATH (path to valid CRCON configuration)
# Set     : $CRCON_stopped="yes" if no CRCON container is running, ="no" otherwise
# Return  : 0 if containers are stopped
#           1 otherwise
stop_CRCON_containers() {
    CRCON_stopped="no"
    printf "\033[36m?\033[0m Stopping CRCON Docker container(s)...\n"
    if [ -n "$CRCON_PATH" ]; then
        if $SUDO docker ps --filter "name=hll_rcon_tool-" --format "{{.Names}}" | grep -q .; then
            printf "└ \033[32mV\033[0m Running CRCON Docker container(s) found.\n"
            cd "$CRCON_PATH" || return 1
            if $SUDO docker compose down; then
                CRCON_stopped="yes"
                printf "  └ \033[32mV\033[0m Containers stopped\n"
                return 0
            else
                printf "  └ \033[31mX\033[0m Containers can't be stopped\n"
                return 1
            fi
        else
            CRCON_stopped="yes"
            printf "└ \033[32mV\033[0m No running CRCON Docker container found.\n"
            return 0
        fi
    else
        printf "└ \033[31mX\033[0m No CRCON configuration found. Skipping container stop.\n"
        return 1
    fi
}

# Input  : $CRCON_PATH (path to valid CRCON configuration)
#          $CRCON_stopped (set to "yes" if no CRCON container is running)
# Set    : $backup_path to the path of the backup file
#          $backup_successful="yes" if backup is successful, ="no" otherwise
#          $backup_file_size to the size of the backup file
# Return : 0 if backup is successful
#          1 otherwise
backup_CRCON() {
    printf "\033[36m?\033[0m Creating backup of CRCON folder...\n"
    backup_successful="no"
    backup_file_size=0
    if [ "$CRCON_stopped" = "yes" ]; then
        printf "Backup process started. Please wait...\n"
        backup_path="$crcon_parent_dir/hll_rcon_tool_$(date '+%Y-%m-%d_%Hh%M').tar.gz"

        if $SUDO tar -zcf "$backup_path" "$CRCON_PATH" >/dev/null 2>&1; then
            backup_successful="yes"
            backup_file_size=$(numfmt --to=iec --format "%.2f" "$(stat --printf="%s" "$backup_path")")
            printf "└ \033[32mV\033[0m Backup successful !\n"
            printf "  Backup file : \033[33m$backup_path\033[0m\n"
            printf "  File size : $backup_file_size\n"
            return 0
        else
            backup_successful="no"
            printf "└ \033[31mX\033[0m Backup failed.\n"
            return 1
        fi
    else
        backup_successful="no"
        printf "└ \033[31mX\033[0m CRCON containers are running. Skipping creating backup.\n"
        return 1
    fi
}

# Input  : $upload_backup (set to "yes" if you want to upload the backup)
#          $backup_successful (set to "yes" if backup is successful)
#          $sftp_host, $sftp_port, $sftp_user, $sftp_dest (SFTP configuration)
# Set    : $upload_successfull="yes" if upload is successful, ="no" otherwise
# Return : 0 if upload is successful
#          1 otherwise
upload_CRCON_backup() {
    printf "\033[36m?\033[0m Uploading backup...\n"

    if [ "$upload_backup" != "yes" ]; then
        upload_successfull="no"
        printf "└ \033[31mX\033[0m Skipping : upload is disabled in config.\n"
        return 1
    fi

    if [ "$backup_successful" = "no" ]; then
        upload_successfull="no"
        printf "└ \033[31mX\033[0m Backup couldn't be created. Aborting upload.\n"
        return 1
    fi

    if [ ! -f "$backup_path" ]; then
        upload_successfull="no"
        printf "└ \033[31mX\033[0m Backup file not found.\n"
        return 1
    fi

    if [ -z "$sftp_host" ] || [ -z "$sftp_port" ] || [ -z "$sftp_user" ] || [ -z "$sftp_dest" ]; then
        upload_successfull="no"
        printf "└ \033[31mX\033[0m Missing SFTP configuration\n"
        [ -z "$sftp_port" ] && printf "  └ sftp port isn't set in config.\n"
        [ -z "$sftp_user" ] && printf "  └ sftp user isn't set in config.\n"
        [ -z "$sftp_host" ] && printf "  └ sftp host isn't set in config.\n"
        [ -z "$sftp_dest" ] && printf "  └ sftp dest. path isn't set in config.\n"
        return 1
    fi

    printf "\033[35m┌──────────────────────────────────────────┐\033[0m\n"
    printf "\033[35m│ Enter your destination host SSH password │\033[0m\n"
    printf "\033[35m└──────────────────────────────────────────┘\033[0m\n"

    if $SUDO scp -P "$sftp_port" "$backup_path" "$sftp_user@$sftp_host:$sftp_dest"; then
        upload_successfull="yes"
        printf "└ \033[32mV\033[0m Backup uploaded successfully\n"
        printf "  Distant file is : \033[33m$sftp_dest/$(basename "$backup_path")\033[0m\n"
        return 0
    else
        printf "└ \033[31mX\033[0m Backup couldn't be uploaded\n"
        return 1
    fi
}

# Input  : $CRCON_PATH (path to valid CRCON configuration)
#          $CRCON_stopped (set to "yes" if no CRCON container is running)
restart_crcon(){
    printf "\033[36m?\033[0m Restarting CRCON Docker containers...\n"
    if [ "$CRCON_stopped" = "yes" ]; then
        cd "$CRCON_PATH" || exit 1
        if $SUDO docker compose up -d --remove-orphans; then
            printf "└ \033[32mV\033[0m CRCON restarted successfully\n"
        else
            printf "└ \033[31mX\033[0m CRCON couldn't be restarted\n"
        fi
        cd "$current_dir" || exit 1
    else
        printf "└ \033[31mX\033[0m CRCON containers were not stopped. Skipping restart.\n"
    fi
}

# Input  : $upload_successfull (set to "yes" if upload is successful)
#          $delete_after_upload (set to "yes" if you want to delete the local backup)
#          $delete_after_upload_dontconfirm (set to "yes" if you want to delete the local backup without confirmation)
# Return : 0 if local backup is deleted
#          1 otherwise
delete_local_backup(){
    if [ "$upload_successfull" = "yes" ] && [ "$delete_after_upload" = "yes" ]; then
        if [ $delete_after_upload_dontconfirm = "yes" ]; then
            printf "\033[36m?\033[0m Deleting local backup...\n"
            if rm "$backup_path"; then
                printf "\033[32mV\033[0m Local backup successfully deleted\n\n"
                return 0
            else
                printf "\033[31mX\033[0m Local backup couldn't be deleted\n\n"
                return 1
            fi
        else
            printf "You asked the local backup to be deleted\n"
            read -r -p "The upload has been reported as successful. Do you confirm ? (y/n) " yn
            case $yn in
                [Yy]* ) echo "Deleting..."; rm "$backup_path";;
                [Nn]* ) echo "Local backup will not be deleted";;
                * ) echo "Invalid input. Please answer y(es) or n(o)";;
            esac
            if [ -f "$backup_path" ]; then
                printf "\033[31mX\033[0m Local backup wasn't deleted\n\n"
                return 1
            else
                printf "\033[32mV\033[0m Local backup successfully deleted\n\n"
                return 0
            fi
        fi
    fi
}

# --- Start ---

current_dir=$(pwd)

printf "\\033c"

printf "┌─────────────────────────────────────────────────────────────────────────────┐\n"
printf "│ CRCON backup                                                                │\n"
printf "└─────────────────────────────────────────────────────────────────────────────┘\n\n"

check_privileges
find_valid_CRCON
stop_CRCON_containers
backup_CRCON
restart_crcon
upload_CRCON_backup
delete_local_backup

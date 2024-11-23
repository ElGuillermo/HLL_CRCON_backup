# HLL_CRCON_backup

## Description
Stand alone tool to backup an Hell Let Loose (HLL) CRCON (see : https://github.com/MarechJ/hll_rcon_tool) install.

That will generate a compressed file containing the whole `hll_rcon_tool` folder.  
The file will be stored in `hll_rcon_tool` parent folder.

What it does :  
- stop CRCON
- make a backup of it
- rebuild CRCON
- restart CRCON
- delete obsoleted Docker containers and images

## Install
- Copy `backup.sh` in CRCON's root (`/root/hll_rcon_tool/`)

## Config
- Nothing to config

## Use
- Get into CRCON's root (`/root/hll_rcon_tool/`) and launch the script `sudo sh ./backup.sh`

The file should then be uploaded on any distant machine to keep it secure in case of a CRCON host machine catastrophic failure.

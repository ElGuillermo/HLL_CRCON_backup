# HLL_CRCON_backup

## Description
Stand alone tool to backup an Hell Let Loose (HLL) CRCON (see : https://github.com/MarechJ/hll_rcon_tool) install.

That will generate a compressed file containing the whole `hll_rcon_tool` folder.  
You then can choose to upload the file to another machine and/or keep it in `hll_rcon_tool` parent folder.

What it does :  
- stop CRCON  
- `(optional)` delete logs  
- create a compressed backup  
- `(optional)` rebuild CRCON  
- restart CRCON  
- `(optional)` delete obsoleted Docker containers and images  
- `(optional)` upload the compressed backup file to anoter machine  
  - `(optional)` delete the local compressed backup file  
- report disk usage of various CRCON components

## Install
- Copy `backup.sh` in CRCON's folder (`/root/hll_rcon_tool/`)

You can download the the file from your CRCON host machine using these commands :
```shell
cd /root/hll_rcon_tool
wget https://raw.githubusercontent.com/ElGuillermo/HLL_CRCON_backup/refs/heads/main/backup.sh
```

## Config
- Edit `backup.sh` and edit the "configuration" part

## Use
- Get into CRCON's root and launch the script using these commands :
```shell
cd /root/hll_rcon_tool
sudo sh ./backup.sh
```

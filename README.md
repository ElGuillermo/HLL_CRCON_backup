# HLL_CRCON_backup
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

> [!NOTE]
> The shell commands given below assume your CRCON is installed in `/root/hll_rcon_tool`.  
> You may have installed your CRCON in a different folder.  
>   
> Some Ubuntu Linux distributions disable the `root` user and `/root` folder by default.  
> In these, your default user is `ubuntu`, using the `/home/ubuntu` folder.  
> You should then find your CRCON in `/home/ubuntu/hll_rcon_tool`.  
>   
> If so, you'll have to adapt the commands below accordingly.

## Install
- Log into your CRCON host machine using SSH and enter these commands (one line at at time) :
```shell
cd /root/hll_rcon_tool
wget https://raw.githubusercontent.com/ElGuillermo/HLL_CRCON_backup/refs/heads/main/backup.sh
```

## Config
- Edit `backup.sh` and set the parameters to fit your needs

## Use
- Get into CRCON's root and launch the script using these commands :
```shell
cd /root/hll_rcon_tool
sudo sh ./backup.sh
```

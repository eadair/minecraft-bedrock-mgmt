# [minecraft-bedrock-mgmt](https://github.com/eadair/minecraft-bedrock-mgmt/tree/main)
### Backup, restore, and update Minecraft Bedrock server for Linux

__Instructions:__
Place the scripts in the Bedrock server directory and run through the shell or scheduled with `crontab`.

## [bedrock-backup.sh](https://github.com/eadair/minecraft-bedrock-mgmt/blob/main/bedrock_backup.sh)
Backup specified Minecraft world with customizable retention policy and notification to Minecraft players.
> [!IMPORTANT]
> Requires `screen` to interact with Bedrock server.

Hourly, daily, and weekly folders will be created in the backup folder.  Individual backups will be purged as retention limits are reached, or moved to daily or weekly folders as required.
> [!NOTE]
> The final hourly backup from the previous day is moved to the daily directory during the current day's first backup.

Parameters:
```
 -w  <Path to world directory>
 -b  <Path to backup directory>
 -s  <Screen name>
 -hr <Hours of hourly backups to retain>   (Optional parameter.  Default: 24)
 -dr <Days of daily backups to retain>     (Optional parameter.  Default: 7)
 -wr <Weeks of weekly backups to retain>   (Optional parameter.  Default: 8)
```

Example backup scheduling with `crontab -e`:
```
# Backup every 2 hours from 10AM until 10PM
0 10-22/2 * * * $HOME/bedrock/bedrock_backup.sh -w $HOME/bedrock/worlds/Springfield -b $HOME/bedrock/backups -s bedrock 
```


## [bedrock-restore.sh](https://github.com/eadair/minecraft-bedrock-mgmt/blob/main/bedrock_restore.sh)
Stop Bedrock server, restore world from backup, and start Bedrock server.
> [!IMPORTANT]
> Requires Bedrock server running as a service.

Parameters:
```
 -f  <Path to zip file containing backup>
 -w  <Path to world directory>
 -s  <Name of Bedrock service>     (Optional parameter.  Default: mcbedrock)
```

> [!WARNING]
> Restores are final.  Ensure you have recently completed a successful backup before restoring a world.

Example usage:
```
sudo ./bedrock_restore.sh -f $HOME/bedrock/backups/hourly/Springfield_20250314_120001.zip -w $HOME/Bedrock/Springfield -s bedrock
```


## [bedrock-update.sh](https://github.com/eadair/minecraft-bedrock-mgmt/blob/main/bedrock_update.sh)
Download and update to latest version of Minecraft Bedrock server.  Retain configuration files.
> [!IMPORTANT]
> Requires Bedrock server running as a service.

Parameters:
```
 -s  <Name of Bedrock service>     (Optional parameter.  Default: mcbedrock)
```

Example usage:
```
sudo ./bedrock_update.sh -s bedrock
```

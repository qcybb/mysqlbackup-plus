# 💾 MySQLBackupPlus
A powerful and flexible MySQL backup tool with built-in optimization features.

## 🚀 Features

**Selective Backup Options**  
Allows users to back up entire databases and/or specific tables, offering flexible backup configurations.

**Automated Backups**  
Easily schedule MySQL database backups via crontab.

**Flexible Compression**  
Supports five different compression methods with customizable compression levels to efficiently reduce storage space.

**Backup Management** (Optional)  
Enable weekly and monthly backups, with automatic rotation for daily, weekly, and monthly backups based on user-defined settings.

**MyISAM Optimization** (Optional)  
Supports MyISAM table optimization using `OPTIMIZE TABLE` for better performance.

**InnoDB Analysis** (Optional)  
Performs `ANALYZE TABLE` on InnoDB tables to update index statistics, improving query optimization and execution efficiency.

## 📥 Installation
**Download the script**
```
wget https://github.com/qcybb/mysqlbackup-plus/raw/main/mysqlbackup-plus.sh
```

**Set Executable Permissions**
```
chmod +x mysqlbackup-plus.sh
```

**Add the script to Crontab** (run daily at 3AM)
```
0 3 * * * /path/to/mysqlbackup-plus.sh
```
If you prefer not to receive email notifications with the backup status information, you can suppress them by doing:
```
0 3 * * * /path/to/mysqlbackup-plus.sh > /dev/null 2>&1
```

## ⚙️ Setup
**Create a .my.cnf file**  
This method enhances security by preventing your MySQL credentials from being exposed in command history.
```
nano ~/.my.cnf
```
**Add MySQL credentials to the file**
```
[client]
user=mysql_user_name
password=mysql_password
```
**Save and exit**  
```
If using nano, press CTRL + X, then Y, and Enter.
```

**Set file permissions** (to prevent unauthorized access)
```
chmod 600 ~/.my.cnf
```

**Run Script Manually**  
To manually execute the MySQL backup script, you can do one of the following:
```
./mysqlbackup-plus.sh
```
```
sh /path/to/mysqlbackup-plus.sh
```

**Preserve Your Settings Across Updates**  

Instead of modifying the script with each new release, ensure your configuration settings remain intact by storing them in a dedicated configuration file.

Create a file named `.mysqlbackup-plus.conf` in your HOME directory, defining only the options you wish to modify.

There is no need to include every setting, as any configurations you define in this file will override the default values in the script.

# 💾 MySQLBackupPlus
A powerful and flexible MySQL backup tool with built-in optimization features.

## ⚙️ Features

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

## 🛠️ Installation

**Download the script**
```sh
wget https://github.com/qcybb/mysqlbackup-plus/raw/main/mysqlbackup-plus.sh
```

**Set Executable Permissions**
```sh
chmod +x mysqlbackup-plus.sh
```

**Add the script to Crontab** (run daily at 3AM)
```sh
0 3 * * * /path/to/mysqlbackup-plus.sh
```
If you prefer not to receive email notifications with the backup status information, you can suppress them by doing:
```sh
0 3 * * * /path/to/mysqlbackup-plus.sh > /dev/null 2>&1
```

## 🔧 Setup
**Create a .my.cnf file**  
This method enhances security by preventing your MySQL credentials from being exposed in command history.
```sh
nano ~/.my.cnf
```
**Add MySQL credentials to the file**
```sh
[client]
user=mysql_user_name
password=mysql_password
```
**Save and exit**  
```
If using nano, press CTRL + X, then Y, and Enter.
```

**Set file permissions** (to prevent unauthorized access)
```sh
chmod 600 ~/.my.cnf
```

**Customize Your Setup**  
```
To keep your settings intact across updates, store them in a configuration file instead
of modifying this script with each new release. Create a file named .mysqlbackup-plus.conf
in your HOME directory and define your options. Any settings in this file will override the
default values set in the script.
```

**Run Script Manually**  
To manually execute the MySQL backup script, you can do one of the following:
```sh
./mysqlbackup-plus.sh
sh /path/to/mysqlbackup-plus.sh
```

#!/bin/sh

## MySQLBackupPlus - A powerful and flexible MySQL backup tool
## Copyright (C) 2025 Qcybb.com
## GitHub Repo: https://github.com/qcybb/mysqlbackup-plus
## Version: 1.3
## Last Updated: 2025-05-25

SCRIPT_VER="1.3"


# START CONFIGURATION SETTINGS

# Set where you want the backups stored (excluding a trailing slash)
BACKUP_DIR="$HOME/mysql_backups"

# Backup filename date format - (eg) /mysql_backups/daily/database_name/database_name_2025-01-01.sql
BACKUP_DATE=$(date +"%Y-%m-%d")

# Create weekly backups
BACKUP_WEEKLY="YES"

# Which day to do the weekly backup (0 = Sunday, 6 = Saturday)
WEEKLY_BACKUP_DAY=0

# Create monthly backups
BACKUP_MONTHLY="NO"

# Which day to do the monthly backup (1 - 28)
MONTHLY_BACKUP_DAY=1

# Rotate daily backups (every X days) - Set to 0 to disable rotation
ROTATE_DAYS=7

# Rotate weekly backups (every X weeks)
ROTATE_WEEKS=4

# Rotate monthly backups (every X months)
ROTATE_MONTHS=6

# Compression method: gzip, bzip2, xz, zstd, lz4 or leave blank for no compression
COMPRESS_METHOD="bzip2"

# Compression level: leave blank for default
# or use 1-9 for gzip and bzip2 ; 0-9 for xz ; 1-19 for zstd ; 1-12 for lz4   
COMPRESS_LEVEL=

# Define databases and/or tables to backup (format: db1 db2:table1 db3:table1,table2)
# or use ALL for all databases
DATABASES="ALL"

# Define excluded databases (format: db1 db2 db3)
# only works if DATABASES="ALL"
# the databases 'mysql', 'information_schema', 'performance_schema', and 'sys' are excluded by default
EXCLUDE_DATABASES=""

# Analyze InnoDB tables and optimize MyISAM tables every week
ANALYZE_OPTIMIZE_DB="NO"

# Analyze and optimize on which day (0 = Sunday, 6 = Saturday)
ANALYZE_OPTIMIZE_DAY=0

# If you want to save the output to a log file instead of being displayed, 
# choose a filename where the output will be saved. If you don’t specify the
# full file path, it will automatically be stored in your HOME directory.
LOG_FILE=""

# END CONFIGURATION SETTINGS


## DO NOT MODIFY ANYTHING BELOW THIS LINE ##


# To preserve your settings across updates, store them in a configuration file
# instead of modifying this script each time a new version is released.
# Create a file named `.mysqlbackup-plus.conf` in your HOME directory and define your options.
# Any settings in this file will override the default values listed above.
CONFIG_FILE="$HOME/.mysqlbackup-plus.conf"
if [ -r "$CONFIG_FILE" ]; then
    . "$CONFIG_FILE"    # If exists, load user defined settings
fi

# Ensure `.my.cnf` exists before continuing
if [ ! -f "$HOME/.my.cnf" ]; then
    printf "\nError: Your .my.cnf file is missing.\nPlease create it before running this script.\n\n"
    printf "In your user home directory (%s), create a file\ncalled .my.cnf and add the following to it:\n\n" "$HOME"
    printf "[client]\nuser = your_mysql_username\npassword = your_mysql_password\n\n"
    printf "In addition, secure the file so\nonly you can read and write to it:\n\n"
    printf "chmod 600 %s/.my.cnf\n\n" "$HOME"
    exit 1
fi

# Ensure backup directory exists
if [ ! -d "$BACKUP_DIR" ]; then
    mkdir -p "$BACKUP_DIR"
fi

# Create weekly backup directory (if needed)
if [ "$BACKUP_WEEKLY" = "YES" ] && [ ! -d "$BACKUP_DIR/weekly" ]; then
    mkdir -p "$BACKUP_DIR/weekly"
fi

# Create monthly backup directory (if needed)
if [ "$BACKUP_MONTHLY" = "YES" ] && [ ! -d "$BACKUP_DIR/monthly" ]; then
    mkdir -p "$BACKUP_DIR/monthly"
fi

# Determine compression level for mysqldump
EXT=".sql"  # Default to plain SQL

if [ -n "$COMPRESS_METHOD" ]; then    
    case "$COMPRESS_METHOD" in
        gzip) CMD=$(command -v gzip); EXT=".sql.gz"; LEVEL_OPT="-${COMPRESS_LEVEL:-6}" ;;
        bzip2) CMD=$(command -v bzip2); EXT=".sql.bz2"; LEVEL_OPT="-${COMPRESS_LEVEL:-9}" ;;
        xz) CMD=$(command -v xz); EXT=".sql.xz"; LEVEL_OPT="-${COMPRESS_LEVEL:-3}" ;;
        zstd) CMD=$(command -v zstd); EXT=".sql.zst"; LEVEL_OPT="-${COMPRESS_LEVEL:-3}" ;;
        lz4) CMD=$(command -v lz4); EXT=".sql.lz4"; LEVEL_OPT="-${COMPRESS_LEVEL:-1}" ;;
        *) printf "Error: Unknown compression method '%s'\n" "$COMPRESS_METHOD"; exit 1 ;;
    esac

    if [ -z "$CMD" ]; then
        printf "Error: '%s' command not found! Please install %s or check your PATH.\n" "$COMPRESS_METHOD" "$COMPRESS_METHOD"
        exit 1
    fi

    COMPRESS_CMD="$CMD -c $LEVEL_OPT"
fi

# Get the binary locations
MYSQL=$(command -v mysql)
if [ -z "$MYSQL" ]; then
    printf "Error: 'mysql' command not found! Please install MySQL or check your PATH.\n"
    exit 1
fi

MYSQLDUMP=$(command -v mysqldump)
if [ -z "$MYSQLDUMP" ]; then
    printf "Error: 'mysqldump' command not found! Please install MySQL or check your PATH.\n"
    exit 1
fi

# Log everything to a file (if enabled)
if [ -n "$LOG_FILE" ]; then
    # If LOG_FILE does not begin with a slash (absolute path), prepend $HOME/.
    case "$LOG_FILE" in
        /*) ;; # Already an absolute path; do nothing.
        *) LOG_FILE="$HOME/$LOG_FILE" ;;
    esac
    exec > "$LOG_FILE" 2>&1
fi

# Get current weekday (0 = Sunday, 6 = Saturday)
CURRENT_WEEKDAY=$(date +%w)

# Get current month day (1-31)
CURRENT_MONTHDAY=$(date +%d | sed 's/^0//')

printf "\n\nMySQLBackupPlus v%s" "$SCRIPT_VER"
printf "\nhttps://github.com/qcybb/mysqlbackup-plus\n"

# Check for updates
VERSION_URL="https://raw.githubusercontent.com/qcybb/mysqlbackup-plus/main/VERSION"

if CURL_BIN=$(command -v curl 2>/dev/null); then
    HTTP_CLIENT="$CURL_BIN"
    CLIENT_TYPE="curl"
elif WGET_BIN=$(command -v wget 2>/dev/null); then
    HTTP_CLIENT="$WGET_BIN"
    CLIENT_TYPE="wget"
else
    printf "\nPlease install curl or wget to check for updates.\n\n\n"
fi

# client has curl or wget installed
if [ -n "$CLIENT_TYPE" ]; then
    if [ "$CLIENT_TYPE" = "curl" ]; then
	LATEST_VERSION=$("$HTTP_CLIENT" -fs --connect-timeout 5 --max-time 5 "$VERSION_URL")
    else
        LATEST_VERSION=$("$HTTP_CLIENT" -q --connect-timeout=5 --timeout=5 -O - "$VERSION_URL")
    fi

    # did we receive a response
    if [ -n "$LATEST_VERSION" ]; then
        if [ "$SCRIPT_VER" != "$LATEST_VERSION" ]; then
            printf "\nUpdate available! Latest version: %s\n\n\n" "$LATEST_VERSION"
        else
            printf "\nYou are running the latest version.\n\n\n"
        fi
    else
	printf "\nCould not retrieve the latest version information from the server.\n\n\n"
    fi
fi

# Analyze and Optimze tables
if [ "$ANALYZE_OPTIMIZE_DB" = "YES" ] && [ "$CURRENT_WEEKDAY" -eq "$ANALYZE_OPTIMIZE_DAY" ]; then
    MYSQL_CMD="$MYSQL --defaults-file=$HOME/.my.cnf -Bs"

    # Get list of databases, excluding system databases
    CHECK_DATABASES=$($MYSQL_CMD -e "SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys');" | LC_ALL=C sort)

    # Exclude any databases
    if [ -n "$EXCLUDE_DATABASES" ]; then
        for EXCLUDED_DB in $EXCLUDE_DATABASES; do
            CHECK_DATABASES=$(echo "$CHECK_DATABASES" | grep -v -E "(^| )$EXCLUDED_DB( |$)")
        done
    fi

    printf "%s\n\n" "Start analyzing or optimizing databases"

    # Loop through the databases
    for DB in $CHECK_DATABASES; do
        printf "%s\n\n" "----------------------------------------"
        printf "Processing database: %s\n" "$DB"

        # Get all MyISAM tables
        MYISAM_TABLES=$($MYSQL_CMD --database="$DB" -e "SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA='$DB' AND ENGINE='MyISAM';")

        # Get all InnoDB tables
        INNODB_TABLES=$($MYSQL_CMD --database="$DB" -e "SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA='$DB' AND ENGINE='InnoDB';")

        # Optimize MyISAM tables
        if [ -n "$MYISAM_TABLES" ]; then
            printf "Optimizing MyISAM tables...\n"
            echo "$MYISAM_TABLES" | while IFS= read -r TABLE; do
                $MYSQL_CMD --database="$DB" -e "OPTIMIZE TABLE \`$TABLE\`;" | sed 's/\t/  /g'
            done
        else
            printf "No MyISAM tables found in %s.\n" "$DB"
        fi

        # Analyze InnoDB tables
        if [ -n "$INNODB_TABLES" ]; then
            printf "Analyzing InnoDB tables...\n"
            echo "$INNODB_TABLES" | while IFS= read -r TABLE; do
                $MYSQL_CMD --database="$DB" -e "ANALYZE TABLE \`$TABLE\`;" | sed 's/\t/  /g'
            done
        else
            printf "No InnoDB tables found in %s.\n" "$DB"
        fi
	printf "\n"
    done

    printf "%s\n\n" "----------------------------------------"
    printf "%s\n\n\n" "Finished analyzing or optimizing databases"
fi

# Start log entry
START_DATE=$(date +"%Y-%m-%d %I:%M:%S %p")
printf "%s\n" "========================================"
printf " Backup Started: %s\n" "$START_DATE"
printf "%s\n" "========================================"

# If ALL is set, fetch all databases
if [ "$DATABASES" = "ALL" ]; then
    DATABASES=$($MYSQL --defaults-file="$HOME/.my.cnf" -e "SHOW DATABASES;" | sed '1d' | grep -v -E "information_schema|performance_schema|mysql|sys" | LC_ALL=C sort)

    # Exclude any databases
    if [ -n "$EXCLUDE_DATABASES" ]; then
        for EXCLUDED_DB in $EXCLUDE_DATABASES; do
	    DATABASES=$(echo "$DATABASES" | grep -v -E "(^| )$EXCLUDED_DB( |$)")
        done
    fi
else
    DATABASES=$(echo "$DATABASES" | tr ' ' '\n' | LC_ALL=C sort | tr '\n' ' ')
fi

# Loop through the databases
for DB_ENTRY in $DATABASES; do
    DB_NAME=$(echo "$DB_ENTRY" | cut -d':' -f1)
    TABLES=$(echo "$DB_ENTRY" | cut -d':' -f2)

    DAILY_PATH="$BACKUP_DIR/daily/$DB_NAME"
    WEEKLY_PATH="$BACKUP_DIR/weekly/$DB_NAME"
    MONTHLY_PATH="$BACKUP_DIR/monthly/$DB_NAME"

    printf "\n%s\n\n" "----------------------------------------"
    printf "[$(date +"%I:%M:%S %p")] Processing %s...\n" "$DB_NAME"

    if [ "$TABLES" != "$DB_NAME" ]; then
        # Table-level backups
        for TABLE in $(echo "$TABLES" | tr ',' ' '); do
	    if mysql --defaults-file="$HOME/.my.cnf" --batch --skip-column-names -e "SELECT TABLE_NAME FROM information_schema.TABLES WHERE TABLE_SCHEMA='$DB_NAME' AND TABLE_NAME='$TABLE'" | grep -Fxq "$TABLE"; then
		[ ! -d "$DAILY_PATH" ] && mkdir -p "$DAILY_PATH"

		OUTPUT_FILE="$DAILY_PATH/${TABLE}_$BACKUP_DATE$EXT"
            	$MYSQLDUMP --defaults-file="$HOME/.my.cnf" "$DB_NAME" "$TABLE" | $COMPRESS_CMD > "$OUTPUT_FILE"

		printf "\n    - Table: $TABLE\n"
		printf "        -> Saved to:  ${BACKUP_DIR}/daily/${DB_NAME}/${TABLE}_${BACKUP_DATE}${EXT}\n"

            	if [ "$BACKUP_WEEKLY" = "YES" ] && [ "$CURRENT_WEEKDAY" -eq "$WEEKLY_BACKUP_DAY" ]; then
                    [ ! -d "$WEEKLY_PATH" ] && mkdir -p "$WEEKLY_PATH"
                    cp "$OUTPUT_FILE" "$WEEKLY_PATH/"
                    printf "        -> Copied to: $WEEKLY_PATH/\n"
            	fi

            	if [ "$BACKUP_MONTHLY" = "YES" ] && [ "$CURRENT_MONTHDAY" -eq "$MONTHLY_BACKUP_DAY" ]; then
                    [ ! -d "$MONTHLY_PATH" ] && mkdir -p "$MONTHLY_PATH"
                    cp "$OUTPUT_FILE" "$MONTHLY_PATH/"
                    printf "        -> Copied to: $MONTHLY_PATH/\n"
            	fi
	    else
		printf "\nError: Table '$TABLE' in database '$DB_NAME' does not exist.\n"
	    fi
        done
    else
        # Full DB backup
	if mysql --defaults-file="$HOME/.my.cnf" --batch --skip-column-names -e "SELECT SCHEMA_NAME FROM information_schema.SCHEMATA WHERE SCHEMA_NAME='$DB_NAME'" | grep -Fxq "$DB_NAME"; then
	    [ ! -d "$DAILY_PATH" ] && mkdir -p "$DAILY_PATH"

	    OUTPUT_FILE="$DAILY_PATH/${DB_NAME}_$BACKUP_DATE$EXT"
	    $MYSQLDUMP --defaults-file="$HOME/.my.cnf" "$DB_NAME" | $COMPRESS_CMD > "$OUTPUT_FILE"

	    printf "\n    - Full Database\n"
	    printf "        -> Saved to:  ${BACKUP_DIR}/daily/${DB_NAME}/${DB_NAME}_${BACKUP_DATE}${EXT}\n"


            if [ "$BACKUP_WEEKLY" = "YES" ] && [ "$CURRENT_WEEKDAY" -eq "$WEEKLY_BACKUP_DAY" ]; then
                [ ! -d "$WEEKLY_PATH" ] && mkdir -p "$WEEKLY_PATH"
                cp "$OUTPUT_FILE" "$WEEKLY_PATH/"
                printf "        -> Copied to: $WEEKLY_PATH/\n"
            fi

            if [ "$BACKUP_MONTHLY" = "YES" ] && [ "$CURRENT_MONTHDAY" -eq "$MONTHLY_BACKUP_DAY" ]; then
                [ ! -d "$MONTHLY_PATH" ] && mkdir -p "$MONTHLY_PATH"
                cp "$OUTPUT_FILE" "$MONTHLY_PATH/"
                printf "        -> Copied to: $MONTHLY_PATH/\n"
            fi
	else
	    printf "\nError: Database '$DB_NAME' does not exist.\n"
	fi
    fi
done

printf "\n%s\n" "----------------------------------------"

# Rotate daily backups
if [ "$ROTATE_DAYS" -gt 0 ]; then
    DELETED_FILES=$(find "$BACKUP_DIR/daily" -type f -mtime +"$ROTATE_DAYS" -print)

    if [ -n "$DELETED_FILES" ]; then
        find "$BACKUP_DIR/daily" -type f -mtime +"$ROTATE_DAYS" -exec rm "{}" \;
        
        UNIT="day"
        [ "$ROTATE_DAYS" -gt 1 ] && UNIT="days"

        printf "\n[$(date +"%I:%M:%S %p")] Rotating daily backups... (Keeping last $ROTATE_DAYS $UNIT)\n"

	COUNT=$(echo "$DELETED_FILES" | wc -l)
	LABEL="Deleted file"
	[ "$COUNT" -gt 1 ] && LABEL="Deleted files"

	printf "\n$LABEL:\n$DELETED_FILES\n"
    fi
fi

# Rotate weekly backups
if [ "$BACKUP_WEEKLY" = "YES" ] && [ "$ROTATE_WEEKS" -gt 0 ]; then
    DELETED_FILES=$(find "$BACKUP_DIR/weekly" -type f -mtime +"$((ROTATE_WEEKS * 7))" -print)

    if [ -n "$DELETED_FILES" ]; then
        find "$BACKUP_DIR/weekly" -type f -mtime +"$((ROTATE_WEEKS * 7))" -exec rm "{}" \;

        UNIT="week"
        [ "$ROTATE_WEEKS" -gt 1 ] && UNIT="weeks"

        printf "\n[$(date +"%I:%M:%S %p")] Rotating weekly backups... (Keeping last $ROTATE_WEEKS $UNIT)\n"

        COUNT=$(echo "$DELETED_FILES" | wc -l)
        LABEL="Deleted file"
        [ "$COUNT" -gt 1 ] && LABEL="Deleted files"

        printf "\n$LABEL:\n$DELETED_FILES\n"
    fi
fi

# Rotate monthly backups
if [ "$BACKUP_MONTHLY" = "YES" ] && [ "$ROTATE_MONTHS" -gt 0 ]; then
    DELETED_FILES=$(find "$BACKUP_DIR/monthly" -type f -mtime +"$((ROTATE_MONTHS * 30))" -print)

    if [ -n "$DELETED_FILES" ]; then
        find "$BACKUP_DIR/monthly" -type f -mtime +"$((ROTATE_MONTHS * 30))" -exec rm "{}" \;

        UNIT="month"
        [ "$ROTATE_MONTHS" -gt 1 ] && UNIT="months"

        printf "\n[$(date +"%I:%M:%S %p")] Rotating monthly backups... (Keeping last $ROTATE_MONTHS $UNIT)\n"

        COUNT=$(echo "$DELETED_FILES" | wc -l)
        LABEL="Deleted file"
        [ "$COUNT" -gt 1 ] && LABEL="Deleted files"

        printf "\n$LABEL:\n$DELETED_FILES\n"
    fi
fi

# End log entry
END_DATE=$(date +"%Y-%m-%d %I:%M:%S %p")
printf "\n%s\n" "=========================================="
printf " Backup Completed: %s\n" "$END_DATE"
printf "%s\n\n" "=========================================="

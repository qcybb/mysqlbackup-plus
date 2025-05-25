#!/bin/sh

## MySQLBackupPlus - A powerful and flexible MySQL backup tool
## Copyright (C) 2025 Qcybb.com
## GitHub: https://github.com/qcybb/mysqlbackup-plus/
## Version: 1.0.0
## Last Updated: 2025-05-21


# START CONFIGURATION SETTINGS

# Set where you want the backups stored (excluding a trailing slash)
BACKUP_DIR="$HOME/mysql_backups"

# Backup filename date format - (eg) /mysql_backups/daily/database_name/database_name_2025-01-01.sql
BACKUP_DATE=$(date +"%Y-%m-%d")

# Create weekly backups
BACKUP_WEEKLY="NO"

# Which day to do the weekly backup (0 = Sunday, 7 = Saturday)
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
COMPRESS_METHOD="gzip"

# Compression level: leave blank for default
# or use 1-9 for gzip and bzip2 ; 0-9 for xz ; 1-19 for zstd ; 1-12 for lz4   
COMPRESS_LEVEL=

# Define databases and/or tables to backup (format: db1 db2:table1 db3:table1,table2)
# or use ALL for all databases
DATABASES="anagrams:english"

# Define excluded databases (format: db1 db2 db3)
# only works if DATABASES="ALL"
# the databases 'mysql', 'information_schema', 'performance_schema', and 'sys' are excluded by default
EXCLUDE_DATABASES=""

# Analyze InnoDB tables and optimize MyISAM tables every week
ANALYZE_OPTIMIZE_DB="NO"

# Analyze and optimize on which day (0 = Sunday, 7 = Saturday)
ANALYZE_OPTIMIZE_DAY=0

# END CONFIGURATION SETTINGS


## DO NOT MODIFY ANYTHING BELOW THIS LINE ##

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
    
    if [ "$COMPRESS_METHOD" = "gzip" ]; then
        GZIP=$(command -v gzip)
	if [ -z "$GZIP" ]; then
	    echo "Error: 'gzip' command not found! Please install gzip or check your PATH."
            exit 1
	fi
    fi

    if [ "$COMPRESS_METHOD" = "bzip2" ]; then
	BZIP2=$(command -v bzip2)
        if [ -z "$BZIP2" ]; then
            echo "Error: 'bzip2' command not found! Please install bzip2 or check your PATH."
            exit 1
        fi
    fi

    if [ "$COMPRESS_METHOD" = "xz" ]; then
        XZ=$(command -v xz)
        if [ -z "$XZ" ]; then
            echo "Error: 'xz' command not found! Please install xz or check your PATH."
            exit 1
        fi
    fi

    if [ "$COMPRESS_METHOD" = "zstd" ]; then
	ZSTD=$(command -v zstd)
        if [ -z "$ZSTD" ]; then
            echo "Error: 'zstd' command not found! Please install zstd or check your PATH."
            exit 1
        fi
    fi

    if [ "$COMPRESS_METHOD" = "lz4" ]; then
	LZ4=$(command -v lz4)
        if [ -z "$LZ4" ]; then
            echo "Error: 'lz4' command not found! Please install lz4 or check your PATH."
            exit 1
        fi
    fi

    case "$COMPRESS_METHOD" in
        "gzip") COMPRESS_CMD="$GZIP -c -${COMPRESS_LEVEL:-6}"; EXT=".sql.gz" ;;
        "bzip2") COMPRESS_CMD="$BZIP2 -c -${COMPRESS_LEVEL:-9}"; EXT=".sql.bz2" ;;
        "xz") COMPRESS_CMD="$XZ -c -${COMPRESS_LEVEL:-3}"; EXT=".sql.xz" ;;
	"zstd") COMPRESS_CMD="$ZSTD -c -${COMPRESS_LEVEL:-3}"; EXT=".sql.zst" ;;
	"lz4") COMPRESS_CMD="$LZ4 -c -${COMPRESS_LEVEL:-1}"; EXT=".sql.lz4" ;;
	*) printf "Unknown compression method: %s\n" "$COMPRESS_METHOD"; exit 1 ;;
    esac
fi

# Get the binary locations
MYSQL=$(command -v mysql)
if [ -z "$MYSQL" ]; then
    echo "Error: 'mysql' command not found! Please install MySQL or check your PATH."
    exit 1
fi

MYSQLDUMP=$(command -v mysqldump)
if [ -z "$MYSQLDUMP" ]; then
    echo "Error: 'mysqldump' command not found! Please install MySQL or check your PATH."
    exit 1
fi

# Get current weekday (0 = Sunday, 6 = Saturday)
CURRENT_WEEKDAY=$(date +%w)

# Get current month day (1-31)
CURRENT_MONTHDAY=$(date +%d | sed 's/^0//')

# Analyze and Optimze tables
if [ "$ANALYZE_OPTIMIZE_DB" = "YES" ] && [ "$CURRENT_WEEKDAY" -eq "$ANALYZE_OPTIMIZE_DAY" ]; then
    MYSQL_CMD="$MYSQL --defaults-file=$HOME/.my.cnf -Bs"

    # Get list of databases, excluding system databases
    CHECK_DATABASES=$($MYSQL_CMD -e "SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys');")

    printf "Start analyzing or optimizing databases\n\n"

    # Loop through the databases
    for DB in $CHECK_DATABASES; do
        printf "%s\n" "----------------------------------------"
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
    done

    printf "%s\n" "----------------------------------------"
    printf "\nFinished analyzing or optimizing databases\n\n"
fi

# Start log entry
START_DATE=$(date +"%Y-%m-%d %I:%M:%S %p")
printf "%s\n" "========================================"
printf " Backup Started: %s\n" "$START_DATE"
printf "%s\n" "========================================"

# If ALL is set, fetch all databases
if [ "$DATABASES" = "ALL" ]; then
    DATABASES=$($MYSQL --defaults-file="$HOME/.my.cnf" -e "SHOW DATABASES;" | sed '1d' | grep -v -E "information_schema|performance_schema|mysql|sys")

    # Exclude any databases
    if [ -n "$EXCLUDE_DATABASES" ]; then
        for EXCLUDED_DB in $EXCLUDE_DATABASES; do
	    DATABASES=$(echo "$DATABASES" | grep -v -E "(^| )$EXCLUDED_DB( |$)")
        done
    fi
fi

# Loop through the databases
for DB_ENTRY in $DATABASES; do
    DB_NAME=$(echo "$DB_ENTRY" | cut -d':' -f1)
    TABLES=$(echo "$DB_ENTRY" | cut -d':' -f2)

    printf "\n----------------------------------------\n"
    printf "[$(date +"%I:%M:%S %p")] Processing %s...\n" "$DB_NAME"

    if [ "$TABLES" != "$DB_NAME" ]; then
        # Table-level backups
        for TABLE in $(echo "$TABLES" | tr ',' ' '); do
            DAILY_PATH="$BACKUP_DIR/daily/$DB_NAME"
            WEEKLY_PATH="$BACKUP_DIR/weekly/$DB_NAME"
            MONTHLY_PATH="$BACKUP_DIR/monthly/$DB_NAME"

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
        done
    else
        # Full DB backup
        DAILY_PATH="$BACKUP_DIR/daily/$DB_NAME"
        WEEKLY_PATH="$BACKUP_DIR/weekly/$DB_NAME"
        MONTHLY_PATH="$BACKUP_DIR/monthly/$DB_NAME"

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
    fi
    printf "%s\n" "----------------------------------------"
done

# Rotate daily backups
if [ "$ROTATE_DAYS" -gt 0 ]; then
    DELETED_FILES=$(find "$BACKUP_DIR/daily" -type f -mtime +"$ROTATE_DAYS" -print)

    if [ -n "$DELETED_FILES" ]; then
        find "$BACKUP_DIR" -type f -mtime +"$ROTATE_DAYS" -exec rm "{}" \;
        
        UNIT="day"
        [ "$ROTATE_DAYS" -gt 1 ] && UNIT="days"

        printf "\n[$(date +"%I:%M:%S %p")] Rotating daily backups... (Keeping last $ROTATE_DAYS $UNIT)\n"
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
    fi
fi

# End log entry
END_DATE=$(date +"%Y-%m-%d %I:%M:%S %p")
printf "\n%s\n" "=========================================="
printf " Backup Completed: %s\n" "$END_DATE"
printf "%s\n" "=========================================="

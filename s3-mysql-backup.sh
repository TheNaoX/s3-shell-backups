#!/bin/sh

#### BEGIN CONFIGURATION ####

# set dates for backup rotation
NOWDATE=`date +%Y-%m-%d`
LASTDATE=$(date +%Y-%m-%d --date='1 week ago')

# set backup directory variables
SRCDIR='/tmp/s3backups'
DESTDIR='bucket-folder'
BUCKET='bucket'

# mysql access details
HOST='127.0.0.1'
USER='backupuser'
PASS='backuppass'

#### END CONFIGURATION ####

# repair, optimize, and dump each database to its own sql file
for DB in $(mysql -u$USER -p$PASS -BNe 'show databases' | grep -Ev 'mysql|information_schema|performance_schema')
do
mysqlcheck -h$HOST -u$USER -p$PASS --auto-repair --optimize $DB
mysqldump -h$HOST -u$USER -p$PASS --quote-names --create-options --force $DB > /$SRCDIR/$DB.sql
done

# tar all the databases into $NOWDATE-backups.tar.gz
tar -czPf $SRCDIR/$NOWDATE-backup.tar.gz $SRCDIR/*.sql

# upload all databases
/usr/bin/s3cmd put $SRCDIR/$NOWDATE-backup.tar.gz s3://$BUCKET/$DESTDIR/

# rotate out old backups
/usr/bin/s3cmd del --recursive s3://$BUCKET/$DESTDIR/$LASTDATE-backup.tar.gz

# remove all local dumps
rm -f $SRCDIR/$NOWDATE-backup.tar.gz

for FILE in $(echo $(ls $SRCDIR/))
do
rm -f $SRCDIR/$FILE
done
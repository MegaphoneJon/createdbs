#!/bin/sh
# 
#start in the directory you want to create it in or specify -r

USER=jon
GROUP=www-dev
DOCIVI=1
CLIENTNAME=
ROOTDIR=`pwd`
DEBUG=0
DRUSHMAKEFILE=/tmp/`pwgen 15 1`
DRUPALDBSETTINGSFILE=/tmp/`pwgen 15 1`
APACHECONFIGFILE=
DOMAINNAME=
#used when the APACHECONFIGFILE isn't set
APACHEFILEPATH=/etc/apache2/sites-available/
password=`pwgen 15 1`

usage () {
  echo "createdbs [options] -n clientname"
  echo
  echo "        -h or --help            This help screen"
  echo "        -n or --name		client name"
  echo "        --no-civi		create Drupal database but not Civi database"
  echo "        -r or --root-dir	Specify the directory in which to create the filesystem.  Defaults to current directory."
  echo "        -u or --user		Specify the owner of the files in the filesystem"
  echo "        -g or --group		Specify the group owner of the files in the filesystem"
  echo "        -a or --apache-config	Specify the name of the Apache config file"
  echo "        -d or --domain-name	Specify the domain name for the Apache config file"
  echo "	--makefile		Specify a drush makefile"
  echo "	--debug			Show debug messages"
  echo "	--delete		Delete the databases (beta)"
}
sanitychecks () {

}
createdrupal () {
  if [ "$DEBUG" -eq 1 ]; then echo DEBUG: Creating Drupal database and user; fi
  mysqladmin create $CLIENTNAME'_drupal'
  mysql -e 'GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, INDEX, ALTER, LOCK TABLES, CREATE TEMPORARY TABLES ON `'$CLIENTNAME'_drupal`.* TO '\'$CLIENTNAME\''@'\''localhost'\'' IDENTIFIED BY '\'$password\'';'
}

createcivi () {
  if [ "$DEBUG" -eq 1 ]; then echo DEBUG: Creating Civi database and user; fi
  mysqladmin create $CLIENTNAME'_civi'
  mysql -e 'GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, INDEX, ALTER, LOCK TABLES, CREATE TEMPORARY TABLES, TRIGGER, CREATE ROUTINE, ALTER ROUTINE ON `'$CLIENTNAME'_civi`.* TO '\'$CLIENTNAME\''@'\''localhost'\'' IDENTIFIED BY '\'$password\'';'	
}

createfiles () {
  if [ "$DEBUG" -eq 1 ]; then echo DEBUG: Creating directory; fi
  cd $ROOTDIR
  mkdir $CLIENTNAME
  chown $USER:$GROUP $CLIENTNAME
  chmod g+w $CLIENTNAME
  cd $CLIENTNAME
  drush make $DRUSHMAKEFILE
  chown -R $USER:$GROUP .
  chmod -R g+w . 
  cp ./sites/default/default.settings.php ./sites/default/settings.php
  chmod g+w ./sites/default/settings.php
  chown :$GROUP ./sites/default/settings.php
}

createdrushmake () {
  echo '' > $DRUSHMAKEFILE
  echo 'core = 7.x' >> $DRUSHMAKEFILE
  echo 'api = 2' >> $DRUSHMAKEFILE
  echo 'projects[] = drupal' >> $DRUSHMAKEFILE
  echo 'projects[] = views' >> $DRUSHMAKEFILE
  if [ "$DEBUG" -eq 1 ]; then echo 'DEBUG: drush make file:' $DRUSHMAKEFILE; fi
}

createdrupaldbsettings () {
  echo '' > $DRUPALDBSETTINGSFILE
  echo '$databases = array (' >> $DRUPALDBSETTINGSFILE
  echo "  'default' =>" >> $DRUPALDBSETTINGSFILE
  echo '  array (' >> $DRUPALDBSETTINGSFILE
  echo "    'default' =>" >> $DRUPALDBSETTINGSFILE
  echo '    array (' >> $DRUPALDBSETTINGSFILE
  echo "      'database' => '"$CLIENTNAME"_drupal'," >> $DRUPALDBSETTINGSFILE
  echo "      'username' => '$CLIENTNAME'," >> $DRUPALDBSETTINGSFILE
  echo "      'password' => '$password'," >> $DRUPALDBSETTINGSFILE
  echo "      'host' => 'localhost'," >> $DRUPALDBSETTINGSFILE
  echo "      'port' => ''," >> $DRUPALDBSETTINGSFILE
  echo "      'driver' => 'mysql'," >> $DRUPALDBSETTINGSFILE
  echo "      'prefix' => ''," >> $DRUPALDBSETTINGSFILE
  echo '    ),' >> $DRUPALDBSETTINGSFILE
  echo '  ),' >> $DRUPALDBSETTINGSFILE
  echo ');' >> $DRUPALDBSETTINGSFILE

  #cat everything into a temp file.
  TEMPSETTINGSFILE=/tmp/`pwgen 15 1`
  head -n 1 $ROOTDIR/$CLIENTNAME/sites/default/settings.php > $TEMPSETTINGSFILE
  cat $DRUPALDBSETTINGSFILE >> $TEMPSETTINGSFILE
  tail -n +2 $ROOTDIR/$CLIENTNAME/sites/default/settings.php >> $TEMPSETTINGSFILE
  cat $TEMPSETTINGSFILE > $ROOTDIR/$CLIENTNAME/sites/default/settings.php

  if [ "$DEBUG" -eq 1 ]; then echo 'DEBUG: temp drupal db settings file:' $TEMPSETTINGSFILE; fi
  if [ "$DEBUG" -eq 1 ]; then echo 'DEBUG: drupal db settings file:' $DRUPALDBSETTINGSFILE; fi
}

createapacheconfig () {
  if [ -z $DOMAINNAME ]; then DOMAINNAME=$CLIENTNAME.local; fi
  if [ "$DEBUG" -eq 1 ]; then echo DEBUG: Creating Apache config file: $APACHECONFIGFILE; fi

  echo '<VirtualHost *:80>' > $APACHECONFIGFILE
  echo '  DocumentRoot /var/www/'$CLIENTNAME >> $APACHECONFIGFILE
  echo '  ServerName '$DOMAINNAME >> $APACHECONFIGFILE
  echo '' >> $APACHECONFIGFILE
  echo '<Directory "/var/www/'$CLIENTNAME'">' >> $APACHECONFIGFILE
  echo '  AllowOverride All' >> $APACHECONFIGFILE
  echo '  order allow,deny' >> $APACHECONFIGFILE
  echo '  allow from all' >> $APACHECONFIGFILE
  echo '  Options -Indexes' >> $APACHECONFIGFILE
  echo '</Directory>' >> $APACHECONFIGFILE
  echo '</VirtualHost>' >> $APACHECONFIGFILE
  #enable the site, reload Apache
  a2ensite `basename $APACHECONFIGFILE`
  service apache2 reload
}

delete () {
  if [ "$DEBUG" -eq 1 ]; then echo DEBUG: Deleting database and filesystem; fi
  'mysqladmin drop '$CLIENTNAME'_civi'
  'mysqladmin drop '$CLIENTNAME'_drupal'
  mysql mysql -e 'DELETE FROM user WHERE User = '\'$CLIENTNAME\'';'
  rm $APACHECONFIGFILE
  cd $ROOTDIR
  rm -r $CLIENTNAME
}

#process options
while [ $# -gt 0 ]; do
  case "$1" in
    -h | --help | -help )
      usage
      exit 0 ;;
    -n | --name )
      shift 
      if [ -z $1 ]; then
        echo "-n or --name must be followed by a client name." >&2
        exit
      else
        CLIENTNAME=$1
      fi
      shift ;;
    --no-civi )
      shift
      DOCIVI=0 ;;
    -u | --user )
     shift 
      if [ -z $1 ]; then
        echo "-u or --user must be followed by a user name or uid." >&2
        exit
      else
        USER=$1
      fi
      shift ;;
    -g | --group )
     shift 
      if [ -z $1 ]; then
        echo "-g or --group must be followed by a group name or gid." >&2
        exit
      else
        GROUP=$1
      fi
      shift ;;
    -r | --root-dir )
     shift 
      if [ -z "$1" ]; then
        echo "-r or --root-dir must be followed by a directory path." >&2
        exit
      elif [ ! -d "$1" ]; then
        echo "root directory does not exist or is not a directory." >&2
        exit
      else
        ROOTDIR=$1
      fi
      shift ;;
    --makefile )
     shift 
      if [ -z "$1" ]; then
        echo "--makefile must be followed by a file name." >&2
        exit
      elif [ ! -f "$1" ]; then
        echo "makefile does not exist." >&2
        exit
      else
        ROOTDIR=$1
      fi
      shift ;;
    -a | --apache-config )
     shift 
      if [ -z $1 ]; then
        echo "-a must be followed by a full path to an Apache config file." >&2
        exit
      else
        APACHECONFIGFILE=$1
      fi
      shift ;;
    -d | --domain-name )
     shift 
      if [ -z $1 ]; then
        echo "-d or --domain-name must be followed by a domain name." >&2
        exit
      else
        DOMAINNAME=$1
      fi
      shift ;;
    --debug )
      shift
      DEBUG=1 ;;
    -h | --help | -help )
      usage
      exit 0 ;;
    --delete )
      DELETEMODE=1
      shift ;;
    -- ) # Stop option processing
      shift
      break ;;
    * )
      break ;;
  esac
done

#check for required options
if [ -z $CLIENTNAME ] 
then
  echo "you must specify a client name with -n or --name"
  echo "Example: createdbs.sh -n pth"
  echo "Use createdbs.sh --help for more info"
  exit
fi

#set APACHECONFIGFILE if it's not set.
if [ -z "$APACHECONFIGFILE" ]; then APACHECONFIGFILE=$APACHEFILEPATH$CLIENTNAME.local; fi


if [ "$DELETEMODE" -eq 1 ]; then
  delete
  exit
fi
createdrupal
if [ "$DOCIVI" -ne 0 ]; then
  createcivi
fi
createdrushmake
createfiles
#createdrupaldbsettings
createapacheconfig


#for binary logging, add this line:
#mysql -e 'GRANT SUPER ON *.* TO '\'$CLIENTNAME\''@'\''localhost'\'';'	

mysql -e 'FLUSH PRIVILEGES;'
echo
echo 'Database credentials:'
echo 'user: '$CLIENTNAME
echo 'pw: '$password
#echo 'GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, INDEX, ALTER, LOCK TABLES, CREATE TEMPORARY TABLES, SHOW VIEW ON `'$1_civi'`.* TO '\'$1\''@'\''localhost'\'' IDENTIFIED BY '\'$password\'';'	

#echo 'GRANT SUPER ON *.* TO '\'$1\''@'\''localhost'\'';'
# alternately put this in /etc/my.cnf:
# log_bin_trust_function_creators = 1

#TODO:
#* replace passwords (and other settings) on Drupal/Civi stuff in settings.php and civicrm.settings.php 
#* create DNS config
#* create options for git

#******************************************************************************
# variables
#******************************************************************************
node_id=$1
my_name=$2
my_ip=$3
peer_name=$4
peer_ip=$5
REPMGR_PASSWORD=reppasswd
PGHOME=/var/lib/pgsql
PGDATA=$PGHOME/9.5/data


#******************************************************************************
# hosts
#******************************************************************************
echo "$my_ip $my_name" >> /etc/hosts
echo "$peer_ip $peer_name" >> /etc/hosts

#******************************************************************************
# timezone
#******************************************************************************
timedatectl set-timezone Asia/Tokyo

#******************************************************************************
# install packages
#******************************************************************************
yum -y install https://download.postgresql.org/pub/repos/yum/9.5/redhat/rhel-7-x86_64/pgdg-centos95-9.5-2.noarch.rpm
yum -y install postgresql95-server repmgr95 barman

#******************************************************************************
# PATH
#******************************************************************************
cat <<EOD > /etc/profile.d/pgsql.sh
PATH=/usr/pgsql-9.5/bin:\$PATH
alias pglog="tail -f /var/lib/pgsql/9.5/data/pg_log/postgresql-$(date +%a).log"
EOD

#******************************************************************************
# ssh config
#******************************************************************************
if [ ! -f /vagrant/id_ecdsa ] ; then
  ssh-keygen -t ecdsa -P "" -f /vagrant/id_ecdsa
fi
install -d $PGHOME/.ssh -o postgres -g postgres -m 0700
install -o postgres -g postgres -m 0600 /vagrant/id_ecdsa $PGHOME/.ssh/
install -o postgres -g postgres -m 0644 /vagrant/id_ecdsa.pub $PGHOME/.ssh/authorized_keys
echo "StrictHostKeyChecking no" > $PGHOME/.ssh/config

#******************************************************************************
# initdb & start PostgreSQL
#******************************************************************************
if [ "$node_id" = "1" ] ; then
  PGSETUP_INITDB_OPTIONS="--no-locale --encoding=UTF-8 --data-checksums" /usr/pgsql-9.5/bin/postgresql95-setup initdb
  install -d $PGHOME/9.5/backups/archive -o postgres -g postgres -m 0700
  systemctl start postgresql-9.5
fi

#******************************************************************************
# repmgr
#******************************************************************************
if [ "$node_id" = "1" ] ; then
  echo "CREATE ROLE repmgr SUPERUSER LOGIN PASSWORD '$REPMGR_PASSWORD';" | su -l postgres -c psql
  echo 'ALTER USER repmgr SET search_path TO repmgr_mycluster, "$user", public;' | su -l postgres -c psql
  su -l postgres -c "/usr/pgsql-9.5/bin/createdb -O repmgr repmgr"
  sed -e "s/{{peer_ip}}/$peer_ip/" \
      -e "s/{{my_ip}}/$my_ip/" \
    /vagrant/pg_hba.conf > $PGDATA/pg_hba.conf

  conf=$PGDATA/postgresql.conf
  sed -i -r \
    -e "s/^#?(listen_addresses) =.*/\1 = '*'/" \
    -e "s/^#?(max_wal_senders) =.*/\1 = 10/" \
    -e "s/^#?(wal_level) =.*/\1 = hot_standby/" \
    -e "s/^#?(hot_standby) =.*/\1 = on/" \
    -e "s/^#?(archive_mode) =.*/\1 = on/" \
    -e "s,^#?(archive_command) =.*,\1 = '/bin/true'," \
    -e "s,^#?(wal_keep_segments) =.*,\1 = 5000," \
    -e "s,^#?(log_timezone) =.*,\1 = 'Asia/Tokyo'," \
    -e "s,^#?(timezone) =.*,\1 = 'Asia/Tokyo'," \
    -e "s,^#?(restart_after_crash) =.*,\1 = off," $conf

  systemctl restart postgresql-9.5
fi

cat <<EOD > /etc/repmgr/9.5/repmgr.conf
cluster=mycluster
node=$node_id
node_name=$my_name
conninfo='host=$my_name user=repmgr password=$REPMGR_PASSWORD dbname=repmgr'
pg_bindir=/usr/pgsql-9.5/bin/
ssh_options=-o "StrictHostKeyChecking no"
EOD

if [ "$node_id" = "1" ] ; then
  su -l postgres -c "/usr/pgsql-9.5/bin/repmgr -f /etc/repmgr/9.5/repmgr.conf master register"
elif [ "$node_id" = "2" ] ; then
  su -l postgres -c "/usr/pgsql-9.5/bin/repmgr -f /etc/repmgr/9.5/repmgr.conf -h $peer_name -U repmgr -d repmgr -D $PGDATA standby clone"
  systemctl restart postgresql-9.5
  su -l postgres -c "/usr/pgsql-9.5/bin/repmgr -f /etc/repmgr/9.5/repmgr.conf standby register"
fi

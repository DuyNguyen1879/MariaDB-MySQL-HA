#!/bin/sh

CONFIG="mariadb.domain.com"
VM=`cat /etc/hostname`

printf "\n>>>\n>>> WORKING ON: $VM ...\n>>>\n\n>>>\n>>> (STEP 1/4) Configuring system ...\n>>>\n\n\n"
sleep 5
sed -ri 's/127\.0\.0\.1\s.*/127.0.0.1 localhost localhost.localdomain/' /etc/hosts
echo 'root:mariadb' | chpasswd
sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config && service sshd restart
sed -i 's/SELINUX=enforcing/SELINUX=disabled/' /etc/sysconfig/selinux
echo 0 > /sys/fs/selinux/enforce

printf "\n>>>\n>>> (STEP 2/4) Installing MariaDB ...\n>>>\n\n"
sleep 5
yum install -y mariadb-server mariadb
cp /sources/$CONFIG/master2.cnf /etc/my.cnf.d/
systemctl start mariadb && systemctl enable mariadb
mysql_secure_installation <<EOF

y
mariadb
mariadb
y
y
y
y
EOF

printf "\n>>>\n>>> (STEP 3/4) Configuring MariaDB ...\n>>>\n\n"
sleep 5
mysql -uroot -pmariadb -e 'CREATE DATABASE zabbix;' \
-e "GRANT ALL PRIVILEGES ON zabbix.* TO 'zabbix'@'%' IDENTIFIED BY 'zabbix';" \
-e 'FLUSH PRIVILEGES;'
mysql -uroot -pmariadb zabbix < /sources/$CONFIG/create.sql
mysql -uroot -pmariadb -e 'STOP SLAVE;' \
-e "GRANT REPLICATION SLAVE ON *.* TO 'zabbix'@'%' IDENTIFIED BY 'zabbix';" \
-e 'FLUSH PRIVILEGES;' \
-e 'FLUSH TABLES WITH READ LOCK;'
mysql -uroot -pmariadb -e 'SHOW MASTER STATUS\g' > /sources/$CONFIG/master2_status
#give root remote access from other cluster members
mysql -uroot -pmariadb -e "GRANT ALL PRIVILEGES ON *.* TO 'root'@'mariadb-master1.domain.com' IDENTIFIED BY 'mariadb' WITH GRANT OPTION;"
#Disable automatic launch of mariadb.service
systemctl disable mariadb.service

printf "\n>>>\n>>> (STEP 4/4) Installing Pacemaker & Corosync ...\n>>>\n\n"
sleep 5
yum install -y pacemaker pcs
echo "hacluster:hacluster" | chpasswd
systemctl start pcsd
for SERVICE in pcsd corosync pacemaker; do systemctl enable $SERVICE; done


printf "\n>>>\n>>> Finished bootstrapping $VM\n>>>\n\n>>> MariaDB is reachable via:\n>>> USERNAME: root\n>>> PASSWORD: mariadb\n"

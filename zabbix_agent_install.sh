#!/bin/bash

# Envs
# ---------------------------------------------------\
PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin
SCRIPT_PATH=$(cd `dirname "${BASH_SOURCE[0]}"` && pwd)

# Additions
# ---------------------------------------------------\
Info() {
	printf "\033[1;32m$@\033[0m\n"
}

Error()
{
	printf "\033[1;31m$@\033[0m\n"
}

isRoot() {
	if [ $(id -u) -ne 0 ]; then
		Error "You must be root user to continue"
		exit 1
	fi
	RID=$(id -u root 2>/dev/null)
	if [ $? -ne 0 ]; then
		Error "User root no found. You should create it to continue"
		exit 1
	fi
	if [ $RID -ne 0 ]; then
		Error "User root UID not equals 0. User root must have UID 0"
		exit 1
	fi
}

isRoot

# Vars
# ---------------------------------------------------\
SERVER_IP=$1
HOST_NAME=$(hostname)
HOST_IP=$(hostname -I | cut -d' ' -f1)
PASS="$(openssl rand -base64 12)"

# Secure agent
PSKIdentity=${HOST_NAME%.*.*}
TLSType="psk"
RAND_PREFIX="-$TLSType-prefix-$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 12 | head -n 1)"

if [[ -f /etc/zabbix/zabbix_agent*.conf ]]; then
	echo "Zabbix agent already installed!"
	exit 1
fi

if [ -z "$1" ]; then
    Error "\nPlease call '$0 <Zabbix Server IP>' to run this command!\n"
    exit 1
fi

# Installation
# ---------------------------------------------------\

# Only run it on (RHEL/CentOS)

if [ -x /usr/bin/yum ] & [ $(cat /etc/os-release  | awk 'NR==2 {print $1}'| grep -i -o '7') ==  "7" ] ; then

yum install epel-release -y
rpm -Uvh https://repo.zabbix.com/zabbix/5.0/rhel/7/x86_64/zabbix-release-5.0-1.el7.noarch.rpm
yum clean all

yum install zabbix-agent -y
# yum install zabbix-agent2 -y # for zabbix-agent to zabbix-agent2

# For PHP-FPM Monitoring
yum install unzip grep gawk lsof jq fcgi -y

  # For Pending Update Monitoring (RHEL/CentOS)
  wget https://github.com/yigitgokcu/zabbix-template-check-updates-linux/archive/master.zip -O /tmp/zabbix-template-check-updates.zip
  unzip -j /tmp/zabbix-template-check-updates.zip -d /tmp/zabbix-template-check-updates
  cp /tmp/zabbix-template-check-updates/userparameter_checkupdates.conf $(find /etc/zabbix/ -name zabbix_agentd*.d -type d | head -n1)
  rm -rf /tmp/zabbix-template-check-updates*

  # Add CronJob (RHEL/CentOS)
  (crontab -u root -l; echo "0 4 * * * yum check-update --quiet | grep '^[a-Z0-9]' | wc -l > /var/lib/zabbix/zabbix.count.updates" ) | crontab -u root - 

elif [ -x /usr/bin/dnf ] & [ $(cat /etc/os-release  | awk 'NR==2 {print $1}'| grep -i -o '8') ==  "8" ] ; then

dnf install epel-release -y
rpm -Uvh https://repo.zabbix.com/zabbix/5.0/rhel/8/x86_64/zabbix-release-5.0-1.el8.noarch.rpm
dnf clean all

dnf install zabbix-agent -y
# yum install zabbix-agent2 -y # for zabbix-agent to zabbix-agent2

# For PHP-FPM Monitoring
dnf install unzip grep gawk lsof jq fcgi -y

  # For Pending Update Monitoring (RHEL/CentOS)
  wget https://github.com/yigitgokcu/zabbix-template-check-updates-linux/archive/master.zip -O /tmp/zabbix-template-check-updates.zip
  unzip -j /tmp/zabbix-template-check-updates.zip -d /tmp/zabbix-template-check-updates
  cp /tmp/zabbix-template-check-updates/userparameter_checkupdates.conf $(find /etc/zabbix/ -name zabbix_agentd*.d -type d | head -n1)
  rm -rf /tmp/zabbix-template-check-updates*

  # Add CronJob (RHEL/CentOS)
  (crontab -u root -l; echo "0 4 * * * yum check-update --quiet | grep '^[a-Z0-9]' | wc -l > /var/lib/zabbix/zabbix.count.updates" ) | crontab -u root -

fi

# Only run it on (Ubuntu/Debian)

if [ -x /usr/bin/apt-get ] & [ $(cat /etc/os-release  | awk 'NR==2 {print $3}'| grep -i -o xenial) ==  "Xenial" ] ; then
  
  wget https://repo.zabbix.com/zabbix/5.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_5.0-1+xenial_all.deb 
  dpkg -i zabbix-release_5.0-1+xenial_all.deb
  apt-get update
  apt install zabbix-agent -y

  # For PHP-FPM Monitoring
  apt-get -y install unzip grep gawk lsof jq libfcgi0ldbl
  
  # Remove UFW and install Firewalld
  # apt remove ufw -y && apt purge ufw -y
  # apt install firewalld -y
  
  # Delete unnecessary files
  rm -rf zabbix-release_*

  # For Pending Update Monitoring (Ubuntu/Debian)
  wget https://github.com/yigitgokcu/zabbix-template-check-updates-linux/archive/master.zip -O /tmp/zabbix-template-check-updates.zip
  unzip -j /tmp/zabbix-template-check-updates.zip -d /tmp/zabbix-template-check-updates
  cp /tmp/zabbix-template-check-updates/userparameter_checkupdates.conf $(find /etc/zabbix/ -name zabbix_agentd*.d -type d | head -n1)
  rm -rf /tmp/zabbix-template-check-updates*

  # Add CronJob (Ubuntu/Debian)
  (crontab -u root -l; echo "0 4 * * * sudo /usr/bin/apt-get upgrade -s | grep -P '^\d+ upgraded' | cut -d" " -f1 > /var/lib/zabbix/zabbix.count.updates" ) | crontab -u root - 

elif [ -x /usr/bin/apt-get ] & [ $(cat /etc/os-release  | awk 'NR==2 {print $3}'| grep -i -o bionic) ==  "Bionic" ]; then

  wget https://repo.zabbix.com/zabbix/5.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_5.0-1+bionic_all.deb
  dpkg -i zabbix-release_5.0-1+bionic_all.deb
  apt-get update

  apt install zabbix-agent -y
  # apt install zabbix-agent2 -y # for zabbix-agent to zabbix-agent2

  # For PHP-FPM Monitoring
  apt-get -y install grep gawk lsof jq libfcgi0ldbl
  
  # Remove UFW and install Firewalld
  # apt remove ufw -y && apt purge ufw -y
  # apt install firewalld -y
  
  # Delete unnecessary files
  rm -rf zabbix-release_*

  # For Pending Update Monitoring (Ubuntu/Debian)
  wget https://github.com/yigitgokcu/zabbix-template-check-updates-linux/archive/master.zip -O /tmp/zabbix-template-check-updates.zip
  unzip -j /tmp/zabbix-template-check-updates.zip -d /tmp/zabbix-template-check-updates
  cp /tmp/zabbix-template-check-updates/userparameter_checkupdates.conf $(find /etc/zabbix/ -name zabbix_agentd*.d -type d | head -n1)
  rm -rf /tmp/zabbix-template-check-updates*

  # Add CronJob (Ubuntu/Debian)
  (crontab -u root -l; echo "0 4 * * * sudo /usr/bin/apt-get upgrade -s | grep -P '^\d+ upgraded' | cut -d " " -f1 > /var/lib/zabbix/zabbix.count.updates" ) | crontab -u root - 
fi

# Configure local zabbix agent
sed -i "s/^\(Server=\).*/\1"$SERVER_IP"/" /etc/zabbix/zabbix_agent*.conf
sed -i "s/^\(ServerActive\).*/\1="$SERVER_IP"/" /etc/zabbix/zabbix_agent*.conf
sed -i "s/^\(Hostname\).*/\1="$HOST_NAME"/" /etc/zabbix/zabbix_agent*.conf

# Creating Directories
mkdir /var/lib/zabbix
mkdir /var/lib/zabbix/scripts
chown -R zabbix:zabbix /var/lib/zabbix/

# Configure firewalld
# ---------------------------------------------------\
echo -en "Do you want to configure Firewalld (y/n)? "
read answer
if echo "$answer" | grep -iq "^y" ;then
    echo "Configuring..."

firewall-cmd --permanent --zone=public --add-rich-rule 'rule family="ipv4" source address="'$SERVER_IP'" port protocol="tcp" port="10050" accept'
firewall-cmd --reload

    echo -e "Done."

else
      echo -e "Nothing to do."
fi

# Enable and start agent
# ---------------------------------------------------\
systemctl enable zabbix-agent && systemctl start zabbix-agent
# systemctl enable zabbix-agent2 && systemctl start zabbix-agent2 # for agent version 2

# PSK
# TLSConnect=psk
# TLSAccept=psk
# TLSPSKIdentity=psk001
# TLSPSKFile=/etc/zabbix/zabbix_agent.psk
# ---------------------------------------------------\
echo -en "Do you want to secure agent? (y/n)? "
read answer
if echo "$answer" | grep -iq "^y" ;then
    echo "Generating PSK..."

    sh -c "openssl rand -hex 32 > /etc/zabbix/zabbix_agent.psk"

    sed -i 's/# TLSConnect=.*/TLSConnect=psk/' /etc/zabbix/zabbix_agent*.conf
    sed -i 's/# TLSAccept=.*/TLSAccept=psk/' /etc/zabbix/zabbix_agent*.conf
    sed -i 's/# TLSPSKFile=.*/TLSPSKFile=\/etc\/zabbix\/zabbix_agent.psk/' /etc/zabbix/zabbix_agent*.conf
    sed -i "s/# TLSPSKIdentity=.*/TLSPSKIdentity="$PSKIdentity$RAND_PREFIX"/" /etc/zabbix/zabbix_agent*.conf

    systemctl restart zabbix-agent
    # systemctl restart zabbix-agent2 # for agent version 2

    Info "PSK - $(cat /etc/zabbix/zabbix_agent.psk)"
    Info "PSKIdentity - $PSKIdentity$RAND_PREFIX"

else
      echo -e "Ok, you agent is will be insecure..."
fi

# Active agent (EnableRemoteCommands)
echo -en "Do you want to enable active agent feature? (y/n)? "
read answer
if echo "$answer" | grep -iq "^y" ;then
    echo "Enabling active agent..."

    sed -i 's/DenyKey=.*/# DenyKey=system.run[*]/' /etc/zabbix/zabbix_agent*.conf
    sed -i 's/# Plugins.SystemRun.LogRemoteCommands=.*/Plugins.SystemRun.LogRemoteCommands=1/' /etc/zabbix/zabbix_agent*.conf
    sed -i 's/# LogRemoteCommands=.*/LogRemoteCommands=1/' /etc/zabbix/zabbix_agent*.conf
    sed -i 's/# User=zabbix.*/User=zabbix/' /etc/zabbix/zabbix_agent*.conf # not working with agent version 2
    sed -i 's/# Timeout=3.*/Timeout=30/' /etc/zabbix/zabbix_agent*.conf

else
      echo -e "Nothing to do."
fi
# For MySQL Monitoring
echo -en "Do you want MySQL monitoring? (y/n)? "
read answer
if echo "$answer" | grep -iq "^y" ;then
    echo "Creating necessary files and MySQL User..."

    touch /var/lib/zabbix/.my.cnf

    echo "[client]
    user=zabbix
    password=$PASS" >> /var/lib/zabbix/.my.cnf

    chown -R zabbix:zabbix /var/lib/zabbix/.my.cnf
    
    wget https://github.com/yigitgokcu/zabbix-template-mysql-galera_cluster-linux/archive/master.zip -O /tmp/zabbix-mysql.zip
    unzip -j /tmp/zabbix-mysql.zip -d /tmp/zabbix-mysql
    cp /tmp/zabbix-mysql/userparameter_mysql.conf $(find /etc/zabbix/ -name zabbix_agentd*.d -type d | head -n1)
    rm -rf /tmp/zabbix-mysql*
    
    mysql -e "CREATE USER 'zabbix'@'localhost' IDENTIFIED BY '$PASS';"
    mysql -e "GRANT ALL PRIVILEGES ON *.* TO 'zabbix'@'localhost';"
    mysql -e "FLUSH PRIVILEGES;"

    echo "Done."

else
      echo -e "Nothing to do."
fi

# For NGINX Monitoring
echo -en "Do you want NGINX monitoring? (y/n)? "
read answer
if echo "$answer" | grep -iq "^y" ;then
    echo "Creating necessary files..."

    wget https://github.com/yigitgokcu/zabbix-template-nginx-linux/archive/master.zip -O /tmp/zabbix-nginx.zip
    unzip -j /tmp/zabbix-nginx.zip -d /tmp/zabbix-nginx
    cp /tmp/zabbix-nginx/statistics.conf /etc/nginx/conf.d/ && service nginx restart
    rm -rf /tmp/zabbix-nginx*
     
    echo "Done."

else
    echo -e "Nothing to do."

fi    

# For PHP-FPM Monitoring
echo -en "Do you want PHP-FPM monitoring? (y/n)? "
read answer
if echo "$answer" | grep -iq "^y" ;then
    echo "Creating necessary files..."

    wget https://github.com/yigitgokcu/zabbix-template-phpfpm-linux/archive/master.zip -O /tmp/zabbix-php-fpm.zip
    unzip -j /tmp/zabbix-php-fpm.zip -d /tmp/zabbix-php-fpm
    cp /tmp/zabbix-php-fpm/userparameter_php_fpm.conf $(find /etc/zabbix/ -name zabbix_agentd*.d -type d | head -n1)
    cp /tmp/zabbix-php-fpm/zabbix_php_fpm_*.sh /var/lib/zabbix/scripts/
    cp /tmp/zabbix-php-fpm/statistics.conf /etc/nginx/conf.d/ && service nginx restart
    chown -R zabbix:zabbix /var/lib/zabbix/scripts/zabbix_php_fpm_*.sh
    chmod +x /var/lib/zabbix/scripts/zabbix_php_fpm_*.sh
    rm -rf /tmp/zabbix-php-fpm*
    
    #Grant privileges to the PHP-FPM auto discovery script only
    echo 'zabbix ALL = NOPASSWD: /var/lib/zabbix/scripts/zabbix_php_fpm_discovery.sh' >> /etc/sudoers
    echo 'zabbix ALL = NOPASSWD: /var/lib/zabbix/scripts/zabbix_php_fpm_status.sh' >> /etc/sudoers

    echo "Done."

else
    echo -e "Nothing to do."

fi    

# For Cpanel Monitoring
echo -en "Do you want Cpanel monitoring? (y/n)? "
read answer
if echo "$answer" | grep -iq "^y" ;then
    echo "Creating necessary files..."

wget https://github.com/yigitgokcu/zabbix-template-cpanel-linux/archive/master.zip -O /tmp/zabbix-template-cpanel-linux.zip
unzip -j /tmp/zabbix-template-cpanel-linux.zip -d /tmp/zabbix-template-cpanel-linux
cp /tmp/zabbix-template-cpanel-linux/userparameter_cpanel.conf  $(find /etc/zabbix/ -name zabbix_agentd*.d -type d | head -n1)
cp /tmp/zabbix-template-cpanel-linux/zabbix_exim-* /var/lib/zabbix/scripts/
rm -rf /tmp/zabbix-template-cpanel-linux*
chown -R zabbix:zabbix /var/lib/zabbix/scripts/zabbix_exim-*
chmod a+x /var/lib/zabbix/scripts/zabbix_exim-*

echo 'zabbix ALL=(ALL) NOPASSWD: /usr/sbin/exim -bp' >> /etc/sudoers
echo 'zabbix ALL=(ALL) NOPASSWD: /usr/sbin/whmapi1' >> /etc/sudoers
echo 'zabbix ALL=(ALL) NOPASSWD: /var/lib/zabbix/scripts/zabbix_exim-delete-frozen.sh' >> /etc/sudoers
echo 'zabbix ALL=(ALL) NOPASSWD: /var/lib/zabbix/scripts/zabbix_exim-find-spammer.py' >> /etc/sudoers

    echo "Done."

else
    echo -e "Nothing to do."

fi    

# For Advanced Disk Monitoring
echo -en "Do you want advanced disk monitoring? (y/n)? "
read answer
if echo "$answer" | grep -iq "^y" ;then
    echo "Creating necessary files..."

wget https://github.com/yigitgokcu/zabbix-template-disk-perfomance-linux/archive/master.zip -O /tmp/zabbix-disk-performance.zip
unzip -j /tmp/zabbix-disk-performance -d /tmp/zabbix-disk-performance
cp /tmp/zabbix-disk-performance/userparameter_check_disk_stat.conf  $(find /etc/zabbix/ -name zabbix_agentd*.d -type d | head -n1)
cp /tmp/zabbix-disk-performance/zabbix_check_disk_stat.py /var/lib/zabbix/scripts/
rm -rf /tmp/zabbix-disk-performance*
chown -R zabbix:zabbix /var/lib/zabbix/scripts/zabbix_check_disk_stat.py
chmod a+x /var/lib/zabbix/scripts/zabbix_check_disk_stat.py

    echo "Done."

else
    echo -e "Nothing to do."

fi

# For Postfix Monitoring
echo -en "Do you want Postfix monitoring? (y/n)? "
read answer
if echo "$answer" | grep -iq "^y" ;then
    echo "Creating necessary files..."

wget https://github.com/yigitgokcu/zabbix-template-postfix-linux/archive/master.zip -O /tmp/zabbix-postfix.zip
unzip -j /tmp/zabbix-postfix.zip -d /tmp/zabbix-postfix
cp /tmp/zabbix-postfix/userparamater_postfix.conf  $(find /etc/zabbix/ -name zabbix_agentd*.d -type d | head -n1)
cp /tmp/zabbix-postfix/pygtail.py /var/lib/zabbix/scripts/
cp /tmp/zabbix-postfix/zabbix-postfix-stats.sh /var/lib/zabbix/scripts/
rm -rf /tmp/zabbix-postfix*
chown -R zabbix:zabbix /var/lib/zabbix/scripts/zabbix-postfix-stats.sh
chmod a+x /var/lib/zabbix/scripts/zabbix-postfix-stats.sh
chown -R zabbix:zabbix /var/lib/zabbix/scripts/pygtail.py 
chmod a+x /var/lib/zabbix/scripts/pygtail.py


# Grant privileges to the script only
echo 'zabbix  ALL=(ALL) NOPASSWD: /var/lib/zabbix/scripts/zabbix-postfix-stats.sh' >> /etc/sudoers  


    echo "Done."

else
    echo -e "Nothing to do."

fi

# We can add more choice for service monitoring in here.
# ---------------------------------------------------\

systemctl restart zabbix-agent
# systemctl restart zabbix-agent2 # for agent version 2

# Final
# ---------------------------------------------------\
echo -e ""
Info "Done!"
Info "Zabbix Agent Status: $(systemctl status zabbix-agent | awk 'NR==3')"
# Info "Zabbix Agent Status: $(systemctl status zabbix-agent2 | awk 'NR==3')" # for agent version 2
Info "Now, you must add this host to your Zabbix server in the Configuration > Hosts area"
Info "This server IP - $HOST_IP"
Info "This server name - $HOST_NAME"

# Self Destruct
rm $0

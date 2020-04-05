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

if [[ -f /etc/zabbix/zabbix_agentd.conf ]]; then
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

if [ -x /usr/bin/yum ]; then

yum install epel-release -y
rpm -Uvh https://repo.zabbix.com/zabbix/4.4/rhel/7/x86_64/zabbix-release-4.4-1.el7.noarch.rpm
yum clean all

yum install zabbix-agent -y
fi

# Only run it on (Ubuntu/Debian)

if [ -x /usr/bin/apt-get ] & [ $(cat /etc/os-release  | awk 'NR==2 {print $3}'| grep -i -o xenial) ==  "Xenial" ] ; then
  
  wget https://repo.zabbix.com/zabbix/4.4/ubuntu/pool/main/z/zabbix-release/zabbix-release_4.4-1+xenial_all.deb 
  dpkg -i zabbix-release_4.4-1+xenial_all.deb
  
elif [ -x /usr/bin/apt-get ] & [ $(cat /etc/os-release  | awk 'NR==2 {print $3}'| grep -i -o bionic) ==  "Bionic" ]; then
  wget wget https://repo.zabbix.com/zabbix/4.4/ubuntu/pool/main/z/zabbix-release/zabbix-release_4.4-1+bionic_all.deb
  dpkg -i zabbix-release_4.4-1+bionic_all.deb

  apt-get update
  apt install zabbix-agent -y
  apt remove ufw -y && apt purge ufw -y
  apt install firewalld -y
  rm -rf zabbix-release_*

fi

# Configure local zabbix agent
sed -i "s/^\(Server=\).*/\1"$SERVER_IP"/" /etc/zabbix/zabbix_agentd.conf
sed -i "s/^\(ServerActive\).*/\1="$SERVER_IP"/" /etc/zabbix/zabbix_agentd.conf
sed -i "s/^\(Hostname\).*/\1="$HOST_NAME"/" /etc/zabbix/zabbix_agentd.conf

# Creating Directories
mkdir /var/lib/zabbix
mkdir /var/lib/zabbix/scripts
chown -R zabbix:zabbix /var/lib/zabbix

# Configure firewalld
# ---------------------------------------------------\
firewall-cmd --permanent --zone=public --add-rich-rule 'rule family="ipv4" source address="$SERVER_IP" port protocol="tcp" port="10050" accept'
firewall-cmd --reload

# Enable and start agent
# ---------------------------------------------------\
systemctl enable zabbix-agent && systemctl start zabbix-agent

# PSK
# TLSConnect=psk
# TLSAccept=psk
# TLSPSKIdentity=psk001
# TLSPSKFile=/etc/zabbix/zabbix_agentd.psk
# ---------------------------------------------------\
echo -en "Secure agent? (y/n)? "
read answer
if echo "$answer" | grep -iq "^y" ;then
    echo "Generate PSK..."

    sh -c "openssl rand -hex 32 > /etc/zabbix/zabbix_agentd.psk"

    sed -i 's/# TLSConnect=.*/TLSConnect=psk/' /etc/zabbix/zabbix_agentd.conf
    sed -i 's/# TLSAccept=.*/TLSAccept=psk/' /etc/zabbix/zabbix_agentd.conf
    sed -i 's/# TLSPSKFile=.*/TLSPSKFile=\/etc\/zabbix\/zabbix_agentd.psk/' /etc/zabbix/zabbix_agentd.conf
    sed -i "s/# TLSPSKIdentity=.*/TLSPSKIdentity="$PSKIdentity$RAND_PREFIX"/" /etc/zabbix/zabbix_agentd.conf

    systemctl restart zabbix-agent

    Info "PSK - $(cat /etc/zabbix/zabbix_agentd.psk)"
    Info "PSKIdentity - $PSKIdentity$RAND_PREFIX"

else
      echo -e "Ok, you agent is will be insecure..."
fi

# Active agent (EnableRemoteCommands)
echo -en "Enable active agent feature? (y/n)? "
read answer
if echo "$answer" | grep -iq "^y" ;then
    echo "Enable active agent..."

    sed -i 's/# EnableRemoteCommands=.*/EnableRemoteCommands=1/' /etc/zabbix/zabbix_agentd.conf
    sed -i 's/# LogRemoteCommands=.*/LogRemoteCommands=1/' /etc/zabbix/zabbix_agentd.conf
    sed -i 's/# User=zabbix.*/User=zabbix/' /etc/zabbix/zabbix_agentd.conf
    sed -i 's/# Timeout=3.*/Timeout=30/' /etc/zabbix/zabbix_agentd.conf

else
      echo -e "Ok."
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
    
    mysql -e "CREATE USER zabbix@localhost IDENTIFIED BY '$PASS';"
    mysql -e "GRANT ALL PRIVILEGES ON *.* TO 'zabbix'@'localhost';"
    mysql -e "FLUSH PRIVILEGES;"

    echo "Files and MySQL user created."

else
      echo -e "Ok."
fi

# We can add more choice for service monitoring in here.
# ---------------------------------------------------\

systemctl restart zabbix-agent

# Final
# ---------------------------------------------------\
echo -e ""
Info "Done!"
Info "$(systemctl status zabbix-agent | awk 'NR==3')"
Info "Now, you must add this host to your Zabbix server in the Configuration > Hosts area"
Info "This server ip - $HOST_IP"
Info "This server name - $HOST_NAME"
rm $0

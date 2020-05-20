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

if [ -x /usr/bin/yum ]; then

# systemctl stop zabbix-agent # for zabbix-agent to zabbix-agent2
# yum remove zabbix-agent -y # for zabbix-agent to zabbix-agent2

yum install epel-release -y
rpm -Uvh https://repo.zabbix.com/zabbix/5.0/rhel/7/x86_64/zabbix-release-5.0-1.el7.noarch.rpm
yum clean all

yum upgrade zabbix-agent -y # for zabbix-agent v4.4 to v5.0
# yum install zabbix-agent2 -y # for zabbix-agent to zabbix-agent2
# mv /etc/zabbix/zabbix_agentd.d/* /etc/zabbix/zabbix_agent2.d/ # for zabbix-agent to zabbix-agent2

# Delete unnecessary files
# rm -rf /etc/zabbix/zabbix_agentd /etc/zabbix/zabbix_agentd.conf # for zabbix-agent to zabbix-agent2
rm -rf /etc/zabbix/zabbix_agentd.conf.rpmnew 

fi
# Only run it on (Ubuntu/Debian)

if [ -x /usr/bin/apt-get ] & [ $(cat /etc/os-release  | awk 'NR==2 {print $3}'| grep -i -o xenial) ==  "Xenial" ] ; then
  
  wget https://repo.zabbix.com/zabbix/5.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_5.0-1+xenial_all.deb 
  dpkg -i zabbix-release_5.0-1+xenial_all.deb
  apt-get update
  apt-get install --only-upgrade zabbix-agent -y

  # Delete unnecessary files
  rm -rf zabbix-release_* 
  rm -rf /etc/zabbix/zabbix_agentd.conf.rpmnew 

elif [ -x /usr/bin/apt-get ] & [ $(cat /etc/os-release  | awk 'NR==2 {print $3}'| grep -i -o bionic) ==  "Bionic" ]; then

  # systemctl stop zabbix-agent # for zabbix-agent to zabbix-agent2
  # apt remove zabbix-agent # for zabbix-agent to zabbix-agent2
  wget https://repo.zabbix.com/zabbix/5.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_5.0-1+bionic_all.deb
  dpkg -i zabbix-release_5.0-1+bionic_all.deb
  apt-get update
  apt upgrade zabbix-agent -y # for zabbix-agent v4.4 to v5.0
 # apt install zabbix-agent2 -y # for zabbix-agent to zabbix-agent2
 # mv /etc/zabbix/zabbix_agentd.d/* /etc/zabbix/zabbix_agent2.d/ # for zabbix-agent to zabbix-agent2

  # Delete unnecessary files
  rm -rf zabbix-release_*
 # rm -rf /etc/zabbix/zabbix_agentd /etc/zabbix/zabbix_agentd.conf # for zabbix-agent to zabbix-agent2
  rm -rf /etc/zabbix/zabbix_agentd.conf.rpmnew
fi

# Configure local zabbix agent
sed -i "s/^\(Server=\).*/\1"$SERVER_IP"/" /etc/zabbix/zabbix_agent*.conf
sed -i "s/^\(ServerActive\).*/\1="$SERVER_IP"/" /etc/zabbix/zabbix_agent*.conf
sed -i "s/^\(Hostname\).*/\1="$HOST_NAME"/" /etc/zabbix/zabbix_agent*.conf 

# Enable and start agent
# ---------------------------------------------------\
systemctl enable zabbix-agent* && systemctl start zabbix-agent*

# PSK
# TLSConnect=psk
# TLSAccept=psk
# TLSPSKIdentity=psk001
# TLSPSKFile=/etc/zabbix/zabbix_agentd.psk
# ---------------------------------------------------\
echo -en "Secure agent? (y/n)? "
read answer
if echo "$answer" | grep -iq "^y" ;then
    echo "Generating PSK..."

    sh -c "openssl rand -hex 32 > /etc/zabbix/zabbix_agent.psk"

    sed -i 's/# TLSConnect=.*/TLSConnect=psk/' /etc/zabbix/zabbix_agent*.conf
    sed -i 's/# TLSAccept=.*/TLSAccept=psk/' /etc/zabbix/zabbix_agent*.conf
    sed -i 's/# TLSPSKFile=.*/TLSPSKFile=\/etc\/zabbix\/zabbix_agent.psk/' /etc/zabbix/zabbix_agent*.conf
    sed -i "s/# TLSPSKIdentity=.*/TLSPSKIdentity="$PSKIdentity$RAND_PREFIX"/" /etc/zabbix/zabbix_agent*.conf

    systemctl restart zabbix-agent*

    Info "PSK - $(cat /etc/zabbix/zabbix_agent.psk)"
    Info "PSKIdentity - $PSKIdentity$RAND_PREFIX"

else
      echo -e "Ok, you agent is will be insecure..."
fi

# Active agent (EnableRemoteCommands)
echo -en "Enabling active agent feature? (y/n)? "
read answer
if echo "$answer" | grep -iq "^y" ;then
    echo "Enabling active agent..."

    sed -i 's/DenyKey=.*/# DenyKey=system.run[*]/' /etc/zabbix/zabbix_agent*.conf
    sed -i 's/# Plugins.SystemRun.LogRemoteCommands=.*/Plugins.SystemRun.LogRemoteCommands=1/' /etc/zabbix/zabbix_agent*.conf
    sed -i 's/# User=zabbix.*/User=zabbix/' /etc/zabbix/zabbix_agent*.conf
    sed -i 's/# Timeout=3.*/Timeout=30/' /etc/zabbix/zabbix_agent*.conf

else
      echo -e "Nothing to do."
fi

systemctl restart zabbix-agent*

# Final
# ---------------------------------------------------\
echo -e ""
Info "Done!"
Info "Zabbix Agent Status: $(systemctl status zabbix-agent* | awk 'NR==3')"
Info "Now, you must add this host to your Zabbix server in the Configuration > Hosts area"
Info "This server IP - $HOST_IP"
Info "This server name - $HOST_NAME"

# Self Destruct
rm $0

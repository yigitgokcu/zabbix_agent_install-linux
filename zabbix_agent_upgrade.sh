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


if [ -z "$1" ]; then
    Error "\nPlease call '$0 <Zabbix Server IP>' to run this command!\n"
    exit 1
fi

# Installation
# ---------------------------------------------------\

# Only run it on (RHEL/CentOS)

if [ -x /usr/bin/yum ] & [[ $(cat /etc/os-release  | awk 'NR==2 {print $1}'| grep -i -o '7') == "7" ]] ; then

# Backup current zabbix_agentd.conf
mv $(find /etc/zabbix/ -name zabbix_agentd*.conf -type f | head -n1) /etc/zabbix/zabbix_agentd.conf.rpmsave

# systemctl stop zabbix-agent # from zabbix-agent to zabbix-agent2
# yum remove zabbix-agent -y # from zabbix-agent to zabbix-agent2

yum install epel-release -y
rpm -Uvh https://repo.zabbix.com/zabbix/5.2/rhel/7/x86_64/zabbix-release-5.2-1.el7.noarch.rpm
yum clean all

yum upgrade zabbix-agent -y # from any version to v5.2
# yum install zabbix-agent2 -y # from zabbix-agent to zabbix-agent2
# mv /etc/zabbix/zabbix_agentd.d/* /etc/zabbix/zabbix_agent2.d/ # from zabbix-agent to zabbix-agent2

elif [ -x /usr/bin/dnf ] & [[ $(cat /etc/os-release  | awk 'NR==2 {print $1}'| grep -i -o '7') == "8" ]] ; then

# Backup current zabbix_agentd.conf
mv $(find /etc/zabbix/ -name zabbix_agentd*.conf -type f | head -n1) /etc/zabbix/zabbix_agentd.conf.rpmsave

# systemctl stop zabbix-agent # from zabbix-agent to zabbix-agent2
# dnf remove zabbix-agent -y # from zabbix-agent to zabbix-agent2

dnf install epel-release -y
rpm -Uvh  https://repo.zabbix.com/zabbix/5.2/rhel/8/x86_64/zabbix-release-5.2-1.el8.noarch.rpm
dnf clean all

dnf upgrade zabbix-agent -y # from any version to v5.2
# dnf install zabbix-agent2 -y # from zabbix-agent to zabbix-agent2
# mv /etc/zabbix/zabbix_agentd.d/* /etc/zabbix/zabbix_agent2.d/ # from zabbix-agent to zabbix-agent2

fi

# Only run it on (Ubuntu)

if [ -x /usr/bin/apt-get ] & [[ $(cat /etc/os-release  | awk 'NR==2 {print $3}'| grep -i -o xenial) == "Xenial" ]] ; then
  
  wget https://repo.zabbix.com/zabbix/5.2/ubuntu/pool/main/z/zabbix-release/zabbix-release_5.2-1+ubuntu16.04_all.deb 
  dpkg -i zabbix-release_5.2-1+ubuntu16.04_all.deb


  apt-get update
  apt-get install --only-upgrade zabbix-agent -y

  # Delete unnecessary files
  rm -rf zabbix-release_* 

elif [ -x /usr/bin/apt-get ] & [[ $(cat /etc/os-release  | awk 'NR==2 {print $3}'| grep -i -o bionic) == "Bionic" ]] ; then

  # systemctl stop zabbix-agent # from zabbix-agent to zabbix-agent2
  # apt remove zabbix-agent # from zabbix-agent to zabbix-agent2

  wget https://repo.zabbix.com/zabbix/5.2/ubuntu/pool/main/z/zabbix-release/zabbix-release_5.2-1+ubuntu18.04_all.deb
  dpkg -i zabbix-release_5.2-1+ubuntu18.04_all.deb

  apt-get update
  apt upgrade zabbix-agent -y # from any version to v5.2
 # apt install zabbix-agent2 -y # from zabbix-agent to zabbix-agent2
 # mv /etc/zabbix/zabbix_agentd.d/* /etc/zabbix/zabbix_agent2.d/ # from zabbix-agent to zabbix-agent2

  # Delete unnecessary files
  rm -rf zabbix-release_*

elif [ -x /usr/bin/apt-get ] & [[ $(cat /etc/os-release  | awk 'NR==2 {print $3}'| grep -i -o focal) == "Focal" ]] ; then
 
 # systemctl stop zabbix-agent # from zabbix-agent to zabbix-agent2
 # apt remove zabbix-agent # from zabbix-agent to zabbix-agent2

  wget https://repo.zabbix.com/zabbix/5.2/ubuntu/pool/main/z/zabbix-release/zabbix-release_5.2-1+ubuntu20.04_all.deb
  dpkg -i zabbix-release_5.2-1+ubuntu20.04_all.deb

  apt-get update
  apt upgrade zabbix-agent -y # from any version to v5.2
 # apt install zabbix-agent2 -y # from zabbix-agent to zabbix-agent2
 # mv /etc/zabbix/zabbix_agentd.d/* /etc/zabbix/zabbix_agent2.d/ # from zabbix-agent to zabbix-agent2

  # Delete unnecessary files
  rm -rf zabbix-release_*
fi

# Configure local zabbix agent
sed -i "s/^\(Server=\).*/\1"$SERVER_IP"/" /etc/zabbix/zabbix_agent*.conf
sed -i "s/^\(ServerActive\).*/\1="$SERVER_IP"/" /etc/zabbix/zabbix_agent*.conf
sed -i "s/^\(Hostname\).*/\1="$HOST_NAME"/" /etc/zabbix/zabbix_agent*.conf 

# Enable and start agent
# ---------------------------------------------------\
systemctl enable zabbix-agent && systemctl start zabbix-agent
# systemctl enable zabbix-agent2 && systemctl start zabbix-agent2 # for zabbix-agent2

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

    systemctl restart zabbix-agent
    # systemctl restart zabbix-agent2 # for zabbix-agent to zabbix-agent2

    Info "PSK - $(cat /etc/zabbix/zabbix_agent.psk)"
    Info "PSKIdentity - $PSKIdentity$RAND_PREFIX"

else
      echo -e "Ok, your agent will be insecure..."
fi

# EnableRemoteCommands
echo -en "Do you want to enable remote commands (y/n)? "
read answer
if echo "$answer" | grep -iq "^y" ;then
    echo "Enabling remote commands..."

    sed -i 's/DenyKey=.*/# DenyKey=system.run[*]/' /etc/zabbix/zabbix_agent*.conf
    sed -i 's/# Plugins.SystemRun.LogRemoteCommands=.*/Plugins.SystemRun.LogRemoteCommands=1/' /etc/zabbix/zabbix_agent*.conf
    sed -i 's/# LogRemoteCommands=.*/LogRemoteCommands=1/' /etc/zabbix/zabbix_agent*.conf
    sed -i 's/# User=zabbix.*/User=zabbix/' /etc/zabbix/zabbix_agent*.conf # not working with agent version 2
    sed -i 's/# Timeout=3.*/Timeout=30/' /etc/zabbix/zabbix_agent*.conf
else
      echo -e "Nothing to do."
fi

systemctl restart zabbix-agent
# systemctl restart zabbix-agent2 # for zabbix-agent2

# Delete backup files
echo -en "Do you want to delete zabbix_agentd.conf backup files (y/n)? "
read answer
if echo "$answer" | grep -iq "^y" ;then
    echo "Deleting..."
    # rm -rf /etc/zabbix/zabbix_agentd /etc/zabbix/zabbix_agentd.conf # from zabbix-agent to zabbix-agent2
    rm -rf /etc/zabbix/zabbix_agent*.conf.rpmnew 
    rm -rf /etc/zabbix/zabbix_agent*.conf.dpkg-dist-*
else
      echo -e "Nothing to do."
fi

# Final
# ---------------------------------------------------\
echo -e ""
Info "Done!"
Info "Zabbix Agent Status: $(systemctl status zabbix-agent | awk 'NR==3')"
# Info "Zabbix Agent Status: $(systemctl status zabbix-agent2 | awk 'NR==3')" # for agent version 2
Info "Now, you must add this host to your Zabbix server in the Configuration > Hosts area"
Info "This server IP - $HOST_IP"
Info "This server name - $HOST_NAME"

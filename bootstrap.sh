#!/usr/bin/env bash

# config data
# files should be the root directory i.e. available under /vagrant
USER_NAME="raoul"
PASSWORD="s3cret"
DISTRO="CentOS-6.4-x86_64-bin-DVD1.iso"
# download from http://nginx.org/packages/centos/6/x86_64/RPMS/
# or modify script to download rpm using wget/curl
NGINX="nginx-1.4.2-1.el6.ngx.x86_64.rpm"

# nothing below needs to be changed.

function setupUsers() {
	grep -q "$USER_NAME" /etc/passwd
	if [[ $? -eq 1  ]]; then
		echo "Adding user $USER_NAME"
		useradd -m "$USER_NAME"
		echo "$PASSWORD" | passwd --stdin "$USER_NAME"
		echo "$USER_NAME ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
		echo "$PASSWORD" | passwd --stdin vagrant
	else
		echo "Skipping... users already setup"
	fi
}


function setupFileSystem() {
	if [[ -e /vagrant/"$DISTRO" ]]; then
		echo "Mounting /vagrant/$DISTRO to /mnt/"
		mount -o loop /vagrant/"$DISTRO" /mnt/
	else
		echo "Unable to mount CentOS distro"
	fi
	
}


function configureYum() {
	grep -q base-local /etc/yum.conf
if [[ $? -eq 1  ]]; then
	echo "Adding [base-local] to yum.conf"
	cat >> /etc/yum.conf<<EOF
[base-local]
name=CentOS 6.4 x86_64 base
failovermethod=priority
baseurl=file:///mnt/
enabled=1
gpgcheck=0
EOF
else
	echo "Skipping... /etc/yum.conf contains [base-local]"
fi


if [[ ! -e /etc/yum.repos.d/CentOS-Base.repo.disabled ]]; then
	echo "Disabling /etc/yum.repos.d/CentOS-Base.repo"
	mv /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.disabled
else
	echo "Skipping... CentOS-Base.repo is disabled"
fi
}


function installNginx() {
	if [[ ! -e /etc/init.d/nginx ]]; then
		echo "Installing nginx"
		rpm -ivh /vagrant/"$NGINX"
		echo "Updating nginx.conf"
		sed -i "/http {/ a\server { listen 80; location /mnt { autoindex on; root /; }}" /etc/nginx/nginx.conf
		service nginx start
		echo "Updating chkconfig for nginx"
		chkconfig --level 2345 nginx on
	else
		echo "Skipping... nginx is installed"
	fi
}


function configureIptables() {
	if [[ ! -e /home/vagrant/iptables.rules ]]; then
	echo "Configuring iptables"
	cat > /home/vagrant/iptables.rules<<EOF
*filter
:INPUT ACCEPT [0:0]
:FORWARD ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
-A INPUT -p tcp -m tcp --dport 80   -j ACCEPT
-A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
-A INPUT -p icmp -j ACCEPT
-A INPUT -i lo -j ACCEPT
-A INPUT -m state --state NEW -m tcp -p tcp --dport 22 -j ACCEPT
-A INPUT -j REJECT --reject-with icmp-host-prohibited
-A FORWARD -j REJECT --reject-with icmp-host-prohibited
COMMIT
EOF
echo "Restoring iptables"
iptables-restore < /home/vagrant/iptables.rules
else
	echo "Skipping... iptables already setup"
fi

grep -q iptables /etc/rc.local
if [[ $? -eq 1 ]]; then
	echo "Add iptables to system boot"
	echo "iptables-restore < /home/vagrant/iptables.rules" >> /etc/rc.local
else
	echo "Skipping... /etc/rc.local contains iptables entry"
fi
}


echo "Start..."

sudo su

# call functions
setupUsers
setupFileSystem
configureYum
installNginx
configureIptables

echo "End..."


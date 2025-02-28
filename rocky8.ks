# System language
lang en_US.UTF-8

# Keyboard layout
keyboard us

# Timezone
timezone America/Los_Angeles --utc

# Root password (hashed)
rootpw --iscrypted $6$CeUazULn6EoZHHpv$YSUsLCOl0YMy091MfngoQwK6u6/ZL.Sn24uiFUyM.gD2PG8hjNNGb8gNsTm6IbL9tefWuHbL1.ckzgJuXRV3T1

# Enable SSH
services --enabled=sshd

# Use DHCP for networking
network --bootproto=dhcp --device=eth0 --onboot=on

# Use the Rocky Linux 8 mirror
url --url=http://10.38.104.100/ipxe/rocky8/BaseOS/

# Partitioning (auto-erase disk)
clearpart --all --initlabel
autopart --type=lvm

# Install additional packages
%packages
@^minimal-environment

%end

# Add SSH public key for root
%post
mkdir -p /root/.ssh
chmod 700 /root/.ssh
echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDHrPVbtdHf0aJeRu49fm/lLQPxopvvz6NZZqqGB+bcocZUW3Hw8bflhouTsJ+S4Z3v7L/F6mmZhXU1U3PqUXLVTE4eFMfnDjBlpOl0VDQoy9aT60C1Sreo469FB0XQQYS5CyIWW5C5rQQzgh1Ov8EaoXVGgW07GHUQCg/cmOBIgFvJym/Jmye4j2ALe641jnCE98yE4mPur7AWIs7n7W8DlvfEVp4pnreqKtlnfMqoOSTVl2v81gnp4H3lqGyjjK0Uku72GKUkAwZRD8BIxbA75oBEr3f6Klda2N88uwz4+3muLZpQParYQ+BhOTvldMMXnhqM9kHhvFZb21jTWV7p" > /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys
chown -R root:root /root/.ssh
echo "%wheel	ALL=(ALL)	NOPASSWD: ALL" > /etc/suders.d/nopasswd
yum install epel-release yum-utils -y   
yum config-manager --set-enabled powertools
yum install libnsl -y
dnf install -y rsync util-linux curl firewalld bind-utils telnet jq nano 
dnf install -y ed tcpdump wget nfs-utils cifs-utils samba-client tree xterm net-tools 
dnf install -y dnf install -y openldap-clients sssd realmd oddjob oddjob-mkhomedir adcli 
dnf install -y samba-common samba-common-tools krb5-workstation openldap-clients iperf3 rsnapshot zip 
dnf install -y nnzip ftp autofs zsh ksh tcsh ansible cabextract fontconfig 
dnf install -y nedit htop tar traceroute mtr pwgen ipa-admintools 
dnf install -y cyrus-sasl cyrus-sasl-plain cyrus-sasl-ldap bc nmap-ncat
%end

# Reboot after installation
reboot


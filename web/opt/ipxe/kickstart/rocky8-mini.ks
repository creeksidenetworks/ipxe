# System language
lang en_US.UTF-8

# Keyboard layout
keyboard us

# Timezone
timezone America/Los_Angeles --utc

# disable selinux
selinux --disabled

# enable network interface rename
bootloader --append="net.ifnames=0"

# Root password (hashed)
rootpw --iscrypted $6$CeUazULn6EoZHHpv$YSUsLCOl0YMy091MfngoQwK6u6/ZL.Sn24uiFUyM.gD2PG8hjNNGb8gNsTm6IbL9tefWuHbL1.ckzgJuXRV3T1

# Enable SSH
services --enabled=sshd

# Use DHCP for networking
network --bootproto=dhcp --device=eth0 --onboot=on

# Use the Rocky Linux 8 mirror
url --url=https://download.rockylinux.org/pub/rocky/8/BaseOS/x86_64/os/
repo --name=AppStream --baseurl=https://download.rockylinux.org/pub/rocky/8/AppStream/x86_64/os/

# Partitioning (auto-erase disk)
clearpart --all --initlabel
# EFI System Partition (Required for UEFI)
part /boot/efi --fstype=efi --size=600 --fsoptions="umask=0077,shortname=winnt"
# Boot Partition
part /boot --fstype=xfs --size=1024
# Create LVM physical volume
part pv.01 --size=1 --grow
# Create volume group
volgroup vg_root pv.01
# Create logical volumes
logvol swap --vgname=vg_root --name=lv_swap --size=2048
logvol / --vgname=vg_root --name=lv_root --fstype=xfs --size=10000 --grow

# Install additional packages
%packages
@^minimal-environment

%end

%post
# Add SSH public key for root
mkdir -p /root/.ssh
chmod 700 /root/.ssh
echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDHrPVbtdHf0aJeRu49fm/lLQPxopvvz6NZZqqGB+bcocZUW3Hw8bflhouTsJ+S4Z3v7L/F6mmZhXU1U3PqUXLVTE4eFMfnDjBlpOl0VDQoy9aT60C1Sreo469FB0XQQYS5CyIWW5C5rQQzgh1Ov8EaoXVGgW07GHUQCg/cmOBIgFvJym/Jmye4j2ALe641jnCE98yE4mPur7AWIs7n7W8DlvfEVp4pnreqKtlnfMqoOSTVl2v81gnp4H3lqGyjjK0Uku72GKUkAwZRD8BIxbA75oBEr3f6Klda2N88uwz4+3muLZpQParYQ+BhOTvldMMXnhqM9kHhvFZb21jTWV7p" > /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys
chown -R root:root /root/.ssh
echo "%wheel	ALL=(ALL)	NOPASSWD: ALL" > /etc/suders.d/nopasswd

# install essential packages
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

# install development tools
dnf groupinstall "Development tools" -y

# install docker ce
yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
curl -s https://download.docker.com/linux/centos/docker-ce.repo -o /etc/yum.repos.d/docker-ce.repo
yum update -y
yum install docker-ce docker-ce-cli containerd.io docker-compose-plugin -y
systemctl enable docker

# disable intel sfp check
echo "options ixgbe allow_unsupported_sfp=1" > /etc/modprobe.d/ixgbe.conf                                                                               
dracut --force

%end

# Reboot after installation
reboot


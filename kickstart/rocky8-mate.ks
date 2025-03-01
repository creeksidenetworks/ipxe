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
url --url=https://dl.rockylinux.org/pub/rocky/8/BaseOS/x86_64/os/
repo --name=AppStream --baseurl=https://dl.rockylinux.org/pub/rocky/8/AppStream/x86_64/os/

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
#autopart --type=lvm

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

# install mate desktop
dnf install -y NetworkManager-adsl NetworkManager-bluetooth NetworkManager-libreswan-gnome NetworkManager-openvpn-gnome 
dnf install -y NetworkManager-ovs NetworkManager-ppp NetworkManager-team NetworkManager-wifi NetworkManager-wwan abrt-desktop 
dnf install -y abrt-java-connector adwaita-gtk2-theme alsa-plugins-pulseaudio atril atril-caja atril-thumbnailer caja caja-actions 
dnf install -y caja-image-converter caja-open-terminal caja-sendto caja-wallpaper caja-xattr-tags dconf-editor engrampa eom firewall-config 
dnf install -y gnome-disk-utility gnome-epub-thumbnailer gstreamer1-plugins-ugly-free gtk2-engines gucharmap gvfs-afc gvfs-afp gvfs-archive 
dnf install -y gvfs-fuse gvfs-gphoto2 gvfs-mtp gvfs-smb initial-setup-gui libmatekbd libmatemixer libmateweather libsecret lm_sensors marco mate-applets 
dnf install -y mate-backgrounds mate-calc mate-control-center mate-desktop mate-dictionary mate-disk-usage-analyzer mate-icon-theme mate-media 
dnf install -y mate-menus mate-menus-preferences-category-menu mate-notification-daemon mate-panel mate-polkit mate-power-manager mate-screensaver 
dnf install -y mate-screenshot mate-search-tool mate-session-manager mate-settings-daemon mate-system-log mate-system-monitor mate-terminal mate-themes 
dnf install -y mate-user-admin mate-user-guide mozo network-manager-applet nm-connection-editor p7zip p7zip-plugins pluma seahorse seahorse-caja 
dnf install -y xdg-user-dirs-gtk slick-greeter-mate gnome-terminal lightdm-settings rxvt-unicode
# Disable user login list
sed -i "s%#greeter-hide-users=false%greeter-hide-users=true%" /etc/lightdm/lightdm.conf
# start GUI
systemctl isolate graphical.target
systemctl set-default graphical.target
ln -fs '/usr/lib/systemd/system/graphical.target' '/etc/systemd/system/default.target'
# Disable reboot and power off from desktop
mkdir -p /etc/polkit-1/rules.d
echo "polkit.addRule(function(action, subject) {
    if (action.id == "org.freedesktop.login1.suspend" ||
        action.id == "org.freedesktop.login1.suspend-multiple-sessions" ||
        action.id == "org.freedesktop.login1.power-off" ||
        action.id == "org.freedesktop.login1.power-off-multiple-sessions" ||
        action.id == "org.freedesktop.login1.reboot" ||
        action.id == "org.freedesktop.login1.reboot-multiple-sessions" ||
        action.id == "org.freedesktop.login1.hibernate" ||
        action.id == "org.freedesktop.login1.hibernate-multiple-sessions")
    {
        return polkit.Result.NO;
    }
});" > /etc/polkit-1/rules.d/55-inhibit-shutdown.rules
chmod 644 /etc/polkit-1/rules.d/55-inhibit-shutdown.rules
# disable screen lock
mkdir -p /etc/xdg/autostart
echo "[Desktop Entry]
Type=Application
Exec=xset -dpms s off
Hidden=false
NoDisplay=false
X-MATE-Autostart-enabled=true
Name[en_US]=Disable DPMS
Name=Disable DPMS
Comment[en_US]=Disable DPMS
Comment=Disable DPMS
" > /etc/xdg/autostart/disable-dpms.desktop
# enable mate as default desktop
echo "mate-session" > tee /etc/skel/.Xclients
chmod 755 /etc/skel/.Xclients

# install desktop applications
echo "
[ivoarch-Tilix]
name=Copr repo for Tilix owned by ivoarch
baseurl=https://copr-be.cloud.fedoraproject.org/results/ivoarch/Tilix/epel-7-\$basearch/
type=rpm-md
skip_if_unavailable=True
gpgcheck=0
gpgkey=https://copr-be.cloud.fedoraproject.org/results/ivoarch/Tilix/pubkey.gpg
repo_gpgcheck=0
enabled=1
enabled_metadata=1
" > /etc/yum.repos.d/tilix.repo
echo "
[sublime-text]
name=Sublime Text - x86_64 - Stable
baseurl=https://download.sublimetext.com/rpm/stable/x86_64
enabled=1
gpgcheck=0
gpgkey=https://download.sublimetext.com/sublimehq-rpm-pub.gpg
" > /etc/yum.repos.d/sublime-text.repo
dnf install -y vim vim-X11 emacs tilix sublime-text meld tmux

# install chrome & firefox 
dnf install https://dl.google.com/linux/direct/google-chrome-stable_current_x86_64.rpm -y
dnf install -y firefox filezilla evince

# install tigervnc-server
dnf install tigervnc-server tigervnc

# disable intel sfp check
echo "options ixgbe allow_unsupported_sfp=1" > /etc/modprobe.d/ixgbe.conf                                                                               
dracut --force

%end

# Reboot after installation
reboot


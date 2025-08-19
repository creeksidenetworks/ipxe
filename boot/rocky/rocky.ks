# System language
lang en_US.UTF-8 --addsupport=en_GB

# Keyboard layout
keyboard us

# Timezone
timezone America/Los_Angeles --utc --ntpservers=0.pool.ntp.org,1.pool.ntp.org,2.pool.ntp.org

# disable selinux
selinux --disabled

# enable firewall
firewall --enabled --ssh 

# enable network interface rename & disable intel nic sfp compatibility check
bootloader --location=mbr --append="net.ifnames=0 ixgbe.allow_unsupported_sfp=1"

# Enable SSH
services --enabled=sshd

# Root password (hashed)
rootpw --iscrypted "$6$CeUazULn6EoZHHpv$YSUsLCOl0YMy091MfngoQwK6u6/ZL.Sn24uiFUyM.gD2PG8hjNNGb8gNsTm6IbL9tefWuHbL1.ckzgJuXRV3T1"
sshkey --username=root "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDHrPVbtdHf0aJeRu49fm/lLQPxopvvz6NZZqqGB+bcocZUW3Hw8bflhouTsJ+S4Z3v7L/F6mmZhXU1U3PqUXLVTE4eFMfnDjBlpOl0VDQoy9aT60C1Sreo469FB0XQQYS5CyIWW5C5rQQzgh1Ov8EaoXVGgW07GHUQCg/cmOBIgFvJym/Jmye4j2ALe641jnCE98yE4mPur7AWIs7n7W8DlvfEVp4pnreqKtlnfMqoOSTVl2v81gnp4H3lqGyjjK0Uku72GKUkAwZRD8BIxbA75oBEr3f6Klda2N88uwz4+3muLZpQParYQ+BhOTvldMMXnhqM9kHhvFZb21jTWV7p"

# additional admin user
user --name=jackson --password="$6$CeUazULn6EoZHHpv$YSUsLCOl0YMy091MfngoQwK6u6/ZL.Sn24uiFUyM.gD2PG8hjNNGb8gNsTm6IbL9tefWuHbL1.ckzgJuXRV3T1" --iscrypted --groups=wheel
sshkey --username=jackson "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDHrPVbtdHf0aJeRu49fm/lLQPxopvvz6NZZqqGB+bcocZUW3Hw8bflhouTsJ+S4Z3v7L/F6mmZhXU1U3PqUXLVTE4eFMfnDjBlpOl0VDQoy9aT60C1Sreo469FB0XQQYS5CyIWW5C5rQQzgh1Ov8EaoXVGgW07GHUQCg/cmOBIgFvJym/Jmye4j2ALe641jnCE98yE4mPur7AWIs7n7W8DlvfEVp4pnreqKtlnfMqoOSTVl2v81gnp4H3lqGyjjK0Uku72GKUkAwZRD8BIxbA75oBEr3f6Klda2N88uwz4+3muLZpQParYQ+BhOTvldMMXnhqM9kHhvFZb21jTWV7p"
 
# Use DHCP for networking
network --bootproto=dhcp --device=eth0 --noipv6 --onboot=on

# Include the dynamically generated partition information
%include /tmp/part-include

# Install additional packages
%packages
@^minimal-environment
%end

#------------------------------------------------------------------
# preinstallation scripts, dynamically partition based on RAM size
#------------------------------------------------------------------
%pre
#!/bin/bash

# read arguments from ipxe
set -- `cat /proc/cmdline`
for I in $*; do 
    case "$I" in 
        *=*) 
            eval $I;; 
    esac; 
done

#printf "Rocky base url     : $rockybaseurl\n"  > /dev/tty1
#printf "partition selected : $partition\n" > /dev/tty1
#sleep 10

if [[ "$partition" == "auto" ]]; then
    # Contintue with auto partition
    # Calculate total RAM in megabytes
    MAX_SWAP_SIZE=$(awk '/MemTotal/ {print int($2 / 1024)}' /proc/meminfo)
    [ $MAX_SWAP_SIZE -gt 262144 ] && MAX_SWAP_SIZE=262144

    # Initialize variables
    smallest_disk=""
    smallest_size=0

    # Iterate over all disks
    # Enable nullglob to prevent non-matching patterns from being treated as literals
    shopt -s nullglob
    for disk in /sys/block/sd*  /sys/block/nvme*; do
        echo "process disk $disk"
        dev=$(basename "$disk")
        size=$(cat "$disk/size")
        phy_sec=$(cat "$disk/queue/physical_block_size")

        # Calculate size in GB
        size_gb=$((size * phy_sec / 1024 / 1024 / 1024))

        # Check if this disk is the smallest found so far
        if [ "$smallest_size" -eq 0 ] || [ "$size_gb" -lt "$smallest_size" ]; then
            smallest_size="$size_gb"
            smallest_disk="$dev"
        fi
    done

    # Verify a suitable disk was found
    if [ -z "$smallest_disk" ]; then
        echo "No suitable disk found for installation." >&2
        exit 1
    fi

    # Deactivate all active volume groups
    vgchange -an

    # Remove all logical volumes
    for lv in $(lvdisplay | awk '/LV Path/ {print $3}'); do
        lvremove -f "$lv"
    done

    # Remove all volume groups
    for vg in $(vgdisplay | awk '/VG Name/ {print $3}'); do
        vgremove -f "$vg"
    done

    # Remove all physical volumes
    for pv in $(pvdisplay | awk '/PV Name/ {print $3}'); do
        pvremove -f "$pv"
    done

    # Write partition information to a temporary file
    cat <<EOF > /tmp/part-include
# Partitioning (auto-erase disk)
clearpart --all --initlabel --disklabel=gpt
bootloader --location=mbr --boot-drive=/dev/$smallest_disk
# EFI System Partition (Required for UEFI)
part /boot/efi --fstype=efi --size=600 --fsoptions="umask=0077,shortname=winnt"  --ondisk=/dev/$smallest_disk
# Boot Partition
part /boot --fstype=xfs --size=1024  --ondisk=/dev/$smallest_disk
# Create LVM physical volume
part pv.01 --size=1 --grow  --ondisk=/dev/$smallest_disk
# Create volume group
volgroup vg_root pv.01
# Create logical volumes
logvol swap --vgname=vg_root --name=lv_swap --fstype=swap --size=2048
logvol / --vgname=vg_root --name=lv_root --fstype=xfs --size=10000 --grow --maxsize=262144
EOF

else
    echo "clearpart --all --initlabel --disklabel=gpt" > /tmp/part-include
fi

%end


#------------------------------------------------------------------
# post installation scripts
#------------------------------------------------------------------
%post
#!/bin/bash

printf "%-10s : %s\n" "$(date '+%Y-%m-%d %H:%M:%S')"  "Post installation starts" 

# read arguments from ipxe
set -- `cat /proc/cmdline`
for I in $*; do 
    case "$I" in 
        *=*) 
            eval $I;; 
    esac; 
done

# disable sudo password requirement
echo "%wheel	ALL=(ALL)	NOPASSWD: ALL" > /etc/sudoers.d/nopasswd

yum install epel-release yum-utils -y   
yum config-manager --set-enabled powertools
#dnf reinstall ca-certificates -y

# Update Rocky and EPEL repository baseurls to use the provided ${baseurl}
case $region in
    "china")
        baseos_url="http://mirrors.ustc.edu.cn/rocky"
        epel_url="http://mirrors.ustc.edu.cn/epel"
        ;;
    *)
        baseos_url=""
        epel_url=""
        ;;
esac

if [ -n "$baseos_url" ]; then
    # Update Rocky repos
    for repo in /etc/yum.repos.d/Rocky-*.repo; do
        sed -i -E "s%^([[:space:]]*)#?([[:space:]]*)baseurl=http.*contentdir%baseurl=${baseos_url}%" "$repo"
        sed -i 's/^mirrorlist=/#mirrorlist=/' "$repo"
    done
fi

if [ -n "$epel_url" ]; then
    # Update EPEL repos
    for repo in /etc/yum.repos.d/epel*.repo; do
        sed -i -E "s%^([[:space:]]*)#?([[:space:]]*)baseurl=http.*epel%baseurl=${epel_url}%" "$repo"
        #sed -i "s|^[[:space:]]*#?[[:space:]]*baseurl=.*epel|baseurl=${epel_url}|g" "$repo"
        sed -i 's/^metalink=/#metalink=/' "$repo"
    done
fi

# install essential packages
printf "%-10s : %s\n" "$(date '+%Y-%m-%d %H:%M:%S')"  "Install essential packages" 
yum update -y
yum install libnsl -y
dnf install -y rsync util-linux curl firewalld bind-utils telnet jq nano 
dnf install -y ed tcpdump wget nfs-utils cifs-utils samba-client tree xterm net-tools 
dnf install -y dnf install -y openldap-clients sssd realmd oddjob oddjob-mkhomedir adcli 
dnf install -y samba-common samba-common-tools krb5-workstation openldap-clients iperf3 rsnapshot zip 
dnf install -y nnzip ftp autofs zsh ksh tcsh ansible cabextract fontconfig 
dnf install -y nedit htop tar traceroute mtr pwgen ipa-admintools sssd realmd zsh ksh tcsh
dnf install -y cyrus-sasl cyrus-sasl-plain cyrus-sasl-ldap bc nmap-ncat

# install development tools
printf "%-10s : %s\n" "$(date '+%Y-%m-%d %H:%M:%S')"  "Install development tools" 
dnf groupinstall "Development tools" -y

# install docker ce
yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
curl -s https://download.docker.com/linux/centos/docker-ce.repo -o /etc/yum.repos.d/docker-ce.repo
yum update -y
yum install docker-ce docker-ce-cli containerd.io docker-compose-plugin -y
systemctl enable docker

if [ $desktop = "desktop" ]; then
    printf "%-10s : %s\n" "$(date '+%Y-%m-%d %H:%M:%S')"  "Install mate desktop" 
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
    dnf install -y xdg-user-dirs-gtk slick-greeter-mate gnome-terminal lightdm-settings rxvt-unicode sssd realmd zsh ksh tcsh
    # Disable user login list
    sed -i "s%#greeter-hide-users=false%greeter-hide-users=true%" /etc/lightdm/lightdm.conf
    # start GUI
    systemctl isolate graphical.target
    systemctl set-default graphical.target
    ln -fs '/usr/lib/systemd/system/graphical.target' '/etc/systemd/system/default.target'
    # enable mate as default desktop
    echo "mate-session" > tee /etc/skel/.Xclients
    chmod 755 /etc/skel/.Xclients

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

    # install xfce desktop
    printf "%-10s : %s\n" "$(date '+%Y-%m-%d %H:%M:%S')"  "Install XFCE desktop" 
    dnf groupinstall -y "Xfce"

    # install desktop applications
    printf "%-10s : %s\n" "$(date '+%Y-%m-%d %H:%M:%S')"  "Install misc desktop applications" 
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
    printf "%-10s : %s\n" "$(date '+%Y-%m-%d %H:%M:%S')"  "Install browsers" 

    dnf install https://dl.google.com/linux/direct/google-chrome-stable_current_x86_64.rpm -y
    dnf install -y firefox filezilla evince

    # install tigervnc-server
    dnf install -y tigervnc-server tigervnc

    # libre office
    lastest_libre_version=$(curl --silent --max-time 15 http://download.documentfoundation.org/libreoffice/stable/ | grep -oP 'href="\K[0-9.]+(?=/)' | sort -V | tail -1)
    printf "%-10s : %s\n" "$(date '+%Y-%m-%d %H:%M:%S')"  "Libera Office verion ${lastest_libre_version}" 
    RPM_PATH="/opt/libreoffice/rpm"
    RPM_FILE="${RPM_PATH}/LibreOffice_${lastest_libre_version}_Linux_x86-64_rpm.tar.gz"
    mkdir -p $RPM_PATH

    REMOTE_URL="http://download.documentfoundation.org/libreoffice/stable/${lastest_libre_version}/rpm/x86_64/LibreOffice_${lastest_libre_version}_Linux_x86-64_rpm.tar.gz"
    curl -# -L http://download.documentfoundation.org/libreoffice/stable/${lastest_libre_version}/rpm/x86_64/LibreOffice_${lastest_libre_version}_Linux_x86-64_rpm.tar.gz -o $RPM_FILE

    if [ -f $RPM_FILE ]; then
        WORK_DIR=$(mktemp -d)
        printf "\nInstall Libreoffice $lastest_libre_version \n" 
        tar xzf $RPM_FILE --strip-components=2 -C ${WORK_DIR}
        yum localinstall ${WORK_DIR}/*.rpm -y
        rm -rf WORK_DIR
    else
        printf "%-10s : %s\n" "$(date '+%Y-%m-%d %H:%M:%S')"  "Libera Office downlaod failed" 
    fi
fi 

%end

# Reboot after installation
reboot


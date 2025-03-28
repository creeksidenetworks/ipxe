# Self hosting iPXE server
## How iPXE works
- DHCP server reply to client's request with DHCP options
- Client use TFTP to download the iPXE firmware and start execution.
- Client then inquiry DHCP server for next step, DHCP server reply with the URL of iPXE script (boot.ipxe)
- iPXE firmware execute the iPXE script and download the bootloader from a remote HTTP server
- For RHEL OS (CentOS/RockyOS), a kickstart file tell OS installer the configuration and post install scripts to run. After installation, the installer will reboot the client server

## Major components
- A DHCP server
- A TFTP server
- A http web server

## Configure EdgeRouter to function as the TFTP server

- Download iPXE boot files
```bash
sudo mkdir -p /config/user-data/tftproot
sudo curl -L https://boot.ipxe.org/ipxe.efi -o /config/user-data/tftproot/ipxe.efi
sudo curl -L https://boot.ipxe.org/undionly.kpxe -o /config/user-data/tftproot/undionly.kpxe
```
- Configure DNSMASQ
    - Assign 10.255.255.254/32 to loopback interface
    - Enable DNSMASQ as DHCP server and TFTP server
    - DNSMASQ listen on 10.255.255.254
    - Two stage boot
        - Download ipxe firmware image to client
        - Then follow the URL to fetech the iPXE boot scripts (replace the ipxe.creekside.network with your own domain)
```bash
set interfaces loopback lo address 10.255.255.254/32
set service dhcp-server use-dnsmasq enable
set service dns forwarding options enable-tftp
set service dns forwarding options tftp-root=/config/user-data/tftproot
set service dns forwarding options listen-address=10.255.255.254
set service dns forwarding options 'dhcp-match=set:bios,60,PXEClient:Arch:00000'
set service dns forwarding options 'dhcp-boot=tag:bios,undionly.kpxe,,10.255.255.254'
set service dns forwarding options 'dhcp-match=set:efi32,60,PXEClient:Arch:00002'
set service dns forwarding options 'dhcp-boot=tag:efi32,ipxe.efi,,10.255.255.254'
set service dns forwarding options 'dhcp-match=set:efi32-1,60,PXEClient:Arch:00006'
set service dns forwarding options 'dhcp-boot=tag:efi32-1,ipxe.efi,,10.255.255.254'
set service dns forwarding options 'dhcp-match=set:efi64,60,PXEClient:Arch:00007'
set service dns forwarding options 'dhcp-boot=tag:efi64,ipxe.efi,,10.255.255.254'
set service dns forwarding options 'dhcp-match=set:efi64-1,60,PXEClient:Arch:00008'
set service dns forwarding options 'dhcp-boot=tag:efi64-1,ipxe.efi,,10.255.255.254'
set service dns forwarding options 'dhcp-match=set:efi64-2,60,PXEClient:Arch:00009'
set service dns forwarding options 'dhcp-boot=tag:efi64-2,ipxe.efi,,10.255.255.254'
set service dns forwarding options 'dhcp-userclass=set:ipxe,iPXE'
set service dns forwarding options 'dhcp-boot=tag:ipxe,http://ipxe.creekside.network/boot.ipxe'
```

## Hosting your own website on Edgerouter

The following steps are optional. You will need to change the DNSMASQ 2nd stage setting to your router's loopback IP

- Change router management UI to alternative port
```bash
set service gui http-port 28080
```
- Configure package repository 
```bash
set system package repository EdgeOS2.0 components 'main contrib non-free'
set system package repository EdgeOS2.0 distribution stretch
set system package repository EdgeOS2.0 password ''
set system package repository EdgeOS2.0 url 'http://archive.debian.org/debian'
set system package repository EdgeOS2.0 username ''
```
-- Install Nginx-light
```bash
sudo apt update 
sudo apt install nginx-light -y
```
-- Upload the files to router & restart nginx service

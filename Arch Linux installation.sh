#######################################
##### VERIFY SIGNATURE OF THE ISO #####
#######################################

##################################### 
##### BOOT THE LIVE ENVIRONMENT #####
#####################################

###################################
##### SET THE KEYBOARD LAYOUT #####
###################################

#     ls /usr/share/kbd/keymaps/**/*.map.gz
#     loadkeys name-of-the-keyboard-layout
#     Make sure numlock is on 
 
################################
##### VERIFY THE BOOT MODE #####
################################

#     ls /sys/firmware/efi/efivars

################################### 
##### CONNECT TO THE INTERNET #####
###################################

##### Check internet connection
#     ping www.archlinux.org

##### Connect to wifi: 
#     wifi-menu -o 
 
#     ip link 
#     wpa_supplicant -B -i wlp1s0 -c <(wpa_passphrase GALA chanamamra) 
#     systemctl start dhcpcd@wlp1s0.service 
 	
##### Find local IP of the host 
#     ip address show 
 
##### Set root password for SSH: 
#     passwd 
 
##### Start SSH daemon 
#     systemctl start sshd
 
##### Connect to host from client via ssh 
#     ssh -o UserKnownHostsFile=/dev/null root@IP 
 
###################################
##### UPDATE THE SYSTEM CLOCK #####
###################################

timedatectl set-ntp true 

############################### 
##### PARTITION THE DISKS #####
###############################

##### Confirm disk name
#     lsblk 

##### Confirm memory size
#     free -m 
 
##### Create a GPT partition table as desired using gdisk
#     gdisk /dev/sda 
#     Zap GPT data structures if necessary 
#     sda1 Size-->128MiB Type-->ef00 (EFI File System) Name-->efi 
#     sda2 Size-->256MiB Type-->8300 (Linux filesystem) Name-->cryptboot 
#     sda3 Size-->7888MiB Type-->8200 (Linux swap) Name-->cryptswap 
#     sda4 Size-->remaining Type-->8300 (Linux filesystem) Name-->cryptbtrfs 
#     Write changes to disk 

##### Automated partition table creation
sgdisk --zap-all /dev/sda && 
sgdisk --new=1:0:+128MiB	--typecode=1:ef00	--change-name=1:efi /dev/sda && \
sgdisk --new=2:0:+1024MiB	--typecode=2:8300	--change-name=2:cryptboot /dev/sda && \
sgdisk --new=3:0:+8192MiB	--typecode=3:8200	--change-name=3:cryptswap /dev/sda && \
sgdisk --new=4:0:0		--typecode=4:8300	--change-name=4:cryptsystem /dev/sda 
 
#################################
##### FORMAT THE PARTITIONS #####
#################################
 
##### Format the EFI partition as fat32 
mkfs.fat -F 32 -n "EFI" /dev/sda1 && \
 
##### Securely wipe cryptboot partition and cryptlvm partition if necessary 
#     shred -v /dev/sdXY 
 
##### Benchmark ciphers, their operting modes, their key sizes and KDFs to make an appropriate choice. 
#     cryptsetup benchmark 
 
##### Format cryptboot  
cryptsetup -c serpent-xts-plain64 --type=luks1 luksFormat /dev/disk/by-partlabel/cryptboot && \
cryptsetup open /dev/disk/by-partlabel/cryptboot boot && \
mkfs.btrfs -f -L "boot" /dev/mapper/boot && \
mount -o x-mount.mkdir,compress=zstd,space_cache=v2 LABEL=boot /mnt && \
mkdir /mnt/{slot_a,slot_b,backups} && \
btrfs subvolume create /mnt/slot_a/boot && \
umount /mnt && \
cryptsetup close /dev/mapper/boot && \
 
##### Format cryptswap
cryptsetup -c serpent-xts-plain64 --type=luks2 luksFormat /dev/disk/by-partlabel/cryptswap && \
cryptsetup open /dev/disk/by-partlabel/cryptswap swap && \
mkswap -L "swap" /dev/mapper/swap && \
cryptsetup close /dev/mapper/swap && \
 
##### Format cryptsystem and configure the subvolumes  
cryptsetup -c serpent-xts-plain64 --type=luks2 luksFormat /dev/disk/by-partlabel/cryptsystem && \
cryptsetup open /dev/disk/by-partlabel/cryptsystem system && \
mkfs.btrfs -f -L "system" /dev/mapper/system && \
mount -o x-mount.mkdir,compress=zstd,space_cache=v2 LABEL=system /mnt && \
btrfs subvolume create /mnt/home && \
mkdir /mnt/{slot_a,slot_b,backups} && \
btrfs subvolume create /mnt/slot_a/root && \
btrfs subvolume create /mnt/slot_a/var && \
btrfs subvolume create /mnt/slot_a/opt && \
btrfs subvolume create /mnt/slot_a/usr && \
umount /mnt && \
cryptsetup close /dev/mapper/system
 
##### List btrfs subvolumes
#     Unlock the LUKS container
#     Mount the LUKS container
#     btrfs subvolume list /mnt 
 
##################################
##### MOUNT THE FILE SYSTEMS #####
##################################

cryptsetup open /dev/disk/by-partlabel/cryptboot boot && \
cryptsetup open /dev/disk/by-partlabel/cryptswap swap && \
swapon -L "swap" && \
cryptsetup open /dev/disk/by-partlabel/cryptsystem system && \
mount -o compress=zstd,space_cache=v2,subvol=/slot_a/root LABEL=system /mnt && \
mount -o x-mount.mkdir,compress=zstd,space_cache=v2,subvol=/slot_a/usr LABEL=system /mnt/usr && \
mount -o x-mount.mkdir,compress=zstd,space_cache=v2,subvol=/home LABEL=system /mnt/home && \
mount -o x-mount.mkdir,compress=zstd,space_cache=v2,subvol=/slot_a/var LABEL=system /mnt/var && \
mount -o x-mount.mkdir,compress=zstd,space_cache=v2,subvol=/slot_a/opt LABEL=system /mnt/opt && \
mount -o x-mount.mkdir,compress=zstd,space_cache=v2,subvol=/slot_a/boot LABEL=boot /mnt/boot && \
mount -o x-mount.mkdir LABEL=EFI /mnt/boot/efi
 
##### Check the mountpoints with 
#     df -hT

############################ 
##### REFRESH THE KEYS #####
############################

pacman-key --refresh-keys 

##############################
##### SELECT THE MIRRORS #####
##############################

pacman -Sy reflector && \
reflector --verbose --country India --sort rate --save /etc/pacman.d/mirrorlist

######################################### 
##### INSTALL THE REQUIRED PACKAGES #####
#########################################

pacstrap /mnt base base-devel btrfs-progs intel-ucode bash-completion wpa_supplicant dialog grub efibootmgr openssh reflector nftables ntfs-3g vim
 
################################
##### CONFIGURE THE SYSTEM #####
################################

echo "EDITOR=vim" >> /mnt/etc/environment && \

##### Fstab 
genfstab -L /mnt >> /mnt/etc/fstab && \
sed -i 's/subvolid=.*,subvol=\//subvol=\//g' /mnt/etc/fstab && \
sed -i 's/subvol=\/.*,subvol=/subvol=\//g' /mnt/etc/fstab && \
sed -i 's/subvol=\/slot_a\/boot/x-systemd.requires=systemd-cryptsetup@boot.service,subvol=\/slot_a\/boot' /mnt/etc/fstab

###### Copy netctl configuration 
cp /etc/netctl/* /mnt/etc/netctl \
 
##### Chroot 
arch-chroot /mnt 

################################

##### Time zone 
ln -sf /usr/share/zoneinfo/Asia/Kolkata /etc/localtime && \
hwclock --systohc && \
 
##### Localization (uncomment en_IN.UTF-8) 
echo "en_IN.UTF-8 UTF-8" >> /etc/locale.gen && \
locale-gen &&  \
echo "LANG=en_IN.UTF-8" >> /etc/locale.conf && \
 
##### Network Configuration 
echo TheCosmicVortex >> /etc/hostname && \
echo >> /etc/hosts && \
echo "127.0.0.1       localhost" >> /etc/hosts && \
echo "::1             localhost" >> /etc/hosts && \
echo "127.0.1.1       TheCosmicVortex.localdomain     TheCosmicVortex" >> /etc/hosts && \
 
##### Setting up sudo and a user 
useradd -m -G wheel bl4ckh0l3 && \
passwd bl4ckh0l3 && \
sed -i 's/# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' /etc/sudoers && \
passwd -l root && \

##### Avoiding having to enter the passphrase twice
dd bs=512 count=4 if=/dev/urandom of=/etc/keyfile-cryptsystem iflag=fullblock && \
chmod 000 /etc/keyfile-cryptsystem && \
chmod 600 /boot/initramfs-linux* && \
cryptsetup -v luksAddKey /dev/sda4 /etc/keyfile-cryptsystem && \

# vi /etc/mkinitcpio.conf
#	FILES=(/etc/keyfile-cryptsystem)

# vi /etc/default/grub
#	GRUB_CMDLINE_LINUX="... cryptkey=rootfs:/etc/keyfile-cryptsystem"

##### Mount the encrypted boot 
dd bs=512 count=4 if=/dev/urandom of=/etc/keyfile-cryptboot iflag=fullblock && \
chmod 600 /etc/keyfile-cryptboot && \
cryptsetup luksAddKey /dev/disk/by-partlabel/cryptboot /etc/keyfile-cryptboot && \
echo >> /etc/crypttab && \
echo "boot     /dev/disk/by-partlabel/cryptboot     /etc/keyfile-cryptboot" >> /etc/crypttab && \

##### Enable SSH 
systemctl enable sshd.socket && \
echo >> /etc/ssh/sshd_config && \
echo "AllowUsers     bl4ckh0l3" >> /etc/ssh/sshd_config && \
 
##### Install and configure tlp
pacman -S tlp && \
pacman -S --asdeps smartmontools lsb-release x86_energy_perf_policy && \
systemctl enable tlp.service && \
systemctl enable tlp-sleep.service && \
 
##### Configure obfuscated netctl 
netctl enable wlp13s0-GALA && \

# cp /etc/netctl/examples/wireless-wpa /etc/netctl 
# vi /etc/netctl/wireless-wpa 
	# wpa_passphrase ESSID passphrase 
# netctl enable wireless-wpa

##### Cleanly unmount /var 
sed -i '/Before=/a RequiresMountsFor=\/var\/log\/journal' /usr/lib/systemd/system/systemd-journald.service

##################################################### 
##### MKINITCPIO-CHKCRYPTOBOOT TO CHECK EFISTUB #####
#####################################################

su -l bl4ckh0l3 
curl -C - -L -O https://aur.archlinux.org/cgit/aur.git/snapshot/mkinitcpio-chkcryptoboot.tar.gz && \
tar -xvzf mkinitcpio-chkcryptoboot.tar.gz && \
cd mkinitcpio-chkcryptoboot && \
makepkg
sudo pacman -U *.pkg.tar.xz



 
 
dd if=/dev/urandom of=hash bs=2048 count=1 iflag=fullblock && 
HASH1=$(sha512sum hash | awk '{print $1}' ) &&
HASH2=$(echo "$HASH1" | sha512sum | awk '{print $1}') 
vim /etc/default/chkcryptoboot.conf



 

###############################
##CHKCRYPTOBOOT Configuration## 
############################### 
 
#Boot Mode: mbr or efi 
BOOTMODE=efi 
 
#Boot disk (in case of mbr. the disk you GRUB is installed) 
BOOTDISK=/dev/disk/by-partlabel/EFI 
 
#ESP mount point (where your ESP partition is mounted) 
ESP=/boot/efi 
 
#BOOTLOADER EFI stub (in case of efi) 
EFISTUB=/boot/efi/EFI/GRUB/grubx64.efi 
 
#Kernel cmdline parameter name 
CMDLINE_NAME=29b97164721350cdca2a10add121d96a636914cb1fb575e7e15c96db82012e42532ec3c732a63ef01ac4c70e2a20ff83d6df1d78992bae056de932f6432fb27b 
 
#Kernel cmdline parameter value 
CMDLINE_VALUE=d6d0a941bc5f023e9c8007029acd621ecdd26adf74ec1203b77883afb8625a662d21cc9a3e8c4673544fb7c5264394174c4469002b3379f01d5a0727816d32f0 
 
#Secret messgae to check against phishing 
SECRETMESSAGE="PLEASE DON'T PWN ME (:" 




###############################################
##### INSTALL AND CONFIGURE OPENSWAP HOOK #####
###############################################

##### Change user 
su -l bl4ckh0l3  
 
##### Download and make PKGBUILD
curl -C - -L -O https://aur.archlinux.org/cgit/aur.git/snapshot/mkinitcpio-openswap.tar.gz && \
tar -xvzf mkinitcpio-openswap.tar.gz && \
cd mkinitcpio-openswap && \
makepkg && \
logout 
 
##### Install and configure mkinitcpio-openswap
cd /home/bl4ckh0l3/mkinitcpio-openswap && \
pacman -U *.pkg.tar.xz && \
dd bs=512 count=4 if=/dev/random of=/etc/keyfile-cryptswap iflag=fullblock && \
chmod 600 /etc/keyfile-cryptswap && \
cryptsetup luksAddKey /dev/disk/by-partlabel/cryptswap /etc/keyfile-cryptswap && \
vim /etc/openswap.conf





## cryptsetup open $swap_device $crypt_swap_name 
## get uuid using e.g. lsblk -f 
swap_device=/dev/disk/by-partlabel/cryptswap 
crypt_swap_name=swap 
 
## one can optionally provide a keyfile device and path on this device 
## to the keyfile 
keyfile_device=/dev/disk/by-label/system 
keyfile_filename=etc/keyfile-cryptswap 
 
## additional arguments are given to mount for keyfile_device 
## has to start with --options (if so desired) 
keyfile_device_mount_options="--options=subvol=/slot_a/root" 
 
## additional arguments are given to cryptsetup 
## --allow-discards options is desired in case swap is on SSD partition 
cryptsetup_options="--type luks2" 




##################################################################################################
##### CONFIGURE BOOTLOADER (use :r!<command here> to write output of command from within vi) #####
##################################################################################################

vi /etc/default/grub 




 
GRUB_CMDLINE_LINUX_DEFAULT="resume=LABEL=swap" 
GRUB_CMDLINE_LINUX="cryptdevice=PARTLABEL=cryptsystem:system cryptkey=rootfs:/etc/keyfile-cryptsystem slot=slot_a 29b97164721350cdca2a10add121d96a636914cb1fb575e7e15c96db82012e42532ec3c732a63ef01ac4c70e2a20ff83d6df1d78992bae056de932f6432fb27b=d6d0a941bc5f023e9c8007029acd621ecdd26adf74ec1203b77883afb8625a662d21cc9a3e8c4673544fb7c5264394174c4469002b3379f01d5a0727816d32f0" 
GRUB_ENABLE_CRYPTODISK=y 
GRUB_DISABLE_SUBMENU=y 




 
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB --recheck --debug && \
grub-mkconfig -o /boot/grub/grub.cfg && \
sed -i "/menuentry 'Arch Linux, with Linux linux (fallback initramfs)'/,/}/d" /boot/grub/grub.cfg && \
sed -i 's/Arch Linux, with Linux linux/Arch Linux slot_a/g' /boot/grub/grub.cfg 
 
#####################
##### INITRAMFS #####
#####################

vi /etc/mkinitcpio.conf 





	MODULES=(i915) 
	BINARIES=(/usr/bin/btrfs) 
	FILES=(/etc/keyfile-cryptsystem)
	HOOKS=(base udev autodetect modconf block chkcryptoboot encrypt openswap resume filesystems keyboard usr fsck shutdown) 





mkinitcpio -p linux 
 
##################
##### REBOOT #####
##################

exit 
umount -R /mnt && \
reboot 
 
#####################################
##### INSTALL AUR WRAPPER "yay" #####
#####################################

curl -C - -L -O https://aur.archlinux.org/cgit/aur.git/snapshot/yay-bin.tar.gz && \
tar -xvzf yay-bin.tar.gz && \
cd yay-bin && \
makepkg -si  

####################### 
##### SECURE BOOT #####
#######################

mkdir cryptboot && \
cd cryptboot && \
vi PKGBUILD




 
# Maintainer: Jugal Gala (its4nitya) <galajugal@posteo.de> 
pkgname=cryptboot 
pkgver=1.2.0 
pkgrel=1 
pkgdesc="Encrypted boot partition manager with UEFI Secure Boot support" 
arch=('any') 
url="https://github.com/its4nitya/cryptboot" 
license=('GPL3') 
depends=('cryptsetup' 'grub' 'efibootmgr' 'efitools' 'sbsigntools') 
install="cryptboot.install" 
source=("${pkgname}-${pkgver}.tar.gz::$url/archive/v$pkgver.tar.gz") 
 
package() { 
  cd "$srcdir/$pkgname-$pkgver" 
  install -Dm755 cryptboot "$pkgdir/usr/bin/cryptboot" 
  install -Dm755 cryptboot-efikeys "$pkgdir/usr/bin/cryptboot-efikeys" 
  install -Dm755 cryptboot-grub-warning "$pkgdir/etc/cryptboot-grub-warning" 
  install -Dm644 cryptboot.conf "$pkgdir/etc/cryptboot.conf" 
  mkdir -p "$pkgdir/usr/local/bin/" 
  ln -s "$pkgdir/etc/cryptboot-grub-warning" "$pkgdir/usr/local/bin/grub-install" 
} 




 
vi cryptboot.install 





# Maintainer: Jugal Gala (its4nitya) <galajugal@posteo.de> 
post_install() { 
    export PATH=$PATH 
} 
 
post_upgrade() { 
    export PATH=$PATH 
} 
 
post_remove() { 
    export PATH=$PATH 
} 




 
makepkg -si --skipinteg && \
sudo -e /etc/cryptboot.conf 
	BOOT_CRYPT_NAME="boot" 
	 
sudo cryptboot-efikeys create && 
sudo cryptboot-efikeys enroll && 
sudo cryptboot update-grub 

####################################################################################################################
####################################################################################################################
#################################################################################################################### 

##########################
##### COPY THE HOOKS #####
##########################

mkdir -p /mnt/etc/pacman.d && 
scp -r bl4ckh0l3@192.168.1.3:"ArchLinux/hooks/" /mnt/etc/pacman.d

## Dektop Environment 
 
sudo pacman -S xorg-server lightdm lxqt ttf-dejavu papirus-icon-theme xscreensaver xorg-fonts-100dpi xorg-xrdb lxappearance-gtk3 firefox thunderbird gvim qpdfview libreoffice-fresh vlc pulseaudio galculator pavucontrol network-manager-applet breeze breeze-gtk numlockx light 
yay -S lightdm-slick-greeter arc-gtk-theme qps lightdm-settings 
 
## Configure mouse libinput 
sudo vi /etc/X11/xorg.conf.d/30-touchpad.conf 
Section "InputClass" 
	Identifier "touchpad" 
	Driver "libinput" 
	MatchIsTouchpad "on" 
	Option "Tapping" "on" 
	Option "TappingButtonMap" "lrm" 
	Option "NaturalScrolling" "true" 
EndSection 
 
## Screenlocker switch login 
vi ~/.Xresources 
xscreensaver.newLoginCommand: dm-tool switch-to-greeter 
 
# Set lightdm greeter 
sudo sed -i 's/#greeter-session=.*/greeter-session=lightdm-slick-greeter/' /etc/lightdm/lightdm.conf && \ 
sudo systemctl enable lightdm.service 
 
sudo vi /usr/bin/grub-mkconfig-wrapper 
 
#!/bin/sh 
 
echo $@ 
grub-mkconfig-original $@ && \ 
sed -i "/menuentry 'Arch Linux, with Linux linux (fallback initramfs)'/,/}/d" $2 && \ 
sed -i 's/Arch Linux, with Linux linux/Arch Linux slot_b/g' $2 && \ 
sed -i '1,/### BEGIN \/etc\/grub.d\/10_linux ###/d' $2 && \ 
sed -i '/### END \/etc\/grub.d\/10_linux ###/,$d' $2 && \ 
echo -e "#!/bin/bash\nexec tail -n +3 \$0\n" > /etc/grub.d/40_custom && \ 
cat $2 >> /etc/grub.d/40_custom && \ 
sed -i 's/slot_a/slot_b/g' /etc/grub.d/40_custom && \ 
grub-mkconfig-original $@ &> /dev/null && \ 
sed -i "/menuentry 'Arch Linux, with Linux linux (fallback initramfs)'/,/}/d" $2 && \ 
sed -i 's/Arch Linux, with Linux linux/Arch Linux/g' $2 
 
sudo chmod +x /usr/bin/grub-mkconfig-wrapper 
 
#GNOME 
 
yay -S gnome-shell-extension-dash-to-dock gnome-shell-extension-topicons-plus gnome-shell-extension-status-area-horizontal-spacing

sudo pacman -S gdm gnome-control-center gnome-video-effects networkmanager gnome-keyring gnome-user-share libva-intel-driver libvdpau-va-gl libva-utils vdpauinfo gnome-terminal nautilus nautilus-sendto nautilus-share nautilus-image-converter gvfs-mtp gvfs-smb gvfs-google gvfs-goa gvfs-afc gvfs-gphoto2 gvfs-ntfs firefox hunspell-en_GB xdg-user-dirs-gtk gnome-menus file-roller p7zip unrar gnome-system-monitor gnome-logs gnome-calculator gnome-tweaks libreoffice-fresh sushi totemgst-plugins-ugly gst-libav grilo-plugins papirus-icon-theme keepassxc syncthing syncthing-gtk python-nautilus

sudo -e /etc/environment
EDITOR=vim
VDPAU_DRIVER=va_gl

https://wiki.archlinux.org/index.php/Hardware_video_acceleration
https://unix.stackexchange.com/questions/266586/gdm-how-to-enable-touchpad-tap-to-click

sudo systemctl enable gdm
sudo systemctl enable NetworkManager 

#KDE

sudo pacman -S xorg-server mesa vulkan-intel plasma ttf-dejavu ttf-liberation syncthing konsole gvim emoji-font firefox dolphin codeblocks okular unarchiver gwenview ark kdenetwork-filesharing samba libreoffice-fresh kcalc filelight vlc  qbittorrent keepassxc openvpn networkmanager-openvpn kaddressbook kmail korganizer knotes kleopatra spectacle git partitionmanager khelpcenter

sudo pacman -S --asdeps keditbookmarks libnotify hunspell-en_GB ffmpegthumbs ruby kdegraphics-thumbnailers purpose qt5-imageformats kimageformats libappimage gst-plugins-good sdl openmpi unarchiver p7zip lzop lrzip pstoedit libmythes coin-or-mp libdvdnav libdvdread live-media lua-socket libnfs libcdio vcdimager libgme libdc1394 libdvdcss dav1d trash-cli libnma kdepim-addons kwalletmanager akonadiconsole perl-authen-sasl perl-cgi perl-datetime-format-iso8601 perl-libwww perl-lwp-protocol-https perl-mediawiki-api perl-mime-tools perl-net-smtp-ssl perl-term-readkey subversion tk perl-file-find-rule perl-test-pod pulseaudio-alsa packagekit-qt5 f2fs-tools exfat-utils nilfs-utils udftools fatresize flite speech-dispatcher

sudo systemctl enable sddm
sudo systemctl enable NetworkManager

yay -S syncthingtray wire-desktop turtl


# Custom kernel
To use RoMA you need to use a customed version avec linux kernel.
It's only affect the way how the traffic between multiple route is manage.
It also add a sysctl parameter (custom_multipath), this parameter can be set to 0 or 1.
If it's set to 0 the traffic is split depending on client/server information (native) and to 1 to use our custom code to split it depending on PID.

If you know how to do it you can use kernel.patch and apply it.


## Installation guide
For the other, you had to download custom-RoMA-kernel-5.18-rc2.tar.gz and follow these instructions :
First download and extract the tarball
```
wget https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-5.18.5.tar.xz
tar xvf linux-5.18.5.tar.xz
```
Then install all the package you need to compile the kernel
```
sudo apt-get install git fakeroot build-essential ncurses-dev xz-utils libssl-dev bc flex libelf-dev bison
```
Load the actual config of your kernel and then configure it.
Don't forget to set CONFIG_INET_DIAG_DESTROY to Y
```
cd linux
cp -v /boot/config-$(uname -r) .config
make menuconfig
```
And finaly compile and install it !
```
make
sudo make modules_install
sudo make install
sudo update-grub (if you use GRUB)
reboot
```

## Uninstallation guide
The defautl value of kernel_version is v5.18.0-rc2+
```
rm -rf /lib/modules/kernel_version
rm /boot/*kernelverion*
sudo grub-update (if you use GRUB)
reboot
```
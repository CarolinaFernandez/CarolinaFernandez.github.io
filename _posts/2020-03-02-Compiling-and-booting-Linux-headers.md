---
layout: post
title:  "Compiling and booting Linux headers"
description: "Compiling and booting Linux headers"
date:   2020-03-02 19:04:51
categories: deployment
tags: [unix]
comments: true
---

* TOC
{:toc}

Although relatively straightforward, compiling and selecting the Linux headers is too manual and is only partially explained at several different documents in the codebase. This entry provides some guidelines and also scripts to automate a bit the process. Find the **complete script at the bottom**.

<!--more-->

### Building

First of all, move to the [list of kernel sources](https://cdn.kernel.org/pub/linux/kernel/). Browse through it to find the desired version of the headers. You may download the sources and uncompress them into the disk. In this sample script the [kernel 4.14.151](https://cdn.kernel.org/pub/linux/kernel/v4.x/linux-4.14.151.tar.gz) is used.

{% include codeblock-header.html %}
```bash
header_version=4.14.151
header_dir=linux-${header_version}

mkdir -p ~/linux-headers
cd ~/linux-headers
current=$PWD

# Download sources
if [[ ! -d $header_dir ]]; then
    wget https://cdn.kernel.org/pub/linux/kernel/v4.x/$header_dir.tar.gz
    tar xvzf $header_dir.tar.gz
    cd ~/linux-headers/$header_dir
fi
```

Have a look at the <code>Documentation/process/changes.rst</code> file to understand the expected versions of the third-party libraries required for the compilation. Follow the process manually, then head to <code>Documentation/admin-guide/README.rst</code>.

First, the configuration must be defined. In this example we don't tailor anything, so it will take a considerable amount of space (not being accurate, you should probably make sure you have 10GB+ of available disk).

{% include codeblock-header.html %}
```bash
# Note: before continue, perform all checks on the versions for the packages
cd ~/linux-headers/$header_dir

# Create configuration file (here, a sample one; not tailored)
## Note: the kernel will be larger when using a sample configuration
## For instance, you may consider saving 10-15 GB for this
cp /boot/config-$(uname -r) .config
```

It is now time to compile the headers and the kernel modules. The first command will prompt *a lot* of questions. After that, both commands will take a good amount of time to finish. In the example we are dedicating the full computing power (all the CPUs) to speed up the building process.

{% include codeblock-header.html %}
```bash
# Compile headers
make -j${cores}

# Compile kernel modules
## Note: "make -j${cores} would compile using all CPUs"
sudo make -j${cores} modules_install
```

### Installing

After the compilation it is now time to install the headers in the system and make them available for use.
You may find issues with configurations such as the locales. Just fix it and retry as needed.

{% include codeblock-header.html %}
```bash
# Install headers
## Note: be sure to properly setup the locales to correct values
## (e.g., everything to "en_US.UTF-8" did work)
sudo make -j${cores} install
## Note: after this, the kernel will be available under /lib/modules
```

### Enabling

After the installation, the system must know that this kernel is available for booting.

{% include codeblock-header.html %}
```bash
# Enable it for booting
sudo update-initramfs -c -k ${header_version}
sudo update-grub
```

If you would wish to select this version of the kernel for the next boot, you can either:

* Enable the GRUB menu and select it manually
* Modify manually the configuration flags under <code>etc/default/grub</code>, then set the flags as desired. For instance, set something like *GRUB_DEFAULT="Advanced options for Ubuntu>Ubuntu, with Linux 4.14.151"*
* Use some tool like [grub-customizer](https://launchpad.net/grub-customizer). This one is handy when your VM is not able to show the GRUB menu. When running it, move to the "General settings" tab, then choose "default entry > predefined" and pick the specific version from the list

The latter option can be installed and run as follows:

{% include codeblock-header.html %}
```bash
# Install grub-customizer
sudo add-apt-repository ppa:danielrichter2007/grub-customizer
apt-get update
sudo apt-get install grub-customizer
## Note: only needed for the usage of grub-customizer when connecting by xterm
sudo apt install x11-xserver-utils -y
# Run it (will require X11 previously installed in the system)
sudo grub-customizer
```

### Altogether

All the script put together, for convenience. Note that this works for building kernel 4.14.151 on an Ubuntu 16.04.4 LTS.

{% include codeblock-header.html %}
```bash
#!/bin/bash

header_version=4.14.151
header_dir=linux-${header_version}
cores=$(nproc --all)

mkdir -p ~/linux-headers
cd ~/linux-headers
current=$PWD

# Download sources
if [[ ! -d $header_dir ]]; then
    wget https://cdn.kernel.org/pub/linux/kernel/v4.x/$header_dir.tar.gz
    tar xvzf $header_dir.tar.gz
    cd ~/linux-headers/$header_dir
fi

# Install make
sudo apt install -y build-essential

cd ~

# Install third-party requirements
if [[ ! -d ~/mcelog ]]; then
    git clone git://git.kernel.org/pub/scm/utils/cpu/mce/mcelog.git
    cd mcelog
    make
    sudo make install
fi

cd $PWD

# Install third-party requirements
sudo apt install -y jfsutils reiserfsprogs xfsprogs btrfs-progs pcmciautils quota ppp nfs-common procps oprofile udev grub iptables openssl bc
sudo apt install -y libelf-dev libssl-dev

# Check versions to fit those in Documentation/process/changes.rst
gcc --version
make --version
ld -v
fdformat --version
depmod -V
e2fsck -V
fsck.jfs -V
fsck.jfs -V
reiserfsck -V
xfs_db -V
mksquashfs -version
dpkg -l | grep btrfsck
pccardctl -V
dpkg -l | grep quota
pppd --version
showmount --version
ps --version
dpkg -l | grep oprofile
dpkg -l | grep udev
grub --version || grub-install --version
dpkg -l | grep mcelog
iptables -V
openssl version
bc --version
perl --version
perldoc -l Getopt::Long
perl -MGetopt::Long -le 'print $INC{"Getopt/Long.pm"}'
perl -MGetopt::Std -le 'print $INC{"Getopt/Std.pm"}'
perl -MFile::Basename -le 'print $INC{"File/Basename.pm"}'
perl -MFile::Find -le 'print $INC{"File/Find.pm"}'

# Create configuration file (here, a sample one; not tailored)
## Note: the kernel will be larger when using a sample configuration
## For instance, you may consider saving 10-15 GB for this
cd ~/linux-headers/$header_dir
cp /boot/config-$(uname -r) .config
df -h

# Compile headers
make -j${cores}

# Compile kernel modules
## Note: "make -j${cores} would compile using all CPUs"
sudo make -j${cores} modules_install
# Install headers
## Note: be sure to properly setup the locales to correct values
## (e.g., everything to "en_US.UTF-8" did work)
sudo make -j${cores} install
## Note: after this, the kernel will be available under /lib/modules

df -h

# Enable it for booting
sudo update-initramfs -c -k ${header_version}
sudo update-grub

# Install grub-customizer
sudo add-apt-repository ppa:danielrichter2007/grub-customizer
apt-get update
sudo apt-get install grub-customizer
## Note: only needed for the usage of grub-customizer when connecting by xterm
sudo apt install x11-xserver-utils -y
# Run it (will require X11 previously installed in the system)
sudo grub-customizer

df -h
```

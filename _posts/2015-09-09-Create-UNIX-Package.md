---
layout: post
title:  "Creating a UNIX package"
description: "Steps to create a UNIX package on Debian and RedHat based distributions"
date:   2015-09-09 08:47:16
categories: deployment
tags: unix
comments: true
---

* TOC
{:toc}

It is already some time since I first started a coding project to provide a tool that easily generates Debian or RedHat packages. This [project](https://github.com/CarolinaFernandez/unixpackage) is at a *somewhat debatable stable state*, with instructions and examples on different README files, and also a step-by-step guide in the wiki. <!--more-->There is ma---any stuff to improve on the packaging options, the bundling modes or the UI itself; but it does the work for simpler projects.

While Python's [Tkinter](https://docs.python.org/2/library/tkinter.html) library is quite straightforward, Java AWT or [Swing](http://docs.oracle.com/javase/tutorial/uiswing/) libraries produced a more refined interface -- yet the development UI takes more time than the development and debugging of the scripts themselves. Basically, the tool is a JAR package with a GUI (and CLI) wrapper on top of some Shell scripts.

---

So far with the history and brief contents of the tool. The idea behind the scripts is explained below, were you interested to understand it and bundling manually.

### DEB package

First, the Debian packages. These are the .deb files used to install sources through apt-get or other package manager. The benefits of packaging and installing following this standard is that there is a built-in registry and workflow (*hooks*) for installing and uninstalling such packages.

Put simply, these are the commands to create a Debian package:

```console
# Creating a Debian package
# Creating compressed file with sources
tar --ignore-failed-read -pczf ${package_name}_${package_version}.tar.gz ${package_name}_${package_version}

# Export full name of the packager or author
export DEBFULLNAME=$name

# Note that "--yes" may be not accepted by your dh_make application
# This will generate the control files under "debian/". Make sure to edit them as needed and
# to place sources under "debian/contents", following the same directory tree these will have
# when the package installs them on the final file system
dh_make --yes -n -$package_class -c $copyright -e $email -p ${package_name}_${package_version} -f $path_to_package.tar.gz

export DH_COMPAT=5
# Move to the root of the package
# Remove "-us -uc" if you wish to sign the package
/usr/bin/dpkg-buildpackage -F -us -uc --source-option=--include-binaries
```

Does not seem complicated, until trying to figure out where to put every file and, sometimes, which values to use for seemingly trivial parameters, as license/copyright, architecture, etc. Yet, as with most stuff, expertise comes with practise.

There are a myriad of configuration possibilities in the Debian control files, located under <code>debian/control</code>. For instance, you can define the behaviour before and after installing or uninstalling the package.

### RPM package

Unlike the Debian package system, the Red Hat package system is less constrained and, in my experience, more prone to funny behaviours upon installation and update of the packages. On the other hand, RPM packages are much easier to generate. For instance, the [structure of the folders](http://www.rpm.org/max-rpm/ch-rpm-build.html) is quite clear.

Here are the steps I followed:

```console
# Creating a Red Hat package
# Create specific user to generate RPM packages
useradd $unixpackage_user -m -s /bin/bash

# Create specific structure for package
mkdir {RPMS,SRPMS,BUILD,SOURCES,SPECS}

# Create the SPEC file (SPEC/$package_name.spec) following a template or example
# (see https://fedoraproject.org/wiki/How_to_create_an_RPM_package#Examples), then
# place sources under "SOURCES", following the same directory tree these will have
# when the package installs them on the final file system

# Add "--sign" if you wish to sign the package
su $unixpackage_user -c "rpmbuild -ba SPECS/$package_name.spec"
```

The SPEC file (as it can be observed in [this example](https://fedoraproject.org/wiki/How_to_create_an_RPM_package#Examples)) provides a way to insert all package-related data in a single file. Data such as the package name, description, list of files to be installed, behaviours on build and install, or the changelog can be defined there.

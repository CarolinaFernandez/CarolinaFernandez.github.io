---
layout: post
brief_title:  "Linux envvars with Apache and Django"
title:  "Linux environment variables with Apache and Django"
description: "Use Linux environment variables to use in Apache and Django configuration files"
date:   2014-09-22 12:23:10
categories: development
tags: [django, apache, unix]
comments: true
---

* TOC
{:toc}

One of the basic issues any software developer or maintainer may face at some point is *how to provide the software such that it can be installed and run from anywhere*. Most people probably prefer a system where the configuration constraints for each software are as minimum as possible.

<!--more-->

If you are running a Django app on top of Apache, you may have at least 3 different files:

* `/etc/apache2/sites-available/some_app.conf`
* `/etc/apache2/conf.d/some_app-vhosts.conf`
* `/path/to/some_app/django.wsgi`

Let us assume the following points:

1. All these files are tracked into your repository, so personal configurations are out of the scope
1. The first file points to the installation path of some of the other files
1. The latter files use variables, relative paths, etc

In this specific case, the configuration inside the first file is tightly coupled to the physical distribution of the files. This means that, if some other files are moved, Apache won't be able to run the app.

---

To solve that, let us take the first configuration file (`/etc/apache2/sites-available/some_app.conf`) as an example:

```apache
Listen 5555
Use SimpleSSLWSGIVHost 5555 some_app /path/to/some_app
WSGIDaemonProcess monitor
WSGIScriptAlias / /path/to/some_app/wsgi/django.wsgi process-group=monitor application-group=%{GLOBAL}
```

The highlighted lines indicate the dependencies, where the physical structure (`/path/to/some_app`) is referenced. To change that, one method would be to use environment variables.

### Environment vars in Apache

Apache uses its own env vars which can be set (1) either using the [`SetEnv`](http://httpd.apache.org/docs/2.0/mod/mod_env.html#setenv) directive into your vhost configuration file (check an [example](http://stackoverflow.com/questions/10902433/setting-environment-variables-for-accessing-in-php)) or (2) exporting the env var directly from Apache's configuration files.

I opted for the second, since the vhost configuration file was not to be touched. The file is located at `/etc/apache2/envvars`, and variables can be exported like in any other Unix script.

<u>Referencing an Apache env var</u> from its configuration files is easy: just replace the path to the app for the variable, surrounded by braces.

That is, first add the environment variable to `/etc/apache2/envvars`.

```shell
# envvars - default environment variables for apache2ctl

# this won't be correct after changing uid
unset HOME

# for supporting multiple apache2 instances
if [ "${APACHE_CONFDIR##/etc/apache2-}" != "${APACHE_CONFDIR}" ] ; then
	SUFFIX="-${APACHE_CONFDIR##/etc/apache2-}"
else
	SUFFIX=
fi

# Since there is no sane way to get the parsed apache2 config in scripts, some
# settings are defined via environment variables and then used in apache2ctl,
# /etc/init.d/apache2, /etc/logrotate.d/apache2, etc.
export APACHE_RUN_USER=www-data
export APACHE_RUN_GROUP=www-data
export APACHE_PID_FILE=/var/run/apache2$SUFFIX.pid
export APACHE_RUN_DIR=/var/run/apache2$SUFFIX
export APACHE_LOCK_DIR=/var/lock/apache2$SUFFIX
# Only /var/log/apache2 is handled by /etc/logrotate.d/apache2.
export APACHE_LOG_DIR=/var/log/apache2$SUFFIX

## The locale used by some modules like mod_dav
export LANG=C
## Uncomment the following line to use the system default locale instead:
#. /etc/default/locale

export LANG

## The command to get the status for 'apache2ctl status'.
## Some packages providing 'www-browser' need '--dump' instead of '-dump'.
#export APACHE_LYNX='www-browser -dump'

## If you need a higher file descriptor limit, uncomment and adjust the
## following line (default is 8192):
#APACHE_ULIMIT_MAX_FILES='ulimit -n 65536'


## If you would like to pass arguments to the web server, add them below
## to the APACHE_ARGUMENTS environment.
#export APACHE_ARGUMENTS=''

# Your own environment variables
export SOME_APP_PATH=/path/to/some_app
```

Then, reference the env var from a given Apache configuration file. And don't forget the enclosing braces.

```apache
Listen 5555
Use SimpleSSLWSGIVHost 5555 some_app ${SOME_APP_PATH}
WSGIDaemonProcess monitor
WSGIScriptAlias / ${SOME_APP_PATH}/wsgi/django.wsgi process-group=monitor application-group=%{GLOBAL}
```

### Environment vars in Unix

OK, you may need variables within the Apache environment because some configuration files need them. Fine. But why environment variables in Unix?

Because you may need to access those variables from within your application code. This can naturally be circumvented by using relative paths within your app, and I personally think that's a neater way. If you did it, feel free to skip this section and go for the final result.

There may be multiple ways to do this. The one I chose was to create a new script under `/etc/profile.d` and export a variable with the path to the app. Note that this method has at least one **rawback**: the data inside the script is only evaluated after the user logs in. This means that any change in this file needs to re-enter the user's session.

You should assess how much this operation is likely to happen in your system and choose the option best suited for you. In this case, this option seemed good enough.

To <u>access the Unix env vars from Python</u> (e.g. from your Django app), just pass the env var's name to the [`os.getenv`](https://docs.python.org/2/library/os.html#os.getenv) module from within your Python code and you are done.


In order to do that, add the same value to a global env var in `/etc/profile.d/some_app.sh`.

```shell
#!/bin/bash

export SOME_APP_PATH=/path/to/some_app
```

Finally, use it inside your Python code.

```python
import os

some_app_path = os.getenv("SOME_APP_PATH")
```

That's all. Keep in mind to keep these variable synchronised after any change.

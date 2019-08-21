---
layout: post
brief_title:  "IptabLex/IptabLes XOR.DDoS on UNIX"
title:  "IptabLex/IptabLes XOR.DDoS attack on UNIX"
description: "Some actions to mitigate the effects of the IptabLex/IptabLes XOR.DDoS attack"
date:   2015-03-16 15:32:45
categories: security
tags: [unix, botnet]
comments: true
---

* TOC
{:toc}

For almost a year now, I have had the opportunity to work with a small network of machines part of a high-speed network and publicly facing the Internet - thus consequently reachable by everyone. During the last quarter of the previous year (around November 2014) and the first quarter of the current one (around February 2015), these machines were targeted by Chinese attackers. They gained access to some of the machines, probably by brute-force attacks via SSH, and placed a couple of binaries that infected the machine to -I assume- send continuous traffic to a set of targeted locations. <!--more-->At the end of the day, this is nothing new: if you have machines connected to the Internet that are not properly maintained or secured (e.g. weak passwords, default SSH port, allowing access as root, lacking a firewall, etc) is music to the attacker's ears.

This comes after I firstly noticed strange behaviours on a number of machines: <code>top</code> showed a strange process called *IptabLex* (or a random sequence of characters, in later attacks) consuming tons of CPU. Apparently, this process forced the machine to be part of a DDoS-based botnet. The first wave of the attack is commented in the [CSO blog](http://www.csoonline.com/article/2600353/malware-cybercrime/new-botnet-research-from-prolexic-research-team.html) and analysed in ["Malware Must Die!"](http://blog.malwaremustdie.org/2014_06_01_archive.html). As for the second wave, [a detailed explanation is given in this post](https://www.fireeye.com/blog/threat-research/2015/02/anatomy_of_a_brutef.html), among a description of its variants and the rootkit (XOR.DDoS) used by the attackers.

In this post I'll summarise what a colleague and me found on the matter. If you fear your machine is infected, you could get a glimpse of the attack here, but be aware that the attack may be further improved by the time you read this.

### First attack wave

During the first attack I noticed an outrageous % of CPU consumption on one of the machines, which was due to a strange file, called *IptabLex* and located under the */root/* folder. By that time, I just killed its process and removed the file, then checked again that the consumption was okay. At this point I did not investigate further, as I am not the sysadmin for these machines, and the consumption seemed just fine.

### Second attack wave

During February, however; the problem with the consumption of CPU had extended to some other machines. A considerable number of our experimental network had been compromised at that point of time. However, the attack seemed more subtle this time: the consuming process respawned with a different name after its previous instance was killed and even some files removed. Let's assume there's an infected machine and let's go step by step on this.

### What to do now?

The safest and cleanest option is install from scratch or restore a backup. See [this](http://askubuntu.com/questions/407457/help-my-server-has-been-hacked-iptables-and-iptablex-in-boot) and [this](http://serverfault.com/questions/218005/how-do-i-deal-with-a-compromised-server). This is sort of an *embuggerance*, in Pratchett's terms.

However, this post is not focused on installing from scratch or restoring a previous version. If you have a complex environment and for whatever reason you have not documented, automated or performed a backup of your deployment; then you may prefer try sanitizing your environment to continue working on the machine as soon as possible. This is <span style="text-decoration: underline;">not</span> a thorough guide, but here are some hints that may help you to identify the problem, isolate it and hopefully, destroy it. As already said, this explanation attempts to be a workaround to fix a compromised environment so you can resume work on your machine, having back its full capacity; but nevertheless, <span style="text-decoration: underline;">you should do a clean install of your OS</span> in the machine as soon as possible.

#### Find the compromised node

It usually seems hard to identify [whether your machine is part of a DDoS botnet](http://security.stackexchange.com/questions/12446/how-do-i-know-if-my-computer-is-being-used-for-a-botnet-based-ddos-attack), as the first thing the attacker does is cover their footprints.

In this case, while the malicious binaries attempt to hide themselves, it is actually (still) possible to see them. Providing a given machine reports strange consumption of CPU, you should originally look for the files *IptabLes*, *IptabLex*; but now also for files *aiziwen* and *2862ashui8u*.

```console
# ls -la /boot
total 1812
drwxr-xr-x  2 root root    4096 Nov 24 05:52 .
drwxr-xr-x 21 root root    4096 Sep 27 13:33 ..
-r--------  1 root root 1103207 Sep 27 13:33 .IptabLes
-r--------  1 root root  722392 Sep 27 13:33 .IptabLex
-r--------  1 root root      33 Sep 27 13:33 IptabLes
-r--------  1 root root      33 Sep 27 13:33 IptabLex
```

```console
# ls -la /root
total 1812
drwxr-xr-x  2 root root    4096 Nov 24 05:52 .
drwxr-xr-x 21 root root    4096 Sep 27 13:33 ..
-r--------  1 root root  610309 Jan 20 11:22 2862ashui8u
-r--------  1 root root 1223123 Feb 03 10:08 aiziwen
```

These are the paths of the infected files in my machines, corresponding to the first and second attack, respectively. Note that their locations may vary for future attacks and maybe in different machines.

Besides, you should also check <code>top</code>:

```console
# top

top - 10:02:30 up 13 min,  2 users,  load average: 0.80, 0.61, 0.36
Tasks:  51 total,   1 running,  50 sleeping,   0 stopped,   0 zombie
Cpu(s):  9.6%us, 47.3%sy,  0.0%ni, 39.0%id,  0.1%wa,  0.0%hi,  3.5%si,  0.5%st
Mem:    506004k total,    54044k used,   451960k free,     4000k buffers
Swap:        0k total,        0k used,        0k free,    21720k cached

  PID USER      PR  NI  VIRT  RES  SHR S %CPU %MEM    TIME+  COMMAND                                                                   
  537 root      20   0 33848  616  208 S 69.1  0.1   7:52.97 djaafnvlvv                                                                
    1 root      20   0  8404  800  668 S  0.0  0.2   0:00.75 init                                                                      
    2 root      20   0     0    0    0 S  0.0  0.0   0:00.00 kthreadd                                                                  
    3 root      20   0     0    0    0 S  0.0  0.0   0:00.06 ksoftirqd/0                                                               
    4 root      20   0     0    0    0 S  0.0  0.0   0:00.00 kworker/0:0                                                               
    5 root      20   0     0    0    0 S  0.0  0.0   0:00.00 kworker/u:0                                                               
    6 root      RT   0     0    0    0 S  0.0  0.0   0:00.00 migration/0                                                               
    7 root      RT   0     0    0    0 S  0.0  0.0   0:00.00 watchdog/0
```

See that process with random characters? It's consuming a lot of CPU and seems to have a random name. It does not seem the typical Unix process. If your machine presents any of these symptoms, then you can assume it is infected.

#### Isolate the node

First things first: you have to get the machine off the public network. Do you have physical access to it? Great! Work locally only. Don't you have? You can either inform the sysadmin and seek for help or try to fix it first by yourself. However, if you want to proceed alone in the first stage, <span style="text-decoration: underline;">you should be confident that you are able to stop and start the machine anytime you want</span>. This is so because you shouldn't leave this machine connected to a public network more time than necessary. Remember, it is being used to attack other machines.

#### Basic attack understanding

Look first for the process with the random name that is consuming most of the machine's CPU (*djaafnvlvv* for this iteration). You should perform a <code>lsof -p $process_pid</code>. This will give you the physical location of the files used to run the process. Alternatively, you could directly scan the filesystem for it:

```console
# find / -name "djaafnvlvv"
/usr/bin/djaafnvlvv
/etc/init.d/djaafnvlvv
/var/lib/update-rc.d/djaafnvlvv
```

Then, have a look at the content of the files, for instance, the file under */etc/init.d/*:

```console
# cat /etc/init.d/djaafnvlvv
#!/bin/sh
# chkconfig: 12345 90 90
# description: djaafnvlvv
### BEGIN INIT INFO
# Provides:		djaafnvlvv
# Required-Start:
# Required-Stop:
# Default-Start:	1 2 3 4 5
# Default-Stop:		
# Short-Description:	djaafnvlvv
### END INIT INFO
case $1 in
start)
	/usr/bin/djaafnvlvv
	;;
stop)
	;;
*)
	/usr/bin/djaafnvlvv
	;;
esac
```

The file */etc/init.d/djaafnvlvv* is an [initscript](http://www.linux.com/learn/tutorials/442412-managing-linux-daemons-with-init-scripts) that starts the infected ELF binary file (*/usr/bin/djaafnvlvv*). You could try <code>strings $binary_file</code> to see the strings, the human-readable text. As an example, here are the 6 last lines of one of the original infected binaries, */root/2862ashui8u* - which, if I remember correctly, copied itself under */lib/libgcc4.4.so*:

```console
# strings /root/2862ashui8u | tail -n 6
cp /lib/libgcc4.so /lib/libgcc4.4.so
/lib/libgcc4.4.so
BB2FA36AAA9541F0
103.25.9.228
8.8.8.8
CAk[S
```

The first IP matches against an open connection, opened by one of the attacker's processes. Some lines before that, there's a dynamic library, *libgcc4.4.so*, that replaces the one in the system and is executed afterwards. That behaviour is really fishy and *alarms should be blaring by now*. You can find [an interesting and more complete analysis of this attack here](https://www.fireeye.com/blog/threat-research/2015/02/anatomy_of_a_brutef.html). You may notice in the previous post that the *BB2FA36AAA9541F0* XOR key also appears. This is another indicator of an infected machine, in this case corresponding to the variant no. 2 of the attack.

Coming back to the analysis of the files, checking the strings in the */root/aiziwen* file (<code>strings /root/aiziwen | grep -E -o "([0-9]{1,3}[\.]){3}[0-9]{1,3}</code>) returned tons of IPs, among them, several belonging to CHINANET and another located in California.

So far, it seems that the two initial files were downloaded into the machine and executed, then, an infected version of *libgcc4.4.so* is placed under */lib* and executed as well. After killing the process with a SIGKILL signal (<code>kill -9 <pid></code>) to the active process (e.g. *djaafnvlvv* for this round), another process with a similarly random name starts to run after a while. There's something looking on the background for this kind of signal. Also, after removing the */lib/libgcc4.4.so* library, it appears after some minutes.

Now, open the */etc/crontab* file with your preferred editor. We saw the following entry at the end of the file:

```console
# vim /etc/crontab
(...)
*/3 * * * * root /etc/cron.hourly/udev.sh
```

Although the name of the file may vary in different attacks, the behaviour is the same: every 3 minutes, it calls that script. I do not recall its contents as it is already removed, but this one ran the infected process with the random name. At the same time, this entry is generated by the copy of the virus (presumably in */lib/libgcc4.4.so*); which makes this whole stuff act in a cyclic fashion, one spawning the other and viceversa.

#### Search for open connections

This step is not that useful to clean your system, but it is interesting to know which location is your infected machine trying to flood, or from where it is downloading the infected files. The next step deals with cleaning the system, so you may just skip there.

Looking at the open connections (<code>lsof -i tcp</code>) related to the infected files, we found the server from where the two infected files mentioned in the first step were being downloaded:

```console
# curl -I -L http://222.186.134.6:6678
HTTP/1.1 200 OK
Content-Type: text/html
Content-Length: 5402
Accept-Ranges: bytes
Server: HFS 2.3 beta
Set-Cookie: HFS_SID=0.327055824687704; path=/;
Cache-Control: no-cache, no-store, must-revalidate, max-age=-1
```

Such IP belongs to CHINANET and seems to be [blacklisted because of spam and botnets](http://www.tcpiputils.com/browse/ip-address/222.186.134.6).

```console
$ whois 222.186.134.6

#
# ARIN WHOIS data and services are subject to the Terms of Use
# available at: https://www.arin.net/whois_tou.html
#
# If you see inaccuracies in the results, please report at
# http://www.arin.net/public/whoisinaccuracy/index.xhtml
#


#
# Query terms are ambiguous.  The query is assumed to be:
#     "n 222.186.134.6"
#
# Use "?" to get help.
#

#
# The following results may also be obtained via:
# http://whois.arin.net/rest/nets;q=222.186.134.6?showDetails=true&amp;showARIN=false&amp;ext=netref2
#

NetRange:       222.0.0.0 - 222.255.255.255
CIDR:           222.0.0.0/8
NetName:        APNIC8
NetHandle:      NET-222-0-0-0-1
Parent:          ()
NetType:        Allocated to APNIC
OriginAS:
Organization:   Asia Pacific Network Information Centre (APNIC)
RegDate:        2003-02-13
Updated:        2010-07-30
Comment:        This IP address range is not registered in the ARIN database.
Comment:        For details, refer to the APNIC Whois Database via
Comment:        WHOIS.APNIC.NET or http://wq.apnic.net/apnic-bin/whois.pl
Comment:        ** IMPORTANT NOTE: APNIC is the Regional Internet Registry
Comment:        for the Asia Pacific region. APNIC does not operate networks
Comment:        using this IP address range and is not able to investigate
Comment:        spam or abuse reports relating to these addresses. For more
Comment:        help, refer to http://www.apnic.net/apnic-info/whois_search2/abuse-and-spamming
Ref:            http://whois.arin.net/rest/net/NET-222-0-0-0-1

OrgName:        Asia Pacific Network Information Centre
OrgId:          APNIC
Address:        PO Box 3646
City:           South Brisbane
StateProv:      QLD
PostalCode:     4101
Country:        AU
RegDate:
Updated:        2012-01-24
Ref:            http://whois.arin.net/rest/org/APNIC

ReferralServer: whois://whois.apnic.net

OrgAbuseHandle: AWC12-ARIN
OrgAbuseName:   APNIC Whois Contact
OrgAbusePhone:  +61 7 3858 3188
OrgAbuseEmail:  search-apnic-not-arin@apnic.net
OrgAbuseRef:    http://whois.arin.net/rest/poc/AWC12-ARIN

OrgTechHandle: AWC12-ARIN
OrgTechName:   APNIC Whois Contact
OrgTechPhone:  +61 7 3858 3188
OrgTechEmail:  search-apnic-not-arin@apnic.net
OrgTechRef:    http://whois.arin.net/rest/poc/AWC12-ARIN


#
# ARIN WHOIS data and services are subject to the Terms of Use
# available at: https://www.arin.net/whois_tou.html
#
# If you see inaccuracies in the results, please report at
# http://www.arin.net/public/whoisinaccuracy/index.xhtml
#

% [whois.apnic.net]
% Whois data copyright terms    http://www.apnic.net/db/dbcopyright.html

% Information related to '222.184.0.0 - 222.191.255.255'

inetnum:        222.184.0.0 - 222.191.255.255
netname:        CHINANET-JS
descr:          CHINANET jiangsu province network
descr:          China Telecom
descr:          A12,Xin-Jie-Kou-Wai Street
descr:          Beijing 100088
country:        CN
admin-c:        CH93-AP
tech-c:         CJ186-AP
mnt-by:         APNIC-HM
mnt-lower:      MAINT-CHINANET-JS
mnt-routes:     MAINT-CHINANET-JS
remarks:        This object can only modify by APNIC hostmaster
remarks:        If you wish to modify this object details please
remarks:        send email to hostmaster@apnic.net with your
remarks:        organisation account name in the subject line.
changed:        hm-changed@apnic.net 20040223
status:         ALLOCATED PORTABLE
source:         APNIC

role:           CHINANET JIANGSU
address:        260 Zhongyang Road,Nanjing 210037
country:        CN
phone:          +86-25-86588231
phone:          +86-25-86588745
fax-no:         +86-25-86588104
e-mail:         ip@jsinfo.net
remarks:        send anti-spam reports to spam@jsinfo.net
remarks:        send abuse reports to abuse@jsinfo.net
remarks:        times in GMT+8
admin-c:        CH360-AP
tech-c:         CS306-AP
tech-c:         CN142-AP
nic-hdl:        CJ186-AP
remarks:        www.jsinfo.net
notify:         ip@jsinfo.net
mnt-by:         MAINT-CHINANET-JS
changed:        dns@jsinfo.net 20090831
changed:        ip@jsinfo.net 20090831
changed:        hm-changed@apnic.net 20090901
source:         APNIC
changed:        hm-changed@apnic.net 20111114

person:         Chinanet Hostmaster
nic-hdl:        CH93-AP
e-mail:         anti-spam@ns.chinanet.cn.net
address:        No.31 ,jingrong street,beijing
address:        100032
phone:          +86-10-58501724
fax-no:         +86-10-58501724
country:        CN
changed:        dingsy@cndata.com 20070416
changed:        zhengzm@gsta.com 20140227
mnt-by:         MAINT-CHINANET
source:         APNIC

% This query was served by the APNIC Whois Service version 1.69.1-APNICv1r0 (UNDEFINED)
```

***Update on March 22th, 2015:</strong> the server seems to be already taken down.***

#### Disinfect the system

The logical step now is to break the aforementioned vicious circle and remove the infected files. But it's not that easy. Besides the loop of replications, there are some inconveniences: some of the files cannot be removed, even by the root user.

Someone who is not a sysadmin, or at least not fully devoted to it :), may be bewildered at this point. How was it that root couldn't make something? Well... Seems that the infected files were changed its attributes to be *immutable*.

```console
# lsattr -la /root
./.                          ---
./..                         ---
./aiziwen                    Immutable
./2862ashui8u                Immutable
```

You must [change the attributes of the files back to mutable](http://unix.stackexchange.com/a/29904/90930) before being able to delete them.

```console
chattr -i -a  /root/aiziwen
rm /root/aiziwen
chattr -i -a  /root/2862ashui8u
rm /root/2862ashui8u
```

Use the previous as a side note to consider during the clean up process. I copy here and adapt the clean process described by [Serhii](http://superuser.com/users/27571/serhii) in the SuperUser's *["DDoS Virus infection (as a unix service) on a Debian 8 VM Webserver"](http://superuser.com/questions/863997/ddos-virus-infection-as-a-unix-service-on-a-debian-8-vm-webserver/868147#868147")* thread:

1. Remove the line in */etc/crontab* that calls to an infected script every 3 minutes.
1. Identify the parent process of the virus (<code>top</code>, then <code>f</code>, then <code>b</code>). Stop it (do not kill it, as this signal triggers a respawn), e.g. with <code>kill -STOP 1632</code>.
1. Check that only the parent infected process lives (e.g. <code>ps aux</code>). The children should die quickly.
1. Delete the infected files under */usr/bin/*, */etc/init.d/*, */root/*, */boot/* and so on. Leave the */lib/libgcc4.4.so* for the moment! To identify any lately modified file (such as the binaries for <code>kill</code>, <code>top</code>, <code>ps</code>, etc), list the files in that folder like this: <code>ls -latr</code> and you'll see the recently modified files at the bottom.
1. Remove the infected cron script in */etc/cron.hourly/udev.sh* (name may vary) and the */lib/libgcc4.4.so* files.
1. Kill completely the infected process.

After cleaning, I recommend you to spend some time looking at <code>top</code> (to see the most-consuming CPU processes), <code>uptime</code> to see the system load average during the last 1, 5 and 15 minutes. See that these numbers correspond to your usage, and not to the virus. Look thoroughly for any other modified files that may be dampering your vision for the overall system status, such as the aforementioned system binaries for <code>top</code> or <code>ps</code>.

#### Update, patch and secure

After all you've passed to try to clean the environment, it's advisable to add proper security. This means updating and upgrading your system in order to patch any security hole, such as [shellshock ](https://cve.mitre.org/cgi-bin/cvename.cgi?name=CVE-2014-6271) (CVE-2014 in all its variants: 6277, 6278, 7169, 7186 and 7187).

It is very important to identify the **attack vector**: do you use a weak password, or run a server not properly maintained that may expose some security? All of that (and more) can be used to break into your system. In the CSO blog they suggest the attackers may be exploiting problematic versions of Apache and other servers to gain access. This was not our case, as these servers are not present in our machines. However, using weak passwords may very well be the cause. The first measure of the series was to increase the password complexity as well as installing a lockout program after a given number of failed login attempts.

I believe that the following is a list of reasonable improvements to make their attacks a little harder the next time:

* **Configure IPtables**: if possible, dropping or rejecting every packet but the ones from a preferred network would be the ideal situation. Otherwise, try to block any traffic coming from/to the IPs found on the 3rd step.
* **Disable root access**: if an attacker enters as root access, then your system is done. If, on the other hand, they only get normal user access, they won't be able to modify system files or run some services. A good way to unite security and practicality is to protect your accessing user (e.g. accessing only via public keys) and adding it to the *sudoers* file.
* **Change your password**: needless to say, the password should be strong enough. Combine letters with numbers symbols, cap, etc etc.
* **Add extra log-in controls**: for instance, [fail2ban](http://www.fail2ban.org/wiki/index.php/Main_Page) locks any user that surpasses a number of log-in attempts. You may even add an IPtables rule to allow only connections from a whitelisted range of IPs.
* **Reconfigure SSH daemon**: another way to protect your server, afaik, is properly configuring your */etc/ssh/sshd_config* configuration file. There, you can add some *security by obscurity* by changing the default SSH port to a random port of your choice. This may not be the most brilliant solution, but it makes attacking slightly more difficult.
* **Restrict access to some locations**: going further, it may be a good practice to restrict access to a subset of public keys; for instance your personal and work computers. Brute-force attack is simply non-viable with this approach.

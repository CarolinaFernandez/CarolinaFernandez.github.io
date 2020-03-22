---
layout: post
title:  "Triggering Git branch updates with Jenkins"
description: "Configure Jenkins to detect updates on a branch and automatically merge against another"
date:   2015-10-13 01:45:04
categories: devops
tags: [jenkins, github]
comments: true
---

* TOC
{:toc}

Git hooks are undoubtedly useful and convenient to integrate with many other tools. One of the tasks I had in mind was to configure Jenkins in a proper way so as to receive notifications from pushes in GitHub and use those to do an internal process -- in this specific case, triggering a merge between every modified branch and the master one.

<!--more-->

*Yet this can be considered as either kind of bold, or under the assumption of limitless trust between the developers; the concept itself can be re-used for many other deployments where your CI requires to be aware of changes per branch in order to trigger some other action.*

### Define the scenario

When developing within a collaborative environment, there are multiple approaches to divide the work among different teams. The approach we use to build our framework is to create a branch per software component, plus a master one where all the others are merged into.

The merging task may be done manually or automatically. In the former case, one or more members of the team shall scan the chosen repository (e.g. GitHub) for changes, optionally validate them and integrate into the master branch. In the later case, no validation will take place as process will be automatically carried out through scripts. If done correctly (i.e. common structure is respected across branches and any change triggers a merge), an automatic merge should work smoothly.

You can find below the steps I followed to configure our environment so as to pull sources and automatically integrate them into *master* branch. There are probably other ways, using some existing plug-ins in Jenkins (maybe with [Git Plug-in](https://wiki.jenkins-ci.org/display/JENKINS/Git+Plugin#GitPlugin-UsingGit%2CJenkinsandprebuildbranchmerging)...).

The following steps **assume** the following:

* Public repository available in GitHub
* Jenkins used as CI tool
* Organisation of the repository:
  * N branches, one per component (e.g. _"component1"_, _"component2"_, ...)
  * One branch to merge them (e.g. _"master"_)
  * Similar or complementing structure across branches (i.e. preferably work in different directories and leave the root clean of files to modify)

### Configuring Jenkins

First things first: Jenkins must be installed and configured.

```shell
# Installing Jenkins
apt-get install jenkins
```

Jenkins will automatically start after some time on the port *8080*.

Another port can be chosen in the *HTTP_PORT* directive under the */etc/default/jenkins* file. Also, if you use some DNS for easy access and you wish to use Nginx, you may create a new site file under */etc/nginx/sites-enabled/* and link it from */etc/nginx/sites-available/*:

```shell
server {
  listen 80;
  server_name <ci.subdomain.domain>;
  server_tokens off;

  location / {
    proxy_pass              http://localhost:8080;
    proxy_set_header        Host $host;
    proxy_set_header        X-Real-IP $remote_addr;
    proxy_set_header        X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_connect_timeout   150;
    proxy_send_timeout      100;
    proxy_read_timeout      100;
    proxy_buffers           4 32k;
    client_max_body_size    8m;
    client_body_buffer_size 128k;
    # Temporarily uncomment the following to debug incoming requests
    #log_format postdata '$request $request_body';
    #access_log  /var/log/nginx/postdata.log  postdata;
  }
  ssl_protocols        TLSv1;
}
```

### Tasks to detect & pull changes

To detect changes in any of the N branches from your project, you should create tasks to retrieve the latest sources upon any change:

#### Parameterize build

The task will receive a POST request from GitHub, which contains a parameter called "*payload*" and whose contents are a JSON structure. Thus the task must be [parameterized](ttps://wiki.jenkins-ci.org/display/JENKINS/Parameterized+Build) by using a text value with the name "*payload*".

![alt text][param_task]

#### Pull source per branch

Set up the repository details to pull the source code and check out to the specific branch (e.g. "*component1*"). You may also place the code in a specific directory, e.g. outside the Jenkins workspace. 

![alt text][repo_details]

#### Trigger remote builds

Enable the checkbox to trigger building this task remotely (through the GitHub webhooks) and define an authentication token, such as "*organisation-git-push-component1*". The resulting address will be something such as "*http://&#60;ci.subdomain.domain&#62;/job/git-pull-component1/buildWithParameters?token=organisation-git-push-component1*".

![alt text][trigger_rem_build]

#### Identify the modifed branch

In the conditional step, add scripting code that process the incoming payload.

![alt text][run_add_tasks]

This script processes the GitHub payload to fetch the name ("*ref*") of the branch where some changes were pushed. Any other processing of the payload -such as obtaining the modified files, name and e-mail of the committer, commit hash, timestamp and so on- should be possible by following a similar procedure. Just bear in mind the structure of the GitHub payload, which you will be able to check by either looking at this [GitHub example](https://developer.github.com/v3/activity/events/types/#webhook-payload-example-15), enabling logging POST requests into your server of choice (e.g. Jenkins) or directly look into the "*GitHub Webhooks*" page, after any initial commit.

```bash
#!/bin/bash
current_branch="<current-module-name>"
# Retrieve branch name from payload
branch=$(echo $payload | python -c 'import json,sys;obj=json.load(sys.stdin);print obj["ref"]')
# Clean branch name
branch_name=${branch#*/}
branch_name=${branch_name#*/}
# Check branch that triggered the event
if [ $branch_name = $current_branch ]; then
  exit 0
else
  exit 1
fi
```

In this bash script, when *0* is returned, any dependant (downstream) task will take place. Otherwise (when *1* is returned), the task will end silently, with no errors.

*__Note__ that using the same script in the normal "*Execute Shell*" text area would result in an error, due to the triggered task attempting to process data from "<u>$branch_name</u>", when different to the expected "<u>$current_branch</u>".*

#### Add downstream tasks

Finally, if some other task depends on this one (downstream task), it shall be defined as such.

Within "*Conditional step (single)*" > "*Builder*" > "*Build triggers*" > "*Projects to build*", write the names of any merging task(s) to be performed after a successful build of this pull task.

### Create hooks in GitHub

Finally, the whole thing must be activated. After due configuration, GitHub is expected to send a POST request against the URL you define, which will triggering the specific task.

Use the same *authentication token* used in "*Enable triggering builds remotely*". The remote URL to add here is something like "*http://&#60;ci.subdomain.domain&#62;/job/git-pull-component1/buildWithParameters?token=organisation-git-push-component1*". It is VERY important to define "*Content Type*" as "*application/x-www-form-urlencoded*", as this enables GitHub to send the JSON payload as the value for the "*payload*" parameter defined in the first step.

### Bonus: the merging task

A simple task will do here. Just remember to call it from the pull task(s) as a downstream task and then add a suitable script to merge branches within the "*Build*" > "*Execute shell*" text area.

The following script is what I use for automatically merging every branch (component) with changes into the master one. It follows a simple approach, as it assumes every change in any modified branch is "trustworthy" and can be passed down to the master branch:

```bash
branch_name="master"
mkdir -p /tmp/project/
cd /tmp/project/

# Start from scratch every time
if [ -d $branch_name ]; then
  sudo rm -r $branch_name
fi
git clone git@github.com:organisation/project.git master

cd $branch_name
git checkout $branch_name
git pull origin $branch_name

set component1 component2 component3 component4 component5
branch_components=$*

git checkout $branch_name
current_branch_name="$(git symbolic-ref HEAD 2>/dev/null)" ||
current_branch_name="(unnamed branch)"     # detached HEAD
current_branch_name=${current_branch_name##refs/heads/}

# Retrieve first 5 characters from most recent log entry
current_last_commit=$(git log origin/$branch_name | head -1 | cut -d " " -f2 | cut -c1-5)

for branch in $branch_components; do
  echo "branch: $branch"
  # Avoid merging a branch with itself
  if [ $current_branch_name != $branch ]; then
    # Assume the code coming from other branches is properly tested, non breaking the project, etc...
    # This will use "theirs" strategy to accept every of the "new" (branch) changes as the reference
    git merge --squash -X theirs origin/$branch
    # Retrieve first 5 characters from last commit in the branch being merged into master
    branch_last_commit=$(git log origin/$branch | head -1 | cut -d " " -f2 | cut -c1-5)
    # Assumes there are no extra files in the pulled directory (i.e. directory is clean)
    git add -A
    git commit -m "Automatic merge of '$branch' ($branch_last_commit) into '$current_branch_name'" --author="project-jenkins <jenkins@localhost>" || true
  fi
done

# Retrieve first 5 characters from most recent log entry
final_last_commit=$(git log $branch_name | head -1 | cut -d " " -f2 | cut -c1-5)

if [ $current_last_commit != $final_last_commit ]; then
  echo "New merge into master... Pushing to repository"
  # Final step: push all changes
  git push origin master
fi
```

[param_task]: /img/post/2015-10-13-Jenkins-GitHub-Hooks-merge/jenkins-githook-task1.png?style=img-center "Parameterize the task with a text value"
[repo_details]: /img/post/2015-10-13-Jenkins-GitHub-Hooks-merge/jenkins-githook-task4.png?style=img-center "Set up repository details and check out behaviour"
[trigger_rem_build]: /img/post/2015-10-13-Jenkins-GitHub-Hooks-merge/jenkins-githook-task3.png?style=img-center "Enable triggering builds remotely"
[run_add_tasks]: /img/post/2015-10-13-Jenkins-GitHub-Hooks-merge/jenkins-githook-task4.png?style=img-center "Add conditional step to run and build other tasks"

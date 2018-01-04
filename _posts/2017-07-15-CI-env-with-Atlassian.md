---
layout: post
brief_title:  "CI and CD with Atlassian stack"
title:  "Continuous Integration and Delivery with Atlassian stack"
description: "Configure Bitbucket and Bamboo to manage development and deploy"
date:   2017-07-15 15:53:11
categories: ci
tags: [bitbucket, bamboo, slack]
comments: true
---

* TOC
{:toc}

Every collaborative development project leverages on a set of tools to facilitate some or all of the development, integration, testing and deployment stages. This document explains how to set-up a simple Continuous Integration and Continuous Delivery environment using part of the Atlassian stack (JIRA, Bitbucket, Bamboo) and Slack.

<!--more-->

### Define the scenario

The environment described hereafter consists of the following:

* Multiple software components hosted under the umbrella of one single project
* Self-hosted Jira, Bitbucket and Bamboo (meaning "*Server*", not "*Cloud*" -- *in fact more hooks are provided for cloud-based set-ups*)
  * Jira for issue tracking, board, release management
  * Bitbucket project with multiple repositories, each per component and with stable (_"master"_) and feature branches
  * Bamboo project with multiple build plans, each with one deployment plan
* GitHub public organisation

The aim of this document is to describe the development workflow (JIRA, Bitbucket, Slack), as well as the Continuous Integration (CI) and Continuous Delivery (CD) set-up (Bamboo, Slack).

Pre-requisites:

* The Atlassian stack should be previously installed and set-up so you own a given project to work on both JIRA, Bitbucket and Bamboo
  * JIRA is already configured
* A GitHub organisation is created, along with its repositories
* A Slack team and channel(s) are created beforehand so notifications can be sent (although not needed for the CI/CD set-up)

### Configuring Bitbucket

First, create the different repositories and configure these as required for your needs. You may need to specify *repository permissions* for specific developers, the *branching model* to define which types of issues and workflows are allowed, the minimum number of approvers, successful builds and tasks before *pull requests* can be merged, and so on.

#### Slack settings

For what is worth for the CI integration, it is possible to send hooks to Slack based on two main type of events: "*push*" (pushing code to the remote) and "*pull request*" (any event occurring on PRs). Under "*Add-ons*" it should be possible to see "*Slack settings*".

![alt text][bitbucket_repo_slack]

There, you should check "*Override settings for global slack notification options*", select the *notification level* (or verbosity) of the events for both push and PR, as well as the specific events that will trigger the hooks. It is straightforward for pushing, but PR can have multiple events based on creation, update, comment, merge and so on. Finally, define the "*Channel name*" of Slack to receive such events and the "*Webhook Url*" indicating the Slack incoming webhook (see "*Slack*" section below for details on how to do so).

#### Hooks

Besides this, under the "*Hooks*" option it is possible to find or add new applications from the Atlassian Marketplace. The CI environment here documented expects automatic mirroring of the self-hosted Bitbucket codebase into the repositories within the GitHub organisation. The "*[Repository Mirror Plugin for Bitbucket](https://marketplace.atlassian.com/plugins/com.englishtown.stash-hook-mirror/server/overview)*" plug-ins provides an straightforward way to mirror the code from Bitbucket to any Git-based url.

This simple approach has caveats too, as it uses a specific username for the mirroring but does not allow explicitly defining its name and e-mail; it is not possible to use in combination with a 2-factor authentication enabled-account in GitHub, and there is no way to configure specific push events or branches that should trigger the mirroring, leading to feature-based branches, not yet merged, being pushed into the public codebase.

### Configuring Bamboo

Bamboo allows defining **[build plans](https://confluence.atlassian.com/bamboo/configuring-plans-289276853.html)** and **[deployment projects](https://confluence.atlassian.com/bamboo/deployment-projects-338363438.html)** as a way to specifically separate the code fetching and compilation from the preparation of the environment and the deployment of the code or binaries generated before.

One project can contain multiple build plans, each containing a deployment project. Since the codebase used in this environment consists of multiple software components, each potentially running in one or more different environments at the same time; the configuration of Bamboo will be based on the following:

* 1 Bamboo project
  * N build plans (1 per software component)
    * M deployment project (1+ per build plan)

Note, however, that other combinations are typically perfectly feasible as well. For instance, one build plan for the whole codebase and one deployment project as well works well with a single-repository codebase to be all deployed to the same environment. Another option is to separate the build of the different software components by using branches within the same build plan, then use one or more deployment projects to address their deployment; and so on.

#### Build plan

The build plan defines different stages and jobs, the latter able to carry out multiple tasks.

![alt text][bamboo_build_tasks]

Typically, the codebase is checked out first, using the [Source Code Checkout](https://confluence.atlassian.com/bamboo/checking-out-code-289277060.html) task. For that, one or more tasks can be defined to pull the codebase from the defined repositories: [linked repositories](https://confluence.atlassian.com/bamboo/linking-to-source-code-repositories-671089223.html) are accessible from all build plans, otherwise these have to be defined per plan or task.

{% capture note-text %}The <em>Source Code Checkout</em> task checks the code out in the <code>${bamboo.build.working.directory}</code> by default. In case your software component contains multiple subcomponents, you may need to check out multiple repositories. To avoid overwriting, define a checkout folder per repository in the <em>Checkout Directory</em> field; e.g. "<em>subcomponentX</em>". Such folder is relative to the working directory; thus each codebase will be available at <code>${bamboo.build.working.directory}/subcomponentX</code>.
{% endcapture %}
{% include highlight-warning.html %}

After fetching all code required, other tasks can work on top of the code in order to compile it, run tests, copy to another location for later use in the deployment stages and so on.

#### Deployment project

A deployment project is linked to each build plan (in this case, for each software component). The project can be configured by defining its environment, local or remote agents assigned for deployments, manual or specific triggers to initiate the deployment, the release naming schema or the user's permissions to view and edit the project; amongst others ([see here](https://confluence.atlassian.com/bamboo/deployment-projects-workflow-362971857.html)).

![alt text][bamboo_deploy]

##### Tasks

Multiple deployment tasks coexist within the deployment project. For instance, tasks can send notifications on when the deployment starts and ends, transfer code or binaries to the deployment environment, configure the targeted environment on-the-fly or send remote commands to get some applications running.

In this simple scenario, the CD consists of two tasks defined to interact with the Slack hooks and notify users about the status of the deployment (useful for shared usage due to limited deployment capabilities and environments); and of a third one to transfer the codebase and/or files resulted from the previous build plan and stages to the target environment, as well as remote commands to make the component run.

{% capture note-text %}The deployment tasks occur after the build tasks. There are a number of <a href="https://confluence.atlassian.com/bamboo/bamboo-variables-289277087.html" target="_blank" title="Bamboo variables">Bamboo variables</a> to be used: some are specific to build time, others to deployment, others for releases, etc. Evaluate carefully each of them within the tasks, specially when re-using across build and development stages.
{% endcapture %}
{% include highlight-note.html %}

![alt text][bamboo_deploy_tasks]

The first and final tasks send a REST payload, formatted in JSON, to the specific incoming webhook (described in the *Slack* section). The payload explicitly indicates the Slack channel where to post the notification and some configuration parameters, in the form of message attachments.

```bash

deployProject="${bamboo.deploy.project}"
deployRelease="${bamboo.deploy.release}"
deployResults="${bamboo.resultsUrl}"
deployEnvironment="${bamboo.deploy.environment}"
deployAgentId="${bamboo.agentId}"
bambooRoot="your_bamboo_url"

webhook_url="${bamboo.slack_hook}"
channel="#devtools"

text="<$deployResults| $deployProject › #$deployRelease > started deploying to <http://$bambooRoot/agent/viewAgent.action?agentId=$deployAgentId|$deployEnvironment>."
escapedText=$(echo $text | sed 's/"/\"/g' | sed "s/'/\'/g" )
labelColor="warning"
json="{\"channel\": \"$channel\", \"attachments\":[{\"color\":\"$labelColor\" , \"text\": \"$escapedText\"}]}"

curl -s -d "payload=$json" "$webhook_url"
```

The second task does two steps altogether: the transmission ("*scp*") of files generated in the previous build stages and the remote command execution ("*ssh*") to get these running at the target environment.

Whilst Bamboo provides several built-in tasks to be parameterised (such as the [SCP task](https://confluence.atlassian.com/bamboo/using-the-scp-task-in-bamboo-305759795.html) and the [SSH task](https://confluence.atlassian.com/bamboo/using-the-ssh-task-in-bamboo-306348532.html), under "*Deployment*"), these seem to lack some compared to the old "*DIY*". Specifically, Bamboo can use several modes of authentication to fetch code and deploy: that is, "*user and password*" and "*public key*" (protected through password or not).

A Bamboo project can be assigned a subset of such credential methods to work with across its build plans and deployment projects. Whilst this is a direct, clean approach; it may not always work. That is, even if granting specific keys at the targeted deployment server(s), the connection may not be established (*possibly some subtlety that needs to be fixed in my environment, though*). In any case, going this way impedes quickly adding new pairs of keys for different tasks. Assuming you have no rights over the whole set-up of Bamboo, the quickest, easiest way is to use a hack: SSH to the remove server using the [Script task](https://confluence.atlassian.com/bamboo/script-289277046.html) (under "*Builder*") and send the private key directly. The following block of code shows this:

{% capture note-text %}Some variables, such as <code>${bamboo.build.working.directory}</code>, are available to both build and development stages. Be careful though if you want to download something into such current directory during the build phase, then use that same content during the deployment phase: the directory may appear empty. The quickest way to overcome this is to force a specific folder of your choice for both build and deployment tasks.
{% endcapture %}
{% include highlight-warning.html %}

```bash
KEY="-----BEGIN RSA PRIVATE KEY-----
...
-----END RSA PRIVATE KEY-----"

# Obtain code from where build process left it, instead
# of retrieving it from ${bamboo.build.working.directory}
int_dir=/path/to/project/codebase
# Deployment environment access
dep_env=user@deployment.target.env

cd $int_dir
echo "Contents of repository in home dir ($int_dir)"
ls -la $int_dir

KEY_FILE=${bamboo.build.working.directory}/tempKey
touch $KEY_FILE
chmod 600 $KEY_FILE
cat >> $KEY_FILE <<EOF
$KEY
EOF

ssh -i $KEY_FILE -o StrictHostKeyChecking=no -pXXXX $dep_env -tt mkdir -p /path/to/project/
scp -i $KEY_FILE -o StrictHostKeyChecking=no -PXXXX -r /path/to/project/* $dep_env:/path/to/project/

ERROR_SSH=$?
rm $KEY_FILE
if [ $ERROR_SSH -ne 0 ]; then
    exit $ERROR_SSH
fi
```

##### Triggers

The deployment process can be either manual (handed over to the developer or integrator, which will first define a release on the codebase version expected to be built) or either [automatic](https://confluence.atlassian.com/bamboo0514/triggers-for-deployment-environments-868985645.html). In the latter case, Bamboo allows defining triggers *after successful build plan*, *after successful stage* or *scheduled*. The two former mean that the code will be deployed after a given branch or *stage of a plan* is successfully built, whilst the latter provides scheduling (daily, specific days per week/month or cron-like).

### Slack

After a [team and channel(s) are created](https://get.slack.help/hc/en-us/articles/206845317-Create-a-Slack-team) for your project, it is possible to define "*applications*" or "*custom integrations*" (incoming webhooks or tailored applications).

Applications provide pre-defined integrations, using incoming webhooks with well-known tools, such as GitHub, Bitbucket as well as other such as [JIRA server](https://slack.com/apps/A0F7YS3MZ-jira) or [JIRA cloud](https://slack.com/apps/A2RPP3NFR-jira-cloud)).

![alt text][slack_apps]

In case there is no integration available in the *Slack marketplace* for the integration you wish to add, you may use instead the "*custom integrations*" (incoming webhooks) to be used with external clients.

![alt text][slack_custom_int]

It is also possible to [define your own application](https://api.slack.com/apps), tied to a specific team. New features and functionality can be added to add *incoming wwebhooks*, *event subscription*, add *bot* capabilities and so own. Multiple incoming webhooks can be defined.

Incoming webhooks at both custom integrations can be implicitly called, by the tools where you add the webhook URL for integration; or explicitly, by pushing data through a REST call with a JSON payload (see [messages](https://api.slack.com/docs/messages) and [message attachments](https://api.slack.com/docs/message-attachments) to understand the format and options in use). There are multiple Gists as well to provide more up-to-date examples using Bash, Python, etc.

#### Incoming webhooks

Similarly to other hooks (e.g. Git), the Slack [webhooks](https://api.slack.com/incoming-webhooks) act as endpoints that receive external notifications and push these to a specific Slack channel.

{% capture note-text %}Some tools, like Bitbucket, ship with support for Slack. This means that the post of the REST payload defined in the <em>"Bamboo"</em> section is done internally by Bitbucket, and the administrator will just provide the URL of the webhook and configure which events trigger the hooks (code push, pull request, etc).{% endcapture %}
{% include highlight-note.html %}

![alt text][slack_webhook_int]

First, define an [incoming webhook integration](https://my.slack.com/services/new/incoming-webhook/), link it to a team and channel. A name, icon and description can be specified for better recognising its purpose and to clearly identify the event to that of a specific software component, for instance.

[bitbucket_repo_slack]: /img/post/2017-07-15-CI-env-with-Atlassian/bitbucket_slack.png?style=img-center "Bitbucket configuration for Slack"
[bamboo_build_tasks]: /img/post/2017-07-15-CI-env-with-Atlassian/bamboo_build_tasks.png?style=img-center "Bamboo build tasks"
[bamboo_deploy]: /img/post/2017-07-15-CI-env-with-Atlassian/bamboo_deployment_configuration.png?style=img-center "Bamboo deployment plan's configuration"
[bamboo_deploy_tasks]: /img/post/2017-07-15-CI-env-with-Atlassian/bamboo_deployment_tasks.png?style=img-center "Bamboo deployment tasks"
[slack_apps]: /img/post/2017-07-15-CI-env-with-Atlassian/slack_manage_apps.png?style=img-center "Slack applications"
[slack_custom_int]: /img/post/2017-07-15-CI-env-with-Atlassian/slack_manage_custom_integrations.png?style=img-center "Slack custom integrations"
[slack_webhook_int]: /img/post/2017-07-15-CI-env-with-Atlassian/slack_incoming-webhook.png?style=img-center "Define Slack webhook integration"

---
layout: post
title:  "Environment variable substitution in Linux"
description: "Automatically substituting environment variables into configuration files"
date:   2020-05-12 21:12:31
categories: devops
tags: [unix]
comments: true
---

* TOC
{:toc}

Setting up a CI/CD on a stack that is deployed on different enviroments may lead you to use different sets of configurations for each environment. You could track these in separate private repositories or do that in a public one, which is accessible to end users as well, who will be able to 1) set up the same environment as you, without the need of sharing a Docker image, and 2) letting them customize their setup.

This post describes how to implement a basic Bash deployment set of scripts (tested in Ubuntu and CentOS) that allows you to define all your environment variables (i.e., configurations that change across environments, sensitive information, etc) and directly apply these to your templated files; thus allowing you to track and share the templates and keeping the generated configuration files only in your specific environment.

<!--more-->

### Which pieces to use

Just two files, each of them containing a list of "key=value" assignments:
 * A template: a file that defines the structutre of the resulting file. It contains lines with "someVar=$some_var (i.e., values of the assignment are Unix-like variables)
 * An environment variables file: a file that provides a list of values, where these are read from. It contains lines with "some_var=50" (i.e., values of the assignment are real, final values)

Then, a Unix command will allow the substiution of the values of the environment variables into the template.

That's it.

### Testing

#### Structure and pieces

First, the basics.

```bash
cd /tmp
mkdir test_envsubst
cd test_envsubst
mkdir -p env/{development,preproduction,production}
mkdir -p common/cfg

# Create env vars file
cat <<EOF > env/development/env.vars
STACK_USER_ROLE_DEFAULT=guest
STACK_USER_NUMBER_MAX=50
EOF

# Create template file
cat <<"EOF" > common/cfg/users.cfg.tpl
userDefaultRole = ${STACK_USER_ROLE_DEFAULT}
numberOfMaxUsers = ${STACK_USER_NUMBER_MAX}
EOF
```

We will create now a replacement script, which can follow a more simple or complex approach, based on your needs.

#### Simple approach

Use this for casual replacements, like a single environment variable files or with simple values assigned.

```bash
# Create replacing script
cat <<"EOF" > replace.sh
#!/bin/bash

ENV="development"
ENV_VARS_FILE="env/${ENV}/env.vars"
USERS_CFG_FILE="common/cfg/users.cfg"

# Load environment variables, then split & export these to make them available
source ${ENV_VARS_FILE=}
export $(cut -d= -f1 ${ENV_VARS_FILE=})

# Replace every exported variable into the template file and generate a new output file
envsubst < ${USERS_CFG_FILE}.tpl > ${USERS_CFG_FILE}
EOF

# Run script
chmod u+x replace.sh
./replace.sh

# Show difference between the generated configuration file (with variables substitued) and the original template file
diff common/cfg/users.cfg.tpl common/cfg/users.cfg
```

#### Complex approach

This is possibly more useful when having a complex setup with multiple files for environment variables and complex values assigned. Try using this is the simple approach does not suit your needs.

```bash
# Create replacing script
cat <<"EOF" > replace.sh
#!/bin/bash

ENV="development"
ENV_VARS=()
ENV_VARS_NAMES=""
DEPLOY_DIR=$(realpath $(dirname $0))
DEPLOY_ENV_DIR=${DEPLOY_DIR}/env/$ENV

# --- Methods ---

# Load environment-related variables from env/${ENV}/env.vars and export them
function fetch_env_vars() {
    DEPLOY_ENV_VARS=${DEPLOY_ENV_DIR}/env.vars
    [[ ! -f $DEPLOY_ENV_VARS ]] && echo "File with filled env vars ($DEPLOY_ENV_VARS) not found" && exit
    while IFS="=" read -r key value; do
        if ! [[ -z $key ]] && ! [[ -z $value ]] && ! [[ "$key" =~ ^#.*$ ]]; then
            # Remove leading and trailing whitespacess on value
            value="${value#"${value%%[![:space:]]*}"}"
            value="${value%"${value##*[![:space:]]}"}"
            line="${key}=${value}"
            export "$line"
            ENV_VARS+=("$line")
        fi
    done < "$DEPLOY_ENV_VARS"
    # Add specific environment variables (related to paths, for proper replacement in files)
    ENV_VARS+=("DEPLOY_DIR=${DEPLOY_DIR}")
    ENV_VARS+=("DEPLOY_ENV_DIR=${DEPLOY_ENV_DIR}")
}

function fetch_env_vars_names() {
    ENV_VARS_NAMES=""
    for var in "${ENV_VARS[@]}"; do
        var=$(echo $var | sed -r -e "s/\n//g")
        separator="="
        # Key is everything to the left-hand side of the first occurrence of the separator
        key=${var%%"$separator"*}
        # Note: some variables may be like "key= value" and must account for the whitespace
        key=${key%%"$separator" *}
        ENV_VARS_NAMES+='$'${key}' '
    done
    # Remove trailing whitespaces on the generated string
    ENV_VARS_NAMES="${ENV_VARS_NAMES%"${ENV_VARS_NAMES##*[![:space:]]}"}"
}

# Replace environment variables in the provided array of template files
function replace_vars_under_path() {
    template_files=( "$@" )
    for template_file in "${template_files[@]}"; do
        template_file_subst="${template_file%%.tpl}"
        # Fine-grained, only substitutes a specific set of variables: the ones under env/${ENV}/envs.var
        envsubst "${ENV_VARS_NAMES}" < $template_file > $template_file_subst
    done
}

# --- Main ---

# Get environment variables and fetch the specific names for later replacement
fetch_env_vars
fetch_env_vars_names

# Repeat for any other folder
template_files_path=${DEPLOY_DIR}/common/cfg
IFS= readarray -t template_common_cfg_files < <(find ${DEPLOY_DIR}/common/cfg/ "*.tpl" -type f -print)
replace_vars_under_path "${template_common_cfg_files[@]}"
EOF

# Run script
chmod u+x replace.sh
./replace.sh

# Show difference between the generated configuration file (with variables substitued) and the original template file
diff common/cfg/users.cfg.tpl common/cfg/users.cfg
```

### Conclusion

This scripts deals with an easy way to export specific environment variables and replace these in all files under the given path(s).

Naturally, you can include logic for other checks such as enforcing the existence of some required files or validating the formatting, print all replaced environment variables, generating partial configurations from special template files that are included into larger templates, etc.

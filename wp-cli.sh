#!/bin/bash

# filename: wp-cli.sh
# author: @Kipjr

jq_docker="docker run --rm jq"
wp_docker="docker-compose run --no-deps --rm --user=33:33 -e HOME=/tmp"
source ./.env
export version=0
export verbose=0
export rebuilt=0
export force=0
export update=0
export purge=0
export option=0
export getoptions=0
showHelp() {
# `cat << EOF` This means that cat should stop reading when EOF is detected
cat << EOF
Usage: ./wp-cli.sh -[iPU] [-VF] 
Install Wordpress and configure for Docker

Exclusive commands: purge, init, update, help, {other}
Optional commands: force, verbose

-h,        --help               Display help

-F,        --force              Remove compiled files

-V,        --verbose            Run script in verbose mode. Will print out each step of execution.

-P,        --purge              Purge all data (needs confirm)

-i,        --init               Rebuild container and files based on .env

-U,        --update             Update core db and plugins

-O         --option            Updates options from .env

-G         --getoptions        retrieves options from WP

If none given, "$@" is executed


EOF
# EOF is found above and hence cat command stops reading. This is equivalent to echo but much neater when printing out.
}
addDNSentry() {
    #body='{
    #    "login": "test-user",
    #    "nonce": "98475920834",
    #    "read_only": false,
    #    "expiration_time": "30 minutes",
    #    "label": "add description",
    #    "global_key": true
    #}'
    #WP_URLDOMAIN=${WP_URL} 
    #signature=openssl dgst -sha512 -sign  $body
    #auth=$(curl -X POST -H "Content-Type: application/json" -H $signature -d $body "ttps://api.transip.nl/v6/auth")
    #dnsreq=$(curl -X POST -H "Content-Type: application/json" -H "Authorization: Bearer [your JSON web token]" -d '{  "dnsEntry": {    "name": "www",    "expire": 86400,    "type": "A",    "content": "127.0.0.1"  }} ' "https://api.transip.nl/v6/domains/${WP_URLDOMAIN}/dns")
    echo 1
}


addVirtualHost() {
    if [ -d '/etc/apache2/sites-available' ]; then
        getCert ${WP_URL}
        cp ./server.virtualhost.conf "${WP_URL}.conf"
        replaceVarFile "${WP_URL}.conf" WP_URL "${WP_URL}"
        replaceVarFile "${WP_URL}.conf" WP_URL "${WP_URL}"
        cp ${WP_URL}.conf /etc/apache2/sites-enabled/${WP_URL}.conf
    else
        echo "apache not installed"  
    fi
}

replaceVarFile() {
    file=$1
    find=$2
    replace=$3
    sed -i "s/${find}/${replace}/g" $file
}

getCert() {
    if [ -d '/etc/letsencrypt' ]; then
        domain=$1
        certbot certonly -d $domain
    else
        echo "certbot not installed"
    fi
}

initWP() {
    #docker ps -q -f name={container Name}
    [  $(docker-compose ps -a | grep ${WP_DB_NAME} | wc -l ) -eq 0 ]  && docker-compose up --no-start ${WP_DB_NAME} ${WP_NAME} && docker-compose start  ${WP_DB_NAME} ${WP_NAME}
    [[ ${WP_HTTPS} == 1 ]] && WP_PROT="https" || WP_PROT="http"
    sleep 15
    eval $wp_docker ${WP_CLI_NAME} wp cli update --yes 
    eval $wp_docker ${WP_CLI_NAME} wp core install --url="${WP_PROT}://${WP_URL}" --title=${WP_TITLE} --admin_user=${WP_ADMIN} --admin_password=${WP_ADMIN_PASSWORD} --admin_email=${WP_ADMIN_EMAIL}
    pluginsWP
    sleep 15
    optionsWP
    eval $wp_docker ${WP_CLI_NAME} user create ${WP_USER} ${WP_USER_EMAIL} --role=administrator --user_pass=${WP_USER_PASSWORD}
}

pluginsWP() {
    eval $wp_docker ${WP_CLI_NAME} wp plugin install --activate ${WP_PLUGINS}
    eval $wp_docker ${WP_CLI_NAME} wp plugin auto-updates enable --all #awaiting update to implement this function
}

optionsWP() {

    #keyvalue
    for item in "${!WPO_@}"
    do
        key=$( echo ${item} | cut -c5- )
        value=$( echo ${!item} | cut -d ',' -f1 )
        eval $wp_docker ${WP_CLI_NAME} wp option update ${key} ${value}
    done


    #eval $jq_docker "$@"

    #objects WPOP_key="item keypath value"
    for item in "${!WPOP_@}"
    do
        key=$( echo ${item} | cut -c6- )
        path=$( echo ${!item} | cut -d ';' -f1 )
        value=$( echo ${!item} | cut -d ';' -f2 )
        eval $wp_docker ${WP_CLI_NAME} wp option patch update ${path} ${key} '${value}' --format=json
    done

}

getWPoptions() {
    eval $wp_docker ${WP_CLI_NAME} wp option list --format=json --unserialize > wp_options.json
    eval $wp_docker ${WP_CLI_NAME} wp option list --format=yaml --unserialize > wp_options.yaml
}



cleanWP() {
        docker-compose rm --force --stop -v
        docker volume prune --force  --filter label=com.docker.compose.project=$(basename "$PWD")
        rm ./"${WP_URL}.conf"
        rm ./.WP_INITIALIZED
        rm ./docker-compose.yml
        rm /etc/apache2/sites
        rm /etc/apache2/sites-enabled/${WP_URL}.conf
}
purge() {
    read -p "Are you sure (Y/n)" q
    if [[ $q == "Y" ]]; then
        cleanWP
        echo "You need to manually remove DNS entry"
        read -p "Delete folder (Y/n)" f
        if [[ $f == "Y" ]]; then
            rm ../$(basename "$PWD")
        fi
    else 
        echo "Action aborted"
        exit 0
    fi
}
createJQimage(){
    cat <<EOF > /tmp/Dockerfile
FROM alpine
RUN apk add --update --no-cache jq
CMD ["sh"]
EOF
    docker build /tmp --tag jq
}



update() {
    docker pull wordpress:cli-php8.0
    eval $wp_docker ${WP_CLI_NAME} wp core check-update
    eval $wp_docker ${WP_CLI_NAME} wp core update
    eval $wp_docker ${WP_CLI_NAME} wp core update-db
    eval $wp_docker ${WP_CLI_NAME} wp plugin update --all
}

main() {
    if [[ -f './.WP_INITIALIZED' && $force == 0 ]]; then
        echo "already initialised"
        exit 0
    elif [ $force == 1 ]; then
        cleanWP
        export force=0
        main
    elif [[ ! -f './.WP_INITIALIZED'  ]]; then
        #addDNSEntry
        addVirtualHost
        cp ./docker-compose.template docker-compose.yml
        replaceVarFile "./docker-compose.yml" '${WP_NAME}' ${WP_NAME}
        replaceVarFile "./docker-compose.yml" '${WP_DB_NAME}' ${WP_DB_NAME}
        replaceVarFile "./docker-compose.yml" '${WP_CLI_NAME}' ${WP_CLI_NAME}
        replaceVarFile "./docker-compose.yml" '${WP_SUBNET}' ${WP_SUBNET}
        initWP
        touch ./.WP_INITIALIZED
    else
        echo "" 
    fi
}
#####
#####  Execution of commands
#####
#
#
# $@ is all command line parameters passed to the script.
# -o is for short options like -v
# -l is for long options with double dash like --version
# the comma separates different long options
# -a is for long options with single dash like -version
options=$(getopt -l "help,force,verbose,init,purge,update,option,getoptions" -o "hViFPUOG"  -- "$@")

# set --:
# If no arguments follow this option, then the positional parameters are unset. Otherwise, the positional parameters
# are set to the arguments, even if some of them begin with a ‘-’.
eval set -- "$options"

while true
do
case $1 in
-h|--help)
    showHelp
    exit 0
    ;;
-V|--verbose)
    export verbose=1
    set -xv  # Set xtrace and verbose mode.
    ;;
-F|--force)
    export force=1
    ;;
-i|--init)
    export init=1
    ;;
-P|--purge)
    export purge=1
    ;;
-U|--update)
    export update=1
    ;;
-O|--option)
    export option=1
    ;;
-G|--getoptions)
    export getoptions=1
    ;;

--)
    shift
    break
    ;;
esac
shift
done

commands=$(($init+$purge+$update+$option+$getoptions)) #exclusive commands

if [[ $commands == 1 ]]; then
    if [[ $init == 1 ]]; then
        main
    elif [[ $purge == 1 ]]; then
        purge
    elif [[ $update == 1 ]]; then
        update
    elif [[ $option == 1 ]]; then
        optionsWP
    elif [[ $getoptions == 1 ]]; then
        getWPoptions
    fi
elif [[ $commands == 0 ]]; then
    [[ $(eval $wp_docker ${WP_CLI_NAME} wp core is-installed)=="" ]] && error=0 || error=1
    if [[ $error  == 0 ]]; then
        [[ -z "$@" ]] && com="wp cli info" || com="$@"
        eval ${wp_docker} ${WP_CLI_NAME} ${com};
    else 
        echo "Unable to execute, WP not installed" 
    fi
else
    echo "Too many commands given"
fi

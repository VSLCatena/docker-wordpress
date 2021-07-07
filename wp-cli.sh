#!/bin/bash

# filename: wp-cli.sh
# author: @Kipjr


wp_docker="docker-compose run --no-deps --rm --user=33:33 -e HOME=/tmp"
source ./.env
export version=0
export verbose=0
export rebuilt=0
export force=0


showHelp() {
# `cat << EOF` This means that cat should stop reading when EOF is detected
cat << EOF
Usage: ./wp-cli.sh [-V] -i [-F]
Install Wordpress and configure for Docker

-h,        --help               Display help

-i,        --init               Rebuild container and files

-F,        --force              Remove compiled files

-V,        --verbose            Run script in verbose mode. Will print out each step of execution.

EOF
# EOF is found above and hence cat command stops reading. This is equivalent to echo but much neater when printing out.
}


addVirtualHost() {
    if [ -d '/etc/apache2/sites-available' ]; then
        getCert ${WP_URL}
        cp ./server.virtualhost.conf "${WP_URL}.conf"
        replaceVarFile "${WP_URL}.conf" WP_URL "${WP_URL}"
        replaceVarFile "${WP_URL}.conf" WP_URL "${WP_URL}"
        cp ${WP_URL}.conf /etc/apache2/sites-enabled/${WP_URL}
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
        eval $wp_docker ${WP_CLI_NAME} wp core install --url="${WP_PROT}://${WP_URL}" --title=${WP_TITLE} --admin_user=${WP_ADMIN} --admin_password=${WP_ADMIN_PASSWORD} --admin_email=${WP_ADMIN_EMAIL}
        pluginsWP
        sleep 15
        #optionsWP
     #  $wp_docker user create $username $mail --role=administrator
}

pluginsWP() {
    eval $wp_docker ${WP_CLI_NAME} wp plugin install --activate ${WP_PLUGINS}
    eval $wp_docker ${WP_CLI_NAME} wp plugin auto-updates enable --all #awaiting update to implement this function
}

optionsWP() {
    for item in "${!WPO_@}"
    do
        item=${item}
        keypath=$( echo ${!item} | cut -d ',' -f1 )
        value=$( echo ${!item} | cut -d ',' -f2 )
        eval $wp_docker ${WP_CLI_NAME} wp option patch ${item} ${keypath}  ${value} --format=plaintext
        echo"${!item}"
    done
}

main() {
    if [[ -f './.WP_INITIALIZED' && $force == 0 ]]; then
        echo "already initialised"
        exit 0
    elif [ $force == 1 ]; then
        docker-compose rm --force --stop -v
        docker volume prune --force  --filter label=com.docker.compose.project=$(basename "$PWD")
        rm ./"${WP_URL}.conf"
        rm ./.WP_INITIALIZED
        rm ./docker-compose.yml
        export force=0
        main
    elif [[ ! -f './.WP_INITIALIZED'  ]]; then
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



# $@ is all command line parameters passed to the script.
# -o is for short options like -v
# -l is for long options with double dash like --version
# the comma separates different long options
# -a is for long options with single dash like -version
options=$(getopt -l "help,force,verbose,init" -o "hViF"  -- "$@")

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
-i|--init)
    export init=1
    ;;
-F|--force)
    export force=1
    ;;

--)
    shift
    break
    ;;
esac
shift
done



if [[ $init == 1 ]]; then
    main
else
    eval ${wp_docker} ${WP_CLI_NAME} "$@"
fi

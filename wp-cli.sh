#!/bin/bash
set +x 
# filename: wp-cli.sh
# author: @Kipjr

[[ $(dpkg -l | grep -w jq | wc -l) == 0 ]] &&  apt install -y jq #install jq cuz important
jq -r '.env|keys[] as $k | "\($k)=\"\(.[$k])\""'  env.json > .env #parse env.json to .env
source .env #import .env
wp_docker="docker-compose run --no-deps --rm --user=33:33 -e HOME=/tmp"

export version=0
export verbose=0
export rebuilt=0
export force=0
export create=0
export update=0
export purge=0
export option=0
export getoptions=0


showHelp() {
# `cat << EOF` This means that cat should stop reading when EOF is detected
cat << EOF
Usage: ./wp-cli.sh -[iPcOUGU] [-VF] 
Install Wordpress and configure for Docker

Exclusive commands: purge, init, create, update, help, {other}
Optional commands: force, verbose

-h,        --help               Display help

-F,        --force              Remove compiled files

-V,        --verbose            Run script in verbose mode. Will print out each step of execution.

-P,        --purge              Purge all data (needs confirm)

-i,        --init               Rebuild container and files based on .env

-c,        --create             Rebuild files based on .env

-U,        --update             Update core db and plugins

-O         --option            Updates options from .env

-G         --getoptions        retrieves options from WP

If none given, "$@" is executed


EOF
# EOF is found above and hence cat command stops reading. This is equivalent to echo but much neater when printing out.
}


writeLog() {
 #usage:  ls -lat asdf 1> /tmp/stdout.log 2> /tmp/stderr.log; cat /tmp/stdout.log | writeLog INFO; cat /tmp/stderr.log | writeLog ERR
 #usage2:  ls -lat asdf | writeLog Info

    IFS=$''    
    TODAY=$(date +"%Y%m%d")
    TS=$(date +"%Y-%m-%d %H:%M:%S:%N")
    NC='\033[0m'         #no color
    LEVEL=${1:-INFO} #TRACE,DEBUG,INFO,WARN,ERROR,CRITICAL AND NONE
    case $LEVEL in
        CRIT)
            COLOR='\033[1;35m' #LPURPLE #CRIT
        ;;
        ERR)
            COLOR='\033[0;31m' #RED #ERR
        ;;
        WARN)
            COLOR='\033[1;33m' #YELLOW #WARN
        ;;
        INFO)
            COLOR='\033[1;37m' #WHITE #INFO
        ;;
        DEBUG)
            COLOR='\033[0;36m' #CYAN #DEBUG
        ;;
        TRACE)
            COLOR='\033[0;32m' #GREEN #TRACE
        ;;        
        *)
            COLOR=$NC
        ;;
    esac
    
    #precreate logfile if needed
    if [[ ${WP_LOG} == "1"  ]];then
        [[ ! -d "./logs/" ]] && mkdir -p ./logs/
        [[ ! -f "./logs/${TODAY}.log" ]] && touch "./logs/${TODAY}.log"
    fi
    
    #parse lines and write to file if needed
    while read -ers  inputLine; do
        lines=("${lines[@]}" "$inputLine") 
    done
    if [[ ${#lines[@]} -gt 0 && $( echo ${lines[@]} | wc -m) -gt 1  ]]; then
        for i in "${lines[@]}"; do
            [[ ${WP_LOG} == "1"  ]] && printf "%s ${RED}[%s]${NC} %s\n" ${TS} "${LEVEL}" "$i" >> "./logs/${TODAY}.log" 
            printf "%s ${COLOR}[%s]${NC} %s\n" ${TS} "${LEVEL}" "$i" 
        done
    fi
    COLOR=$NC
    IFS=$' \t\n'
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
        echo "apache not installed" | writeLog ERR
    fi
}

replaceVarFile() {
    file=$1
    find=$2
    replace=$3
    sed -i "s/${find}/${replace}/g" $file
    echo "${find} → ${replace} in ${file}" | writeLog TRACE
}

getCert() {
    if [ -d '/etc/letsencrypt' ]; then
        domain=$1
        certbot certonly -d $domain  1> /tmp/stdout.log 2> /tmp/stderr.log; cat /tmp/stdout.log | writeLog INFO; cat /tmp/stderr.log | writeLog ERR
    else
        echo "certbot not installed" | writeLog WARN
    fi
}

initWP() {
    #docker ps -q -f name={container Name}
    if [[  $(docker-compose ps -a | grep ${WP_DB_NAME} | wc -l ) -eq 0 ]]; then
        docker-compose up --no-start ${WP_DB_NAME} ${WP_NAME}  1> /tmp/stdout.log 2> /tmp/stderr.log; cat /tmp/stdout.log | writeLog INFO; cat /tmp/stderr.log | writeLog ERR
        docker-compose start  ${WP_DB_NAME} ${WP_NAME}   1> /tmp/stdout.log 2> /tmp/stderr.log; cat /tmp/stdout.log | writeLog INFO; cat /tmp/stderr.log | writeLog ERR
    fi
    [[ ${WP_HTTPS} == 1 ]] && WP_PROT="https" || WP_PROT="http"
    sleep 15
    docker pull wordpress:cli-php8.0  1> /tmp/stdout.log 2> /tmp/stderr.log; cat /tmp/stdout.log | writeLog INFO; cat /tmp/stderr.log | writeLog ERR
    eval $wp_docker ${WP_CLI_NAME} wp core install --url="${WP_PROT}://${WP_URL}" --title=${WP_TITLE} --admin_user=${WP_ADMIN} --admin_password=${WP_ADMIN_PASSWORD} --admin_email=${WP_ADMIN_EMAIL} 1> /tmp/stdout.log 2> /tmp/stderr.log; cat /tmp/stdout.log | writeLog INFO; cat /tmp/stderr.log | writeLog ERR
    pluginsWP
    sleep 15
    optionsWP
    eval $wp_docker ${WP_CLI_NAME} wp user create ${WP_USER} ${WP_USER_EMAIL} --role=administrator --user_pass=${WP_USER_PASSWORD} 1> /tmp/stdout.log 2> /tmp/stderr.log; cat /tmp/stdout.log | writeLog INFO; cat /tmp/stderr.log | writeLog ERR
}

pluginsWP() {
    eval $wp_docker ${WP_CLI_NAME} wp plugin install --activate ${WP_PLUGINS} 1> /tmp/stdout.log 2> /tmp/stderr.log; cat /tmp/stdout.log | writeLog INFO; cat /tmp/stderr.log | writeLog ERR
    eval $wp_docker ${WP_CLI_NAME} wp plugin auto-updates enable --all 1> /tmp/stdout.log 2> /tmp/stderr.log; cat /tmp/stdout.log | writeLog INFO; cat /tmp/stderr.log | writeLog ERR #awaiting update to implement this function
}

optionsWP() {
    keylen=$(jq -r '.wp_options| length' env.json)
    #keyvalue
    for ((i=0;i<$keylen;i++)); 
    do
        #jq -r --argjson i $i '.wp_options[$i] | {(.option_name):.option_value}' ./env.json >/tmp/var.json #write option to disk
        jq  --compact-output --argjson i $i '.wp_options[$i] | .option_value' ./env.json >/tmp/var.json #write option to disk
        #sed -i 's/"//g' /tmp/var.json
        key=$(jq -r --argjson i $i '.wp_options[$i] |  {(.option_name):.option_value}|to_entries|.[].key' ./env.json) #get option key
        eval $wp_docker ${WP_CLI_NAME} wp option update --format=json --autoload=yes $key < /tmp/var.json  1> /tmp/stdout.log 2> /tmp/stderr.log; cat /tmp/stdout.log | writeLog INFO; cat /tmp/stderr.log | writeLog ERR
    done

 # jq -r '.wp_options as $in | .wp_options| reduce paths(scalars) as $path ({}; . + { ( [$in[$path[0]].option_name]+$path[2:]  | map(tostring) | join(" ")): $in| getpath($path) } as $data | $data | map_values(select( $in[$path[0]].option_name != ($in|getpath($path)))))' env.json
 # "wp_mail_smtp smtp host": "smtp-relay.gmail.com",
 #jq -r '.wp_options[] as $arr|{($arr.option_name):$arr.option_value}' env.json
 #[
 #{
 #   itsec-storage:
 #       {values}
 #}]
}

getWPoptions() {
    eval $wp_docker ${WP_CLI_NAME} wp option list --format=json --unserialize > wp_options.json 1> /tmp/stdout.log 2> /tmp/stderr.log; cat /tmp/stdout.log | writeLog INFO; cat /tmp/stderr.log | writeLog ERR
    eval $wp_docker ${WP_CLI_NAME} wp option list --format=yaml --unserialize > wp_options.yaml 1> /tmp/stdout.log 2> /tmp/stderr.log; cat /tmp/stdout.log | writeLog INFO; cat /tmp/stderr.log | writeLog ERR
    echo  "Exported to wp_options.json/yaml" | writeLog "INFO"
}



cleanWP() {
        docker-compose rm --force --stop -v  1> /tmp/stdout.log 2> /tmp/stderr.log; cat /tmp/stdout.log | writeLog INFO; cat /tmp/stderr.log | writeLog ERR
        docker volume prune --force  --filter label=com.docker.compose.project=$(basename "$PWD")  1> /tmp/stdout.log 2> /tmp/stderr.log; cat /tmp/stdout.log | writeLog INFO; cat /tmp/stderr.log | writeLog ERR
        [[ -f "./${WP_URL}.conf" ]] &&  rm ./"${WP_URL}.conf"
        [[ -f "./.WP_INITIALIZED" ]] && rm  "./.WP_INITIALIZED"
        [[ -f "./docker-compose.yml" ]] && rm "./docker-compose.yml"
        [[ -f "/etc/apache2/sites-enabled/${WP_URL}.conf" ]] && rm  "/etc/apache2/sites-enabled/${WP_URL}.conf"
}
purge() {
    read -p "Are you sure (Y/n)" q
    if [[ $q == "Y" ]]; then
        cleanWP
        echo "You need to manually remove DNS entry"  | writeLog "INFO"
        read -p "Delete folder (Y/n)" f
        if [[ $f == "Y" ]]; then
            rm ../$(basename "$PWD")
        fi
    else 
        echo "Action aborted"  | writeLog "INFO"
        exit 0
    fi
}




update() {
    echo "Updating wp-cli" | writeLog "INFO"
    docker pull wordpress:cli-php8.0 
    echo "Checking for wp updates"  | writeLog "INFO"
    eval $wp_docker ${WP_CLI_NAME} wp core check-update 1> /tmp/stdout.log 2> /tmp/stderr.log; cat /tmp/stdout.log | writeLog INFO; cat /tmp/stderr.log | writeLog ERR
    echo "Updating wp core"  | writeLog "INFO"
    eval $wp_docker ${WP_CLI_NAME} wp core update 1> /tmp/stdout.log 2> /tmp/stderr.log; cat /tmp/stdout.log | writeLog INFO; cat /tmp/stderr.log | writeLog ERR
    echo "Updating wp db" | writeLog "INFO"
    eval $wp_docker ${WP_CLI_NAME} wp core update-db 1> /tmp/stdout.log 2> /tmp/stderr.log; cat /tmp/stdout.log | writeLog INFO; cat /tmp/stderr.log | writeLog ERR
    echo "Updating wp plugins"  | writeLog "INFO"
    eval $wp_docker ${WP_CLI_NAME} wp plugin update --all  1> /tmp/stdout.log 2> /tmp/stderr.log; cat /tmp/stdout.log | writeLog INFO; cat /tmp/stderr.log | writeLog ERR
}
createFiles() {
    addVirtualHost
    cp ./docker-compose.template docker-compose.yml
    replaceVarFile "./docker-compose.yml" '${WP_NAME}' ${WP_NAME}
    replaceVarFile "./docker-compose.yml" '${WP_DB_NAME}' ${WP_DB_NAME}
    replaceVarFile "./docker-compose.yml" '${WP_CLI_NAME}' ${WP_CLI_NAME}
}


main() {
    if [[ -f './.WP_INITIALIZED' && $force == 0 ]]; then
        echo  "already initialised" | writeLog "INFO"
        exit 0
    elif [ $force == 1 ]; then
        cleanWP
        export force=0
        main
    elif [[ ! -f './.WP_INITIALIZED'  ]]; then
        #addDNSEntry
        createFiles
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
options=$(getopt -l "help,force,verbose,init,create,purge,update,option,getoptions" -o "hViFPUOGc"  -- "$@")
echo "wp-cli.sh ${options}" | writeLog "DEBUG"
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
-c|--create)
    export create=1
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

commands=$(($init+$create+$purge+$update+$option+$getoptions)) #exclusive commands

if [[ $commands == 1 ]]; then
    if [[ $init == 1 ]]; then
        main
    elif [[ $purge == 1 ]]; then
        purge
    elif [[ $update == 1 ]]; then
        update
    elif [[ $option == 1 ]]; then
        optionsWP
    elif [[ $create == 1 ]]; then
        createFiles
    elif [[ $getoptions == 1 ]]; then
        getWPoptions
    fi
elif [[ $commands == 0 ]]; then
    [[ $(eval $wp_docker ${WP_CLI_NAME} wp core is-installed)=="" ]] && error=0 || error=1
    if [[ $error  == 0 ]]; then
        [[ -z "$@" ]] && com="wp cli info" || com="$@"
        eval ${wp_docker} ${WP_CLI_NAME} ${com};
    else 
        echo "Unable to execute, WP not installed" | writeLog "ERR"
    fi
else
    echo  "Too many commands given"| writeLog "ERR"
fi

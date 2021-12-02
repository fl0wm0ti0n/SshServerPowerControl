#!/bin/bash

###########################################################
# Usecase: Script to control the power of servers via SSH #
# Description: IBM's IMM2, DELL's IDRAC6 and HP's ILO3    #
# ManagementController are tested. However a default os   #
# which alows over SSH to control the power would work,   #
# for example Debian. remember that os allows only off    #
# and restart                                             #
# A serverlist.json is required.                          #
# If you have entered an os ssh and a management ssh the  #
# script takes the os ssh for shutdown and restart        #
#                                                         #
# Author: Florian Gabriel (https://github.com/fl0wm0ti0n) #
# Date: 2021-11-27                                        #                                              
###########################################################

###########################################################
### pre-requirements:
# linux bash:   
# sudo apt-get install jq

# Windows bash:
# chocolatey install jq
# install: cygwin (mit chere, gcc, make, sshpass, jq) und cmder
# https://github-wiki-see.page/m/cmderdev/cmder/wiki/Integrating-Cygwin#Add-Cygwin-to-Path
###########################################################

###########################################################
### global declarations
#"X:\Server-Daten\Server u. Netzwerk\Allgemein\Serverliste.json"
# use the serverlist_template.json to ccreate your own serverlist
jsonlist="serverlist.json" # path to serverlist as json
task=""
cat=""
serverlist=()

###########################################################
### Help text
function WriteHelpText() {
    echo "syntax: script.sh -task<poweron|poweroff|restart> [-category<farm|vm-host|vm-guest|all>] [<hostname1> <hostname2>]"
    echo "example to start all server with category farm: script.sh -taskpoweron -categoryfarm"
    echo "example to poweroff all listed servers: script.sh -taskpoweroff ibmserver01 dellserver02"
    exit
}
###########################################################

###########################################################
### loop thru args
function EntryPoint() {
i=0
for ARG in $@
do
    if [[ $ARG == *"--help"* ]]; then
        WriteHelpText
    fi
    if [[ $ARG == *"-task"* ]]; then
        task=$ARG
        task=`echo $task | cut -c 6-`
        if [[ $task == "poweroff" ]] || [[ $task == "poweron" ]] || [[ $task == "restart" ]]; then
            echo "choosen task is: $task"
        fi
        continue
    fi
    if [[ $ARG == *"-category"* ]]; then
        cat=$ARG
        cat=`echo $cat | cut -c 10-`
        echo "choosen server category is: $cat"
        continue
    else
        if [[ $ARG != *"-task"* ]] && [[ $ARG != *"--help"* ]]; then
            serverlist+=( "$ARG" )
            echo "server is: $ARG"
            i=$(($i+1))
            continue
        else
            WriteHelpText
        fi
    fi
done

# if zero arguments, write helptext
#if [ -z "$@" ]; then
#    WriteHelpText
#fi
}
###########################################################

###########################################################
### Send SSH command in seperate Shells
function SendSshCommand() {

    sshon=$1
    ip=$2
    port=$3
    sshoption=$4
    user=$5
    pw=$6
    oncommand=$7
    offcommand=$8
    restartcommand=$9
    healthcommand=${10}
    task=${11}
    hostname=${12}

    echo "succeed entering SSH Handler"
    if [[ $task == "poweroff" ]]; then
        echo "send poweroff command to $hostname with IP $ip"
        (sshpass -p $pw ssh -p $port -o$sshoption $user@$ip "$offcommand")
        #echo $temp
    fi
    if [[ $task == "poweron" ]]; then
        echo "send poweron command to $hostname with IP $ip"
       (sshpass -p $pw ssh -p $port -o$sshoption $user@$ip "$oncommand")
        #echo $temp
    fi
    if [[ $task == "restart" ]]; then
        echo "send restart command to $hostname with IP $ip"
        (sshpass -p $pw ssh -p $port -o$sshoption $user@$ip "$restartcommand")
        #echo $temp
    fi
}

###########################################################

###########################################################
### iterate thru servers and do task on it
function DoJobForServers() {
    goodser=()
    errorser=()
    errorcat=0
    x=0
    y=0
    while read -r id
    do      
        read -r hostname
        read -r category
        read -r sshon
        read -r ip
        read -r port
        read -r sshoption
        read -r user
        read -r pw
        read -r oncommand
        read -r offcommand
        read -r restartcommand
        read -r healthcommand
        read -r ossshon
        read -r osip
        read -r osport
        read -r ossshoption
        read -r osuser
        read -r ospw
        read -r osoffcommand
        read -r osrestartcommand
        if [[ "$cat" != "" ]]; then
            category=`echo $category | tr -d '\r'`
            if [[ "$category" == "$cat" ]]; then
                errorcat=0
                if [ $ossshon = true ] && ([[ $task = "poweroff" ]] || [[ $task == "restart" ]]); then
                    echo "OS SSH parameters are set, run command for harmless $task"
                    SendSshCommand $ossshon $osip $osport $ossshoption $osuser $ospw "" "$osoffcommand" "$osrestartcommand" "" $task $hostname
                else
                    echo "Run SSH command"
                    SendSshCommand $sshon $ip $port $sshoption $user $pw "$oncommand" "$offcommand" "$restartcommand" "$healthcommand" $task $hostname
                fi
            else
                errorcat=1
            fi
        else
            for server in ${serverlist[@]}
            do
                hostname=`echo $hostname | tr -d '\r'`
                if [[ "$hostname" == "$server" ]]; then
                    goodser[$x]=$server
                    x=$(($x+1))
                    if [ $ossshon = true ] && ([[ $task = "poweroff" ]] || [[ $task == "restart" ]]); then
                        echo "OS SSH parameters are set, run command for harmless $task"
                        SendSshCommand $ossshon $osip $osport $ossshoption $osuser $ospw "" "$osoffcommand" "$osrestartcommand" "" $task $hostname
                    else
                        echo "Run SSH command"
                        SendSshCommand $sshon $ip $port $sshoption $user $pw "$oncommand" "$offcommand" "$restartcommand" "$healthcommand" $task $hostname
                    fi
                else
                    errorser[$y]=$server
                    y=$(($y+1))
                fi
            done
        fi

    done < <(jq -r '.[] | .id, .serverinfos.hostname, .serverinfos.category, 
    ( .ssh | .sshon, .ip, .port, .sshoption, .user, .pw, .oncommand, .offcommand, .restartcommand, .healthcommand), 
    ( .os.osssh | .sshon, .ip, .port, .sshoption, .user, .pw, .offcommand, .restartcommand)' $jsonlist)

    ### ErrorHandler
    y=0
    if (( ${#errorser[@]} )); then
        for error in ${errorser[@]}
        do 
            for good in ${goodser[@]}
            do
                if [[ $error == $good ]]; then
                errorser[$y]=""
                fi
            done
            y=$(($y+1))
        done
    fi
    for error in ${errorser[@]}
    do
        if [[ $error != "" ]]; then
            echo "ERROR: the server $error in the argumentlist wasn't found in the jsonfile."
        fi
    done
    if [ $errorcat -eq 1 ]; then
        echo "ERROR: the category $cat in the argumentlist wasn't found in the jsonfile."
    fi
}
###########################################################

###########################################################
### here starts the programm
EntryPoint $@
DoJobForServers 
###########################################################
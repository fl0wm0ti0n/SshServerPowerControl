# SshServerPowerControl
Start, stop and restart servers which are listed in a json-file via ssh.

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
# use the serverlist_template.json to create your own serverlist
jsonlist="serverlist.json" # path to serverlist as json

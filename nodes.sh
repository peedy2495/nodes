#!/bin/bash

# NODES - Control Tool
#
# Start/Restart/Shutdown your environment or
# Excute commands in your infrastructure.

ver=0.1
deps=(ether-wake salt)

ARGS=$@

# Main-Function
# main() returns messages and exit-codes
main() {

    check_root
    check_deps
    read_config

    verbose=0
    all=0
    exe=0

    PARAMS=""
    while (( "$#" )); do
      case "$1" in
        -h|--help)
          usage
          ;;
        --version)
          echo $ver
          exit 0
          ;;
        -v|--verbose)
          verbose=1
          shift
          ;;
        -a|--all)
          all=1
          shift
          ;;
        start|boot)
          start_nodes
            shift
          ;;
        stop|shutdown)
          stop_nodes
            shift
          ;;
        reboot)
          reboot_nodes
            shift
          ;;
        execute)
          exe=1
          shift
          ;;
        -*|--*=) # unsupported flags
          if [ $exe -eq 1 ]; then
            cmdline="$cmdline $1"
            shift
          else
            echo "Error: Unsupported Option $1" >&2
            usage
          fi
          ;;
        *) # preserve positional arguments
          if [ $exe -eq 1 ]; then
            cmdline="$cmdline $1"
            shift
          else
            echo "Error: Unsupported Function $1" >&2
            usage
          fi
          ;;
    esac
  done

  if [ $exe -eq 1 ]; then
    execute "$cmdline"
  fi
}

# Check if current user is root
# check_root() returns exit on fail
check_root(){
  if [ "$EUID" -ne 0 ]
    then echo "Need root permissions to perfom actions ... please login as root."
    exit
  fi

}

# Check reqired dependencies to be able to perform all actions
# check_deps() returns exit on fail
check_deps(){
  deps=(\
    /usr/sbin/ether-wake \
    /usr/bin/salt \
    )
  for dep in ${deps[@]}; do
    if ! [[ -f $dep ]]; then
      echo "missing dependency: $dep. Please install it first."
      exit 1
    fi
  done
}

# Start/Boot configured Nodes
# start_nodes() returns nothing
start_nodes() {
    echo "starting nodes ..."
    for n in "${!node[@]}"; do
        ether-wake -i $ifout ${node[$n]}
        if [ $verbose -eq 1 ]; then
            echo "calling $n @ ${node[$n]}"
        fi
    done
}

# Stop/Shutdown configured Nodes
# stop_nodes() returns nothing
stop_nodes() {
    known=()
    echo "stopping nodes ..."
    for n in "${!node[@]}"; do
        host=${n%.*}
        if ! [[ ${known[*]} =~ (^|[[:space:]])"$host"($|[[:space:]]) ]]; then
            salt $host system.shutdown
            if [ $verbose -eq 1 ]; then
                echo "shutting down $host"
            fi
            known+=("${host}")
        fi
    done
    if [ $all -eq 1 ]; then
        shutdown -h now &
    fi
}

# Reboot configured Nodes
# reboot_nodes() returns nothing
reboot_nodes() {
    known=()
    echo "rebooting nodes ..."
    for n in "${!node[@]}"; do
        host=${n%.*}
        if ! [[ ${known[*]} =~ (^|[[:space:]])"$host"($|[[:space:]]) ]]; then
            salt $host system.reboot
            if [ $verbose -eq 1 ]; then
                echo "rebooting $host"
            fi
            known+=("${host}")
        fi
    done
    if [ $all -eq 1 ]; then
        echo "rebooting $HOSTNAME"
        sleep 2
        reboot &
    fi
}

# Execute commands on nodes
# execute() "<command>" returns command outputs
execute() {
  known=()
  cmd="$@"
    echo -e "executing ${br_blue}$cmd${rst} on nodes ..."
    for n in "${!node[@]}"; do
        host=${n%.*}
        if ! [[ ${known[*]} =~ (^|[[:space:]])"$host"($|[[:space:]]) ]]; then
            salt "$host" cmd.run "$cmd"
            known+=("${host}")
        fi
    done
    if [ $all -eq 1 ]; then
        echo -ne "${cyan}$HOSTNAME(local):${green}\n    "
        eval $cmd
        echo -ne ${rst}
    fi
  exit
}

# Print Usage Text
# usage() returns exit-code 1
usage() {
    echo "Usage: cluster [options] <function>

Cluster allows for controlling start/stopping/rebooting a swath of remote systems in
a cluster, so they can be controlled with ease.

Options:
  --version             show program's version number and exit
  -V, --versions-report
                        Show program's dependencies version number and exit.
  -h, --help            show this help message and exit
  -v, --verbose         print detailed informations during processing
  -a, --all             called function includes local node, too!
Functions:
  start, boot           Fire up all remote nodes; option -a, --all does nothing
  stop, shutdown        Shutdown nodes
  reboot                Reboot nodes
  execute               executing commands on nodes.
"
    exit 1
}

# import config values
# read_config() returns variables with values
read_config() {
    declare -gA node
    source ./nodes.conf
}

# basic ansi colors for text output

red="\e[0;31m"
green="\e[0;32m"
yellow="\e[0;33m"
blue="\e[0;34m"
magenta="\e[0;35m"
cyan="\e[0;36m"
white="\e[0;37m"
br_red="\e[0;91m"
br_green="\e[0;92m"
br_yellow="\e[0;93m"
br_blue="\e[0;94m"
br_magenta="\e[0;95m"
br_cyan="\e[0;96m"
br_white="\e[0;97m"
expand_bg="\e[K"
blue_bg="\e[0;104m${expand_bg}"
red_bg="\e[0;101m${expand_bg}"
green_bg="\e[0;102m${expand_bg}"
bold="\e[1m"
uline="\e[4m"
rst="\e[0m"     #reset color settigs to terminal default

main $ARGS #Let's go on ...

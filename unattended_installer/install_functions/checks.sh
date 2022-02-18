# Wazuh installer - checks.sh functions.
# Copyright (C) 2015, Wazuh Inc.
#
# This program is a free software; you can redistribute it
# and/or modify it under the terms of the GNU General Public
# License (version 2) as published by the FSF - Free Software
# Foundation.

function checks_arch() {

    arch=$(uname -m)

    if [ "${arch}" != "x86_64" ]; then
        common_logger -e "Uncompatible system. This script must be run on a 64-bit system."
        exit 1
    fi
}

function checks_arguments() {

    # -------------- Configurations ---------------------------------

    if [[ ( -n "${AIO}"  || -n "${configurations}" ) && -f "${tar_file}" ]]; then
            common_logger -e "File ${tar_file} exists. Please remove it if you want to use a new configuration."
            exit 1
    fi

    if [[ -n "${configurations}" && ( -n "${AIO}" || -n "${indexer}" || -n "${dashboard}" || -n "${wazuh}" || -n "${overwrite}" || -n "${start_elastic_cluster}" || -n "${tar_conf}" || -n "${uninstall}" ) ]]; then
        common_logger -e "The argument -c|--create-configurations can't be used with -a, -k, -e, -u or -w arguments."
        exit 1
    fi

    # -------------- Overwrite --------------------------------------

    if [ -n "${overwrite}" ] && [ -z "${AIO}" ] && [ -z "${indexer}" ] && [ -z "${dashboard}" ] && [ -z "${wazuh}" ]; then 
        common_logger -e "The argument -o|--overwrite must be used with -a, -k, -e or -w. If you want to uninstall all the components use -u|--uninstall"
        exit 1
    fi

    # -------------- Uninstall --------------------------------------

    if [ -n "${uninstall}" ]; then

        if [ -z "${wazuhinstalled}" ] && [ -z "${wazuh_remaining_files}" ]; then
            common_logger "Wazuh manager components were not found on the system so it was not uninstalled."
        fi

        if [ -z "${filebeatinstalled}" ] && [ -z "${filebeat_remaining_files}" ]; then
            common_logger "Filebeat components were not found on the system so it was not uninstalled."
        fi

        if [ -z "${indexerinstalled}" ] && [ -z "${indexer_remaining_files}" ]; then
            common_logger "Wazuh Indexer components were not found on the system so it was not uninstalled."
        fi

        if [ -z "${dashboardinstalled}" ] && [ -z "${dashboard_remaining_files}" ]; then
            common_logger "Wazuh Dashboard components were found on the system so it was not uninstalled."
        fi

        if [ -n "$AIO" ] || [ -n "$indexer" ] || [ -n "$dashboard" ] || [ -n "$wazuh" ]; then
            common_logger -e "It is not possible to uninstall and install in the same operation. If you want to overwrite the components use -o|--overwrite"
            exit 1
        fi
    fi

    # -------------- All-In-One -------------------------------------

    if [ -n "${AIO}" ]; then

        if [ -n "$indexer" ] || [ -n "$dashboard" ] || [ -n "$wazuh" ]; then
            common_logger -e "Argument -a|--all-in-one is not compatible with -wi|--wazuh-indexer, -wd|--wazuh-dashboard or -ws|--wazuh-server"
            exit 1
        fi

        if [ -n "${wazuhinstalled}" ] || [ -n "${wazuh_remaining_files}" ] || [ -n "${indexerinstalled}" ] || [ -n "${indexer_remaining_files}" ] || [ -n "${filebeatinstalled}" ] || [ -n "${filebeat_remaining_files}" ] || [ -n "${dashboardinstalled}" ] || [ -n "${dashboard_remaining_files}" ]; then
            if [ -n "${overwrite}" ]; then
                installCommon_rollBack
            else
                common_logger -e "Some the Wazuh components were found on this host. If you want to overwrite the current installation, run this script back using the option -o/--overwrite. NOTE: This will erase all the existing configuration and data."
                exit 1
            fi
        fi
    fi

    # -------------- Indexer ----------------------------------

    if [ -n "${indexer}" ]; then

        if [ -n "${indexerinstalled}" ] || [ -n "${indexer_remaining_files}" ]; then
            if [ -n "${overwrite}" ]; then
                installCommon_rollBack
            else
                common_logger -e "Wazuh Indexer is already installed in this node or some of its files haven't been erased. Use option -o|--overwrite to overwrite all components."
                exit 1
            fi
        fi
    fi

    # -------------- Wazuh Dashboard --------------------------------

    if [ -n "${dashboard}" ]; then
        if [ -n "${dashboardinstalled}" ] || [ -n "${dashboard_remaining_files}" ]; then
            if [ -n "${overwrite}" ]; then
                installCommon_rollBack
            else
                common_logger -e "Wazuh Dashboard is already installed in this node or some of its files haven't been erased. Use option -o|--overwrite to overwrite all components."
                exit 1
            fi
        fi
    fi

    # -------------- Wazuh ------------------------------------------

    if [ -n "${wazuh}" ]; then
        if [ -n "${wazuhinstalled}" ] || [ -n "${wazuh_remaining_files}" ]; then
            if [ -n "${overwrite}" ]; then
                installCommon_rollBack
            else
                common_logger -e "Wazuh is already installed in this node or some of its files haven't been erased. Use option -o|--overwrite to overwrite all components."
                exit 1
            fi
        fi

        if [ -n "${filebeatinstalled}" ] || [ -n "${filebeat_remaining_files}" ]; then
            if [ -n "${overwrite}" ]; then
                installCommon_rollBack
            else
                common_logger -e "Filebeat is already installed in this node or some of its files haven't been erased. Use option -o|--overwrite to overwrite all components."
                exit 1
            fi
        fi
    fi

    # -------------- Cluster start ----------------------------------

    if [[ -n "${start_elastic_cluster}" && ( -n "${AIO}" || -n "${indexer}" || -n "${dashboard}" || -n "${wazuh}" || -n "${overwrite}" || -n "${configurations}" || -n "${tar_conf}" || -n "${uninstall}") ]]; then
        common_logger -e "The argument -s|--start-cluster can't be used with -a, -k, -e or -w arguments."
        exit 1
    fi

    # -------------- Global -----------------------------------------

    if [ -z "${AIO}" ] && [ -z "${indexer}" ] && [ -z "${dashboard}" ] && [ -z "${wazuh}" ] && [ -z "${start_elastic_cluster}" ] && [ -z "${configurations}" ] && [ -z "${uninstall}"]; then
        common_logger -e "At least one of these arguments is necessary -a|--all-in-one, -c|--create-configurations, -wi|--wazuh-indexer, -wd|--wazuh-dashboard, -s|--start-cluster, -ws|--wazuh-server, -u|--uninstall"
        exit 1
    fi

}

function checks_health() {

    checks_specifications
    if [ -n "${indexer}" ]; then
        if [ "${cores}" -lt 2 ] || [ "${ram_gb}" -lt 3700 ]; then
            common_logger -e "Your system does not meet the recommended minimum hardware requirements of 4Gb of RAM and 2 CPU cores. If you want to proceed with the installation use the -i option to ignore these requirements."
            exit 1
        else
            common_logger "Check recommended minimum hardware requirements for Wazuh Indexer done."
        fi
    fi

    if [ -n "${dashboard}" ]; then
        if [ "${cores}" -lt 2 ] || [ "${ram_gb}" -lt 3700 ]; then
            common_logger -e "Your system does not meet the recommended minimum hardware requirements of 4Gb of RAM and 2 CPU cores. If you want to proceed with the installation use the -i option to ignore these requirements."
            exit 1
        else
            common_logger "Check recommended minimum hardware requirements for Wazuh Dashboard done."
        fi
    fi

    if [ -n "${wazuh}" ]; then
        if [ "${cores}" -lt 2 ] || [ "${ram_gb}" -lt 1700 ]; then
            common_logger -e "Your system does not meet the recommended minimum hardware requirements of 2Gb of RAM and 2 CPU cores . If you want to proceed with the installation use the -i option to ignore these requirements."
            exit 1
        else
            common_logger "Check recommended minimum hardware requirements for Wazuh Manager done."
        fi
    fi

    if [ -n "${AIO}" ]; then
        if [ "${cores}" -lt 2 ] || [ "${ram_gb}" -lt 3700 ]; then
            common_logger -e "Your system does not meet the recommended minimum hardware requirements of 4Gb of RAM and 2 CPU cores. If you want to proceed with the installation use the -i option to ignore these requirements."
            exit 1
        else
            common_logger "Check recommended minimum hardware requirements for AIO done."
        fi
    fi

}

# This function ensures different names in the config.yml file.
function checks_names() {

    if [ -n "${indxname}" ] && [ -n "${dashname}" ] && [ "${indxname}" == "${dashname}" ]; then
        common_logger -e "The node names for Wazuh Indexer and Wazuh Dashboard must be different."
        exit 1
    fi

    if [ -n "${indxname}" ] && [ -n "${winame}" ] && [ "${indxname}" == "${winame}" ]; then
        common_logger -e "The node names for Elastisearch and Wazuh must be different."
        exit 1
    fi

    if [ -n "${winame}" ] && [ -n "${dashname}" ] && [ "${winame}" == "${dashname}" ]; then
        common_logger -e "The node names for Wazuh Server and Wazuh Indexer must be different."
        exit 1
    fi

    if [ -n "${winame}" ] && [ -z "$(echo "${server_node_names[@]}" | grep -w "${winame}")" ]; then
        common_logger -e "The Wazuh server node name ${winame} does not appear on the configuration file."
        exit 1
    fi

    if [ -n "${indxname}" ] && [ -z "$(echo "${indexer_node_names[@]}" | grep -w "${indxname}")" ]; then
        common_logger -e "The Wazuh Indexer node name ${indxname} does not appear on the configuration file."
        exit 1
    fi

    if [ -n "${dashname}" ] && [ -z "$(echo "${dashboard_node_names[@]}" | grep -w "${dashname}")" ]; then
        common_logger -e "The Wazuh Dashboard node name ${dashname} does not appear on the configuration file."
        exit 1
    fi

}

# This function checks if the target certificates are created before to start the installation.
function checks_previousCertificate() {

    if [ ! -f "${tar_file}" ]; then
        common_logger -e "No certificates file found (${tar_file}). Run the script with the option -c|--certificates to create automatically or copy them from the node where they were created."
        exit 1
    fi

    if [ -n "${indxname}" ]; then
        if ! $(tar -tf "${tar_file}" | grep -q "${indxname}".pem) || ! $(tar -tf "${tar_file}" | grep -q "${indxname}"-key.pem); then
            common_logger -e "There is no certificate for the indexer node ${indxname} in ${tar_file}."
            exit 1
        fi
    fi

    if [ -n "${dashname}" ]; then
        if ! $(tar -tf "${tar_file}" | grep -q "${dashname}".pem) || ! $(tar -tf "${tar_file}" | grep -q "${dashname}"-key.pem); then
            common_logger -e "There is no certificate for the Wazuh Dashboard node ${dashname} in ${tar_file}."
            exit 1
        fi
    fi

    if [ -n "${winame}" ]; then
        if ! $(tar -tf "${tar_file}" | grep -q "${winame}".pem) || ! $(tar -tf "${tar_file}" | grep -q "${winame}"-key.pem); then
            common_logger -e "There is no certificate for the wazuh server node ${winame} in ${tar_file}."
            exit 1
        fi
    fi

}

function checks_specifications() {

    cores=$(cat /proc/cpuinfo | grep -c processor )
    ram_gb=$(free -m | awk '/^Mem:/{print $2}')

}
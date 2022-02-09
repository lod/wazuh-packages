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

    if [[ -n "${configurations}" && ( -n "${AIO}" || -n "${indexer}" || -n "${dashboards}" || -n "${wazuh}" || -n "${overwrite}" || -n "${start_elastic_cluster}" || -n "${tar_conf}" || -n "${uninstall}" ) ]]; then
        common_logger -e "The argument -c|--create-configurations can't be used with -a, -k, -e, -u or -w arguments."
        exit 1
    fi

    # -------------- Overwrite --------------------------------------

    if [ -n "${overwrite}" ] && [ -z "${AIO}" ] && [ -z "${indexer}" ] && [ -z "${dashboards}" ] && [ -z "${wazuh}" ]; then 
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

        if [ -z "${indexerchinstalled}" ] && [ -z "${indexer_remaining_files}" ]; then
            common_logger "Elasticsearch components were not found on the system so it was not uninstalled."
        fi

        if [ -z "${dashboardsinstalled}" ] && [ -z "${dashboards_remaining_files}" ]; then
            common_logger "Kibana components were found on the system so it was not uninstalled."
        fi

        if [ -n "$AIO" ] || [ -n "$elasticsearch" ] || [ -n "$kibana" ] || [ -n "$wazuh" ]; then
            common_logger -e "The argument -u|--uninstall can't be used with -a, -k, -e or -w. If you want to overwrite the components use -o|--overwrite"
            exit 1
        fi
    fi

    # -------------- All-In-One -------------------------------------

    if [ -n "${AIO}" ]; then

        if [ -n "$elasticsearch" ] || [ -n "$kibana" ] || [ -n "$wazuh" ]; then
            common_logger -e "Argument -a|--all-in-one is not compatible with -e|--elasticsearch, -k|--kibana or -w|--wazuh-server"
            exit 1
        fi

        if [ -n "${wazuhinstalled}" ] || [ -n "${wazuh_remaining_files}" ] || [ -n "${indexerchinstalled}" ] || [ -n "${indexer_remaining_files}" ] || [ -n "${filebeatinstalled}" ] || [ -n "${filebeat_remaining_files}" ] || [ -n "${dashboardsinstalled}" ] || [ -n "${dashboards_remaining_files}" ]; then
            if [ -n "${overwrite}" ]; then
                common_rollback
            else
                common_logger -e "Some the Wazuh components were found on this host. If you want to overwrite the current installation, run this script back using the option -o/--overwrite. NOTE: This will erase all the existing configuration and data."
                exit 1
            fi
        fi
    fi

    # -------------- Elasticsearch ----------------------------------

    if [ -n "${indexer}" ]; then

        if [ -n "${indexerchinstalled}" ] || [ -n "${indexer_remaining_files}" ]; then
            if [ -n "${overwrite}" ]; then
                common_rollback
            else
                common_logger -e "Elasticsearch is already installed in this node or some of its files haven't been erased. Use option -o|--overwrite to overwrite all components."
                exit 1
            fi
        fi
    fi

    # -------------- Kibana -----------------------------------------

    if [ -n "${dashboards}" ]; then
        if [ -n "${dashboardsinstalled}" ] || [ -n "${dashboards_remaining_files}" ]; then
            if [ -n "${overwrite}" ]; then
                common_rollback
            else
                common_logger -e "Kibana is already installed in this node or some of its files haven't been erased. Use option -o|--overwrite to overwrite all components."
                exit 1
            fi
        fi
    fi

    # -------------- Wazuh ------------------------------------------

    if [ -n "${wazuh}" ]; then
        if [ -n "${wazuhinstalled}" ] || [ -n "${wazuh_remaining_files}" ]; then
            if [ -n "${overwrite}" ]; then
                common_rollback
            else
                common_logger -e "Wazuh is already installed in this node or some of its files haven't been erased. Use option -o|--overwrite to overwrite all components."
                exit 1
            fi
        fi

        if [ -n "${filebeatinstalled}" ] || [ -n "${filebeat_remaining_files}" ]; then
            if [ -n "${overwrite}" ]; then
                common_rollback
            else
                common_logger -e "Filebeat is already installed in this node or some of its files haven't been erased. Use option -o|--overwrite to overwrite all components."
                exit 1
            fi
        fi
    fi

    # -------------- Cluster start ----------------------------------

    if [[ -n "${start_elastic_cluster}" && ( -n "${AIO}" || -n "${indexer}" || -n "${dashboards}" || -n "${wazuh}" || -n "${overwrite}" || -n "${configurations}" || -n "${tar_conf}" || -n "${uninstall}") ]]; then
        common_logger -e "The argument -s|--start-cluster can't be used with -a, -k, -e or -w arguments."
        exit 1
    fi

    # -------------- Global -----------------------------------------

    if [ -z "${AIO}" ] && [ -z "${indexer}" ] && [ -z "${dashboards}" ] && [ -z "${wazuh}" ] && [ -z "${start_elastic_cluster}" ] && [ -z "${configurations}" ] && [ -z "${uninstall}" ]; then
        common_logger -e "At least one of these arguments is necessary -a|--all-in-one, -c|--create-configurations, -e|--elasticsearch <elasticsearch-node-name>, -k|--kibana <kibana-node-name>, -s|--start-cluster, -w|--wazuh-server <wazuh-node-name>, -u|--uninstall"
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
            common_logger "Check recommended minimum hardware requirements for Elasticsearch done."
        fi
    fi

    if [ -n "${dashboards}" ]; then
        if [ "${cores}" -lt 2 ] || [ "${ram_gb}" -lt 3700 ]; then
            common_logger -e "Your system does not meet the recommended minimum hardware requirements of 4Gb of RAM and 2 CPU cores. If you want to proceed with the installation use the -i option to ignore these requirements."
            exit 1
        else
            common_logger "Check recommended minimum hardware requirements for Kibana done."
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

    if [ -n "${aio}" ]; then
        if [ "${cores}" -lt 2 ] || [ "${ram_gb}" -lt 3700 ]; then
            common_logger -e "Your system does not meet the recommended minimum hardware requirements of 4Gb of RAM and 2 CPU cores. If you want to proceed with the installation use the -i option to ignore these requirements."
            exit 1
        else
            common_logger "Check recommended minimum hardware requirements for AIO done."
        fi
    fi

}

function checks_installed() {

    if [ "${sys_type}" == "yum" ]; then
        wazuhinstalled=$(yum list installed 2>/dev/null | grep wazuh-manager)
    elif [ "${sys_type}" == "zypper" ]; then
        wazuhinstalled=$(zypper packages | grep wazuh-manager | grep i+)
    elif [ "${sys_type}" == "apt-get" ]; then
        wazuhinstalled=$(apt list --installed  2>/dev/null | grep wazuh-manager)
    fi

    if [ -d "/var/ossec" ]; then
        wazuh_remaining_files=1
    fi

    if [ "${sys_type}" == "yum" ]; then
        indexerchinstalled=$(yum list installed 2>/dev/null | grep wazuh-indexer | grep -v kibana)
    elif [ "${sys_type}" == "zypper" ]; then
        indexerchinstalled=$(zypper packages | grep wazuh-indexer | grep -v kibana | grep i+)
    elif [ "${sys_type}" == "apt-get" ]; then
        indexerchinstalled=$(apt list --installed 2>/dev/null | grep wazuh-indexer | grep -v kibana)
    fi

    if [ -d "/var/lib/wazuh-indexer/" ] || [ -d "/usr/share/wazuh-indexer" ] || [ -d "/etc/wazuh-indexer" ] || [ -f "${base_path}/search-guard-tlstool*" ]; then
        indexer_remaining_files=1
    fi

    if [ "${sys_type}" == "yum" ]; then
        filebeatinstalled=$(yum list installed 2>/dev/null | grep filebeat)
    elif [ "${sys_type}" == "zypper" ]; then
        filebeatinstalled=$(zypper packages | grep filebeat | grep i+)
    elif [ "${sys_type}" == "apt-get" ]; then
        filebeatinstalled=$(apt list --installed  2>/dev/null | grep filebeat)
    fi

    if [ -d "/var/lib/filebeat/" ] || [ -d "/usr/share/filebeat" ] || [ -d "/etc/filebeat" ]; then
        filebeat_remaining_files=1
    fi

    if [ "${sys_type}" == "yum" ]; then
        dashboardsinstalled=$(yum list installed 2>/dev/null | grep wazuh-dashboards)
    elif [ "${sys_type}" == "zypper" ]; then
        dashboardsinstalled=$(zypper packages | grep wazuh-dashboards | grep i+)
    elif [ "${sys_type}" == "apt-get" ]; then
        dashboardsinstalled=$(apt list --installed  2>/dev/null | grep wazuh-dashboards)
    fi

    if [ -d "/var/lib/wazuh-dashboards/" ] || [ -d "/usr/share/wazuh-dashboards" ] || [ -d "/etc/wazuh-dashboards" ] || [ -d "/run/wazuh-dashboards/" ]; then
        dashboards_remaining_files=1
    fi

}

# This function ensures different names in the config.yml file.
function checks_names() {

    if [ -n "${indxname}" ] && [ -n "${dashname}" ] && [ "${indxname}" == "${dashname}" ]; then
        common_logger -e "The node names for Elastisearch and Kibana must be different."
        exit 1
    fi

    if [ -n "${indxname}" ] && [ -n "${winame}" ] && [ "${indxname}" == "${winame}" ]; then
        common_logger -e "The node names for Elastisearch and Wazuh must be different."
        exit 1
    fi

    if [ -n "${winame}" ] && [ -n "${dashname}" ] && [ "${winame}" == "${dashname}" ]; then
        common_logger -e "The node names for Wazuh and Kibana must be different."
        exit 1
    fi

    if [ -n "${winame}" ] && [ -z "$(echo "${wazuh_servers_node_names[@]}" | grep -w "${winame}")" ]; then
        common_logger -e "The Wazuh server node name ${winame} does not appear on the configuration file."
        exit 1
    fi

    if [ -n "${indxname}" ] && [ -z "$(echo "${indexer_node_names[@]}" | grep -w "${indxname}")" ]; then
        common_logger -e "The Elasticsearch node name ${indxname} does not appear on the configuration file."
        exit 1
    fi

    if [ -n "${dashname}" ] && [ -z "$(echo "${dashboards_node_names[@]}" | grep -w "${dashname}")" ]; then
        common_logger -e "The Kibana node name ${dashname} does not appear on the configuration file."
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
            common_logger -e "There is no certificate for the elasticsearch node ${indxname} in ${tar_file}."
            exit 1
        fi
    fi

    if [ -n "${dashname}" ]; then
        if ! $(tar -tf "${tar_file}" | grep -q "${dashname}".pem) || ! $(tar -tf "${tar_file}" | grep -q "${dashname}"-key.pem); then
            common_logger -e "There is no certificate for the kibana node ${dashname} in ${tar_file}."
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

function checks_system() {

    if [ -n "$(command -v yum)" ]; then
        sys_type="yum"
        sep="-"
    elif [ -n "$(command -v zypper)" ]; then
        sys_type="zypper"
        sep="-"
    elif [ -n "$(command -v apt-get)" ]; then
        sys_type="apt-get"
        sep="="
    else
        common_logger -e "Couldn'd find type of system"
        exit 1
    fi

}

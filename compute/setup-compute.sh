#!/bin/bash
#---------------------------------------------
#Project - openstack-easy-deploy
#Description - compute node installer script
#Date created - 20190220
#Compatible OS - Centos 7.x (only)
#https://github.com/rafalefighter
#---------------------------------------------


CURRENT_DIR=$(pwd)

function write_cofig_files() {

    #get user input
    echo "Note - Please configure openstack controller befor this ..!!"
    echo "Note - Please use values from the controller deployment for this setup ..!!"
    echo
    read -p "Enter Controller IP = " CONTROLLER_IP
    read -p "Enter This Compute node IP = " COMPUTE_IP
    read -p "Enter provider network interface = " PROVIDER_NET
    read -p "Enter Openstack Password = " OPENSTACK_PASSWORD
    read -p "Enter region (datacenter) = " REGION

    #print confirmation
    echo 
    echo "-------------------------------------"
    echo "Controller IP = "$CONTROLLER_IP
    echo "This Compute node IP = "$COMPUTE_IP
    echo "Provider network interface = "$PROVIDER_NET 
    echo "Provider interface IP = "$PROVIDER_IFACE_IP 
    echo "Openstack Pass = "$OPENSTACK_PASSWORD 
    echo "Datacenter region = " $REGION
    echo "-------------------------------------"


    #confirmation
    read -p "Are these details correct ? " -r
    echo    
    if [[ $REPLY =~ ^[Nn]$ ]]
    then
        return
    fi

    #change config files
    find ./ -type f -exec sed -i -e "s/CONTROLLERIPADDR/$CONTROLLER_IP/g" {} \;
    find ./ -type f -exec sed -i -e "s/COMPUTEIPADDR/$COMPUTE_IP/g" {} \;
    find ./ -type f -exec sed -i -e "s/PROVIDERNETIFACEVAL/$PROVIDER_NET/g" {} \;
    find ./ -type f -exec sed -i -e "s/OVERLAY_INTERFACE_IP_ADDRESS/$COMPUTE_IP/g" {} \;
    find ./ -type f -exec sed -i -e "s/RABBITPASS/$OPENSTACK_PASSWORD/g" {} \;
    find ./ -type f -exec sed -i -e "s/SQLPASS/$OPENSTACK_PASSWORD/g" {} \;
    find ./ -type f -exec sed -i -e "s/OPENSTACKPASS/$OPENSTACK_PASSWORD/g" {} \;
    find ./ -type f -exec sed -i -e "s/OPENSTACKREGION/$REGION/g" {} \;

}



function install_services() {

    yum -y install epel-release
    yum -y install centos-release-openstack-rocky
    yum -y install python-openstackclient  
    yum -y install wget zip unzip htop iftop tcpdump ebtables httpd iptables-services net-tools bind-utils
    yum -y install openstack-nova-compute
    yum -y install openstack-neutron-linuxbridge ebtables ipset

}

function configure_os() {

    echo "disabling selinux----"
    sed -i 's/enforcing/disabled/g' /etc/selinux/config /etc/selinux/config
    setenforce 0
    sestatus

    echo "disabling firewalld service-----"
    systemctl disable firewalld
    systemctl stop firewalld

    echo "enabling iptables service---"
    systemctl enable iptables
    systemctl start iptables

    echo "flushing iptables---"
    iptables -F 
    iptables-save
    iptables-save > /etc/sysconfig/iptables

    echo "disabling ipv6----"
    sed -i 's/GRUB_CMDLINE_LINUX="/GRUB_CMDLINE_LINUX="ipv6.disable=1 /g' /etc/default/grub
    grub2-mkconfig -o /boot/grub2/grub.cfg

    echo "alias ns='netstat -plntu'" >> ~/.bashrc
    echo "alias ll='ls -lh'" >> ~/.bashrc
    echo "alias os='openstack'" >> ~/.bashrc
    echo "alias os-status=\"systemctl list-units | egrep 'neutron|openstack'\""  >> ~/.bashrc
    . ~/.bashrc

}


function configure_nova_compute() {

    #copy nova config files
    /bin/cp -rf $CURRENT_DIR/config/nova/nova.conf /etc/nova/

    #start and enable nova services on compute node
    systemctl enable libvirtd.service openstack-nova-compute.service
    systemctl start libvirtd.service openstack-nova-compute.service

}


function configure_neutron_compute() {

    #copy neutron config files on compute node
    /bin/cp -rf $CURRENT_DIR/config/neutron/neutron.conf /etc/neutron/
    /bin/cp -rf $CURRENT_DIR/config/neutron/linuxbridge_agent.ini /etc/neutron/plugins/ml2/

    #restart nova compute services
    systemctl restart openstack-nova-compute.service

    #start and enable neutron services on compute node
    systemctl enable neutron-linuxbridge-agent.service
    systemctl start neutron-linuxbridge-agent.service

}

#write config files
write_cofig_files

#bootstrap
install_services
configure_os

#nova-service related
configure_nova_compute

#neutron-service related
configure_neutron_compute

#check os-status
os-status
echo ""
echo ""
openstack endpoint list
#!/bin/bash
#---------------------------------------------
#Project - openstack-easy-deploy
#Description - openstack storage node install script
#Date created - 20190220
#Compatible OS - Centos 7.x (only)
#https://github.com/rafalefighter
#---------------------------------------------


function write_cofig_files() {

    #get user input
    echo "Note - This configuration need up and running openstack and ceph clusters ..!!"
    echo "     - please install ceph cluster using setup-ceph installer"
    echo
    echo "Note - Please use the same values from openstack deployment for this setup ..!!"


    echo
    read -p "Enter Controller IP = " CONTROLLER_IP
    read -p "Enter Openstack Password = " OPENSTACK_PASSWORD
    read -p "Enter region (datacenter) = " REGION

    echo

    #print confirmation
    echo 
    echo "-------------------------------------"
    echo "Controller IP = "$CONTROLLER_IP
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
    find ./ -type f -exec sed -i -e "s/RABBITPASS/$OPENSTACK_PASSWORD/g" {} \;
    find ./ -type f -exec sed -i -e "s/SQLPASS/$OPENSTACK_PASSWORD/g" {} \;
    find ./ -type f -exec sed -i -e "s/OPENSTACKPASS/$OPENSTACK_PASSWORD/g" {} \;
    find ./ -type f -exec sed -i -e "s/OPENSTACKREGION/$REGION/g" {} \;
    

}

CURRENT_DIR=$(pwd)


function install_storage_backend() {

    #install openstack repo
    yum -y install centos-release-openstack-rocky

    #install cinder volume service
    yum -y install openstack-cinder targetcli python-keystone

    #install lvm services for storage node
    yum -y install lvm2 device-mapper-persistent-data
    
}



function configure_lvm_storage_node(){
    
    #copy config  files
    /bin/cp -rf $CURRENT_DIR/config/cinder-volume.conf /etc/cinder/cinder.conf

    #start and enable lvm
    systemctl enable lvm2-lvmetad.service 
    systemctl start lvm2-lvmetad.service

    #start and enable target
    systemctl enable target.service
    systemctl start target.service

    #optional  enable cinder volume services
    systemctl enable openstack-cinder-volume.service 
    systemctl start openstack-cinder-volume.service

}



write_cofig_files
install_storage_backend
configure_lvm_storage_node
#!/bin/bash
#---------------------------------------------
#Project - openstack-easy-deploy
#Description - ceph-storage configuration for openstack
#Date created - 20190220
#Compatible OS - Centos 7.x (only)
#https://github.com/rafalefighter
#---------------------------------------------



CURRENT_DIR=$(pwd)

function write_cofig_files() {

    #get user input
    echo "  -- This configuration need up and running openstack and ceph clusters ..!!"
    echo "  -- Please use the same values from openstack deployment for this setup ..!!"


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
    find ./ -type f -exec sed -i -e "s/RABBITPASS/$OPENSTACK_PASSWORD/g" {} \;
    find ./ -type f -exec sed -i -e "s/SQLPASS/$OPENSTACK_PASSWORD/g" {} \;
    find ./ -type f -exec sed -i -e "s/OPENSTACKPASS/$OPENSTACK_PASSWORD/g" {} \;
    find ./ -type f -exec sed -i -e "s/OPENSTACKREGION/$REGION/g" {} \;
    

}

function configure_glance_image_service(){

    #copy config files
    /bin/cp -rf $CURRENT_DIR/config/glance-api-ceph.conf /etc/glance/glance-api.conf

    #restart  all glance services
    systemctl restart openstack-glance-api.service 
    systemctl restart openstack-glance-registry.service

}


function configure_cinder_volume_service(){

    #generate uuid for kvm
    uuidgen > $CURRENT_DIR/config/uuid.txt
    KVMHWUUID=`cat $CURRENT_DIR/config/uuid.txt`

    #change the uuid for xml files
    find ./ -type f -exec sed -i -e "s/KVMHWUUID/$KVMHWUUID/g" {} \;

    #copy config files
    /bin/cp -rf $CURRENT_DIR/config/cinder-ceph.conf /etc/cinder/cinder.conf

    #enable cinder volume services
    systemctl enable openstack-cinder-volume.service 
    systemctl start openstack-cinder-volume.service

    #restart all cinder services
    systemctl restart openstack-cinder-scheduler.service
    systemctl restart openstack-cinder-api.service 

    #infomation 
    echo
    echo "Please use below info for configure ceph on compute node"
    echo
    echo "----------------------------------------------"
    echo "KVM Hypervisor UUID = " $KVMHWUUID
    echo "----------------------------------------------"

}



function configure_nova_compute_service(){

    #get kvm uuid
    read -p "Enter This Compute node IP = " COMPUTE_IP  
    read -p "Please enter KVM hardware UUID = " KVMHWUUID

    #replace kvm uuid
    find ./ -type f -exec sed -i -e "s/KVMHWUUID/$KVMHWUUID/g" {} \;
    find ./ -type f -exec sed -i -e "s/COMPUTEIPADDR/$COMPUTE_IP/g" {} \;  

    #copy xml to ceph folder
    /bin/cp -rf $CURRENT_DIR/config/kvmsecrect.xml /etc/ceph

    #configure hypervisor to use secret
    virsh secret-define --file /etc/ceph/kvmsecrect.xml
    virsh secret-set-value --secret $KVMHWUUID --base64 $(cat /etc/ceph/ceph.client.cinder.keyring)

    #copy config  files
    /bin/cp -rf $CURRENT_DIR/config/nova-ceph.conf /etc/nova/nova.conf

    #restart  all glance services


    
    systemctl restart openstack-nova-compute.service

}


PS3='Select the node to configure with CEPH backend - '
options=("CONTROLLER" "COMPUTE")
select choice in "${options[@]}"
do
    case $choice in
        "CONTROLLER")
            echo
            echo "  Configuring CONTROLLER node with CEPH backend....."
            write_cofig_files
            configure_glance_image_service
            configure_cinder_volume_service
            break
            ;;
        "COMPUTE")
            echo
            echo "  Configuring the COMPUTE node with CEPH backend....."
            write_cofig_files
            configure_nova_compute_service
            break
            ;;
        *) echo "invalid option";;
    esac
done

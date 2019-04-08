#!/bin/bash
#---------------------------------------------
#Project - openstack-easy-deploy
#Description - openstack controller node install script
#Date created - 20190220
#Compatible OS - Centos 7.x (only)
#https://github.com/rafalefighter
#---------------------------------------------


CURRENT_DIR=$(pwd)

function write_cofig_files() {

    #get user input
    read -p "Enter Controller IP = " CONTROLLER_IP
    read -p "Enter provider network interface = " PROVIDER_NET
    read -p "Enter Openstack Password = " OPENSTACK_PASSWORD
    read -p "Enter region (datacenter) = " REGION


    #confirmation
    read -p "Are these details correct ? " -r
    echo    
    if [[ $REPLY =~ ^[Nn]$ ]]
    then
        return
    fi

    #change config files
    find ./ -type f -exec sed -i -e "s/CONTROLLERIPADDR/$CONTROLLER_IP/g" {} \;
    find ./ -type f -exec sed -i -e "s/PROVIDERNETIFACEVAL/$PROVIDER_NET/g" {} \;
    find ./ -type f -exec sed -i -e "s/OVERLAY_INTERFACE_IP_ADDRESS/$CONTROLLER_IP/g" {} \;
    find ./ -type f -exec sed -i -e "s/RABBITPASS/$OPENSTACK_PASSWORD/g" {} \;
    find ./ -type f -exec sed -i -e "s/SQLPASS/$OPENSTACK_PASSWORD/g" {} \;
    find ./ -type f -exec sed -i -e "s/OPENSTACKPASS/$OPENSTACK_PASSWORD/g" {} \;
    find ./ -type f -exec sed -i -e "s/OPENSTACKREGION/$REGION/g" {} \;

}


function install_services() {

    #clean and update
    yum clean all
    yum -y update

    #install repos
    yum -y install epel-release
    yum -y install centos-release-openstack-rocky

    yum -y install python2-PyMySQL rabbitmq-server 
    yum -y install memcached python-memcached 
    yum -y install wget zip unzip htop iftop tcpdump ebtables httpd iptables-services net-tools bind-utils
    yum -y install mariadb mariadb-server
    yum -y install python-openstackclient

    #install keystone
    yum -y install openstack-keystone mod_wsgi

    #install glance service
    yum -y install openstack-glance 

    #installing nova computer services
    yum -y install openstack-nova-api openstack-nova-conductor 
    yum -y install openstack-nova-console openstack-nova-novncproxy
    yum -y install openstack-nova-scheduler openstack-nova-placement-api

    #install neutron
    yum install -y openstack-neutron openstack-neutron-ml2
    yum install -y openstack-neutron-linuxbridge

    #install horizan
    yum -y install openstack-dashboard

    #install cinder services
    yum -y install openstack-cinder

    #install volume servuice support
    yum -y targetcli python-keystone
    yum -y install lvm2 device-mapper-persistent-data
    
}



function configure_os() {

    #sourcing the adminrc file 
    source $CURRENT_DIR/config/keystone/adminrc

    echo "configuring mariadb service----"
    /bin/cp -rf $CURRENT_DIR/config/mariadb/openstack_db.cnf /etc/my.cnf.d/
    systemctl restart mariadb.service


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



function configure_memcached() {

    /bin/cp -rf $CURRENT_DIR/config/memcached/memcached.conf /etc/sysconfig/memcached.conf
    /bin/cp -rf $CURRENT_DIR/config/memcached/memcached.service /etc/systemd/system

    chown root:memcached /etc/sysconfig/memcached.conf

    systemctl enable memcached.service
    systemctl start memcached.service

}


function configure_rabbitmq() {

    systemctl enable rabbitmq-server.service
    systemctl start rabbitmq-server.service

    rabbitmqctl add_user openstack $OPENSTACK_PASSWORD  
    rabbitmqctl set_permissions openstack ".*" ".*" ".*"

}


function configure_database() {

    systemctl enable mariadb.service
    systemctl start mariadb.service

    echo "creating databases----"
    mysql -u root < $CURRENT_DIR/sql/databases.sql
}


function configure_keystone() {

    systemctl enable httpd
    systemctl start httpd

    #copy configurtaion files
    /bin/cp -rf $CURRENT_DIR/config/keystone/keystone.conf /etc/keystone/
    /bin/cp -rf $CURRENT_DIR/config/apache/httpd.conf /etc/httpd/conf/

    #fix permissions for keystone conf
    chown root:keystone /etc/keystone/keystone.conf

    #create link for apache
    ln -s /usr/share/keystone/wsgi-keystone.conf /etc/httpd/conf.d/

    #restart apache service 
    systemctl restart httpd

    #keystone configure tokens and credentials
    keystone-manage fernet_setup --keystone-user keystone --keystone-group keystone
    keystone-manage credential_setup --keystone-user keystone --keystone-group keystone

    #populate keystone database
    /bin/sh -c "keystone-manage db_sync" keystone

    #enable keystone api endpoints
    keystone-manage bootstrap --bootstrap-password $OPENSTACK_PASSWORD \
    --bootstrap-admin-url http://$CONTROLLER_IP:5000/v3/ \
    --bootstrap-internal-url http://$CONTROLLER_IP:5000/v3/ \
    --bootstrap-public-url http://$CONTROLLER_IP:5000/v3/ \
    --bootstrap-region-id $REGION

    openstack project create --domain default --description "Service Project" service
    openstack role create user
    #openstack domain create --description "An Example Domain" example
    #openstack project create --domain default --description "Demo Project" myproject
    #openstack user create --domain default --password openstackpass  myuser
    #openstack role create myrole
    #openstack role add --project myproject --user myuser myrole

}


function configure_glance() {

    #copy configuration files
    /bin/cp -rf $CURRENT_DIR/config/glance/glance-api.conf /etc/glance/
    /bin/cp -rf $CURRENT_DIR/config/glance/glance-registry.conf /etc/glance/

    #create user role and service for glance
    openstack user create --domain default --password $OPENSTACK_PASSWORD glance
    openstack role add --project service --user glance admin
    openstack service create --name glance --description "OpenStack Image" image

    #create glance API endpoints
    openstack endpoint create --region $REGION image public http://$CONTROLLER_IP:9292
    openstack endpoint create --region $REGION image internal http://$CONTROLLER_IP:9292
    openstack endpoint create --region $REGION image admin http://$CONTROLLER_IP:9292

    #populate glance database
    /bin/sh -c "glance-manage db_sync" glance


    #start and enable glance related services
    systemctl enable openstack-glance-api.service openstack-glance-registry.service
    systemctl start openstack-glance-api.service openstack-glance-registry.service

}


function configure_nova() {

    #Create the Compute service credentials:
    openstack user create --domain default --password $OPENSTACK_PASSWORD nova
    openstack role add --project service --user nova admin
    openstack service create --name nova --description "OpenStack Compute" compute

    #Create the Compute API service endpoints:
    openstack endpoint create --region $REGION compute public http://$CONTROLLER_IP:8774/v2.1
    openstack endpoint create --region $REGION compute internal http://$CONTROLLER_IP:8774/v2.1
    openstack endpoint create --region $REGION compute admin http://$CONTROLLER_IP:8774/v2.1

    #Create a Placement service user using your chosen PLACEMENT_PASS:
    openstack user create --domain default --password $OPENSTACK_PASSWORD placement

    #dd the Placement user to the service project with the admin role
    openstack role add --project service --user placement admin

    #Create the Placement API entry in the service catalog
    openstack service create --name placement --description "Placement API" placement

    #Create the Placement API service endpoints:
    openstack endpoint create --region $REGION placement public http://$CONTROLLER_IP:8778
    openstack endpoint create --region $REGION placement internal http://$CONTROLLER_IP:8778
    openstack endpoint create --region $REGION placement admin http://$CONTROLLER_IP:8778

    #copying configuration files
    /bin/cp -rf $CURRENT_DIR/config/nova/nova.conf /etc/nova/
    /bin/cp -rf $CURRENT_DIR/config/nova/00-nova-placement-api.conf /etc/httpd/conf.d/

    #fix log permissions 
    chown nova:nova /var/log/nova/ *

    #restarting apache
    systemctl restart httpd

    #populating databsaes
    /bin/sh -c "nova-manage api_db sync" nova
    /bin/sh -c "nova-manage cell_v2 map_cell0" nova
    /bin/sh -c "nova-manage cell_v2 create_cell --name=cell1 --verbose" nova
    /bin/sh -c "nova-manage db sync" nova

    #verify database population
    /bin/sh -c "nova-manage cell_v2 list_cells" nova

    #starting nova services
    systemctl start openstack-nova-api.service
    systemctl start openstack-nova-scheduler.service
    systemctl start openstack-nova-conductor.service
    systemctl start openstack-nova-novncproxy.service

    #enabling nova services
    systemctl enable openstack-nova-api.service
    systemctl enable openstack-nova-scheduler.service
    systemctl enable openstack-nova-conductor.service
    systemctl enable openstack-nova-novncproxy.service

}


function configure_neutron() {

    #create neutron user and add roles
    openstack user create --domain default --password $OPENSTACK_PASSWORD neutron
    openstack role add --project service --user neutron admin

    #create neutron service 
    openstack service create --name neutron --description "OpenStack Networking" network

    #create neutron API endpoints
    openstack endpoint create --region $REGION network public http://$CONTROLLER_IP:9696
    openstack endpoint create --region $REGION network internal http://$CONTROLLER_IP:9696
    openstack endpoint create --region $REGION network admin http://$CONTROLLER_IP:9696


    #copy config files
    /bin/cp -rf $CURRENT_DIR/config/neutron/metadata_agent.ini /etc/neutron/
    /bin/cp -rf $CURRENT_DIR/config/neutron/neutron.conf /etc/neutron/
    /bin/cp -rf $CURRENT_DIR/config/neutron/dhcp_agent.ini /etc/neutron/
    /bin/cp -rf $CURRENT_DIR/config/neutron/l3_agent.ini /etc/neutron/
    /bin/cp -rf $CURRENT_DIR/config/neutron/linuxbridge_agent.ini /etc/neutron/plugins/ml2/
    /bin/cp -rf $CURRENT_DIR/config/neutron/ml2_conf.ini /etc/neutron/plugins/ml2/

    #create symlink for neutron
    ln -s /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugin.ini

    #populate neutron databse
    /bin/sh -c "neutron-db-manage --config-file /etc/neutron/neutron.conf \
    --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade head" neutron

    #restart the nova api
    systemctl restart openstack-nova-api.service

    #enabling services
    systemctl enable neutron-server.service
    systemctl enable neutron-linuxbridge-agent.service 
    systemctl enable neutron-dhcp-agent.service
    systemctl enable neutron-metadata-agent.service

    #enable l3 services
    systemctl enable neutron-l3-agent.service

    #starting services
    systemctl start neutron-server.service
    systemctl start neutron-linuxbridge-agent.service
    systemctl start neutron-dhcp-agent.service
    systemctl start neutron-metadata-agent.service


    #start l3 services
    systemctl start neutron-l3-agent.service

}


function configure_horizan() {

    #copying config file
    /bin/cp -rf $CURRENT_DIR/config/horizan/local_settings /etc/openstack-dashboard/

    #restarting services
    systemctl restart httpd.service
    systemctl restart memcached.service

}


function configure_cinder() {

    #create user and admin role for cinder
    openstack user create --domain default --password $OPENSTACK_PASSWORD cinder
    openstack role add --project service --user cinder admin

    #create cinder driver services
    openstack service create --name cinderv2 --description "OpenStack Block Storage" volumev2
    openstack service create --name cinderv3 --description "OpenStack Block Storage" volumev3

    #Create the Block Storage service API endpoints:
    openstack endpoint create --region $REGION volumev2 public http://$CONTROLLER_IP:8776/v2/%\(project_id\)s
    openstack endpoint create --region $REGION volumev2 internal http://$CONTROLLER_IP:8776/v2/%\(project_id\)s
    openstack endpoint create --region $REGION volumev2 admin http://$CONTROLLER_IP:8776/v2/%\(project_id\)s
    openstack endpoint create --region $REGION volumev3 public http://$CONTROLLER_IP:8776/v3/%\(project_id\)s
    openstack endpoint create --region $REGION volumev3 internal http://$CONTROLLER_IP:8776/v3/%\(project_id\)s
    openstack endpoint create --region $REGION volumev3 admin http://$CONTROLLER_IP:8776/v3/%\(project_id\)s
  
    #copy config  files
    /bin/cp -rf $CURRENT_DIR/config/cinder/cinder.conf /etc/cinder/cinder.conf

    #populate cinder database
    /bin/sh -c "cinder-manage db sync" cinder

    #restart nova api service
    systemctl restart openstack-nova-api.service

    #fix log permissions
    chown cinder:cinder /var/log/cinder/ *

    #enable cinder services
    systemctl enable openstack-cinder-api.service
    systemctl enable openstack-cinder-scheduler.service

    #start cinder services
    systemctl start openstack-cinder-scheduler.service
    systemctl start openstack-cinder-api.service 

}


function fix_permissions() {

    #fix log permissions
    chown glance:glance /var/log/glance/api.log

    #restart glance api
    systemctl restart openstack-glance-api.service

}


#write config
write_cofig_files

#install packages
install_services

#configure_os
configure_os

#configure memcached
configure_memcached

#bootstarp_openstack
configure_database
configure_rabbitmq

#configure keystone
configure_keystone

#configure glance
configure_glance

#configure nova
configure_nova

#configure neutron
configure_neutron

#installing horizan
configure_horizan

#installing cinder
configure_cinder

#post install permission fix
fix_permissions

#show openstack status
os-status
echo ""
echo ""
openstack endpoint list

#infomation 
echo
echo "Please use below info for compute or storage node install"
echo
echo "----------------------------------------------"
echo "Controller IP = "$CONTROLLER_IP
echo "Openstack Pass = "$OPENSTACK_PASSWORD 
echo "Datacenter region = " $REGION
echo "----------------------------------------------"
echo
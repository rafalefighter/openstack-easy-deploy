-- keystone database
CREATE DATABASE keystone /*\!40100 DEFAULT CHARACTER SET utf8 */;
GRANT ALL PRIVILEGES ON keystone.* TO 'root'@'localhost' IDENTIFIED BY 'SQLPASS';
GRANT ALL PRIVILEGES ON keystone.* TO 'root'@'%' IDENTIFIED BY 'SQLPASS';


-- glance database
CREATE DATABASE glance;
GRANT ALL PRIVILEGES ON glance.* TO 'root'@'localhost' IDENTIFIED BY 'SQLPASS';
GRANT ALL PRIVILEGES ON glance.* TO 'root'@'%' IDENTIFIED BY 'SQLPASS';

-- nova database
CREATE DATABASE nova_api;
CREATE DATABASE nova;
CREATE DATABASE nova_cell0;
CREATE DATABASE placement;
GRANT ALL PRIVILEGES ON nova_api.* TO 'root'@'localhost' IDENTIFIED BY 'SQLPASS';
GRANT ALL PRIVILEGES ON nova_api.* TO 'root'@'%' IDENTIFIED BY 'SQLPASS';
GRANT ALL PRIVILEGES ON nova.* TO 'root'@'localhost' IDENTIFIED BY 'SQLPASS';
GRANT ALL PRIVILEGES ON nova.* TO 'root'@'%' IDENTIFIED BY 'SQLPASS';
GRANT ALL PRIVILEGES ON nova_cell0.* TO 'root'@'localhost' IDENTIFIED BY 'SQLPASS';
GRANT ALL PRIVILEGES ON nova_cell0.* TO 'root'@'%' IDENTIFIED BY 'SQLPASS';
GRANT ALL PRIVILEGES ON placement.* TO 'root'@'localhost' IDENTIFIED BY 'SQLPASS';
GRANT ALL PRIVILEGES ON placement.* TO 'root'@'%' IDENTIFIED BY 'SQLPASS';

--neutron database
CREATE DATABASE neutron;
GRANT ALL PRIVILEGES ON neutron.* TO 'root'@'localhost' IDENTIFIED BY 'SQLPASS';
GRANT ALL PRIVILEGES ON neutron.* TO 'root'@'%' IDENTIFIED BY 'SQLPASS';

--cinder database
CREATE DATABASE cinder;
GRANT ALL PRIVILEGES ON cinder.* TO 'root'@'localhost' IDENTIFIED BY 'SQLPASS';
GRANT ALL PRIVILEGES ON cinder.* TO 'root'@'%' IDENTIFIED BY 'SQLPASS';

--this set of permissions only for testing. 
GRANT ALL ON *.* TO 'root'@'localhost';
GRANT ALL ON *.* TO 'root'@'%';

--set root password
SET PASSWORD FOR 'root'@'localhost' = PASSWORD('SQLPASS');

-- flush
FLUSH PRIVILEGES;


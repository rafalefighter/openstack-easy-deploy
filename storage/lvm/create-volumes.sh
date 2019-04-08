#!/bin/bash

pvcreate /dev/sdb
vgcreate cinder-volumes /dev/sdb
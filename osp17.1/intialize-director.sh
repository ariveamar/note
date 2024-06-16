#!/bin/bash
useradd stack
echo "stack ALL=(root) NOPASSWD:ALL" | tee -a /etc/sudoers.d/stack
chmod 0440 /etc/sudoers.d/stack
cat /etc/sudoers.d/stack
hostnamectl set-hostname director-tni.kemhan.go.id
subscription-manager register --username ts.xx --password='xx'
subscription-manager attach --pool=xx
subscription-manager release --set=9.2
echo "10.122.7.250 director.example.co.id" >> /etc/hosts
su - stack -c ' mkdir /home/stack/templates'
su - stack -c ' mkdir /home/stack/images'

sudo subscription-manager repos --disable=*
sudo subscription-manager repos --enable=rhel-9-for-x86_64-baseos-eus-rpms --enable=rhel-9-for-x86_64-appstream-eus-rpms --enable=rhel-9-for-x86_64-highavailability-eus-rpms --enable=openstack-17.1-for-rhel-9-x86_64-rpms --enable=fast-datapath-for-rhel-9-x86_64-rpms
yum -y install tmux
yum -y update
dnf install -y python3-tripleoclient
openstack tripleo container image prepare default --local-push-destination --output-env-file containers-prepare-parameter.yaml

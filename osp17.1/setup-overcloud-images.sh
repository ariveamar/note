#!/bin/bash
su - stack
source /home/stack//stackrc
sudo dnf install rhosp-director-images-uefi-x86_64 rhosp-director-images-ipa-x86_64
su - stack -c "mkdir /home/stack/images" 
su - stack -c "mkdir /home/stack/templates"
cd /home/stack/images
for i in /usr/share/rhosp-director-images/ironic-python-agent-latest.tar /usr/share/rhosp-director-images/overcloud-hardened-uefi-full-latest.tar; do tar -xvf $i; done
openstack overcloud image upload --image-path /home/stack/images/

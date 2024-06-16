#!/bin/bash
echo "Are your running this script using TMUX ? If not yet Please Use Tmux   Please Confirm !!!"
read inputs
echo $inputs
echo "Please edit containers-prepare-parameter.yaml & Add username & Password for access subscription Please Confirm !!!"
read inputs
echo $inputs
echo "Please edit undercloud.conf based on your network condition  Please Confirm !!!"
read inputs
echo $inputs
echo "Confirm Deploy Director !!!"
read inputs
echo $inputs
openstack undercloud install

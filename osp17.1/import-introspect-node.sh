#!/bin/bash

cat <<EOF>/home/stack/node.yaml
nodes:
  - name: "controller-01"
    ports:
      - address: "94:40:C9:D6:BC:AF"
    cpu: 4
    memory: 6144
    disk: 400
    arch: "x86_64"
    pm_type: "ipmi"
    pm_user: "admin"
    pm_password: "password*1"
    pm_addr: "10.122.1.5"
  - name: "controller-02"
    ports:
      - address: "94:40:C9:D6:BD:57"
    cpu: 4
    memory: 6144
    disk: 400
    arch: "x86_64"
    pm_type: "ipmi"
    pm_user: "admin"
    pm_password: "password*1"
    pm_addr: "10.122.1.6"
  - name: "controller-03"
    ports:
      - address: "94:40:C9:D6:BD:0F"
    cpu: 4
    memory: 6144
    disk: 400
    arch: "x86_64"
    pm_type: "ipmi"
    pm_user: "admin"
    pm_password: "password*1"
    pm_addr: "10.122.1.7"
  - name: "compute-01"
    ports:
      - address: "94:40:C9:D6:BD:23"
    cpu: 4
    memory: 6144
    disk: 400
    arch: "x86_64"
    pm_type: "ipmi"
    pm_user: "admin"
    pm_password: "password*1"
    pm_addr: "10.122.1.8"
  - name: "compute-02"
    ports:
      - address: "94:40:C9:D6:BD:03"
    cpu: 4
    memory: 6144
    disk: 400
    arch: "x86_64"
    pm_type: "ipmi"
    pm_user: "admin"
    pm_password: "password*1"
    pm_addr: "10.122.1.9"
  - name: "compute-03"
    ports:
      - address: "94:40:C9:D6:BD:47"
    cpu: 4
    memory: 6144
    disk: 400
    arch: "x86_64"
    pm_type: "ipmi"
    pm_user: "admin"
    pm_password: "password*1"
    pm_addr: "10.122.1.10"
  - name: "ceph-storage-01"
    ports:
      - address: "50:7c:6f:30:16:ee"
    cpu: 4
    memory: 6144
    disk: 400
    arch: "x86_64"
    pm_type: "ipmi"
    pm_user: "hpadmin"
    pm_password: "password*1"
    pm_addr: "10.122.1.11"
  - name: "ceph-storage-02"
    ports:
      - address: "50:7c:6f:2f:85:ce"
    cpu: 4
    memory: 6144
    disk: 400
    arch: "x86_64"
    pm_type: "ipmi"
    pm_user: "hpadmin"
    pm_password: "password*1"
    pm_addr: "10.122.1.12"
  - name: "ceph-storage-03"
    ports:
      - address: "50:7c:6f:2f:88:ae"
    cpu: 4
    memory: 6144
    disk: 400
    arch: "x86_64"
    pm_type: "ipmi"
    pm_user: "hpadmin"
    pm_password: "password*1"
    pm_addr: "10.122.1.13"
EOF
openstack overcloud node import /home/stack/node.yaml
openstack overcloud node introspect --all-manageable --provide


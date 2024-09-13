# 01: Deploy Operator
## Via Dashboard
- OpenShift Virtualization
- Kubernetes NMState Kubernetes

## OSP Director Operator
1. Create `osp-director-operator.yaml` and apply the defined CRDs
```yaml
ACCOUNT=arief_ivt
VERSION=1.0.0
podman image inspect quay.io/$ACCOUNT/osp-director-operator-index:$VERSION

cat<<EOF > osp-director-operator.yaml
# CatalogSource
---
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: osp-director-operator-index
  namespace: openstack
spec:
  sourceType: grpc
  image: quay.io/$ACCOUNT/osp-director-operator-index:$VERSION

# OperatorGroup
---
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: "osp-director-operator-group"
  namespace: openstack
spec:
  targetNamespaces:
  - openstack

# Subscription 
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: osp-director-operator-subscription
  namespace: openstack
spec:
  config:
    env:
    - name: WATCH_NAMESPACE
      value: openstack,openshift-machine-api,openshift-sriov-network-operator
  source: osp-director-operator-index
  sourceNamespace: openstack
  name: osp-director-operator
EOF

# Apply
oc apply -f osp-director-operator.yaml

# Verify the operator
oc get operators
```

# 02: Create Custom Image
## 02.1
1. Install virtctl
```bash
sudo subscription-manager repos --enable=cnv-4.12-for-rhel-8-x86_64-rpms
sudo dnf install -y kubevirt-virtctl
```

2. Install virt-customize
```bash
sudo dnf install -y libguestfs-tools-c
```

## 02.2
1. Download RHEL 9.2 QCOW2
Link: https://access.redhat.com/downloads

wget LINK -o rhel-9.2-x86_64-kvm.qcow2

3. Createa customize image script (This is for making predictable network interface names)
```bash
vim customize_image.sh
```

```bash
#!/bin/bash
set -eux

if [ -e /etc/kernel/cmdline ]; then
  echo 'Updating /etc/kernel/cmdline'
  sed -i -e "s/^\(.*\)net\.ifnames=0\s*\(.*\)/\1\2/" /etc/kernel/cmdline
fi

source /etc/default/grub
if grep -q "net.ifnames=0" <<< "$GRUB_CMDLINE_LINUX"; then
  echo 'Updating /etc/default/grub'
  sed -i -e "s/^\(GRUB_CMDLINE_LINUX=.*\)net\.ifnames=0\s*\(.*\)/\1\2/" /etc/default/grub
fi
if [ "$GRUB_ENABLE_BLSCFG" == "true" ]; then
  echo 'Fixing BLS entries'
  find /boot/loader/entries -type f -exec sed -i -e "s/^\(.*\)net\.ifnames=0\s*\(.*\)/\1\2/" {} \;
fi
# Always do this, on RHEL8 with BLS we still need it as the BLS entry uses $kernelopts from grubenv
echo 'Running grub2-mkconfig'
grub2-mkconfig -o /etc/grub2.cfg
grub2-mkconfig -o /etc/grub2-efi.cfg
rm -f /etc/sysconfig/network-scripts/ifcfg-ens* /etc/sysconfig/network-scripts/ifcfg-eth*
update-ca-trust extract
```

4. Run the custom script on the image and truncate the `/etc/machine-id` content
```bash
IMAGE_PATH=rhel-9.2-x86_64-kvm.qcow2
file $IMAGE_PATH
export LIBGUESTFS_BACKEND=direct
chmod 755 customize_image.sh
virt-customize -a $IMAGE_PATH --run customize_image.sh --truncate /etc/machine-id
```

5. Upload the image to OCP-V
```bash
IMAGE_NAME=openstack-base
IMAGE_SIZE=500Gi
IMAGE_PATH=rhel-9.2.qcow2
STORAGE_CLASS=ocs-storagecluster-ceph-rbd-virtualization
ACCESS_MODE=ReadWriteOnce

virtctl image-upload dv $IMAGE_NAME -n openstack \
  --size=$IMAGE_SIZE --image-path=$IMAGE_PATH \
  --storage-class $STORAGE_CLASS --access-mode $ACCESS_MODE --insecure
```

# 03: Create Git secret
0. Generate ssh key
```bash
ssh-keygen -f cbt
```

1. Create secret
```bash
oc create secret generic git-secret -n openstack \
 --from-file=git_ssh_identity=cbt \
 --from-literal=git_url=git@github.com:imtekid/osp-17.git
```

2. Verify secret
```bash
oc get secret/git-secret -n openstack
```

# 04: Create root login password
1. Generate password
```bash
echo -n "p@ssw0rdEXCELCOID" | base64
```

2. Create password secret
```bash
cat<<EOF > userpassword.yaml
apiVersion: v1
kind: Secret
metadata:
  name: userpassword
  namespace: openstack
data:
  NodeRootPassword: "cEBzc3cwcmRFWENFTENPSUQ="
EOF

oc create -f userpassword.yaml
```
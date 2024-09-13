# Create Bond1
1. Create Bond1 on NMState
```bash
cat<<EOF > ocp-bond1.yaml
apiVersion: nmstate.io/v1
kind: NodeNetworkConfigurationPolicy
metadata:
  name: ocp-bond1
spec:
  desiredState:
    interfaces:
    - name: bond1
      type: bond
      state: up
      link-aggregation:
        mode: 802.3ad
        options:
          miimon: '100'
        port:
        - ens2f0np0
        - ens3f1np1
      mtu: 9000
EOF
```

2. Create storage VLAN Interface
```bash
cat<<EOF > ocp-storage-mtu.yaml
apiVersion: nmstate.io/v1
kind: NodeNetworkConfigurationPolicy
metadata:
  name: osp-storage-vlan-4008
spec:
  desiredState:
    interfaces:
    - name: ens1f0np0
      mtu: 9000
      type: ethernet
      state: up
    - name: ens2f1np1
      mtu: 9000
      type: ethernet
      state: up
EOF

oc create -f ocp-storage-mtu.yaml

cat<<EOF > ocp-storage-vlan-4008.yaml
apiVersion: nmstate.io/v1
kind: NodeNetworkConfigurationPolicy
metadata:
  name: osp-storage-vlan-4008
spec:
  desiredState:
    interfaces:
    - name: ens1f0np0
      mtu: 9000
      type: ethernet
      state: up
    - name: ens2f1np1
      mtu: 9000
      type: ethernet
      state: up
    - name: ens1f0np0.4008
      mtu: 9000
      type: vlan
      state: up
      vlan:
        id: 4008
        base-iface: ens1f0np0
    - name: ens2f1np1.4008
      mtu: 9000
      type: vlan
      state: up
      vlan:
        id: 4008
        base-iface: ens2f1np1
EOF
oc create -f ocp-storage-vlan-4008.yaml
```

# Dummy Bridge
```yaml
apiVersion: nmstate.io/v1
kind: NodeNetworkConfigurationPolicy
metadata:
  name: br-osp-storage
spec:
  nodeSelector:
    kubernetes.io/hostname: "cbtcnb02nfvpct01.intra.excelcom.co.id"
  desiredState:
    interfaces:
    - name: br-osp-storage
      mtu: 9000
      description: Testing OSP-Storage 
      type: linux-bridge
      state: up
      bridge:
        options:
          stp:
            enabled: false
        port:
        - name: ens1f0np0.4008
        - name: ens2f1np1.4008
```

3. Create OpenStackNetConfig
- Check on the file
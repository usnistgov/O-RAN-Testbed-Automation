#!/bin/bash -x
#
################################################################################
#   Copyright (c) 2019 AT&T Intellectual Property.                             #
#   Copyright (c) 2022 Nokia.                                                  #
#                                                                              #
#   Licensed under the Apache License, Version 2.0 (the "License");            #
#   you may not use this file except in compliance with the License.           #
#   You may obtain a copy of the License at                                    #
#                                                                              #
#       http://www.apache.org/licenses/LICENSE-2.0                             #
#                                                                              #
#   Unless required by applicable law or agreed to in writing, software        #
#   distributed under the License is distributed on an "AS IS" BASIS,          #
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.   #
#   See the License for the specific language governing permissions and        #
#   limitations under the License.                                             #
################################################################################


usage() {
    echo "Usage: $0 [ -k <k8s version> -d <docker version> -e <helm version> -c <cni-version>" 1>&2;

    echo "k:    kubernetes version" 1>&2;
    echo "c:    kubernetes CNI  version" 1>&2;
    echo "d:    docker version" 1>&2;
    echo "e:    helm version" 1>&2;
    exit 1;
}


wait_for_pods_running () {
  NS="$2"
  CMD="kubectl get pods --all-namespaces "
  if [ "$NS" != "all-namespaces" ]; then
    CMD="kubectl get pods -n $2 "
  fi
  KEYWORD="Running"
  if [ "$#" == "3" ]; then
    KEYWORD="${3}.*Running"
  fi

  CMD2="$CMD | grep \"$KEYWORD\" | wc -l"
  NUMPODS=$(eval "$CMD2")
  echo "waiting for $NUMPODS/$1 pods running in namespace [$NS] with keyword [$KEYWORD]"
  while [  $NUMPODS -lt $1 ]; do
    sleep 5
    NUMPODS=$(eval "$CMD2")
    echo "> waiting for $NUMPODS/$1 pods running in namespace [$NS] with keyword [$KEYWORD]"
  done 
}


start_ipv6_if () {
  IPv6IF="$1"
  if ifconfig -a $IPv6IF; then
    echo "" >> /etc/network/interfaces.d/50-cloud-init.cfg
    echo "allow-hotplug ${IPv6IF}" >> /etc/network/interfaces.d/50-cloud-init.cfg
    echo "iface ${IPv6IF} inet6 auto" >> /etc/network/interfaces.d/50-cloud-init.cfg
    ifconfig ${IPv6IF} up
  fi
}

KUBEV="1.28.11"
KUBECNIV="0.7.5"
HELMV="3.14.4"
DOCKERV="20.10.21"

echo running ${0}
while getopts ":k:d:e:n:c" o; do
    case "${o}" in
    e)	
       HELMV=${OPTARG}
        ;;
    d)
       DOCKERV=${OPTARG}
        ;;
    k)
       KUBEV=${OPTARG}
       ;;
    c)
       KUBECNIV=${OPTARG}
       ;;
    *)
       usage
       ;;
    esac
done

if [[ ${HELMV} == 2.* ]]; then
  echo "helm 2 ("${HELMV}")not supported anymore" 
  exit -1
fi

set -x
export DEBIAN_FRONTEND=noninteractive
echo "$(hostname -I) $(hostname)" >> /etc/hosts
printenv

IPV6IF=""

rm -rf /opt/config
mkdir -p /opt/config
echo "" > /opt/config/docker_version.txt
echo "1.16.0" > /opt/config/k8s_version.txt
echo "0.7.5" > /opt/config/k8s_cni_version.txt
echo "3.14.4" > /opt/config/helm_version.txt
echo "$(hostname -I)" > /opt/config/host_private_ip_addr.txt
echo "$(curl ifconfig.co)" > /opt/config/k8s_mst_floating_ip_addr.txt
echo "$(hostname -I)" > /opt/config/k8s_mst_private_ip_addr.txt
echo "__mtu__" > /opt/config/mtu.txt
echo "__cinder_volume_id__" > /opt/config/cinder_volume_id.txt
echo "$(hostname)" > /opt/config/stack_name.txt

ISAUX='false'
if [[ $(cat /opt/config/stack_name.txt) == *aux* ]]; then
  ISAUX='true'
fi

modprobe -- ip_vs
modprobe -- ip_vs_rr
modprobe -- ip_vs_wrr
modprobe -- ip_vs_sh
modprobe -- nf_conntrack_ipv4
modprobe -- nf_conntrack_ipv6
modprobe -- nf_conntrack_proto_sctp

if [ ! -z "$IPV6IF" ]; then
  start_ipv6_if $IPV6IF
fi

SWAPFILES=$(grep swap /etc/fstab | sed '/^[ \t]*#/ d' | sed 's/[\t ]/ /g' | tr -s " " | cut -f1 -d' ')
if [ ! -z $SWAPFILES ]; then
  for SWAPFILE in $SWAPFILES
  do
    if [ ! -z $SWAPFILE ]; then
      echo "disabling swap file $SWAPFILE"
      if [[ $SWAPFILE == UUID* ]]; then
        UUID=$(echo $SWAPFILE | cut -f2 -d'=')
        swapoff -U $UUID
      else
        swapoff $SWAPFILE
      fi
      sed -i "\%$SWAPFILE%d" /etc/fstab
    fi
  done
fi


echo "### Docker version  = "${DOCKERV}
echo "### k8s version     = "${KUBEV}
echo "### helm version    = "${HELMV}
echo "### k8s cni version = "${KUBECNIV}

#KUBEVERSION="${KUBEV}-00"
CNIVERSION="${KUBECNIV}-00"
DOCKERVERSION="${DOCKERV}"

UBUNTU_RELEASE=$(lsb_release -r | sed 's/^[a-zA-Z:\t ]\+//g')
if [[ ${UBUNTU_RELEASE} == 16.* ]]; then
  echo "Installing on Ubuntu $UBUNTU_RELEASE (Xenial Xerus) host"
  if [ ! -z "${DOCKERV}" ]; then
    DOCKERVERSION="${DOCKERV}-0ubuntu1~16.04.5"
  fi
elif [[ ${UBUNTU_RELEASE} == 18.* ]]; then
  echo "Installing on Ubuntu $UBUNTU_RELEASE (Bionic Beaver)"
  if [ ! -z "${DOCKERV}" ]; then
    DOCKERVERSION="${DOCKERV}-0ubuntu1~18.04.4"
  fi
elif [[ ${UBUNTU_RELEASE} == 20.* ]]; then
  echo "Installing on Ubuntu $UBUNTU_RELEASE (Focal Fossal)"
  if [ ! -z "${DOCKERV}" ]; then
    DOCKERVERSION="${DOCKERV}-0ubuntu1~20.04.2"  # 20.10.21-0ubuntu1~20.04.2
  fi
else
  echo "Unsupported Ubuntu release ($UBUNTU_RELEASE) detected.  Exit."
fi

echo "docker version to use = "${DOCKERVERSION}

#curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
#echo 'deb http://apt.kubernetes.io/ kubernetes-xenial main' > /etc/apt/sources.list.d/kubernetes.list

mkdir /etc/apt/keyrings
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

mkdir -p /etc/apt/apt.conf.d
echo "APT::Acquire::Retries \"3\";" > /etc/apt/apt.conf.d/80-retries

apt-get update
RES=$(apt-get install -y  curl jq netcat make ipset moreutils 2>&1)
if [[ $RES == */var/lib/dpkg/lock* ]]; then
  echo "Fail to get dpkg lock.  Wait for any other package installation"
  echo "process to finish, then rerun this script"
  exit -1
fi

APTOPTS="--allow-downgrades --allow-change-held-packages --allow-unauthenticated --ignore-hold "

for PKG in kubeadm docker.io; do
  INSTALLED_VERSION=$(dpkg --list |grep ${PKG} |tr -s " " |cut -f3 -d ' ')
  if [ ! -z ${INSTALLED_VERSION} ]; then
    if [ "${PKG}" == "kubeadm" ]; then
      kubeadm reset -f
      rm -rf ~/.kube
      apt-get -y $APTOPTS remove kubeadm kubelet kubectl kubernetes-cni
    else
      apt-get -y $APTOPTS remove "${PKG}"
    fi
  fi
done
apt-get -y autoremove

if [ -z ${DOCKERVERSION} ]; then
  apt-get install -y $APTOPTS docker.io
else
  apt-get install -y $APTOPTS docker.io=${DOCKERVERSION}
fi
cat > /etc/docker/daemon.json <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF
mkdir -p /etc/systemd/system/docker.service.d
systemctl enable docker.service
systemctl daemon-reload
systemctl restart docker

if [ -z ${CNIVERSION} ]; then
  apt-get install -y $APTOPTS kubernetes-cni
else
  apt-get install -y $APTOPTS kubernetes-cni=${CNIVERSION}
fi

if [ -z ${KUBEVERSION} ]; then
  apt-get install -y $APTOPTS kubeadm kubelet kubectl
else
  apt-get install -y $APTOPTS kubeadm=${KUBEVERSION} kubelet=${KUBEVERSION} kubectl=${KUBEVERSION}
fi

apt-mark hold docker.io kubernetes-cni kubelet kubeadm kubectl


kubeadm config images pull --kubernetes-version=${KUBEV}


NODETYPE="master"
if [ "$NODETYPE" == "master" ]; then

  if [[ ${KUBEV} == 1.13.* ]]; then
    cat <<EOF >/root/config.yaml
apiVersion: kubeadm.k8s.io/v1alpha3
kubernetesVersion: v${KUBEV}
kind: ClusterConfiguration
apiServerExtraArgs:
  feature-gates: SCTPSupport=true
networking:
  dnsDomain: cluster.local
  podSubnet: 10.244.0.0/16
  serviceSubnet: 10.96.0.0/12
---
apiVersion: kubeproxy.config.k8s.io/v1alpha1
kind: KubeProxyConfiguration
mode: ipvs
EOF

  elif [[ ${KUBEV} == 1.14.* ]]; then
    cat <<EOF >/root/config.yaml
apiVersion: kubeadm.k8s.io/v1beta1
kubernetesVersion: v${KUBEV}
kind: ClusterConfiguration
apiServerExtraArgs:
  feature-gates: SCTPSupport=true
networking:
  dnsDomain: cluster.local
  podSubnet: 10.244.0.0/16
  serviceSubnet: 10.96.0.0/12
---
apiVersion: kubeproxy.config.k8s.io/v1alpha1
kind: KubeProxyConfiguration
mode: ipvs
EOF
  elif [[ ${KUBEV} == 1.15.* ]] || [[ ${KUBEV} == 1.16.* ]] || [[ ${KUBEV} == 1.18.* ]]; then
    cat <<EOF >/root/config.yaml
apiVersion: kubeadm.k8s.io/v1beta2
kubernetesVersion: v${KUBEV}
kind: ClusterConfiguration
apiServer:
  extraArgs:
    feature-gates: SCTPSupport=true
networking:
  dnsDomain: cluster.local
  podSubnet: 10.244.0.0/16
  serviceSubnet: 10.96.0.0/12
---
apiVersion: kubeproxy.config.k8s.io/v1alpha1
kind: KubeProxyConfiguration
mode: ipvs
EOF
  elif [[ ${KUBEV} == 1.28.* ]] ; then
    echo "Do Nothing for now."
    else
    echo "Unsupported Kubernetes version requested.  Bail."
    exit
  fi

  cat <<EOF > /root/rbac-config.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: tiller
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: tiller
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
  - kind: ServiceAccount
    name: tiller
    namespace: kube-system
EOF

if [[ ${KUBEV} == 1.28.11 ]]; then
  kubeadm init --pod-network-cidr=10.244.0.0/16
  mkdir -p /run/flannel
cat <<EOF > /run/flannel/subnet.env
FLANNEL_NETWORK=10.244.0.0/16
FLANNEL_SUBNET=10.244.0.1/24
FLANNEL_MTU=1450
FLANNEL_IPMASQ=true
EOF
else  
  kubeadm init --config /root/config.yaml
fi

  cd /root
  rm -rf .kube
  mkdir -p .kube
  cp -i /etc/kubernetes/admin.conf /root/.kube/config
  chown root:root /root/.kube/config
  export KUBECONFIG=/root/.kube/config
  echo "KUBECONFIG=${KUBECONFIG}" >> /etc/environment

  kubectl get pods --all-namespaces

if [[ ${KUBEV} == 1.28.11 ]]; then
  kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
else
  # we refer to version 0.18.1 because later versions use namespace kube-flannel instead of kube-system TODO
  kubectl apply -f "https://raw.githubusercontent.com/flannel-io/flannel/v0.18.1/Documentation/kube-flannel.yml"
fi

if [[ ${KUBEV} == 1.28.11 ]]; then
  wait_for_pods_running 7 kube-system
  wait_for_pods_running 1 kube-flannel
  kubectl taint nodes --all node-role.kubernetes.io/control-plane:NoSchedule-
else
  wait_for_pods_running 8 kube-system
  kubectl taint nodes --all node-role.kubernetes.io/master-
fi


  HELMV=$(cat /opt/config/helm_version.txt)
  HELMVERSION=${HELMV}
  if [ ! -e helm-v${HELMVERSION}-linux-amd64.tar.gz ]; then
    wget https://get.helm.sh/helm-v${HELMVERSION}-linux-amd64.tar.gz
  fi
  cd /root && rm -rf Helm && mkdir Helm && cd Helm
  tar -xvf ../helm-v${HELMVERSION}-linux-amd64.tar.gz
  mv linux-amd64/helm /usr/local/bin/helm

  cd /root

  rm -rf /root/.helm
#  if [[ ${KUBEV} == 1.16.* ]]; then
#    if [[ ${HELMVERSION} == 2.* ]]; then
#       helm init --service-account tiller --override spec.selector.matchLabels.'name'='tiller',spec.selector.matchLabels.'app'='helm' --output yaml > /tmp/helm-init.yaml
#       sed 's@apiVersion: extensions/v1beta1@apiVersion: apps/v1@' /tmp/helm-init.yaml > /tmp/helm-init-patched.yaml
#       kubectl apply -f /tmp/helm-init-patched.yaml
#    fi
#  else
#    if [[ ${HELMVERSION} == 2.* ]]; then
#       helm init --service-account tiller
#    fi
#  fi
#  if [[ ${HELMVERSION} == 2.* ]]; then
#     helm init -c
#     export HELM_HOME="$(pwd)/.helm"
#     echo "HELM_HOME=${HELM_HOME}" >> /etc/environment
#  fi

  while ! helm version; do
    echo "Waiting for Helm to be ready"
    sleep 15
  done

  echo "Preparing a master node (lower ID) for using local FS for PV"
  PV_NODE_NAME=$(kubectl get nodes |grep master | cut -f1 -d' ' | sort | head -1)
  kubectl label --overwrite nodes $PV_NODE_NAME local-storage=enable
  if [ "$PV_NODE_NAME" == "$(hostname)" ]; then
    mkdir -p /opt/data/dashboard-data
  fi

  echo "Done with master node setup"
fi


if [[ ! -z "" && ! -z "" ]]; then 
  echo " " >> /etc/hosts
fi
if [[ ! -z "" && ! -z "" ]]; then 
  echo " " >> /etc/hosts
fi
if [[ ! -z "" && ! -z "helm.ricinfra.local" ]]; then 
  echo " helm.ricinfra.local" >> /etc/hosts
fi

if [[ "1" -gt "100" ]]; then
  cat <<EOF >/etc/ca-certificates/update.d/helm.crt

EOF
fi

if [[ "1" -gt "100" ]]; then
  mkdir -p /etc/docker/certs.d/:
  cat <<EOF >/etc/docker/ca.crt

EOF
  cp /etc/docker/ca.crt /etc/docker/certs.d/:/ca.crt

  service docker restart
  systemctl enable docker.service
  docker login -u  -p  :
  docker pull :/whoami:0.0.1
fi

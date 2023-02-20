#!/bin/bash

dir="$HOME/k8s-files" && mkdir $dir
image_dir="$dir"/k8s-images/ && mkdir $image_dir
binary_dir="$dir"/k8s-bins/ && mkdir $binary_dir
config_dir="$dir"/k8s-configs/ && mkdir $config_dir
k8s_version="v1.24.10"
k8s_config_version="v0.4.0"
containerd_version="1.6.13"
runc_version="1.1.4"
cni_plugins_version="v1.1.1"
crictl_version="v1.24.2"
calico_hub="docker.io/calico/"
calico_version="v3.25.0" && mkdir "$image_dir"calico/

download="false"
k8s_images_pull="true"
calico_images_pull="false"

if [ $download == "true" ]
then
        echo "Binary Download section"
        wget -P $binary_dir "https://github.com/containernetworking/plugins/releases/download/${cni_plugins_version}/cni-plugins-linux-amd64-${cni_plugins_version}.tgz" 
        wget -P $binary_dir "https://github.com/kubernetes-sigs/cri-tools/releases/download/${crictl_version}/crictl-${crictl_version}-linux-amd64.tar.gz"
        wget -P $binary_dir "https://dl.k8s.io/release/${k8s_version}/bin/linux/amd64/kubeadm"
        wget -P $binary_dir "https://dl.k8s.io/release/${k8s_version}/bin/linux/amd64/kubelet"
        chmod +x $binary_dir/{kubeadm,kubelet}
        wget -P $config_dir "https://raw.githubusercontent.com/kubernetes/release/${k8s_config_version}/cmd/kubepkg/templates/latest/deb/kubelet/lib/systemd/system/kubelet.service"
        wget -P $config_dir "https://raw.githubusercontent.com/kubernetes/release/${k8s_config_version}/cmd/kubepkg/templates/latest/deb/kubeadm/10-kubeadm.conf" 
        wget -P $binary_dir "https://github.com/containerd/containerd/releases/download/v${containerd_version}/containerd-${containerd_version}-linux-amd64.tar.gz"
        wget -P $config_dir "https://raw.githubusercontent.com/containerd/containerd/main/containerd.service"
        wget -P $binary_dir "https://github.com/opencontainers/runc/releases/download/v${runc_version}/runc.amd64"
fi

k8s_hub=`"$binary_dir"/kubeadm --kubernetes-version $k8s_version config images list | grep apiserver | cut -d'/' -f1`
components_images=("`"$binary_dir"/kubeadm --kubernetes-version $k8s_version config images list | grep pause`"
                   "`"$binary_dir"/kubeadm --kubernetes-version $k8s_version config images list | grep etcd`"
                   "`"$binary_dir"/kubeadm --kubernetes-version $k8s_version config images list | grep coredns`"
                   )

k8s_images=('kube-apiserver'
        'kube-controller-manager'
        'kube-scheduler'
        'kube-proxy'
        )

#TODO
#find out images and tags of calico network
#edit tigera-operator file and set registry and path of images
calico_images=('pod2daemon-flexvol'
                'typha'
                'cni'
                'node'
                'kube-controllers'
                'apiserver'
                'node-driver-registrar'
                'csi'
        )
if [ $k8s_images_pull == "true" ]
then
echo Downloading k8s images...
for i in "${k8s_images[@]}"; do
  k8s_image_full="$k8s_hub"/"$i":"$k8s_version"
  k8s_image_save_name=$image_dir$i-"$k8s_version"
  docker pull $k8s_image_full
  docker save $k8s_image_full -o $k8s_image_save_name.tar
  docker rmi $k8s_image_full
done

echo Downloading components images...

for i in "${components_images[@]}"; do

  ck8s_image_name=`echo $i | awk -F "/" '{print $NF}' | cut -d':' -f1`
  ck8s_image_tag=`echo $i | awk -F "/" '{print $NF}' | cut -d':' -f2`
  ck8s_image_save_name=$image_dir$ck8s_image_name-$ck8s_image_tag
  docker pull $i
  docker save $i -o $ck8s_image_save_name.tar
  docker rmi $i
done
fi

if [ $calico_images_pull == "true" ]
then
echo Downloading calico images...
for i in "${calico_images[@]}"; do
  calico_image_full=$calico_hub$i:$calico_version
  calico_image_save_name="$image_dir"calico/$i-$calico_version
  docker pull $calico_image_full
  docker save $calico_image_full -o $calico_image_save_name.tar
  docker rmi $calico_image_full
done
fi


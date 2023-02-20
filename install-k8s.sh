k8s_files_dir="/home/support/k8s-files" && cd $k8s_files_dir
image_dir="$k8s_files_dir"/k8s-images/ 
binary_dir="$k8s_files_dir"/k8s-bins/ 
config_dir="$k8s_files_dir"/k8s-configs/ 
k8s_version="v1.24.10"
k8s_config_version="v0.4.0"
containerd_version="1.6.13"
runc_version="1.1.4"
cni_plugins_version="v1.1.1"
crictl_version="v1.24.2"
calico_version="v3.25.0"
ARCH="amd64"
BIN_DEST="/usr/local/bin" && sudo mkdir -p "$BIN_DEST"
CNI_DEST="/opt/cni/bin" && sudo mkdir -p "$CNI_DEST"
role="master"
sudo apt update
sudo apt upgrade -y
sudo apt install -y socat conntrack
sudo timedatectl set-timezone Asia/Tehran

sudo swapoff -a; sudo sed -i '/swap/d' /etc/fstab
sudo rm -f /swap.img

cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe br_netfilter && sudo modprobe overlay
cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF
sudo sysctl --system


echo -e "====installing cni"

sudo tar Cxzvf "$CNI_DEST" $binary_dir/"cni-plugins-linux-${ARCH}-${cni_plugins_version}.tgz" 

echo -e "====installing crictl"

sudo tar Cxzvf $BIN_DEST $binary_dir/"crictl-${crictl_version}-linux-${ARCH}.tar.gz"

echo -e "====installing kubeadm,kubelet"
sudo rsync -avzh $binary_dir/{kubeadm,kubelet} $BIN_DEST
sudo chown root:root $BIN_DEST/{kubeadm,kubelet}

echo -e "====service creation for kubelet"
sudo rsync -avzh $config_dir/kubelet.service /etc/systemd/system/
sudo sed -i "s:/usr/bin:${BIN_DEST}:g"  /etc/systemd/system/kubelet.service
sudo mkdir -p /etc/systemd/system/kubelet.service.d
sudo rsync -avzh $config_dir/10-kubeadm.conf /etc/systemd/system/kubelet.service.d/
sudo sed -i "s:/usr/bin:${BIN_DEST}:g"  /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
sudo chown -R root:root /etc/systemd/system/kubelet.*
sudo systemctl daemon-reload
sudo systemctl enable --now kubelet


echo -e "—------ install containerd —-------------------------------"
sudo tar Cxzvf /usr/local $binary_dir/containerd-${containerd_version}-linux-amd64.tar.gz
sudo rsync -avzh $config_dir/containerd.service /etc/systemd/system/
sudo mkdir /etc/containerd/
sudo systemctl daemon-reload
sudo systemctl enable --now containerd
sudo su -c "containerd config default > /etc/containerd/config.toml"
sudo sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/g' /etc/containerd/config.toml

pause_image="`"$binary_dir"/kubeadm --kubernetes-version $k8s_version config images list | grep pause`"
sudo sed -i  "s,sandbox_image =.*,sandbox_image = \""$pause_image"\"," /etc/containerd/config.toml

sudo systemctl restart containerd
echo -e "=====installing runc"
sudo install -m 755 $binary_dir/runc.amd64 /usr/local/sbin/runc



echo -e "=====import k8s images"
#TODO
#seperate images directories
if [ $role == "master" ]
then
    for i in "$image_dir"* ; do sudo ctr -n k8s.io images import $i ;done
    echo -e "=====import calico images"
    for i in "$image_dir"calico/* ; do sudo ctr -n k8s.io images import $i ;done
elif [ $role == "worker" ]
then
    pause_tag="`"$binary_dir"/kubeadm --kubernetes-version $k8s_version config images list | grep pause | cut -d':' -f2`"
    for i in pause-$pause_tag kube-proxy-$k8s_version ; do sudo ctr -n k8s.io images import "$image_dir"$i.tar ;done
    echo -e "=====import calico images"
    for i in cni node pod2daemon-flexvol csi node-driver-registrar ; do sudo ctr -n k8s.io images import $image_dir/calico/"$i"-"$calico_version".tar ;done
else 
    echo "specify role"
fi


###sudo kubeadm --kubernetes-version $k8s_version --apiserver-cert-extra-sans 127.0.0.1 init --pod-network-cidr=192.168.200.0/22
###sudo kubeadm token create --print-join-command
















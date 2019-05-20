#!/bin/bash
#ceph一键部署脚本
#for Centos7

#1.disable iptables&selinux

echo -n "正在配置iptables防火墙……"
systemctl stop firewalld > /dev/null 2>&1
systemctl disable firewalld  > /dev/null 2>&1
if [ $? -eq 0 ];then
echo -n "Iptables防火墙初始化完毕！"
fi

echo -n "正在关闭SELinux……"
setenforce 0 > /dev/null 2>&1
sed -i '/^SELINUX=/s/=.*/=disabled/' /etc/selinux/config
if [ $? -eq 0 ];then
        echo -n "SELinux初始化完毕！"
fi

#2.set hostname as ceph##

HOSTNAME=ceph
hostnamectl set-hostname ceph
IP=`ip route |grep src|grep metric|awk -F" " '{ print $9 }'`
echo "$IP $HOSTNAME" >>/etc/hosts

#3.install epel.repo#
yum install -y epel-release

cat <<EOF > /etc/yum.repos.d/ceph.repo
[Ceph]
name=Ceph packages for $basearch
baseurl=http://mirrors.163.com/ceph/rpm-jewel/el7/x86_64
enabled=1
gpgcheck=1
type=rpm-md
gpgkey=http://mirrors.163.com/ceph/keys/release.asc
priority=1

[Ceph-noarch]
name=Ceph noarch packages
baseurl=http://mirrors.163.com/ceph/rpm-jewel/el7/noarch
enabled=1
gpgcheck=1
type=rpm-md
gpgkey=http://mirrors.163.com/ceph/keys/release.asc
priority=1

[ceph-source]
name=Ceph source packages
baseurl=http://mirrors.163.com/ceph/rpm-jewel/el7/SRPMS
enabled=1
gpgcheck=1
type=rpm-md
gpgkey=http://mirrors.163.com/ceph/keys/release.asc
priority=1

EOF


#sed -e "s/^metalink=/#metalink=/g" \
#        -e "s/^mirrorlist=http/#mirrorlist=http/g" \
#        -e "s@^#baseurl=@baseurl=@g" \
#        -i /etc/yum.repos.d/*.repo

#echo 192.168.239.241 mirror.centos.org                  >> /etc/hosts
#echo 192.168.239.241 download.fedoraproject.org  >> /etc/hosts


#4.update system & install ceph-deploy##

yum update -y &&yum clean all &&yum -y install ceph-deploy

#5.设置本机密匙#
#ssh-keygen
#ssh-copy-id ceph

ssh-keygen -t rsa -P "" -f ~/.ssh/id_rsa
cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
#ssh -o stricthostkeychecking=no $HOSTNAME 

#####################################################################
#1.ceph服务初始化###
yum clean all &&yum -y install ceph-deploy

mkdir /etc/ceph &&cd /etc/ceph
ceph-deploy new ceph

#ceph-deploy new $HOSTNAME 
 
#2.修改配置文件 ###

cp ceph.conf ceph.conf.bak
#sed -i 's/cephx/none/g' /etc/ceph/ceph.conf
sed -i 's@^$@osd_pool_default_size = 1@g' ceph.conf
echo "mon_pg_warn_max_per_osd = 1000" >> /etc/ceph/ceph.conf


#3.安装ceph###

ceph-deploy install ceph

#4.创建monitor服务###
ceph-deploy mon create ceph
ceph-deploy  gatherkeys ceph
#4.osd###

#准备osd ###
mkfs.xfs  /dev/sdb
mkdir -p /var/local/osd
mount /dev/sdb  /var/local/osd/
chown -R ceph:ceph /var/local/osd*
#创建osd ###
ceph-deploy osd prepare ceph:/var/local/osd
#激活osd ###
ceph-deploy osd activate ceph:/var/local/osd
#chown -R ceph:ceph /var/local/osd* 有些同学可能会忘记配置目录权限引起激活osd失败 
#查看状态：###
ceph-deploy osd list ceph

#5.修改配置文件权限###

ceph-deploy admin ceph
chmod +r /etc/ceph/*

#6.部署mds服务###

ceph-deploy mds create ceph
ceph mds stat

#7.创建ceph文件系统###

ceph fs ls
ceph osd pool create cephfs_data 128
ceph osd pool create cephfs_metadata 128
ceph fs new cephfs cephfs_metadata cephfs_data
ceph fs ls

#8.挂载Ceph文件系统

mkdir /ceph
yum install -y ceph-fuse
IP=`ip route |grep src|grep metric|awk -F" " '{ print $9 }'`
ceph-fuse -m $IP:6789/ /ceph
df -Th

#9.查看ceph状态

#ceph monitor仲裁状态：ceph quorum_status  --format json-pretty 

ceph mon stat 
ceph osd stat 
#ceph osd tree（显示crush图）
ceph osd tree 
ceph pg stat 
#ceph auth list（集群的认证密码）




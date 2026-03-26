# 部署指引

实践使用4台虚拟机，运行CentOS系统，使用DNF（Dandified Yum）安装repo库内软件，需要网络适配器连接外网，如无外网环境需自行提前下载安装包。
本实践使用root用户身份部署软件，实际操作中请使用普通用户，使用root用户需**注意操作**对象与**权限**设置。

## 1. 部署前准备

部署使用到的软件列表如下：
| 名称 | 版本 | 获取方式 | 备注 |
|-------|---------|-------------|-------------|
| **CentOS** | Stream-8-20240603.0 | <https://vault.centos.org/8-stream/isos/x86_64/> | 可换用国内mirrors下载（如阿里云/清华源） |
| **Zabbix** | 7.4 | <https://www.zabbix.com/cn/download> | 按实际需要选择组件安装 |
| **nginx** | 1.14.1-9 | `dnf install zabbix-nginx-conf` | 无需单独下载，与zabbix一同安装 |
| **php** | 8.2 | `dnf module switch-to php:8.2` | 与zabbix一同安装 |
| **MySQL** | community-8.4.8 | <https://dev.mysql.com/downloads/repo/yum/> | 官网提供全容量rpm包下载 |
| **Consul** | 1.22.2 | <https://developer.hashicorp.com/consul/install#linux> | 官网提供二进制安装下载 |
| **Keepalived** | 2.1.5 | `dnf install keepalived` | 根据需要选择版本即可 |

部署使用的4台虚拟机设定如下：
| 名称 | IP地址 | 部署的软件 | 备注 |
|-------|---------|-------------|-------------|
| ZBXS1 | 10.0.1.41<br>10.0.8.41 | zabbix(server, agent), nginx, php, consul, keepalived | vip地址10.0.1.40，节点主 |
| ZBXS2 | 10.0.1.42<br>10.0.8.42 | zabbix(server, agent), nginx, php, keepalived | vip地址10.0.1.40，节点备 |
| ZBXDB1 | 10.0.1.51<br>10.0.8.51 | mysql, consul, keepalived | vip地址10.0.1.50，节点主 |
| ZBXDB2 | 10.0.1.52<br>10.0.8.52 | mysql, consul, keepalived | vip地址10.0.1.50，节点备 |

CPU与内存根据实际需求部署，此处选择CPU=1*2 内存=8GB。

每台虚拟机均部署两张网卡，网卡1用于4台虚拟机内联，网卡2用于外网安装软件。<br>
![网卡部署情况](/public/system/NetAdapter_Setting.png "网卡部署情况")

## 2. 操作系统部署

挂载CentOS ISO镜像后开机安装，无需添加新账户，系统安装完成后修改网卡配置固定IP，后续可通过SSH连接主机。推荐通过SSH密钥免密登录。在SSH客户端执行`ssh-keygen -t rsa`生成公私钥，将公钥内容复制到服务器端`用户目录/.ssh/authorized_keys`文件中，登录时使用命令`ssh 用户@IP地址`即可。

## 3.配置yum源

此处使用CentOS镜像挂载系统作为yum源，为加快dnf包管理速度，将不需要的repo源进行备份，启用Media repo源，命令如下：

```
mkdir /etc/yum.repos.d/repo_bak   #将不需要repo源备份至repo_bak文件夹中
mv /etc/yum.repos.d/*.repo /etc/yum.repos.d/repo_bak/
mv /etc/yum.repos.d/repo_bak/CentOS-Stream-Media.repo /etc/yum.repos.d/CentOS-Stream-Media.repo  #移回我们需要的Media repo源
vi /etc/yum.repos.d/CentOS-Stream-Media.repo

# 将文件内的enabled选项从0不启用改为1启用
[media-baseos]
name=CentOS Stream $releasever - Media - BaseOS
baseurl=file:///media/CentOS/BaseOS
        file:///media/cdrom/BaseOS
        file:///media/cdrecorder/BaseOS
gpgcheck=1
enabled=1                                # <------ 0改为1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-centosofficial

[media-appstream]
name=CentOS Stream $releasever - Media - AppStream
baseurl=file:///media/CentOS/AppStream
        file:///media/cdrom/AppStream
        file:///media/cdrecorder/AppStream
gpgcheck=1
enabled=1                                # <------ 0改为1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-centosofficial
```
然后对应baseurl内第一条建立对应文件夹并进行镜像挂载
```
mkdir /media/cdrom/
mount /dev/cdrom /media/cdrom/
# ls检查是否挂载成功
[root@zbxs1 ~]# ls -l /media/CentOS/
total 50
dr-xr-xr-x 4 root root  2048 Jun  3  2024 AppStream
dr-xr-xr-x 4 root root  2048 Jun  3  2024 BaseOS
dr-xr-xr-x 3 root root  2048 Jun  3  2024 EFI
-r--r--r-- 1 root root   298 Jun  3  2024 EULA
-r--r--r-- 1 root root   741 Jun  3  2024 extra_files.json
-r--r--r-- 1 root root 18092 Jun  3  2024 GPL
dr-xr-xr-x 3 root root  2048 Jun  3  2024 images
dr-xr-xr-x 2 root root  2048 Jun  3  2024 isolinux
-r--r--r-- 1 root root 18092 Sep 14  2021 LICENSE
-r--r--r-- 1 root root    88 Jun  3  2024 media.repo
-r--r--r-- 1 root root  1542 Jun  3  2024 TRANS.TBL
```

## 4.Zabbix安装
- *添加Zabbix仓库源*
  
  连接到Zabbix两台服务器，执行命令
  ```
  dnf config-manager --add-repo https://repo.zabbix.com/zabbix/7.4/release/rhel/8/noarch/zabbix-release-latest-7.4.el8.noarch.rpm
  dnf clean all    # 清理repo缓存
  ```
  repo添加完成后检查仓库目录应可以看到Zabbix repo
  ```
  [root@zbxs1 ~]# ls -l /etc/yum.repos.d/zabbix*
  -rw-r--r-- 1 root root  225 Mar 22 05:30 zabbix-release.repo
  -rw-r--r-- 1 root root  717 Mar 22 05:38 zabbix.repo
  -rw-r--r-- 1 root root  231 Mar 22 05:30 zabbix-third-party.repo
  -rw-r--r-- 1 root root  429 Mar 22 05:30 zabbix-tools.repo
  -rw-r--r-- 1 root root  712 Mar 22 05:30 zabbix-unstable.repo
  ```
- *安装Zabbix*
  
  执行命令
  ```
  dnf module switch-to php:8.2        # 切换php模块至zabbix需求版本
  dnf install zabbix-server-mysql zabbix-web-mysql zabbix-nginx-conf zabbix-sql-scripts zabbix-selinux-policy zabbix-agent
  ```
  安装完成后跳过安装数据库等步骤，这里选择先将Zabbix配置文件写好
  
  编辑`/etc/zabbix/zabbix_server.conf`配置文件，找到以下配置进行修改
  ```
  # 数据库配置
  DBHost=10.0.1.50        # 如遇到连接数据库问题，可将此处修改为实际主库地址10.0.1.51，待解决连接问题后再改回虚拟IP地址10.0.1.50
  DBName=zabbix           # DBName与DBUser默认为zabbix，检查是否值正确即可
  DBUser=zabbix
  DBPassword=zabbix       # DBPassword应按实际情况修改，此处使用zabbix作为密码
  DBPort=3306             # DBPort端口，默认3306，根据实际情况指定
  DBTLSConnect=required   # 由于MySQL在8.4版本要求数据库连接安全性较高，此处建议将TLS连接设定为required，如有需要应当指定CAFile/CertFile/KeyFile

  # HA配置
  HANodeName=Zabbix_Node01      # HA集群配置节点名，应集群全局唯一
  NodeAddress=10.0.1.41:10051   # 此处指定内网实际ip与监听端口，则ListenPort可不用设置
  ```
  配置文件参考详见本仓库/zabbix/zabbix_server.conf

  编辑`/etc/zabbix/zabbix_agentd.conf`配置文件，找到以下配置进行修改
  ```
  Server=10.0.1.41, 10.0.1.42   # 如填写VIP地址理论上亦可
  ```
  配置文件参考详见本仓库/zabbix/zabbix_agentd.conf
  
- *配置nginx*
  
  编辑配置文件/etc/nginx/conf.d/zabbix.conf，取消'listen' and 'server_name'行注释，按需配置值
  ```
  listen          8000;             # zabbix web访问端口        
  server_name     example.com;      # 服务器名
  ```
  配置文件参考详见本仓库/zabbix/nginx/zabbix.conf

  **此处暂不启动zabbix相关服务，待后续软件安装完毕后再启动**

5. MySQL安装
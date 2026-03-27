## 操作系统部署

挂载CentOS ISO镜像后开机安装。

各安装选项应按需设定，此处根据后续未用到GUI，软件选择**Minimal Install** , 加选**Development Tools**/**Security Tools**/**System Tools**，分区仅作安装演示，网卡A手动指定ip地址用于内网通信，网卡B使用DHCP连接外网即可，用户选择不创建。KDump建议开启，会占用一些内存空间但在系统崩溃时方便运维人员排查问题。

Installation Summary<br>
![Installation Summary](/public/centos/install_summary.png "Installation Summary")
<br>
Software Selection<br>
![Software Selection](/public/centos/software_selection.png "Software Selection")
<br>
Disk Partition<br>
![Disk Partition](/public/centos/partition.png "Disk Partition")
<br>
Network Settings<br>
![Network Settings](/public/centos/network.png "Network Settings")
<br>
系统安装完成，断开ISO镜像，系统启动后登录命令行检查IP等网络配置，测试是否内外网连通，CentOS 8可使用nmtui工具管理网络连接与IP配置,注意是否开启网卡自动连接。

测试SSH连接主机。
```
C:\Users\user>ssh root@10.0.1.41
The authenticity of host '10.0.1.41 (10.0.1.41)' can't be established.
ED25519 key fingerprint is SHA256:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx.
This key is not known by any other names.
Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
Warning: Permanently added '10.0.1.41' (ED25519) to the list of known hosts.
root@10.0.1.41's password:
Last login: Fri Mar 27 16:55:47 2026
[root@zbxs1 ~]# exit
logout
Connection to 10.0.1.41 closed.

C:\Users\user>
```

## SSH免密登录

推荐通过SSH密钥免密登录。在SSH客户端执行`ssh-keygen -t rsa`生成公私钥，将公钥内容复制到服务器端`用户目录/.ssh/authorized_keys`文件中，登录时使用命令`ssh 用户@IP地址`即可。
```
# 在SSH客户端方执行
C:\Users\user>ssh-keygen -t rsa
Generating public/private rsa key pair.
Enter file in which to save the key (C:\Users\user/.ssh/id_rsa):
Created directory 'C:\\Users\\user/.ssh'.
Enter passphrase (empty for no passphrase):
Enter same passphrase again:
Your identification has been saved in C:\Users\user/.ssh/id_rsa
Your public key has been saved in C:\Users\user/.ssh/id_rsa.pub
The key fingerprint is:
SHA256:xxxxxxxxxxxxxxxxxxx user@DESKTOP
The key's randomart image is:
+---[RSA 3072]----+
|                 |
|                 |
|      the        |
|     key 's      |
|    randomart    |
|      image      |
|      seems      |
|      like       |
|      this       |
+----[SHA256]-----+
# 复制id_rsa.pub公钥到服务器，此处演示复制公钥到对方服务器的root用户下
C:\Users\user>scp .ssh\id_rsa.pub root@10.0.1.41:/root/.ssh/authorized_keys
root@10.0.1.41's password:
id_rsa.pub                                   100%  577     0.6KB/s   00:00

C:\Users\user>
# 测试免密登录服务器，SSH连接不提示输入密码
C:\Users\user>ssh root@10.0.1.41
Last login: Fri Mar 27 17:51:05 2026 from 10.0.1.30
[root@zbxs1 ~]# exit
logout
Connection to 10.0.1.41 closed.

C:\Users\user>
```

**注意**：<br>
4台服务器间也应根据使用情况互相配置SSH免密登录信任，后续配置方式不过多赘述。

## 配置yum源

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
mkdir /media/CentOS/
mount /dev/cdrom /media/CentOS/
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

<p style="display: flex; justify-content: space-between;"><a href="00-Pre-deployment.md"><strong>&lt;--回到00-Pre-deployment.md</strong></a><a href="02-Zabbix_installation.md"><strong>到下一页02-Zabbix_installation.md--&gt;</strong></a></p>
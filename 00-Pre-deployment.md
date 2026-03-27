## 部署前准备

实践使用4台虚拟机，运行CentOS系统，使用DNF（Dandified Yum）安装repo库内软件，需要网络适配器连接外网，如无外网环境需自行提前下载安装包。
本实践使用root用户身份部署软件，实际操作中请使用普通用户，使用root用户需**注意操作**对象与**权限**设置。

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
<br>
<p style="display: flex; justify-content: space-between;"><a href="Readme.md"><strong>&lt;--回到Readme.md</strong></a><a href="01-System_env_setup.md"><strong>到下一页01-System_env_setup.md--&gt;</strong></a></p>
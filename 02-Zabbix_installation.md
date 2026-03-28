## Zabbix安装
- *添加Zabbix 7.4仓库源*
  
  连接到Zabbix两台服务器，执行命令
  ```
  dnf install -y https://repo.zabbix.com/zabbix/7.4/release/rhel/8/noarch/zabbix-release-latest-7.4.el8.noarch.rpm    #不添加 -y 参数会提示是否安装，按提示输入y确认安装
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
- *安装Zabbix 7.4*
  
  执行命令
  ```
  dnf module switch-to php:8.2        # 切换php模块至zabbix需求版本
  dnf install zabbix-server-mysql zabbix-web-mysql zabbix-nginx-conf zabbix-sql-scripts zabbix-selinux-policy zabbix-agent
  ```

  检查安装结果
  ```
  # 检查php模块版本，[e]应处于8.2，确认已切换至8.2版本
  [root@zbxs1 ~]# dnf module list php
  Last metadata expiration check: 0:00:24 ago on Fri 27 Mar 2026 06:59:14 PM CST.
  CentOS Stream 8 - Media - AppStream
  Name                Stream                 Profiles                                 Summary
  php                 7.2 [d]                common [d], devel, minimal               PHP scripting language
  php                 7.3                    common [d], devel, minimal               PHP scripting language
  php                 7.4                    common [d], devel, minimal               PHP scripting language
  php                 8.0                    common [d], devel, minimal               PHP scripting language
  php                 8.2 [e]                common [d], devel, minimal               PHP scripting language

  Hint: [d]efault, [e]nabled, [x]disabled, [i]nstalled

  # 检查zabbix相关软件包是否均已安装成功
  [root@zbxs1 ~]# dnf list installed zabbix*
  Installed Packages
  zabbix-agent.x86_64                                       7.4.8-release1.el8                               @zabbix
  zabbix-nginx-conf.noarch                                  7.4.8-release1.el8                               @zabbix
  zabbix-release.noarch                                     7.4-3.el8                                        @@commandline
  zabbix-selinux-policy.x86_64                              7.4.8-release1.el8                               @zabbix
  zabbix-server-mysql.x86_64                                7.4.8-release1.el8                               @zabbix
  zabbix-sql-scripts.noarch                                 7.4.8-release1.el8                               @zabbix
  zabbix-web.noarch                                         7.4.8-release1.el8                               @zabbix
  zabbix-web-deps.noarch                                    7.4.8-release1.el8                               @zabbix
  zabbix-web-mysql.noarch                                   7.4.8-release1.el8                               @zabbix
  ```

- *配置Zabbix Server与Agent*

  安装完成后跳过安装数据库等步骤，这里选择先将Zabbix配置文件写好
  
  编辑`/etc/zabbix/zabbix_server.conf`配置文件，找到以下配置位置进行修改
  ```
  # 数据库配置
  DBHost=10.0.1.50        # 如遇到连接数据库问题，可将此处修改为实际源库地址10.0.1.51，待解决连接问题后再改回虚拟IP地址10.0.1.50
  DBName=zabbix           # DBName与DBUser默认为zabbix，检查是否值正确即可
  DBUser=zabbix
  DBPassword=zabbix       # DBPassword应按实际情况修改，此处使用zabbix作为密码
  DBPort=3306             # DBPort端口，默认3306，根据实际情况指定
  DBTLSConnect=required   # 由于MySQL在8.4版本要求数据库连接安全性较高，此处建议将TLS连接设定为required，如有需要应当指定CAFile/CertFile/KeyFile

  # HA配置
  HANodeName=Zabbix_Node01      # HA集群配置节点名，应集群全局唯一
  NodeAddress=10.0.1.41:10051   # 此处指定内网实际ip与监听端口，则ListenPort可不用设置
  ```
  配置文件参考详见本仓库[server-conf](/zabbix/zabbix_server.conf)

  编辑`/etc/zabbix/zabbix_agentd.conf`配置文件，找到以下配置进行修改
  ```
  Server=10.0.1.41, 10.0.1.42   # 如填写VIP地址理论上亦可
  ```
  配置文件参考详见本仓库[agentd-conf](/zabbix/zabbix_agentd.conf)
  
- *配置nginx*
  
  编辑配置文件/etc/nginx/conf.d/zabbix.conf，取消'listen' and 'server_name'行注释，按需配置值
  ```
  listen          8000;             # zabbix web访问端口        
  server_name     example.com;      # 服务器名
  ```
  配置文件参考详见本仓库[nginx-conf](/zabbix/nginx/zabbix.conf)

  **此处暂不启动zabbix相关服务，待后续软件安装完毕后再启动**
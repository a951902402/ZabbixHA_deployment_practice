## MySQL安装
安装方式为使用官方提供的仓库安装，官方同时也提供了全容量的rpm包与单一rpm包下载，安装时应当考虑软件依赖关系按顺序安装。
- *添加MySQL仓库源*

    首先添加MySQL仓库源，执行以下命令
    ```
    # 官方未直接在文档内提供repo rpm包链接，请先确认链接有效性后再执行安装命令
    dnf install -y https://dev.mysql.com/get/mysql84-community-release-el8-2.noarch.rpm
    dnf clean all
    ```
    repo添加完成后检查仓库目录应可以看到MySQL repo
    ```
    [root@zbxdb1 ~]# ls -l /etc/yum.repos.d/mysql*
    -rw-r--r--. 1 root root 3191 Jan  7 19:20 /etc/yum.repos.d/mysql-community-debuginfo.repo
    -rw-r--r--. 1 root root 2871 Jan  7 19:20 /etc/yum.repos.d/mysql-community.repo
    -rw-r--r--. 1 root root 2991 Jan  7 19:20 /etc/yum.repos.d/mysql-community-source.repo
    ```
- *安装MySQL 8.4*
    
    由于CentOS 8默认启用MySQL 8.0模块，为安装8.4版本，需要先行禁用CentOS 8自带的MySQL模块，然后使用官方提供的仓库安装MySQL 8.4，先查询启用的MySQL模块
    ```
    [root@zbxdb1 ~]# dnf module list mysql
    Last metadata expiration check: 0:08:15 ago on Fri 27 Mar 2026 08:33:48 PM CST.
    CentOS Stream 8 - Media - AppStream
    Name                     Stream                     Profiles                              Summary
    mysql                    8.0 [d]                    client, server [d]                    MySQL Module

    Hint: [d]efault, [e]nabled, [x]disabled, [i]nstalled
    ```
    可以看到8.0模块处于default状态，执行以下命令禁用8.0模块
    ```
    [root@zbxdb1 ~]# dnf module disable mysql -y
    Last metadata expiration check: 0:15:30 ago on Fri 27 Mar 2026 08:33:48 PM CST.
    Dependencies resolved.
    ========================================================================================================================
    Package                     Architecture               Version                       Repository                   Size
    ========================================================================================================================
    Disabling modules:
    mysql

    Transaction Summary
    ========================================================================================================================

    Complete!
    ```
    再次检查MySQL模块状态，确认已禁用
    ```
    [root@zbxdb1 ~]# dnf module list mysql
    Last metadata expiration check: 0:17:17 ago on Fri 27 Mar 2026 08:33:48 PM CST.
    CentOS Stream 8 - Media - AppStream
    Name                    Stream                       Profiles                             Summary
    mysql                   8.0 [d][x]                   client, server [d]                   MySQL Module

    Hint: [d]efault, [e]nabled, [x]disabled, [i]nstalled
    ```
    安装MySQL 8.4版本，相关依赖client/client-plugins/common/icu-data-files/libs会一并安装
    ```
    dnf install mysql-community-server -y
    ```
    安装完成后检查安装结果
    ```
    [root@zbxdb1 ~]# dnf list installed mysql-community*
    Installed Packages
    mysql-community-client.x86_64                                    8.4.8-1.el8                            @mysql-8.4-lts-community
    mysql-community-client-plugins.x86_64                            8.4.8-1.el8                            @mysql-8.4-lts-community
    mysql-community-common.x86_64                                    8.4.8-1.el8                            @mysql-8.4-lts-community
    mysql-community-icu-data-files.x86_64                            8.4.8-1.el8                            @mysql-8.4-lts-community
    mysql-community-libs.x86_64                                      8.4.8-1.el8                            @mysql-8.4-lts-community
    mysql-community-server.x86_64                                    8.4.8-1.el8                            @mysql-8.4-lts-community
    ``` 

- *启动mysql服务与基础配置*

    安装完成后查看是否自动创建mysql用户
    ```
    cat /etc/passwd | grep mysql
    ```
    如未看到mysql用户，则需要手动添加mysql用户，命令如下
    ```
    groupadd mysql
    useradd -r -g mysql -s /bin/false mysql
    ```
    打开`/etc/my.cnf`配置文件，添加以下配置
    ``` 
    [mysqld]
    user = mysql
    port = 3306          # 如有需要可以修改监听端口
    ```
    配置mysql服务运行的系统用户为刚才添加的mysql用户，避免使用root用户运行数据库服务带来的安全风险

    配置文件参考详见
    
    Source:[my.cnf.origin](/mysql/source/my.cnf.origin)，此为配置源副本复制前的配置文件。<br>
    Replica:[my.cnf.origin](/mysql/replica/my.cnf.origin)，此为配置源副本复制前的配置文件。

    现在启动mysql服务并设置开机自启
    ```
    systemctl start mysqld
    systemctl enable mysqld
    ```
    检查mysql服务状态
    ```
    [root@zbxdb1 ~]# systemctl status mysqld
    ● mysqld.service - MySQL Server
    Loaded: loaded (/usr/lib/systemd/system/mysqld.service; enabled; vendor preset: disabled)
    Active: active (running) since Fri 2026-03-27 21:27:45 CST; 2min 49s ago
        Docs: man:mysqld(8)
            http://dev.mysql.com/doc/refman/en/using-systemd.html
    Main PID: 2470 (mysqld)
    Status: "Server is operational"
        Tasks: 34 (limit: 4473)
    Memory: 424.3M
    CGroup: /system.slice/mysqld.service
            └─2470 /usr/sbin/mysqld

    Mar 27 21:27:40 zbxdb1 systemd[1]: Starting MySQL Server...
    Mar 27 21:27:45 zbxdb1 systemd[1]: Started MySQL Server.
    ```
    服务启动后，mysql会自动创建用户'root'@'localhost'，并在`/var/log/mysqld.log`日志文件中记录初始root用户的随机密码，使用以下命令查看日志获取初始密码
    ```
    grep 'temporary password' /var/log/mysqld.log
    ```
    使用获取的初始密码登录mysql，强制修改密码后即可正常使用
    ```
    [root@zbxdb1 ~]# mysql -uroot -p
    Enter password:
    Welcome to the MySQL monitor.  Commands end with ; or \g.
    Your MySQL connection id is 8
    Server version: 8.4.8

    Copyright (c) 2000, 2026, Oracle and/or its affiliates.

    Oracle is a registered trademark of Oracle Corporation and/or its
    affiliates. Other names may be trademarks of their respective
    owners.

    Type 'help;' or '\h' for help. Type '\c' to clear the current input statement.

    mysql> ALTER USER 'root'@'localhost' IDENTIFIED BY 'MyNewPass4!';
    Query OK, 0 rows affected (0.01 sec)

    mysql>
    ```
    MySQL默认启用了validate_password插件，可以查看并调整当前密码策略配置，实际应考虑使用情况对应调整，以下语句仅供参考
    ```
    # 查看当前密码策略配置
    mysql> SHOW VARIABLES LIKE 'validate_password%';
    # 调整密码策略配置语句示例
    mysql> SET GLOBAL validate_password.policy=LOW;
    mysql> SET GLOBAL validate_password.length=4;
    ```
- MySQL SSL连接(*可选*)

    MySQL 8.4版本可以在用户登录与源副本复制数据传输过程等场景下启用SSL连接
    
    以下语句可以看到默认SSL状态与生成的证书信息
    ```
    mysql> SHOW VARIABLES LIKE '%ssl%';
    +-------------------------------------+-----------------+
    | Variable_name                       | Value           |
    +-------------------------------------+-----------------+
    | admin_ssl_ca                        |                 |
    | admin_ssl_capath                    |                 |
    | admin_ssl_cert                      |                 |
    | admin_ssl_cipher                    |                 |
    | admin_ssl_crl                       |                 |
    | admin_ssl_crlpath                   |                 |
    | admin_ssl_key                       |                 |
    | mysqlx_ssl_ca                       |                 |
    | mysqlx_ssl_capath                   |                 |
    | mysqlx_ssl_cert                     |                 |
    | mysqlx_ssl_cipher                   |                 |
    | mysqlx_ssl_crl                      |                 |
    | mysqlx_ssl_crlpath                  |                 |
    | mysqlx_ssl_key                      |                 |
    | performance_schema_show_processlist | OFF             |
    | ssl_ca                              | ca.pem          |
    | ssl_capath                          |                 |
    | ssl_cert                            | server-cert.pem |
    | ssl_cipher                          |                 |
    | ssl_crl                             |                 |
    | ssl_crlpath                         |                 |
    | ssl_fips_mode                       | OFF             |
    | ssl_key                             | server-key.pem  |
    | ssl_session_cache_mode              | ON              |
    | ssl_session_cache_timeout           | 300             |
    +-------------------------------------+-----------------+
    25 rows in set (0.00 sec)
    ```
    证书默认生成在`/var/lib/mysql`目录下，可以根据实际需要自行生成证书替换默认证书，提高生产环境的安全性。

    证书可以在数据库配置文件中指定，打开`/etc/my.cnf`配置文件，添加以下配置
    ```
    [mysqld]
    ssl_ca = ca.pem
    ssl_cert = server-cert.pem
    ssl_key = server-key.pem
    ```
    配置中不指定路径，则会默认读取`/var/lib/mysql`目录下的证书文件。配置完成后执行`systemctl restart mysqld`重启mysql服务使配置生效
    
    配置文件参考详见
    
    Source:[my.cnf](/mysql/source/my.cnf)，位于#SSL pem configuration。<br>
    Replica:[my.cnf](/mysql/replica/my.cnf)，位于#SSL pem configuration。

    为用户登录过程中强制SSL连接，可以在添加或更改用户时添加require SSL选项，例如
    ```
    mysql> CREATE USER 'need_ssl_user'@'%' IDENTIFIED BY 'password' REQUIRE SSL;
    ```
    当启用要求SSL后，用户登录时会强制使用SSL连接，否则会提示`ERROR 1045 (28000): Access denied for user 'need_ssl_user'@'%' (using password: YES)`，需要指定`--ssl-mode=require`选项才能成功登录，在登录后可以查看当前连接加密方式。
    ```
    mysql> SHOW SESSION STATUS LIKE 'Ssl_cipher';
    +---------------+------------------------+
    | Variable_name | Value                  |
    +---------------+------------------------+
    | Ssl_cipher    | TLS_AES_128_GCM_SHA256 |
    +---------------+------------------------+
    1 row in set (0.01 sec)
    ```

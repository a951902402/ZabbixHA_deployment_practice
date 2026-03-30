## Zabbix配置

前文我们已经安装过Zabbix的组件，现在需要创建和导入Zabbix的数据库用户/表结构等数据

- *Zabbix的MySQL数据库配置*

    登录到MySQL数据库，运行以下代码，其中<br>
    1. 用户zabbix的ip范围应更改为你自己的zabbix所在网段或所在ip，使得你的zabbix-server能够访问数据库，此处写为10.0.1.X网段。
    2. 用户zabbix按照在`zabbix_server.conf`中`DBPassword`项设定值填写，前文设定值为zabbix。
    ```
    mysql> create database zabbix character set utf8mb4 collate utf8mb4_bin;
    mysql> create user 'zabbix'@'10.0.1.%' identified by 'zabbix';
    mysql> grant all privileges on zabbix.* to 'zabbix'@'10.0.1.%';
    mysql> set global log_bin_trust_function_creators = 1;
    ```

    登录到Zabbix服务器，找到zabbix数据库导入脚本，将脚本压缩包传到MySQL服务器（存放地址无要求），并在MySQL服务器上执行导入脚本
    ```
    # Zabbix上
    scp -p /usr/share/zabbix/sql-scripts/mysql/server.sql.gz root@10.0.1.50:/root/

    # MySQL上
    zcat server.sql.gz | mysql --default-character-set=utf8mb4 -uzabbix -p zabbix
    Enter password:               # 此处输入MySQL用户zabbix的密码
    ```
    执行结束后登录MySQL源副本库查看是否均有zabbix库，如数据库复制正常工作，则在副本库上应当看到我们在主库执行插入的数据均已被同步
    ```
    mysql> SHOW DATABASES;
    +--------------------+
    | Database           |
    +--------------------+
    | information_schema |
    | mysql              |
    | performance_schema |
    | sys                |
    | zabbix             |
    +--------------------+
    5 rows in set (0.08 sec)
    ```
    最后关闭在导入过程中开启的`log_bin_trust_function_creators`变量
    ```
    mysql> set global log_bin_trust_function_creators = 0;
    mysql> quit;
    ```

- *开启并配置Zabbix*

    启动Zabbix server和agent进程，并设定开机自启
    ```
    systemctl start zabbix-server zabbix-agent nginx php-fpm
    systemctl enable zabbix-server zabbix-agent nginx php-fpm
    ```

    浏览器访问Zabbix地址`http://10.0.1.40:8000`，端口为在nginx配置中设定值
    
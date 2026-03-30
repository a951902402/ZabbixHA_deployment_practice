## MySQL源副本复制配置
MySQL 8.4版本支持二进制日志与基于全局事务ID两种方式实现源副本复制。
> MySQL 8.4 supports different methods of replication. The traditional method is based on replicating events from the source's binary log, and requires the log files and positions in them to be synchronized between source and replica. The newer method based on global transaction identifiers (GTIDs) is transactional and therefore does not require working with log files or positions within these files, which greatly simplifies many common replication tasks. Replication using GTIDs guarantees consistency between source and replica as long as all transactions committed on the source have also been applied on the replica. 

本实践使用基于GTID的复制方式，详细信息请参考MySQL官方文档[MySQL Replication with GTIDs](https://dev.mysql.com/doc/refman/8.4/en/replication-gtids.html)。

- *MySQL预配置*

    在MySQL源副本两台服务器均完成基础配置后，在配置源副本之前，需要先行配置用于源副本复制的用户，以及设定两台服务器的server_id。

    1. 设定server_id

        打开`/etc/my.cnf`配置文件，为每台服务器设置唯一的server_id，例如源服务器的server_id设为1，副本服务器的server_id设为2，添加如下配置
        ```
        # MySQL源服务器配置
        [mysqld]
        server_id = 1  # 源服务器设为1
        # MySQL副本服务器配置
        [mysqld]
        server_id = 2  # 副本服务器设为2
        ```
        配置完成后执行`systemctl restart mysqld`重启mysql服务，进入mysql命令行，查看当前server_id
        ```
        mysql> show variables like 'server_id';
        +---------------+-------+
        | Variable_name | Value |
        +---------------+-------+
        | server_id     | 1     |
        +---------------+-------+
        1 row in set (0.00 sec)
        ```

    2. 创建复制用户

        分别登录两台服务器的MySQL，创建用于源副本复制的数据库用户，并授予REPLICATION SLAVE权限，注意账户登录IP范围设定，以用户repl并设定从IP为10.0.1.0网段的主机能够使用repl身份登录为例，
        ```
        mysql> CREATE USER 'repl'@'10.0.1.%' IDENTIFIED BY '123456';
        mysql> GRANT REPLICATION SLAVE ON *.* TO 'repl'@'10.0.1.%';
        mysql> FLUSH PRIVILEGES;
        ```
    
    3. (*全新配置跳过*)同步并停止目前正在运行的事务与复制
        
        如果是正在运行的基于二进制日志位置的源副本复制环境，拓扑中任何位置不包含正在运行的GTID 的事务，则应同步源副本所有事务并关闭当前MySQL服务。**如果是全新安装，则跳过此步骤**。
        ```
        # 同步源副本所有事务
        mysql> SET @@GLOBAL.read_only = ON;
        ```
        等待所有正在进行的事务提交或回滚，**确保副本已处理所有更新**，然后使用mysqldump工具进行数据备份，并导入从库，同时为回滚打好基础
        
        然后再继续使用mysqladmin工具停止两台服务器的MySQL服务，此处username应为具备关闭服务器权限的用户。
        ```
        mysqladmin -uusername -p shutdown
        ```
- *MySQL源副本配置*

    首先打开源副本两台服务器`/etc/my.cnf`配置文件，打开基于 GTID 的复制
    ```
    [mysqld]
    gtid_mode=ON                 # 启用GTID模式
    enforce-gtid-consistency=ON  # 强制GTID一致性
    ```
    在MySQL 8.4版本中，二进制日志默认启用，无需特别设定`log_bin`选项，如果进行过mysqld初始化禁用了二进制日志，则需要单独启用，保证源服务器能够正常复制。
    >In MySQL 8.4, binary logging is enabled by default, whether or not you specify the --log-bin option. The exception is if you use mysqld to initialize the data directory manually by invoking it with the --initialize or --initialize-insecure option, when binary logging is disabled by default. It is possible to enable binary logging in this case by specifying the --log-bin option. When binary logging is enabled, the log_bin system variable, which shows the status of binary logging on the server, is set to ON.

    然后在源与副本服务器上设定`read_only`，避免在开启复制后在副本服务器上误插入数据导致源副本数据不一致，从而Replica进程报错复制停止
    ```
    # 在源上
    [mysqld]
    read_only = OFF
    super_read_only = OFF

    # 在副本上
    [mysqld]
    read_only = ON
    super_read_only = ON
    ```
    配置完成后各自执行`systemctl restart mysqld`重启mysql服务使配置生效。

    然后登录副本服务器的MySQL命令行，告知副本服务器使用使用基于 GTID 的事务的源服务器作为复制数据源，并使用基于 GTID 的自动定位而不是基于文件的定位，示例如下
    ```
    mysql> CHANGE REPLICATION SOURCE TO
     >     SOURCE_HOST = '10.0.1.41',
     >     SOURCE_PORT = 3306,
     >     SOURCE_USER = 'repl',
     >     SOURCE_PASSWORD = '123456',
     >     SOURCE_AUTO_POSITION = 1,
     >     GET_SOURCE_PUBLIC_KEY = 1;
    ```
    配置完成后执行`START REPLICA;`启动复制，使用`SHOW REPLICA STATUS\G;`查看复制状态，确认Slave_IO_Running和Slave_SQL_Running均为Yes，且Last_Error为空，表示源副本复制配置成功。
    ```
    mysql> START REPLICA;
    mysql> SHOW REPLICA STATUS\G;
    ******** 1. row ********
    Replica_IO_State: Waiting for source to send event
    Source_Host: 10.0.1.41
    Source_User: repl
    Source_Port: 3306
    Connect_Retry: 60
    Source_Log_File: binlog.000008
    ...
    Replica_IO_Running: Yes
    Replica_SQL_Running: Yes
    ...
    Source_SSL_Allowed: No
    Source_SSL_CA_File: 
    Source_SSL_CA_Path: 
    Source_SSL_Cert: 
    Source_SSL_Cipher: 
    Source_SSL_Key: 
    ...
    Last_IO_Errno: 0
    Last_IO_Error: 
    Last_SQL_Errno: 0
    Last_SQL_Error: 
    ...
    Replica_SQL_Running_State: Replica has read all relay log; waiting for more updates
    ...
    ```

    (*全新配置跳过*)如在之前步骤中启用了源服务器的read_only选项，为允许源服务器能够再次更新数据，执行如下命令
    ```
    mysql> SET @@GLOBAL.read_only = OFF;
    ```

    示例并未使用SSL源副本复制连接，Replica SSL详见MySQL官方文档[19.3.1 Setting Up Replication to Use Encrypted Connections](https://dev.mysql.com/doc/refman/8.4/en/replication-encrypted-connections.html)。

- *MySQL源副本复制配置验证*

    在源服务器上创建测试数据库与表，并插入测试数据
    ```
    mysql> CREATE DATABASE testdb;
    mysql> USE testdb;
    mysql> CREATE TABLE testtable (id INT PRIMARY KEY, name VARCHAR(50));
    mysql> INSERT INTO testtable VALUES (1, 'testdata');
    ```
    然后在副本服务器上查询测试表，确认能够查询到刚才插入的数据
    ```
    mysql> USE testdb;
    mysql> SELECT * FROM testtable;
    +----+----------+
    | id | name     |
    +----+----------+
    |  1 | testdata |
    +----+----------+
    1 row in set (0.00 sec)
    ```
    至此，MySQL源副本复制配置完成，并且验证成功。

> [!NOTE]
> 可选源副本复制安全性配置

以下配置可以根据使用需求设置，非启用Replication强制配置要求.

- 从复制用户名密码储存

    在`CHANGE REPLICATION SOURCE TO`语句中，我们直接指定了复制用户的用户名与密码，在启动复制后，在`/var/log/mysqld.log`日志中我们会看到如下一条告警日志
    ```
    2026-03-28T10:09:19.359933Z 5 [Warning] [MY-010897] [Repl] Storing MySQL user name or password information in the connection metadata repository is not secure and is therefore not recommended. Please consider using the USER and PASSWORD connection options for START REPLICA; see the 'START REPLICA Syntax' in the MySQL Manual for more information.
    ```
    我们可以不在`CHANGE REPLICATION SOURCE TO`语句中指定复制用户的用户名与密码，而是在`START REPLICA`语句中使用USER和PASSWORD选项指定复制用户的用户名与密码
    ```
    mysql> START REPLICA USER='repl' PASSWORD='123456';
    ```
    关于此配置的更多信息请参考MySQL官方文档[15.4.2.4 START REPLICA Statement](https://dev.mysql.com/doc/refman/8.4/en/start-replica.html)

- 启用中继日志

    在MySQL 8.4版本中，存在一个[Bug #2212](https://bugs.mysql.com/bug.php?id=2122)，如果从复制使用默认的基于主机的中继日志文件名，则会导致修改主机名后导致基于GTID的源副本复制失效，并出现以下错误`Failed to open the relay log and Could not find target log during relay log initialization. `，并且在配置源副本复制后，可以在`/var/log/mysqld.log`日志中我们会看到如下一条告警日志
    ```
    2026-03-28T10:09:19.357277Z 0 [Warning] [MY-010604] [Repl] Neither --relay-log nor --relay-log-index were used; so replication may break when this MySQL server acts as a replica and has his hostname changed!! Please use '--relay-log=zbxdb2-relay-bin' to avoid this problem.
    ```
    在MySQL服务器中也可查询到中继日志的相关变量信息，默认情况下中继日志命名以当前主机名开头
    ```
    mysql> show variables like 'relay%';
    +-----------------------+--------------------------------------+
    | Variable_name         | Value                                |
    +-----------------------+--------------------------------------+
    | relay_log             | zbxdb2-relay-bin                      |
    | relay_log_basename    | /var/lib/mysql/zbxdb2-relay-bin       |
    | relay_log_index       | /var/lib/mysql/zbxdb2-relay-bin.index |
    | relay_log_purge       | ON                                   |
    | relay_log_recovery    | OFF                                  |
    | relay_log_space_limit | 0                                    |
    +-----------------------+--------------------------------------+
    6 rows in set (0.01 sec)
    ```

    因此建议在副本服务器的`/etc/my.cnf`配置文件中配置并指定中继日志文件名，例如
    ```
    [mysqld]
    relay_log = /var/lib/mysql/mysql-relay
    relay_log_index =  /var/lib/mysql/mysql-relay.index    # 在只指定了relay_log系统变量，relay_log_index将默认用relay_log的值作为中继日志索引文件的基名。
    ```
    关于中继日志请参考MySQL官方文档[19.2.4.1 The Relay Log](https://dev.mysql.com/doc/refman/8.4/en/replica-logs-relaylog.html)

- 启用半同步复制

    默认情况下，MySQL 复制是异步的。这意味着源服务器在提交事务后不知道任何副本是否以及何时检索和处理了事务，也没有保证任何事件会传送到任何副本。如果源服务器崩溃，从源到副本的故障转移存在到一个相对于源缺少事务的服务器的可能，由此会导致不可逆的**数据丢失风险**。

    与异步复制相比，半同步复制提供了**更高的数据完整性**，然而造成的**性能影响**是为提高数据完整性而付出的代价。这意味着半同步复制最适合通过快速网络通信的靠近的服务器，最不适合通过慢速网络通信的距离较远的服务器。

    半同步复制是使用插件实现的，必须在源和副本上安装这些插件，才能在实例上使用半同步复制。

    1. <span id="check">检查半同步复制插件</span>

        要检查半同步复制插件是否已安装，请在源和副本上执行以下语句
        ```
        mysql> SHOW PLUGINS;
        +-----------------------------------------+--------------------------------+
        | Variable_name                           | Value                          |
        +-----------------------------------------+--------------------------------+
        | basedir                                 | /usr/                          |
        | binlog_direct_non_transactional_updates | OFF                            |
        | character_sets_dir                      | /usr/share/mysql-8.4/charsets/ |
        ...
        | slave_load_tmpdir                       | /tmp                           |
        | tmpdir                                  | /tmp                           |
        +-----------------------------------------+--------------------------------+
        或者
        mysql> SELECT PLUGIN_NAME, PLUGIN_STATUS
                FROM INFORMATION_SCHEMA.PLUGINS
                WHERE PLUGIN_NAME LIKE '%semi%';
        +----------------------+---------------+
        | PLUGIN_NAME          | PLUGIN_STATUS |
        +----------------------+---------------+
        | rpl_semi_sync_source | ACTIVE        |
        +----------------------+---------------+

        ```
        如果未安装半同步复制插件，则需要在源和副本上安装插件，首先应当检查插件文件是否存在
        ```
        # mysql shell查询插件目录
        mysql> SHOW VARIABLES LIKE 'plugin_dir';
        +---------------+--------------------------+
        | Variable_name | Value                    |
        +---------------+--------------------------+
        | plugin_dir    | /usr/lib64/mysql/plugin/ |
        +---------------+--------------------------+
        1 row in set (0.00 sec)
        # 查看插件文件是否存在
        ls -l /usr/lib64/mysql/plugin/semi*
        ```
        MySQL 8.4版本使用插件为`semisync_source.so`与`semisync_replica.so`，如未找到插件文件，则需要获取对应版本的插件或考虑重新安装MySQL。

    2. 安装半同步复制插件

        安装半同步复制插件可以采用写入配置文件方式/MySQL命令行方式两种方式。

        a. 写入配置文件方式
        
        在源和副本的`/etc/my.cnf`配置文件中添加以下配置
        ```
        # MySQL源服务器配置
        [mysqld]
        plugin-load-add = semisync_source.so
        rpl_semi_sync_source_enabled = 1
        rpl_semi_sync_source_timeout = 1000

        # MySQL副本服务器配置
        [mysqld]
        plugin-load-add = semisync_replica.so
        rpl_semi_sync_replica_enabled = 1
        rpl_semi_sync_source_timeout = 1000
        ```
        配置完成后执行`systemctl restart mysqld`重启mysql服务，然后进入MySQL命令行，按照[步骤1](#check)验证插件STATUS为**ACTIVE**

        b. MySQL命令行方式

        安装插件的功能需要支持动态加载的 MySQL 服务器。需检查系统变量`have_dynamic_loading`的值为YES，确认支持动态加载功能。
        ```
        mysql> SHOW VARIABLES LIKE 'have_dynamic_loading';
        +----------------------+-------+
        | Variable_name        | Value |
        +----------------------+-------+
        | have_dynamic_loading | YES   |
        +----------------------+-------+
        1 row in set (0.00 sec)
        ```
        然后在源和副本的MySQL命令行中分别执行以下语句安装半同步复制插件
        ```
        # 在源上
        mysql> INSTALL PLUGIN rpl_semi_sync_source SONAME 'semisync_source.so';
        # 在副本上
        mysql> INSTALL PLUGIN rpl_semi_sync_replica SONAME 'semisync_replica.so';
        ```
        如果尝试安装插件时出现类似于此处所示的错误，则必须安装 libimf，可以在<https://dev.mysqlserver.cn/downloads/os-linux.html>获取
        ```
        ERROR 1126 (HY000): Can't open shared library
        '/usr/local/mysql/lib/plugin/semisync_source.so'
        (errno: 22 libimf.so: cannot open shared object file:
        No such file or directory)
        ```
        安装半同步复制插件后，它默认处于禁用状态。要启用插件，请执行以下语句
        ```
        # 在源上
        mysql> SET GLOBAL rpl_semi_sync_source_enabled = 1;
        # 在副本上
        mysql> SET GLOBAL rpl_semi_sync_replica_enabled = 1;
        ```
        配置完成后按照[步骤1](#check)验证插件STATUS为**ACTIVE**

    3. 启动复制 I/O（接收器）线程

        如果在运行时在副本上启用半同步复制，则还必须启动复制 I/O（接收器）线程（如果它已经在运行，则先停止它）以使副本连接到源并注册为半同步副本，否则副本将继续使用异步复制。
        ```
        mysql> STOP REPLICA IO_THREAD;
        mysql> START REPLICA IO_THREAD;
        ```
        复制 I/O（接收器）线程处于``SHOW REPLICA STATUS\G``命令的`Replica_IO_State`列中
        ```
        mysql> SHOW REPLICA STATUS\G;
        ****** 1. row ******
        Replica_IO_State: Waiting for source to send event
        Source_Host: 10.0.1.46
        Source_User: repl
        ...
        ```
    4. 检查半同步复制

        检查半同步复制状态变量请使用`SHOW VARIABLES LIKE 'rpl_semi_sync%';`，如需要修改半同步复制相关配置，请使用`SET GLOBAL`语句修改对应系统变量

        还可以使用`SHOW STATUS LIKE 'Rpl_semi_sync%';`检查半同步复制状态变量的当前值，此处不过多赘述

    关于半同步复制请参考MySQL官方文档[19.4.10 Semisynchronous Replication](https://dev.mysql.com/doc/refman/8.4/en/replication-semisync.html)



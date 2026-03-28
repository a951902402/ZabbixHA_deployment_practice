## MySQL主从复制配置
MySQL 8.4版本支持二进制日志与基于全局事务ID两种方式实现主从复制。
> MySQL 8.4 supports different methods of replication. The traditional method is based on replicating events from the source's binary log, and requires the log files and positions in them to be synchronized between source and replica. The newer method based on global transaction identifiers (GTIDs) is transactional and therefore does not require working with log files or positions within these files, which greatly simplifies many common replication tasks. Replication using GTIDs guarantees consistency between source and replica as long as all transactions committed on the source have also been applied on the replica. 

本实践使用基于GTID的复制方式，详细信息请参考MySQL官方文档[MySQL Replication with GTIDs](https://dev.mysql.com/doc/refman/8.4/en/replication-gtids.html)。

- *MySQL预配置*

    在MySQL主从两台服务器均完成基础配置后，在配置主从之前，需要先行配置用于主从复制的用户，以及设定两台服务器的server_id。

    1. 设定server_id

        打开`/etc/my.cnf`配置文件，为每台服务器设置唯一的server_id，例如主服务器的server_id设为1，从服务器的server_id设为2，添加如下配置
        ```
        # MySQL主服务器配置
        [mysqld]
        server_id = 1  # 主服务器设为1
        # MySQL从服务器配置
        [mysqld]
        server_id = 2  # 从服务器设为2
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

        分别登录两台服务器的MySQL，创建用于主从复制的数据库用户，并授予REPLICATION SLAVE权限，注意账户登录IP范围设定，以用户repl并设定从IP为10.0.1.0网段的主机能够使用repl身份登录为例，
        ```
        mysql> CREATE USER 'repl'@'10.0.1.%' IDENTIFIED BY '123456';
        mysql> GRANT REPLICATION SLAVE ON *.* TO 'repl'@'10.0.1.%';
        mysql> FLUSH PRIVILEGES;
        ```
    
    3. (*全新配置跳过*)同步并停止目前正在运行的事务与复制
        
        如果是正在运行的基于二进制日志位置的主从复制环境，拓扑中任何位置不包含正在运行的GTID 的事务，则应同步主从所有事务并关闭当前MySQL服务。**如果是全新安装，则跳过此步骤**。
        ```
        # 同步主从所有事务
        mysql> SET @@GLOBAL.read_only = ON;
        ```
        等待所有正在进行的事务提交或回滚，**确保副本已处理所有更新**，然后再继续使用mysqladmin工具停止两台服务器的MySQL服务，此处username应为具备关闭服务器权限的用户。
        ```
        mysqladmin -uusername -p shutdown
        ```
- *MySQL主从配置*

    首先打开主从两台服务器`/etc/my.cnf`配置文件，打开基于 GTID 的复制
    ```
    [mysqld]
    gtid_mode=ON                 # 启用GTID模式
    enforce-gtid-consistency=ON  # 强制GTID一致性
    ```
    在MySQL 8.4版本中，二进制日志默认启用，无需特别设定`log_bin`选项，如果进行过mysqld初始化禁用了二进制日志，则需要单独启用，保证源服务器能够正常复制。
    >In MySQL 8.4, binary logging is enabled by default, whether or not you specify the --log-bin option. The exception is if you use mysqld to initialize the data directory manually by invoking it with the --initialize or --initialize-insecure option, when binary logging is disabled by default. It is possible to enable binary logging in this case by specifying the --log-bin option. When binary logging is enabled, the log_bin system variable, which shows the status of binary logging on the server, is set to ON.
    
    配置完成后各自执行`systemctl restart mysqld`重启mysql服务使配置生效。

    然后登录从服务器的MySQL命令行，告知从服务器使用使用基于 GTID 的事务的主服务器作为复制数据源，并使用基于 GTID 的自动定位而不是基于文件的定位，示例如下
    ```
    mysql> CHANGE REPLICATION SOURCE TO
     >     SOURCE_HOST = '10.0.1.41',
     >     SOURCE_PORT = 3306,
     >     SOURCE_USER = 'repl',
     >     SOURCE_PASSWORD = '123456',
     >     SOURCE_AUTO_POSITION = 1;
    ```
    配置完成后执行`START REPLICA;`启动复制，使用`SHOW REPLICA STATUS\G;`查看复制状态，确认Slave_IO_Running和Slave_SQL_Running均为Yes，且Last_Error为空，表示主从复制配置成功。
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

    (*全新配置跳过*)如在之前步骤中启用了主服务器的read_only选项，为允许主服务器能够再次更新数据，执行如下命令
    ```
    mysql> SET @@GLOBAL.read_only = OFF;
    ```

    示例并未使用SSL主从复制连接，Replica SSL详见MySQL官方文档[19.3.1 Setting Up Replication to Use Encrypted Connections](https://dev.mysql.com/doc/refman/8.4/en/replication-encrypted-connections.html)。

- *MySQL主从复制配置验证*

    在主服务器上创建测试数据库与表，并插入测试数据
    ```
    mysql> CREATE DATABASE testdb;
    mysql> USE testdb;
    mysql> CREATE TABLE testtable (id INT PRIMARY KEY, name VARCHAR(50));
    mysql> INSERT INTO testtable VALUES (1, 'testdata');
    ```
    然后在从服务器上查询测试表，确认能够查询到刚才插入的数据
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
    至此，MySQL主从复制配置完成，并且验证成功。

- *可选主从复制安全性配置*

    1. 从复制用户名密码储存

        在`CHANGE REPLICATION SOURCE TO`语句中，我们直接指定了复制用户的用户名与密码，在启动复制后，在`/var/log/mysqld.log`日志中我们会看到如下一条告警日志
        ```
        2026-03-28T10:09:19.359933Z 5 [Warning] [MY-010897] [Repl] Storing MySQL user name or password information in the connection metadata repository is not secure and is therefore not recommended. Please consider using the USER and PASSWORD connection options for START REPLICA; see the 'START REPLICA Syntax' in the MySQL Manual for more information.
        ```
        我们可以不在`CHANGE REPLICATION SOURCE TO`语句中指定复制用户的用户名与密码，而是在`START REPLICA`语句中使用USER和PASSWORD选项指定复制用户的用户名与密码
        ```
        mysql> START REPLICA USER='repl' PASSWORD='123456';
        ```
        关于此配置的更多信息请参考MySQL官方文档[15.4.2.4 START REPLICA Statement](https://dev.mysql.com/doc/refman/8.4/en/start-replica.html)

    2. 启用中继日志

        在MySQL 8.4版本中，存在一个[Bug #2212](https://bugs.mysql.com/bug.php?id=2122)，如果从复制使用默认的基于主机的中继日志文件名，则会导致修改主机名后导致基于GTID的主从复制失效，并出现以下错误`Failed to open the relay log and Could not find target log during relay log initialization. `，并且在配置主从复制后，可以在`/var/log/mysqld.log`日志中我们会看到如下一条告警日志
        ```
        2026-03-28T10:09:19.357277Z 0 [Warning] [MY-010604] [Repl] Neither --relay-log nor --relay-log-index were used; so replication may break when this MySQL server acts as a replica and has his hostname changed!! Please use '--relay-log=zbxs2-relay-bin' to avoid this problem.
        ```
        在MySQL服务器中也可查询到中继日志的相关变量信息，默认情况下中继日志命名以当前主机名开头
        ```
        mysql> show variables like 'relay%';
        +-----------------------+--------------------------------------+
        | Variable_name         | Value                                |
        +-----------------------+--------------------------------------+
        | relay_log             | zbxs2-relay-bin                      |
        | relay_log_basename    | /var/lib/mysql/zbxs2-relay-bin       |
        | relay_log_index       | /var/lib/mysql/zbxs2-relay-bin.index |
        | relay_log_purge       | ON                                   |
        | relay_log_recovery    | OFF                                  |
        | relay_log_space_limit | 0                                    |
        +-----------------------+--------------------------------------+
        6 rows in set (0.01 sec)
        ```

        因此建议在从服务器的`/etc/my.cnf`配置文件中配置并指定中继日志文件名，例如
        ```
        [mysqld]
        relay_log = /var/lib/mysql/mysql-relay
        relay_log_index =  /var/lib/mysql/mysql-relay.index    # 在只指定了relay_log系统变量，relay_log_index将默认用relay_log的值作为中继日志索引文件的基名。
        ```
        关于中继日志请参考MySQL官方文档[19.2.4.1 The Relay Log](https://dev.mysql.com/doc/refman/8.4/en/replica-logs-relaylog.html)

  <p style="display: flex; justify-content: space-between;"><a href="03-MySQL_installation.md"><strong>&lt;--回到03-MySQL_installation.md</strong></a><a href="05.md"><strong>到下一页05.md--&gt;</strong></a></p>


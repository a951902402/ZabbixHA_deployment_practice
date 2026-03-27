## MySQL主从复制配置
MySQL 8.4版本支持二进制日志与基于全局事务ID两种方式实现主从复制。
> MySQL 8.4 supports different methods of replication. The traditional method is based on replicating events from the source's binary log, and requires the log files and positions in them to be synchronized between source and replica. The newer method based on global transaction identifiers (GTIDs) is transactional and therefore does not require working with log files or positions within these files, which greatly simplifies many common replication tasks. Replication using GTIDs guarantees consistency between source and replica as long as all transactions committed on the source have also been applied on the replica. 

本实践使用基于GTID的复制方式，详细信息请参考MySQL官方文档[MySQL Replication with GTIDs](https://dev.mysql.com/doc/refman/8.4/en/replication-gtids.html)。

- *配置MySQL主从复制*

    在MySQL主从两台服务器均完成基础配置后，分别登录两台服务器的MySQL，创建用于主从复制的数据库用户，并授予REPLICATION SLAVE权限，以用户repl为例
    ```
    CREATE USER 'repl'@'10.0.1.%' IDENTIFIED BY '123456' required SSL;
    GRANT REPLICATION SLAVE ON *.* TO 'repl'@'10.0.1.%';
    FLUSH PRIVILEGES;
    ```
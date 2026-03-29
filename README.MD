# Zabbix 高可用架构说明

本架构实现了 Zabbix 高可用部署，并将 MySQL 数据库与 Zabbix 服务分离，提升整体系统的可用性与可靠性。

## 本架构实现概述

- **Zabbix 高可用**：Zabbix 服务器通过自我配置的 HA 机制保证监控服务不中断。
- **MySQL 源副本复制**：数据库采用源副本复制，基于 GTID（全局事务标识）确保源副本数据一致性。
- **Keepalived**：用于实现虚拟 IP 和故障切换功能。
- **Consul 监控与切换**：Consul 用于实时监控 MySQL 源副本状态，并在源库故障时自动完成源副本切换。Consul 服务端部署在 Zabbix 主服务器上，在 MySQL 两台服务器上各部署一个 Consul agent 做 MySQL 源副本状态监测，Consul 服务端通过两个 agent 的 check 做 watch 进行故障切换。

## 主要特性

- Zabbix 服务高可用，自动故障转移
- 数据库源副本一致性，自动切换源库
- 服务与数据库解耦，便于扩展与维护
- MySQL IP 高可用通过 Keepalived 实现
- Consul 通过 agent check 实现精确的故障切换监控

## 本仓库架构适用场景

架构适用于对监控系统高可用性和数据一致性有较高要求的环境。

## 使用组件说明

- **Zabbix Server**：部署两台，使用自我配置HA机制。
- **MySQL 数据库**：部署两台，基于GTID的源副本复制保证数据一致性。
- **Consul**&&**Keepalived**：Consul服务端部署在 Zabbix 主服务器上，两台 MySQL 服务器上各部署一个 Consul agent，负责 MySQL 源副本健康检查与自动故障切换。使用 Keepalived 虚拟 IP 实现高可用。

## 架构图

```
               用户访问
                  |
        [Zabbix VIP (Keepalived)]
                  |
      [Zabbix A] <--> [Zabbix B]
        |                    |
        |                    |
    [MySQL VIP (Keepalived)] |
        |                    |
    [MySQL Source] <--> [MySQL Replica]
        |                    |
    [Consul Agent]      [Consul Agent]
        |                    |
        +--------------------+
    [Consul Server (在 Zabbix A 上)]
```

## 仓库包含内容

包含的文件项如下：

```
ZABBIXHA_DEPLOYMENT_PRACTICE
|   Deploy_Guide.MD              -----架构部署过程描述与相关代码展示
|   README.MD                    -----架构总体介绍
|   
+---consul
+---mysql
+---public
|   \---system
|           NetAdapter_Setting.png
|           
\---zabbix
    |   zabbix_agentd.conf
    |   zabbix_server.conf
    |   
    \---nginx
            zabbix.conf
```

## 如何开始
部署文档见仓库各md文档，从[00-Pre-deployment.md](00-Pre-deployment.md)开始。

## 备注

1. 此实践共仅使用四台虚拟机，适用于数据安全性要求不高的环境，较合理的企业级部署应当按照**2台**及以上Zabbix服务器部署（*按照官方文档指引部署配置文件即可*），**3台**及以上MySQL服务器（*1台Source与2台Replica，有较大数据读写需求的可以做数据库读写分离*）
2. 部署过程未使用Docker/K8s等应用虚拟化环境，consul服务可以考虑部署虚拟化
3. Zabbix前端与后端也可考虑分离部署，本实践不包含此项
# Zabbix 高可用架构说明

本架构实现了 Zabbix 高可用部署，并将 MySQL 数据库与 Zabbix 服务分离，提升整体系统的可用性与可靠性。

## 架构概述

- **Zabbix 高可用**：Zabbix 服务器通过自我配置的 HA 机制与 Keepalived 实现高可用，保证监控服务不中断。Zabbix 和 MySQL 均各部署两台。
- **MySQL 主从复制**：数据库采用主从复制，基于 GTID（全局事务标识）确保主从数据一致性。MySQL 也使用 Keepalived 实现 IP 高可用。
- **Consul 监控与切换**：Consul 用于实时监控 MySQL 主从状态，并在主库故障时自动完成主从切换。Consul 主服务部署在 Zabbix 主服务器上，在 MySQL 两台服务器上各部署一个 Consul agent 做 MySQL 主从状态监测，Consul 主服务通过两个 agent 的 check 做 watch 进行故障切换。

## 组件说明

- **Zabbix Server**：部署两台，使用 Keepalived 虚拟 IP 实现高可用。
- **MySQL 数据库**：部署两台，主从架构，GTID 保证数据一致性，也使用 Keepalived 实现 IP 高可用。
- **Consul**：主服务部署在 Zabbix 主服务器上，两台 MySQL 服务器上各部署一个 Consul agent，负责 MySQL 主从健康检查与自动故障切换。

## 架构图

```
[Client]
    |
[Zabbix VIP (Keepalived)]
    |
[Zabbix Server A (主)] <--> [Zabbix Server B]
    |                    |
    |                    |
[MySQL VIP (Keepalived)] |
    |                    |
[MySQL Master] <--> [MySQL Slave]
    |                    |
[Consul Agent]       [Consul Agent]
    |                    |
    +--------------------+
         [Consul 主服务 (在 Zabbix Server A 上)]
```

## 主要特性

- Zabbix 服务高可用，自动故障转移
- 数据库主从一致性，自动切换主库
- 服务与数据库解耦，便于扩展与维护
- MySQL IP 高可用通过 Keepalived 实现
- Consul 通过 agent check 实现精确的故障切换监控

## 适用场景

适用于对监控系统高可用性和数据一致性有较高要求的企业级环境。

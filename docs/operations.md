# 日志、报错与日常维护

[功能详解](features.md) · [风险清单](risk-register.md) · [修复历史](fix-history.md)

## 两类日志，各5GB

| 类型 | 目录 / 文件 | 周期 | 保留方式 |
| --- | --- | --- | --- |
| 分钟流量 | `/opt/f50-traffic-hours/counters/YYYY-MM-DD.jsonl` | 约60秒 | 5GB，不按天数过期，满后清最早日期文件 |
| 操作与报错 | `/opt/f50-diagnostics/YYYY-MM-DD/` | 事件持续收集、约15秒落盘 | 5GB，不按天数过期，4MiB分片并按容量轮转 |
| 小时统计 | `/opt/f50-traffic-hours/YYYY-MM-DD.csv` | 约5分钟导出 | 最近100天，供统计复核 |
| 每日峰值 | `/opt/f50-speed-peaks/history.json` | 约10秒汇总，有新峰值才持久更新 | 100天，页面读取30天缓存 |
| 原始统计库 | 现有持久目录，通常 `/opt/vnstat/vnstat.db` | vnStat周期保存 | 不因更新面板清空；五分钟明细保留2400小时 |

容量预算按十进制GB；错误日志的活动文件在收集轮次才检查，边界可暂时超出少量空间。分钟日志另有单日16MiB异常快循环保护；正常每分钟记录远低于这个量。两类各5GB是日志预算，不是把系统卡剩余空间写满。断电可能损失尚未持久保存的尾部记录。

## 每分钟记录哪些字段

| 字段 | 意义 |
| --- | --- |
| `ts` / `interval_start_ts` | 本次与区间起点时间戳 |
| `boot` / `ifindex` | 启动编号与蜂窝接口编号 |
| `uptime` / `interval_seconds` | 单调运行时间与真实采样间隔 |
| `rx` / `tx` | 原始累计字节计数，以字符串保留 |
| `received_bytes` / `sent_bytes` / `total_bytes` | 本区间接收、发送与合计，合计=前两者相加 |
| `status` | `normal`、`initial`、`restart`、`counter-reset` 或 `sampling-gap` |

只有同次启动、同接口、计数未下降且运行时间间隔有效时计算差值；重启、计数归零或采样缺口保留原值和状态，不凭空补出流量。服务重启后首个区间可不足60秒，以记录里的真实间隔为准。分钟旁证不直接改写套餐额度或已用校准。

## 报错日志怎么读

| 文件 | 内容 |
| --- | --- |
| `events.log` | 开关种类、目标、退出码、耗时 |
| `errors.log` | 控制错误、队列溢出等提示 |
| `system.log` | 筛选后的系统/控制错误与有限内核崩溃上下文 |
| `state.log` | 发生错误时的负载、进程与已有状态缓存 |
| `archive-*.log` | 已轮转的旧分片，保留到容量预算清理 |

流量查询失败会以 `f50-traffic-query` 标签记录月/日/小时查询阶段、退出码或返回结构错误。没有响应不当成0用量；网页报XHR但后端没有对应错误时，要继续查连接、RPC与浏览器链路。

设备SSH中读取（不要将原文直接公开）：

```sh
date
df -h /opt
du -sh /opt/f50-diagnostics /opt/f50-traffic-hours/counters
tail -n 5 /opt/f50-traffic-hours/counters/$(date +%Y-%m-%d).jsonl
tail -n 80 /opt/f50-diagnostics/$(date +%Y-%m-%d)/system.log
logread -e f50-traffic-query
ubus call f50quota status
```

## 先定位失效的层

1. **手机是否能加入热点**：检查关联、有效BSSID、DHCP；USB正常不能替代手机检查。
2. **管理IP能否打开**：先用实际IP访问，区分本地后台与公网/DNS问题。
3. **RPC是否及时返回**：状态时间是否新鲜，是否有busy、残留锁或异常退出。
4. **插件与DNS**：分别检查53、5353、7874，记录原组合；修补后恢复原状态。
5. **流量是否跳增**：核对同一时间窗的原始rx/tx差、启动/接口与统计落盘周期；统一GB/GiB，保留旧账本。
6. **内核/SD/供电**：检查I/O、只读、OOM、崩溃上下文。用户态timeout不能解决所有驱动死锁。

按[第十三章](13-optional-repair-and-optimization.md)选择分支和风险编号，保存时间、操作、预期与实际。读数恢复一次不能写成长期稳定性通过。

## 服务与恢复

```sh
/etc/init.d/f50history running
/etc/init.d/f50-speed-peaks running
/etc/init.d/f50-traffic-archive running
/etc/init.d/f50-diagnostics running
ubus call f50openclash status
ubus call f50adguard status
```

面板安装前会创建设备自己的恢复目录并打印 `restore.sh`；使用该路径恢复，不复制维护者机器的 `/root/...` 路径。恢复不删除流量库、峰值历史和日志。短信与系统组件各自有独立安装/恢复流程。

日志和队列可能含手机号、网络标识或短信；只留本机/私人备份。反馈问题时摘取最少必要内容并脱敏，不提交 SMTP 授权码、私钥、订阅、设备免密名单或完整备份。

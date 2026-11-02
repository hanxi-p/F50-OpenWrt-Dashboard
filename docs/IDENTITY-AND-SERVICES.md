# 设备ID、事件与持久化（2026-11-02）

## 身份主线

设备资产主键为随机UUID；MAC、IP和接口是网络标识，不是物理设备主键。已知标识沿用现有注册表中的UUID，多个已确认绑定的MAC在device_index中归到同一UUID。

未知标识分配稳定的provisional UUID，只代表待核实观测对象，不宣称已经识别出一台新物理设备。注册表短暂不可读时缓存ID保持，状态标为registry_unavailable；原注册表明确解除绑定后才重新生成临时观测ID。原始记录按标识保留，解除/改绑不改写原始历史。

当前观测接口保留devices（按MAC的兼容采集视图），新增device_index（以UUID为键的设备视图）。样本加入device_id和identity_state；它们表示采样时的归属快照，不自动成为训练标签。旧样本缺失ID时保留原样，不捏造历史归属。跨节点档案共享需核实身份域，不按同MAC直接合并。

## SQLite归档

依赖sqlite3-cli。/etc/odi/archive.sqlite保存devices（UUID主键）、identifiers（节点/标识到UUID）、features（原始标识特征历史）及source_snapshots（DHCPv6和mDNS最近快照）。10分钟及服务启动检查点更新，事务、WAL、FULL同步和版本检查；档案和原统计仍以既有注册表/账本为准，本阶段没有强制更换其存储。

数据库页面预算约32MiB，原始特征旧行按7天清理；归档失败不阻断采集或上网，状态见/tmp/odi/archive-status.json。数据库及目录仅root访问，不公开真实档案和快照。

## Wi-Fi事件服务

wifi-events.uc由独立的odi-wifi-events procd服务管理，动态订阅当前hostapd对象的assoc、sta-authorized、disassoc、deauth。probe/auth不作为连接记录；关联、授权、断开分开标记。

回调只入内存队列并返回成功，不进行SQL、磁盘等待或准入判断。日志批量写入/etc/odi/wifi-events.jsonl，512KiB双文件轮换、队列128、每分钟最多240条，丢弃计数写入/tmp/odi/wifi-events-status.json。事件未及时解析到ID时保留MAC来源并标unresolved，供后续关联，不随意生成物理身份。

订阅成功不等于厂商驱动每次都能发出完整事件。已有快照会话继续作为兜底，未收到真实事件时不能声称精确事件时长通过。事件服务故障不停止已有Wi-Fi、转发或统计；不调用notify_response改变hostapd配置。

## 功能开启范围

| 优先级 | 当前处理 |
|---|---|
| P0 Wi-Fi上下线 | 独立事件订阅已启用；三轮订阅检查通过，真实断连仍待自然事件验证 |
| P0 DHCP/IPv6/mDNS | DHCP事件、租约和邻居已采集，新增DHCPv6服务快照并归档；DUID等仅在客户端和服务提供时可取得 |
| P0 持久档案 | 原UUID注册表保持，新增SQLite归档，不强制重置 |
| P1 每设备流量 | 保留现有自研只读后端；nlbwmon不安装、不并行运行 |
| P1 多协议匹配 | 特征历史及可解释影子候选已运行，不自动合并或迁移准入权限 |
| P2 机器学习 | 路由器持续留样；未核实标签不足，尚无训练好的身份分类器 |
| 暂缓完整关联帧/射频 | 不更换wpad/驱动，不启用Monitor取样 |

三轮共69项ID/事件规范化/SQLite断言覆盖ID稳定、多标识归档、空/扫描事件排除、SQL文本安全、完整性和未来版本拒绝；三轮完整归档采集及三轮真实订阅检查通过。F50重启ODI三轮ID保持，原统计采集器PID和配置保持；未主动断开设备验证无线事件。

其他路由器部署前须核对注册表路径、sqlite3-cli/ucode-ubus依赖，单独安装events-service到/etc/init.d/odi-wifi-events；现有通用面板安装器不自动安装本试运行目录。只复制源码和配置模板，不复制另一节点的运行状态/档案数据库。

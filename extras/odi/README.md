# ODI 第一阶段：独立观测采集器

当前为F50试运行源码，不是完整ODI产品。独立procd服务每30秒采集一次，不读写现有设备归属、权限或流量账本，已加入影子候选匹配，但没有自动合并、自动删除设备或指纹匹配准确率承诺。

## 已实现

- 实际无线接口和hostapd get_clients能力检测，记录可用HT/VHT/HE/EHT、WMM、MFP、RRM、扩展能力及capabilities原字段。空能力/默认字段标记limited；RSSI和速率单独保存为诊断信息。
- DHCP租约的地址、主机名、到期时间和可用Client ID；过期租约忽略，01:MAC形式明确标记不构成独立证据。其他Client ID尚未验证稳定性。
- IPv4/IPv6邻居地址、接口和邻居状态；明确不是连接证明，不解析为永久身份。
- 可用时读取umdns服务缓存；作为独立时间戳快照保存，不猜测服务属于哪个MAC。
- 每项来源记录观测时间与90秒有效期；保留最近一次来源特征，消费者须检查有效期。档案以MAC为观测键，状态unclassified，不代替现有永久UUID。
- 新生成router_id，保存在独立状态；尚未提供site域配置或跨节点同步。

## 存储与隔离

/tmp/odi/observations.json为当前观测与能力标记，/tmp/odi/mdns.json为服务快照；/etc/odi/observations.json为10分钟检查点及正常停止保存。目录0700、数据0600。保留7天、最多1024个MAC及每MAC64个来源，每项特征最大16KiB、mDNS快照最大256KiB。没有保存通信正文和每秒原始历史。

数据属于私有网络信息，不应提交Git。服务失败可由procd有限重试，不影响转发；损坏的持久状态拒绝覆盖，供维护者恢复。

## 依赖与部署边界

需ucode（fs/uloop）、ubus、ip及现有hostapd；umdns为可选增强。F50安装前模拟依赖，新增umdns而不更新其他库，默认仅LAN、启用jail。其他固件必须重新核对依赖、umdns接口作用域及现有mDNS服务冲突，不更换wpad或无线驱动。

文件部署目标：agent.uc和normalize.uc到/usr/libexec/odi/，service到/etc/init.d/odi-agent并设755。先编译检查agent、隔离目录单轮测试和备份，再启动服务。基础面板和通用面板安装器不会自动安装本目录。

停止并禁用odi-agent即可停止采集；保留/etc/odi用于恢复。若umdns是本次单独新增且没有其他使用者，可再停止、禁用并卸载；不要删除已有服务或恢复整份apk world来回退。

## 尚未实现

DHCPv6 DUID/IAID、SSDP、TCP指纹、完整关联IE、服务到MAC的可验证关联、管理详情UI、多路由器协同、AX6S离线包集成均未完成。没有启用nlbwmon，也不使用无线收发量替代外网计数。

初步验证包括三轮24项规范化断言、三轮隔离单次采集、编译和启动检查。正式试运行仍需积累真实重连、换MAC及同型号碰撞样本；没有为测试主动断开客户端或重启网络。

## 第二阶段：DHCP事件与影子候选（2026-11-01）

利用现有dnsmasq DHCP脚本转发给hotplug的环境字段，在/etc/hotplug.d/dhcp/90-odi挂接最佳努力记录器。dnsmasq配置和原脚本保持，不重启DHCP。只允许MAC格式和add/update/remove事件，白名单读取Vendor Class、请求选项、User Class、Client ID、名称与地址；字段限长、单MAC写锁、最多1024个文件，数据保存在/tmp/odi/dhcp。事件不会被当成连接证明。实际字段取决于客户端提供内容，安装处理器不代表已经捕获到这些字段。

identity.uc读取现有F50档案，仅在同一本机注册表中为未知MAC寻找候选；输出/tmp/odi/candidates.json，带策略版本、时间和有效期。已知MAC继续交由原系统处理。比较同频段规范化无线报告、非通用名称、未经验证Client ID及DHCP选项组合；这些均为解释标签，不是准确率或独立强证据计分。

多个目标档案匹配、目标档案成员同时关联时标为conflict。空能力默认值不参与无线相似匹配，通用名称剔除，同源字段不据此叠加成高置信度。没有candidate_high自动规则，所有结果automatic_link=false；不会修改原档案、账目、会话、免密或拉黑名单。

当前档案适配器为F50的/etc/f50-devices/profiles.json；其他路由器需接入其本地档案路径并验证，未打入AX6S安装包。mDNS依然单独存储，尚未猜测绑定到MAC。影子结果尚未接入面板UI，也没有候选确认/撤销页面。

测试包含三轮33项影子断言（已知/未知、缺失注册表、规范化、空指纹、冲突和输入不变）、三轮合成DHCP事件和三轮隔离完整采集。合成事件仅写隔离目录；真实DHCP元数据等待自然续租，不主动断开设备。代码部署只重载ODI，原采集器PID及受保护配置/档案摘要保持。冷启动、真实换MAC、同型号碰撞与长期资源负载仍需实测样本。

## 特征历史阶段

新增learning.uc、mdns.uc与tests-learning.uc。按MAC保留多版本特征并统计窗口重复性/档案内碰撞，地址唯一对应时补mDNS名称、服务和型号提示；动态生成解释候选，仍不自动关联。历史包含在独立ODI持久状态中，每10分钟及正常停止保存。字段版本最多4个、单特征4KiB、未见记录7天淘汰，模型条目预算约2MiB。详细进度及分类器设计见项目docs；不能把窗口计数称为训练准确率。

## 路由器留样

采样由路由器ODI后台执行，按五分钟窗口/特征变化留样，私有日志容量轮换，标签单独保存且不从推断自动生成。实现为sampler.uc，测试为tests-sampler.uc；文件与限制见项目docs/DATASET.md。

## UUID主视图、SQLite及实时事件

新增subjects.uc统一上层UUID，MAC仅作原始标识；新增archive.uc写入SQLite档案归档，wifi-events.uc独立订阅Wi-Fi关联/授权/断开。原注册表和自研计数保持，nlbwmon不安装。详见项目docs/IDENTITY-AND-SERVICES.md；真实事件和跨硬件测试边界以文档为准。

# 无线驱动日志与发包修补

[返回功能目录](../../README.md#功能目录) · 功能ID：`wifi-log-quiet` · 诊断管理

这是特定 F50 构建的可选兼容修补，基础面板安装器**不会执行**。保留 SIPA 和现有加速、IPv6及网络配置；不要靠压掉错误日志判断修复成功。

## 当前状态

发送路径工具仅为局部兼容修补：较长观察中仍复现 `CMD_TX_DATA / SPRD_CMD_STATUS_ERROR`，尚未彻底解决。不能将隔离检查、短观察或普通传输通过当成无线故障完全修复；暂不作为常规安装方案，保留给匹配构建的排查与复核。

## 先匹配构建

限定已核对的 PCIe F50、内核 `5.4.254-gb50db5b6224c`。工具完整匹配输入 SHA256，输出只写新文件，其他构建拒绝生成。不附带或分发厂商 `.ko`。

| 阶段 | SHA256 |
| --- | --- |
| 原始模块 | `d6a42377cab3ff62a2c990ff7a08c1cf2cf5c7f270aedd15491e267897098481` |
| 三处逐包信息日志降噪后 | `7c7d77a2aecc96d085f830795d24f1f4c95e2a5322455e75bff580629706f63d` |
| 发包路径修补后 | `2ade081cb0db136dcd5eca36ed903793041c4b086c204761d4d2d44f62416e2d` |

日志工具仅移除三处逐包信息调用及其重定位，保留真正错误。另将无线查询写为当前 `iw` 支持的接口形式，避免错误 `iw dev …` 导致 `dev_load`/模块加载请求。

## 发送错误的处理

上游已定位 AP IPv6 组播过度使用 `CMD_TX_DATA` 的拒绝问题，以及命令描述符的五字节前缀偏移错误，见[发送路径修补](https://github.com/dikeckaan/mu300-linux/commit/24691fb17887c7360ad5e726cd0ea5707efe03d2)。AP DNS转数据队列的来源见[上游修补](https://github.com/dikeckaan/mu300-linux/commit/f4f5e760cfa67d96fe6939c4d0ee0f23b930394e)。

本构建工具将 AP IPv6 组播交回数据/特殊报文分类；PCIe AP/GO 的普通 DNS 在校验和处理、加锁之前交回数据队列，DHCP、VoWiFi与其他模式保留原分支。描述符 LUT/TID 访问计入五字节前缀。仍保留固件错误输出。

```sh
node extras/dashboard/optional/wifi-quiet/driver-quiet.cjs ORIGINAL.ko QUIET.ko
node extras/dashboard/optional/wifi-tx/driver-tx-fix.cjs QUIET.ko TX-FIXED.ko
```

只生成本地候选文件；安装、重载和重启均不由这两个命令执行。源程序会核对旧指令、改动范围、重定位、被复用代码块的原直接入口和最终输出哈希。供复核的汇编及 ARM 隔离程序位于 `optional/wifi-tx/`。

## 应用与恢复

先备份正在使用的模块、账本和名称映射，准备独立管理回退。`optional/wifi-quiet/` 与 `optional/wifi-tx/` 的激活/恢复脚本分别对应表中的两个阶段，只能在输入哈希和私有备份路径匹配后使用；发包阶段模板要求当前已是降噪驱动。按模板准备文件后，再由使用者明确确认应用和重启。

替换磁盘模块不会改变已加载驱动；需要重新启动。恢复脚本仅对 AP 未启动做一次自动回滚，不能覆盖所有启动或发包异常。不要为了复测反复断开唯一管理入口。

验收须检查 AP关联、DNS、真实上下行及文件校验、统计/名称保留、网络配置不变，并按时间窗口读取新增错误。ARM分支和描述符隔离测试不代替联网测试；无线命令拒绝减少不代表 SIPA、长期弱信号或所有固件错误均已解决。

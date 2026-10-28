# 无线驱动日志与发包修补

[返回功能目录](../../README.md#功能目录) · 功能ID：`wifi-log-quiet` · 诊断管理

这是特定 F50 构建的可选兼容修补，基础面板安装器**不会执行**。保留 SIPA 和现有加速、IPv6及网络配置；不要靠压掉错误日志判断修复成功。

## 当前状态

后续已实际验证[官方 5.4 底座与源码修复](../../extras/dashboard/optional/wifi-source-repair/README.md)：使用官方 v2026.10.27.2 Image、ramdisk 和整套模块，并源码重编译无线模块保留 AP ARP/DNS 防护。该路径覆盖此前局部补丁遗漏的 EDMA 回压重试及完成唤醒，不继续增加二进制改写。真实重启与上下行验收见[本轮记录](../reviews/2026-10-28-edma-source-repair.md)。这不代表整套 OpenWrt rootfs 或面板升级为上游新版，基础安装器也不会自动执行内核更新。

SIPA 的 `ret -115` 通常是 IPA 恢复中的 `-EINPROGRESS` 流控状态，结合队列恢复与真实传输判断，不能仅凭这一行认定故障。下文保留的旧“未决”记录反映当时判断，不代表该状态本身已被证实为丢包。

PHY 命令兼容处理同时识别 `sprd_wlan_combo`：默认全天线、distance 0、txpower auto 不发出无效命令，避免启动时的 -95 / -12 与 powered-off CMD_SET_PARAM；显式参数及其他驱动仍执行并报告失败。诊断采集保留 EDMA full、push link fail 和 tx return err，不以旧 CMD 错误计数未增长代替完整检查。

以下保留旧二进制修补的失败与阶段记录：

发送路径工具仅为局部兼容修补：较长观察中仍复现 `CMD_TX_DATA / SPRD_CMD_STATUS_ERROR`，早期版本尚未彻底解决。补齐AP ARP分支后，匹配构建的新启动观察窗口未再复现；不据此保证长期或全部固件故障已解决。不能将隔离检查、短观察或普通传输通过当成无线故障完全修复；暂不作为常规安装方案，保留给匹配构建的排查与复核。

## 先匹配构建

限定已核对的 PCIe F50、内核 `5.4.254-gb50db5b6224c`。工具完整匹配输入 SHA256，输出只写新文件，其他构建拒绝生成。不附带或分发厂商 `.ko`。

| 阶段 | SHA256 |
| --- | --- |
| 原始模块 | `d6a42377cab3ff62a2c990ff7a08c1cf2cf5c7f270aedd15491e267897098481` |
| 三处逐包信息日志降噪后 | `7c7d77a2aecc96d085f830795d24f1f4c95e2a5322455e75bff580629706f63d` |
| 发包路径修补后 | `2ade081cb0db136dcd5eca36ed903793041c4b086c204761d4d2d44f62416e2d` |
| 补齐ARP后 | `efddc24b6791c4147f02a07b436eda22ee5b550f24b3bedc17ff758c07f6b071` |

日志工具仅移除三处逐包信息调用及其重定位，保留真正错误。另将无线查询写为当前 `iw` 支持的接口形式，避免错误 `iw dev …` 导致 `dev_load`/模块加载请求。


## 发送错误的处理

上游已定位 AP IPv6 组播过度使用 `CMD_TX_DATA` 的拒绝问题，以及命令描述符的五字节前缀偏移错误，见[发送路径修补](https://github.com/dikeckaan/mu300-linux/commit/24691fb17887c7360ad5e726cd0ea5707efe03d2)。AP DNS转数据队列的来源见[上游修补](https://github.com/dikeckaan/mu300-linux/commit/f4f5e760cfa67d96fe6939c4d0ee0f23b930394e)。

本构建工具将 AP IPv6 组播交回数据/特殊报文分类；PCIe AP/GO 的 ARP与普通 DNS 在校验和处理、加锁之前交回数据队列，DHCP、VoWiFi与其他模式保留原分支。描述符 LUT/TID 访问计入五字节前缀。仍保留固件错误输出。

```sh
node extras/dashboard/optional/wifi-quiet/driver-quiet.cjs ORIGINAL.ko QUIET.ko
node extras/dashboard/optional/wifi-tx/driver-tx-fix.cjs QUIET.ko TX-FIXED.ko
```

只生成本地候选文件；安装、重载和重启均不由这两个命令执行。源程序会核对旧指令、改动范围、重定位、被复用代码块的原直接入口和最终输出哈希。供复核的汇编及 ARM 隔离程序位于 `optional/wifi-tx/`。

## 应用与恢复

先备份正在使用的模块、账本和名称映射，准备独立管理回退。`optional/wifi-quiet/` 与 `optional/wifi-tx/` 的激活/恢复脚本分别对应表中的两个阶段，只能在输入哈希和私有备份路径匹配后使用；最终模板接受已核对的降噪驱动或早期发包补丁，私有原件必须与当前模块哈希一致。按模板准备文件后，再由使用者明确确认应用和重启。

替换磁盘模块不会改变已加载驱动；需要重新启动。恢复脚本仅对 AP 未启动做一次自动回滚，不能覆盖所有启动或发包异常。不要为了复测反复断开唯一管理入口。

验收须检查 AP关联、DNS、真实上下行及文件校验、统计/名称保留、网络配置不变，并按时间窗口读取新增错误。ARM分支和描述符隔离测试不代替联网测试；无线命令拒绝减少不代表 SIPA、长期弱信号或所有固件错误均已解决。

长时复查续：早期发包补丁的同类拒绝确有复现，记录保留。已补充AP/GO PCIe ARP数据队列分支；新增135项ARM分类检查，原分支/描述符检查保持。SIPA -115 在运行中仍可出现，另列未决，不称系统零故障。

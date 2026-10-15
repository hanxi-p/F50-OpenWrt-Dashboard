# 全部功能

从[功能目录](../README.md#功能目录)分别选择需要的功能。

### 界面与设备

- [ ] **[手机与桌面布局](features/mobile-layout.md)** `mobile-layout`
  常用信息常显，详情按需展开，手机按钮每行3个。
- [ ] **[信号与网络质量](features/signal.md)** `signal`
  制式、运营商、频段、QCI和信号读数集中展示。
- [ ] **[基站、小区与SIM详情](features/cell-details.md)** `cell-details`
  需要时展开查看基站、小区、地址与手机号。
- [ ] **[CPU总负载与逐核心详情](features/cpu.md)** `cpu`
  总占用常显，点开查看8个核心占用与频率。
- [ ] **[内存占用与余量](features/memory.md)** `memory`
  显示占用百分比、剩余量和Linux可管理总量。
- [ ] **[四传感器温度](features/temperature.md)** `temperature`
  大字号平均温度，框内列出四个传感器。

### 速率与历史

- [ ] **[实时下载/上传双曲线](features/live-chart.md)** `live-chart`
  最近5分钟、约2秒采样，关掉网页也继续记录。
- [ ] **[每日下载/上传峰值](features/daily-peaks.md)** `daily-peaks`
  今日峰值常显，点击展开30天峰值双曲线。

### 流量与套餐

- [ ] **[本次累计接收/发送](features/session-usage.md)** `session-usage`
  分别显示当前蜂窝接口收到和发出的总字节数。
- [ ] **[本小时使用流量](features/hourly-usage.md)** `hourly-usage`
  显示北京时间当前小时接收+发送合计。
- [ ] **[今日使用流量](features/today-usage.md)** `today-usage`
  从北京时间0点累计到当前的接收+发送。
- [ ] **[套餐总量、已用和剩余](features/plan.md)** `plan`
  自己填写套餐总量与已用，显示进度和剩余额度。
- [ ] **[每日用量折线](features/daily-usage-chart.md)** `daily-usage-chart`
  点击本月总消耗，在首页展开最近30天。
- [ ] **[月度用量历史](features/monthly-history.md)** `monthly-history`
  查看每月接收、发送和含校准的已用合计。

### 快捷控制

- [ ] **[蜂窝流量开关](features/data-switch.md)** `data-switch`
  打开或关闭移动数据连接。
- [ ] **[性能/能效模式](features/power-mode.md)** `power-mode`
  按需开关大核：性能全核，能效使用4个小核。
- [ ] **[4G/自动5G切换](features/radio-mode.md)** `radio-mode`
  点击立即切换，倒计时只提示预计等待。
- [ ] **[OpenClash开关](features/openclash.md)** `openclash`
  已装代理插件的异步启停与状态反馈。
- [ ] **[Wi-Fi热点开关](features/wifi-switch.md)** `wifi-switch`
  更多设置内控制热点开关。
- [ ] **[AdGuard Home开关](features/adguard.md)** `adguard`
  广告过滤服务独立启停，位于更多设置。
- [ ] **[自动/手动Wi-Fi信道](features/channel.md)** `channel`
  按当前地区与驱动能力选择合法非DFS信道。
- [ ] **[制式与频段锁定](features/band-lock.md)** `band-lock`
  在更多设置查看邻区并锁定制式/频段。
- [ ] **[重启调制解调器](features/modem-restart.md)** `modem-restart`
  只重启蜂窝模块，保留本地管理入口。
- [ ] **[重启设备与二次确认](features/device-restart.md)** `device-restart`
  防止误点导致整机重启。
- [ ] **[切换到Android](features/android-switch.md)** `android-switch`
  更多设置中主动进入保留的原厂系统。

### 日志与排错

- [ ] **[每分钟流量日志](features/minute-log.md)** `minute-log`
  每分钟记录下载/上传增量与合计，保留5GB。
- [ ] **[报错与操作日志](features/error-log.md)** `error-log`
  保留操作结果、错误原因和故障上下文，容量5GB。
- [ ] **[DNS协调与恢复](features/dns-recovery.md)** `dns-recovery`
  在代理、广告过滤和直连之间协调可用解析链。
- [ ] **[热点启动保护与恢复](features/wifi-recovery.md)** `wifi-recovery`
  针对零BSSID、长期pending和异常热点提供保护。
- [ ] **[超时、锁与子进程清理](features/bounded-control.md)** `bounded-control`
  避免控制任务无限等待、重复切换或留下孤儿任务。

### 独立扩展

- [ ] **[短信转发到邮件](features/sms-email.md)** `sms-email`
  发送号码与完整短信原文转发到自己的邮箱。
- [ ] **[IPv6多前缀学习](features/ipv6.md)** `ipv6`
  学习蜂窝前缀并撤回失效前缀。
- [ ] **[短信存储与接收守护](features/sms-storage.md)** `sms-storage`
  短信保存后释放SIM空间，保持接收与写池串行。
- [ ] **[USB网络与防火墙适配](features/usb-firewall.md)** `usb-firewall`
  修补RNDIS桥接顺序与厂商5.4的flowtable问题。
- [ ] **[更新与回滚互斥](features/boot-rollback.md)** `boot-rollback`
  回滚恢复匹配模块，避免并发修改启动控制。

### 定向诊断

- [ ] **[无线失败命令追踪](features/wireless-trace.md)** `wireless-trace`
  记录无线初始化究竟是哪条命令失败。

### 管理与可选配置

- [ ] **[指定设备后台免密](features/trusted-login.md)** `trusted-login`
  选择允许免密进入后台的设备及Wi-Fi/USB范围。
- [ ] **[SSH密钥登录](features/ssh-key.md)** `ssh-key`
  配置自己的SSH公钥授权与连接别名。
- [ ] **[后台会话时长](features/session-timeout.md)** `session-timeout`
  单独设置后台会话期限，例如12小时。
- [ ] **[SMTP邮箱参数](features/smtp.md)** `smtp`
  单独设置发件邮箱、SMTP/TLS、收件人与授权码。
- [ ] **[代理与订阅配置](features/proxy-configuration.md)** `proxy-configuration`
  安装和导入自己的代理、订阅或规则，配置DNS与IPv6。
- [ ] **[RPC兼容性修补](features/rpcd-compatibility.md)** `rpcd-compatibility`
  按系统构建和ABI选择RPC依赖库兼容修补。

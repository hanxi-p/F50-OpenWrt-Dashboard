# 2026-10-29 节点通知的渠道与有效期（R100）

后续节点切换仅发Bark，isArchive=1、ttl=600；短信、设备故障和恢复不带ttl，原邮件保留。按内部事件ID的route-前缀分类，不以标题/正文判断，手动双参数发送默认不加过期。

WxPusher生产者不再写入节点事件，投递者也拦截旧待发节点事件并移到私有suppressed目录，避免仅改生产者后旧消息继续发送。短信、故障及原WAN/DNS抑制策略不变。

Bark有效期单位从官方ArchiveProcessor核对为秒，expireDate以客户端创建时间加ttl计算；过期清理由Bark客户端处理。固定源码见[官方实现](https://github.com/Finb/Bark/blob/5a59513d1f04b7659c938db24461ae92a8ee3831/NotificationServiceExtension/Processor/ArchiveProcessor.swift)。没有给WxPusher传未公开的过期参数。

原生三轮渠道/队列去重、Wx实际投递函数的旧节点拦截及短信/故障放行通过；12次真实发送脚本的mock curl检查通过，只有节点事件携带ttl=600，其余无ttl，全部保留isArchive=1。测试使用假凭据与运输桩，未发真实弹窗，未冒充手机端十分钟清理验收。

修改前备份四个脚本，增量替换并仅重启通知生产/投递服务；实机源码读回及运行中策略检查通过，Wx待发节点为0，SMTP运行，网络/代理配置及启动ID未变。实际节点、密钥、队列正文与原始记录不公开。此前双渠道节点通知记录保留为历史，当前策略以本记录为准。

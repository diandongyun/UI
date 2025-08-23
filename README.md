# 多面板一键安装脚本集合

> 声明：该项目仅供个人学习、交流，请遵守当地法律法规，勿用于非法用途；请勿用于生产环境。

本项目收录了常见的几种节点管理面板安装脚本，包括 **x-ui**、**3x-ui**、**s-ui**、**h-ui**，可用于快速搭建和管理节点。

---

## 功能特点

- 一条命令即可完成安装
- 支持多用户管理
- 支持多种协议（VLESS、VMess、TUIC、Hysteria2、Xhttp等）
- 集成常用的 Web 管理界面
- 支持证书申请（ACME）、流量统计、节点限速等

---

## 安装方法

在 VPS 上执行以下命令之一即可安装对应的面板：

### 安装 x-ui
```
bash <(curl -Ls https://raw.githubusercontent.com/diandongyun/UI/main/x-ui.sh)
```

x-ui

最早出现的轻量级多协议节点管理面板

提供简洁的 Web 管理界面

支持 VLESS/VMess/Trojan/Shadowsocks 等常见协议

内置 TLS 证书申请、流量统计功能

适合个人和小规模使用


安装 3x-ui
```
bash <(curl -Ls https://raw.githubusercontent.com/diandongyun/UI/main/3x-ui.sh)
```

3x-ui

基于 x-ui 的增强版，功能更丰富

支持多用户、多协议、多节点管理

优化了界面交互和日志显示

增强了 API 支持，适合二次开发和批量管理

适合有一定规模的节点部署


安装 s-ui
```
bash <(curl -Ls https://raw.githubusercontent.com/diandongyun/UI/main/s-ui.sh)
```

s-ui

更注重批量管理和大规模部署的面板

支持多节点统一管理

提供更灵活的配置和用户权限控制

适合团队或多节点运维场景


安装 h-ui
```
bash <(curl -Ls https://raw.githubusercontent.com/diandongyun/UI/main/h-ui.sh)
```

h-ui

新一代轻量化节点管理面板

支持最新的 Hysteria2（hy2）协议

更适合高性能网络环境和低延迟应用

提供基础的 Web 管理界面，配置简单

适合需要使用 hy2 协议的用户


## 面板对比

| 面板名称 | 主要支持协议 | 特点 | 适用场景 |
|----------|--------------|------|----------|
| **x-ui** | VLESS / VMess | 轻量、简洁，功能基础，安装量大 | 个人使用，小规模节点 |
| **3x-ui** | VLESS / VMess / Xhttp | 增强版 x-ui，多用户、多节点，API 支持更好 | 多节点运维、需要 API 或批量管理 |
| **s-ui** | TUIC / Shadowsocks / VLESS | 更注重多节点统一管理和权限控制 | 团队管理、大规模部署 |
| **h-ui** | Hysteria2 (hy2) | 新一代轻量面板，支持最新 hy2，性能高 | 需要 hy2 协议、低延迟环境 |


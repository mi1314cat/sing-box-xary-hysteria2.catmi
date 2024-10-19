# 简介一键安装脚本
- 建议开启bbr加速，可大幅加快节点reality和vmess节点的速度
- 无脑回车一键安装或者自定义安装
- 完全无需域名，使用自签证书部署hy2，（使用argo隧道支持vmess ws优选ip（理论上比普通优选ip更快））
- 支持修改reality端口号和域名，hysteria2端口号
- 无脑生成sing-box，clash-meta，v2rayN，nekoray等通用链接格式
- 支持warp，任意门，ss解锁流媒体
- 支持任意门中转
- 支持端口跳跃

## hysteria2内核

alpine-hysteria2
一键安装
 ```bash
bash <(curl -fsSL https://github.com/mi1314cat/sing-box-xary-hysteria2.catmi/raw/refs/heads/main/alpine-hysteria2.sh)
```
一键卸载
```bash
bash <(curl -fsSL https://github.com/mi1314cat/sing-box-xary-hysteria2.catmi/raw/refs/heads/main/uninstall_alpine-hysteria2.sh)
```
### Debian ubuntu ....
 hysteria2 带面板脚本
```bash
bash <(curl -fsSL https://github.com/mi1314cat/sing-box-xary-hysteria2.catmi/raw/refs/heads/main/cathy2.sh)
```
  hysteria2 脚本
```bash
bash <(curl -fsSL https://github.com/mi1314cat/sing-box-xary-hysteria2.catmi/raw/refs/heads/main/H3hy2.sh)
```
## sing-box内核
### reality hysteria2二合一脚本

```bash
bash <(curl -fsSL https://github.com/mi1314cat/sing-box-xary-hysteria2.catmi/raw/main/install.sh)
```
### reality和hysteria2 vmess ws三合一脚本

```bash
bash <(curl -fsSL https://github.com/mi1314cat/sing-box-xary-hysteria2.catmi/raw/main/beta.sh)
```
### 尝鲜区
 tcp-brutal reality(双端sing-box 1.7.0及以上可用)

[文档](https://github.com/apernet/tcp-brutal/blob/master/README.zh.md)

```bash
bash <(curl -fsSL https://github.com/mi1314cat/sing-box-xary-hysteria2.catmi/raw/main/tcp-brutal-reality.sh)
```
 brutal reality vision reality hysteria2三合一(双端sing-box 1.7.0及以上可用)，warp分类，端口跳跃等功能

```bash
bash <(curl -fsSL https://github.com/mi1314cat/sing-box-xary-hysteria2.catmi/raw/main/brutal-reality-hysteria.sh)
```

##xary内核

### xary  vmess+ws or socks 脚本
```bash
bash <(curl -fsSL https://github.com/mi1314cat/sing-box-xary-hysteria2.catmi/raw/main/xary.sh) socks
```
```bash
bash <(curl -fsSL https://github.com/mi1314cat/sing-box-xary-hysteria2.catmi/raw/main/xary.sh) vmess
```

## 解决DNS泄露，无分流群组
```
https://github.com/mi1314cat/sing-box-xary-hysteria2.catmi/raw/refs/heads/main/nodnsleak.ini
```



## Credit
- [sing-box-example](https://github.com/chika0801/sing-box-examples)
- [sing-reality-box](https://github.com/deathline94/sing-REALITY-Box)
- [sing-box](https://github.com/SagerNet/sing-box)



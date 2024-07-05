# get-docker

## 如何部署
docker & docker-compose一键部署最新版，根据IP归属指定对应配置文件优化，针对大陆鸡使用自定义镜像加速.

- 头也不回的安装
```shell
bash <(wget -qO- https://raw.githubusercontent.com/honeok8s/get-docker/main/get-docker.sh)
```

- 本地使用，包含执行卸载
```shell
curl -fsSL -O https://raw.githubusercontent.com/honeok8s/get-docker/main/get-docker.sh && chmod +x ./get-docker.sh

# 默认直接安装
./get-docker.sh

# uninstall 全局卸载
./get-docker.sh uninstall
```
![getdocker](img/output.png)

- 感谢B站伙伴（PS：忘了什么名字...）提供的AS4837镜像加速地址，hub.littlediary.cn 不胜感激.
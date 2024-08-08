# get-docker

## 如何部署
docker & docker-compose一键部署最新版，根据IP归属指定对应配置文件优化，针对大陆鸡使用自定义镜像加速.

- 直接运行
```shell
curl -fsSL https://github.com/honeok8s/get-docker/releases/download/v0.1/get-docker.sh.x -o get-docker.sh && chmod +x get-docker.sh && ./get-docker.sh
```
```shell
#bash <(wget -qO- https://raw.githubusercontent.com/honeok8s/get-docker/main/get-docker.sh)
#curl -fsSL https://raw.githubusercontent.com/honeok8s/get-docker/main/get-docker.sh | bash -
```
- 下载本地运行
```shell
#curl -fsSL -O https://raw.githubusercontent.com/honeok8s/get-docker/main/get-docker.sh && chmod +x ./get-docker.sh (不可用)

# 默认安装 Docker
./get-docker.sh

# 卸载 Docker
./get-docker.sh uninstall
```

![getdocker](img/v2.0.1_debian12.png)
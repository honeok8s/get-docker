# get-docker

## 如何部署
docker & docker-compose一键部署最新版，根据IP归属指定对应配置文件优化，针对大陆鸡使用自定义镜像加速.

- 直接运行(不建议大陆服务器使用这种方式)
```shell
bash <(wget -qO- https://raw.githubusercontent.com/honeok8s/get-docker/main/get-docker.sh)
```
```shell
curl -fsSL https://raw.githubusercontent.com/honeok8s/get-docker/main/get-docker.sh | bash -
```
- 下载本地运行
```shell
curl -fsSL -O https://raw.githubusercontent.com/honeok8s/get-docker/main/get-docker.sh && chmod +x ./get-docker.sh

# 默认安装 Docker
./get-docker.sh

# 卸载 Docker
./get-docker.sh uninstall
```

![getdocker](img/v2.0.1_debian12.png)
# get-docker

## 如何部署
docker & docker-compose一键部署最新版，根据IP归属指定对应配置文件优化，针对大陆鸡使用自定义镜像加速.

- 一键安装
```shell
bash <(wget -qO- https://raw.githubusercontent.com/honeok8s/get-docker/main/get-docker.sh)
curl -fsSL https://raw.githubusercontent.com/honeok8s/get-docker/main/get-docker.sh | bash -
```
- 安装
```shell
curl -fsSL -O https://raw.githubusercontent.com/honeok8s/get-docker/main/get-docker.sh && chmod +x ./get-docker.sh
```
- 卸载
```shell
./get-docker.sh uninstall
```
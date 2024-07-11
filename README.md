# get-docker

## 如何部署
docker & docker-compose一键部署最新版，根据IP归属指定对应配置文件优化，针对大陆鸡使用自定义镜像加速.

- 直接运行
```shell
bash <(wget -qO- https://raw.githubusercontent.com/honeok8s/get-docker/main/get-docker.sh)
```
- 下载本地运行
```shell
curl -fsSL -O https://raw.githubusercontent.com/honeok8s/get-docker/main/get-docker.sh && chmod +x ./get-docker.sh

# 默认安装 Docker
./get-docker.sh

# 卸载 Docker
./get-docker.sh uninstall
```
![getdocker](img/new_dev_1.0.8.png)
![getdocker](img/v2.0.1_centos.png)

- 感谢B站: CN-JS-HuiBai
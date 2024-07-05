# get-docker

## 如何部署
写着玩的，docker & docker-compose一键部署最新版，根据IP归属指定对应配置文件优化，使用自定义镜像加速对大陆鸡友好，主要自己方便~

- 头也不回的安装
```shell
bash <(wget -qO- https://raw.githubusercontent.com/honeok8s/get-docker/main/get-docker.sh)
```

- 长期使用,包括但不限于卸载又或是蛋疼
```shell
curl -fsSL -O https://raw.githubusercontent.com/honeok8s/get-docker/main/get-docker.sh && chmod +x ./get-docker.sh

# 默认直接安装
./get-docker.sh

# uninstall 全局卸载
./get-docker.sh uninstall
```

![getdocker](https://image.honeok.com/file/e15546f1ec2e29060b2e6.png)


- 感谢B站伙伴（PS：忘了什么名字...）提供的AS4837镜像加速地址，hub.littlediary.cn 不胜感激.
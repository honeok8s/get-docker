#!/bin/bash

################################################################################
# Author: honeok
# Blog: honeok.com
# Script Name: get_docker.sh
# Description: This script automates the installation of Docker and Docker Compose
#              on CentOS7x, Debian, and Ubuntu Linux distributions. It detects the
#              operating system type and installs Docker from official or
#              mirrored repositories based on the user's location (China or other).
#              The script checks for internet connectivity, retrieves the server's
#              IPv4 and optional IPv6 addresses, and configures Docker based on
#              geographical location. It also includes uninstallation options for
#              Docker and Docker Compose on supported Linux distributions.
#
# Description: 此脚本用于自动化在CentOS7.X,Debian和Ubuntu Linux发行版上安装Docker和Docker Compose.
#              根据用户所在地区(中国或其他地区),脚本检测操作系统类型,并从官方或阿里云镜像仓库安装Docker
#              脚本还检查网络连接,获取服务器的IPv4和IPv6 地址,并根据地理位置配置Docker配置文件.
#              同时提供了在支持的Linux发行版上卸载Docker和Docker Compose的选项.
#
################################################################################

set -o errexit

gitdocker_version=(v1.0.5)
os_release=$(grep '^PRETTY_NAME=' /etc/os-release | cut -d '"' -f 2)
uninstall_check_system=$(cat /etc/os-release)

# ANSI颜色码
yellow='\033[1;33m' # 提示
red='\033[1;31m'    # 警告
green='\033[1;32m'  # 成功
blue='\033[1;34m'
purple='\033[1;35m' # 紫 & 粉
white='\033[0m'     # 结尾

################################################################################
# Functions Definition
################################################################################

# 通过ping image.honeok.com检查是否有外网
check_internet_connect(){
  printf "${yellow}执行网络检测${white}\n"
  if ! ping -c 1 image.honeok.com; then
    printf "${red}网络错误!无法访问公网! ${white}\n"
    exit 1
  fi
}

# 检查服务器IPV4 & IPV6
ip_address(){
  ipv4_address=$(curl -s ipv4.ip.sb)
  ipv6_address=$(curl -s --max-time 1 ipv6.ip.sb || true)
  location=$(curl -s myip.ipip.net | awk -F "来自于：" '{print $2}' | awk '{gsub(/^[[:space:]]+|[[:space:]]+$/,""); print}')
  
  printf "${yellow}当前IPv4地址: $ipv4_address ${white}\n"

  if [ -n "$ipv6_address" ]; then
    printf "${yellow}当前IPv6地址: $ipv6_address ${white}\n"
  fi
  
  printf "${yellow}当前IP归属: $location ${white}\n"
  
  org_info=$(curl -s -f ipinfo.io/org)
  if [ $? -eq 0 ]; then
    printf "${yellow}运营商: $org_info. ${white}\n"
  else
    printf "${red}获取运营商信息失败. ${white}\n"
  fi

  sleep 2s
  echo ""
}

# 检查Docker或Docker Compose是否已安装,用于函数嵌套
check_docker_installed() {
  if docker --version >/dev/null 2>&1; then
    printf "${red}Docker已安装,正在退出安装程序.${white}\n"
    echo ""
    script_completion_message
    exit 0
  fi

  if docker compose --version >/dev/null 2>&1; then
    printf "${red}Docker Compose(新版)已安装,正在退出安装程序.${white}\n"
	echo ""
    script_completion_message
    exit 0
  fi

  if docker-compose --version >/dev/null 2>&1; then
    printf "${red}Docker Compose(旧版)已安装,正在退出安装程序.${white}\n"
    echo ""
    script_completion_message
    exit 0
  fi
}

# 检查服务器内存和硬盘可用空间
check_server_resources() {
  # 获取内存总量,单位为MB
  mem_total=$(free -m | awk '/^Mem:/{print $2}')

  # 获取根分区的可用空间,单位为GB
  disk_avail=$(df -h / | awk 'NR==2 {print $4}')

  # 获取内存使用百分比
  mem_used_percentage=$(free | awk '/^Mem:/{print ($3/$2)*100}')

  # 获取磁盘使用百分比
  disk_used_percentage=$(df -h / | awk 'NR==2 {sub(/%/,"",$5); print $5}')

  # 检查内存和硬盘空间
  if (( mem_total < 900 )); then
    printf "${red}内存小于900MB,无法继续安装 Docker.${white}\n"
    script_completion_message
    exit 1
  fi

  # 将硬盘可用空间转换为数值,去除单位(GB)
  disk_avail_value=$(echo $disk_avail | awk '{gsub("G",""); print}')

  # 检查硬盘空间
  if (( disk_avail_value < 5 )); then
    printf "${red}硬盘可用空间小于5GB,无法继续安装 Docker.${white}\n"
    script_completion_message
    exit 1
  fi

  # 输出剩余的内存和磁盘空间信息
  echo ""
  printf "${yellow}剩余内存: ${mem_total}MB,已使用内存: %.2f%%${white}\n" "$mem_used_percentage"
  printf "${yellow}剩余磁盘空间: ${disk_avail},已使用磁盘空间: %s${white}\n" "$disk_used_percentage%"
  echo ""
}

# 在CentOS上安装Docker
centos_install_docker(){
  local repo_url=""
  
  if [ "$(curl -s https://ipinfo.io/country)" == 'CN' ]; then
    repo_url="http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo"
  else
    repo_url="https://download.docker.com/linux/centos/docker-ce.repo"
  fi

  check_docker_installed
  printf "${yellow}在${os_release}上安装Docker! ${white}\n"

  # 根据官方文档删除旧版本的Docker
  sudo yum remove docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine -y >/dev/null 2>&1 || true

  sudo yum install yum-utils -y >/dev/null 2>&1
  sudo yum-config-manager --add-repo "$repo_url" >/dev/null 2>&1
  sudo yum makecache fast
  sudo yum install docker-ce docker-ce-cli containerd.io -y
  sudo systemctl enable docker --now >/dev/null 2>&1

  # 检查Docker服务是否处于活动状态 
  if ! sudo systemctl is-active docker >/dev/null 2>&1; then
    printf "${red}错误:Docker状态检查失败或服务无法启动,请检查安装日志或手动启动Docker服务. ${white}\n"
    exit 1
  else
    echo ""
    printf "${green}Docker已完成自检,启动并设置开机自启. ${white}\n"
    echo ""
    sleep 2s
  fi
}

# 在 Debian/Ubuntu 上安装 Docker
debian_install_docker(){
  local repo_url=""
  local gpg_key_url=""
  local codename="$(lsb_release -cs)"

  if [ "$(curl -s https://ipinfo.io/country)" == 'CN' ]; then
    case "$os_release" in
      *ubuntu*|*Ubuntu*)
        repo_url="https://mirrors.aliyun.com/docker-ce/linux/ubuntu"
        gpg_key_url="https://mirrors.aliyun.com/docker-ce/linux/ubuntu/gpg"
        ;;
      *debian*|*Debian*)
        repo_url="https://mirrors.aliyun.com/docker-ce/linux/debian"
        gpg_key_url="https://mirrors.aliyun.com/docker-ce/linux/debian/gpg"
        ;;
      *)
	    printf "${red}此脚本不支持的Linux发行版. ${white}\n"
        exit 1
        ;;
    esac
  else
    case "$os_release" in
      *ubuntu*|*Ubuntu*)
        repo_url="https://download.docker.com/linux/ubuntu"
        gpg_key_url="https://download.docker.com/linux/ubuntu/gpg"
        ;;
      *debian*|*Debian*)
        repo_url="https://download.docker.com/linux/debian"
        gpg_key_url="https://download.docker.com/linux/debian/gpg"
        ;;
      *)
        printf "${red}此脚本不支持的Linux发行版. ${white}\n"
        exit 1
        ;;
    esac
  fi

  check_docker_installed
  printf "${yellow}在${os_release}上安装Docker! ${white}\n"

  # 根据官方文档删除旧版本的Docker
  for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do
    sudo apt-get remove $pkg >/dev/null 2>&1 || true
  done

  sudo apt-get update >/dev/null 2>&1
  sudo apt-get install -y ca-certificates curl

  sudo install -m 0755 -d /etc/apt/keyrings
  sudo curl -fsSL "$gpg_key_url" -o /etc/apt/keyrings/docker.asc
  sudo chmod a+r /etc/apt/keyrings/docker.asc
  
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] $repo_url $codename stable" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
  
  sudo apt-get update && sudo apt-get install docker-ce docker-ce-cli containerd.io -y

  # 检查Docker服务是否处于活动状态
  if ! sudo systemctl is-active docker >/dev/null 2>&1; then
    printf "${red}错误:Docker状态检查失败或服务无法启动,请检查安装日志或手动启动Docker服务. ${white}\n"
    exit 1
  else
    echo ""
    printf "${green}Docker已完成自检,启动并设置开机自启. ${white}\n"
    echo ""
    sleep 2s
  fi
}

# 在CentOS上卸载Docker
centos_uninstall_docker(){
  printf "${yellow}从${os_release}卸载Docker. ${white}\n"
  echo ""
  sudo docker rm -f $(docker ps -q) >/dev/null 2>&1 || true
  sudo systemctl stop docker >/dev/null 2>&1 && sudo systemctl disable docker >/dev/null 2>&1
  sudo yum remove docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin docker-ce-rootless-extras -y
  sudo rm -fr /var/lib/docker && sudo rm -fr /var/lib/containerd && sudo rm -rf /etc/docker
  sleep 2s
  echo ""
  printf "${green}Docker和Docker Compose已从${os_release}卸载. ${white}\n"
  script_completion_message
}

# 在Debian/Ubuntu上卸载Docker
debian_uninstall_docker(){
  printf "${yellow}从${os_release}卸载Docker. ${white}\n"
  echo ""
  sudo docker rm -f $(docker ps -q) >/dev/null 2>&1 || true
  sudo systemctl stop docker >/dev/null 2>&1
  sudo systemctl disable docker >/dev/null 2>&1
  sudo apt-get purge docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin docker-ce-rootless-extras -y
  sudo rm -fr /var/lib/docker && sudo rm -fr /var/lib/containerd && sudo rm -fr /etc/docker
  if ls /etc/apt/sources.list.d/docker.* >/dev/null 2>&1; then
    sudo rm -f /etc/apt/sources.list.d/docker.*
  fi
  if ls /etc/apt/keyrings/docker.* >/dev/null 2>&1; then
    sudo rm -f /etc/apt/keyrings/docker.*
  fi
  sleep 2s
  echo ""
  printf "${green}Docker和Docker Compose已从${os_release}卸载,并清理文件夹和相关依赖. ${white}\n"
  script_completion_message
}

# 定义Docker配置文件
# 如果服务器在中国,并且有IPv6地址,则使用中国的镜像加速器和IPv6配置
# 如果服务器在中国,但只有IPv4地址，则仅使用中国的镜像加速器
# 如果服务器在非中国地区,并且有IPv6地址,则使用IPv6配置
# 默认情况下,对于非中国地区且只有IPv4地址的服务器,使用基本配置
# 根据服务器的实际情况动态生成并加载Docker配置文件,确保最佳的镜像下载和网络配置
generate_docker_config(){
  local config_file="/etc/docker/daemon.json"
  local ipv4_address=$(curl -s ipv4.ip.sb)
  local ipv6_address=$(curl -s --max-time 1 ipv6.ip.sb)
  local is_china_server='false'

  # 检查服务器是否在中国
  if [ "$(curl -s https://ipinfo.io/country)" == 'CN' ]; then
    is_china_server='true'
  fi

  # 基本配置
  local base_config=$(cat <<EOF
{
  "exec-opts": [
    "native.cgroupdriver=systemd"
  ],
  "max-concurrent-downloads": 10,
  "max-concurrent-uploads": 5,
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "30m",
    "max-file": "3"
  },
  "ipv6": false
}
EOF
)

# 根据条件生成不同的配置
  if [ "$is_china_server" == 'true' ]; then
    if [ -n "$ipv6_address" ]; then
    # 中国服务器且存在IPv6
    local china_with_ipv6_config=$(cat <<EOF
{
  "registry-mirrors": [
    "https://hub.littlediary.cn",
    "https://registry.honeok.com"
   ],
   "exec-opts": [
      "native.cgroupdriver=systemd"
    ],
   "max-concurrent-downloads": 10,
   "max-concurrent-uploads": 5,
   "log-driver": "json-file",
   "log-opts": {
     "max-size": "30m",
     "max-file": "3"
   },
   "ipv6": true,
   "fixed-cidr-v6": "fd00:dead:beef:c0::/80",
   "experimental": true,
   "ip6tables": true
}
EOF
)
      echo "$china_with_ipv6_config" > "$config_file"
    else
      # 中国服务器但只有IPv4
      local china_with_ipv4_config=$(cat <<EOF
{
  "registry-mirrors": [
     "https://hub.littlediary.cn",
     "https://registry.honeok.com"
  ],
  "exec-opts": [
     "native.cgroupdriver=systemd"
  ],
  "max-concurrent-downloads": 10,
  "max-concurrent-uploads": 5,
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "30m",
    "max-file": "3"
  },
  "ipv6": false
}
EOF
)
      echo "$china_with_ipv4_config" > "$config_file"
    fi
    elif [ -n "$ipv6_address" ]; then
    # 非中国服务器但存在IPv6
    local non_china_with_ipv6_config=$(cat <<EOF
{
    "exec-opts": [
       "native.cgroupdriver=systemd"
    ],
    "max-concurrent-downloads": 10,
    "max-concurrent-uploads": 5,
    "log-driver": "json-file",
    "log-opts": {
      "max-size": "30m",
      "max-file": "3"
    },
    "ipv6": true,
    "fixed-cidr-v6": "fd00:dead:beef:c0::/80",
    "experimental": true,
    "ip6tables": true
}
EOF
)
    echo "$non_china_with_ipv6_config" > "$config_file"
  else
    # 默认情况,非中国服务器且只有IPv4
    echo "$base_config" > "$config_file"
  fi

  # 校验和重新加载Docker守护进程
  printf "${green}Docker配置文件已重新加载并重启Docker服务. ${white}\n"
  sudo systemctl daemon-reload && sudo systemctl restart docker
  echo ""
  printf "${yellow}Docker配置文件已根据服务器IP归属做相关优化,如需修改配置文件请 vim & nano $config_file ${white}\n"
  echo ""
}

# 显示已安装Docker和Docker Compose版本
docker_main_version(){
  local docker_version=""
  local docker_compose_version=""

  if command -v docker >/dev/null 2>&1; then
    docker_version=$(docker --version | awk '{gsub(/,/, "", $3); print $3}')
  elif command -v docker.io >/dev/null 2>&1; then
    docker_version=$(docker.io --version | awk '{gsub(/,/, "", $3); print $3}')
  fi
  
  if command -v docker-compose >/dev/null 2>&1; then
    docker_compose_version=$(docker-compose version | awk 'NR==1{print $4}')
  elif command -v docker >/dev/null 2>&1 && docker compose --version >/dev/null 2>&1; then
    docker_compose_version=$(docker compose version | awk 'NR==1{print $4}')
  fi

  printf "${yellow}已安装Docker版本: v$docker_version ${white}\n"
  printf "${yellow}已安装Docker Compose版本: $docker_compose_version ${white}\n"
  echo ""
}

print_getdocker_logo() {
cat << 'EOF'
                                                                                                              
                                                                                                              
  ,----..                   ___                                                     ,-.                       
 /   /   \                ,--.'|_                 ,---,                         ,--/ /|                       
|   :     :               |  | :,'              ,---.'|    ,---.              ,--. :/ |               __  ,-. 
.   |  ;. /               :  : ' :              |   | :   '   ,'\             :  : ' /              ,' ,'/ /| 
.   ; /--`      ,---.   .;__,'  /               |   | |  /   /   |    ,---.   |  '  /       ,---.   '  | |' | 
;   | ;  __    /     \  |  |   |              ,--.__| | .   ; ,. :   /     \  '  |  :      /     \  |  |   ,' 
|   : |.' .'  /    /  | :__,'| :             /   ,'   | '   | |: :  /    / '  |  |   \    /    /  | '  :  /   
.   | '_.' : .    ' / |   '  : |__          .   '  /  | '   | .; : .    ' /   '  : |. \  .    ' / | |  | '    
'   ; : \  | '   ;   /|   |  | '.'|         '   ; |:  | |   :    | '   ; :__  |  | ' \ \ '   ;   /| ;  : |    
'   | '/  .' '   |  / |   ;  :    ;         |   | '/  '  \   \  /  '   | '.'| '  : |--'  '   |  / | |  , ;    
|   :    /   |   :    |   |  ,   /          |   :    :|   `----'   |   :    : ;  |,'     |   :    |  ---'     
 \   \ .'     \   \  /     ---`-'            \   \  /               \   \  /  '--'        \   \  /            
  `---`        `----'                         `----'                 `----'                `----'             
                                                                                                              
EOF

  printf "${yellow}Author: honeok ${white} \n"
  printf "${blue}Version: $gitdocker_version ${white} \n"
  printf "${purple}Project:https://github.com/honeok8s ${white} \n"

  sleep 2s
  echo ""
}

# 显示Docker信息
docker_info(){
  printf "${yellow}正在获取Docker信息. ${white}\n"
  sleep 2s
  sudo docker version
}

# 退出脚本前显示执行完成信息
script_completion_message() {
  local timezone=$(timedatectl | awk '/Time zone/ {print $3}')
  local current_time=$(date '+%Y-%m-%d %H:%M:%S')

  echo ""
  printf "${green}服务器当前时间: ${current_time} 时区: ${timezone} 脚本: $(basename $0) 执行完成!再见! ${white}\n"
}
################################################################################
# Main Script Execution
################################################################################

# 打印 "gitdocker" Logo
print_getdocker_logo

# 检查脚本是否以root用户身份运行
if [[ $EUID -ne 0 ]]; then
  printf "${red}此脚本必须以root用户身份运行. ${white}\n"
  exit 1
fi

# 获取服务器IP地址
ip_address

# 检查操作系统是否受支持(CentOS,Debian,Ubuntu)
case "$os_release" in
  *CentOS*|*centos*|*Debian*|*debian*|*Ubuntu*|*ubuntu*)
    printf "${yellow}检测到本脚本支持的Linux发行版: $os_release ${white}\n"
    ;;
    *)
    printf "${red}此脚本不支持的Linux发行版: $os_release ${white}\n"
    exit 1
    ;;
esac

# 卸载
if [[ "$1" == "uninstall" ]]; then
  case "$uninstall_check_system" in
    *CentOS*|*centos*)
      centos_uninstall_docker
      ;;
    *Debian*|*debian*|*Ubuntu*|*ubuntu*)
      debian_uninstall_docker
      ;;
    *)
      printf "${red}此脚本不支持的Linux发行版. ${white}\n"
      exit 1
      ;;
  esac
  exit 0
fi

# 根据操作系统类型安装Docker
case "$os_release" in
  *CentOS*|*centos*)
    check_internet_connect
    check_server_resources
    centos_install_docker
    generate_docker_config
    ;;
  *Debian*|*debian*|*Ubuntu*|*ubuntu*)
    check_internet_connect
    check_server_resources
    debian_install_docker
    generate_docker_config
    ;;
  *)
    printf "${red}此脚本不支持的Linux发行版. ${white}\n"
    exit 1
    ;;
esac

sleep 2s

# 显示已安装的Docker和Docker Compose版本
docker_main_version

# 显示Docker信息
docker_info

script_completion_message

exit 0
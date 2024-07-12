#!/bin/bash
# Author: honeok
# Blog: honeok.com
# Script Name: get_docker.sh
# Description: This script automates the installation of Docker and Docker Compose on CentOS7x, Debian, and Ubuntu Linux distributions. It detects the
#              operating system type and installs Docker from official or mirrored repositories based on the user's location (China or other).
#              The script checks for internet connectivity, retrieves the server's IPv4 and optional IPv6 addresses, and configures Docker based on
#              geographical location. It also includes uninstallation options for Docker and Docker Compose on supported Linux distributions.
#
# Usage: ./get_docker.sh [uninstall]
################################################################################

set -o errexit
clear

gitdocker_version=(v2.0.2)
os_release=$(grep '^PRETTY_NAME=' /etc/os-release | cut -d '"' -f 2)

# ANSI颜色码,用于彩色输出
yellow='\033[1;33m' # 提示信息
red='\033[1;31m'    # 警告信息
green='\033[1;32m'  # 成功信息
blue='\033[1;34m'   # 一般信息
cyan='\033[1;36m'   # 特殊信息
purple='\033[1;35m' # 紫色或粉色信息
gray='\033[1;30m'   # 灰色信息
white='\033[0m'     # 结束颜色设置

# 检查网络连接
check_internet_connect(){
	printf "${yellow}执行网络检测.${white}\n"
	if ! ping -c 2 image.honeok.com &> /dev/null; then
		printf "${red}网络错误: 无法访问互联网!.${white}\n"
		exit 1
	fi

	echo ""
}

# 获取服务器IP地址
check_ip_address(){
	ipv4_address=$(curl -s ipv4.ip.sb)
	ipv6_address=$(curl -s --max-time 1 ipv6.ip.sb || true)
	location=$(curl -s myip.ipip.net | awk -F "来自于：" '{print $2}' | awk '{gsub(/^[[:space:]]+|[[:space:]]+$/,""); print}')

	printf "${yellow}当前IPv4地址: $ipv4_address ${white}\n"
	[ -n "$ipv6_address" ] && printf "${yellow}当前IPv6地址: $ipv6_address ${white}\n"
	printf "${yellow}IP地理位置: $location${white}\n"

	org_info=$(curl -s -f ipinfo.io/org)
	if [ $? -eq 0 ]; then
		printf "${yellow}ISP 提供商: $org_info.${white}\n"
	else
		printf "${red}无法获取ISP信息.${white}\n"
	fi

	sleep 2s
	echo ""
}

# 检查服务器内存和硬盘可用空间
check_server_resources() {
	# 获取内存总量、已用内存和可用内存
	mem_total=$(free -m | awk '/^Mem:/{print $2}')
	mem_used=$(free -m | awk '/^Mem:/{print $3}')
	mem_free=$(free -m | awk '/^Mem:/{print $7}')

	# 计算内存使用率
	mem_used_percentage=$(awk "BEGIN {printf \"%.2f\", ${mem_used}/${mem_total}*100}")

	# 打印服务器内存信息
	printf "${yellow}服务器内存总量: ${mem_total}MB${white}\n"
	printf "${yellow}已用内存: ${mem_used}MB (${mem_used_percentage}%%)${white}\n"
	printf "${yellow}可用内存: ${mem_free}MB${white}\n"

	# 遍历实际挂载的磁盘分区,排除常见的系统分区
	printf "${yellow}磁盘分区使用情况:${white}\n"
	df -h | awk -v yellow="$yellow" -v white="$white" '
	NR>1 && !/^(udev|tmpfs|overlay|devpts|sysfs|proc)/ {
		printf "  - %-10s: 总量 %-5s, 已用 %-5s, 可用 %-5s, 使用率: %s\n", 
			$1, yellow $2 white, yellow $3 white, yellow $4 white, yellow $5 white
	}'

	echo ""
}

# 检查Docker或Docker Compose是否已安装,用于在函数操作系统安装docker中嵌套
check_docker_installed() {
	if docker --version >/dev/null 2>&1; then
		printf "${red}Docker已安装,正在退出安装程序.${white}\n"
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

	if docker compose --version >/dev/null 2>&1; then
		printf "${red}Docker Compose(新版)已安装,正在退出安装程序.${white}\n"
		echo ""
		script_completion_message
		exit 0
	fi

	echo ""
}

# 在CentOS上安装Docker
centos_install_docker(){
	local repo_url=""

	# 检查是否为CentOS7
	if ! grep -q '^ID="centos"' /etc/os-release || ! grep -q '^VERSION_ID="7"' /etc/os-release; then
		printf "${red}错误: 检测到操作系统为CentOS,但本脚本仅支持在CentOS7上安装Docker,如有需求请 honeok.com 留言.${white}\n"
		script_completion_message
		exit 1
	fi

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
		printf "${green}Docker已完成自检,启动并设置开机自启. ${white}\n"
		sleep 2s
	fi

	echo ""
}

# 在 Debian/Ubuntu 上安装 Docker
debian_install_docker(){
	local repo_url=""
	local gpg_key_url=""
	local codename="$(lsb_release -cs)"

	# 根据服务器位置选择镜像源
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
	apt install sudo >/dev/null 2>&1
	for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do
		sudo apt remove $pkg >/dev/null 2>&1 || true
	done

	sudo apt update -y >/dev/null 2>&1
	sudo apt install apt-transport-https ca-certificates curl gnupg lsb-release -y >/dev/null 2>&1

	# 下载并安装Docker的GPG密钥
	sudo install -m 0755 -d /etc/apt/keyrings
	sudo curl -fsSL "$gpg_key_url" -o /etc/apt/keyrings/docker.asc
	sudo chmod a+r /etc/apt/keyrings/docker.asc

	# 添加Docker的软件源
	echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] $repo_url $codename stable" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

	sudo apt update -y && sudo apt install docker-ce docker-ce-cli containerd.io -y

	# 检查Docker服务是否处于活动状态
	if ! sudo systemctl is-active docker >/dev/null 2>&1; then
		printf "${red}错误:Docker状态检查失败或服务无法启动,请检查安装日志或手动启动Docker服务. ${white}\n"
		exit 1
	else
		printf "${green}Docker已完成自检,启动并设置开机自启. ${white}\n"
		sleep 2s
	fi

	echo ""
}

# 卸载Docker
uninstall_docker() {
	local uninstall_check_system=$(cat /etc/os-release)
	printf "${yellow}准备卸载Docker. ${white}\n"
	sleep 2s

	# 检查Docker是否安装
	if ! command -v docker &> /dev/null; then
		printf "${red}错误: Docker未安装在系统上,无法继续卸载.${white}\n"
		script_completion_message
		exit 1
	fi

	if [[ $uninstall_check_system == *"CentOS"* ]]; then
		printf "${yellow}从${os_release}卸载Docker. ${white}\n"
		sudo docker rm -f $(docker ps -q) >/dev/null 2>&1 || true && sudo systemctl stop docker >/dev/null 2>&1 && sudo systemctl disable docker >/dev/null 2>&1
		sudo yum remove docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin docker-ce-rootless-extras -y
		sudo rm -fr /var/lib/docker && sudo rm -fr /var/lib/containerd && sudo rm -rf /etc/docker/*
		# 完全卸载debian/ubuntu的docker软件安装源
		if [ -f /etc/yum.repos.d/docker.* ];then
			sudo rm -f /etc/yum.repos.d/docker.*
		fi
	elif [[ $uninstall_check_system == *"Ubuntu"* ]] || [[ $uninstall_check_system == *"Debian"* ]]; then
		printf "${yellow}从${os_release}卸载Docker. ${white}\n"
		sudo docker rm -f $(docker ps -q) >/dev/null 2>&1 || true && sudo systemctl stop docker >/dev/null 2>&1 && sudo systemctl disable docker >/dev/null 2>&1
		sudo apt-get purge docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin docker-ce-rootless-extras -y
		sudo rm -fr /var/lib/docker && sudo rm -fr /var/lib/containerd && sudo rm -fr /etc/docker/*
		# 完全卸载debian/ubuntu的docker软件安装源
		if ls /etc/apt/sources.list.d/docker.* >/dev/null 2>&1; then
			sudo rm -f /etc/apt/sources.list.d/docker.*
		fi
		if ls /etc/apt/keyrings/docker.* >/dev/null 2>&1; then
			sudo rm -f /etc/apt/keyrings/docker.*
		fi
	else
		printf "${red}抱歉,此脚本不支持您的Linux发行版. ${white}\n"
		exit 1
	fi

	# 检查卸载是否成功
	if command -v docker &> /dev/null; then
		printf "${red}错误: Docker卸载失败,请手动检查.${white}\n"
		exit 1
	else
		echo ""
		printf "${green}Docker和Docker Compose已从${os_release}卸载,并清理文件夹和相关依赖. ${white}\n"
		sleep 2s
	fi

	echo ""
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

# 基本配置模板
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
  "storage-driver": "overlay2",
  "ipv6": false
}
EOF
)

# registry-mirrors 配置
local registry_mirrors_config=$(cat <<EOF
  "registry-mirrors": [
    "https://hub.littlediary.cn",
    "https://registry.honeok.com",
    "https://docker.kejilion.pro"
  ]
EOF
)

# 根据条件生成不同的配置
if [ "$is_china_server" == 'true' ]; then
	if [ -n "$ipv6_address" ]; then
	# 中国服务器且存在IPv6
		local china_with_ipv6_config=$(cat <<EOF
{
   $registry_mirrors_config,
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
   "storage-driver": "overlay2",
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
  $registry_mirrors_config,
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
  "storage-driver": "overlay2",
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
	"storage-driver": "overlay2",
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

	printf "${yellow}正在获取Docker信息. ${white}\n"
	sleep 2s
	sudo docker version

	echo ""
}

# 退出脚本前显示执行完成信息
script_completion_message() {
	local timezone=$(timedatectl | awk '/Time zone/ {print $3}')
	local current_time=$(date '+%Y-%m-%d %H:%M:%S')

	printf "${green}服务器当前时间: ${current_time} 时区: ${timezone} 脚本执行完成.${white}\n"

	printf "${purple}感谢使用本脚本!如有疑问,请访问 honeok.com 获取更多信息.${white}\n"
}

print_getdocker_logo() {
cat << 'EOF'
   ______     __         __           __            
  / _______  / /_   ____/ ____  _____/ /_____  _____
 / / __/ _ \/ __/  / __  / __ \/ ___/ //_/ _ \/ ___/
/ /_/ /  __/ /_   / /_/ / /_/ / /__/ ,< /  __/ /    
\____/\___/\__/   \__,_/\____/\___/_/|_|\___/_/     
                                                    
EOF

	printf "${gray}############################################################## ${white} \n"
	printf "${yellow}Author: honeok ${white} \n"
	printf "${blue}Version: $gitdocker_version ${white} \n"
	printf "${purple}Project: https://github.com/honeok8s/get-docker ${white} \n"
	printf "${gray}############################################################## ${white} \n"
	sleep 2s
	echo ""
}

# 执行逻辑
# 检查脚本是否以root用户身份运行
if [[ $EUID -ne 0 ]]; then
	printf "${red}此脚本必须以root用户身份运行. ${white}\n"
	exit 1
fi

# 参数检查
if [ -n "$1" ] && [ "$1" != "uninstall" ]; then
	print_getdocker_logo
	printf "${red}错误: 无效参数! (可选: 没有参数/uninstall). ${white}\n"
	script_completion_message
	exit 1
fi

if [ -n "$2" ]; then
	print_getdocker_logo
	printf "${red}错误: 只能提供一个参数 (可选: uninstall). ${white}\n"
	script_completion_message
	exit 1
fi

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

# 开始脚本
main(){
	# 打印Logo
	print_getdocker_logo

	# 检查网络连接
	check_internet_connect

	# 获取IP地址
	check_ip_address

	# 检查服务器资源
	check_server_resources

	# 执行卸载 Docker
	if [ "$1" == "uninstall" ]; then
		uninstall_docker
		script_completion_message
		exit 0
	fi

	# 检查操作系统兼容性并执行安装或卸载
	case "$os_release" in
	*CentOS*|*centos*)
		centos_install_docker
		generate_docker_config
		docker_main_version
		;;
	*Debian*|*debian*|*Ubuntu*|*ubuntu*)
		debian_install_docker
		generate_docker_config
		docker_main_version
		;;
	*)
		printf "${red}使用方法: ./get_docker.sh [uninstall]${white}\n"
		exit 1
		;;
	esac

	# 完成脚本
	script_completion_message
}

main "$@"
exit 0

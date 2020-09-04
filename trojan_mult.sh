#!/bin/bash

function blue(){
  echo -e "\033[34m\033[01m$1\033[0m"
}
function green(){
  echo -e "\033[32m\033[01m$1\033[0m"
}
function red(){
  echo -e "\033[31m\033[01m$1\033[0m"
}
function version_lt(){
  test "$(echo "$@" | tr " " "\n" | sort -rV | head -n 1)" != "$1";
}
#copy from 秋水逸冰 ss scripts
if [[ -f /etc/redhat-release ]]; then
  release="centos"
elif cat /etc/issue | grep -Eqi "debian"; then
  release="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
  release="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
  release="centos"
elif cat /proc/version | grep -Eqi "debian"; then
  release="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
  release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
  release="centos"
fi

if [ "$release" == "centos" ]; then
  systemPackage="yum"
  systempwd="/usr/lib/systemd/system/"
elif [ "$release" == "ubuntu" ]; then
  systemPackage="apt"
  systempwd="/lib/systemd/system/"
elif [ "$release" == "debian" ]; then
  systemPackage="apt"
  systempwd="/lib/systemd/system/"
fi

function install(){
  $systemPackage -y install nginx
  systemctl enable nginx
  systemctl stop nginx
  sleep 5
  cat > /etc/nginx/nginx.conf <<-EOF
user  root;
worker_processes  1;
error_log  /var/log/nginx/error.log warn;
pid        /var/run/nginx.pid;
events {
  worker_connections  1024;
}
http {
  include       /etc/nginx/mime.types;
  default_type  application/octet-stream;
  log_format  main  '\$remote_addr - \$remote_user [\$time_local] "\$request" '
    '\$status \$body_bytes_sent "\$http_referer" '
    '"\$http_user_agent" "\$http_x_forwarded_for"';
  access_log  /var/log/nginx/access.log  main;
  sendfile        on;
  #tcp_nopush     on;
  keepalive_timeout  120;
  client_max_body_size 20m;
  #gzip  on;
  server {
    listen       80;
    server_name  $your_domain;
    root /usr/share/nginx/html;
    index index.php index.html index.htm;
  }
}
EOF
  #设置伪装站
  rm -rf /usr/share/nginx/html/*
  cd /usr/share/nginx/html/
  wget https://github.com/dajiangfu/trojan/raw/master/web.zip >/dev/null 2>&1
  unzip web.zip >/dev/null 2>&1
  sleep 5
  #申请https证书
  if [ ! -d "/usr/src" ]; then
    mkdir /usr/src
  fi
  mkdir /usr/src/trojan-cert /usr/src/trojan-temp
  curl https://get.acme.sh | sh
  ~/.acme.sh/acme.sh --issue -d $your_domain --standalone
  ~/.acme.sh/acme.sh --installcert -d $your_domain --key-file /usr/src/trojan-cert/private.key --fullchain-file /usr/src/trojan-cert/fullchain.cer
  if test -s /usr/src/trojan-cert/fullchain.cer; then
    systemctl start nginx
    cd /usr/src
    #下载trojan服务端
    wget https://api.github.com/repos/trojan-gfw/trojan/releases/latest >/dev/null 2>&1
    latest_version=`grep tag_name latest| awk -F '[:,"v]' '{print $6}'`
    rm -f latest
    wget https://github.com/trojan-gfw/trojan/releases/download/v${latest_version}/trojan-${latest_version}-linux-amd64.tar.xz >/dev/null 2>&1
    tar xf trojan-${latest_version}-linux-amd64.tar.xz >/dev/null 2>&1
    #下载trojan客户端
    wget https://github.com/dajiangfu/trojan/raw/master/trojan-cli.zip >/dev/null 2>&1
    wget -P /usr/src/trojan-temp https://github.com/trojan-gfw/trojan/releases/download/v${latest_version}/trojan-${latest_version}-win.zip >/dev/null 2>&1
    unzip trojan-cli.zip >/dev/null 2>&1
    unzip /usr/src/trojan-temp/trojan-${latest_version}-win.zip -d /usr/src/trojan-temp/ >/dev/null 2>&1
    #cp /usr/src/trojan-cert/fullchain.cer /usr/src/trojan-cli/fullchain.cer
    mv -f /usr/src/trojan-temp/trojan/trojan.exe /usr/src/trojan-cli/ 
    trojan_passwd=$(cat /dev/urandom | head -1 | md5sum | head -c 8)
    cat > /usr/src/trojan-cli/config.json <<-EOF
{
  "run_type": "client",
  "local_addr": "127.0.0.1",
  "local_port": 1080,
  "remote_addr": "$your_domain",
  "remote_port": 443,
  "password": [
    "$trojan_passwd"
  ],
  "log_level": 1,
  "ssl": {
    "verify": true,
    "verify_hostname": true,
    "cert": "",
    "cipher": "ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES256-SHA:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES128-SHA:ECDHE-RSA-AES256-SHA:DHE-RSA-AES128-SHA:DHE-RSA-AES256-SHA:AES128-SHA:AES256-SHA:DES-CBC3-SHA",
    "cipher_tls13": "TLS_AES_128_GCM_SHA256:TLS_CHACHA20_POLY1305_SHA256:TLS_AES_256_GCM_SHA384",
    "sni": "",
    "alpn": [
      "h2",
      "http/1.1"
    ],
    "reuse_session": true,
    "session_ticket": false,
    "curves": ""
  },
  "tcp": {
    "no_delay": true,
    "keep_alive": true,
    "reuse_port": false,
    "fast_open": false,
    "fast_open_qlen": 20
  }
}
EOF
    rm -rf /usr/src/trojan/server.conf
    cat > /usr/src/trojan/server.conf <<-EOF
{
  "run_type": "server",
  "local_addr": "0.0.0.0",
  "local_port": 443,
  "remote_addr": "127.0.0.1",
  "remote_port": 80,
  "password": [
    "$trojan_passwd"
  ],
  "log_level": 1,
  "ssl": {
    "cert": "/usr/src/trojan-cert/fullchain.cer",
    "key": "/usr/src/trojan-cert/private.key",
    "key_password": "",
    "cipher": "ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384",
    "cipher_tls13": "TLS_AES_128_GCM_SHA256:TLS_CHACHA20_POLY1305_SHA256:TLS_AES_256_GCM_SHA384",
    "prefer_server_cipher": true,
    "alpn": [
      "http/1.1"
    ],
    "alpn_port_override": {
      "h2": 81
    },
    "reuse_session": true,
    "session_ticket": false,
    "session_timeout": 600,
    "plain_http_response": "",
    "curves": "",
    "dhparam": ""
  },
  "tcp": {
    "prefer_ipv4": false,
    "no_delay": true,
    "keep_alive": true,
    "reuse_port": false,
    "fast_open": false,
    "fast_open_qlen": 20
  },
  "mysql": {
    "enabled": false,
    "server_addr": "127.0.0.1",
    "server_port": 3306,
    "database": "trojan",
    "username": "trojan",
    "password": "",
    "key": "",
    "cert": "",
    "ca": ""
  }
}
EOF
    cd /usr/src/trojan-cli/
    zip -q -r trojan-cli.zip /usr/src/trojan-cli/
    trojan_path=$(cat /dev/urandom | head -1 | md5sum | head -c 16)
    mkdir /usr/share/nginx/html/${trojan_path}
    mv /usr/src/trojan-cli/trojan-cli.zip /usr/share/nginx/html/${trojan_path}/
    #增加启动脚本

    cat > ${systempwd}trojan.service <<-EOF
[Unit]
Description=trojan
After=network.target

[Service]
Type=simple
PIDFile=/usr/src/trojan/trojan/trojan.pid
ExecStart=/usr/src/trojan/trojan -c "/usr/src/trojan/server.conf"
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure
RestartSec=1s

[Install]
WantedBy=multi-user.target
EOF

    chmod +x ${systempwd}trojan.service
    systemctl start trojan.service
    systemctl enable trojan.service
    if [ "$release" == "centos" ]; then
      read -p "是否启用防火墙 ?请输入 [Y/n] :" yn
      [ -z "${yn}" ] && yn="y"
      if [[ $yn == [Yy] ]]; then
        systemctl start firewalld.service
        systemctl enable firewalld.service
        firewall-cmd --zone=public --add-port=80/tcp --permanent
        firewall-cmd --zone=public --add-port=443/tcp --permanent
        firewall-cmd --reload
      else
        systemctl disable firewalld.service
      fi
    elif [ "$release" == "ubuntu" ]; then
      read -p "是否启用防火墙 ?请输入 [Y/n] :" yn
      [ -z "${yn}" ] && yn="y"
      if [[ $yn == [Yy] ]]; then
        systemctl start ufw
        systemctl enable ufw
        ufw allow 80
        ufw allow 443
        ufw reload
      else
        systemctl disable ufw
      fi
    fi
    rm -f /usr/share/nginx/html/web.zip
    rm -f /usr/src/trojan-${latest_version}-linux-amd64.tar.xz
    rm -f /usr/src/trojan-cli.zip
    rm -rf /usr/src/trojan-temp
    green "======================================================================"
    green "Trojan已安装完成，请使用以下链接下载trojan客户端，此客户端已配置好所有参数"
    green "1、复制下面的链接，在浏览器打开，下载客户端，注意此下载链接将在1个小时后失效"
    blue "http://${your_domain}/$trojan_path/trojan-cli.zip"
    green "2、将下载的压缩包解压，打开文件夹，打开start.bat即打开并运行Trojan客户端"
    green "3、打开stop.bat即关闭Trojan客户端"
    green "4、Trojan客户端需要搭配浏览器插件使用，例如switchyomega等"
    green "======================================================================"
  else
    red "==================================="
    red "https证书没有申请成功，自动安装失败"
    green "不要担心，你可以手动修复证书申请"
    green "1. 重启VPS"
    green "2. 重新执行脚本，使用修复证书功能"
    red "==================================="
  fi
}

function install_trojan(){
  nginx_status=`ps -aux | grep "nginx: worker" |grep -v "grep"`
  if [ -n "$nginx_status" ]; then
    systemctl stop nginx
  fi
  $systemPackage -y install net-tools socat
  Port80=`netstat -tlpn | awk -F '[: ]+' '$1=="tcp"{print $5}' | grep -w 80`
  Port443=`netstat -tlpn | awk -F '[: ]+' '$1=="tcp"{print $5}' | grep -w 443`
  if [ -n "$Port80" ]; then
    process80=`netstat -tlpn | awk -F '[: ]+' '$5=="80"{print $9}'`
    red "==========================================================="
    red "检测到80端口被占用，占用进程为：${process80}，本次安装结束"
    red "==========================================================="
    exit 1
  fi
  if [ -n "$Port443" ]; then
    process443=`netstat -tlpn | awk -F '[: ]+' '$5=="443"{print $9}'`
    red "============================================================="
    red "检测到443端口被占用，占用进程为：${process443}，本次安装结束"
    red "============================================================="
    exit 1
  fi
  #目前SELinux 支持三种模式，分别是enforcing：强制模式，permissive：宽容模式，disabled：关闭
  if [ -f "/etc/selinux/config" ]; then
    CHECK=$(grep SELINUX= /etc/selinux/config | grep -v "#")
    if [ "$CHECK" != "SELINUX=disabled" ]; then
      read -p "检测到SELinux开启状态，是否继续开启SElinux ?请输入 [Y/n] :" yn
      [ -z "${yn}" ] && yn="y"
      if [[ $yn == [Yy] ]]; then
        green "添加放行80/443端口规则"
        $systemPackage -y install policycoreutils-python
        if semanage port -l | grep -w http_port_t | grep -w 80 >/dev/null 2>/dev/null; then
          green "80端口已添加"
        else
          semanage port -a -t http_port_t -p tcp 80 >/dev/null 2>&1
          green "80端口已添加"
        fi
        if semanage port -l | grep -w http_port_t | grep -w 443 >/dev/null 2>/dev/null; then
          green "443端口已添加"
        else
          semanage port -a -t http_port_t -p tcp 443 >/dev/null 2>&1
          green "443端口已添加"
        fi
      else
        if [ "$CHECK" == "SELINUX=enforcing" ]; then
            sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
        elif [ "$CHECK" == "SELINUX=permissive" ]; then
            sed -i 's/SELINUX=permissive/SELINUX=disabled/g' /etc/selinux/config
        fi
        red "======================================================================="
        red "关闭selinux后，必须重启VPS才能生效，再执行本脚本，即将在3秒后重启......"
        red "======================================================================="
        clear
        green "重启倒计时3s"
        sleep 1s
        clear
        green "重启倒计时2s"
        sleep 1s
        clear
        green "重启倒计时1s"
        sleep 1s
        clear
        green "重启中..."
        reboot
      fi
    fi
  fi
  if [ "$release" == "centos" ]; then
    if [ -n "$(grep ' 6\.' /etc/redhat-release)" ] ;then
      red "==============="
      red "当前系统不受支持"
      red "==============="
      exit
    fi
    if [ -n "$(grep ' 5\.' /etc/redhat-release)" ] ;then
      red "==============="
      red "当前系统不受支持"
      red "==============="
      exit
    fi
    systemctl stop firewalld.service
    rpm -Uvh https://github.com/dajiangfu/trojan/raw/master/nginx-release-centos-7-0.el7.ngx.noarch.rpm
  elif [ "$release" == "ubuntu" ]; then
    if  [ -n "$(grep ' 14\.' /etc/os-release)" ] ;then
      red "==============="
      red "当前系统不受支持"
      red "==============="
      exit
    fi
    if  [ -n "$(grep ' 12\.' /etc/os-release)" ] ;then
      red "==============="
      red "当前系统不受支持"
      red "==============="
      exit
    fi
    systemctl stop ufw
    $systemPackage update
  elif [ "$release" == "debian" ]; then
    $systemPackage update
  fi
  $systemPackage -y install wget unzip zip curl tar >/dev/null 2>&1
  green "======================="
  blue "请输入绑定到本VPS的域名"
  green "======================="
  read your_domain
  real_addr=`ping ${your_domain} -c 1 | sed '1{s/[^(]*(//;s/).*//;q}'`
  local_addr=`curl ipv4.icanhazip.com`
  if [ $real_addr == $local_addr ] ; then
    green "=========================================="
    green "       域名解析正常，开始安装trojan"
    green "=========================================="
    sleep 1s
    install
  else
    red "================================"
    red "域名解析地址与本VPS IP地址不一致"
    red "若你确认稍后可以将域名解析到本VPS的IP上，可强制脚本继续"
    red "================================"
    read -p "是否强制运行 ?请输入 [Y/n] :" yn
    [ -z "${yn}" ] && yn="y"
    if [[ $yn == [Yy] ]]; then
      green "强制继续运行脚本"
      sleep 1s
      install
    else
      exit 1
    fi
  fi
}

function repair_cert(){
  systemctl stop nginx
  Port80=`netstat -tlpn | awk -F '[: ]+' '$1=="tcp"{print $5}' | grep -w 80`
  if [ -n "$Port80" ]; then
    process80=`netstat -tlpn | awk -F '[: ]+' '$5=="80"{print $9}'`
    red "==========================================================="
    red "检测到80端口被占用，占用进程为：${process80}，本次安装结束"
    red "==========================================================="
    exit 1
  fi
  green "======================="
  blue "请输入绑定到本VPS的域名"
  blue "务必与之前失败使用的域名一致"
  green "======================="
  read your_domain
  real_addr=`ping ${your_domain} -c 1 | sed '1{s/[^(]*(//;s/).*//;q}'`
  local_addr=`curl ipv4.icanhazip.com`
  if [ $real_addr == $local_addr ] ; then
    ~/.acme.sh/acme.sh --issue -d $your_domain --standalone
    ~/.acme.sh/acme.sh --installcert -d $your_domain --key-file /usr/src/trojan-cert/private.key --fullchain-file /usr/src/trojan-cert/fullchain.cer
    if test -s /usr/src/trojan-cert/fullchain.cer; then
      green "证书申请成功"
      green "请将/usr/src/trojan-cert/下的fullchain.cer下载放到客户端trojan-cli文件夹"
      systemctl restart trojan
      systemctl start nginx
    else
      red "申请证书失败"
    fi
  else
    red "================================"
    red "域名解析地址与本VPS IP地址不一致"
    red "本次安装失败，请确保域名解析正常"
    red "================================"
  fi
}

function remove_trojan(){
  red "================================"
  red "即将卸载trojan"
  red "同时卸载安装的nginx"
  red "================================"
  systemctl stop trojan
  systemctl disable trojan
  rm -f ${systempwd}trojan.service
  if [ "$release" == "centos" ]; then
    $systemPackage -y remove nginx
  else
    $systemPackage -y autoremove nginx
  fi
  rm -rf /usr/src/trojan*
  rm -rf /usr/share/nginx/html/*
  green "=============="
  green "trojan删除完毕"
  green "=============="
}

function update_trojan(){
  /usr/src/trojan/trojan -v 2>trojan.tmp
  curr_version=`cat trojan.tmp | grep "trojan" | awk '{print $4}'`
  wget https://api.github.com/repos/trojan-gfw/trojan/releases/latest >/dev/null 2>&1
  latest_version=`grep tag_name latest| awk -F '[:,"v]' '{print $6}'`
  rm -f latest
  rm -f trojan.tmp
  if version_lt "$curr_version" "$latest_version"; then
    green "当前版本$curr_version,最新版本$latest_version,开始升级……"
    mkdir trojan_update_temp && cd trojan_update_temp
    wget https://github.com/trojan-gfw/trojan/releases/download/v${latest_version}/trojan-${latest_version}-linux-amd64.tar.xz >/dev/null 2>&1
    tar xf trojan-${latest_version}-linux-amd64.tar.xz >/dev/null 2>&1
    mv ./trojan/trojan /usr/src/trojan/
    cd .. && rm -rf trojan_update_temp
    systemctl restart trojan
    /usr/src/trojan/trojan -v 2>trojan.tmp
    green "trojan升级完成，当前版本：`cat trojan.tmp | grep "trojan" | awk '{print $4}'`"
    rm -f trojan.tmp
  else
    green "当前版本$curr_version,最新版本$latest_version,无需升级"
  fi
}

start_menu(){
  clear
  green " ======================================="
  green " 介绍：一键安装trojan      "
  green " 系统：centos7+/debian9+/ubuntu16.04+"
  green " 网站：www.atrandys.com              "
  green " Youtube：Randy's 堡垒                "
  blue " 声明："
  red " *请不要在任何生产环境使用此脚本"
  red " *请不要有其他程序占用80和443端口"
  red " *若是第二次使用脚本，请先执行卸载trojan"
  green " ======================================="
  echo
  green " 1. 安装trojan"
  red " 2. 卸载trojan"
  green " 3. 升级trojan"
  green " 4. 修复证书"
  blue " 0. 退出脚本"
  echo
  read -p "请输入数字:" num
  case "$num" in
  1)
  install_trojan
  ;;
  2)
  remove_trojan 
  ;;
  3)
  update_trojan 
  ;;
  4)
  repair_cert 
  ;;
  0)
  exit 1
  ;;
  *)
  clear
  red "请输入正确数字"
  sleep 1s
  start_menu
  ;;
  esac
}

start_menu

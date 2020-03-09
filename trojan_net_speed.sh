#!/bin/bash

blue(){
  echo -e "\033[34m\033[01m$1\033[0m"
}
green(){
  echo -e "\033[32m\033[01m$1\033[0m"
}
red(){
  echo -e "\033[31m\033[01m$1\033[0m"
}

#安装trojan
function trojan(){
  curl -O https://raw.githubusercontent.com/dajiangfu/trojan/master/trojan_mult.sh
  chmod +x trojan_mult.sh
  ./trojan_mult.sh
  sleep 1s
  read -s -n1 -p "按任意键继续 ... "
}

#安装BBR+BBR魔改版+BBRplus+Lotserver
function net_speed(){
  cd /usr/src
  wget -N "https://raw.githubusercontent.com/dajiangfu/Linux-NetSpeed/master/tcp.sh"
  chmod +x tcp.sh
  ./tcp.sh
  sleep 1s
  read -s -n1 -p "按任意键继续 ... "
}

#设置计划任务
function crontab_edit(){
  cat /etc/crontab
  read -p "请按照以上格式输入计划任务：" crontab_cmd
  rm -f /etc/crontab
  sleep 1s
  cat > /etc/crontab <<-EOF
SHELL=/bin/bash
PATH=/sbin:/bin:/usr/sbin:/usr/bin
MAILTO=root

# For details see man 4 crontabs

# Example of job definition:
# .---------------- minute (0 - 59)
# |  .------------- hour (0 - 23)
# |  |  .---------- day of month (1 - 31)
# |  |  |  .------- month (1 - 12) OR jan,feb,mar,apr ...
# |  |  |  |  .---- day of week (0 - 6) (Sunday=0 or 7) OR sun,mon,tue,wed,thu,fri,sat
# |  |  |  |  |
# *  *  *  *  * user-name  command to be executed

$crontab_cmd

EOF
  systemctl enable crond.service
  systemctl start crond.service
  crontab /etc/crontab
  systemctl reload crond.service
  systemctl status crond.service
  blue "编辑后的计划任务："
  echo
  crontab -l
  sleep 1s
  read -s -n1 -p "按任意键继续 ... "
  start_menu
}

#修改SSH端口号
function change_ssh_port(){
  declare -i port_num
  read -p "请输入新端口号(1024-65535):" port_num
  if [[ $port_num -ge 1024 && $port_num -le 65535 ]]; then
    green " 输入端口号正确，正在设置该端口号"
  else
    red "输入的端口号错误，请重新输入"
    unset port_num
    change_ssh_port
  fi
  grep -q "Port $port_num" /etc/ssh/sshd_config
  if [ $? -eq 0 ]; then
    red " 端口已经添加，请勿重复添加"
    return
  else
    sed -i "/Port 22/a\Port $port_num" /etc/ssh/sshd_config
    sed -i '/Port 22/s/^#//' /etc/ssh/sshd_config
    firewall-cmd --zone=public --add-port=$port_num/tcp --permanent
    firewall-cmd --reload
    systemctl restart sshd.service
  fi
  sleep 1s
  read -s -n1 -p "按任意键继续 ... "
  start_menu
}

#关闭SSH默认22端口
function close_ssh_default_port(){
  grep -q "#Port 22" /etc/ssh/sshd_config
  if [ $? -eq 0 ]; then
    red " 端口22已被关闭，无需重复操作"
  else
    sed -i 's/Port 22/#Port 22/g' /etc/ssh/sshd_config
    firewall-cmd --reload
    systemctl restart sshd.service
    green " 新端口连接成功后屏蔽原22端口成功"
  fi
  sleep 1s
  read -s -n1 -p "按任意键继续 ... "
  start_menu
}

#清除缓存
function del_cache(){
  rm -f trojan_mult.sh
  rm -f /usr/src/tcp.sh
  rm "$0"
}

#开始菜单
start_menu(){
  clear
  green " ======================================="
  green " 介绍："
  green " 一键安装trojan+BBR+BBR魔改版+BBRplus+Lotserver综合脚本"
  green " 一键配置计划任务、修改SSH端口"
  blue " 声明："
  red " *请不要在任何生产环境使用此脚本"
  red " *仅供技术交流使用，切勿用作非法用途，因使用不当造成麻烦请不要说认得我！"
  green " ======================================="
  echo
  green " 1. 启动trojan安装脚本"
  green " 2. 启动BBR+BBR魔改+BBRplus+Lotserver安装脚本"
  green " 3. 设置计划任务"
  green " 4. 修改SSH端口号"
  green " 5. 关闭SSH默认22端口"
  green " 6. 清除缓存"
  blue " 0. 退出脚本"
  echo
  read -p "请输入数字:" num
  case "$num" in
  1)
  trojan
  ;;
  2)
  net_speed
  ;;
  3)
  crontab_edit
  ;;
  4)
  change_ssh_port
  ;;
  5)
  close_ssh_default_port
  ;;
  6)
  del_cache
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

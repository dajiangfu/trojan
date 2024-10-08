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

#copy from 秋水逸冰 ss scripts
if [[ -f /etc/redhat-release ]]; then
  release_os="centos"
elif cat /etc/issue | grep -Eqi "debian"; then
  release_os="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
  release_os="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
  release_os="centos"
elif cat /proc/version | grep -Eqi "debian"; then
  release_os="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
  release_os="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
  release_os="centos"
fi

if [ "$release_os" == "centos" ]; then
  systemPackage_os="yum"
elif [ "$release_os" == "ubuntu" ]; then
  systemPackage_os="apt"
elif [ "$release_os" == "debian" ]; then
  systemPackage_os="apt"
fi

#修改SSH端口号
function change_ssh_port(){
  cd
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
    if [ "$release_os" == "centos" ]; then
      firewall-cmd --zone=public --add-port=$port_num/tcp --permanent
      firewall-cmd --reload
    elif [ "$release_os" == "ubuntu" ]; then
      ufw allow $port_num
      ufw reload
    fi
    #目前SELinux 支持三种模式，分别是enforcing：强制模式，permissive：宽容模式，disabled：关闭
    if [ -f "/etc/selinux/config" ]; then
      CHECK=$(grep SELINUX= /etc/selinux/config | grep -v "#")
      if [ "$CHECK" != "SELINUX=disabled" ]; then
        read -p "检测到SELinux开启状态，是否继续开启SElinux ?请输入 [Y/n] :" yn
        [ -z "${yn}" ] && yn="y"
        if [[ $yn == [Yy] ]]; then
          green "添加放行$port_num端口规则"
          $systemPackage_os -y install policycoreutils-python
          semanage port -a -t ssh_port_t -p tcp $port_num
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
    systemctl restart sshd.service
    sleep 1s
    red " 稍后请使用修改好的端口连接SSH"
  fi
}

#关闭SSH默认22端口
function close_ssh_default_port(){
  cd
  grep -q "#Port 22" /etc/ssh/sshd_config
  if [ $? -eq 0 ]; then
    red " 端口22已被关闭，无需重复操作"
  else
    sed -i 's/Port 22/#Port 22/g' /etc/ssh/sshd_config
    if [ "$release_os" == "centos" ]; then
      firewall-cmd --reload
    elif [ "$release_os" == "ubuntu" ]; then
      ufw reload
    fi
    systemctl restart sshd.service
    green " 新端口连接成功后屏蔽原22端口成功"
  fi
}

#安装trojan
function trojan(){
  cd
  curl -O https://raw.githubusercontent.com/dajiangfu/trojan/master/trojan_mult.sh
  chmod +x trojan_mult.sh
  ./trojan_mult.sh
}

#设置计划任务
function crontab_edit(){
  cd
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
  chmod +x /etc/crontab
  systemctl enable crond.service
  systemctl start crond.service
  crontab /etc/crontab
  systemctl reload crond.service
  systemctl status crond.service
  blue "编辑后的计划任务："
  echo
  crontab -l
}

#安装BBR+BBR魔改版+BBRplus+Lotserver
function net_speed(){
  cd /usr/src
  wget -N "https://raw.githubusercontent.com/dajiangfu/Linux-NetSpeed/master/tcp.sh"
  chmod +x tcp.sh
  ./tcp.sh
}

#一键全自动安装
function auto_install(){
  read -p "是否关闭SSH默认22端口 ?请输入 [Y/n] :" yn
  [ -z "${yn}" ] && yn="y"
  if [[ $yn == [Yy] ]]; then
    close_ssh_default_port
    sleep 1s
  fi
  read -p "是否安装trojan ?请输入 [Y/n] :" yn
  [ -z "${yn}" ] && yn="y"
  if [[ $yn == [Yy] ]]; then
    trojan
    sleep 1s
  fi
  read -p "是否设置计划任务 ?请输入 [Y/n] :" yn
  [ -z "${yn}" ] && yn="y"
  if [[ $yn == [Yy] ]]; then
    echo
    crontab_edit
    sleep 1s
  fi
  read -p "是否安装加速模块 ?请输入 [Y/n] :" yn
  [ -z "${yn}" ] && yn="y"
  if [[ $yn == [Yy] ]]; then
    echo
    net_speed
    sleep 1s
  fi
}

#清除缓存
function del_cache(){
  cd
  green " 已清除完毕"
  rm -f trojan_mult.sh
  rm -f /usr/src/tcp.sh
  rm -f "$0"
}

#解决centos 7 yum仓库无法使用问题(临时方案一)
function centos7_yum(){
  green "启用 *.repo 中的 baseurl，注释 mirrorlist，将baseurl仓库地址替换为vault.centos.org存档站点"
  sed -i s/^#.*baseurl=http/baseurl=http/g /etc/yum.repos.d/*.repo
  sed -i s/^mirrorlist=http/#mirrorlist=http/g /etc/yum.repos.d/*.repo
  sed -i s/mirror.centos.org/vault.centos.org/g /etc/yum.repos.d/*.repo
  green "清除 YUM 缓存，如有需要可再生成新的缓存"
  yum clean all
  yum makecache
  green "验证可用仓库"
  yum repolist
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
  green " 1. 修改SSH端口号"
  green " 2. 关闭SSH默认22端口"
  green " 3. 启动trojan安装脚本"
  green " 4. 设置计划任务"
  green " 5. 启动BBR+BBR魔改+BBRplus+Lotserver安装脚本"
  green " 6. 全自动执行2-5"
  green " 7. 清除缓存"
  green " 8. 解决centos 7 yum仓库无法使用问题"
  blue " 0. 退出脚本"
  echo
  read -p "请输入数字:" num
  case "$num" in
  1)
  change_ssh_port
  ;;
  2)
  close_ssh_default_port
  sleep 1s
  read -s -n1 -p "按任意键返回菜单 ... "
  start_menu
  ;;
  3)
  trojan
  sleep 1s
  read -s -n1 -p "按任意键返回上级菜单 ... "
  start_menu
  ;;
  4)
  crontab_edit
  sleep 1s
  read -s -n1 -p "按任意键返回菜单 ... "
  start_menu
  ;;
  5)
  net_speed
  sleep 1s
  read -s -n1 -p "按任意键返回上级菜单 ... "
  start_menu
  ;;
  6)
  auto_install
  ;;
  7)
  del_cache
  ;;
  8)
  centos7_yum
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

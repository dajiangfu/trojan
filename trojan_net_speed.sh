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
}

#安装BBR+BBR魔改版+BBRplus+Lotserver
function net_speed(){
  cd /usr/src
  wget -N "https://raw.githubusercontent.com/dajiangfu/Linux-NetSpeed/master/tcp.sh"
  chmod +x tcp.sh
  ./tcp.sh
}

#开始菜单
start_menu(){
  clear
  green " ======================================="
  green " 介绍："
  green " 一键安装trojan+BBR+BBR魔改版+BBRplus+Lotserver综合脚本"
  blue " 声明："
  red " *请不要在任何生产环境使用此脚本"
  red " *仅供技术交流使用，切勿用作非法用途，因使用不当造成麻烦请不要说认得我！"
  green " ======================================="
  echo
  green " 1. 安装trojan"
  green " 2. 安装BBR+BBR魔改版+BBRplus+Lotserver"
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

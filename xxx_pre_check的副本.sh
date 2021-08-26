#!/bin/bash

green(){
        echo -e "\e[32m $1 \e[0m"
}

red(){
     echo -e "\e[31m $1 \e[0m"
}


root_check(){
        if [ $UID -ne 0 ];then
            red "权限不足，请切换至root用户执行..."
            exit 1;
        else
            green "ok..."
        fi
}

data_dir_check(){
    pwd_dir=`pwd`
    if [ ${pwd_dir} == ${data_dir} ];then
        green "ok..."
    else
        red "执行安装的目录路径与预设的路径不匹配...请检查..."
        exit 1
    fi
}

rpm_exist_install_check(){
    if [ `rpm -qa | grep $1 |wc -l` -ne 0 ];then
        green "ok..."
    else
        red "$1 未安装..."
        green "正在走正常流程yum安装$1 相关rpm包..."
        yum install -y $1
        if [ $? == 1 ]; then
            green "$1 yum安装未成功，准备离线安装..."
            rpm -Uvh --force --nodeps ./$2
            if  [ $? == 0 ];then
                green "$1 安装成功..."
            else
                red "$1 未安装成功...请检查..."
                exit 1
            fi
        else
            if [ `rpm -qa | grep $1 |wc -l` -ne 0 ];then
                green "$1 已安装..."
            else
                red "$1 未安装成功...请检查..."
                exit 1
            fi
        fi
    fi
}


green "安装环境预检开始..."

green "检查当前用户是否为root..."
root_check

green "检查当前目录是否为预设的数据目录..."
data_dir_check

green "检查unzip是否安装并确保安装..."
rpm_exist_install_check unzip unzip-6.0-21.el7.x86_64.rpm

#!/bin/bash

#系统信息
# 指令集
unset machine
# 系统
unset release
# 系统版本
unset systemVersion
unset apt
unset apt_no_install_recommends
unset dnf
unset dnf_no_install_recommends
# CPU线程数
unset cpu_thread_num
# 系统时区
unset timezone
# ssh service name
unset ssh_service

#安装配置信息
nginx_version="nginx-1.24.0"
openssl_version="openssl-openssl-3.1.0"
nginx_prefix="/usr/local/nginx"
nginx_config="${nginx_prefix}/conf.d/xray.conf"
nginx_service="/etc/systemd/system/nginx.service"
nginx_is_installed=""

php_version="php-8.2.5"
php_prefix="/usr/local/php"
php_service="/etc/systemd/system/php-fpm.service"
unset php_is_installed

cloudreve_version="3.7.1"
cloudreve_prefix="/usr/local/cloudreve"
cloudreve_service="/etc/systemd/system/cloudreve.service"
unset cloudreve_is_installed

nextcloud_url="https://download.nextcloud.com/server/releases/nextcloud-26.0.0.tar.bz2"

xray_config="/usr/local/etc/xray/config.json"
unset xray_is_installed

temp_dir="/temp_install_update_xray_tls_web"
unset is_installed

#连接配置信息
# 域名列表 两个列表用来区别 www.主域名
unset domain_list
unset true_domain_list
unset domain_config_list
# 域名伪装列表，对应域名列表
unset pretend_list

# TCP配置，0代表禁用，1代表VLESS+TCP+XTLS-Vision+REALITY
unset protocol_1
# REALITY使用的vless uuid
unset xid_1
# REALITY伪装域名类型，0代表未使用，1代表自己的域名(回落到本机Nginx)，2代表他人的域名(直连，不安装Nginx)
unset reality_mode
# REALITY监听端口
unset reality_port
# REALITY(他人域名)的伪装域名(同时作为serverNames和dest)
unset reality_sni
# REALITY的dest(自己的域名为Nginx的unix socket，他人域名为"域名:443")
unset reality_dest
# REALITY x25519私钥/公钥、shortId
unset reality_private_key
unset reality_public_key
unset reality_short_id
# 旧版本遗留的TCP(XTLS/TLS)配置，0代表没有，1代表有(本脚本已不再支持，重新生成配置时会被移除)
unset legacy_tcp_tls
# 旧版本遗留的gRPC/WebSocket inbound数量(本脚本已不再支持，重新生成配置时会被移除)
unset legacy_grpc_ws
# XHTTP配置，0代表禁用，1代表启用 (VLESS+XHTTP+TLS，过CDN，上下行不分离)
unset protocol_4
# xhttp的path
unset xhttp_path
# xhttp协议的vless uuid
unset xid_4
# XHTTP上下行分离，0代表不分离，1代表分离
unset xhttp_split
# XHTTP上下行分离时的上行域名/下行域名
unset xhttp_up_domain
unset xhttp_down_domain

# 现在有没有通过脚本启动swap
using_swap_now=0
# 在更新
unset update
# 在 install_update_xray_tls_web 函数中
in_install_update_xray_tls_web=0

#功能性函数：
#定义几个颜色
purple()                           #基佬紫
{
    echo -e "\\033[35;1m${*}\\033[0m"
}
tyblue()                           #天依蓝
{
    echo -e "\\033[36;1m${*}\\033[0m"
}
green()                            #原谅绿
{
    echo -e "\\033[32;1m${*}\\033[0m"
}
yellow()                           #鸭屎黄
{
    echo -e "\\033[33;1m${*}\\033[0m"
}
red()                              #姨妈红
{
    echo -e "\\033[31;1m${*}\\033[0m"
}
blue()                             #蓝色
{
    echo -e "\\033[34;1m${*}\\033[0m"
}
#检查基本命令
check_base_command()
{
    hash -r
    local i
    local temp_command_list=('bash' 'sh' 'command' 'type' 'hash' 'install' 'true' 'false' 'exit' 'echo' 'test' 'sort' 'sed' 'awk' 'grep' 'cut' 'cd' 'rm' 'cp' 'mv' 'head' 'tail' 'uname' 'tr' 'md5sum' 'cat' 'find' 'wc' 'ls' 'mktemp' 'swapon' 'swapoff' 'mkswap' 'chmod' 'chown' 'chgrp' 'export' 'tar' 'gzip' 'mkdir' 'arch' 'uniq' 'dd' 'env')
    for i in "${temp_command_list[@]}"
    do
        if ! command -V "${i}" > /dev/null; then
            red "命令\"${i}\"未找到"
            red "不是标准的Linux系统"
            exit 1
        fi
    done
}
check_sudo()
{
    if [ "$SUDO_GID" ] && [ "$SUDO_COMMAND" ] && [ "$SUDO_USER" ] && [ "$SUDO_UID" ]; then
        if [ "$SUDO_USER" = "root" ] && [ "$SUDO_UID" = "0" ]; then
            #it's root using sudo, no matter it's using sudo or not, just fine
            return 0
        fi
        if [ -n "$SUDO_COMMAND" ]; then
            #it's a normal user doing "sudo su", or `sudo -i` or `sudo -s`, or `sudo su acmeuser1`
            echo "$SUDO_COMMAND" | grep -- "/bin/su\$" >/dev/null 2>&1 || echo "$SUDO_COMMAND" | grep -- "/bin/su " >/dev/null 2>&1 || grep "^$SUDO_COMMAND\$" /etc/shells >/dev/null 2>&1
            return $?
        fi
        #otherwise
        return 1
    fi
    return 0
}
#版本比较函数
version_ge()
{
    test "$(echo -e "$1\\n$2" | sort -rV | head -n 1)" == "$1"
}
#检查脚本更新
# 注意：原脚本会从第三方仓库(CatherineReyes-byte/Xray-script)下载并覆盖自身，
# 这会把本次修复覆盖掉，且以root身份执行未经审查的远程代码，因此已禁用自动更新。
check_script_update()
{
    return 1
}
#更新脚本
update_script()
{
    yellow "脚本自动更新已被禁用"
    return 0
}
ask_update_script()
{
    return 0
}
ask_update_script_force()
{
    return 0
}
redhat_install()
{
    if $dnf_no_install_recommends -y install "$@"; then
        return 0
    fi


    if $dnf --help | grep -q "\\-\\-enablerepo="; then
        local enable_repo="--enablerepo="
    else
        local enable_repo="--enablerepo "
    fi
    if $dnf --help | grep -q "\\-\\-disablerepo="; then
        local disable_repo="--disablerepo="
    else
        local disable_repo="--disablerepo "
    fi
    if [ $release == centos-stream ]; then
        local epel_repo="epel,epel-next"
    elif [ $release == oracle ]; then
        if version_ge "$systemVersion" 9; then
            local epel_repo="ol9_developer_EPEL"
        elif version_ge "$systemVersion" 8; then
            local epel_repo="ol8_developer_EPEL"
        elif version_ge "$systemVersion" 7; then
            local epel_repo="ol7_developer_EPEL"
        else
            local epel_repo="epel"
        fi
    else
        local epel_repo="epel"
    fi


    if [ $release == fedora ]; then
        if $dnf_no_install_recommends -y ${enable_repo}"remi" install "$@"; then
            return 0
        fi
    else
        if $dnf_no_install_recommends -y ${enable_repo}"${epel_repo}" install "$@"; then
            return 0
        fi
        if $dnf_no_install_recommends -y ${enable_repo}"${epel_repo},powertools" install "$@" || $dnf_no_install_recommends -y ${enable_repo}"${epel_repo},PowerTools" install "$@"; then
            return 0
        fi
    fi
    if $dnf_no_install_recommends -y ${enable_repo}"*" ${disable_repo}"*-debug,*-debuginfo,*-source" install "$@"; then
        return 0
    fi
    if $dnf_no_install_recommends -y ${enable_repo}"*" install "$@"; then
        return 0
    fi
    return 1
}
#安装单个重要依赖
test_important_dependence_installed()
{
    local temp_exit_code=1
    if [ $release == "ubuntu" ] || [ $release == "debian" ] || [ $release == "deepin" ] || [ $release == "other-debian" ]; then
        if LANG="en_US.UTF-8" LANGUAGE="en_US:en" dpkg -s "$1" 2>/dev/null | grep -qi 'status[ '$'\t]*:[ '$'\t]*install[ '$'\t]*ok[ '$'\t]*installed[ '$'\t]*$'; then
            if LANG="en_US.UTF-8" LANGUAGE="en_US:en" apt-mark manual "$1" | grep -qi 'set[ '$'\t]*to[ '$'\t]*manually[ '$'\t]*installed'; then
                temp_exit_code=0
            else
                red "安装依赖 \"$1\" 出错！"
                green  "欢迎进行Bug report(https://github.com/CatherineReyes-byte/Xray-script/issues)，感谢您的支持"
                yellow "按回车键继续或者Ctrl+c退出"
                read -s
            fi
        elif $apt_no_install_recommends -y install "$1"; then
            temp_exit_code=0
        else
            $apt update
            $apt_no_install_recommends -y -f install
            $apt_no_install_recommends -y install "$1" && temp_exit_code=0
        fi
    else
        if rpm -q "$2" > /dev/null 2>&1; then
            if [ "$dnf" == "microdnf" ]; then
                redhat_install dnf
                dnf="dnf"
                dnf_no_install_recommends="dnf --setopt install_weak_deps=0"
            fi
            if [ "$dnf" == "dnf" ]; then
                dnf mark install "$2" && temp_exit_code=0
            else
                yumdb set reason user "$2" && temp_exit_code=0
            fi
        elif redhat_install "$2"; then
            temp_exit_code=0
        fi
    fi
    return $temp_exit_code
}
check_important_dependence_installed()
{
    if ! test_important_dependence_installed "$@"; then
        if [ $release == "ubuntu" ] || [ $release == "debian" ] || [ $release == "deepin" ] || [ $release == "other-debian" ]; then
            red "重要组件\"$1\"安装失败！！"
        else
            red "重要组件\"$2\"安装失败！！"
        fi
        yellow "按回车键继续或者Ctrl+c退出"
        read -s
    fi
}
#安装依赖
install_dependence()
{
    if [ $release == "ubuntu" ] || [ $release == "debian" ] || [ $release == "deepin" ] || [ $release == "other-debian" ]; then
        if ! $apt_no_install_recommends -y install "$@"; then
            $apt update
            $apt_no_install_recommends -y -f install
            if ! $apt_no_install_recommends -y install "$@"; then
                yellow "依赖安装失败！！"
                green  "欢迎进行Bug report(https://github.com/CatherineReyes-byte/Xray-script/issues)，感谢您的支持"
                yellow "按回车键继续或者Ctrl+c退出"
                read -s
            fi
        fi
    else
        if ! redhat_install "$@"; then
            yellow "依赖安装失败！！"
            green  "欢迎进行Bug report(https://github.com/CatherineReyes-byte/Xray-script/issues)，感谢您的支持"
            yellow "按回车键继续或者Ctrl+c退出"
            read -s
        fi
    fi
}
# 防止apt卸载时自动安装替代软件
apt_purge()
{
    local ret_code=0
    mv /etc/apt/sources.list /etc/apt/sources.list.bak
    mv /etc/apt/sources.list.d /etc/apt/sources.list.d.bak
    $apt -y --allow-change-held-packages purge "$@" || ret_code=1
    mv /etc/apt/sources.list.bak /etc/apt/sources.list
    mv /etc/apt/sources.list.d.bak /etc/apt/sources.list.d
    return $ret_code
}
apt_auto_remove_purge()
{
    local ret_code=0
    mv /etc/apt/sources.list /etc/apt/sources.list.bak
    mv /etc/apt/sources.list.d /etc/apt/sources.list.d.bak
    $apt -y --auto-remove --allow-change-held-packages purge "$@" || ret_code=1
    mv /etc/apt/sources.list.bak /etc/apt/sources.list
    mv /etc/apt/sources.list.d.bak /etc/apt/sources.list.d
    return $ret_code
}
#安装epel源
install_epel()
{
    if [ $release == "ubuntu" ] || [ $release == "debian" ] || [ $release == "deepin" ] || [ $release == "other-debian" ]; then
        return
    fi

    local ret=0
    if [ $release == fedora ]; then
        return
    elif [ $release == centos-stream ]; then
        if version_ge "$systemVersion" 10; then
            ret=-1
        elif version_ge "$systemVersion" 9; then
            check_important_dependence_installed "" dnf-plugins-core
            dnf config-manager --set-enabled crb || ret=-1
            redhat_install "https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm" "https://dl.fedoraproject.org/pub/epel/epel-next-release-latest-9.noarch.rpm" || ret=-1
        elif version_ge "$systemVersion" 8; then
            check_important_dependence_installed "" dnf-plugins-core
            dnf config-manager --set-enabled powertools || dnf config-manager --set-enabled PowerTools || ret=-1
            redhat_install epel-release epel-next-release || ret=-1
        else
            ret=-1
        fi
    elif [ $release == centos ]; then
        if version_ge "$systemVersion" 9; then
            ret=-1
        elif version_ge "$systemVersion" 8; then
            check_important_dependence_installed "" dnf-plugins-core
            dnf config-manager --set-enabled powertools || dnf config-manager --set-enabled PowerTools || ret=-1
            redhat_install epel-release || ret=-1
        elif version_ge "$systemVersion" 7; then
            redhat_install epel-release || ret=-1
        elif version_ge "$systemVersion" 6; then
            redhat_install epel-release || ret=-1
        else
            ret=-1
        fi
    elif [ $release == oracle ]; then
        if version_ge "$systemVersion" 9; then
            ret=-1
        elif version_ge "$systemVersion" 8; then
            redhat_install oracle-epel-release-el8 || ret=-1
        elif version_ge "$systemVersion" 7; then
            redhat_install oracle-epel-release-el7 || ret=-1
        else
            ret=-1
        fi
    elif [ $release == rhel ]; then
        if version_ge "$systemVersion" 9; then
            ret=-1
        elif version_ge "$systemVersion" 8; then
            subscription-manager repos --enable "codeready-builder-for-rhel-8-$(arch)-rpms" || ret=-1
            redhat_install "https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm" || ret=-1
        elif version_ge "$systemVersion" 7; then
            subscription-manager repos --enable "rhel-*-optional-rpms" --enable "rhel-*-extras-rpms" --enable "rhel-ha-for-rhel-*-server-rpms" || ret=-1
            redhat_install "https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm" || ret=-1
        else
            ret=-1
        fi
    else
        ############
        if [ $dnf == microdnf ]; then
            check_important_dependence_installed "" dnf
            dnf="dnf"
            dnf_no_install_recommends="dnf --setopt install_weak_deps=0"
        fi
        if [ $dnf == dnf ]; then
            check_important_dependence_installed "" dnf-plugins-core
            dnf config-manager --set-enabled powertools || dnf config-manager --set-enabled PowerTools
        fi
        redhat_install epel-release || ret=-1
    fi

    if [ $ret -ne 0 ]; then
        if [ $release == other-redhat ]; then
            if $dnf repolist epel | grep -q epel; then
                return
            fi
            yellow "epel源安装失败，这可能导致之后的安装失败，也可能没有影响(取决于你的系统的repo包含软件是否丰富)"
            echo
            tyblue "除了安装epel源过程出错，也有可能是因为你使用的系统比较冷门导致安装失败"
            tyblue "这种情况下可以手动安装epel源，之后重新运行脚本"
        else
            yellow "epel源安装失败！！"
        fi
        echo
        green  "欢迎进行Bug report(https://github.com/CatherineReyes-byte/Xray-script/issues)，感谢您的支持"
        yellow "按回车键继续或者Ctrl+c退出"
        read -s
    fi
}
fedora_install_remi()
{
    if [ $release != fedora ]; then
        return
    fi
    if ! redhat_install "https://rpms.remirepo.net/fedora/remi-release-$systemVersion.rpm"; then
        yellow "remi源安装失败！！"
        green  "欢迎进行Bug report(https://github.com/CatherineReyes-byte/Xray-script/issues)，感谢您的支持"
        yellow "按回车键继续或者Ctrl+c退出"
        read -s
    fi
}
#进入工作目录
enter_temp_dir()
{
    local temp_exit_code=0
    cd / || temp_exit_code=1
    rm -rf "$temp_dir" || temp_exit_code=1
    mkdir "$temp_dir" || temp_exit_code=1
    cd "$temp_dir" || temp_exit_code=1
    if [ $temp_exit_code -eq 1 ]; then
        yellow "进入临时目录失败"
        tyblue "可能是之前运行脚本中断导致，建议先重启系统，再运行脚本"
        exit 1
    fi
}
#检查是否需要php
check_need_php()
{
    [ $is_installed -eq 0 ] && return 1
    local i
    for i in "${pretend_list[@]}"
    do
        [ "$i" == "2" ] && return 0
    done
    return 1
}
#检查是否需要cloudreve
check_need_cloudreve()
{
    [ $is_installed -eq 0 ] && return 1
    local i
    for i in "${pretend_list[@]}"
    do
        [ "$i" == "1" ] && return 0
    done
    return 1
}
#检查Nginx更新
check_nginx_update()
{
    local nginx_version_now
    local openssl_version_now
    nginx_version_now="nginx-$(${nginx_prefix}/sbin/nginx -V 2>&1 | grep "^nginx version:" | cut -d / -f 2)"
    openssl_version_now="openssl-openssl-$(${nginx_prefix}/sbin/nginx -V 2>&1 | grep "^built with OpenSSL" | awk '{print $4}')"
    if [ "$nginx_version_now" == "$nginx_version" ] && [ "$openssl_version_now" == "$openssl_version" ]; then
        return 1
    else
        return 0
    fi
}
#检查php更新
check_php_update()
{
    local php_version_now
    php_version_now="php-$(${php_prefix}/bin/php -v | head -n 1 | awk '{print $2}')"
    [ "$php_version_now" == "$php_version" ] && return 1
    return 0
}
swap_on()
{
    if [ $using_swap_now -ne 0 ]; then
        red    "开启swap错误发生"
        green  "欢迎进行Bug report(https://github.com/CatherineReyes-byte/Xray-script/issues)，感谢您的支持"
        yellow "按回车键继续或者Ctrl+c退出"
        read -s
    fi
    local need_swap_size=$(( $1+$(free -m | sed -n 2p | awk '{print $3}')+$(free -m | sed -n 3p | awk '{print $3}')-$(free -m | sed -n 2p | awk '{print $2}')-$(free -m | sed -n 3p | awk '{print $2}') ))
    if [ $need_swap_size -gt 0 ]; then
        tyblue "可用内存不足$1M，自动申请swap。。"
        if dd if=/dev/zero of=${temp_dir}/swap bs=1M count=$need_swap_size && chmod 0600 ${temp_dir}/swap && mkswap ${temp_dir}/swap && swapon ${temp_dir}/swap; then
            using_swap_now=1
        else
            rm -rf ${temp_dir}/swap
            red    "开启swap失败！"
            yellow "可能是机器内存和硬盘空间都不足"
            green  "欢迎进行Bug report(https://github.com/CatherineReyes-byte/Xray-script/issues)，感谢您的支持"
            yellow "按回车键继续或者Ctrl+c退出"
            read -s
        fi
    fi
}
swap_off()
{
    if [ $using_swap_now -eq 1 ]; then
        tyblue "正在恢复swap。。。"
        if swapoff ${temp_dir}/swap && rm -rf ${temp_dir}/swap; then
            using_swap_now=0
        else
            red    "关闭swap失败！"
            green  "欢迎进行Bug report(https://github.com/CatherineReyes-byte/Xray-script/issues)，感谢您的
支持"
            yellow "按回车键继续或者Ctrl+c退出"
            read -s
        fi
    fi
}
#启用/禁用php cloudreve
turn_on_off_php()
{
    if check_need_php; then
        systemctl start php-fpm
        systemctl enable php-fpm
    else
        systemctl stop php-fpm
        systemctl disable php-fpm
    fi
}
turn_on_off_cloudreve()
{
    if check_need_cloudreve; then
        systemctl start cloudreve
        systemctl enable cloudreve
    else
        systemctl stop cloudreve
        systemctl disable cloudreve
    fi
}
let_change_cloudreve_domain()
{
    tyblue "----------- 请打开\"https://${domain_list[$1]}\"修改Cloudreve站点信息 ---------"
    tyblue "  1. 登陆帐号"
    tyblue "  2. 右上角头像 -> 管理面板"
    tyblue "  3. 左侧的参数设置 -> 站点信息"
    tyblue "  4. 站点URL改为\"https://${domain_list[$1]}\" -> 往下拉点击保存"
    sleep 15s
    echo -e "\\n\\n"
    tyblue "按两次回车键以继续。。。"
    read -s
    read -s
}
ask_if()
{
    local choice=""
    while [ "$choice" != "y" ] && [ "$choice" != "n" ]
    do
        tyblue "$1"
        read choice
    done
    [ $choice == y ] && return 0
    return 1
}
#卸载函数
#下载并运行Xray官方安装脚本 参数：传给官方脚本的参数
#(不使用 bash -c "$(curl ...)"：curl失败时它会得到空脚本并返回成功，导致误判安装成功)
run_xray_install_script()
{
    local script_file
    script_file="$(mktemp)" || return 1
    if ! curl -fsSL --retry 3 -o "$script_file" https://github.com/XTLS/Xray-install/raw/main/install-release.sh || [ ! -s "$script_file" ]; then
        red "下载Xray官方安装脚本失败"
        rm -f "$script_file"
        return 1
    fi
    bash "$script_file" "$@"
    local ret=$?
    rm -f "$script_file"
    return $ret
}
remove_xray()
{
    if ! run_xray_install_script remove --purge; then
        systemctl stop xray
        systemctl disable xray
        rm -rf /usr/local/bin/xray
        rm -rf /usr/local/etc/xray
        rm -rf /etc/systemd/system/xray.service
        rm -rf /etc/systemd/system/xray.service.d
        rm -rf /etc/systemd/system/xray@.service
        rm -rf /etc/systemd/system/xray@.service.d
        rm -rf /var/log/xray
        systemctl daemon-reload
    fi
    xray_is_installed=0
    reality_direct=0
    is_installed=0
}
remove_nginx()
{
    systemctl stop nginx
    systemctl disable nginx
    rm -rf $nginx_service
    systemctl daemon-reload
    rm -rf ${nginx_prefix}
    nginx_is_installed=0
    is_installed=0
}
remove_php()
{
    systemctl stop php-fpm
    systemctl disable php-fpm
    rm -rf $php_service
    systemctl daemon-reload
    rm -rf ${php_prefix}
    php_is_installed=0
}
remove_cloudreve()
{
    systemctl stop cloudreve
    systemctl disable cloudreve
    rm -rf $cloudreve_service
    systemctl daemon-reload
    rm -rf ${cloudreve_prefix}
    cloudreve_is_installed=0
}
#备份域名伪装网站
backup_domains_web()
{
    local i
    mkdir "${temp_dir}/domain_backup"
    for i in "${true_domain_list[@]}"
    do
        if [ "$1" == "cp" ]; then
            cp -rf "${nginx_prefix}/html/${i}" "${temp_dir}/domain_backup" 2>/dev/null
        else
            mv "${nginx_prefix}/html/${i}" "${temp_dir}/domain_backup" 2>/dev/null
        fi
    done
}
#获取配置信息
get_config_info()
{
    [ $is_installed -eq 0 ] && return
    local temp
    local main_clients
    local ngc="$nginx_config"
    #REALITY(他人域名)直连模式没有Nginx配置文件
    [ -e "$ngc" ] || ngc=/dev/null
    #旧版本遗留的gRPC/WebSocket inbound(本脚本已不再支持)
    legacy_grpc_ws=$(grep -Ec '"network"[ '$'\t]*:[ '$'\t]*"(ws|grpc)"' $xray_config)
    #XHTTP inbound位于主inbound之后
    if grep -q '"network"[ '$'\t]*:[ '$'\t]*"xhttp"' $xray_config; then
        protocol_4=1
        xhttp_path="$(grep -A1 '"xhttpSettings"' $xray_config | grep '"path"' | head -n 1 | cut -d : -f 2 | cut -d \" -f 2)"
        xid_4="$(grep '"id"' $xray_config | tail -n 1 | cut -d : -f 2 | cut -d \" -f 2)"
    else
        protocol_4=0
    fi
    #REALITY(VLESS + TCP + XTLS-Vision)
    legacy_tcp_tls=0
    reality_mode=0
    if grep -q '"security"[ '$'\t]*:[ '$'\t]*"reality"' $xray_config; then
        protocol_1=1
        xid_1="$(grep '"id"' $xray_config | head -n 1 | cut -d : -f 2 | cut -d \" -f 2)"
        reality_port="$(grep '"port"' $xray_config | head -n 1 | tr -cd '0-9')"
        reality_dest="$(grep '"dest"' $xray_config | head -n 1 | cut -d \" -f 4)"
        reality_private_key="$(grep '"privateKey"' $xray_config | head -n 1 | cut -d \" -f 4)"
        reality_short_id="$(grep -A1 '"shortIds"' $xray_config | tail -n 1 | cut -d \" -f 2)"
        reality_sni="$(grep -A1 '"serverNames"' $xray_config | tail -n 1 | cut -d \" -f 2)"
        if [ "$reality_dest" == "/dev/shm/nginx/reality.sock" ]; then
            reality_mode=1
        else
            reality_mode=2
        fi
        reality_public_key="$(xray x25519 -i "$reality_private_key" 2>/dev/null | parse_x25519 public)"
    else
        protocol_1=0
        #主inbound带有clients，说明是旧版本的TCP(XTLS/TLS)配置
        main_clients=$(( $(grep -c '"clients"' $xray_config) - legacy_grpc_ws - protocol_4 ))
        [ $main_clients -gt 0 ] && legacy_tcp_tls=1
    fi
    unset domain_list
    unset true_domain_list
    unset domain_config_list
    unset pretend_list
    domain_list=($(grep "^#domain_list=" $ngc | cut -d = -f 2))
    true_domain_list=($(grep "^#true_domain_list=" $ngc | cut -d = -f 2))
    domain_config_list=($(grep "^#domain_config_list=" $ngc | cut -d = -f 2))
    pretend_list=($(grep "^#pretend_list=" $ngc | cut -d = -f 2))
    #XHTTP上下行分离的上行/下行域名(仅分离模式下存在)
    xhttp_up_domain="$(grep "^#xhttp_up_domain=" $ngc | head -n 1 | cut -d = -f 2)"
    xhttp_down_domain="$(grep "^#xhttp_down_domain=" $ngc | head -n 1 | cut -d = -f 2)"
    if [ $protocol_4 -ne 0 ] && [ -n "$xhttp_up_domain" ] && [ -n "$xhttp_down_domain" ]; then
        xhttp_split=1
    else
        xhttp_split=0
        xhttp_up_domain=""
        xhttp_down_domain=""
    fi
}
gen_cflags()
{
    cflags=('-g0' '-O3')
    if gcc -v --help 2>&1 | grep -qw "\\-fstack\\-reuse"; then
        cflags+=('-fstack-reuse=all')
    fi
    if gcc -v --help 2>&1 | grep -qw "\\-fdwarf2\\-cfi\\-asm"; then
        cflags+=('-fdwarf2-cfi-asm')
    fi
    if gcc -v --help 2>&1 | grep -qw "\\-fplt"; then
        cflags+=('-fplt')
    fi
    if gcc -v --help 2>&1 | grep -qw "\\-ftrapv"; then
        cflags+=('-fno-trapv')
    fi
    if gcc -v --help 2>&1 | grep -qw "\\-fexceptions"; then
        cflags+=('-fno-exceptions')
    elif gcc -v --help 2>&1 | grep -qw "\\-fhandle\\-exceptions"; then
        cflags+=('-fno-handle-exceptions')
    fi
    if gcc -v --help 2>&1 | grep -qw "\\-funwind\\-tables"; then
        cflags+=('-fno-unwind-tables')
    fi
    if gcc -v --help 2>&1 | grep -qw "\\-fasynchronous\\-unwind\\-tables"; then
        cflags+=('-fno-asynchronous-unwind-tables')
    fi
    if gcc -v --help 2>&1 | grep -qw "\\-fstack\\-check"; then
        cflags+=('-fno-stack-check')
    fi
    if gcc -v --help 2>&1 | grep -qw "\\-fstack\\-clash\\-protection"; then
        cflags+=('-fno-stack-clash-protection')
    fi
    if gcc -v --help 2>&1 | grep -qw "\\-fstack\\-protector"; then
        cflags+=('-fno-stack-protector')
    fi
    if gcc -v --help 2>&1 | grep -qw "\\-fcf\\-protection="; then
        cflags+=('-fcf-protection=none')
    fi
    if gcc -v --help 2>&1 | grep -qw "\\-fsplit\\-stack"; then
        cflags+=('-fno-split-stack')
    fi
    if gcc -v --help 2>&1 | grep -qw "\\-fsanitize"; then
        > temp.c
        if gcc -E -fno-sanitize=all temp.c >/dev/null 2>&1; then
            cflags+=('-fno-sanitize=all')
        fi
        rm temp.c
    fi
    if gcc -v --help 2>&1 | grep -qw "\\-finstrument\\-functions"; then
        cflags+=('-fno-instrument-functions')
    fi
}
gen_cxxflags()
{
    cxxflags=('-g0' '-O3')
    if g++ -v --help 2>&1 | grep -qw "\\-fstack\\-reuse"; then
        cxxflags+=('-fstack-reuse=all')
    fi
    if g++ -v --help 2>&1 | grep -qw "\\-fdwarf2\\-cfi\\-asm"; then
        cxxflags+=('-fdwarf2-cfi-asm')
    fi
    if g++ -v --help 2>&1 | grep -qw "\\-fplt"; then
        cxxflags+=('-fplt')
    fi
    if g++ -v --help 2>&1 | grep -qw "\\-ftrapv"; then
        cxxflags+=('-fno-trapv')
    fi
    if g++ -v --help 2>&1 | grep -qw "\\-fstack\\-check"; then
        cxxflags+=('-fno-stack-check')
    fi
    if g++ -v --help 2>&1 | grep -qw "\\-fstack\\-clash\\-protection"; then
        cxxflags+=('-fno-stack-clash-protection')
    fi
    if g++ -v --help 2>&1 | grep -qw "\\-fstack\\-protector"; then
        cxxflags+=('-fno-stack-protector')
    fi
    if g++ -v --help 2>&1 | grep -qw "\\-fcf\\-protection="; then
        cxxflags+=('-fcf-protection=none')
    fi
    if g++ -v --help 2>&1 | grep -qw "\\-fsplit\\-stack"; then
        cxxflags+=('-fno-split-stack')
    fi
    if g++ -v --help 2>&1 | grep -qw "\\-fsanitize"; then
        > temp.cpp
        if g++ -E -fno-sanitize=all temp.cpp >/dev/null 2>&1; then
            cxxflags+=('-fno-sanitize=all')
        fi
        rm temp.cpp
    fi
    if g++ -v --help 2>&1 | grep -qw "\\-finstrument\\-functions"; then
        cxxflags+=('-fno-instrument-functions')
    fi
    if g++ -v --help 2>&1 | grep -qw "\\-fvtable\\-verify"; then
        cxxflags+=('-fvtable-verify=none')
    fi
}

check_base_command
if [[ ! -f '/etc/os-release' ]]; then
    red "系统版本太老，Xray官方脚本不支持"
    exit 1
fi
if [[ -f /.dockerenv ]] || grep -q 'docker\|lxc' /proc/1/cgroup && [[ "$(type -P systemctl)" ]]; then
    true
elif [[ -d /run/systemd/system ]] || grep -q systemd <(ls -l /sbin/init); then
    true
else
    red "仅支持使用systemd的系统！"
    exit 1
fi
if [[ ! -d /dev/shm ]]; then
    red "/dev/shm不存在，不支持的系统"
    exit 1
fi
if [[ "$(type -P apt)" ]] || [ "$(type -P apt-get)" ]; then
    if [[ "$(type -P dnf)" ]] || [[ "$(type -P microdnf)" ]] || [[ "$(type -P yum)" ]]; then
        red "同时存在 apt/apt-get 和 dnf/microdnf/yum"
        red "不支持的系统！"
        exit 1
    fi
    release="other-debian"
    dnf="true"
    dnf_no_install_recommends="true"
    if [[ "$(type -P apt)" ]]; then
        apt="apt"
    else
        apt="apt-get"
    fi
    apt_no_install_recommends="$apt --no-install-recommends"
elif [[ "$(type -P dnf)" ]] || [[ "$(type -P microdnf)" ]] || [[ "$(type -P yum)" ]]; then
    release="other-redhat"
    apt="true"
    apt_no_install_recommends="true"
    if [[ "$(type -P dnf)" ]]; then
        dnf="dnf"
    elif [[ "$(type -P microdnf)" ]]; then
        dnf="microdnf"
    else
        dnf="yum"
    fi
    if $dnf --help | grep -q "\\-\\-setopt="; then
        dnf_no_install_recommends="$dnf --setopt=install_weak_deps=0"
    else
        dnf_no_install_recommends="$dnf --setopt install_weak_deps=0"
    fi
else
    red "apt,apt-get,dnf,microdnf,yum命令均不存在"
    red "不支持的系统"
    exit 1
fi
# if [[ -z "${BASH_SOURCE[0]}" ]]; then
#     red "请以文件的形式运行脚本，或不支持的bash版本"
#     exit 1
# fi
if [ "$EUID" != "0" ]; then
    red "请用root用户运行此脚本！！"
    exit 1
fi
if ! check_sudo; then
    yellow "检测到正在使用sudo！"
    yellow "acme.sh不支持sudo，请使用root用户运行此脚本"
    tyblue "详情请见：https://github.com/acmesh-official/acme.sh/wiki/sudo"
    exit 1
fi
if systemctl cat ssh > /dev/null; then
    ssh_service="ssh"
else
    ssh_service="sshd"
fi
[ -e $nginx_config ] && nginx_is_installed=1 || nginx_is_installed=0
[ -e ${php_prefix}/php-fpm.service.default ] && php_is_installed=1 || php_is_installed=0
[ -e ${cloudreve_prefix}/cloudreve.db ] && cloudreve_is_installed=1 || cloudreve_is_installed=0
[ -e /usr/local/bin/xray ] && xray_is_installed=1 || xray_is_installed=0
([ $xray_is_installed -eq 1 ] && [ $nginx_is_installed -eq 1 ]) && is_installed=1 || is_installed=0
#REALITY(他人域名)直连模式：只有Xray，没有Nginx
reality_direct=0
if [ $xray_is_installed -eq 1 ] && [ $nginx_is_installed -eq 0 ] && [ -e $xray_config ] && grep -q '"security"[ '$'\t]*:[ '$'\t]*"reality"' $xray_config; then
    reality_direct=1
    is_installed=1
fi
cpu_thread_num="$(grep '^processor' /proc/cpuinfo | uniq | wc -l)"
if [ -z "$cpu_thread_num" ] || [ $cpu_thread_num -lt 1 ]; then
    red "获取CPU线程数失败！"
    exit 1
fi
case "$(uname -m)" in
    'amd64' | 'x86_64')
        machine='amd64'
        ;;
    'armv5tel')
        machine='armv5'
        ;;
    'armv6l')
        machine='armv6'
        ;;
    'armv7' | 'armv7l')
        machine='armv7'
        ;;
    'armv8' | 'aarch64')
        machine='arm64'
        ;;
    *)
        machine=''
        ;;
esac

#获取系统版本信息
get_system_info()
{
    timezone="$(ls -l /etc/localtime | awk -F zoneinfo/ '{print $NF}')"
    if [[ ! -L /etc/localtime ]] || [ "$timezone" == "" ]; then
        yellow "获取时区失败！"
        green  "欢迎进行Bug report(https://github.com/CatherineReyes-byte/Xray-script/issues)，感谢您的支持"
        yellow "按回车键继续或者Ctrl+c退出"
        read -s
    fi
    if bash -c "echo $(grep '^[ '$'\t]*ID[ '$'\t]*=' /etc/os-release | cut -d = -f 2-)" | grep -qiw ubuntu; then
        release="ubuntu"
    elif bash -c "echo $(grep '^[ '$'\t]*ID[ '$'\t]*=' /etc/os-release | cut -d = -f 2-)" | grep -qiw debian; then
        release="debian"
    elif bash -c "echo $(grep '^[ '$'\t]*ID[ '$'\t]*=' /etc/os-release | cut -d = -f 2-)" | grep -qiw deepin; then
        release="deepin"
    elif bash -c "echo $(grep '^[ '$'\t]*ID[ '$'\t]*=' /etc/os-release | cut -d = -f 2-)" | grep -qiw centos; then
        if bash -c "echo $(grep '^[ '$'\t]*NAME[ '$'\t]*=' /etc/os-release | cut -d = -f 2-)" | grep -qiw stream; then
            release="centos-stream"
        else
            release="centos"
        fi
    elif bash -c "echo $(grep '^[ '$'\t]*ID[ '$'\t]*=' /etc/os-release | cut -d = -f 2-)" | grep -qiw fedora; then
        release="fedora"
    elif bash -c "echo $(grep '^[ '$'\t]*NAME[ '$'\t]*=' /etc/os-release | cut -d = -f 2-)" | grep -qiw oracle; then
        release="oracle"
    elif bash -c "echo $(grep '^[ '$'\t]*ID[ '$'\t]*=' /etc/os-release | cut -d = -f 2-)" | grep -qiw rhel; then
        release="rhel"
    elif bash -c "echo $(grep '^[ '$'\t]*ID[ '$'\t]*=' /etc/os-release | cut -d = -f 2-)" | grep -qiw redhatenterprise; then
        release="rhel"
    fi
    systemVersion="$(bash -c "echo $(grep '^[ '$'\t]*VERSION_ID[ '$'\t]*=' /etc/os-release | cut -d = -f 2-)")"
    if [ "$(bash -c "echo $(grep '^[ '$'\t]*ID[ '$'\t]*=' /etc/os-release | cut -d = -f 2-)")" == "" ] || [ "$systemVersion" == "" ]; then
        yellow "获取系统信息失败！"
        green  "欢迎进行Bug report(https://github.com/CatherineReyes-byte/Xray-script/issues)，感谢您的支持"
        yellow "按回车键继续或者Ctrl+c退出"
        read -s
    fi
}

#检查TCP 80端口和443端口是否被占用
#按当前传输协议检查端口占用：REALITY检查"80(自己的域名需要)+监听端口"，其它模式检查80和443
check_port_for_mode()
{
    if [ "$protocol_1" == "1" ]; then
        if [ "$reality_mode" == "1" ]; then
            check_port 80 "$reality_port"
        else
            check_port "$reality_port"
        fi
    else
        check_port
    fi
}
check_port()
{
    green "正在检查端口占用。。。"
    local xray_status=0
    local nginx_status=0
    systemctl -q is-active xray && xray_status=1 && systemctl stop xray
    systemctl -q is-active nginx && nginx_status=1 && systemctl stop nginx
    ([ $xray_status -eq 1 ] || [ $nginx_status -eq 1 ]) && sleep 2s
    local check_list=('80' '443')
    [ $# -ne 0 ] && check_list=("$@")
    local i
    for i in "${check_list[@]}"
    do
        if ss -natl | awk '{print $4}'  | awk -F : '{print $NF}' | grep -E "^[0-9]+$" | grep -wq "${i}"; then
            red "TCP:${i}端口被占用！"
            yellow "请用 lsof -i:${i} 命令检查"
            exit 1
        fi
    done
    [ $xray_status -eq 1 ] && systemctl start xray
    [ $nginx_status -eq 1 ] && systemctl start nginx
}

#检查Nginx是否已通过apt/dnf/yum安装
check_nginx_installed_system()
{
    if [[ ! -f /usr/lib/systemd/system/nginx.service ]] && [[ ! -f /lib/systemd/system/nginx.service ]]; then
        return 0
    fi
    red    "------------检测到Nginx已安装，并且会与此脚本冲突------------"
    yellow " 如果您不记得之前有安装过Nginx，那么可能是使用别的一键脚本时安装的"
    yellow " 建议使用纯净的系统运行此脚本"
    echo
    ! ask_if "是否尝试卸载？(y/n)" && exit 0
    apt_purge '^nginx' '^libnginx'
    $dnf -y remove 'nginx*'
    if [[ ! -f /usr/lib/systemd/system/nginx.service ]] && [[ ! -f /lib/systemd/system/nginx.service ]]; then
        return 0
    fi
    red "卸载失败！"
    yellow "请尝试更换系统，建议使用Ubuntu最新版系统"
    green  "欢迎进行Bug report(https://github.com/CatherineReyes-byte/Xray-script/issues)，感谢您的支持"
    exit 1
}

#检查SELinux
check_SELinux()
{
    turn_off_selinux()
    {
        if command -V setenforce >/dev/null 2>&1; then
            local selinux_utils_is_installed=1
        else
            local selinux_utils_is_installed=0
            check_important_dependence_installed selinux-utils libselinux-utils
        fi
        setenforce 0
        sed -i 's/^[ \t]*SELINUX[ \t]*=[ \t]*enforcing[ \t]*$/SELINUX=disabled/g' /etc/sysconfig/selinux
        sed -i 's/^[ \t]*SELINUX[ \t]*=[ \t]*enforcing[ \t]*$/SELINUX=disabled/g' /etc/selinux/config
        if [ $selinux_utils_is_installed -eq 0 ]; then
            $dnf -y remove libselinux-utils
            apt_purge selinux-utils
        fi
    }
    if getenforce 2>/dev/null | grep -wqi Enforcing || grep -Eq '^[ '$'\t]*SELINUX[ '$'\t]*=[ '$'\t]*enforcing[ '$'\t]*$' /etc/sysconfig/selinux 2>/dev/null || grep -Eq '^[ '$'\t]*SELINUX[ '$'\t]*=[ '$'\t]*enforcing[ '$'\t]*$' /etc/selinux/config 2>/dev/null; then
        yellow "检测到SELinux已开启，脚本可能无法正常运行"
        if ask_if "尝试关闭SELinux?(y/n)"; then
            turn_off_selinux
        else
            exit 0
        fi
    fi
}

#配置sshd
check_ssh_timeout()
{
    if grep -q "#This file has been edited by Xray-TLS-Web-setup-script" /etc/ssh/sshd_config; then
        return 0
    fi
    echo -e "\\n\\n\\n"
    tyblue "------------------------------------------"
    tyblue " 安装可能需要比较长的时间"
    tyblue " 如果中途断开连接将会很麻烦"
    tyblue " 设置ssh连接超时时间将有效降低断连可能性"
    echo
    ! ask_if "是否设置ssh连接超时时间？(y/n)" && return 0
    sed -i '/^[ \t]*ClientAliveInterval[ \t]/d' /etc/ssh/sshd_config
    sed -i '/^[ \t]*ClientAliveCountMax[ \t]/d' /etc/ssh/sshd_config
    echo >> /etc/ssh/sshd_config
    echo "ClientAliveInterval 30" >> /etc/ssh/sshd_config
    echo "ClientAliveCountMax 60" >> /etc/ssh/sshd_config
    echo "#This file has been edited by Xray-TLS-Web-setup-script" >> /etc/ssh/sshd_config
    systemctl restart $ssh_service
    green  "----------------------配置完成----------------------"
    tyblue " 请重新连接服务器以让配置生效"
    if [ $in_install_update_xray_tls_web -eq 1 ]; then
        yellow " 重新连接服务器后，请再次运行脚本完成剩余部分的安装/升级"
        yellow " 再次运行脚本时，重复之前选过的选项即可"
        yellow " 按回车键退出。。。。"
        read -s
    fi
    exit 0
}

#删除防火墙和阿里云盾
uninstall_firewall()
{
    green "正在删除防火墙。。。"
    ufw disable
    apt_purge firewalld
    apt_purge ufw
    systemctl stop firewalld
    systemctl disable firewalld
    $dnf -y remove firewalld
    green "正在删除阿里云盾和腾讯云盾 (仅对阿里云和腾讯云服务器有效)。。。"
    #阿里云盾
    pkill -9 assist_daemon
    rm -rf /usr/local/share/assist-daemon
    systemctl stop CmsGoAgent
    systemctl disable CmsGoAgent
    systemctl stop cloudmonitor
    /etc/rc.d/init.d/cloudmonitor remove
    rm -rf /usr/local/cloudmonitor
    rm -rf /etc/systemd/system/CmsGoAgent.service
    systemctl daemon-reload
    #aliyun-assist
    systemctl stop AssistDaemon
    systemctl disable AssistDaemon
    systemctl stop aliyun
    systemctl disable aliyun
    apt_purge aliyun-assist
    $dnf -y remove aliyun_assist
    rm -rf /usr/local/share/aliyun-assist
    rm -rf /usr/sbin/aliyun_installer
    rm -rf /usr/sbin/aliyun-service
    rm -rf /usr/sbin/aliyun-service.backup
    rm -rf /etc/systemd/system/aliyun.service
    rm -rf /etc/systemd/system/AssistDaemon.service
    systemctl daemon-reload
    #AliYunDun aegis
    pkill -9 AliYunDunUpdate
    pkill -9 AliYunDun
    pkill -9 AliHids
    /etc/init.d/aegis uninstall
    rm -rf /usr/local/aegis
    rm -rf /etc/init.d/aegis
    rm -rf /etc/rc2.d/S80aegis
    rm -rf /etc/rc3.d/S80aegis
    rm -rf /etc/rc4.d/S80aegis
    rm -rf /etc/rc5.d/S80aegis

    #腾讯云盾
    /usr/local/qcloud/stargate/admin/uninstall.sh
    /usr/local/qcloud/YunJing/uninst.sh
    /usr/local/qcloud/monitor/barad/admin/uninstall.sh
    systemctl daemon-reload
    systemctl stop YDService
    systemctl disable YDService
    rm -rf /lib/systemd/system/YDService.service
    systemctl daemon-reload
    systemctl stop tat_agent
    systemctl disable tat_agent
    rm -rf /etc/systemd/system/tat_agent.service
    systemctl daemon-reload
    sed -i 's#/usr/local/qcloud#rcvtevyy4f5d#g' /etc/rc.local
    sed -i '/rcvtevyy4f5d/d' /etc/rc.local
    rm -rf $(find /etc/udev/rules.d -iname "*qcloud*" 2>/dev/null)
    pkill -9 watchdog.sh
    pkill -9 secu-tcs-agent
    pkill -9 YDService
    pkill -9 YDLive
    pkill -9 sgagent
    pkill -9 tat_agent
    pkill -9 /usr/local/qcloud
    pkill -9 barad_agent
    kill -s 9 "$(ps -aux | grep '/usr/local/qcloud/nv//nv_driver_install_helper\.sh' | awk '{print $2}')"
    rm -rf /usr/local/qcloud
    rm -rf /usr/local/sa
    rm -rf /usr/local/yd.socket.client
    rm -rf /usr/local/yd.socket.server
    mkdir /usr/local/qcloud
    mkdir /usr/local/qcloud/action
    mkdir /usr/local/qcloud/action/login_banner.sh
    mkdir /usr/local/qcloud/action/action.sh
    if [[ "$(type -P uname)" ]] && uname -a | grep solaris >/dev/null; then
        crontab -l | sed "/qcloud/d" | crontab --
    else
        crontab -l | sed "/qcloud/d" | crontab -
    fi

    # Huawei Cloud
    rm -rf /CloudResetPwdUpdateAgent
    rm -rf /etc/init.d/HSSInstall
    rm -rf /usr/local/uniagent
    pkill -9 uniagent
}

#升级系统组件
#安装脚本运行所需的基础依赖：curl、jq、openssl、qrencode
install_base_dependence()
{
    green "正在检查/安装基础依赖(curl、jq、openssl、qrencode)。。。"
    check_important_dependence_installed curl curl
    check_important_dependence_installed jq jq
    check_important_dependence_installed openssl openssl
    check_important_dependence_installed qrencode qrencode
}
doupdate()
{
    updateSystem()
    {
        check_important_dependence_installed "ubuntu-release-upgrader-core"
        echo -e "\\n\\n\\n"
        tyblue "------------------请选择升级系统版本--------------------"
        tyblue " 1. beta版(测试版)          当前版本号：22.10"
        tyblue " 2. release版(稳定版)       当前版本号：22.10"
        tyblue " 3. LTS版(长期支持版)       当前版本号：22.04"
        tyblue " 0. 不升级系统"
        tyblue "-------------------------注意事项-------------------------"
        yellow " 1.升级过程中遇到问话/对话框，如果不清楚，请选择yes/y/第一个选项"
        yellow " 2.升级系统可能需要15分钟或更久"
        yellow " 3.有的时候不能一次性更新到所选择的版本，可能要更新多次"
        yellow " 4.升级系统后以下配置可能会恢复系统默认配置："
        yellow "     ssh端口   ssh超时时间    bbr加速(恢复到关闭状态)"
        tyblue "----------------------------------------------------------"
        green  " 您现在的系统版本是：$systemVersion"
        tyblue "----------------------------------------------------------"
        echo
        choice=""
        while [[ ! "$choice" =~ ^(0|[1-9][0-9]*)$ ]] || ((choice>3))
        do
            read -p "您的选择是：" choice
        done
        if [ $choice -ne 0 ]; then
            if ! [[ "$(grep -i '^[ '$'\t]*port[ '$'\t]' /etc/ssh/sshd_config | awk '{print $2}')" =~ ^("22"|)$ ]]; then
                red "检测到ssh端口号被修改"
                red "升级系统后ssh端口号可能恢复默认值(22)"
                yellow "按回车键继续。。。"
                read -s
            fi
            if [ $in_install_update_xray_tls_web -eq 1 ]; then
                echo
                tyblue "提示：即将开始升级系统"
                yellow " 升级完系统后服务器将重启，重启后，请再次运行脚本完成 Xray-TLS+Web 剩余部分的安装/升级"
                yellow " 再次运行脚本时，重复之前选过的选项即可"
                echo
                sleep 2s
                yellow "按回车键以继续。。。"
                read -s
            fi
        fi
        local i
        for ((i=0;i<2;i++))
        do
            sed -i '/^[ \t]*Prompt[ \t]*=/d' /etc/update-manager/release-upgrades
            echo 'Prompt=normal' >> /etc/update-manager/release-upgrades
            case "$choice" in
                1)
                    do-release-upgrade -d -m server
                    do-release-upgrade -d -m server
                    sed -i 's/Prompt=normal/Prompt=lts/' /etc/update-manager/release-upgrades
                    do-release-upgrade -d -m server
                    do-release-upgrade -d -m server
                    sed -i 's/Prompt=lts/Prompt=normal/' /etc/update-manager/release-upgrades
                    do-release-upgrade -p -m server
                    do-release-upgrade -p -m server
                    sed -i 's/Prompt=normal/Prompt=lts/' /etc/update-manager/release-upgrades
                    do-release-upgrade -p -m server
                    do-release-upgrade -p -m server
                    ;;
                2)
                    do-release-upgrade -m server
                    do-release-upgrade -m server
                    ;;
                3)
                    sed -i 's/Prompt=normal/Prompt=lts/' /etc/update-manager/release-upgrades
                    do-release-upgrade -m server
                    do-release-upgrade -m server
                    ;;
            esac
            $apt -y --purge autoremove
            $apt update
            $apt -y --purge autoremove
            $apt -y --auto-remove --purge --no-install-recommends full-upgrade
            $apt -y --purge autoremove
            $apt clean
        done
    }
    while ((1))
    do
        echo -e "\\n\\n\\n"
        tyblue "-----------------------是否更新系统组件？-----------------------"
        green  " 1. 更新已安装软件，并升级系统 (Ubuntu专享)"
        green  " 2. 仅更新已安装软件"
        red    " 3. 不更新"
        if [ $release == "ubuntu" ] && (($(free -m | sed -n 2p | awk '{print $2}')<400)); then
            red "检测到内存过小，升级系统可能导致无法开机，请谨慎选择"
        fi
        echo
        choice=""
        while [ "$choice" != "1" ] && [ "$choice" != "2" ] && [ "$choice" != "3" ]
        do
            read -p "您的选择是：" choice
        done
        if [ $release == "ubuntu" ] || [ $choice -ne 1 ]; then
            break
        fi
        echo
        yellow " 更新系统仅支持Ubuntu！"
        sleep 3s
    done
    if [ $choice -eq 1 ]; then
        updateSystem
        $apt -y --purge autoremove
        $apt clean
    elif [ $choice -eq 2 ]; then
        tyblue "-----------------------即将开始更新-----------------------"
        yellow " 更新过程中遇到问话/对话框，如果不明白，选择yes/y/第一个选项"
        yellow " 按回车键继续。。。"
        read -s
        $apt -y --purge autoremove
        $apt update
        $apt -y --purge autoremove
        $apt -y --auto-remove --purge --no-install-recommends full-upgrade
        $apt -y --purge autoremove
        $apt clean
        $dnf -y autoremove
        $dnf_no_install_recommends -y upgrade
        $dnf -y autoremove
        $dnf clean all
    fi
    install_base_dependence
}

#安装bbr
#启用Linux内核原生BBR(BBRv1) + fq；不安装第三方内核，不下载第三方脚本
#成功返回0，失败返回1
enable_native_bbr()
{
    local kernel_version
    kernel_version="$(uname -r | cut -d - -f 1)"
    if ! version_ge "$kernel_version" "4.9"; then
        red    "当前内核版本为${kernel_version}，低于4.9，不支持原生BBR"
        yellow "请先通过发行版自带的方式升级内核后再启用(本脚本不再安装第三方内核)"
        return 1
    fi
    modprobe tcp_bbr 2>/dev/null
    modprobe sch_fq 2>/dev/null
    if ! grep -qw bbr /proc/sys/net/ipv4/tcp_available_congestion_control 2>/dev/null; then
        red    "当前内核没有提供bbr(tcp_bbr模块不可用)"
        yellow "常见原因：OpenVZ/LXC等容器虚拟化无法修改内核参数，或内核编译时未包含BBR"
        return 1
    fi
    #清理旧配置，避免冲突(/etc/sysctl.conf在sysctl --system中最后生效)
    if [ -f /etc/sysctl.conf ]; then
        sed -i '/^[ \t]*net\.core\.default_qdisc[ \t]*=/d;/^[ \t]*net\.ipv4\.tcp_congestion_control[ \t]*=/d' /etc/sysctl.conf
    fi
    mkdir -p /etc/sysctl.d
    cat > /etc/sysctl.d/99-xray-bbr.conf <<EOF
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
EOF
    mkdir -p /etc/modules-load.d
    printf 'tcp_bbr\nsch_fq\n' > /etc/modules-load.d/xray-bbr.conf
    sysctl -p /etc/sysctl.d/99-xray-bbr.conf >/dev/null 2>&1 || sysctl --system >/dev/null 2>&1
    #让当前默认网卡立即使用fq(默认队列算法只对之后新建的队列生效)
    if command -v tc >/dev/null 2>&1; then
        local dev
        dev="$(ip route show default 2>/dev/null | awk '/default/ {print $5; exit}')"
        [ -n "$dev" ] && tc qdisc replace dev "$dev" root fq 2>/dev/null
    fi
    local cc qd
    cc="$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)"
    qd="$(sysctl -n net.core.default_qdisc 2>/dev/null)"
    if [ "$cc" == "bbr" ] && [ "$qd" == "fq" ]; then
        green "原生BBR + fq 已启用！"
        return 0
    fi
    red "启用失败：当前拥塞控制算法=${cc:-未知}，默认队列算法=${qd:-未知}"
    if [ "$cc" == "bbr" ] && [ "$qd" != "fq" ]; then
        yellow "BBR已生效，但fq队列算法不可用(当前内核没有sch_fq模块)；内核4.13及以上的BBR自带pacing，没有fq也能工作"
    fi
    return 1
}
install_bbr()
{
    local choice=""
    local cc
    local qd
    while true
    do
        cc="$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)"
        qd="$(sysctl -n net.core.default_qdisc 2>/dev/null)"
        echo -e "\n\n\n"
        tyblue "------------------启用Linux原生BBR------------------"
        green  " 当前内核版本      ：$(uname -r)"
        green  " 当前拥塞控制算法  ：${cc:-未知}"
        green  " 当前默认队列算法  ：${qd:-未知}"
        if [ "$cc" == "bbr" ] && [ "$qd" == "fq" ]; then
            green " 状态：已启用 BBR + fq"
        fi
        tyblue "----------------------------------------------------"
        green  " 1. 启用原生BBR + fq (Linux内核自带，无需重启)"
        yellow " 0. 跳过"
        echo
        choice=""
        while [ "$choice" != "0" ] && [ "$choice" != "1" ]
        do
            read -p "您的选择是：" choice
        done
        [ "$choice" == "0" ] && break
        enable_native_bbr
        break
    done
}
#解析"xray x25519"的输出(兼容新旧版本：Private key/Public key 与 PrivateKey/Password (PublicKey))
#参数：private 或 public，输入：xray x25519的输出(标准输入)
parse_x25519()
{
    if [ "$1" == "private" ]; then
        sed -n 's/^[Pp]rivate[ ]*[Kk]ey:[ ]*//p' | head -n 1 | tr -d ' \r'
    else
        grep -iE '^(public[ ]*key|password)' | head -n 1 | sed 's/^[^:]*:[ ]*//' | tr -d ' \r'
    fi
}
#生成/校验REALITY的x25519密钥对和shortId(需要已安装Xray)
#reality_private_key非空时(自定义)只推导公钥，为空时自动生成；reality_short_id为空时自动生成
generate_reality_keys()
{
    local out
    if [ -z "$reality_private_key" ]; then
        out="$(xray x25519 2>/dev/null)" || return 1
        reality_private_key="$(echo "$out" | parse_x25519 private)"
    else
        out="$(xray x25519 -i "$reality_private_key" 2>/dev/null)" || return 1
    fi
    reality_public_key="$(echo "$out" | parse_x25519 public)"
    [[ "$reality_private_key" =~ ^[A-Za-z0-9_-]{43}$ ]] || return 1
    [[ "$reality_public_key" =~ ^[A-Za-z0-9_-]{43}$ ]] || return 1
    [ -z "$reality_short_id" ] && reality_short_id="$(openssl rand -hex 8 2>/dev/null)"
    [[ "$reality_short_id" =~ ^([0-9a-f]{2}){1,8}$ ]] || return 1
    return 0
}
#读取REALITY的伪装域名类型和监听端口
readRealityType()
{
    local choice=""
    local port=""
    echo -e "\n\n\n"
    tyblue "------------------ REALITY 伪装域名类型 ------------------"
    tyblue " 1. 使用自己的域名"
    tyblue "      Xray回落到本机Nginx(真实证书+伪装网站)，需要一个解析到本服务器的域名"
    tyblue "      将安装Nginx、申请证书，并可选择伪装网站页面"
    tyblue " 2. 使用他人的域名 (如 www.microsoft.com)"
    tyblue "      只安装Xray，不安装Nginx/php/证书，不需要自己的域名"
    echo
    while [ "$choice" != "1" ] && [ "$choice" != "2" ]
    do
        read -p "您的选择是：" choice
    done
    reality_mode="$choice"
    echo
    tyblue "REALITY监听端口(直接回车使用默认的443)"
    while true
    do
        read -p "监听端口(默认443)：" port
        [ -z "$port" ] && port=443
        if [[ ! "$port" =~ ^[0-9]+$ ]]; then
            red "端口必须是数字！"
            continue
        fi
        port=$((10#$port))
        if ((port<1 || port>65535)); then
            red "端口必须在1-65535之间！"
            continue
        fi
        if [ "$reality_mode" == "1" ] && [ $port -eq 80 ]; then
            red "使用自己的域名时，80端口需要用于申请证书和HTTP跳转，请换一个端口！"
            continue
        fi
        break
    done
    if [ $port -ne 443 ]; then
        yellow "注意：REALITY监听非443端口会增加服务器IP被封锁的风险(Xray官方提示)，建议尽量使用443"
    fi
    reality_port=$port
}
#检查REALITY的伪装域名(他人域名)是否合适：能解析、支持TLS1.3、支持h2。不合适时询问是否仍然使用
#成功(可以使用)返回0，否则返回1
check_reality_dest()
{
    local d="$1"
    local ok=1
    local out
    green "正在检查伪装域名 ${d} 。。。"
    if command -v getent >/dev/null 2>&1 && ! getent ahosts "$d" >/dev/null 2>&1; then
        red "无法解析域名 ${d}"
        ok=0
    else
        out="$(echo | timeout 15 openssl s_client -connect "${d}:443" -servername "$d" -tls1_3 -alpn h2,http/1.1 2>/dev/null)"
        if ! echo "$out" | grep -qi 'TLSv1\.3'; then
            red "${d} 不支持TLS 1.3(或无法连接其443端口)"
            ok=0
        elif ! echo "$out" | grep -qi 'ALPN protocol: h2'; then
            red "${d} 不支持HTTP/2(h2)"
            ok=0
        fi
    fi
    if [ $ok -eq 1 ]; then
        green "${d} 检查通过(TLS 1.3 + h2)"
        return 0
    fi
    yellow "该域名可能不适合作为REALITY的伪装域名"
    ask_if "是否仍然使用该域名？(y/n)"
}
#读取REALITY(他人域名)的伪装域名，同时作为serverNames和dest
readRealityDirectDomain()
{
    local d=""
    local domain_regex='^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+$'
    echo -e "\n\n\n"
    tyblue "------------------ REALITY 伪装域名 ------------------"
    tyblue " 请填写一个您想伪装成的真实网站的域名，要求："
    tyblue "   1. 能从本服务器正常访问，并且支持 TLS 1.3 和 HTTP/2 (h2)"
    tyblue "   2. 最好是大型、稳定、不会被封锁的网站，不要使用CDN服务商自己的域名"
    tyblue "   常见选择：www.microsoft.com  www.apple.com  addons.mozilla.org"
    echo
    while true
    do
        read -p "请输入伪装域名(不要带http://、https://和端口)：" d
        d="${d,,}"
        [ -z "$d" ] && continue
        if [ ${#d} -gt 253 ] || [[ ! "$d" =~ $domain_regex ]]; then
            red "域名格式不正确！"
            continue
        fi
        check_reality_dest "$d" && break
    done
    reality_sni="$d"
    reality_dest="${d}:443"
}
#读取REALITY的安全参数：UUID、x25519私钥、shortId。可自动生成，也可自定义(任意一项留空则自动生成)
#私钥/公钥需要Xray安装后才能生成，这里只读取用户自定义的值
readRealitySecurity()
{
    local choice=""
    local input=""
    local uuid_regex='^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
    xid_1=""
    reality_private_key=""
    reality_short_id=""
    echo -e "\n\n\n"
    tyblue "------------------ REALITY 安全参数 ------------------"
    tyblue " 1. 全部自动生成 (UUID、x25519密钥对、shortId) (推荐)"
    tyblue " 2. 自定义 (UUID、私钥、shortId，任意一项留空则自动生成)"
    echo
    while [ "$choice" != "1" ] && [ "$choice" != "2" ]
    do
        read -p "您的选择是：" choice
    done
    if [ "$choice" == "2" ]; then
        while true
        do
            read -p "请输入UUID(留空自动生成)：" input
            [ -z "$input" ] && break
            if [[ "$input" =~ $uuid_regex ]]; then
                xid_1="${input,,}"
                break
            fi
            red "UUID格式不正确！"
        done
        while true
        do
            read -p "请输入x25519私钥(PrivateKey，43位，留空自动生成)：" input
            [ -z "$input" ] && break
            if [[ "$input" =~ ^[A-Za-z0-9_-]{43}$ ]]; then
                reality_private_key="$input"
                break
            fi
            red "私钥格式不正确(应为43位base64url字符串)！"
        done
        while true
        do
            read -p "请输入shortId(2-16位十六进制且长度为偶数，留空自动生成)：" input
            [ -z "$input" ] && break
            if [[ "$input" =~ ^([0-9a-fA-F]{2}){1,8}$ ]]; then
                reality_short_id="${input,,}"
                break
            fi
            red "shortId格式不正确！"
        done
    fi
    [ -z "$xid_1" ] && xid_1="$(cat /proc/sys/kernel/random/uuid)"
}
#获取服务器公网IP，成功输出IP并返回0，失败返回1
get_server_ip()
{
    local ip=""
    local url
    for url in https://api.ipify.org https://ipv4.icanhazip.com https://ifconfig.me/ip https://ip.sb
    do
        ip="$(curl -fsSL -4 -m 8 "$url" 2>/dev/null | tr -d ' \r\n')"
        if [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
            echo "$ip"
            return 0
        fi
    done
    for url in https://api64.ipify.org https://ipv6.icanhazip.com
    do
        ip="$(curl -fsSL -6 -m 8 "$url" 2>/dev/null | tr -d ' \r\n')"
        if [[ "$ip" =~ ^[0-9a-fA-F:]+$ ]] && [[ "$ip" =~ : ]]; then
            echo "$ip"
            return 0
        fi
    done
    return 1
}
#读取xray_protocol配置
readProtocolConfig()
{
    echo -e "\\n\\n\\n"
    tyblue "---------------------请选择传输协议---------------------"
    tyblue " 1. VLESS + TCP + XTLS-Vision + REALITY (不走CDN，纯直连高隐蔽)"
    tyblue " 2. VLESS + XHTTP + TLS (过CDN，上下行不分离)"
    tyblue " 3. VLESS + XHTTP + TLS (过CDN，上下行分离)"
    yellow " 0. 无 (仅提供Web服务)"
    echo
    blue   " 注："
    blue   "   1. 如不使用CDN，请选择REALITY"
    blue   "   2. REALITY不能过CDN；伪装域名可以用自己的域名(Nginx回落+真实证书+伪装网站)，也可以借用他人的域名(只安装Xray，不需要自己的域名和证书)"
    blue   "   3. XHTTP支持通过CDN，上下行走同一个域名/同一条CDN链路(不使用downloadSettings分离)，仅支持VLESS，需要Xray v24.11.21及以上"
    blue   "   4. XHTTP上下行分离：上传走\"上行域名\"、下载走\"下行域名\"，两个域名需分别设置、必须不同(可同一根域名下的不同子域名，也可不同根域名)，均需解析到此服务器(可分别接入不同CDN)"
    blue   "      上下行分离时两个域名共用同一个伪装网站(不支持Cloudreve)，客户端需使用支持downloadSettings的较新版Xray内核"
    echo
    local choice=""
    while [[ ! "$choice" =~ ^(0|1|2|3)$ ]]
    do
        read -p "您的选择是：" choice
    done
    if [ $choice -eq 1 ]; then
        protocol_1=1
    else
        protocol_1=0
    fi
    if [ $choice -eq 2 ] || [ $choice -eq 3 ]; then
        protocol_4=1
    else
        protocol_4=0
    fi
    if [ $choice -eq 3 ]; then
        xhttp_split=1
    else
        xhttp_split=0
    fi
}

#读取伪装类型 输入domain 输出pretend
readPretend()
{
    local queren=0
    while [ $queren -ne 1 ]
    do
        echo -e "\\n\\n\\n"
        tyblue "------------------------------请选择伪装网站页面------------------------------"
        green  " 1. Cloudreve (推荐)"
        purple "     个人网盘"
        green  " 2. Nextcloud (推荐)"
        purple "     个人网盘，需安装php"
        tyblue " 3. 403页面"
        purple "     模拟网站后台"
        red    " 4. 自定义静态网站 (不推荐)"
        red    " 5. 自定义反向代理网页 (不推荐)"
        echo
        green  " 内存<128MB 建议选择 403页面"
        green  " 128MB<=内存<1G 建议选择 Cloudreve"
        green  " 内存>=1G 建议选择 Nextcloud 或 Cloudreve"
        echo
        yellow " 关于选择伪装网站的详细说明见：https://github.com/CatherineReyes-byte/Xray-script#伪装网站说明"
        echo
        pretend=""
        while [[ "$pretend" != "1" && "$pretend" != "2" && "$pretend" != "3" && "$pretend" != "4" && "$pretend" != "5" ]]
        do
            read -p "您的选择是：" pretend
        done
        queren=1
        if [ $pretend -eq 1 ]; then
            if [ "$readPretend_no_cloudreve" == "1" ]; then
                red "Cloudreve只能用于一个域名，XHTTP上下行分离使用两个域名，请选择其他伪装网站！"
                sleep 3s
                queren=0
            elif [ -z "$machine" ]; then
                red "您的VPS指令集不支持Cloudreve！"
                yellow "Cloudreve仅支持 x86_64, arm64, armv7, armv6, armv5 !"
                sleep 3s
                queren=0
            fi
        elif [ $pretend -eq 2 ]; then
            if (([ $release == "centos" ] || [ $release == centos-stream ] || [ $release == oracle ]) && ! version_ge "$systemVersion" "8" ) || ([ $release == "rhel" ] && ! version_ge "$systemVersion" "8") || ([ $release == "fedora" ] && ! version_ge "$systemVersion" "30") || ([ $release == "ubuntu" ] && ! version_ge "$systemVersion" "20.04") || ([ $release == "debian" ] && ! version_ge "$systemVersion" "11"); then
                red "系统版本过低，无法安装php！"
                echo
                tyblue "安装Nextcloud需要安装php"
                yellow "仅支持在以下版本系统下安装php："
                yellow " 1. Ubuntu 20.04+"
                yellow " 2. Debian 11+"
                yellow " 3. 其他以 Debian 11+ 为基的系统"
                yellow " 4. Red Hat Enterprise Linux 8+"
                yellow " 5. CentOS 8+"
                yellow " 6. Fedora 30+"
                yellow " 7. Oracle Linux 8+"
                yellow " 8. 其他以 Red Hat 8+ 为基的系统"
                sleep 3s
                queren=0
                continue
            elif [ $release == "other-debian" ] || [ $release == "other-redhat" ]; then
                yellow "未知的系统，可能导致php安装失败！"
                echo
                tyblue "安装Nextcloud需要安装php"
                yellow "仅支持在以下版本系统下安装php："
                yellow " 1. Ubuntu 20.04+"
                yellow " 2. Debian 11+"
                yellow " 3. 其他以 Debian 11+ 为基的系统"
                yellow " 4. Red Hat Enterprise Linux 8+"
                yellow " 5. CentOS 8+"
                yellow " 6. Fedora 30+"
                yellow " 7. Oracle Linux 8+"
                yellow " 8. 其他以 Red Hat 8+ 为基的系统"
                ! ask_if "确定选择吗？(y/n)" && queren=0 && continue
            elif [ $release == "deepin" ]; then
                red "php暂不支持deepin，请更换其他系统"
                sleep 3s
                queren=0
                continue
            fi
            if [ $php_is_installed -eq 0 ]; then
                tyblue "安装Nextcloud需要安装php"
                yellow "编译&&安装php可能需要额外消耗15-60分钟"
                yellow "php将占用一定系统资源，不建议内存<512M的机器使用"
                ! ask_if "确定选择吗？(y/n)" && queren=0
            fi
        elif [ $pretend -eq 4 ]; then
            local temp_site_domain
            for temp_site_domain in "$@"
            do
                tyblue "安装完成后请在 \"${nginx_prefix}/html/${temp_site_domain}\" 放置您的网站源代码"
            done
            ! ask_if "确认并继续？(y/n)" && queren=0
        elif [ $pretend -eq 5 ]; then
            yellow "输入反向代理网址，格式如：\"https://v.qq.com\""
            pretend=""
            while [ -z "$pretend" ]
            do
                read -p "请输入反向代理网址：" pretend
            done
        fi
    done
}
#读取XHTTP上下行分离的上行域名和下行域名
#两个域名各只解析自身(不含www)，伪装网站共用；读取后依次追加到域名列表末尾(上行域名在前，下行域名在后)
readXhttpSplitDomains()
{
    local up=""
    local down=""
    local pretend
    local queren=0
    local domain_regex='^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+$'
    check_split_domain()
    {
        local d="$1"
        local i
        [ -z "$d" ] && return 1
        if [ "$(echo -n "$d" | wc -c)" -gt 46 ]; then
            red "域名过长！"
            return 1
        fi
        if [[ ! "$d" =~ $domain_regex ]]; then
            red "域名格式不正确(不要带\"http://\"、\"https://\"、端口或路径)！"
            return 1
        fi
        for i in "${!domain_list[@]}"
        do
            if [ "$d" == "${domain_list[$i]}" ] || [ "$d" == "${true_domain_list[$i]}" ]; then
                red "域名已存在！"
                return 1
            fi
        done
        return 0
    }
    echo -e "\\n\\n\\n"
    tyblue "------------------XHTTP 上下行分离：设置上行/下行域名------------------"
    tyblue " 上行域名：客户端上传数据(POST)时连接的域名"
    tyblue " 下行域名：客户端下载数据(GET)时连接的域名"
    green  " 1. 两个域名必须不同，且都需要解析到此服务器(可分别接入不同的CDN)"
    green  " 2. 可以是同一根域名下的不同子域名，如：up.123.com 和 down.123.com"
    green  " 3. 也可以是不同的根域名，如：123.com 和 456.com"
    yellow " 两个域名都只解析自身(无需解析www.前缀)，将各自申请一张证书"
    echo
    while [ $queren -ne 1 ]
    do
        up=""
        while ! check_split_domain "$up"
        do
            read -p "请输入上行域名：" up
            up="${up,,}"
        done
        while true
        do
            read -p "请输入下行域名：" down
            down="${down,,}"
            if [ "$down" == "$up" ]; then
                red "下行域名不能与上行域名相同！"
                continue
            fi
            check_split_domain "$down" && break
        done
        echo
        ask_if "上行域名是\"$up\"，下行域名是\"$down\"，确认吗？(y/n)" && queren=1
    done
    readPretend_no_cloudreve=1
    readPretend "$up" "$down"
    unset readPretend_no_cloudreve
    true_domain_list+=("$up" "$down")
    domain_list+=("$up" "$down")
    domain_config_list+=("2" "2")
    pretend_list+=("$pretend" "$pretend")
    xhttp_up_domain="$up"
    xhttp_down_domain="$down"
}
readDomain()
{
    check_domain()
    {
        if [ -z "$1" ]; then
            return 1
        elif [ "${1%%.*}" == "www" ]; then
            red "域名前面不要带www！"
            return 1
        elif [ "$(echo -n "$1" | wc -c)" -gt 42 ]; then
            red "域名过长！"
            return 1
        else
            return 0
        fi
    }
    local domain
    local domain_config=""
    local pretend
    echo -e "\\n\\n\\n"
    tyblue "--------------------请选择域名解析情况--------------------"
    tyblue " 1. 主域名 和 www.主域名 都解析到此服务器上 \\033[32m(推荐)"
    green  "    如：123.com 和 www.123.com 都解析到此服务器上"
    tyblue " 2. 仅某个特定域名解析到此服务器上"
    green  "    如：123.com 或 www.123.com 或 xxx.123.com 中的一个解析到此服务器上"
    echo
    while [ "$domain_config" != "1" ] && [ "$domain_config" != "2" ]
    do
        read -p "您的选择是：" domain_config
    done
    local queren=0
    while [ $queren -ne 1 ]
    do
        domain=""
        echo
        if [ $domain_config -eq 1 ]; then
            tyblue '---------请输入主域名(前面不带"www."、"http://"或"https://")---------'
            while ! check_domain "$domain"
            do
                read -p "请输入域名：" domain
            done
        else
            tyblue '-------请输入解析到此服务器的域名(前面不带"http://"或"https://")-------'
            while [ -z "$domain" ]
            do
                read -p "请输入域名：" domain
                if [ "$(echo -n "$domain" | wc -c)" -gt 46 ]; then
                    red "域名过长！"
                    domain=""
                fi
            done
        fi
        echo
        ask_if "您输入的域名是\"$domain\"，确认吗？(y/n)" && queren=1
    done
    readPretend "$domain"
    true_domain_list+=("$domain")
    [ $domain_config -eq 1 ] && domain_list+=("www.$domain") || domain_list+=("$domain")
    domain_config_list+=("$domain_config")
    pretend_list+=("$pretend")
}

install_nginx_compile_toolchains()
{
    green "正在安装Nginx编译工具链。。。"
    if [ $release == "centos" ] || [ $release == centos-stream ] || [ $release == oracle ] || [ $release == "rhel" ] || [ $release == "fedora" ] || [ $release == "other-redhat" ]; then
        install_dependence ca-certificates wget gcc gcc-c++ make perl-IPC-Cmd perl-Getopt-Long perl-Data-Dumper
        if ! perl -e "use FindBin" > /dev/null 2>&1; then
            install_dependence perl-FindBin
        fi
    else
        install_dependence ca-certificates wget gcc g++ make perl-base perl
    fi
}
install_php_compile_toolchains()
{
    green "正在安装php编译工具链。。。"
    if [ $release == "centos" ] || [ $release == centos-stream ] || [ $release == oracle ] || [ $release == "rhel" ] || [ $release == "fedora" ] || [ $release == "other-redhat" ]; then
        install_dependence ca-certificates wget xz gcc gcc-c++ make pkgconf-pkg-config autoconf git
    else
        install_dependence ca-certificates wget xz-utils gcc g++ make pkg-config autoconf git
    fi
}
install_nginx_dependence()
{
    green "正在安装Nginx依赖。。。"
    if [ $release == "centos" ] || [ $release == centos-stream ] || [ $release == oracle ] || [ $release == "rhel" ] || [ $release == "fedora" ] || [ $release == "other-redhat" ]; then
        install_dependence pcre2-devel zlib-devel libxml2-devel libxslt-devel gd-devel geoip-devel perl-ExtUtils-Embed gperftools-devel perl-devel
    else
        install_dependence libpcre2-dev zlib1g-dev libxml2-dev libxslt1-dev libgd-dev libgeoip-dev libgoogle-perftools-dev libperl-dev
    fi
}
install_php_dependence()
{
    green "正在安装php依赖。。。"
    if [ $release == "centos" ] || [ $release == centos-stream ] || [ $release == oracle ] || [ $release == "rhel" ] || [ $release == "fedora" ] || [ $release == "other-redhat" ]; then
        fedora_install_remi
        install_dependence libxml2-devel sqlite-devel systemd-devel libacl-devel openssl-devel krb5-devel pcre2-devel zlib-devel bzip2-devel libcurl-devel gdbm-devel libdb-devel tokyocabinet-devel lmdb-devel enchant-devel libffi-devel libpng-devel gd-devel libwebp-devel libjpeg-turbo-devel libXpm-devel freetype-devel gmp-devel uw-imap-devel libicu-devel openldap-devel oniguruma-devel unixODBC-devel freetds-devel libpq-devel aspell-devel libedit-devel net-snmp-devel libsodium-devel libargon2-devel libtidy-devel libxslt-devel libzip-devel ImageMagick-devel
    else
        if ! $apt_no_install_recommends -y install libxml2-dev libsqlite3-dev libsystemd-dev libacl1-dev libapparmor-dev libssl-dev libkrb5-dev libpcre2-dev zlib1g-dev libbz2-dev libcurl4-openssl-dev libqdbm-dev libdb-dev libtokyocabinet-dev liblmdb-dev libenchant-2-dev libffi-dev libpng-dev libgd-dev libwebp-dev libjpeg-dev libxpm-dev libfreetype6-dev libgmp-dev libc-client2007e-dev libicu-dev libldap2-dev libsasl2-dev libonig-dev unixodbc-dev freetds-dev libpq-dev libpspell-dev libedit-dev libmm-dev libsnmp-dev libsodium-dev libargon2-dev libtidy-dev libxslt1-dev libzip-dev libmagickwand-dev && ! $apt_no_install_recommends -y install libxml2-dev libsqlite3-dev libsystemd-dev libacl1-dev libapparmor-dev libssl-dev libkrb5-dev libpcre2-dev zlib1g-dev libbz2-dev libcurl4-openssl-dev libqdbm-dev libdb-dev libtokyocabinet-dev liblmdb-dev libenchant-dev libffi-dev libpng-dev libgd-dev libwebp-dev libjpeg-dev libxpm-dev libfreetype6-dev libgmp-dev libc-client2007e-dev libicu-dev libldap2-dev libsasl2-dev libonig-dev unixodbc-dev freetds-dev libpq-dev libpspell-dev libedit-dev libmm-dev libsnmp-dev libsodium-dev libargon2-dev libtidy-dev libxslt1-dev libzip-dev libmagickwand-dev; then
            $apt update
            $apt_no_install_recommends -y -f install
            if ! $apt_no_install_recommends -y install libxml2-dev libsqlite3-dev libsystemd-dev libacl1-dev libapparmor-dev libssl-dev libkrb5-dev libpcre2-dev zlib1g-dev libbz2-dev libcurl4-openssl-dev libqdbm-dev libdb-dev libtokyocabinet-dev liblmdb-dev libenchant-2-dev libffi-dev libpng-dev libgd-dev libwebp-dev libjpeg-dev libxpm-dev libfreetype6-dev libgmp-dev libc-client2007e-dev libicu-dev libldap2-dev libsasl2-dev libonig-dev unixodbc-dev freetds-dev libpq-dev libpspell-dev libedit-dev libmm-dev libsnmp-dev libsodium-dev libargon2-dev libtidy-dev libxslt1-dev libzip-dev libmagickwand-dev && ! $apt_no_install_recommends -y install libxml2-dev libsqlite3-dev libsystemd-dev libacl1-dev libapparmor-dev libssl-dev libkrb5-dev libpcre2-dev zlib1g-dev libbz2-dev libcurl4-openssl-dev libqdbm-dev libdb-dev libtokyocabinet-dev liblmdb-dev libenchant-dev libffi-dev libpng-dev libgd-dev libwebp-dev libjpeg-dev libxpm-dev libfreetype6-dev libgmp-dev libc-client2007e-dev libicu-dev libldap2-dev libsasl2-dev libonig-dev unixodbc-dev freetds-dev libpq-dev libpspell-dev libedit-dev libmm-dev libsnmp-dev libsodium-dev libargon2-dev libtidy-dev libxslt1-dev libzip-dev libmagickwand-dev; then
                yellow "依赖安装失败！！"
                green  "欢迎进行Bug report(https://github.com/CatherineReyes-byte/Xray-script/issues)，感谢您的支持"
                yellow "按回车键继续或者Ctrl+c退出"
                read -s
            fi
        fi
    fi
}
install_acme_dependence()
{
    green "正在安装acme.sh依赖。。。"
    if [ $release == "centos" ] || [ $release == centos-stream ] || [ $release == oracle ] || [ $release == "rhel" ] || [ $release == "fedora" ] || [ $release == "other-redhat" ]; then
        install_dependence curl openssl crontabs
    else
        install_dependence curl openssl cron
    fi
}
install_web_dependence()
{
    green "正在安装伪装网站依赖。。。"
    if [ "$1" == "" ]; then
        for i in "${pretend_list[@]}"
        do
            if [ "$i" == "1" ]; then
                install_dependence ca-certificates wget
                break
            fi
        done
        for i in "${pretend_list[@]}"
        do
            if [ "$i" == "2" ]; then
                install_dependence ca-certificates curl bzip2
                break
            fi
        done
    else
        if [ "$1" == "1" ]; then
            install_dependence ca-certificates wget
        elif [ "$1" == "2" ]; then
            install_dependence ca-certificates curl bzip2
        fi
    fi
}

#编译&&安装php
compile_php()
{
    green "正在编译php。。。。"
    local cflags
    local cxxflags
    gen_cflags
    gen_cxxflags
    # php.net/distributions 只保留最新版本，旧版本在museum.php.net
    if ! wget -O "${php_version}.tar.xz" "https://www.php.net/distributions/${php_version}.tar.xz" && ! wget -O "${php_version}.tar.xz" "https://museum.php.net/php${php_version:4:1}/${php_version}.tar.xz"; then
        red    "获取php失败"
        yellow "按回车键继续或者按Ctrl+c终止"
        read -s
    fi
    tar -xJf "${php_version}.tar.xz"
    rm -f "${php_version}.tar.xz"
    cd "${php_version}"
    sed -i 's#db$THIS_VERSION/db_185.h include/db$THIS_VERSION/db_185.h include/db/db_185.h#& include/db_185.h#' configure
    if [ $release == "ubuntu" ] || [ $release == "debian" ] || [ $release == "deepin" ] || [ $release == "other-debian" ]; then
        sed -i 's#if test -f $THIS_PREFIX/$PHP_LIBDIR/lib$LIB.a || test -f $THIS_PREFIX/$PHP_LIBDIR/lib$LIB.$SHLIB_SUFFIX_NAME#& || true#' configure
        sed -i 's#if test ! -r "$PDO_FREETDS_INSTALLATION_DIR/$PHP_LIBDIR/libsybdb.a" && test ! -r "$PDO_FREETDS_INSTALLATION_DIR/$PHP_LIBDIR/libsybdb.so"#& \&\& false#' configure
        ./configure --prefix=${php_prefix} --enable-embed=shared --enable-fpm --with-fpm-user=www-data --with-fpm-group=www-data --with-fpm-systemd --with-fpm-acl --with-fpm-apparmor --disable-phpdbg --with-layout=GNU --with-openssl --with-kerberos --with-external-pcre --with-zlib --enable-bcmath --with-bz2 --enable-calendar --with-curl --enable-dba --with-qdbm --with-db4 --with-db1 --with-tcadb --with-lmdb --with-enchant --enable-exif --with-ffi --enable-ftp --enable-gd --with-external-gd --with-avif --with-webp --with-jpeg --with-xpm --with-freetype --enable-gd-jis-conv --with-gettext --with-gmp --with-mhash --with-imap --with-imap-ssl --enable-intl --with-ldap --with-ldap-sasl --enable-mbstring --with-mysqli --with-mysql-sock --with-unixODBC --enable-pcntl --with-pdo-dblib --with-pdo-mysql --with-zlib-dir --with-pdo-odbc=unixODBC,/usr --with-pdo-pgsql --with-pgsql --with-pspell --with-libedit --with-mm --enable-shmop --with-snmp --enable-soap --enable-sockets --with-sodium --with-external-libcrypt --with-password-argon2 --enable-sysvmsg --enable-sysvsem --enable-sysvshm --with-tidy --with-xsl --with-zip --enable-mysqlnd --with-pear CFLAGS="${cflags[*]}" CXXFLAGS="${cxxflags[*]}"
    else
        ./configure --prefix=${php_prefix} --with-libdir=lib64 --enable-embed=shared --enable-fpm --with-fpm-user=www-data --with-fpm-group=www-data --with-fpm-systemd --with-fpm-acl --disable-phpdbg --with-layout=GNU --with-openssl --with-kerberos --with-external-pcre --with-zlib --enable-bcmath --with-bz2 --enable-calendar --with-curl --enable-dba --with-gdbm --with-db4 --with-db1 --with-tcadb --with-lmdb --with-enchant --enable-exif --with-ffi --enable-ftp --enable-gd --with-external-gd --with-avif --with-webp --with-jpeg --with-xpm --with-freetype --enable-gd-jis-conv --with-gettext --with-gmp --with-mhash --with-imap --with-imap-ssl --enable-intl --with-ldap --with-ldap-sasl --enable-mbstring --with-mysqli --with-mysql-sock --with-unixODBC --enable-pcntl --with-pdo-dblib --with-pdo-mysql --with-zlib-dir --with-pdo-odbc=unixODBC,/usr --with-pdo-pgsql --with-pgsql --with-pspell --with-libedit --enable-shmop --with-snmp --enable-soap --enable-sockets --with-sodium --with-external-libcrypt --with-password-argon2 --enable-sysvmsg --enable-sysvsem --enable-sysvshm --with-tidy --with-xsl --with-zip --enable-mysqlnd --with-pear CFLAGS="${cflags[*]}" CXXFLAGS="${cxxflags[*]}"
    fi
    swap_on 2048
    if ! make -j$cpu_thread_num; then
        swap_off
        red    "php编译失败！"
        green  "欢迎进行Bug report(https://github.com/CatherineReyes-byte/Xray-script/issues)，感谢您的支持"
        yellow "在Bug修复前，建议使用Ubuntu最新版系统"
        exit 1
    fi
    swap_off
    cd ..
}
instal_php_imagick()
{
    local cflags
    gen_cflags
    if ! git clone https://github.com/Imagick/imagick; then
        yellow "获取php-imagick源码失败"
        yellow "按回车键继续或者按Ctrl+c终止"
        read -s
    fi
    cd imagick
    ${php_prefix}/bin/phpize
    ./configure --with-php-config=${php_prefix}/bin/php-config CFLAGS="${cflags[*]}"
    swap_on 380
    if ! make -j$cpu_thread_num; then
        swap_off
        yellow "php-imagick编译失败"
        green  "欢迎进行Bug report(https://github.com/CatherineReyes-byte/Xray-script/issues)，感谢您的支持"
        yellow "在Bug修复前，建议使用Ubuntu最新版系统"
        yellow "按回车键继续或者按Ctrl+c终止"
        read -s
    else
        swap_off
    fi
    mv modules/imagick.so "$(${php_prefix}/bin/php -i | grep "^extension_dir" | awk '{print $3}')"
    cd ..
    rm -rf imagick
}
install_php_part1()
{
    green "正在安装php。。。。"
    cd "${php_version}"
    make install
    mv sapi/fpm/php-fpm.service "${php_prefix}/php-fpm.service.default.temp"
    mv php.ini-production "${php_prefix}"
    mv php.ini-development "${php_prefix}"
    cd ..
    rm -rf "${php_version}"
    instal_php_imagick
    mv "${php_prefix}/php-fpm.service.default.temp" "${php_prefix}/php-fpm.service.default"
    php_is_installed=1
}
install_php_part2()
{
    useradd -r -s /bin/bash www-data
    cp ${php_prefix}/etc/php-fpm.conf.default ${php_prefix}/etc/php-fpm.conf
    cp ${php_prefix}/etc/php-fpm.d/www.conf.default ${php_prefix}/etc/php-fpm.d/www.conf
    sed -i 's/^[ \t]*listen[ \t]*=/;&/g' ${php_prefix}/etc/php-fpm.d/www.conf
    sed -i 's/^[ \t]*env\[PATH\][ \t]*=/;&/g' ${php_prefix}/etc/php-fpm.d/www.conf
cat >> ${php_prefix}/etc/php-fpm.d/www.conf << EOF

listen = /dev/shm/php-fpm/php-fpm.sock
pm = dynamic
pm.max_children = $((16*cpu_thread_num))
pm.start_servers = $cpu_thread_num
pm.min_spare_servers = $cpu_thread_num
pm.max_spare_servers = $((16*cpu_thread_num))
env[PATH] = $PATH
EOF
    rm -rf "${php_prefix}/etc/php.ini"
    cp "${php_prefix}/php.ini-production" "${php_prefix}/etc/php.ini"
cat >> ${php_prefix}/etc/php.ini << EOF

[PHP]
extension=imagick.so
zend_extension=opcache.so
opcache.enable=1
date.timezone=$timezone

;如果使用mysql，并且使用unix domain socket方式连接，请正确设置以下内容
;pdo_mysql.default_socket=/var/run/mysqld/mysqld.sock
;mysqli.default_socket=/var/run/mysqld/mysqld.sock

memory_limit=-1
post_max_size=0
upload_max_filesize=9223372036854775807
max_file_uploads=50000
max_execution_time=0
max_input_time=0
output_buffering=4096
session.auto_start=0
EOF
    install -m 644 "${php_prefix}/php-fpm.service.default" $php_service
cat >> $php_service <<EOF

[Service]
ProtectSystem=false
ExecStartPre=/bin/rm -rf /dev/shm/php-fpm
ExecStartPre=/bin/mkdir /dev/shm/php-fpm
ExecStartPre=/bin/chmod 711 /dev/shm/php-fpm
ExecStartPre=/bin/chown www-data:www-data /dev/shm/php-fpm
ExecStopPost=/bin/rm -rf /dev/shm/php-fpm
EOF
    systemctl daemon-reload
}

#编译&&安装nignx
compile_nginx()
{
    green "正在编译Nginx。。。。"
    local cflags
    gen_cflags
    if ! wget -O ${nginx_version}.tar.gz https://nginx.org/download/${nginx_version}.tar.gz; then
        red    "获取nginx失败"
        yellow "按回车键继续或者按Ctrl+c终止"
        read -s
    fi
    tar -zxf ${nginx_version}.tar.gz
    rm -f "${nginx_version}.tar.gz"
    if ! wget -O ${openssl_version}.tar.gz https://github.com/openssl/openssl/archive/${openssl_version#*-}.tar.gz; then
        red    "获取openssl失败"
        yellow "按回车键继续或者按Ctrl+c终止"
        read -s
    fi
    tar -zxf ${openssl_version}.tar.gz
    rm -f "${openssl_version}.tar.gz"
    cd ${nginx_version}
    sed -i "s/OPTIMIZE[ \\t]*=>[ \\t]*'-O'/OPTIMIZE          => '-O3'/g" src/http/modules/perl/Makefile.PL
    sed -i 's/NGX_PERL_CFLAGS="$CFLAGS `$NGX_PERL -MExtUtils::Embed -e ccopts`"/NGX_PERL_CFLAGS="`$NGX_PERL -MExtUtils::Embed -e ccopts` $CFLAGS"/g' auto/lib/perl/conf
    sed -i 's/NGX_PM_CFLAGS=`$NGX_PERL -MExtUtils::Embed -e ccopts`/NGX_PM_CFLAGS="`$NGX_PERL -MExtUtils::Embed -e ccopts` $CFLAGS"/g' auto/lib/perl/conf
    ./configure --prefix="${nginx_prefix}" --user=root --group=root --with-threads --with-file-aio --with-http_ssl_module --with-http_v2_module --with-http_realip_module --with-http_addition_module --with-http_xslt_module=dynamic --with-http_image_filter_module=dynamic --with-http_geoip_module=dynamic --with-http_sub_module --with-http_dav_module --with-http_flv_module --with-http_mp4_module --with-http_gunzip_module --with-http_gzip_static_module --with-http_auth_request_module --with-http_random_index_module --with-http_secure_link_module --with-http_degradation_module --with-http_slice_module --with-http_stub_status_module --with-http_perl_module=dynamic --with-mail=dynamic --with-mail_ssl_module --with-stream=dynamic --with-stream_ssl_module --with-stream_realip_module --with-stream_geoip_module=dynamic --with-stream_ssl_preread_module --with-google_perftools_module --with-compat --with-cc-opt="${cflags[*]}" --with-openssl="../$openssl_version" --with-openssl-opt="${cflags[*]}"
    #--with-select_module --with-poll_module --with-cpp_test_module --with-pcre --with-pcre-jit --with-libatomic
    #./configure --prefix=/usr/local/nginx --with-openssl=../$openssl_version --with-mail=dynamic --with-mail_ssl_module --with-stream=dynamic --with-stream_ssl_module --with-stream_realip_module --with-stream_geoip_module=dynamic --with-stream_ssl_preread_module --with-http_ssl_module --with-http_v2_module --with-http_realip_module --with-http_addition_module --with-http_xslt_module=dynamic --with-http_image_filter_module=dynamic --with-http_geoip_module=dynamic --with-http_sub_module --with-http_dav_module --with-http_flv_module --with-http_mp4_module --with-http_gunzip_module --with-http_gzip_static_module --with-http_auth_request_module --with-http_random_index_module --with-http_secure_link_module --with-http_degradation_module --with-http_slice_module --with-http_stub_status_module --with-http_perl_module=dynamic --with-pcre --with-libatomic --with-compat --with-cpp_test_module --with-google_perftools_module --with-file-aio --with-threads --with-poll_module --with-select_module --with-cc-opt="-Wno-error ${cflags[*]}"
    swap_on 480
    if ! make -j$cpu_thread_num; then
        swap_off
        red    "Nginx编译失败！"
        green  "欢迎进行Bug report(https://github.com/CatherineReyes-byte/Xray-script/issues)，感谢您的支持"
        yellow "在Bug修复前，建议使用Ubuntu最新版系统"
        exit 1
    fi
    swap_off
    cd ..
}
config_service_nginx()
{
    rm -rf $nginx_service
cat > $nginx_service << EOF
[Unit]
Description=The NGINX HTTP and reverse proxy server
After=syslog.target network-online.target remote-fs.target nss-lookup.target
Wants=network-online.target

[Service]
Type=forking
User=root
ExecStartPre=/bin/rm -rf /dev/shm/nginx
ExecStartPre=/bin/mkdir /dev/shm/nginx
ExecStartPre=/bin/chmod 711 /dev/shm/nginx
ExecStartPre=/bin/mkdir /dev/shm/nginx/tcmalloc
ExecStartPre=/bin/chmod 0777 /dev/shm/nginx/tcmalloc
ExecStart=${nginx_prefix}/sbin/nginx
ExecStop=${nginx_prefix}/sbin/nginx -s stop
ExecStopPost=/bin/rm -rf /dev/shm/nginx
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF
    chmod 644 $nginx_service
    systemctl daemon-reload
}
install_nginx_part1()
{
    green "正在安装Nginx。。。"
    cd "${nginx_version}"
    make install
    cd ..
    rm -rf "${nginx_version}"
    rm -rf "$openssl_version"
}
install_nginx_part2()
{
    mkdir ${nginx_prefix}/conf.d
    touch $nginx_config
    mkdir ${nginx_prefix}/certs
    mkdir ${nginx_prefix}/html/issue_certs
cat > ${nginx_prefix}/conf/issue_certs.conf << EOF
events {
    worker_connections  1024;
}
http {
    server {
        listen [::]:80 ipv6only=off;
        root ${nginx_prefix}/html/issue_certs;
    }
}
EOF
cat > ${nginx_prefix}/conf.d/nextcloud.conf <<EOF
    client_max_body_size 0;
    #client_body_timeout 300s;
    fastcgi_buffers 64 4K;
    gzip on;
    gzip_vary on;
    gzip_comp_level 4;
    gzip_min_length 256;
    gzip_proxied expired no-cache no-store private no_last_modified no_etag auth;
    gzip_types application/atom+xml application/javascript application/json application/ld+json application/manifest+json application/rss+xml application/vnd.geo+json application/vnd.ms-fontobject application/x-font-ttf application/x-web-app-manifest+json application/xhtml+xml application/xml font/opentype image/bmp image/svg+xml image/x-icon text/cache-manifest text/css text/plain text/vcard text/vnd.rim.location.xloc text/vtt text/x-component text/x-cross-domain-policy;
    add_header Referrer-Policy                      "no-referrer"   always;
    add_header X-Content-Type-Options               "nosniff"       always;
    add_header X-Download-Options                   "noopen"        always;
    add_header X-Frame-Options                      "SAMEORIGIN"    always;
    add_header X-Permitted-Cross-Domain-Policies    "none"          always;
    add_header X-Robots-Tag                         "none"          always;
    add_header X-XSS-Protection                     "1; mode=block" always;
    fastcgi_hide_header X-Powered-By;
    index index.php index.html /index.php\$request_uri;
    location = / {
        if ( \$http_user_agent ~ ^DavClnt ) {
            return 302 https://\$host/remote.php/webdav/\$is_args\$args;
        }
    }
    location = /robots.txt {
        allow all;
        log_not_found off;
        access_log off;
    }
    location ^~ /.well-known {
        location = /.well-known/carddav { return 301 https://\$host/remote.php/dav/; }
        location = /.well-known/caldav  { return 301 https://\$host/remote.php/dav/; }
        location /.well-known/acme-challenge    { try_files \$uri \$uri/ =404; }
        location /.well-known/pki-validation    { try_files \$uri \$uri/ =404; }
        return 301 https://\$host/index.php\$request_uri;
    }
    location ~ ^/(?:build|tests|config|lib|3rdparty|templates|data)(?:$|/)  { return 404; }
    location ~ ^/(?:\\.|autotest|occ|issue|indie|db_|console)                { return 404; }
    location ~ \\.php(?:$|/) {
        rewrite ^/(?!index|remote|public|cron|core\\/ajax\\/update|status|ocs\\/v[12]|updater\\/.+|oc[ms]-provider\\/.+|.+\\/richdocumentscode\\/proxy) /index.php\$request_uri;
        fastcgi_split_path_info ^(.+?\\.php)(/.*)$;
        set \$path_info \$fastcgi_path_info;
        try_files \$fastcgi_script_name =404;
        include fastcgi.conf;
        fastcgi_param PATH_INFO \$path_info;
        fastcgi_param REMOTE_ADDR 127.0.0.1;
        fastcgi_param SERVER_PORT 443;
        fastcgi_param HTTPS on;
        fastcgi_param modHeadersAvailable true;
        fastcgi_param front_controller_active true;
        fastcgi_pass unix:/dev/shm/php-fpm/php-fpm.sock;
        fastcgi_intercept_errors on;
        fastcgi_request_buffering off;
        fastcgi_read_timeout 24h;
        fastcgi_max_temp_file_size 0;
    }
    location ~ \\.(?:css|js|svg|gif|png|jpg|ico)$ {
        try_files \$uri /index.php\$request_uri;
        expires 6M;
        access_log off;
    }
    location ~ \\.woff2?$ {
        try_files \$uri /index.php\$request_uri;
        expires 7d;
        access_log off;
    }
    location /remote {
        return 301 https://\$host/remote.php\$request_uri;
    }
    location / {
        try_files \$uri \$uri/ /index.php\$request_uri;
    }
EOF
    config_service_nginx
    systemctl enable nginx
    nginx_is_installed=1
    [ $xray_is_installed -eq 1 ] && is_installed=1 || is_installed=0
}

#安装/更新Xray
#配置xray.service
#新版Xray官方安装脚本默认以非root用户"xray"运行服务，且不再支持"-u root"参数。
#本脚本中Nginx以root运行，xray需要读取root创建的证书并访问/dev/shm下的unix socket，
#因此通过drop-in文件将运行用户改为root(drop-in不会被官方脚本升级时覆盖)
config_xray_service()
{
    mkdir -p /etc/systemd/system/xray.service.d
cat > /etc/systemd/system/xray.service.d/99-xray-tls-web-setup.conf <<EOF
# This file has been created by Xray-TLS-Web setup script
[Service]
User=root
Group=root
UMask=0022
ExecStartPre=/bin/rm -rf /dev/shm/xray
ExecStartPre=/bin/mkdir /dev/shm/xray
ExecStartPre=/bin/chmod 711 /dev/shm/xray
ExecStopPost=/bin/rm -rf /dev/shm/xray
EOF
    systemctl daemon-reload
    systemctl -q is-active xray && systemctl restart xray
}
#检查已安装的Xray是否支持XHTTP传输(v24.11.21及以上)
#无法获取版本号时默认认为支持，以免误拦截
check_xray_support_xhttp()
{
    local ver
    ver="$(xray version 2>/dev/null | head -n 1 | awk '{print $2}')"
    ver="${ver#v}"
    [[ "$ver" =~ ^[0-9]+(\.[0-9]+)+$ ]] || return 0
    version_ge "$ver" "24.11.21"
}
#获取Xray-core最新稳定版(非Pre-release、非draft)的版本号，成功时输出形如 v26.11.9 并返回0，失败返回1
get_latest_xray_version()
{
    local json=""
    local tag=""
    local i
    for ((i=0;i<3;i++))
    do
        json="$(curl -fsSL -m 30 -H "Accept: application/vnd.github+json" -A "Mozilla/5.0" https://api.github.com/repos/XTLS/Xray-core/releases/latest 2>/dev/null)" && [ -n "$json" ] && break
        json=""
        sleep 2s
    done
    if [ -n "$json" ] && command -v jq >/dev/null 2>&1; then
        if [ "$(echo "$json" | jq -r '.prerelease' 2>/dev/null)" == "false" ] && [ "$(echo "$json" | jq -r '.draft' 2>/dev/null)" == "false" ]; then
            tag="$(echo "$json" | jq -r '.tag_name' 2>/dev/null)"
        fi
    fi
    #备用：GitHub的latest重定向永远指向最新的非Pre-release版本(不受API限流影响)
    if [[ ! "$tag" =~ ^v[0-9]+(\.[0-9]+)+$ ]]; then
        tag="$(curl -fsSIL -m 30 -o /dev/null -w '%{url_effective}' https://github.com/XTLS/Xray-core/releases/latest 2>/dev/null | sed 's#.*/tag/##')"
    fi
    [[ "$tag" =~ ^v[0-9]+(\.[0-9]+)+$ ]] || return 1
    echo "$tag"
}
install_update_xray()
{
    green "正在安装/更新Xray。。。。"
    local version_args=()
    local latest_tag=""
    if latest_tag="$(get_latest_xray_version)"; then
        green "Xray-core最新稳定版：${latest_tag}"
        version_args=(--version "$latest_tag")
    else
        yellow "未能获取Xray最新稳定版的版本号，将使用官方安装脚本的默认版本(同样是最新稳定版)"
    fi
    if ! run_xray_install_script install "${version_args[@]}" --without-geodata --without-logfiles && ! run_xray_install_script install "${version_args[@]}" --without-geodata --without-logfiles; then
        red    "安装/更新Xray失败"
        yellow "按回车键继续或者按Ctrl+c终止"
        read -s
        return 1
    fi
    config_xray_service
    systemctl enable xray
    xray_is_installed=1
    ([ $nginx_is_installed -eq 1 ] || [ "$reality_direct" == "1" ]) && is_installed=1 || is_installed=0
}

#安装acme.sh
install_acme_sh()
{
    [ -e $HOME/.acme.sh/acme.sh ] && $HOME/.acme.sh/acme.sh --uninstall
    rm -rf $HOME/.acme.sh
    if ! curl -fsSL https://get.acme.sh | sh || [ ! -e $HOME/.acme.sh/acme.sh ]; then
        yellow "通过get.acme.sh安装失败，尝试直接从GitHub安装。。。"
        local acme_tmp
        acme_tmp="$(mktemp -d)"
        if ! curl -fsSL --retry 3 -o "${acme_tmp}/acme.sh" https://raw.githubusercontent.com/acmesh-official/acme.sh/master/acme.sh || ! (cd "$acme_tmp" && sh ./acme.sh --install) || [ ! -e $HOME/.acme.sh/acme.sh ]; then
            red "安装acme.sh失败"
            rm -rf "$acme_tmp"
            return 1
        fi
        rm -rf "$acme_tmp"
    fi
    # 默认使用Let's Encrypt(无需注册邮箱)；ZeroSSL作为备用(需要邮箱，注册失败不影响)
    $HOME/.acme.sh/acme.sh --set-default-ca --server letsencrypt
    $HOME/.acme.sh/acme.sh --register-account -ak ec-256 --server zerossl -m "my@example.com" || true
    return 0
}

#获取证书 参数: 域名位置
#依次尝试 Let's Encrypt、ZeroSSL。
#注意：不能再使用 --ocsp (OCSP Must-Staple)，Let's Encrypt已不再支持，带此参数申请证书必定失败
get_cert()
{
    if [ ${domain_config_list[$1]} -eq 1 ]; then
        green "正在获取 \"${domain_list[$1]}\"、\"${true_domain_list[$1]}\" 的域名证书"
    else
        green "正在获取 \"${domain_list[$1]}\" 的域名证书"
    fi
    mv $xray_config ${xray_config}.bak
    mv ${nginx_prefix}/conf/nginx.conf ${nginx_prefix}/conf/nginx.conf.bak2
    cp ${nginx_prefix}/conf/nginx.conf.default ${nginx_prefix}/conf/nginx.conf
    echo "{}" > $xray_config
    local domain_args=(-d "${true_domain_list[$1]}")
    [ ${domain_config_list[$1]} -eq 1 ] && domain_args+=(-d "${domain_list[$1]}")
    local pre_hook="mv ${nginx_prefix}/conf/nginx.conf ${nginx_prefix}/conf/nginx.conf.bak && cp ${nginx_prefix}/conf/issue_certs.conf ${nginx_prefix}/conf/nginx.conf && sleep 2s && systemctl restart nginx"
    local post_hook="mv ${nginx_prefix}/conf/nginx.conf.bak ${nginx_prefix}/conf/nginx.conf && sleep 2s && systemctl restart nginx"
    local ca
    local ret
    local issued=0
    for ca in letsencrypt zerossl
    do
        green "正在向 ${ca} 申请证书。。。"
        $HOME/.acme.sh/acme.sh --issue "${domain_args[@]}" -w ${nginx_prefix}/html/issue_certs -k ec-256 -ak ec-256 --server "$ca" --pre-hook "$pre_hook" --post-hook "$post_hook"
        ret=$?
        # 返回2表示证书已存在且未到续期时间，视为成功
        if [ $ret -eq 0 ] || [ $ret -eq 2 ]; then
            issued=1
            break
        fi
        # 若post-hook没有执行，恢复nginx配置
        [ -e ${nginx_prefix}/conf/nginx.conf.bak ] && mv -f ${nginx_prefix}/conf/nginx.conf.bak ${nginx_prefix}/conf/nginx.conf
        rm -rf $HOME/.acme.sh/${true_domain_list[$1]}_ecc
    done
    if [ $issued -eq 0 ]; then
        yellow "申请失败，使用--debug重试(输出详细日志，便于排查)"
        $HOME/.acme.sh/acme.sh --issue "${domain_args[@]}" -w ${nginx_prefix}/html/issue_certs -k ec-256 -ak ec-256 --server letsencrypt --pre-hook "$pre_hook" --post-hook "$post_hook" --debug
        [ -e ${nginx_prefix}/conf/nginx.conf.bak ] && mv -f ${nginx_prefix}/conf/nginx.conf.bak ${nginx_prefix}/conf/nginx.conf
    fi
    if ! $HOME/.acme.sh/acme.sh --installcert -d ${true_domain_list[$1]} --key-file ${nginx_prefix}/certs/${true_domain_list[$1]}.key --fullchain-file ${nginx_prefix}/certs/${true_domain_list[$1]}.cer --reloadcmd "sleep 2s && systemctl restart xray" --ecc; then
        $HOME/.acme.sh/acme.sh --remove --domain ${true_domain_list[$1]} --ecc
        rm -rf $HOME/.acme.sh/${true_domain_list[$1]}_ecc
        rm -rf "${nginx_prefix}/certs/${true_domain_list[$1]}.key" "${nginx_prefix}/certs/${true_domain_list[$1]}.cer"
        mv ${xray_config}.bak $xray_config
        mv ${nginx_prefix}/conf/nginx.conf.bak2 ${nginx_prefix}/conf/nginx.conf
        return 1
    fi
    mv ${xray_config}.bak $xray_config
    mv ${nginx_prefix}/conf/nginx.conf.bak2 ${nginx_prefix}/conf/nginx.conf
    return 0
}
get_all_certs()
{
    local i
    for ((i=0;i<${#domain_list[@]};i++))
    do
        if ! get_cert "$i"; then
            red    "域名\"${true_domain_list[$i]}\"证书申请失败！"
            yellow "请检查："
            yellow "    1.域名是否解析正确"
            yellow "    2.vps防火墙80端口是否开放"
            yellow "并在安装/重置域名完成后，使用脚本主菜单\"重置域名\"选项修复"
            yellow "按回车键继续。。。"
            read -s
        fi
    done
}

#配置nginx
config_nginx_init()
{
cat > ${nginx_prefix}/conf/nginx.conf <<EOF

user  root root;
worker_processes  auto;

#error_log  logs/error.log;
#error_log  logs/error.log  notice;
#error_log  logs/error.log  info;

#pid        logs/nginx.pid;
google_perftools_profiles /dev/shm/nginx/tcmalloc/tcmalloc;

events {
    worker_connections  1024;
}


http {
    include       mime.types;
    default_type  application/octet-stream;
    server_names_hash_bucket_size 64;
    #log_format  main  '\$remote_addr - \$remote_user [\$time_local] "\$request" '
    #                  '\$status \$body_bytes_sent "\$http_referer" '
    #                  '"\$http_user_agent" "\$http_x_forwarded_for"';

    #access_log  logs/access.log  main;

    sendfile        on;
    #tcp_nopush     on;

    #keepalive_timeout  0;
    keepalive_timeout  65;

    #gzip  on;

    include       $nginx_config;
    #server {
        #listen       80;
        #server_name  localhost;

        #charset koi8-r;

        #access_log  logs/host.access.log  main;

        #location / {
        #    root   html;
        #    index  index.html index.htm;
        #}

        #error_page  404              /404.html;

        # redirect server error pages to the static page /50x.html
        #
        #error_page   500 502 503 504  /50x.html;
        #location = /50x.html {
        #    root   html;
        #}

        # proxy the PHP scripts to Apache listening on 127.0.0.1:80
        #
        #location ~ \\.php\$ {
        #    proxy_pass   http://127.0.0.1;
        #}

        # pass the PHP scripts to FastCGI server listening on 127.0.0.1:9000
        #
        #location ~ \\.php\$ {
        #    root           html;
        #    fastcgi_pass   127.0.0.1:9000;
        #    fastcgi_index  index.php;
        #    fastcgi_param  SCRIPT_FILENAME  /scripts\$fastcgi_script_name;
        #    include        fastcgi_params;
        #}

        # deny access to .htaccess files, if Apache's document root
        # concurs with nginx's one
        #
        #location ~ /\\.ht {
        #    deny  all;
        #}
    #}


    # another virtual host using mix of IP-, name-, and port-based configuration
    #
    #server {
    #    listen       8000;
    #    listen       somename:8080;
    #    server_name  somename  alias  another.alias;

    #    location / {
    #        root   html;
    #        index  index.html index.htm;
    #    }
    #}


    # HTTPS server
    #
    #server {
    #    listen       443 ssl;
    #    server_name  localhost;

    #    ssl_certificate      cert.pem;
    #    ssl_certificate_key  cert.key;

    #    ssl_session_cache    shared:SSL:1m;
    #    ssl_session_timeout  5m;

    #    ssl_ciphers  HIGH:!aNULL:!MD5;
    #    ssl_prefer_server_ciphers  on;

    #    location / {
    #        root   html;
    #        index  index.html index.htm;
    #    }
    #}

}
EOF
}
config_nginx()
{
    config_nginx_init
    local i
    local ng_suffix=""
    local ng_default_listen
    local ng_www_listen
    local ng_domain_listen
    ng_default_listen="    listen unix:/dev/shm/nginx/default.sock default_server;
    listen unix:/dev/shm/nginx/h2.sock http2 default_server;"
    ng_www_listen="    listen unix:/dev/shm/nginx/default.sock;
    listen unix:/dev/shm/nginx/h2.sock http2;"
    if [ "$protocol_1" == "1" ]; then
        #REALITY(自己的域名)：Xray通过unix socket回落到Nginx，Nginx需要自己做TLS，HTTP跳转需要带上REALITY端口
        [ "$reality_port" != "443" ] && ng_suffix=":${reality_port}"
        ng_default_listen="    listen unix:/dev/shm/nginx/reality.sock ssl http2 default_server;
    ssl_certificate ${nginx_prefix}/certs/${true_domain_list[0]}.cer;
    ssl_certificate_key ${nginx_prefix}/certs/${true_domain_list[0]}.key;
    ssl_protocols TLSv1.2 TLSv1.3;"
        ng_www_listen=""
    fi
cat > $nginx_config<<EOF
server {
    listen 80 reuseport default_server;
    listen [::]:80 reuseport default_server;
    return 301 https://${domain_list[0]}${ng_suffix};
}
server {
    listen 80;
    listen [::]:80;
    server_name ${domain_list[@]};
    return 301 https://\$host${ng_suffix}\$request_uri;
}
EOF
    local temp_domain_list2=()
    for i in "${!domain_config_list[@]}"
    do
        [ ${domain_config_list[$i]} -eq 1 ] && temp_domain_list2+=("${true_domain_list[$i]}")
    done
    if [ ${#temp_domain_list2[@]} -ne 0 ]; then
cat >> $nginx_config<<EOF
server {
    listen 80;
    listen [::]:80;
${ng_www_listen}
    server_name ${temp_domain_list2[@]};
    return 301 https://www.\$host${ng_suffix}\$request_uri;
}
EOF
        if [ "$protocol_1" == "1" ]; then
            #REALITY: 通过HTTPS(回落)访问主域名时，也需要跳转到www，每个域名使用自己的证书
            for i in "${!domain_config_list[@]}"
            do
                [ ${domain_config_list[$i]} -eq 1 ] || continue
cat >> $nginx_config<<EOF
server {
    listen unix:/dev/shm/nginx/reality.sock ssl http2;
    ssl_certificate ${nginx_prefix}/certs/${true_domain_list[$i]}.cer;
    ssl_certificate_key ${nginx_prefix}/certs/${true_domain_list[$i]}.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    server_name ${true_domain_list[$i]};
    return 301 https://www.\$host${ng_suffix}\$request_uri;
}
EOF
            done
        fi
    fi
cat >> $nginx_config<<EOF
server {
${ng_default_listen}
    return 301 https://${domain_list[0]}${ng_suffix};
}
EOF
    for ((i=0;i<${#domain_list[@]};i++))
    do
        ng_domain_listen="    listen unix:/dev/shm/nginx/default.sock;
    listen unix:/dev/shm/nginx/h2.sock http2;"
        if [ "$protocol_1" == "1" ]; then
            ng_domain_listen="    listen unix:/dev/shm/nginx/reality.sock ssl http2;
    ssl_certificate ${nginx_prefix}/certs/${true_domain_list[$i]}.cer;
    ssl_certificate_key ${nginx_prefix}/certs/${true_domain_list[$i]}.key;
    ssl_protocols TLSv1.2 TLSv1.3;"
        fi
cat >> $nginx_config<<EOF
server {
${ng_domain_listen}
    server_name ${domain_list[$i]};
    add_header Strict-Transport-Security "max-age=63072000; includeSubdomains; preload" always;
EOF
        if [ $protocol_4 -ne 0 ]; then
            #XHTTP的请求路径为 ${xhttp_path}/<sessionId>/<seq> 形式，需前缀匹配；^~ 使其优先于正则location(如nextcloud的php规则)
cat >> $nginx_config<<EOF
    location ^~ ${xhttp_path}/ {
        client_max_body_size 0;
        client_body_buffer_size 1m;
        client_body_timeout 24h;
        keepalive_timeout 24h;
        send_timeout 24h;
        grpc_read_timeout 24h;
        grpc_send_timeout 24h;
        lingering_close always;
        lingering_time 24h;
        lingering_timeout 24h;
        grpc_pass grpc://unix:/dev/shm/xray/xhttp.sock;
    }
EOF
        fi
        if [ "${pretend_list[$i]}" == "1" ]; then
cat >> $nginx_config<<EOF
    location / {
        proxy_set_header X-Forwarded-For 127.0.0.1;
        proxy_set_header Host \$http_host;
        proxy_redirect off;
        proxy_pass http://unix:/dev/shm/cloudreve/cloudreve.sock;
        client_max_body_size 0;
    }
EOF
        elif [ "${pretend_list[$i]}" == "2" ]; then
            echo "    root ${nginx_prefix}/html/${true_domain_list[$i]};" >> $nginx_config
            echo "    include ${nginx_prefix}/conf.d/nextcloud.conf;" >> $nginx_config
        elif [ "${pretend_list[$i]}" == "3" ]; then
            if [ $protocol_4 -ne 0 ]; then
                echo "    location / {" >> $nginx_config
                echo "        return 403;" >> $nginx_config
                echo "    }" >> $nginx_config
            else
                echo "    return 403;" >> $nginx_config
            fi
        elif [ "${pretend_list[$i]}" == "4" ]; then
            echo "    root ${nginx_prefix}/html/${true_domain_list[$i]};" >> $nginx_config
        else
cat >> $nginx_config<<EOF
    location / {
        proxy_pass ${pretend_list[$i]};
        proxy_set_header referer "${pretend_list[$i]}";
        proxy_ssl_server_name on;
    }
EOF
        fi
        echo "}" >> $nginx_config
    done
cat >> $nginx_config << EOF
#-----------------不要修改以下内容----------------
#domain_list=${domain_list[@]}
#true_domain_list=${true_domain_list[@]}
#domain_config_list=${domain_config_list[@]}
#pretend_list=${pretend_list[@]}
EOF
    if [ $protocol_4 -ne 0 ] && [ "$xhttp_split" == "1" ]; then
        echo "#xhttp_up_domain=${xhttp_up_domain}" >> $nginx_config
        echo "#xhttp_down_domain=${xhttp_down_domain}" >> $nginx_config
    fi
}

#配置xray：VLESS + TCP + XTLS-Vision + REALITY
#自己的域名(reality_mode=1)：dest为Nginx的unix socket，serverNames为所有自己的域名
#他人的域名(reality_mode=2)：dest为"域名:443"，serverNames为该域名
config_xray_reality()
{
    local dest
    local names=()
    local n
    local i
    if [ "$reality_mode" == "1" ]; then
        dest="/dev/shm/nginx/reality.sock"
        for n in "${domain_list[@]}" "${true_domain_list[@]}"
        do
            [[ " ${names[*]} " == *" $n "* ]] || names+=("$n")
        done
    else
        dest="$reality_dest"
        names=("$reality_sni")
    fi
cat > $xray_config <<EOF
{
    "log": {
        "loglevel": "none"
    },
    "inbounds": [
        {
            "port": ${reality_port},
            "protocol": "vless",
            "settings": {
                "clients": [
                    {
                        "id": "${xid_1}",
                        "flow": "xtls-rprx-vision"
                    }
                ],
                "decryption": "none"
            },
            "streamSettings": {
                "network": "tcp",
                "security": "reality",
                "realitySettings": {
                    "show": false,
                    "dest": "${dest}",
                    "xver": 0,
                    "serverNames": [
EOF
    for ((i=0;i<${#names[@]};i++))
    do
        if [ $i -eq $((${#names[@]}-1)) ]; then
            echo "                        \"${names[$i]}\"" >> $xray_config
        else
            echo "                        \"${names[$i]}\"," >> $xray_config
        fi
    done
cat >> $xray_config <<EOF
                    ],
                    "privateKey": "${reality_private_key}",
                    "shortIds": [
                        "${reality_short_id}"
                    ]
                }
            },
            "sniffing": {
                "enabled": true,
                "destOverride": [
                    "http",
                    "tls",
                    "quic"
                ]
            }
        }
    ],
    "routing": {
        "rules": [
            {
                "type": "field",
                "protocol": ["bittorrent"],
                "outboundTag": "blocked"
            }
        ]
    },
    "outbounds": [
        {
            "protocol": "freedom"
        },
        {
            "protocol": "blackhole",
            "tag": "blocked"
        }
    ]
}
EOF
}
#配置xray
config_xray()
{
    local i
    local temp_domain
    if [ "${legacy_grpc_ws:-0}" != "0" ] || [ "${legacy_tcp_tls:-0}" == "1" ]; then
        yellow "已移除旧版本遗留的gRPC/WebSocket/TCP(XTLS/TLS)配置(本脚本已不再支持)，请将客户端改为REALITY或XHTTP"
        legacy_grpc_ws=0
        legacy_tcp_tls=0
    fi
    if [ "$protocol_1" == "1" ]; then
        config_xray_reality
        return
    fi
cat > $xray_config <<EOF
{
    "log": {
        "loglevel": "none"
    },
    "inbounds": [
        {
            "sniffing": {
                "enabled": true
            },
            "port": 443,
            "protocol": "vless",
            "settings": {
EOF
    echo '                "decryption": "none",' >> $xray_config
    echo '                "fallbacks": [' >> $xray_config
cat >> $xray_config <<EOF
                    {
                        "alpn": "h2",
                        "dest": "/dev/shm/nginx/h2.sock"
                    },
                    {
                        "dest": "/dev/shm/nginx/default.sock"
                    }
                ]
            },
            "streamSettings": {
                "network": "tcp",
                "security": "tls",
                "tlsSettings": {
                    "alpn": [
                        "h2",
                        "http/1.1"
                    ],
                    "minVersion": "1.2",
                    "certificates": [
EOF
    for ((i=0;i<${#true_domain_list[@]};i++))
    do
cat >> $xray_config <<EOF
                        {
                            "certificateFile": "${nginx_prefix}/certs/${true_domain_list[$i]}.cer",
                            "keyFile": "${nginx_prefix}/certs/${true_domain_list[$i]}.key"
EOF
        ((i==${#true_domain_list[@]}-1)) && echo "                        }" >> $xray_config || echo "                        }," >> $xray_config
    done
cat >> $xray_config <<EOF
                    ]
                }
            }
EOF
    if [ $protocol_4 -ne 0 ]; then
        echo '        },' >> $xray_config
        echo '        {' >> $xray_config
cat >> $xray_config <<EOF
            "listen": "/dev/shm/xray/xhttp.sock",
            "protocol": "vless",
            "settings": {
                "clients": [
                    {
                        "id": "$xid_4"
                    }
                ],
                "decryption": "none"
            },
            "sniffing": {
                "enabled": true
            },
            "streamSettings": {
                "network": "xhttp",
                "xhttpSettings": {
                    "path": "$xhttp_path",
                    "mode": "auto"
                }
            }
EOF
    fi
cat >> $xray_config <<EOF
        }
    ],
    "routing": {
        "rules": [
            {
                "type": "field",
                "protocol": ["bittorrent"],
                "outboundTag": "blocked"
            }
        ]
    },
    "outbounds": [
        {
            "protocol": "freedom"
        },
        {
            "protocol": "blackhole",
            "tag": "blocked"
        }
    ]
}
EOF
}

init_web()
{
    systemctl stop php-fpm
    systemctl stop cloudreve
    if [ "${pretend_list[$1]}" == "1" ]; then
        if [ $cloudreve_is_installed -eq 1 ]; then
            systemctl start cloudreve
            systemctl enable cloudreve
            let_change_cloudreve_domain "$1"
        else
            install_init_cloudreve "$1"
        fi
        turn_on_off_php
    elif [ "${pretend_list[$1]}" == "2" ]; then
        if ! curl -o "${nginx_prefix}/html/nextcloud.tar.bz2" "${nextcloud_url}"; then
            red    "获取Nextcloud失败"
            yellow "按回车键继续或者按Ctrl+c终止"
            read -s
        fi
        rm -rf "${nginx_prefix}/html/nextcloud"
        if ! tar -xjf "${nginx_prefix}/html/nextcloud.tar.bz2" -C "${nginx_prefix}/html"; then
            red    "解压 Nextcloud 失败"
            yellow "按回车键继续或者按Ctrl+c终止"
            read -s
        fi
        rm -f "${nginx_prefix}/html/nextcloud.tar.bz2"
        rm -rf "${nginx_prefix}/html/${true_domain_list[$1]}"
        mv "${nginx_prefix}/html/nextcloud" "${nginx_prefix}/html/${true_domain_list[$1]}"
        chown -R www-data:www-data "${nginx_prefix}/html/${true_domain_list[$1]}"
        systemctl start php-fpm
        systemctl enable php-fpm
        let_init_nextcloud "$1"
        turn_on_off_cloudreve
    elif [ "${pretend_list[$1]}" == "4" ]; then
        mkdir "${nginx_prefix}/html/${true_domain_list[$1]}"
        turn_on_off_php
        turn_on_off_cloudreve
    else
        turn_on_off_php
        turn_on_off_cloudreve
    fi
}

#安装/更新Cloudreve
update_cloudreve()
{
    green "正在安装/更新Cloudreve。。。"
    local temp_cloudreve_status=0
    systemctl -q is-active cloudreve && temp_cloudreve_status=1
    systemctl stop cloudreve
    if ! wget -O "$cloudreve_prefix/cloudreve.tar.gz" "https://github.com/cloudreve/Cloudreve/releases/download/${cloudreve_version}/cloudreve_${cloudreve_version}_linux_${machine}.tar.gz"; then
        red "获取Cloudreve失败！！"
        yellow "按回车键继续或者按Ctrl+c终止"
        read -s
    fi
    tar -zxf "$cloudreve_prefix/cloudreve.tar.gz" -C "$cloudreve_prefix" cloudreve
    rm -f "$cloudreve_prefix/cloudreve.tar.gz"
    chmod +x "$cloudreve_prefix/cloudreve"
cat > $cloudreve_prefix/conf.ini << EOF
[System]
Mode = master
Debug = false
[UnixSocket]
Listen = /dev/shm/cloudreve/cloudreve.sock
EOF
    rm -rf $cloudreve_service
cat > $cloudreve_service << EOF
[Unit]
Description=Cloudreve
Documentation=https://docs.cloudreve.org
After=network.target
After=mysqld.service
Wants=network.target

[Service]
WorkingDirectory=$cloudreve_prefix
ExecStartPre=/bin/rm -rf /dev/shm/cloudreve
ExecStartPre=/bin/mkdir /dev/shm/cloudreve
ExecStartPre=/bin/chmod 711 /dev/shm/cloudreve
ExecStart=$cloudreve_prefix/cloudreve
ExecStopPost=/bin/rm -rf /dev/shm/cloudreve
Restart=on-abnormal
RestartSec=5s
KillMode=mixed

StandardOutput=null
StandardError=syslog

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    [ $temp_cloudreve_status -eq 1 ] && systemctl start cloudreve
}
install_init_cloudreve()
{
    remove_cloudreve
    mkdir -p $cloudreve_prefix
    chmod 0700 $cloudreve_prefix
    update_cloudreve
    rm -rf /dev/shm/cloudreve
    local password
    password="$("$cloudreve_prefix/cloudreve" | grep "password" | awk '{print $6}')"
    sleep 1s
    systemctl start cloudreve
    systemctl enable cloudreve
    tyblue "-------- 请打开\"https://${domain_list[$1]}\"进行Cloudreve初始化 -------"
    tyblue "  1. 登陆帐号"
    purple "    初始管理员账号：admin@cloudreve.org"
    purple "    初始管理员密码：$password"
    tyblue "  2. 右上角头像 -> 管理面板"
    tyblue "  3. 这时会弹出对话框 \"确定站点URL设置\" 选择 \"更改\""
    tyblue "  4. 左侧参数设置 -> 注册与登陆 -> 不允许新用户注册 -> 往下拉点击保存"
    sleep 15s
    echo -e "\\n\\n"
    tyblue "按两次回车键以继续。。。"
    read -s
    read -s
    cloudreve_is_installed=1
}

#初始化nextcloud 参数 1:域名在列表中的位置
let_init_nextcloud()
{
    echo -e "\\n\\n"
    yellow "请尽快打开\"https://${domain_list[$1]}\"进行Nextcloud初始化设置："
    tyblue " 1. 初始化管理员用户名和密码"
    tyblue " 2. 数据库类型选择SQLite"
    tyblue " 3. 不建议勾选\"安装推荐的应用\"，初始化完成后还能安装"
    sleep 15s
    echo -e "\\n\\n"
    tyblue "按两次回车键以继续。。。"
    read -s
    read -s
    echo
}

#URL编码(仅保留字母数字及._~-)
urlencode_str()
{
    local str="$1"
    local i
    local c
    local out=""
    local LC_ALL=C
    for ((i=0;i<${#str};i++))
    do
        c="${str:$i:1}"
        case "$c" in
            [a-zA-Z0-9._~-]) out+="$c" ;;
            *) out+="$(printf '%%%02X' "'$c")" ;;
        esac
    done
    echo -n "$out"
}
#XHTTP上下行分离的extra(下行连接)配置，紧凑JSON，用于分享链接
get_xhttp_split_extra_json()
{
    echo -n "{\"downloadSettings\":{\"address\":\"${xhttp_down_domain}\",\"port\":443,\"network\":\"xhttp\",\"security\":\"tls\",\"tlsSettings\":{\"serverName\":\"${xhttp_down_domain}\",\"alpn\":[\"h2\"],\"fingerprint\":\"chrome\"},\"xhttpSettings\":{\"path\":\"${xhttp_path}\",\"host\":\"${xhttp_down_domain}\"}}}"
}
#输出XHTTP上下行分离的Xray客户端outbound配置(JSON)
print_xhttp_split_json()
{
cat <<EOF
{
    "protocol": "vless",
    "settings": {
        "vnext": [
            {
                "address": "${xhttp_up_domain}",
                "port": 443,
                "users": [
                    {
                        "id": "${xid_4}",
                        "encryption": "none"
                    }
                ]
            }
        ]
    },
    "streamSettings": {
        "network": "xhttp",
        "security": "tls",
        "tlsSettings": {
            "serverName": "${xhttp_up_domain}",
            "alpn": ["h2"],
            "fingerprint": "chrome"
        },
        "xhttpSettings": {
            "path": "${xhttp_path}",
            "host": "${xhttp_up_domain}",
            "mode": "packet-up",
            "extra": {
                "downloadSettings": {
                    "address": "${xhttp_down_domain}",
                    "port": 443,
                    "network": "xhttp",
                    "security": "tls",
                    "tlsSettings": {
                        "serverName": "${xhttp_down_domain}",
                        "alpn": ["h2"],
                        "fingerprint": "chrome"
                    },
                    "xhttpSettings": {
                        "path": "${xhttp_path}",
                        "host": "${xhttp_down_domain}"
                    }
                }
            }
        }
    }
}
EOF
}
#输出REALITY的连接信息、分享链接和二维码
print_reality_info()
{
    local addr
    local ip
    local sni_list=()
    local sni
    local n
    local link
    local first_link=""
    if [ "$reality_mode" == "1" ]; then
        for n in "${domain_list[@]}" "${true_domain_list[@]}"
        do
            [[ " ${sni_list[*]} " == *" $n "* ]] || sni_list+=("$n")
        done
    else
        sni_list=("$reality_sni")
    fi
    if ip="$(get_server_ip)"; then
        addr="$ip"
    else
        addr="服务器IP"
        yellow "未能自动获取服务器公网IP，请将下面的\"服务器IP\"替换为您的服务器IP"
    fi
    [[ "$addr" =~ : ]] && [[ ! "$addr" =~ ^\[ ]] && addr="[$addr]"
    tyblue "--------------------- VLESS-TCP-XTLS-Vision-REALITY (不走CDN) ---------------------"
    tyblue " protocol(传输协议)    ：vless"
    purple "  (V2RayN选择\"添加[VLESS]服务器\";V2RayNG选择\"手动输入[VLESS]\")"
    tyblue " address(地址)         ：${addr}"
    tyblue " port(端口)            ：${reality_port}"
    tyblue " id(用户ID/UUID)       ：${xid_1}"
    tyblue " flow(流控)            ：xtls-rprx-vision"
    tyblue " encryption(加密)      ：none"
    tyblue " network(传输方式)     ：tcp"
    tyblue " type(伪装类型)        ：none"
    tyblue " security(传输层加密)  ：reality"
    if [ ${#sni_list[@]} -eq 1 ]; then
        tyblue " serverName(SNI)       ：${sni_list[*]}"
    else
        tyblue " serverName(SNI)       ：${sni_list[*]} (任选其一)"
    fi
    tyblue " fingerprint(指纹)     ：chrome"
    tyblue " publicKey(公钥)       ：${reality_public_key}"
    tyblue " shortId               ：${reality_short_id}"
    tyblue " spiderX               ：/"
    tyblue " Mux(多路复用)         ：请关闭"
    if [ "$reality_mode" == "1" ]; then
        purple "  (伪装域名为自己的域名：Xray回落到本机Nginx，REALITY握手使用真实证书与伪装网站)"
    else
        purple "  (伪装域名为他人的域名：REALITY握手目标为 ${reality_dest}，本机没有Nginx)"
    fi
    echo
    tyblue "分享链接："
    for sni in "${sni_list[@]}"
    do
        link="vless://${xid_1}@${addr}:${reality_port}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${sni}&fp=chrome&pbk=${reality_public_key}&sid=${reality_short_id}&spx=%2F&type=tcp&headerType=none#Xray-REALITY"
        [ -z "$first_link" ] && first_link="$link"
        green "$link"
    done
    echo
    if command -v qrencode >/dev/null 2>&1; then
        tyblue "二维码(${sni_list[0]})："
        qrencode -t ANSIUTF8 "$first_link"
    else
        yellow "未安装qrencode，无法显示二维码"
    fi
    tyblue "------------------------------------------------------------------------"
}
print_share_link()
{
    echo
    tyblue "分享链接："
    if [ $protocol_4 -ne 0 ] && [ "$xhttp_split" == "1" ]; then
        green  "=========== VLESS-XHTTP-TLS 上下行分离 (上行域名连接\"${xhttp_up_domain}\"，下行域名连接\"${xhttp_down_domain}\") ==========="
        tyblue "vless://${xid_4}@${xhttp_up_domain}:443?encryption=none&type=xhttp&security=tls&sni=${xhttp_up_domain}&host=${xhttp_up_domain}&path=%2F${xhttp_path#/}&mode=packet-up&alpn=h2&fp=chrome&extra=$(urlencode_str "$(get_xhttp_split_extra_json)")"
        yellow "上下行分离的分享链接依赖客户端对extra(downloadSettings)的支持，若导入后未分离，请按连接信息中的参数/JSON手动配置"
    elif [ $protocol_4 -ne 0 ]; then
        green  "=========== VLESS-XHTTP-TLS \\033[35m(若域名开启了CDN解析则会连接CDN，否则将直连)\\033[32m ==========="
        for i in "${domain_list[@]}"
        do
            tyblue "vless://${xid_4}@${i}:443?encryption=none&type=xhttp&security=tls&sni=${i}&host=${i}&path=%2F${xhttp_path#/}&mode=packet-up&alpn=h2"
        done
    fi
}
print_config_info()
{
    echo -e "\\n\\n\\n"
    if [ "$protocol_1" == "1" ]; then
        print_reality_info
    fi
    if [ $protocol_4 -ne 0 ] && [ "$xhttp_split" == "1" ]; then
        echo
        tyblue "------------- VLESS-XHTTP-TLS 上下行分离 (上行/下行各连各的域名，均可过CDN) -------------"
        tyblue " protocol(传输协议)    ：\\033[33mvless"
        purple "  (V2RayN选择\"添加[VLESS]服务器\";V2RayNG选择\"手动输入[VLESS]\")"
        tyblue " port(端口)            ：\\033[33m443"
        tyblue " id(用户ID/UUID)       ：\\033[33m${xid_4}"
        tyblue " flow(流控)            ：\\033[33m空"
        tyblue " encryption(加密)      ：\\033[33mnone"
        tyblue " network(传输方式)     ：\\033[33mxhttp"
        tyblue " path(路径)            ：\\033[33m${xhttp_path}\\033[35m (上行、下行相同)"
        tyblue " security(传输层加密)  ：\\033[33mtls"
        tyblue " allowInsecure         ：\\033[33mfalse"
        tyblue " fingerprint           ：\\033[33m空\\033[36m/\\033[33mchrome\\033[32m(推荐)\\033[36m/\\033[33mfirefox\\033[36m/\\033[33msafari"
        tyblue " alpn                  ：建议设置为\\033[33mh2"
        tyblue " Mux(多路复用)         ：请关闭"
        echo
        tyblue " ======== 主连接 = 上行 (客户端上传数据) ========"
        tyblue "  address(地址)               ：\\033[33m${xhttp_up_domain}\\033[35m (使用CDN优选IP时可填优选IP，host/serverName仍填该域名)"
        tyblue "  host                        ：\\033[33m${xhttp_up_domain}"
        tyblue "  serverName(SNI)             ：\\033[33m${xhttp_up_domain}"
        tyblue "  mode(模式)                  ：\\033[33mpacket-up\\033[32m(推荐)"
        purple "   (stream-up/stream-one需要CDN到服务器全程HTTP/2流式传输，经HTTP/1.1回源的CDN大流量上传可能卡住，不建议过CDN使用；上下行分离不支持stream-one)"
        tyblue " ======== downloadSettings = 下行 (客户端下载数据) ========"
        purple "  (位于xhttpSettings的extra中，如客户端不支持图形化配置，请使用下方JSON)"
        tyblue "  address(地址)               ：\\033[33m${xhttp_down_domain}\\033[35m (使用CDN优选IP时可填优选IP，host/serverName仍填该域名)"
        tyblue "  port(端口)                  ：\\033[33m443"
        tyblue "  host                        ：\\033[33m${xhttp_down_domain}"
        tyblue "  serverName(SNI)             ：\\033[33m${xhttp_down_domain}"
        tyblue "  path(路径)                  ：\\033[33m${xhttp_path}"
        tyblue "  security/alpn/fingerprint   ：与上行相同(tls / h2 / chrome)"
        echo
        yellow " 上行域名与下行域名需分别解析到此服务器，可各自接入不同的CDN；两个域名共用同一个path和同一个UUID"
        yellow " 客户端Xray内核需支持downloadSettings(已实测v24.11.21与v26.10.21可用，建议使用最新版)"
        tyblue " ------------- Xray客户端outbound配置(JSON，可直接使用) -------------"
        print_xhttp_split_json
        tyblue "------------------------------------------------------------------------"
    elif [ $protocol_4 -ne 0 ]; then
        echo
        tyblue "------------- VLESS-XHTTP-TLS (有CDN则走CDN，否则直连) -------------"
        tyblue " protocol(传输协议)    ：\\033[33mvless"
        purple "  (V2RayN选择\"添加[VLESS]服务器\";V2RayNG选择\"手动输入[VLESS]\")"
        if [ ${#domain_list[@]} -eq 1 ]; then
            tyblue " address(地址)         ：\\033[33m${domain_list[*]}"
        else
            tyblue " address(地址)         ：\\033[33m${domain_list[*]} \\033[35m(任选其一)"
        fi
        purple "  (Qv2ray:主机) (使用CDN优选IP时，address可填优选IP，此时host与serverName必须填域名)"
        tyblue " port(端口)            ：\\033[33m443"
        tyblue " id(用户ID/UUID)       ：\\033[33m${xid_4}"
        tyblue " flow(流控)            ：\\033[33m空"
        tyblue " encryption(加密)      ：\\033[33mnone"
        tyblue " ---Transport/StreamSettings(底层传输方式/流设置)---"
        tyblue "  network(传输方式)             ：\\033[33mxhttp"
        purple "   (部分客户端显示为splithttp/xhttp)"
        tyblue "  path(路径)                    ：\\033[33m${xhttp_path}"
        tyblue "  host                          ：\\033[33m域名\\033[35m(与serverName一致，address填域名时可留空)"
        tyblue "  mode(模式)                    ：\\033[33mpacket-up\\033[32m(推荐，兼容各类CDN)"
        purple "   (stream-up/stream-one需要CDN到服务器全程HTTP/2流式传输，经HTTP/1.1回源的CDN大流量上传可能卡住，不建议过CDN使用)"
        tyblue "  extra/downloadSettings        ：\\033[33m不配置\\033[35m(上下行均走同一域名/同一条CDN链路，不分离)"
        tyblue "  security(传输层加密)          ：\\033[33mtls"
        purple "   (V2RayN(G):底层传输安全;Qv2ray:TLS设置-安全类型)"
        if [ ${#domain_list[@]} -eq 1 ]; then
            tyblue "  serverName                    ：\\033[33m${domain_list[*]}"
        else
            tyblue "  serverName                    ：\\033[33m${domain_list[*]} \\033[35m(与address所选域名一致)"
        fi
        purple "   (V2RayN(G):SNI;Qv2ray:TLS设置-服务器地址;Shadowrocket:Peer 名称)"
        tyblue "  allowInsecure                 ：\\033[33mfalse"
        purple "   (Qv2ray:TLS设置-允许不安全的证书(不打勾);Shadowrocket:允许不安全(关闭))"
        tyblue "  fingerprint                   ：\\033[33m空\\033[36m/\\033[33mchrome\\033[32m(推荐)\\033[36m/\\033[33mfirefox\\033[36m/\\033[33msafari"
        purple "                                           (此选项决定是否伪造浏览器指纹，空代表不伪造)"
        tyblue "  alpn                          ：建议设置为\\033[33mh2 \\033[35m(也可设置为h2,http/1.1)"
        purple "   (Qv2ray:TLS设置-ALPN) (注意Qv2ray如果要设置alpn为h2,http/1.1，请填写\"h2|http/1.1\")"
        tyblue " ------------------------其他-----------------------"
        tyblue "  Mux(多路复用)                 ：请关闭 (XHTTP自带连接复用，无需开启Mux)"
        purple "   (V2RayN:设置页面-开启Mux多路复用)"
        tyblue "------------------------------------------------------------------------"
    fi
    echo
    yellow "注：部分选项可能分享链接无法涉及，如果不怕麻烦，建议手动填写"
    # ask_if "是否生成分享链接？(y/n)" && print_share_link
    echo
    yellow " 关于fingerprint与alpn，详见：https://github.com/CatherineReyes-byte/Xray-script#关于tls握手tls指纹和alpn"
    echo
    blue   " 若要实现Fullcone(NAT类型开放)，需要以下条件："
    blue   "   如果客户端系统为Windows，并且正在使用透明代理或TUN/Bypass LAN，请确保当前网络设置为专用网络"
    echo
    tyblue " 脚本最后更新时间：2023.1.1"
    echo
    red    " 此脚本仅供交流学习使用，请勿使用此脚本行违法之事。网络非法外之地，行非法之事，必将接受法律制裁!!!!"
    tyblue " 2020.11"
}

install_update_xray_tls_web()
{
    in_install_update_xray_tls_web=1
    local ret
    if [ $update -eq 1 ]; then
        get_config_info
        if [ "${legacy_grpc_ws:-0}" != "0" ] || [ "${legacy_tcp_tls:-0}" == "1" ]; then
            red    "检测到旧版本遗留的gRPC/WebSocket/TCP(XTLS/TLS)配置，本脚本已不再支持！"
            yellow "继续更新将移除它们(REALITY/XHTTP配置不受影响)，客户端需改用REALITY或XHTTP"
            if ! ask_if "是否继续更新？(y/n)"; then
                in_install_update_xray_tls_web=0
                return 0
            fi
        fi
        #REALITY(他人域名)直连模式没有Nginx，走精简的更新流程
        if [ "$reality_direct" == "1" ]; then
            update_reality_direct
            ret=$?
            in_install_update_xray_tls_web=0
            return $ret
        fi
    else
        #先选择传输协议(REALITY可自定义端口，端口检查依赖该选择)
        readProtocolConfig
        if [ "$protocol_1" == "1" ]; then
            readRealityType
            if [ "$reality_mode" == "2" ]; then
                #REALITY(他人域名)：只安装Xray，走精简的安装流程
                install_reality_direct
                ret=$?
                in_install_update_xray_tls_web=0
                return $ret
            fi
        fi
    fi
    check_nginx_installed_system
    [ "$dnf" == "yum" ] && check_important_dependence_installed "" "yum-utils"
    check_SELinux
    check_important_dependence_installed iproute2 iproute
    check_port_for_mode
    check_important_dependence_installed tzdata tzdata
    get_system_info
    check_important_dependence_installed ca-certificates ca-certificates
    check_important_dependence_installed wget wget
    check_important_dependence_installed "procps" "procps-ng"
    install_epel
    # ask_update_script
    # check_ssh_timeout
    uninstall_firewall
    doupdate
    enter_temp_dir
    install_bbr
    $apt_no_install_recommends -y -f install

    #读取信息
    if [ $update -eq 0 ]; then
        if [ "$protocol_1" == "1" ]; then
            #REALITY(自己的域名)：域名、证书模式、伪装网站，再读取安全参数
            readDomain
            readRealitySecurity
        elif [ "$xhttp_split" == "1" ]; then
            readXhttpSplitDomains
        else
            readDomain
        fi
        xhttp_path="/$(head -c 20 /dev/urandom | md5sum | head -c 10)"
        xid_4="$(cat /proc/sys/kernel/random/uuid)"
    else
        get_config_info
    fi

    local choice

    local install_php
    if [ $update -eq 0 ]; then
        [ "${pretend_list[0]}" == "2" ] && install_php=1 || install_php=0
    else
        install_php=$php_is_installed
    fi
    local use_existed_php=0
    if [ $install_php -eq 1 ]; then
        if [ $update -eq 1 ]; then
            if check_php_update; then
                ! ask_if "检测到php有新版本，是否更新?(y/n)" && use_existed_php=1
            else
                green "php已经是最新版本，不更新"
                use_existed_php=1
            fi
        elif [ $php_is_installed -eq 1 ]; then
            tyblue "---------------检测到php已存在---------------"
            tyblue " 1. 使用现有php"
            tyblue " 2. 卸载现有php并重新编译安装"
            echo
            choice=""
            while [ "$choice" != "1" ] && [ "$choice" != "2" ]
            do
                read -p "您的选择是：" choice
            done
            [ $choice -eq 1 ] && use_existed_php=1
        fi
    fi

    local use_existed_nginx=0
    if [ $update -eq 1 ]; then
        if check_nginx_update; then
            ! ask_if "检测到Nginx有新版本，是否更新?(y/n)" && use_existed_nginx=1
        else
            green "Nginx已经是最新版本，不更新"
            use_existed_nginx=1
        fi
    elif [ $nginx_is_installed -eq 1 ]; then
        tyblue "---------------检测到Nginx已存在---------------"
        tyblue " 1. 使用现有Nginx"
        tyblue " 2. 卸载现有Nginx并重新编译安装"
        echo
        choice=""
        while [ "$choice" != "1" ] && [ "$choice" != "2" ]
        do
            read -p "您的选择是：" choice
        done
        [ $choice -eq 1 ] && use_existed_nginx=1
    fi
    #此参数只在[ $update -eq 0 ]时有效
    local temp_remove_cloudreve=1
    if [ $update -eq 0 ] && [ "${pretend_list[0]}" == "1" ] && [ $cloudreve_is_installed -eq 1 ]; then
        tyblue "----------------- Cloudreve已存在 -----------------"
        tyblue " 1. 使用现有Cloudreve"
        tyblue " 2. 卸载并重新安装"
        echo
        red    "警告：卸载Cloudreve将删除网盘中所有文件和用户信息"
        choice=""
        while [ "$choice" != "1" ] && [ "$choice" != "2" ]
        do
            read -p "您的选择是：" choice
        done
        [ $choice -eq 1 ] && temp_remove_cloudreve=0
    fi

    if [ $update -eq 0 ]; then
        green "即将开始安装Xray-TLS+Web，可能需要10-20分钟。。。"
        sleep 3s
    fi

    [ $use_existed_nginx -eq 0 ] && install_nginx_compile_toolchains
    install_nginx_dependence
    if [ $install_php -eq 1 ]; then
        [ $use_existed_php -eq 0 ] && install_php_compile_toolchains
        install_php_dependence
    fi
    install_acme_dependence
    if [ $update -eq 0 ]; then
        install_web_dependence ""
    else
        [ $cloudreve_is_installed -eq 1 ] && install_web_dependence "1"
    fi
    $apt clean
    $dnf clean all

    #编译&&安装php
    if [ $install_php -eq 1 ]; then
        if [ $use_existed_php -eq 0 ]; then
            compile_php
            remove_php
            install_php_part1
        else
            systemctl stop php-fpm
            systemctl disable php-fpm
        fi
        install_php_part2
        [ $update -eq 1 ] && turn_on_off_php
    fi

    #编译&&安装Nginx
    if [ $use_existed_nginx -eq 0 ]; then
        compile_nginx
        [ $update -eq 1 ] && backup_domains_web
        remove_nginx
        install_nginx_part1
    else
        systemctl stop nginx
        systemctl disable nginx
        rm -rf ${nginx_prefix}/conf.d
        rm -rf ${nginx_prefix}/certs
        rm -rf ${nginx_prefix}/html/issue_certs
        rm -rf ${nginx_prefix}/conf/issue_certs.conf
        cp ${nginx_prefix}/conf/nginx.conf.default ${nginx_prefix}/conf/nginx.conf
    fi
    install_nginx_part2
    [ $update -eq 1 ] && [ $use_existed_nginx -eq 0 ] && mv "${temp_dir}/domain_backup/"* ${nginx_prefix}/html 2>/dev/null

    #安装Xray
    remove_xray
    install_update_xray
    if [ $protocol_4 -ne 0 ] && ! check_xray_support_xhttp; then
        red    "当前安装的Xray版本过低，不支持XHTTP传输(需要v24.11.21及以上)！"
        yellow "按回车键继续或者按Ctrl+c终止"
        read -s
    fi
    if [ "$protocol_1" == "1" ] && [ $update -eq 0 ]; then
        if ! generate_reality_keys; then
            red "生成REALITY的密钥/shortId失败！(自定义的私钥格式不正确，或xray x25519命令不可用)"
            cd /
            rm -rf "$temp_dir"
            in_install_update_xray_tls_web=0
            return 1
        fi
    fi

    if [ $update -eq 0 ]; then
        install_acme_sh
    fi
    $HOME/.acme.sh/acme.sh --upgrade --auto-upgrade
    get_all_certs

    #配置Nginx和Xray
    config_nginx
    config_xray
    if [ "$protocol_1" == "1" ] && ! xray run -test -c "$xray_config" >/dev/null 2>&1; then
        red "Xray配置校验失败！"
        xray run -test -c "$xray_config"
        cd /
        rm -rf "$temp_dir"
        in_install_update_xray_tls_web=0
        return 1
    fi
    sleep 2s
    systemctl stop cloudreve
    systemctl restart xray nginx
    if [ "$protocol_1" == "1" ] && ! check_xray_listening; then
        red    "Xray没有在端口${reality_port}上正常监听！"
        yellow "请查看日志：journalctl -u xray -n 30 --no-pager"
    fi
    if [ $update -eq 0 ]; then
        [ "${pretend_list[0]}" == "1" ] && [ $temp_remove_cloudreve -eq 1 ] && remove_cloudreve
        init_web 0
        [ "$xhttp_split" == "1" ] && init_web 1
        green "-------------------安装完成-------------------"
        print_config_info
    else
        [ $cloudreve_is_installed -eq 1 ] && update_cloudreve
        turn_on_off_cloudreve
        green "-------------------更新完成-------------------"
    fi
    cd /
    rm -rf "$temp_dir"
    in_install_update_xray_tls_web=0
}

#等待Xray启动并在REALITY端口上监听，成功返回0，超时返回1
check_xray_listening()
{
    local i
    for ((i=0;i<10;i++))
    do
        if systemctl -q is-active xray && ss -ltn 2>/dev/null | awk '{print $4}' | grep -Eq "[:.]${reality_port}$"; then
            return 0
        fi
        sleep 1s
    done
    return 1
}
#REALITY(他人域名)直连模式安装/更新失败时统一收尾
reality_abort()
{
    red "$1"
    cd /
    rm -rf "$temp_dir"
    in_install_update_xray_tls_web=0
}
#REALITY(他人域名)直连模式：基础环境检查与准备(两个流程共用)
#成功返回0，失败返回1
reality_direct_prepare()
{
    local cmd
    local missing=0
    [ "$dnf" == "yum" ] && check_important_dependence_installed "" "yum-utils"
    check_important_dependence_installed iproute2 iproute
    check_important_dependence_installed tzdata tzdata
    get_system_info
    check_important_dependence_installed ca-certificates ca-certificates
    check_important_dependence_installed wget wget
    check_important_dependence_installed "procps" "procps-ng"
    install_epel
    uninstall_firewall
    doupdate
    enter_temp_dir
    install_bbr
    $apt_no_install_recommends -y -f install
    #依赖校验
    for cmd in curl openssl ss systemctl
    do
        if ! command -v $cmd >/dev/null 2>&1; then
            red "缺少必需的命令：${cmd}"
            missing=1
        fi
    done
    if [ $missing -eq 1 ]; then
        reality_abort "依赖校验失败，请先手动安装缺失的组件后重试"
        return 1
    fi
    command -v jq >/dev/null 2>&1 || yellow "未安装jq，将使用备用方式获取Xray最新版本号"
    command -v qrencode >/dev/null 2>&1 || yellow "未安装qrencode，将无法显示二维码"
    return 0
}
#安装 VLESS + TCP + XTLS-Vision + REALITY (他人的域名，纯直连，只安装Xray)
install_reality_direct()
{
    green "---------- 安装 VLESS + TCP + XTLS-Vision + REALITY (他人的域名) ----------"
    check_important_dependence_installed iproute2 iproute
    check_port_for_mode
    reality_direct_prepare || return 1
    readRealityDirectDomain
    readRealitySecurity
    #已有的Nginx/php/Cloudreve在本模式下用不到
    if [ $nginx_is_installed -eq 1 ] || [ $php_is_installed -eq 1 ] || [ $cloudreve_is_installed -eq 1 ]; then
        yellow "检测到已安装Nginx/php/Cloudreve，REALITY(他人的域名)模式不需要它们"
        yellow "继续将卸载它们(包括网站文件、证书和Cloudreve网盘数据)！"
        if ! ask_if "是否继续？(y/n)"; then
            cd /
            rm -rf "$temp_dir"
            return 0
        fi
        remove_cloudreve
        remove_php
        remove_nginx
    fi
    #安装Xray(最新稳定版)
    remove_xray
    if ! install_update_xray || ! command -v xray >/dev/null 2>&1; then
        reality_abort "Xray安装失败！"
        return 1
    fi
    if ! generate_reality_keys; then
        reality_abort "生成REALITY的密钥/shortId失败！(自定义的私钥格式不正确，或xray x25519命令不可用)"
        return 1
    fi
    protocol_4=0
    xhttp_split=0
    config_xray
    if ! xray run -test -c "$xray_config" >/dev/null 2>&1; then
        xray run -test -c "$xray_config"
        reality_abort "Xray配置校验失败！"
        return 1
    fi
    systemctl restart xray
    if ! check_xray_listening; then
        yellow "请查看日志：journalctl -u xray -n 30 --no-pager"
        reality_abort "Xray没有在端口${reality_port}上正常监听！"
        return 1
    fi
    reality_direct=1
    nginx_is_installed=0
    xray_is_installed=1
    is_installed=1
    green "-------------------安装完成-------------------"
    print_config_info
    cd /
    rm -rf "$temp_dir"
    in_install_update_xray_tls_web=0
    return 0
}
#更新 VLESS + TCP + XTLS-Vision + REALITY (他人的域名)：更新系统组件和Xray，保持原有配置
update_reality_direct()
{
    green "---------- 更新 VLESS + TCP + XTLS-Vision + REALITY (他人的域名) ----------"
    reality_direct_prepare || return 1
    if ! install_update_xray || ! command -v xray >/dev/null 2>&1; then
        reality_abort "Xray更新失败！"
        return 1
    fi
    get_config_info
    config_xray
    if ! xray run -test -c "$xray_config" >/dev/null 2>&1; then
        xray run -test -c "$xray_config"
        reality_abort "Xray配置校验失败！"
        return 1
    fi
    systemctl restart xray
    if ! check_xray_listening; then
        yellow "请查看日志：journalctl -u xray -n 30 --no-pager"
        reality_abort "Xray没有在端口${reality_port}上正常监听！"
        return 1
    fi
    green "-------------------更新完成-------------------"
    cd /
    rm -rf "$temp_dir"
    in_install_update_xray_tls_web=0
    return 0
}
#主菜单函数
full_install_php()
{
    green "开始安装/更新php。。。"
    sleep 3s
    install_php_compile_toolchains
    install_php_dependence
    enter_temp_dir
    compile_php
    remove_php
    install_php_part1
    install_php_part2
    cd /
    rm -rf "$temp_dir"
}
#安装/检查更新/更新php
install_check_update_update_php()
{
    [ "$dnf" == "yum" ] && check_important_dependence_installed "" "yum-utils"
    check_SELinux
    check_important_dependence_installed tzdata tzdata
    get_system_info
    if (([ $release == "centos" ] || [ $release == centos-stream ] || [ $release == oracle ]) && ! version_ge "$systemVersion" "8" ) || ([ $release == "rhel" ] && ! version_ge "$systemVersion" "8") || ([ $release == "fedora" ] && ! version_ge "$systemVersion" "30") || ([ $release == "ubuntu" ] && ! version_ge "$systemVersion" "20.04") || ([ $release == "debian" ] && ! version_ge "$systemVersion" "11"); then
        red "系统版本过低，无法安装php！"
        echo
        tyblue "安装Nextcloud需要安装php"
        yellow "仅支持在以下版本系统下安装php："
        yellow " 1. Ubuntu 20.04+"
        yellow " 2. Debian 11+"
        yellow " 3. 其他以 Debian 11+ 为基的系统"
        yellow " 4. Red Hat Enterprise Linux 8+"
        yellow " 5. CentOS 8+"
        yellow " 6. Fedora 30+"
        yellow " 7. Oracle Linux 8+"
        yellow " 8. 其他以 Red Hat 8+ 为基的系统"
        return 1
    elif [ $release == "other-debian" ] || [ $release == "other-redhat" ]; then
        yellow "未知的系统，可能导致php安装失败！"
        echo
        tyblue "安装Nextcloud需要安装php"
        yellow "仅支持在以下版本系统下安装php："
        yellow " 1. Ubuntu 20.04+"
        yellow " 2. Debian 11+"
        yellow " 3. 其他以 Debian 11+ 为基的系统"
        yellow " 4. Red Hat Enterprise Linux 8+"
        yellow " 5. CentOS 8+"
        yellow " 6. Fedora 30+"
        yellow " 7. Oracle Linux 8+"
        yellow " 8. 其他以 Red Hat 8+ 为基的系统"
        ! ask_if "确定选择吗？(y/n)" && return 0
    elif [ $release == "deepin" ]; then
        red "php暂不支持deepin，请选择其他系统"
        return 1
    fi
    check_important_dependence_installed ca-certificates ca-certificates
    check_important_dependence_installed wget wget
    check_important_dependence_installed "procps" "procps-ng"
    install_epel
    local php_status=0
    if [ $php_is_installed -eq 1 ]; then
        ask_update_script_force
        if check_php_update; then
            green "php有新版本"
            ! ask_if "是否更新？(y/n)" && return 0
        else
            green "php已是最新版本"
            return 0
        fi
        systemctl -q is-active php-fpm && php_status=1
    else
        ask_update_script
        tyblue "安装php用于运行nextcloud网盘"
        yellow "编译&&安装php可能需要消耗15-60分钟"
        yellow "且php将占用一定系统资源，不建议内存<512M的机器使用"
        ! ask_if "是否继续？(y/n)" && return 0
    fi
    check_ssh_timeout
    get_config_info
    full_install_php
    turn_on_off_php
    if [ $php_status -eq 1 ]; then
        systemctl start php-fpm
    else
        systemctl stop php-fpm
    fi
    green "安装/更新完成！"
}
check_update_update_nginx()
{
    check_nginx_installed_system
    [ "$dnf" == "yum" ] && check_important_dependence_installed "" "yum-utils"
    check_SELinux
    check_important_dependence_installed tzdata tzdata
    get_system_info
    check_important_dependence_installed ca-certificates ca-certificates
    check_important_dependence_installed wget wget
    check_important_dependence_installed "procps" "procps-ng"
    install_epel
    ask_update_script_force
    if check_nginx_update; then
        green "Nginx有新版本"
        ! ask_if "是否更新？(y/n)" && return 0
    else
        green "Nginx已是最新版本"
        return 0
    fi
    check_ssh_timeout
    get_config_info
    local nginx_status=0
    local xray_status=0
    systemctl -q is-active nginx && nginx_status=1
    systemctl -q is-active xray && xray_status=1
    install_nginx_compile_toolchains
    install_nginx_dependence
    enter_temp_dir
    compile_nginx
    backup_domains_web
    remove_nginx
    install_nginx_part1
    install_nginx_part2
    config_nginx
    mv "${temp_dir}/domain_backup/"* ${nginx_prefix}/html 2>/dev/null
    get_all_certs
    if [ $nginx_status -eq 1 ]; then
        systemctl restart nginx
    else
        systemctl stop nginx
    fi
    if [ $xray_status -eq 1 ]; then
        systemctl restart xray
    else
        systemctl stop xray
    fi
    cd /
    rm -rf "$temp_dir"
    green "更新完成！"
}
restart_xray_tls_web()
{
    get_config_info
    if [ "$reality_direct" == "1" ]; then
        systemctl restart xray
        sleep 1s
        if systemctl -q is-active xray; then
            green "重启/启动成功！！"
        else
            red "Xray启动失败！！"
        fi
        return
    fi
    systemctl restart xray nginx
    systemctl stop php-fpm cloudreve
    turn_on_off_php
    turn_on_off_cloudreve
    sleep 1s
    if ! systemctl -q is-active xray; then
        red "Xray启动失败！！"
    elif ! systemctl -q is-active nginx; then
        red "Nginx启动失败！！"
    elif check_need_php && ! systemctl -q is-active php-fpm; then
        red "php启动失败！！"
    elif check_need_cloudreve && ! systemctl -q is-active cloudreve; then
        red "Cloudreve启动失败！！"
    else
        green "重启/启动成功！！"
    fi
}
reinit_domain()
{
    [ "$dnf" == "yum" ] && check_important_dependence_installed "" "yum-utils"
    check_important_dependence_installed iproute2 iproute
    get_config_info
    check_port_for_mode
    check_important_dependence_installed tzdata tzdata
    get_system_info
    check_important_dependence_installed ca-certificates ca-certificates
    check_important_dependence_installed wget wget
    install_acme_dependence
    ask_update_script
    yellow "重置域名将删除所有现有域名(包括域名证书、伪装网站等)"
    ! ask_if "是否继续？(y/n)" && return 0
    get_config_info
    local old_true_domain_list=("${true_domain_list[@]}")
    local new_domain_count=1
    if [ "$xhttp_split" == "1" ]; then
        #XHTTP上下行分离：重置后需要重新设置上行域名和下行域名
        new_domain_count=2
        unset domain_list
        unset true_domain_list
        unset domain_config_list
        unset pretend_list
        readXhttpSplitDomains
    else
        readDomain
    fi
    if [ "${pretend_list[-1]}" == "2" ] && [ $php_is_installed -eq 0 ]; then
        check_SELinux
        check_important_dependence_installed "procps" "procps-ng"
        install_epel
        install_web_dependence "${pretend_list[-1]}"
        in_install_update_xray_tls_web=1
        check_ssh_timeout
        in_install_update_xray_tls_web=0
        full_install_php
    else
        [ "${pretend_list[-1]}" == "1" ] && check_SELinux
        install_web_dependence "${pretend_list[-1]}"
    fi
    green "重置域名中。。。"
    local temp_domain_list=("${domain_list[@]: -$new_domain_count}")
    local temp_true_domain_list=("${true_domain_list[@]: -$new_domain_count}")
    local temp_domain_config_list=("${domain_config_list[@]: -$new_domain_count}")
    local temp_pretend_list=("${pretend_list[@]: -$new_domain_count}")
    systemctl stop xray
    systemctl stop nginx
    systemctl stop php-fpm
    systemctl disable php-fpm
    systemctl stop cloudreve
    systemctl disable cloudreve
    local i
    for i in "${old_true_domain_list[@]}"
    do
        rm -rf "${nginx_prefix}/html/${i}"
    done
    rm -rf "${nginx_prefix}/certs"
    mkdir "${nginx_prefix}/certs"
    install_acme_sh
    $HOME/.acme.sh/acme.sh --upgrade --auto-upgrade
    unset domain_list
    unset true_domain_list
    unset domain_config_list
    unset pretend_list
    domain_list=("${temp_domain_list[@]}")
    domain_config_list=("${temp_domain_config_list[@]}")
    true_domain_list=("${temp_true_domain_list[@]}")
    pretend_list=("${temp_pretend_list[@]}")
    get_all_certs
    config_nginx
    config_xray
    sleep 2s
    systemctl restart xray nginx
    init_web 0
    [ "$xhttp_split" == "1" ] && init_web 1
    green "域名重置完成！！"
    print_config_info
}
add_domain()
{
    [ "$dnf" == "yum" ] && check_important_dependence_installed "" "yum-utils"
    check_important_dependence_installed iproute2 iproute
    get_config_info
    check_port_for_mode
    check_important_dependence_installed tzdata tzdata
    get_system_info
    check_important_dependence_installed ca-certificates ca-certificates
    check_important_dependence_installed wget wget
    # ask_update_script
    get_config_info
    local need_cloudreve=0
    check_need_cloudreve && need_cloudreve=1
    readDomain
    local i
    for ((i=${#domain_list[@]}-1; i!=0;))
    do
        ((i--))
        if [ "${domain_list[-1]}" == "${domain_list[$i]}" ] || [ "${domain_list[-1]}" == "${true_domain_list[$i]}" ] || [ "${true_domain_list[-1]}" == "${domain_list[$i]}" ] || [ "${true_domain_list[-1]}" == "${true_domain_list[$i]}" ]; then
            red "域名已存在！"
            return 1
        fi
    done
    if [ "${pretend_list[-1]}" == "1" ] && [ $need_cloudreve -eq 1 ]; then
        yellow "Cloudreve只能用于一个域名！！"
        tyblue "Nextcloud可以用于多个域名"
        return 1
    fi
    if [ "${pretend_list[-1]}" == "2" ] && [ $php_is_installed -eq 0 ]; then
        check_SELinux
        check_important_dependence_installed "procps" "procps-ng"
        install_epel
        install_web_dependence "${pretend_list[-1]}"
        in_install_update_xray_tls_web=1
        check_ssh_timeout
        in_install_update_xray_tls_web=0
        full_install_php
    else
        [ "${pretend_list[-1]}" == "1" ] && check_SELinux
        install_web_dependence "${pretend_list[-1]}"
    fi
    if ! get_cert "-1"; then
        sleep 2s
        systemctl restart xray nginx
        red "申请证书失败！！"
        red "域名添加失败"
        return 1
    fi
    config_nginx
    config_xray
    sleep 2s
    systemctl stop php-fpm cloudreve
    systemctl restart xray nginx
    init_web "-1"
    green "域名添加完成！！"
    print_config_info
}
delete_domain()
{
    get_config_info
    if [ ${#domain_list[@]} -le 1 ]; then
        red "只有一个域名"
        return 1
    fi
    local i
    tyblue "-----------------------请选择要删除的域名-----------------------"
    for i in "${!domain_list[@]}"
    do
        if [ ${domain_config_list[$i]} -eq 1 ]; then
            tyblue " $((i+1)). ${domain_list[$i]} ${true_domain_list[$i]}"
        else
            tyblue " $((i+1)). ${domain_list[$i]}"
        fi
    done
    yellow " 0. 不删除"
    local delete=""
    while ! [[ "$delete" =~ ^([1-9][0-9]*|0)$ ]] || [ $delete -gt ${#domain_list[@]} ]
    do
        read -p "你的选择是：" delete
    done
    [ $delete -eq 0 ] && return 0
    ((delete--))
    if [ "$xhttp_split" == "1" ] && { [ "${true_domain_list[$delete]}" == "$xhttp_up_domain" ] || [ "${true_domain_list[$delete]}" == "$xhttp_down_domain" ]; }; then
        red    "该域名是XHTTP上下行分离使用的上行/下行域名，不能删除！"
        yellow "如需删除，请先通过主菜单\"更换传输协议\"更换为其他传输协议"
        return 1
    fi
    if [ "${pretend_list[$delete]}" == "2" ]; then
        red "警告：此操作可能导致该域名下的Nextcloud网盘数据被删除"
        ! ask_if "是否要继续？(y/n)" && return 0
    fi
    $HOME/.acme.sh/acme.sh --remove --domain ${true_domain_list[$delete]} --ecc
    rm -rf $HOME/.acme.sh/${true_domain_list[$delete]}_ecc
    rm -rf "${nginx_prefix}/certs/${true_domain_list[$delete]}.key" "${nginx_prefix}/certs/${true_domain_list[$delete]}.cer"
    rm -rf ${nginx_prefix}/html/${true_domain_list[$delete]}
    unset 'domain_list[$delete]'
    unset 'true_domain_list[$delete]'
    unset 'domain_config_list[$delete]'
    unset 'pretend_list[$delete]'
    domain_list=("${domain_list[@]}")
    true_domain_list=("${true_domain_list[@]}")
    domain_config_list=("${domain_config_list[@]}")
    pretend_list=("${pretend_list[@]}")
    config_nginx
    config_xray
    systemctl restart xray nginx
    turn_on_off_php
    turn_on_off_cloudreve
    green "域名删除完成！！"
    print_config_info
}
change_pretend()
{
    [ "$dnf" == "yum" ] && check_important_dependence_installed "" "yum-utils"
    check_important_dependence_installed tzdata tzdata
    get_system_info
    check_important_dependence_installed ca-certificates ca-certificates
    check_important_dependence_installed wget wget
    ask_update_script
    get_config_info
    local change=""
    if [ ${#domain_list[@]} -eq 1 ]; then
        change=0
    else
        local i
        tyblue "-----------------------请选择要修改伪装类型的域名-----------------------"
        for i in "${!domain_list[@]}"
        do
            if [ ${domain_config_list[$i]} -eq 1 ]; then
                tyblue " $((i+1)). ${domain_list[$i]} ${true_domain_list[$i]}"
            else
                tyblue " $((i+1)). ${domain_list[$i]}"
            fi
        done
        yellow " 0. 不修改"
        while ! [[ "$change" =~ ^([1-9][0-9]*|0)$ ]] || [ $change -gt ${#domain_list[@]} ]
        do
            read -p "你的选择是：" change
        done
        [ $change -eq 0 ] && return 0
        ((change--))
    fi
    local pretend
    readPretend "${true_domain_list[$change]}"
    if [ "${pretend_list[$change]}" == "$pretend" ]; then
        yellow "伪装类型没有变化"
        return 1
    fi
    if [ "${pretend_list[$change]}" == "2" ]; then
        red "警告：此操作可能导致该域名下的Nextcloud网盘数据被删除"
        ! ask_if "是否要继续？(y/n)" && return 0
    fi
    local need_cloudreve=0
    check_need_cloudreve && need_cloudreve=1
    pretend_list[$change]="$pretend"
    if [ "$pretend" == "1" ] && [ $need_cloudreve -eq 1 ]; then
        yellow "Cloudreve只能用于一个域名！！"
        tyblue "Nextcloud可以用于多个域名"
        return 1
    fi
    if [ "$pretend" == "2" ] && [ $php_is_installed -eq 0 ]; then
        check_SELinux
        check_important_dependence_installed "procps" "procps-ng"
        install_epel
        install_web_dependence "$pretend"
        in_install_update_xray_tls_web=1
        check_ssh_timeout
        in_install_update_xray_tls_web=0
        full_install_php
    else
        [ "$pretend" == "1" ] && check_SELinux
        install_web_dependence "$pretend"
    fi
    config_nginx
    systemctl stop php-fpm cloudreve
    systemctl restart nginx
    init_web "$change"
    green "修改完成！"
}
reinstall_cloudreve()
{
    get_config_info
    ! check_need_cloudreve && red "Cloudreve目前没有绑定域名" && return 1
    red "重新安装Cloudreve将删除所有的网盘文件以及帐户信息，并重置管理员密码"
    ! ask_if "确定要继续吗？(y/n)" && return 0
    [ "$dnf" == "yum" ] && check_important_dependence_installed "" "yum-utils"
    check_SELinux
    check_important_dependence_installed ca-certificates ca-certificates
    check_important_dependence_installed wget wget
    ask_update_script
    install_web_dependence "1"
    enter_temp_dir
    local i
    for i in "${!pretend_list[@]}"
    do
        if [ "${pretend_list[$i]}" == "1" ]; then
            install_init_cloudreve "$i"
            break
        fi
    done
    cd /
    rm -rf "$temp_dir"
    green "重装完成！"
}
#为XHTTP上下行分离新增上行域名和下行域名(只能新增，不能使用已有域名)并申请证书
#成功返回0；失败返回1，此时域名列表恢复为调用前的状态
add_xhttp_split_domains()
{
    [ "$dnf" == "yum" ] && check_important_dependence_installed "" "yum-utils"
    check_important_dependence_installed iproute2 iproute
    check_port_for_mode
    check_important_dependence_installed tzdata tzdata
    get_system_info
    check_important_dependence_installed ca-certificates ca-certificates
    check_important_dependence_installed wget wget
    local old_count=${#domain_list[@]}
    readXhttpSplitDomains
    local up_idx=$old_count
    local down_idx=$((old_count+1))
    restore_domain_lists()
    {
        domain_list=("${domain_list[@]:0:$old_count}")
        true_domain_list=("${true_domain_list[@]:0:$old_count}")
        domain_config_list=("${domain_config_list[@]:0:$old_count}")
        pretend_list=("${pretend_list[@]:0:$old_count}")
    }
    if [ "${pretend_list[$up_idx]}" == "2" ] && [ $php_is_installed -eq 0 ]; then
        check_SELinux
        check_important_dependence_installed "procps" "procps-ng"
        install_epel
        install_web_dependence "${pretend_list[$up_idx]}"
        in_install_update_xray_tls_web=1
        check_ssh_timeout
        in_install_update_xray_tls_web=0
        full_install_php
    else
        install_web_dependence "${pretend_list[$up_idx]}"
    fi
    if ! get_cert "$up_idx"; then
        sleep 2s
        systemctl restart xray nginx
        red "上行域名\"${true_domain_list[$up_idx]}\"证书申请失败！"
        restore_domain_lists
        return 1
    fi
    if ! get_cert "$down_idx"; then
        sleep 2s
        systemctl restart xray nginx
        red "下行域名\"${true_domain_list[$down_idx]}\"证书申请失败！"
        #清理已申请成功的上行域名证书
        $HOME/.acme.sh/acme.sh --remove --domain ${true_domain_list[$up_idx]} --ecc
        rm -rf $HOME/.acme.sh/${true_domain_list[$up_idx]}_ecc
        rm -rf "${nginx_prefix}/certs/${true_domain_list[$up_idx]}.key" "${nginx_prefix}/certs/${true_domain_list[$up_idx]}.cer"
        restore_domain_lists
        return 1
    fi
    return 0
}
change_xray_protocol()
{
    get_config_info
    if [ "$protocol_1" == "1" ]; then
        red    "当前为REALITY模式，不支持更换传输协议！"
        yellow "如需更换，请使用主菜单中的\"1. 重新安装\"重新选择传输协议"
        return 1
    fi
    local protocol_4_old=$protocol_4
    local xhttp_split_old=$xhttp_split
    readProtocolConfig
    if [ "$protocol_1" == "1" ]; then
        red    "不支持从当前传输协议切换到REALITY！"
        yellow "如需使用REALITY，请使用主菜单中的\"1. 重新安装\"重新选择传输协议"
        return 1
    fi
    local resplit=0
    if [ "${legacy_grpc_ws:-0}" != "0" ] || [ "${legacy_tcp_tls:-0}" == "1" ]; then
        yellow "检测到旧版本遗留的gRPC/WebSocket/TCP(XTLS/TLS)配置，本脚本已不再支持，更换传输协议后它们将被移除"
        ! ask_if "是否继续？(y/n)" && return 0
    elif [ $protocol_4_old -eq $protocol_4 ] && [ $xhttp_split_old -eq $xhttp_split ]; then
        if [ $xhttp_split -eq 1 ]; then
            yellow "当前已是XHTTP上下行分离模式"
            yellow "可以重新设置上行域名和下行域名(需新增两个域名，原来的两个域名会保留为普通域名，可通过\"删除域名\"删除)"
            ! ask_if "是否重新设置上行域名和下行域名？(y/n)" && return 0
            resplit=1
        else
            red "传输协议未更换"
            return 1
        fi
    fi
    if [ $protocol_4 -ne 0 ] && ! check_xray_support_xhttp; then
        red "当前安装的Xray版本过低，不支持XHTTP传输(需要v24.11.21及以上)，请先使用主菜单中的\"更新Xray\"！"
        return 1
    fi
    if [ $protocol_4_old -eq 0 ] && [ $protocol_4 -ne 0 ]; then
        xhttp_path="/$(head -c 20 /dev/urandom | md5sum | head -c 10)"
        xid_4=$(cat /proc/sys/kernel/random/uuid)
    fi
    local new_split_domains=0
    if [ $xhttp_split -eq 1 ] && { [ $xhttp_split_old -eq 0 ] || [ $resplit -eq 1 ]; }; then
        if ! add_xhttp_split_domains; then
            red "域名添加失败，传输协议未更换"
            return 1
        fi
        new_split_domains=1
    fi
    config_xray
    config_nginx
    if [ $new_split_domains -eq 1 ]; then
        sleep 2s
        systemctl stop php-fpm cloudreve
        systemctl restart xray nginx
        init_web "$((${#domain_list[@]}-2))"
        init_web "$((${#domain_list[@]}-1))"
    else
        systemctl -q is-active xray && systemctl restart xray
        systemctl -q is-active nginx && systemctl restart nginx
    fi
    green "更换成功！！"
    print_config_info
}
change_xray_id()
{
    get_config_info
    local flag=""
    tyblue "-------------请输入你要修改的id-------------"
    tyblue " 1. REALITY的id"
    tyblue " 2. XHTTP的id"
    echo
    while [[ ! "$flag" =~ ^[12]$ ]]
    do
        read -p "您的选择是：" flag
    done
    if [ $flag -eq 1 ] && [ $protocol_1 -eq 0 ]; then
        red "没有使用该协议！"
        return 1
    elif [ $flag -eq 2 ] && [ $protocol_4 -eq 0 ]; then
        red "没有使用该协议！"
        return 1
    fi
    local xid
    [ $flag -eq 1 ] && xid="$xid_1" || xid="$xid_4"
    tyblue "您现在的id是：$xid"
    ! ask_if "是否要继续?(y/n)" && return 0
    while true
    do
        xid=""
        while [ -z "$xid" ]
        do
            tyblue "-------------请输入新的id-------------"
            read xid
        done
        tyblue "您输入的id是：$xid"
        ask_if "是否确定?(y/n)" && break
    done
    if [ $flag -eq 1 ]; then
        xid_1="$xid"
    else
        xid_4="$xid"
    fi
    config_xray
    systemctl -q is-active xray && systemctl restart xray
    green "更换成功！！"
    print_config_info
}
change_xray_xhttp_path()
{
    get_config_info
    if [ $protocol_4 -eq 0 ]; then
        red "没有使用XHTTP协议！"
        return 1
    fi
    tyblue "您现在的XHTTP path是：$xhttp_path"
    ! ask_if "是否要继续?(y/n)" && return 0
    while true
    do
        xhttp_path=""
        while [ -z "$xhttp_path" ]
        do
            tyblue "---------------请输入新的path(/+字母数字组合)---------------"
            read xhttp_path
        done
        if [[ ! "$xhttp_path" =~ ^/[A-Za-z0-9_.~-]+$ ]]; then
            red "path必须以/开头，且只能包含字母、数字及_.~-，并且不能以/结尾"
            continue
        fi
        tyblue "您输入的path是：$xhttp_path"
        ask_if "是否确定?(y/n)" && break
    done
    config_xray
    config_nginx
    systemctl -q is-active xray && systemctl restart xray
    systemctl -q is-active nginx && systemctl restart nginx
    green "更换成功！！"
    print_config_info
}
simplify_system()
{
    if systemctl -q is-active xray || systemctl -q is-active nginx || systemctl -q is-active php-fpm; then
        yellow "请先停止Xray-TLS+Web"
        return 1
    fi
    [ "$dnf" == "yum" ] && check_important_dependence_installed "" "yum-utils"
    check_important_dependence_installed tzdata tzdata
    get_system_info
    check_important_dependence_installed "procps" "procps-ng"
    yellow "警告："
    tyblue " 1. 此功不能保证在所有系统运行成功 (特别是某些VPS定制系统)，如果运行失败，可能导致VPS无法开机"
    tyblue " 2. 如果VPS上部署了 Xray-TLS+Web 以外的东西，可能被误删"
    ! ask_if "是否要继续?(y/n)" && return 0
    echo
    local save_ssh=0
    yellow "提示：精简系统可能导致ssh配置文件(/etc/ssh/sshd_config)恢复默认"
    tyblue "这可能导致ssh端口恢复默认(22)，且有些系统默认仅允许密钥登录(不允许密码登录)"
    tyblue "你可以自己备份ssh文件或使用脚本自动备份"
    ask_if "是否备份ssh配置文件?(y/n)" && save_ssh=1
    if [ $save_ssh -eq 1 ]; then
        enter_temp_dir
        cp /etc/ssh/sshd_config sshd_config
    fi
    uninstall_firewall
    if [ $release == "centos" ] || [ $release == centos-stream ] || [ $release == oracle ] || [ $release == "rhel" ] || [ $release == "fedora" ] || [ $release == "other-redhat" ]; then
        local temp_backup=()
        local temp_important=('openssh-server' 'initscripts' 'tar')
        for i in "${temp_important[@]}"
        do
            rpm -q "$i" > /dev/null 2>&1 && temp_backup+=("$i")
        done
        local temp_remove_list=('openssl' 'perl*' 'xz' 'libselinux-utils' 'zip' 'unzip' 'bzip2' 'wget' 'procps-ng' 'procps' 'iproute' 'dbus-glib' 'udisk*' 'libudisk*' 'gdisk*' 'libblock*' '*-devel' 'nginx*')
        #libxmlb
        if ! $dnf -y remove "${temp_remove_list[@]}"; then
            for i in "${temp_remove_list[@]}"
            do
                $dnf -y remove "$i"
            done
        fi
        for i in "${temp_backup[@]}"
        do
            check_important_dependence_installed "" "$i"
        done
    else
        local debian_remove_packages=('^cron$' '^anacron$' '^cups' '^foomatic' '^openssl$' '^snapd$' '^kdump-tools$' '^flex$' '^make$' '^automake$' '^cloud-init' '^pkg-config$' '^gcc-[1-9][0-9]*$' '^cpp-[1-9][0-9]*$' '^curl$' '^python' '^libpython' '^dbus$' '^at$' '^open-iscsi$' '^rsyslog$' '^acpid$' '^libnetplan0$' '^glib-networking-common$' '^bcache-tools$' '^bind([0-9]|-|$)' '^lshw$' '^thermald' '^libdbus' '^libevdev' '^libupower' '^readline-common$' '^libreadline' '^xz-utils$' '^selinux-utils$' '^wget$' '^zip$' '^unzip$' '^bzip2$' '^finalrd$' '^cryptsetup' '^libplymouth' '^lib.*-dev$' '^perl$' '^perl-modules' '^x11' '^libx11' '^qemu' '^xdg-' '^libglib' '^libicu' '^libxml' '^liburing' '^libisc' '^libdns' '^isc-' '^net-tools$' '^xxd$' '^xkb-data$' '^lsof$' '^task' '^usb' '^libusb' '^doc' '^libwrap' '^libtext' '^libmagic' '^libpci' '^liblocale' '^keyboard' '^libuni[^s]' '^libpipe' '^man-db$' '^manpages' '^liblock' '^liblog' '^libxapian' '^libpsl' '^libpap' '^libgs[0-9]' '^libpaper' '^postfix' '^nginx' '^libnginx' '^libpop' '^libslang' '^apt-utils$' '^google')
        local debian_keep_packages=('apt-utils' 'whiptail' 'initramfs-tools' 'isc-dhcp-client' 'netplan.io' 'openssh-server' 'network-manager' 'ifupdown' 'ifupdown-ng' 'ca-certificates')
        local remove_packages=()
        local keep_packages=()
        for i in "${debian_keep_packages[@]}"
        do
            LANG="en_US.UTF-8" LANGUAGE="en_US:en" dpkg -s "$i" 2>/dev/null | grep -qi 'status[ '$'\t]*:[ '$'\t]*install[ '$'\t]*ok[ '$'\t]*installed[ '$'\t]*$' && keep_packages+=("$i")
        done
        keep_packages+=($(dpkg --list 'grub*' | grep '^[ '$'\t]*ii[ '$'\t]' | awk '{print $2}'))
        dpkg -l | grep '^[ '$'\t]*ii[ '$'\t]' | awk '{print $2}' | cut -d : -f 1 > temp
        for package in "${debian_remove_packages[@]}"
        do
            if grep -q "$package" temp; then
                tyblue "将删除软件包：$package"
                remove_packages+=("$package")
            fi
        done
        cp /etc/apt/sources.list sources.list.bak
        sed -i 's#https://#http://#g' /etc/apt/sources.list
        #'^libp11' '^libtasn' '^libkey' '^libnet'
        if ! apt_auto_remove_purge "${remove_packages[@]}"; then
            $apt update
            $apt -y -f --no-install-recommends install
            if ! apt_auto_remove_purge "${remove_packages[@]}"; then
                red    "精简系统时有错误发生（某些软件包卸载失败）"
                echo
                tyblue "如果您是小白，建议选择n终止卸载，如果后续仍有出现错误，请重装系统"
                echo
                tyblue "否则，可以按照以下步骤尝试修复："
                tyblue " 1. 阅读错误信息，找到导致卸载错误的软件包；手动运行这条命令可能可以帮助寻找错误包： $apt -f --no-install-recommends install (在终端中运行，参考2)"
                tyblue " 2. 按ctrl+z将脚本挂在后台，也可尝试新建一个终端(不一定能新建成功)"
                tyblue " 3. 如果能看出导致卸载错误的原因并解决是最好；如果不能，运行 '$apt update && $apt --no-install-recommends install 软件包名' 手动升级该软件包"
                tyblue " 4. 运行fg命令返回脚本(对应ctrl+z命令)"
                tyblue " 5. 在完成上述步骤后，选择y继续卸载"
                echo
                if ask_if "继续卸载?(y/n)"; then
                    if ! apt_auto_remove_purge "${remove_packages[@]}"; then
                        red "卸载失败！"
                        tyblue "按回车键继续，如果后续仍有出现错误，请重装系统"
                        read -s
                    fi
                fi
            fi
        fi
        for i in "${keep_packages[@]}"
        do
            check_important_dependence_installed "$i" ""
        done
        mv sources.list.bak /etc/apt/sources.list
    fi
    ([ $nginx_is_installed -eq 1 ] || [ $php_is_installed -eq 1 ] || [ $is_installed -eq 1 ]) && install_epel
    [ $nginx_is_installed -eq 1 ] && install_nginx_dependence
    [ $php_is_installed -eq 1 ] && install_php_dependence
    [ $is_installed -eq 1 ] && install_acme_dependence
    if [ $save_ssh -eq 1 ]; then
        cp sshd_config /etc/ssh/sshd_config
        cd /
        rm -rf "$temp_dir"
        systemctl restart $ssh_service
    fi
    green "精简完成"
}
repair_tuige()
{
    yellow "尝试修复退格键异常问题，退格键正常请不要修复"
    ! ask_if "是否要继续?(y/n)" && return 0
    if stty -a | grep -q 'erase = ^?'; then
        stty erase '^H'
    elif stty -a | grep -q 'erase = ^H'; then
        stty erase '^?'
    fi
    green "修复完成！！"
}
change_dns()
{
    red    "注意！！"
    red    "1.部分云服务商(如阿里云)使用本地服务器作为软件包源，修改dns后需要换源！！"
    red    "  如果不明白，那么请在安装完成后再修改dns，并且修改完后不要重新安装"
    red    "2.Ubuntu系统重启后可能会恢复原dns"
    tyblue "此操作将修改dns服务器为1.1.1.1和1.0.0.1(cloudflare公共dns)"
    ! ask_if "是否要继续?(y/n)" && return 0
    if ! grep -q "#This file has been edited by Xray-TLS-Web-setup-script" /etc/resolv.conf; then
        sed -i 's/^[ \t]*nameserver[ \t][ \t]*/#&/' /etc/resolv.conf
        {
            echo
            echo 'nameserver 1.1.1.1'
            echo 'nameserver 1.0.0.1'
            echo '#This file has been edited by Xray-TLS-Web-setup-script'
        } >> /etc/resolv.conf
    fi
    green "修改完成！！"
}
#开始菜单
start_menu()
{
    local xray_status
    [ $xray_is_installed -eq 1 ] && xray_status="\\033[32m已安装" || xray_status="\\033[31m未安装"
    systemctl -q is-active xray && xray_status+="                \\033[32m运行中" || xray_status+="                \\033[31m未运行"
    local nginx_status
    [ $nginx_is_installed -eq 1 ] && nginx_status="\\033[32m已安装" || nginx_status="\\033[31m未安装"
    systemctl -q is-active nginx && nginx_status+="                \\033[32m运行中" || nginx_status+="                \\033[31m未运行"
    [ "$reality_direct" == "1" ] && nginx_status="\\033[36m无需(REALITY直连模式)"
    local php_status
    [ $php_is_installed -eq 1 ] && php_status="\\033[32m已安装" || php_status="\\033[31m未安装"
    systemctl -q is-active php-fpm && php_status+="                \\033[32m运行中" || php_status+="                \\033[31m未运行"
    local cloudreve_status
    [ $cloudreve_is_installed -eq 1 ] && cloudreve_status="\\033[32m已安装" || cloudreve_status="\\033[31m未安装"
    systemctl -q is-active cloudreve && cloudreve_status+="                \\033[32m运行中" || cloudreve_status+="                \\033[31m未运行"
    tyblue "------------------------ Xray-TLS+Web 搭建/管理脚本 ------------------------"
    echo
    tyblue "           Xray   ：           ${xray_status}"
    echo
    tyblue "           Nginx  ：           ${nginx_status}"
    echo
    tyblue "           php    ：           ${php_status}"
    echo
    tyblue "        Cloudreve ：           ${cloudreve_status}"
    echo
    tyblue "       官网：https://github.com/CatherineReyes-byte/Xray-script"
    echo
    tyblue "----------------------------------注意事项----------------------------------"
    yellow " 1. 此脚本需要一个解析到本服务器的域名(REALITY使用他人的域名时不需要)"
    tyblue " 2. 此脚本安装时间较长，建议在安装前阅读："
    tyblue "      https://github.com/CatherineReyes-byte/Xray-script#安装时长说明"
    green  " 3. 建议在纯净的系统上使用此脚本 (VPS控制台-重置系统)"
    tyblue "----------------------------------------------------------------------------"
    echo
    echo
    tyblue " -----------安装/更新/卸载-----------"
    if [ $is_installed -eq 0 ]; then
        green  "   1. 安装Xray-TLS+Web"
    else
        green  "   1. 重新安装Xray-TLS+Web"
    fi
    purple "         流程：[更新系统组件]->[安装bbr]->[安装php]->安装Nginx->安装Xray->申请证书->配置文件->[安装/配置Cloudreve]"
    green  "   2. 更新Xray-TLS+Web"
    purple "         流程：更新脚本->[更新系统组件]->[更新bbr]->[更新php]->[更新Nginx]->更新Xray->更新证书->更新配置文件->[更新Cloudreve]"
    tyblue "   3. 检查更新/更新脚本"
    tyblue "   4. 更新系统组件"
    tyblue "   5. 启用原生BBR"
    purple "         仅启用Linux内核原生BBR+fq(不安装第三方内核)"
    tyblue "   6. 安装/检查更新/更新php"
    tyblue "   7. 检查更新/更新Nginx"
    tyblue "   8. 更新Cloudreve"
    tyblue "   9. 更新Xray"
    red    "  10. 卸载Xray-TLS+Web"
    red    "  11. 卸载php"
    red    "  12. 卸载Cloudreve"
    echo
    tyblue " --------------启动/停止-------------"
    tyblue "  13. 启动/重启Xray-TLS+Web"
    tyblue "  14. 停止Xray-TLS+Web"
    echo
    tyblue " ----------------管理----------------"
    tyblue "  15. 查看配置信息"
    tyblue "  16. 重置域名"
    purple "         将删除所有域名配置，安装过程中域名输错了造成Xray无法启动可以用此选项修复"
    tyblue "  17. 添加域名"
    tyblue "  18. 删除域名"
    tyblue "  19. 修改伪装网站类型"
    tyblue "  20. 重新安装Cloudreve"
    purple "         将删除所有Cloudreve网盘的文件和帐户信息，管理员密码忘记可用此选项恢复"
    tyblue "  21. 修改传输协议"
    tyblue "  22. 修改id(用户ID/UUID)"
    tyblue "  23. 修改XHTTP的path(路径)"
    echo
    tyblue " ----------------其它----------------"
    tyblue "  24. 精简系统"
    purple "         删除不必要的系统组件，即使已经安装 Xray-TLS+Web 仍然可以使用此功能"
    tyblue "  25. 尝试修复退格键无法使用的问题"
    purple "         部分ssh工具(如Xshell)可能有这类问题"
    tyblue "  26. 修改dns"
    yellow "  0. 退出脚本"
    echo
    echo
    local choice=""
    while [[ ! "$choice" =~ ^(0|[1-9][0-9]*)$ ]] || ((choice>26))
    do
        read -p "您的选择是：" choice
    done
    if (( choice==2 || (7<=choice&&choice<=9) || choice==13 || (15<=choice&&choice<=23) )) && [ $is_installed -eq 0 ]; then
        red "请先安装Xray-TLS+Web！！"
        return 1
    fi
    if [ "$reality_direct" == "1" ] && (( choice==6 || choice==7 || choice==8 || choice==11 || choice==12 || (16<=choice&&choice<=21) || choice==23 )); then
        red    "当前为REALITY(他人的域名)直连模式，没有Nginx/域名/伪装网站，此选项不可用！"
        yellow "如需更换传输协议或域名模式，请使用\"1. 重新安装\""
        return 1
    fi
    if (( 17<=choice&&choice<=20 )) && ! (systemctl -q is-active nginx && systemctl -q is-active xray); then
        red "请先启动Xray-TLS+Web！！"
        return 1
    fi
    if [ $choice -eq 1 ]; then
        install_update_xray_tls_web
    elif [ $choice -eq 2 ]; then
        [ "$dnf" == "yum" ] && check_important_dependence_installed "" "yum-utils"
        check_important_dependence_installed ca-certificates ca-certificates
        check_important_dependence_installed wget wget
        ask_update_script_force
        bash "${BASH_SOURCE[0]}" --update
    elif [ $choice -eq 3 ]; then
        [ "$dnf" == "yum" ] && check_important_dependence_installed "" "yum-utils"
        check_important_dependence_installed ca-certificates ca-certificates
        check_important_dependence_installed wget wget
        ask_update_script
    elif [ $choice -eq 4 ]; then
        [ "$dnf" == "yum" ] && check_important_dependence_installed "" "yum-utils"
        check_important_dependence_installed tzdata tzdata
        get_system_info
        check_ssh_timeout
        check_important_dependence_installed "procps" "procps-ng"
        doupdate
        green "更新完成！"
    elif [ $choice -eq 5 ]; then
        [ "$dnf" == "yum" ] && check_important_dependence_installed "" "yum-utils"
        check_important_dependence_installed ca-certificates ca-certificates
        check_important_dependence_installed wget wget
        check_important_dependence_installed "procps" "procps-ng"
        enter_temp_dir
        install_bbr
        $apt_no_install_recommends -y -f install
        rm -rf "$temp_dir"
    elif [ $choice -eq 6 ]; then
        install_check_update_update_php
    elif [ $choice -eq 7 ]; then
        check_update_update_nginx
    elif [ $choice -eq 8 ]; then
        if [ $cloudreve_is_installed -eq 0 ]; then
            red    "请先安装Cloudreve！"
            tyblue "在 修改伪装网站类型/重置域名/添加域名 里选择Cloudreve"
            return 1
        fi
        [ "$dnf" == "yum" ] && check_important_dependence_installed "" "yum-utils"
        check_SELinux
        install_web_dependence "1"
        ask_update_script_force
        enter_temp_dir
        update_cloudreve
        cd /
        rm -rf "$temp_dir"
        green "Cloudreve更新完成！"
    elif [ $choice -eq 9 ]; then
        [ "$dnf" == "yum" ] && check_important_dependence_installed "" "yum-utils"
        check_SELinux
        check_important_dependence_installed ca-certificates ca-certificates
        check_important_dependence_installed curl curl
        install_update_xray
        green "Xray更新完成！"
    elif [ $choice -eq 10 ]; then
        ! ask_if "确定要删除吗?(y/n)" && return 0
        [ "$dnf" == "yum" ] && check_important_dependence_installed "" "yum-utils"
        check_important_dependence_installed ca-certificates ca-certificates
        check_important_dependence_installed curl curl
        remove_xray
        remove_nginx
        remove_php
        remove_cloudreve
        $HOME/.acme.sh/acme.sh --uninstall
        rm -rf $HOME/.acme.sh
        green "删除完成！"
    elif [ $choice -eq 11 ]; then
        get_config_info
        [ $is_installed -eq 1 ] && check_need_php && red "有域名正在使用php" && return 1
        ! ask_if "确定要删除php吗?(y/n)" && return 0
        remove_php && green "删除完成！"
    elif [ $choice -eq 12 ]; then
        get_config_info
        [ $is_installed -eq 1 ] && check_need_cloudreve && red "有域名正在使用Cloudreve" && return 1
        ! ask_if "确定要删除cloudreve吗?(y/n)" && return 0
        remove_cloudreve && green "删除完成！"
    elif [ $choice -eq 13 ]; then
        restart_xray_tls_web
    elif [ $choice -eq 14 ]; then
        [ "$reality_direct" == "1" ] && systemctl stop xray || systemctl stop xray nginx
        [ $php_is_installed -eq 1 ] && systemctl stop php-fpm
        [ $cloudreve_is_installed -eq 1 ] && systemctl stop cloudreve
        green "已停止！"
    elif [ $choice -eq 15 ]; then
        get_config_info
        print_config_info
    elif [ $choice -eq 16 ]; then
        reinit_domain
    elif [ $choice -eq 17 ]; then
        add_domain
    elif [ $choice -eq 18 ]; then
        delete_domain
    elif [ $choice -eq 19 ]; then
        change_pretend
    elif [ $choice -eq 20 ]; then
        reinstall_cloudreve
    elif [ $choice -eq 21 ]; then
        change_xray_protocol
    elif [ $choice -eq 22 ]; then
        change_xray_id
    elif [ $choice -eq 23 ]; then
        change_xray_xhttp_path
    elif [ $choice -eq 24 ]; then
        simplify_system
    elif [ $choice -eq 25 ]; then
        repair_tuige
    elif [ $choice -eq 26 ]; then
        change_dns
    fi
}

if [ "$1" == "--update" ]; then
    update=1
    install_update_xray_tls_web
else
    update=0
    start_menu
fi

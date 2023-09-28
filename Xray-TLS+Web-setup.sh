#!/bin/bash

#系统信息
#指令集
machine=""
#什么系统
release=""
#系统版本号
systemVersion=""
debian_package_manager=""
redhat_package_manager=""
redhat_package_manager_enhanced=""
#CPU线程数
cpu_thread_num=""
#现在有没有通过脚本启动swap
using_swap_now=0 

#系统时区
timezone=""

#安装信息
nginx_version="nginx-1.22.0"
openssl_version="openssl-openssl-3.0.3"
nginx_prefix="/usr/local/nginx"
nginx_config="${nginx_prefix}/conf.d/xray.conf"
nginx_service="/etc/systemd/system/nginx.service"
nginx_is_installed=""

php_version="php-8.1.6"
php_prefix="/usr/local/php"
php_service="/etc/systemd/system/php-fpm.service"
php_is_installed=""

cloudreve_version="3.5.3"
cloudreve_prefix="/usr/local/cloudreve"
cloudreve_service="/etc/systemd/system/cloudreve.service"
cloudreve_is_installed=""

nextcloud_url="https://download.nextcloud.com/server/releases/nextcloud-24.0.0.zip"

xray_config="/usr/local/etc/xray/config.json"
xray_is_installed=""

temp_dir="/temp_install_update_xray_tls_web"

is_installed=""

update=""
in_install_update_xray_tls_web=0

#配置信息
#域名列表 两个列表用来区别 www.主域名
unset domain_list
unset true_domain_list
unset domain_config_list
#域名伪装列表，对应域名列表
unset pretend_list

# TCP使用的会话层协议，0代表禁用，1代表VLESS
protocol_1=""
# grpc使用的会话层协议，0代表禁用，1代表VLESS，2代表VMess
protocol_2=""
# WebSocket使用的会话层协议，0代表禁用，1代表VLESS，2代表VMess
protocol_3=""

serviceName=""
path=""

xid_1=""
xid_2=""
xid_3=""

#功能性函数：
#定义几个颜色
	@@ -101,7 +125,7 @@ check_base_command()
{
    hash -r
    local i
    local temp_command_list=('bash' 'sh' 'command' 'type' 'hash' 'install' 'true' 'false' 'exit' 'echo' 'test' 'sort' 'sed' 'awk' 'grep' 'cut' 'cd' 'rm' 'cp' 'mv' 'head' 'tail' 'uname' 'tr' 'md5sum' 'cat' 'find' 'wc' 'ls' 'mktemp' 'swapon' 'swapoff' 'mkswap' 'chmod' 'chown' 'chgrp' 'export' 'tar' 'gzip' 'mkdir' 'arch' 'uniq')
    for i in "${temp_command_list[@]}"
    do
        if ! command -V "${i}" > /dev/null; then
	@@ -174,17 +198,17 @@ ask_update_script_force()
}
redhat_install()
{
    if $redhat_package_manager_enhanced install "$@"; then
        return 0
    fi


    if $redhat_package_manager --help | grep -q "\\-\\-enablerepo="; then
        local enable_repo="--enablerepo="
    else
        local enable_repo="--enablerepo "
    fi
    if $redhat_package_manager --help | grep -q "\\-\\-disablerepo="; then
        local disable_repo="--disablerepo="
    else
        local disable_repo="--disablerepo "
	@@ -207,21 +231,21 @@ redhat_install()


    if [ $release == fedora ]; then
        if $redhat_package_manager_enhanced ${enable_repo}"remi" install "$@"; then
            return 0
        fi
    else
        if $redhat_package_manager_enhanced ${enable_repo}"${epel_repo}" install "$@"; then
            return 0
        fi
        if $redhat_package_manager_enhanced ${enable_repo}"${epel_repo},powertools" install "$@" || $redhat_package_manager_enhanced ${enable_repo}"${epel_repo},PowerTools" install "$@"; then
            return 0
        fi
    fi
    if $redhat_package_manager_enhanced ${enable_repo}"*" ${disable_repo}"*-debug,*-debuginfo,*-source" install "$@"; then
        return 0
    fi
    if $redhat_package_manager_enhanced ${enable_repo}"*" install "$@"; then
        return 0
    fi
    return 1
	@@ -240,16 +264,21 @@ test_important_dependence_installed()
                yellow "按回车键继续或者Ctrl+c退出"
                read -s
            fi
        elif $debian_package_manager -y --no-install-recommends install "$1"; then
            temp_exit_code=0
        else
            $debian_package_manager update
            $debian_package_manager -y -f install
            $debian_package_manager -y --no-install-recommends install "$1" && temp_exit_code=0
        fi
    else
        if rpm -q "$2" > /dev/null 2>&1; then
            if [ "$redhat_package_manager" == "dnf" ]; then
                dnf mark install "$2" && temp_exit_code=0
            else
                yumdb set reason user "$2" && temp_exit_code=0
	@@ -276,10 +305,10 @@ check_important_dependence_installed()
install_dependence()
{
    if [ $release == "ubuntu" ] || [ $release == "debian" ] || [ $release == "deepin" ] || [ $release == "other-debian" ]; then
        if ! $debian_package_manager -y --no-install-recommends install "$@"; then
            $debian_package_manager update
            $debian_package_manager -y -f install
            if ! $debian_package_manager -y --no-install-recommends install "$@"; then
                yellow "依赖安装失败！！"
                green  "欢迎进行Bug report(https://github.com/CatherineReyes-byte/Xray-script/issues)，感谢您的支持"
                yellow "按回车键继续或者Ctrl+c退出"
	@@ -295,6 +324,27 @@ install_dependence()
        fi
    fi
}
#安装epel源
install_epel()
{
	@@ -356,7 +406,13 @@ install_epel()
            ret=-1
        fi
    else
        if [ $redhat_package_manager == dnf ]; then
            check_important_dependence_installed "" dnf-plugins-core
            dnf config-manager --set-enabled powertools || dnf config-manager --set-enabled PowerTools
        fi
	@@ -365,7 +421,7 @@ install_epel()

    if [ $ret -ne 0 ]; then
        if [ $release == other-redhat ]; then
            if $redhat_package_manager repolist epel | grep -q epel; then
                return
            fi
            yellow "epel源安装失败，这可能导致之后的安装失败，也可能没有影响(取决于你的系统的repo包含软件是否丰富)"
	@@ -627,7 +683,13 @@ get_config_info()
    [ $protocol_2 -ne 0 ] && ((temp++))
    [ $protocol_3 -ne 0 ] && ((temp++))
    if [ $(grep -c '"clients"' $xray_config) -eq $temp ]; then
        protocol_1=1
        xid_1="$(grep '"id"' $xray_config | head -n 1 | cut -d : -f 2 | cut -d \" -f 2)"
    else
        protocol_1=0
	@@ -755,43 +817,46 @@ if [[ ! -d /dev/shm ]]; then
    red "/dev/shm不存在，不支持的系统"
    exit 1
fi
if [[ "$(type -P apt)" ]]; then
    if [[ "$(type -P dnf)" ]] || [[ "$(type -P yum)" ]]; then
        red "同时存在apt和yum/dnf"
        red "不支持的系统！"
        exit 1
    fi
    release="other-debian"
    debian_package_manager="apt"
    redhat_package_manager="true"
    redhat_package_manager_enhanced="true"
elif [[ "$(type -P dnf)" ]]; then
    release="other-redhat"
    redhat_package_manager="dnf"
    debian_package_manager="true"
    if $redhat_package_manager --help | grep -q "\\-\\-setopt="; then
        redhat_package_manager_enhanced="$redhat_package_manager -y --setopt=install_weak_deps=False"
    else
        redhat_package_manager_enhanced="$redhat_package_manager -y --setopt install_weak_deps=False"
    fi
elif [[ "$(type -P yum)" ]]; then
    release="other-redhat"
    redhat_package_manager="yum"
    debian_package_manager="true"
    if $redhat_package_manager --help | grep -q "\\-\\-setopt="; then
        redhat_package_manager_enhanced="$redhat_package_manager -y --setopt=install_weak_deps=False"
    else
        redhat_package_manager_enhanced="$redhat_package_manager -y --setopt install_weak_deps=False"
    fi
else
    red "apt yum dnf命令均不存在"
    red "不支持的系统"
    exit 1
fi
if [[ -z "${BASH_SOURCE[0]}" ]]; then
    red "请以文件的形式运行脚本，或不支持的bash版本"
    exit 1
fi
if [ "$EUID" != "0" ]; then
    red "请用root用户运行此脚本！！"
    exit 1
	@@ -802,6 +867,11 @@ if ! check_sudo; then
    tyblue "详情请见：https://github.com/acmesh-official/acme.sh/wiki/sudo"
    exit 1
fi
[ -e $nginx_config ] && nginx_is_installed=1 || nginx_is_installed=0
[ -e ${php_prefix}/php-fpm.service.default ] && php_is_installed=1 || php_is_installed=0
[ -e ${cloudreve_prefix}/cloudreve.db ] && cloudreve_is_installed=1 || cloudreve_is_installed=0
	@@ -816,8 +886,14 @@ case "$(uname -m)" in
    'amd64' | 'x86_64')
        machine='amd64'
        ;;
    'armv5tel' | 'armv6l' | 'armv7' | 'armv7l')
        machine='arm'
        ;;
    'armv8' | 'aarch64')
        machine='arm64'
	@@ -901,8 +977,8 @@ check_nginx_installed_system()
    yellow " 建议使用纯净的系统运行此脚本"
    echo
    ! ask_if "是否尝试卸载？(y/n)" && exit 0
    $debian_package_manager -y purge '^nginx' '^libnginx'
    $redhat_package_manager -y remove 'nginx*'
    if [[ ! -f /usr/lib/systemd/system/nginx.service ]] && [[ ! -f /lib/systemd/system/nginx.service ]]; then
        return 0
    fi
	@@ -927,8 +1003,8 @@ check_SELinux()
        sed -i 's/^[ \t]*SELINUX[ \t]*=[ \t]*enforcing[ \t]*$/SELINUX=disabled/g' /etc/sysconfig/selinux
        sed -i 's/^[ \t]*SELINUX[ \t]*=[ \t]*enforcing[ \t]*$/SELINUX=disabled/g' /etc/selinux/config
        if [ $selinux_utils_is_installed -eq 0 ]; then
            $redhat_package_manager -y remove libselinux-utils
            $debian_package_manager -y purge selinux-utils
        fi
    }
    if getenforce 2>/dev/null | grep -wqi Enforcing || grep -Eq '^[ '$'\t]*SELINUX[ '$'\t]*=[ '$'\t]*enforcing[ '$'\t]*$' /etc/sysconfig/selinux 2>/dev/null || grep -Eq '^[ '$'\t]*SELINUX[ '$'\t]*=[ '$'\t]*enforcing[ '$'\t]*$' /etc/selinux/config 2>/dev/null; then
	@@ -960,7 +1036,7 @@ check_ssh_timeout()
    echo "ClientAliveInterval 30" >> /etc/ssh/sshd_config
    echo "ClientAliveCountMax 60" >> /etc/ssh/sshd_config
    echo "#This file has been edited by Xray-TLS-Web-setup-script" >> /etc/ssh/sshd_config
    systemctl restart sshd
    green  "----------------------配置完成----------------------"
    tyblue " 请重新连接服务器以让配置生效"
    if [ $in_install_update_xray_tls_web -eq 1 ]; then
	@@ -977,11 +1053,11 @@ uninstall_firewall()
{
    green "正在删除防火墙。。。"
    ufw disable
    $debian_package_manager -y purge firewalld
    $debian_package_manager -y purge ufw
    systemctl stop firewalld
    systemctl disable firewalld
    $redhat_package_manager -y remove firewalld
    green "正在删除阿里云盾和腾讯云盾 (仅对阿里云和腾讯云服务器有效)。。。"
    #阿里云盾
    pkill -9 assist_daemon
	@@ -998,8 +1074,8 @@ uninstall_firewall()
    systemctl disable AssistDaemon
    systemctl stop aliyun
    systemctl disable aliyun
    $debian_package_manager -y purge aliyun-assist
    $redhat_package_manager -y remove aliyun_assist
    rm -rf /usr/local/share/aliyun-assist
    rm -rf /usr/sbin/aliyun_installer
    rm -rf /usr/sbin/aliyun-service
	@@ -1073,8 +1149,8 @@ doupdate()
        check_important_dependence_installed "ubuntu-release-upgrader-core"
        echo -e "\\n\\n\\n"
        tyblue "------------------请选择升级系统版本--------------------"
        tyblue " 1. beta版(测试版)          当前版本号：22.04"
        tyblue " 2. release版(稳定版)       当前版本号：22.04"
        tyblue " 3. LTS版(长期支持版)       当前版本号：22.04"
        tyblue " 0. 不升级系统"
        tyblue "-------------------------注意事项-------------------------"
	@@ -1139,12 +1215,12 @@ doupdate()
                    do-release-upgrade -m server
                    ;;
            esac
            $debian_package_manager -y --purge autoremove
            $debian_package_manager update
            $debian_package_manager -y --purge autoremove
            $debian_package_manager -y --auto-remove --purge --no-install-recommends full-upgrade
            $debian_package_manager -y --purge autoremove
            $debian_package_manager clean
        done
    }
    while ((1))
	@@ -1161,7 +1237,9 @@ doupdate()
        choice=""
        while [ "$choice" != "1" ] && [ "$choice" != "2" ] && [ "$choice" != "3" ]
        do
            read -p "您的选择是：" choice
        done
        if [ $release == "ubuntu" ] || [ $choice -ne 1 ]; then
            break
	@@ -1172,23 +1250,23 @@ doupdate()
    done
    if [ $choice -eq 1 ]; then
        updateSystem
        $debian_package_manager -y --purge autoremove
        $debian_package_manager clean
    elif [ $choice -eq 2 ]; then
        tyblue "-----------------------即将开始更新-----------------------"
        yellow " 更新过程中遇到问话/对话框，如果不明白，选择yes/y/第一个选项"
        yellow " 按回车键继续。。。"
        read -s
        $debian_package_manager -y --purge autoremove
        $debian_package_manager update
        $debian_package_manager -y --purge autoremove
        $debian_package_manager -y --auto-remove --purge --no-install-recommends full-upgrade
        $debian_package_manager -y --purge autoremove
        $debian_package_manager clean
        $redhat_package_manager -y autoremove
        $redhat_package_manager_enhanced upgrade
        $redhat_package_manager -y autoremove
        $redhat_package_manager clean all
    fi
}

	@@ -1300,8 +1378,8 @@ install_bbr()
                yellow "没有内核可卸载"
                return 0
            fi
            $debian_package_manager -y purge "${kernel_list_image[@]}" "${kernel_list_modules[@]}" && exit_code=0
            [ $exit_code -eq 1 ] && $debian_package_manager -y -f install
            apt-mark manual "^grub"
        else
            rpm -qa > "temp_installed_list"
	@@ -1360,8 +1438,8 @@ install_bbr()
                yellow "没有内核可卸载"
                return 0
            fi
            #$redhat_package_manager -y remove "${kernel_list[@]}" "${kernel_list_headers[@]}" "${kernel_list_modules[@]}" "${kernel_list_core[@]}" "${kernel_list_devel[@]}" && exit_code=0
            $redhat_package_manager -y remove "${kernel_list[@]}" "${kernel_list_modules[@]}" "${kernel_list_core[@]}" "${kernel_list_devel[@]}" && exit_code=0
        fi
        if [ $exit_code -eq 0 ]; then
            green "卸载成功"
	@@ -1490,7 +1568,13 @@ install_bbr()
        local choice=""
        while [[ ! "$choice" =~ ^(0|[1-9][0-9]*)$ ]] || ((choice>10))
        do
            read -p "您的选择是：" choice
        done
        if (( 1<=choice&&choice<=4 )); then
            if (( choice==1 || choice==4 )) && ([ $release == "ubuntu" ] || [ $release == "debian" ] || [ $release == "deepin" ] || [ $release == "other-debian" ]) && ! dpkg-deb --help | grep -qw "zstd"; then
	@@ -1504,8 +1588,8 @@ install_bbr()
                    if ! version_ge "$(dpkg --list | grep '^[ '$'\t]*ii[ '$'\t][ '$'\t]*linux-base[ '$'\t]' | awk '{print $3}')" "4.5ubuntu1~16.04.1"; then
                        install_dependence linux-base
                        if ! version_ge "$(dpkg --list | grep '^[ '$'\t]*ii[ '$'\t][ '$'\t]*linux-base[ '$'\t]' | awk '{print $3}')" "4.5ubuntu1~16.04.1"; then
                            if ! $debian_package_manager update; then
                                red "$debian_package_manager update出错"
                                green  "欢迎进行Bug report(https://github.com/CatherineReyes-byte/Xray-script/issues)，感谢您的支持"
                                yellow "按回车键继续或者Ctrl+c退出"
                                read -s
	@@ -1652,7 +1736,7 @@ install_bbr()
readProtocolConfig()
{
    echo -e "\\n\\n\\n"
    tyblue "---------------------请选择传输层协议---------------------"
    tyblue " 1. TCP"
    tyblue " 2. gRPC"
    tyblue " 3. WebSocket"
	@@ -1663,15 +1747,16 @@ readProtocolConfig()
    yellow " 0. 无 (仅提供Web服务)"
    echo
    blue   " 注："
    blue   "   1. 不知道什么是CDN或不使用CDN，请选择TCP"
    blue   "   2. gRPC和WebSocket支持通过CDN，关于两者的区别，详见：https://github.com/CatherineReyes-byte/Xray-script#关于grpc与websocket"
    blue   "   3. 只有TCP能使用XTLS，且XTLS完全兼容TLS"
    blue   "   4. 能使用TCP传输的只有VLESS"
    echo
    local choice=""
    while [[ ! "$choice" =~ ^(0|[1-9][0-9]*)$ ]] || ((choice>7))
    do
        read -p "您的选择是：" choice
    done
    if [ $choice -eq 1 ] || [ $choice -eq 4 ] || [ $choice -eq 5 ] || [ $choice -eq 7 ]; then
        protocol_1=1
	@@ -1688,8 +1773,22 @@ readProtocolConfig()
    else
        protocol_3=0
    fi
    if [ $protocol_2 -eq 1 ]; then
        tyblue "-------------- 请选择使用gRPC传输的会话层协议 --------------"
        tyblue " 1. VMess"
        tyblue " 2. VLESS"
        echo
	@@ -1703,7 +1802,7 @@ readProtocolConfig()
        [ $choice -eq 1 ] && protocol_2=2
    fi
    if [ $protocol_3 -eq 1 ]; then
        tyblue "-------------- 请选择使用WebSocket传输的会话层协议 --------------"
        tyblue " 1. VMess"
        tyblue " 2. VLESS"
        echo
	@@ -1712,7 +1811,9 @@ readProtocolConfig()
        choice=""
        while [[ ! "$choice" =~ ^([1-9][0-9]*)$ ]] || ((choice>2))
        do
            read -p "您的选择是：" choice
        done
        [ $choice -eq 1 ] && protocol_3=2
    fi
	@@ -1744,13 +1845,19 @@ readPretend()
        pretend=""
        while [[ "$pretend" != "1" && "$pretend" != "2" && "$pretend" != "3" && "$pretend" != "4" && "$pretend" != "5" ]]
        do
            read -p "您的选择是：" pretend
        done
        queren=1
        if [ $pretend -eq 1 ]; then
            if [ -z "$machine" ]; then
                red "您的VPS指令集不支持Cloudreve！"
                yellow "Cloudreve仅支持x86_64、arm64和arm指令集"
                sleep 3s
                queren=0
            fi
	@@ -1802,11 +1909,12 @@ readPretend()
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
	@@ -1838,7 +1946,9 @@ readDomain()
    echo
    while [ "$domain_config" != "1" ] && [ "$domain_config" != "2" ]
    do
        read -p "您的选择是：" domain_config
    done
    local queren=0
    while [ $queren -ne 1 ]
	@@ -1853,17 +1963,15 @@ readDomain()
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
	@@ -1909,10 +2017,10 @@ install_php_dependence()
        fedora_install_remi
        install_dependence libxml2-devel sqlite-devel systemd-devel libacl-devel openssl-devel krb5-devel pcre2-devel zlib-devel bzip2-devel libcurl-devel gdbm-devel libdb-devel tokyocabinet-devel lmdb-devel enchant-devel libffi-devel libpng-devel gd-devel libwebp-devel libjpeg-turbo-devel libXpm-devel freetype-devel gmp-devel uw-imap-devel libicu-devel openldap-devel oniguruma-devel unixODBC-devel freetds-devel libpq-devel aspell-devel libedit-devel net-snmp-devel libsodium-devel libargon2-devel libtidy-devel libxslt-devel libzip-devel ImageMagick-devel
    else
        if ! $debian_package_manager -y --no-install-recommends install libxml2-dev libsqlite3-dev libsystemd-dev libacl1-dev libapparmor-dev libssl-dev libkrb5-dev libpcre2-dev zlib1g-dev libbz2-dev libcurl4-openssl-dev libqdbm-dev libdb-dev libtokyocabinet-dev liblmdb-dev libenchant-2-dev libffi-dev libpng-dev libgd-dev libwebp-dev libjpeg-dev libxpm-dev libfreetype6-dev libgmp-dev libc-client2007e-dev libicu-dev libldap2-dev libsasl2-dev libonig-dev unixodbc-dev freetds-dev libpq-dev libpspell-dev libedit-dev libmm-dev libsnmp-dev libsodium-dev libargon2-dev libtidy-dev libxslt1-dev libzip-dev libmagickwand-dev && ! $debian_package_manager -y --no-install-recommends install libxml2-dev libsqlite3-dev libsystemd-dev libacl1-dev libapparmor-dev libssl-dev libkrb5-dev libpcre2-dev zlib1g-dev libbz2-dev libcurl4-openssl-dev libqdbm-dev libdb-dev libtokyocabinet-dev liblmdb-dev libenchant-dev libffi-dev libpng-dev libgd-dev libwebp-dev libjpeg-dev libxpm-dev libfreetype6-dev libgmp-dev libc-client2007e-dev libicu-dev libldap2-dev libsasl2-dev libonig-dev unixodbc-dev freetds-dev libpq-dev libpspell-dev libedit-dev libmm-dev libsnmp-dev libsodium-dev libargon2-dev libtidy-dev libxslt1-dev libzip-dev libmagickwand-dev; then
            $debian_package_manager update
            $debian_package_manager -y -f install
            if ! $debian_package_manager -y --no-install-recommends install libxml2-dev libsqlite3-dev libsystemd-dev libacl1-dev libapparmor-dev libssl-dev libkrb5-dev libpcre2-dev zlib1g-dev libbz2-dev libcurl4-openssl-dev libqdbm-dev libdb-dev libtokyocabinet-dev liblmdb-dev libenchant-2-dev libffi-dev libpng-dev libgd-dev libwebp-dev libjpeg-dev libxpm-dev libfreetype6-dev libgmp-dev libc-client2007e-dev libicu-dev libldap2-dev libsasl2-dev libonig-dev unixodbc-dev freetds-dev libpq-dev libpspell-dev libedit-dev libmm-dev libsnmp-dev libsodium-dev libargon2-dev libtidy-dev libxslt1-dev libzip-dev libmagickwand-dev && ! $debian_package_manager -y --no-install-recommends install libxml2-dev libsqlite3-dev libsystemd-dev libacl1-dev libapparmor-dev libssl-dev libkrb5-dev libpcre2-dev zlib1g-dev libbz2-dev libcurl4-openssl-dev libqdbm-dev libdb-dev libtokyocabinet-dev liblmdb-dev libenchant-dev libffi-dev libpng-dev libgd-dev libwebp-dev libjpeg-dev libxpm-dev libfreetype6-dev libgmp-dev libc-client2007e-dev libicu-dev libldap2-dev libsasl2-dev libonig-dev unixodbc-dev freetds-dev libpq-dev libpspell-dev libedit-dev libmm-dev libsnmp-dev libsodium-dev libargon2-dev libtidy-dev libxslt1-dev libzip-dev libmagickwand-dev; then
                yellow "依赖安装失败！！"
                green  "欢迎进行Bug report(https://github.com/CatherineReyes-byte/Xray-script/issues)，感谢您的支持"
                yellow "按回车键继续或者Ctrl+c退出"
	@@ -1944,15 +2052,15 @@ install_web_dependence()
        for i in "${pretend_list[@]}"
        do
            if [ "$i" == "2" ]; then
                install_dependence ca-certificates wget unzip
                break
            fi
        done
    else
        if [ "$1" == "1" ]; then
            install_dependence ca-certificates wget
        elif [ "$1" == "2" ]; then
            install_dependence ca-certificates wget unzip
        fi
    fi
}
	@@ -2355,7 +2463,7 @@ events {
http {
    include       mime.types;
    default_type  application/octet-stream;
    #log_format  main  '\$remote_addr - \$remote_user [\$time_local] "\$request" '
    #                  '\$status \$body_bytes_sent "\$http_referer" '
    #                  '"\$http_user_agent" "\$http_x_forwarded_for"';
	@@ -2497,6 +2605,15 @@ server {
    return 301 https://${domain_list[0]};
}
EOF
    for ((i=0;i<${#domain_list[@]};i++))
    do
cat >> $nginx_config<<EOF
	@@ -2547,7 +2664,44 @@ EOF
                echo "        return 403;" >> $nginx_config
                echo "    }" >> $nginx_config
            else
                echo "    return 403;" >> $nginx_config
            fi
        elif [ "${pretend_list[$i]}" == "4" ]; then
            echo "    root ${nginx_prefix}/html/${true_domain_list[$i]};" >> $nginx_config
	@@ -2556,6 +2710,7 @@ cat >> $nginx_config<<EOF
    location / {
        proxy_pass ${pretend_list[$i]};
        proxy_set_header referer "${pretend_list[$i]}";
    }
EOF
        fi
	@@ -2582,19 +2737,27 @@ cat > $xray_config <<EOF
    },
    "inbounds": [
        {
            "port": 443,
            "protocol": "vless",
            "settings": {
EOF
    if [ $protocol_1 -eq 1 ]; then
cat >> $xray_config <<EOF
                "clients": [
                    {
                        "id": "$xid_1",
                        "flow": "xtls-rprx-direct"
                    }
                ],
EOF
    fi
    echo '                "decryption": "none",' >> $xray_config
    echo '                "fallbacks": [' >> $xray_config
	@@ -2618,8 +2781,8 @@ cat >> $xray_config <<EOF
            },
            "streamSettings": {
                "network": "tcp",
                "security": "xtls",
                "xtlsSettings": {
                    "alpn": [
                        "h2",
                        "http/1.1"
	@@ -2694,6 +2857,9 @@ EOF
        fi
cat >> $xray_config <<EOF
            },
            "streamSettings": {
                "network": "ws",
                "wsSettings": {
	@@ -2705,9 +2871,22 @@ EOF
cat >> $xray_config <<EOF
        }
    ],
    "outbounds": [
        {
            "protocol": "freedom"
        }
    ]
}
	@@ -2728,14 +2907,19 @@ init_web()
        fi
        turn_on_off_php
    elif [ "${pretend_list[$1]}" == "2" ]; then
        if ! wget -O "${nginx_prefix}/html/nextcloud.zip" "${nextcloud_url}"; then
            red    "获取Nextcloud失败"
            yellow "按回车键继续或者按Ctrl+c终止"
            read -s
        fi
        rm -rf "${nginx_prefix}/html/${true_domain_list[$1]}"
        unzip -q -d "${nginx_prefix}/html" "${nginx_prefix}/html/nextcloud.zip"
        rm -f "${nginx_prefix}/html/nextcloud.zip"
        mv "${nginx_prefix}/html/nextcloud" "${nginx_prefix}/html/${true_domain_list[$1]}"
        chown -R www-data:www-data "${nginx_prefix}/html/${true_domain_list[$1]}"
        systemctl start php-fpm
	@@ -2810,15 +2994,15 @@ install_init_cloudreve()
    chmod 0700 $cloudreve_prefix
    update_cloudreve
    rm -rf /dev/shm/cloudreve
    local temp
    temp="$("$cloudreve_prefix/cloudreve" | grep "初始管理员密码：" | awk '{print $4}')"
    sleep 1s
    systemctl start cloudreve
    systemctl enable cloudreve
    tyblue "-------- 请打开\"https://${domain_list[$1]}\"进行Cloudreve初始化 -------"
    tyblue "  1. 登陆帐号"
    purple "    初始管理员账号：admin@cloudreve.org"
    purple "    $temp"
    tyblue "  2. 右上角头像 -> 管理面板"
    tyblue "  3. 这时会弹出对话框 \"确定站点URL设置\" 选择 \"更改\""
    tyblue "  4. 左侧参数设置 -> 注册与登陆 -> 不允许新用户注册 -> 往下拉点击保存"
	@@ -2834,10 +3018,10 @@ install_init_cloudreve()
let_init_nextcloud()
{
    echo -e "\\n\\n"
    yellow "请立即打开\"https://${domain_list[$1]}\"进行Nextcloud初始化设置："
    tyblue " 1.自定义管理员的用户名和密码"
    tyblue " 2.数据库类型选择SQLite"
    tyblue " 3.建议不勾选\"安装推荐的应用\"，因为进去之后还能再安装"
    sleep 15s
    echo -e "\\n\\n"
    tyblue "按两次回车键以继续。。。"
	@@ -2848,7 +3032,7 @@ let_init_nextcloud()

print_share_link()
{
    if [ $protocol_1 -eq 1 ]; then
        local ip=""
        while [ -z "$ip" ]
        do
	@@ -2860,33 +3044,25 @@ print_share_link()
    fi
    echo
    tyblue "分享链接："
    if [ $protocol_1 -eq 1 ]; then
        green  "============ VLESS-TCP-TLS\\033[35m(不走CDN)\\033[32m ============"
        for i in "${!domain_list[@]}"
        do
            if [ "${pretend_list[$i]}" == "1" ] || [ "${pretend_list[$i]}" == "2" ]; then
                tyblue "vless://${xid_1}@${ip}:443?security=tls&sni=${domain_list[$i]}&alpn=http%2F1.1"
            else
                tyblue "vless://${xid_1}@${ip}:443?security=tls&sni=${domain_list[$i]}&alpn=h2,http%2F1.1"
            fi
        done
        green  "============ VLESS-TCP-XTLS\\033[35m(不走CDN)\\033[32m ============"
        yellow "Linux/安卓/路由器："
        for i in "${!domain_list[@]}"
        do
            if [ "${pretend_list[$i]}" == "1" ] || [ "${pretend_list[$i]}" == "2" ]; then
                tyblue "vless://${xid_1}@${ip}:443?security=xtls&sni=${domain_list[$i]}&alpn=http%2F1.1&flow=xtls-rprx-splice"
            else
                tyblue "vless://${xid_1}@${ip}:443?security=xtls&sni=${domain_list[$i]}&alpn=h2,http%2F1.1&flow=xtls-rprx-splice"
            fi
        done
        yellow "其他："
        for i in "${!domain_list[@]}"
        do
            if [ "${pretend_list[$i]}" == "1" ] || [ "${pretend_list[$i]}" == "2" ]; then
                tyblue "vless://${xid_1}@${ip}:443?security=xtls&sni=${domain_list[$i]}&alpn=http%2F1.1&flow=xtls-rprx-direct"
            else
                tyblue "vless://${xid_1}@${ip}:443?security=xtls&sni=${domain_list[$i]}&alpn=h2,http%2F1.1&flow=xtls-rprx-direct"
            fi
        done
    fi
	@@ -2921,25 +3097,35 @@ print_config_info()
{
    echo -e "\\n\\n\\n"
    if [ $protocol_1 -ne 0 ]; then
        tyblue "--------------------- VLESS-TCP-XTLS/TLS (不走CDN) ---------------------"
        tyblue " protocol(传输协议)    ：\\033[33mvless"
        purple "  (V2RayN选择\"添加[VLESS]服务器\";V2RayNG选择\"手动输入[VLESS]\")"
        tyblue " address(地址)         ：\\033[33m服务器ip"
        purple "  (Qv2ray:主机)"
        tyblue " port(端口)            ：\\033[33m443"
        tyblue " id(用户ID/UUID)       ：\\033[33m${xid_1}"
        tyblue " flow(流控)            ："
        tyblue "                         使用XTLS ："
        tyblue "                                    Linux/安卓/路由器：\\033[33mxtls-rprx-splice\\033[32m(推荐)\\033[36m或\\033[33mxtls-rprx-direct"
        tyblue "                                    其它             ：\\033[33mxtls-rprx-direct"
        tyblue "                         使用TLS  ：\\033[33m空"
        tyblue " encryption(加密)      ：\\033[33mnone"
        tyblue " ---Transport/StreamSettings(底层传输方式/流设置)---"
        tyblue "  network(传输方式)             ：\\033[33mtcp"
        purple "   (Shadowrocket传输方式选none)"
        tyblue "  type(伪装类型)                ：\\033[33mnone"
        purple "   (Qv2ray:协议设置-类型)"
        tyblue "  security(传输层加密)          ：\\033[33mxtls\\033[36m或\\033[33mtls \\033[35m(此选项将决定是使用XTLS还是TLS)"
        purple "   (V2RayN(G):底层传输安全;Qv2ray:TLS设置-安全类型)"
        if [ ${#domain_list[@]} -eq 1 ]; then
            tyblue "  serverName                    ：\\033[33m${domain_list[*]}"
	@@ -2949,13 +3135,11 @@ print_config_info()
        purple "   (V2RayN(G):SNI;Qv2ray:TLS设置-服务器地址;Shadowrocket:Peer 名称)"
        tyblue "  allowInsecure                 ：\\033[33mfalse"
        purple "   (Qv2ray:TLS设置-允许不安全的证书(不打勾);Shadowrocket:允许不安全(关闭))"
        tyblue "  fingerprint                   ："
        tyblue "                                  使用XTLS ：\\033[33m空"
        tyblue "                                  使用TLS  ：\\033[33m空\\033[36m/\\033[33mchrome\\033[32m(推荐)\\033[36m/\\033[33mfirefox\\033[36m/\\033[33msafari"
        purple "                                           (此选项决定是否伪造浏览器指纹，空代表不伪造)"
        tyblue "  alpn                          ："
        tyblue "                                  伪造浏览器指纹  ：此参数不生效，可随意设置"
        tyblue "                                  不伪造浏览器指纹：serverName填的域名对应的伪装网站为网盘则设置为\\033[33mhttp/1.1\\033[36m，否则设置为\\033[33m空\\033[36m或\\033[33mh2,http/1.1"
        purple "   (Qv2ray:TLS设置-ALPN) (注意Qv2ray如果要设置alpn为h2,http/1.1，请填写\"h2|http/1.1\")"
        tyblue " ------------------------其他-----------------------"
        tyblue "  Mux(多路复用)                 ：使用XTLS必须关闭;不使用XTLS也建议关闭"
	@@ -2999,7 +3183,9 @@ print_config_info()
        purple "   (V2RayN(G):SNI和伪装域名;Qv2ray:TLS设置-服务器地址;Shadowrocket:Peer 名称)"
        tyblue "  allowInsecure                 ：\\033[33mfalse"
        purple "   (Qv2ray:TLS设置-允许不安全的证书(不打勾);Shadowrocket:允许不安全(关闭))"
        tyblue "  alpn                          ：\\033[33m空\\033[36m或\\033[33mh2,http/1.1"
        purple "   (Qv2ray:TLS设置-ALPN) (注意Qv2ray如果要设置alpn为h2,http/1.1，请填写\"h2|http/1.1\")"
        tyblue " ------------------------其他-----------------------"
        tyblue "  Mux(多路复用)                 ：强烈建议关闭"
	@@ -3044,26 +3230,24 @@ print_config_info()
        purple "   (V2RayN(G):SNI和伪装域名;Qv2ray:TLS设置-服务器地址;Shadowrocket:Peer 名称)"
        tyblue "  allowInsecure                 ：\\033[33mfalse"
        purple "   (Qv2ray:TLS设置-允许不安全的证书(不打勾);Shadowrocket:允许不安全(关闭))"
        tyblue "  alpn                          ：此参数不生效，可随意设置"
        purple "   (Qv2ray:TLS设置-ALPN) (注意Qv2ray如果要设置alpn为h2,http/1.1，请填写\"h2|http/1.1\")"
        tyblue " ------------------------其他-----------------------"
        tyblue "  Mux(多路复用)                 ：建议关闭"
        purple "   (V2RayN:设置页面-开启Mux多路复用)"
        tyblue "------------------------------------------------------------------------"
    fi
    echo
    ask_if "是否生成分享链接？(y/n)" && print_share_link
    echo
    yellow " 关于fingerprint与alpn，详见：https://github.com/CatherineReyes-byte/Xray-script#关于tls握手tls指纹和alpn"
    echo
    blue   " 若想实现Fullcone(NAT类型开放)，需要达成以下条件："
    blue   "   1. 确保客户端核心为 Xray v1.3.0+"
    blue   "   2. 若您正在使用Netch作为客户端，请不要使用模式 [1] 连接 (可使用模式 [3] Bypass LAN )"
    blue   "   3. 如果测试系统为Windows，并且正在使用透明代理或TUN/Bypass LAN，请确保当前网络设置为专用网络"
    echo
    blue   " 若想实现WebSocket 0-rtt，请将客户端核心升级至 Xray v1.4.0+"
    echo
    tyblue " 脚本最后更新时间：2021.09.10"
    echo
    red    " 此脚本仅供交流学习使用，请勿使用此脚本行违法之事。网络非法外之地，行非法之事，必将接受法律制裁!!!!"
    tyblue " 2020.11"
	@@ -3073,7 +3257,7 @@ install_update_xray_tls_web()
{
    in_install_update_xray_tls_web=1
    check_nginx_installed_system
    [ "$redhat_package_manager" == "yum" ] && check_important_dependence_installed "" "yum-utils"
    check_SELinux
    check_important_dependence_installed iproute2 iproute
    check_port
	@@ -3083,13 +3267,15 @@ install_update_xray_tls_web()
    check_important_dependence_installed wget wget
    check_important_dependence_installed "procps" "procps-ng"
    install_epel
    ask_update_script
    check_ssh_timeout
    uninstall_firewall
    doupdate
    enter_temp_dir
    install_bbr
    $debian_package_manager -y -f install

    #读取信息
    if [ $update -eq 0 ]; then
	@@ -3188,8 +3374,8 @@ install_update_xray_tls_web()
    else
        [ $cloudreve_is_installed -eq 1 ] && install_web_dependence "1"
    fi
    $debian_package_manager clean
    $redhat_package_manager clean all

    #编译&&安装php
    if [ $install_php -eq 1 ]; then
	@@ -3275,7 +3461,7 @@ full_install_php()
#安装/检查更新/更新php
install_check_update_update_php()
{
    [ "$redhat_package_manager" == "yum" ] && check_important_dependence_installed "" "yum-utils"
    check_SELinux
    check_important_dependence_installed tzdata tzdata
    get_system_info
	@@ -3347,7 +3533,7 @@ install_check_update_update_php()
check_update_update_nginx()
{
    check_nginx_installed_system
    [ "$redhat_package_manager" == "yum" ] && check_important_dependence_installed "" "yum-utils"
    check_SELinux
    check_important_dependence_installed tzdata tzdata
    get_system_info
	@@ -3416,7 +3602,7 @@ restart_xray_tls_web()
}
reinit_domain()
{
    [ "$redhat_package_manager" == "yum" ] && check_important_dependence_installed "" "yum-utils"
    check_important_dependence_installed iproute2 iproute
    check_port
    check_important_dependence_installed tzdata tzdata
	@@ -3484,7 +3670,7 @@ reinit_domain()
}
add_domain()
{
    [ "$redhat_package_manager" == "yum" ] && check_important_dependence_installed "" "yum-utils"
    check_important_dependence_installed iproute2 iproute
    check_port
    check_important_dependence_installed tzdata tzdata
	@@ -3590,7 +3776,7 @@ delete_domain()
}
change_pretend()
{
    [ "$redhat_package_manager" == "yum" ] && check_important_dependence_installed "" "yum-utils"
    check_important_dependence_installed tzdata tzdata
    get_system_info
    check_important_dependence_installed ca-certificates ca-certificates
	@@ -3662,7 +3848,7 @@ reinstall_cloudreve()
    ! check_need_cloudreve && red "Cloudreve目前没有绑定域名" && return 1
    red "重新安装Cloudreve将删除所有的网盘文件以及帐户信息，并重置管理员密码"
    ! ask_if "确定要继续吗？(y/n)" && return 0
    [ "$redhat_package_manager" == "yum" ] && check_important_dependence_installed "" "yum-utils"
    check_SELinux
    check_important_dependence_installed ca-certificates ca-certificates
    check_important_dependence_installed wget wget
	@@ -3810,19 +3996,15 @@ simplify_system()
        yellow "请先停止Xray-TLS+Web"
        return 1
    fi
    [ "$redhat_package_manager" == "yum" ] && check_important_dependence_installed "" "yum-utils"
    check_important_dependence_installed tzdata tzdata
    get_system_info
    check_important_dependence_installed "procps" "procps-ng"
    yellow "警告："
    tyblue " 1. 此功能可能导致某些VPS无法开机，请谨慎使用"
    tyblue " 2. 如果VPS上部署了 Xray-TLS+Web 以外的东西，可能被误删"
    ! ask_if "是否要继续?(y/n)" && return 0
    echo
    yellow "提示：在精简系统前请先设置apt/yum/dnf的软件源为http/ftp而非https/ftps"
    purple "通常来说系统默认即是http/ftp"
    ! ask_if "是否要继续?(y/n)" && return 0
    echo
    local save_ssh=0
    yellow "提示：精简系统可能导致ssh配置文件(/etc/ssh/sshd_config)恢复默认"
    tyblue "这可能导致ssh端口恢复默认(22)，且有些系统默认仅允许密钥登录(不允许密码登录)"
	@@ -3842,42 +4024,66 @@ simplify_system()
        done
        local temp_remove_list=('openssl' 'perl*' 'xz' 'libselinux-utils' 'zip' 'unzip' 'bzip2' 'wget' 'procps-ng' 'procps' 'iproute' 'dbus-glib' 'udisk*' 'libudisk*' 'gdisk*' 'libblock*' '*-devel' 'nginx*')
        #libxmlb
        if ! $redhat_package_manager -y remove "${temp_remove_list[@]}"; then
            for i in "${temp_remove_list[@]}"
            do
                $redhat_package_manager -y remove "$i"
            done
        fi
        for i in "${temp_backup[@]}"
        do
            check_important_dependence_installed "" "$i"
        done
    else
        local temp_backup=()
        local temp_important=('apt-utils' 'whiptail' 'initramfs-tools' 'isc-dhcp-client' 'netplan.io' 'openssh-server' 'network-manager')
        for i in "${temp_important[@]}"
        do
            LANG="en_US.UTF-8" LANGUAGE="en_US:en" dpkg -s "$i" 2>/dev/null | grep -qi 'status[ '$'\t]*:[ '$'\t]*install[ '$'\t]*ok[ '$'\t]*installed[ '$'\t]*$' && temp_backup+=("$i")
        done
        temp_backup+=($(dpkg --list 'grub*' | grep '^[ '$'\t]*ii[ '$'\t]' | awk '{print $2}'))
        local temp_remove_list=('cron' 'anacron' '^cups' '^foomatic' 'openssl' 'snapd' 'kdump-tools' 'flex' 'make' 'automake' '^cloud-init' 'pkg-config' '^gcc-[1-9][0-9]*$' '^cpp-[1-9][0-9]*$' 'curl' '^python' '^libpython' 'dbus' 'at' 'open-iscsi' 'rsyslog' 'acpid' 'libnetplan0' 'glib-networking-common' 'bcache-tools' '^bind([0-9]|-|$)' 'lshw' '^thermald' '^libdbus' '^libevdev' '^libupower' 'readline-common' '^libreadline' 'xz-utils' 'selinux-utils' 'wget' 'zip' 'unzip' 'bzip2' 'finalrd' '^cryptsetup' '^libplymouth' '^lib.*-dev$' 'perl' '^perl-modules' '^x11' '^libx11' '^qemu' '^xdg-' '^libglib' '^libicu' '^libxml' '^liburing' '^libisc' '^libdns' '^isc-' 'net-tools' 'xxd' 'xkb-data' 'lsof' '^task' '^usb' '^libusb' '^doc' '^libwrap' '^libtext' '^libmagic' '^libpci' '^liblocale' '^keyboard' '^libuni[^s]' '^libpipe' 'man-db' '^manpages' '^liblock' '^liblog' '^libxapian' '^libpsl' '^libpap' '^libgs[0-9]' '^libpaper' '^postfix' '^nginx' '^libnginx')
        #'^libp11' '^libtasn' '^libkey' '^libnet'
        if ! $debian_package_manager -y --auto-remove purge "${temp_remove_list[@]}"; then
            $debian_package_manager -y -f install
            $debian_package_manager -y --auto-remove purge cron anacron || $debian_package_manager -y -f install
            $debian_package_manager -y --auto-remove purge '^cups' '^foomatic' || $debian_package_manager -y -f install
            for i in "${temp_remove_list[@]}"
            do
                $debian_package_manager -y --auto-remove purge "$i" || $debian_package_manager -y -f install
            done
        fi
        $debian_package_manager -y --auto-remove purge '^libpop' || $debian_package_manager -y -f install
        $debian_package_manager -y --auto-remove purge '^libslang' || $debian_package_manager -y -f install
        $debian_package_manager -y --auto-remove purge apt-utils || $debian_package_manager -y -f install
        for i in "${temp_backup[@]}"
        do
            check_important_dependence_installed "$i" ""
        done
    fi
    ([ $nginx_is_installed -eq 1 ] || [ $php_is_installed -eq 1 ] || [ $is_installed -eq 1 ]) && install_epel
    [ $nginx_is_installed -eq 1 ] && install_nginx_dependence
	@@ -3887,7 +4093,7 @@ simplify_system()
        cp sshd_config /etc/ssh/sshd_config
        cd /
        rm -rf "$temp_dir"
        systemctl restart sshd
    fi
    green "精简完成"
}
	@@ -4007,7 +4213,9 @@ start_menu()
    local choice=""
    while [[ ! "$choice" =~ ^(0|[1-9][0-9]*)$ ]] || ((choice>27))
    do
        read -p "您的选择是：" choice
    done
    if (( choice==2 || (7<=choice&&choice<=9) || choice==13 || (15<=choice&&choice<=24) )) && [ $is_installed -eq 0 ]; then
        red "请先安装Xray-TLS+Web！！"
	@@ -4020,32 +4228,32 @@ start_menu()
    if [ $choice -eq 1 ]; then
        install_update_xray_tls_web
    elif [ $choice -eq 2 ]; then
        [ "$redhat_package_manager" == "yum" ] && check_important_dependence_installed "" "yum-utils"
        check_important_dependence_installed ca-certificates ca-certificates
        check_important_dependence_installed wget wget
        ask_update_script_force
        bash "${BASH_SOURCE[0]}" --update
    elif [ $choice -eq 3 ]; then
        [ "$redhat_package_manager" == "yum" ] && check_important_dependence_installed "" "yum-utils"
        check_important_dependence_installed ca-certificates ca-certificates
        check_important_dependence_installed wget wget
        ask_update_script
    elif [ $choice -eq 4 ]; then
        [ "$redhat_package_manager" == "yum" ] && check_important_dependence_installed "" "yum-utils"
        check_important_dependence_installed tzdata tzdata
        get_system_info
        check_ssh_timeout
        check_important_dependence_installed "procps" "procps-ng"
        doupdate
        green "更新完成！"
    elif [ $choice -eq 5 ]; then
        [ "$redhat_package_manager" == "yum" ] && check_important_dependence_installed "" "yum-utils"
        check_important_dependence_installed ca-certificates ca-certificates
        check_important_dependence_installed wget wget
        check_important_dependence_installed "procps" "procps-ng"
        enter_temp_dir
        install_bbr
        $debian_package_manager -y -f install
        rm -rf "$temp_dir"
    elif [ $choice -eq 6 ]; then
        install_check_update_update_php
	@@ -4057,7 +4265,7 @@ start_menu()
            tyblue "在 修改伪装网站类型/重置域名/添加域名 里选择Cloudreve"
            return 1
        fi
        [ "$redhat_package_manager" == "yum" ] && check_important_dependence_installed "" "yum-utils"
        check_SELinux
        install_web_dependence "1"
        ask_update_script_force
	@@ -4067,15 +4275,15 @@ start_menu()
        rm -rf "$temp_dir"
        green "Cloudreve更新完成！"
    elif [ $choice -eq 9 ]; then
        [ "$redhat_package_manager" == "yum" ] && check_important_dependence_installed "" "yum-utils"
        check_SELinux
        check_important_dependence_installed ca-certificates ca-certificates
        check_important_dependence_installed curl curl
        install_update_xray
        green "Xray更新完成！"
    elif [ $choice -eq 10 ]; then
        ! ask_if "确定要删除吗?(y/n)" && return 0
        [ "$redhat_package_manager" == "yum" ] && check_important_dependence_installed "" "yum-utils"
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
        systemctl stop xray nginx

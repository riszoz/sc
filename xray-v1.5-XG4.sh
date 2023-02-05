#!/bin/bash

#颜色
red='\033[0;31m'
green='\033[1;32m'
yellow='\033[1;33m'
plain='\033[0m'
#定义颜色变量
RED="\033[31m"    # Error message
GREEN="\033[32m"  # Success message
YELLOW="\033[33m" # Warning message
BLUE="\033[36m"   # Info message
PLAIN='\033[0m'
red='\e[91m' green='\e[92m' yellow='\e[93m' magenta='\e[95m' cyan='\e[96m' none='\e[0m'

#定义停留警告界面
Error() { read -sp "$(echo -e "\n${red}$*${none}\n")"; }

#定义停留通知界面
Notifi() { read -sp "$(echo -e "\n${green}$*${none}\n")"; }

#输出执行成功信息
PrintTrueInfo() { echo -e "\n${yellow}$*${none}\n"; }

#输出执行错误信息
PrintFalseInfo() { echo -e "\n${red}$*${none}\n"; }

#定义存放错误信息的变量
error_info=

#定义是否显示安装bbr加速的选项
print_bbr=true

#定义备份账号信息的路径
backup="/etc/xray/xray_backup.conf"

#定义一个空的伪装路径变量
WSPATH=

#定义一个空的xray监听的端口变量
XPORT=
#定义一个空的域名变量
DOMAIN=

#定义一个搭建账号类型的变量
account_class=

#获取当前位置
path_now=$(pwd)

#获取用户目录
desktop=/home/$(who | awk '{print $1}') 

#获取用户名
user_name=$(who | awk '{print $1}')



red='\033[0;31m'
bblue='\033[0;34m'
plain='\033[0m'
blue(){ echo -e "\033[36m\033[01m$1\033[0m";}
red(){ echo -e "\033[31m\033[01m$1\033[0m";}
green(){ echo -e "\033[32m\033[01m$1\033[0m";}
yellow(){ echo -e "\033[33m\033[01m$1\033[0m";}
white(){ echo -e "\033[37m\033[01m$1\033[0m";}
readp(){ read -p "$(yellow "$1")" $2;}

[[ $EUID -ne 0 ]] && yellow "请以root模式运行脚本" && exit
if [[ -f /etc/redhat-release ]]; then
release="Centos"
elif cat /etc/issue | grep -q -E -i "debian"; then
release="Debian"
elif cat /etc/issue | grep -q -E -i "ubuntu"; then
release="Ubuntu"
elif cat /etc/issue | grep -q -E -i "centos|red hat|redhat"; then
release="Centos"
elif cat /proc/version | grep -q -E -i "debian"; then
release="Debian"
elif cat /proc/version | grep -q -E -i "ubuntu"; then
release="Ubuntu"
elif cat /proc/version | grep -q -E -i "centos|red hat|redhat"; then
release="Centos"
else 
red "不支持你当前系统，请选择使用Ubuntu,Debian,Centos系统" && exit 
fi

re_ufw() {
	rm -rf acme.sh-master
	rm -f master.tar.gz 
	echo
	即将重启ufw防火墙，稍后VPS可能会断开一会儿...
	sleep 2
	echo y | ufw enable		# 启动ufw防火墙
	systemctl restart ufw; systemctl enable ufw; ufw reload  	# 重新加载并重新启动ufw防火墙
}

v4v6(){
	v6=$(curl -s6m6 api64.ipify.org -k)
	v4=$(curl -s4m6 api64.ipify.org -k)
}

acme1(){
	[[ $(type -P yum) ]] && yumapt='yum -y' || yumapt='apt -y'
	[[ $(type -P curl) ]] || (yellow "检测到curl未安装，升级安装中" && $yumapt update;$yumapt install curl)
	[[ $(type -P lsof) ]] || (yellow "检测到lsof未安装，升级安装中" && $yumapt update;$yumapt install lsof)
	[[ $(type -P socat) ]] || $yumapt install socat
	v4v6
	if [[ -z $v4 ]]; then
		yellow "检测到VPS为纯IPV6 Only，添加dns64"
		echo -e nameserver 2a01:4f8:c2c:123f::1 > /etc/resolv.conf
		green "dns64添加完毕"
		sleep 2
	fi
}

acme2(){
	yellow "关闭防火墙，开放所有端口规则"
	systemctl stop firewalld.service >/dev/null 2>&1
	systemctl disable firewalld.service >/dev/null 2>&1
	setenforce 0 >/dev/null 2>&1
	ufw disable >/dev/null 2>&1
	iptables -P INPUT ACCEPT >/dev/null 2>&1
	iptables -P FORWARD ACCEPT >/dev/null 2>&1
	iptables -P OUTPUT ACCEPT >/dev/null 2>&1
	iptables -t mangle -F >/dev/null 2>&1
	iptables -F >/dev/null 2>&1
	iptables -X >/dev/null 2>&1
	netfilter-persistent save >/dev/null 2>&1
	if [[ -n $(apachectl -v 2>/dev/null) ]]; then
		systemctl stop httpd.service >/dev/null 2>&1
		systemctl disable httpd.service >/dev/null 2>&1
		service apache2 stop >/dev/null 2>&1
		systemctl disable apache2 >/dev/null 2>&1
	fi
	green "所有端口已开放"
	sleep 2
	if [[ -n $(lsof -i :80|grep -v "PID") ]]; then
		yellow "检测到80端口被占用，现执行80端口全释放"
		sleep 2
		lsof -i :80|grep -v "PID"|awk '{print "kill -9",$2}'|sh >/dev/null 2>&1
		green "80端口全释放完毕！"
		sleep 2
	fi
}

acme3(){
	auto=`date +%s%N |md5sum | cut -c 1-10`
	Aemail=$auto@gmail.com
	echo 
	yellow "当前注册的邮箱名称：$Aemail"
	sleep 1
	echo 
	green "开始安装acme.sh申请证书脚本"
	wget -N https://github.com/Neilpang/acme.sh/archive/master.tar.gz >/dev/null 2>&1
	tar -zxvf master.tar.gz >/dev/null 2>&1
	cd acme.sh-master >/dev/null 2>&1
	./acme.sh --install >/dev/null 2>&1
	cd
	curl https://get.acme.sh | sh -s email=$Aemail
	[[ -n $(/root/.acme.sh/acme.sh -v 2>/dev/null) ]] && green "安装acme.sh证书申请程序成功" || red "安装acme.sh证书申请程序失败" 
	bash /root/.acme.sh/acme.sh --upgrade --use-wget --auto-upgrade
}

checktls(){
	fail(){
		red "遗憾，域名证书申请失败"
		yellow "建议一：更换下二级域名名称再尝试执行脚本（重要）"
		green "例：原二级域名 x.ygkkk.eu.org 或 x.ygkkk.cf ，在cloudflare中重命名其中的x名称，确定并生效"
		echo
		yellow "建议二：更换下当前本地网络IP环境，再尝试执行脚本" && exit
	}

	if [[ -f /etc/x-ui/server.crt && -f /etc/x-ui/server.key ]] && [[ -s /etc/x-ui/server.crt && -s /etc/x-ui/server.key ]]; then
		sed -i '/--cron/d' /etc/crontab
		echo "0 0 * * * root bash /root/.acme.sh/acme.sh --cron -f >/dev/null 2>&1" >> /etc/crontab
		green "域名证书申请成功或已存在！域名证书（cert.crt）和密钥（private.key）已保存到 /etc/x-ui文件夹内" 
		yellow "公钥文件crt路径如下，可直接复制"
		green "/etc/x-ui/server.crt"
		yellow "密钥文件key路径如下，可直接复制"
		green "/etc/x-ui/server.key"
		echo $ym > /etc/x-ui/ca.log
		if [[ -f '/usr/local/bin/hysteria' ]]; then
			blue "检测到hysteria代理协议，此证书将自动应用"
		fi
		if [[ -f '/usr/bin/caddy' ]]; then
			blue "检测到naiveproxy代理协议，此证书将自动应用"
		fi
		if [[ -f '/usr/local/bin/tuic' ]]; then
			blue "检测到tuic代理协议，此证书将自动应用"
		fi
		if [[ -f '/usr/bin/x-ui' ]]; then
			blue "检测到x-ui（xray代理协议），此证书可在面版上手动填写应用"
		fi
		else
			fail
	fi
}

installCA(){
	rm -f /etc/x-ui/server.*
	bash ~/.acme.sh/acme.sh --install-cert -d ${ym} --key-file /etc/x-ui/server.key --fullchain-file /etc/x-ui/server.crt --ecc
}

checkacmeca(){
	nowca=`bash /root/.acme.sh/acme.sh --list | tail -1 | awk '{print $1}'`
	if [[ $nowca == $ym ]]; then
	red "经检测，输入的域名已有证书申请记录，不用重复申请"
	red "证书申请记录如下："
	bash /root/.acme.sh/acme.sh --list
	yellow "如果一定要重新申请，请先执行删除证书选项" && exit
	fi
}

ACMEstandaloneDNS(){
	echo 
	readp "请输入解析完成的域名:" ym
	green "已输入的域名:$ym" && sleep 1
	checkacmeca
	domainIP=$(curl -s ipget.net/?ip="$ym")
	wro
	if [[ $domainIP = $v4 ]]; then
	bash /root/.acme.sh/acme.sh  --issue -d ${ym} --standalone -k ec-256 --server letsencrypt --insecure
	fi
	if [[ $domainIP = $v6 ]]; then
	bash /root/.acme.sh/acme.sh  --issue -d ${ym} --standalone -k ec-256 --server letsencrypt --listen-v6 --insecure
	fi
	installCA
	checktls
}

ACMEDNS(){
	green "提示：泛域名申请前须要在解析平上设置一个名称为 * 字符的解析记录（输入格式：*.一级主域）"
	readp "请输入解析完成的域名:" ym
	green "已输入的域名:$ym" && sleep 1
	checkacmeca
	freenom=`echo $ym | awk -F '.' '{print $NF}'`
	if [[ $freenom =~ tk|ga|gq|ml|cf ]]; then
	red "经检测，你正在使用freenom免费域名解析，不支持当前DNS API模式，脚本退出" && exit 
	fi
	domainIP=$(curl -s ipget.net/?ip=$ym)
	if [[ -n $(echo $domainIP | grep nginx) && -n $(echo $ym | grep \*) ]]; then
	green "经检测，当前为泛域名证书申请，" && sleep 2
	abc=ygkkk.acme$(echo $ym | tr -d '*')
	domainIP=$(curl -s ipget.net/?ip=$abc)
	else
	green "经检测，当前为单域名证书申请，" && sleep 2
	fi
	wro
	echo
	ab="请选择托管域名解析服务商：\n1.Cloudflare\n2.腾讯云DNSPod\n3.阿里云Aliyun\n 请选择："
	readp "$ab" cd
	case "$cd" in 
	1 )
	readp "请复制Cloudflare的Global API Key：" GAK
	export CF_Key="$GAK"
	readp "请输入登录Cloudflare的注册邮箱地址：" CFemail
	export CF_Email="$CFemail"
	if [[ $domainIP = $v4 ]]; then
	bash /root/.acme.sh/acme.sh --issue --dns dns_cf -d ${ym} -k ec-256 --server letsencrypt --insecure
	fi
	if [[ $domainIP = $v6 ]]; then
	bash /root/.acme.sh/acme.sh --issue --dns dns_cf -d ${ym} -k ec-256 --server letsencrypt --listen-v6 --insecure
	fi
	;;
	2 )
	readp "请复制腾讯云DNSPod的DP_Id：" DPID
	export DP_Id="$DPID"
	readp "请复制腾讯云DNSPod的DP_Key：" DPKEY
	export DP_Key="$DPKEY"
	if [[ $domainIP = $v4 ]]; then
	bash /root/.acme.sh/acme.sh --issue --dns dns_dp -d ${ym} -k ec-256 --server letsencrypt --insecure
	fi
	if [[ $domainIP = $v6 ]]; then
	bash /root/.acme.sh/acme.sh --issue --dns dns_dp -d ${ym} -k ec-256 --server letsencrypt --listen-v6 --insecure
	fi
	;;
	3 )
	readp "请复制阿里云Aliyun的Ali_Key：" ALKEY
	export Ali_Key="$ALKEY"
	readp "请复制阿里云Aliyun的Ali_Secret：" ALSER
	export Ali_Secret="$ALSER"
	if [[ $domainIP = $v4 ]]; then
	bash /root/.acme.sh/acme.sh --issue --dns dns_ali -d ${ym} -k ec-256 --server letsencrypt --insecure
	fi
	if [[ $domainIP = $v6 ]]; then
	bash /root/.acme.sh/acme.sh --issue --dns dns_ali -d ${ym} -k ec-256 --server letsencrypt --listen-v6 --insecure
	fi
	esac
	installCA
	checktls
}

wro(){
	v4v6
	if [[ -n $(echo $domainIP | grep nginx) ]]; then
		yellow "当前域名解析到的IP：无"
		red "域名解析无效，请检查域名是否填写正确或稍等几分钟等待解析完成再执行脚本" && exit 
	elif [[ -n $(echo $domainIP | grep ":") || -n $(echo $domainIP | grep ".") ]]; then
		if [[ $domainIP != $v4 ]] && [[ $domainIP != $v6 ]]; then
			yellow "当前域名解析到的IP：$domainIP"
			red "当前域名解析的IP与当前VPS使用的IP不匹配"
			green "建议如下："
			yellow "1、请确保CDN小黄云关闭状态(仅限DNS)，其他域名解析网站设置同理"
			yellow "2、请检查域名解析网站设置的IP是否正确"
			exit 
			else
			green "恭喜，域名解析正确，当前域名解析到的IP：$domainIP"
		fi
	fi
}


#开始申请证书
acme(){
	clear
	yellow "稍等3秒，检测IP环境中"
	echo
	mkdir -p /etc/x-ui
	wgcfv6=$(curl -s6m6 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
	wgcfv4=$(curl -s4m6 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
	if [[ ! $wgcfv4 =~ on|plus && ! $wgcfv6 =~ on|plus ]]; then
	ab="1.选择独立80端口模式申请证书（仅需域名，小白推荐），安装过程中将强制释放80端口\n2.选择DNS API模式申请证书（需域名、ID、Key），自动识别单域名与泛域名\n0.返回上一层\n\n 请选择："
	readp "$ab" cd
	case "$cd" in 
		1 ) acme1 && acme2 && acme3 && ACMEstandaloneDNS;;
		2 ) acme1 && acme3 && ACMEDNS;;
		0 ) start_menu;;
	esac
	else
	yellow "检测到正在使用WARP接管VPS出站，现执行临时关闭"
	systemctl stop wg-quick@wgcf >/dev/null 2>&1
	green "WARP已临时闭关"
	ab="1.选择独立80端口模式申请证书（仅需域名，小白推荐），安装过程中将强制释放80端口\n2.选择DNS API模式申请证书（需域名、ID、Key），自动识别单域名与泛域名\n0.返回上一层\n\n 请选择："
	readp "$ab" cd
	case "$cd" in 
		1 ) acme1 && acme2 && acme3 && ACMEstandaloneDNS;;
		2 ) acme1 && acme3 && ACMEDNS;;
		0 ) start_menu;;
	esac
	yellow "现恢复原先WARP接管VPS出站设置，现执行WARP开启"
	systemctl start wg-quick@wgcf >/dev/null 2>&1
	green "WARP已恢复开启"
	fi
	}
	Certificate(){
	[[ -z $(/root/.acme.sh/acme.sh -v 2>/dev/null) ]] && yellow "未安装acme.sh证书申请，无法执行" && exit 
	green "Main_Domainc下显示的域名就是已申请成功的域名证书，Renew下显示对应域名证书的自动续期时间点"
	bash /root/.acme.sh/acme.sh --list
}

#检查证书
acmeshow(){
	if [[ -n $(/root/.acme.sh/acme.sh -v 2>/dev/null) ]]; then
	caacme1=`bash /root/.acme.sh/acme.sh --list | tail -1 | awk '{print $1}'`
	if [[ -n $caacme1 ]]; then
	caacme=$caacme1
	else
	caacme='无证书申请记录'
	fi
	else
	caacme='未安装acme'
	fi
}

#续期证书
acmerenew(){
	[[ -z $(/root/.acme.sh/acme.sh -v 2>/dev/null) ]] && yellow "未安装acme.sh证书申请，无法执行" && exit 
	green "以下显示的域名就是已申请成功的域名证书"
	bash /root/.acme.sh/acme.sh --list | tail -1 | awk '{print $1}'
	echo
	green "开始续期证书…………" && sleep 3
	bash /root/.acme.sh/acme.sh --cron -f
	checktls
}

#卸载证书
uninstall_crt(){
	[[ -z $(/root/.acme.sh/acme.sh -v 2>/dev/null) ]] && yellow "未安装acme.sh证书申请，无法执行" && exit 
	curl https://get.acme.sh | sh
	bash /root/.acme.sh/acme.sh --uninstall
	rm -f /etc/x-ui/server.*
	rm -rf ~/.acme.sh acme.sh
	sed -i '/--cron/d' /etc/crontab
	[[ -z $(/root/.acme.sh/acme.sh -v 2>/dev/null) ]] && green "acme.sh卸载完毕" || red "acme.sh卸载失败"
}

# 显示菜单
start_menu(){
	clear 
	yellow " 提示："
	yellow " 一、独立80端口模式仅支持单域名证书申请，在80端口不被占用的情况下支持自动续期，"
	yellow " 二、DNS API模式不支持freenom免费域名申请，支持单域名与泛域名证书申请，无条件自动续期"
	yellow " 三、泛域名申请前须要在解析平上设置一个名称为 * 字符的解析记录"
	echo
	red "========================================================================="
	acmeshow
	blue "当前已申请成功的证书（域名形式）："
	yellow "$caacme"
	echo
	red "========================================================================="
	green " 1. acme.sh申请letsencrypt ECC证书（支持独立模式与DNS API模式） "
	green " 2. 查询已申请成功的域名及自动续期时间点 "
	green " 3. 手动一键证书续期 "
	green " 4. 删除证书并卸载一键ACME证书申请脚本 "
	green " 0. 退出 "
	echo
	read -p "请输入数字:" NumberInput
	echo
	case "$NumberInput" in     
		1 ) acme && re_ufw;;
		2 ) Certificate;;
		3 ) acmerenew;;
		4 ) uninstall_crt;;
		* ) exit      
	esac
}


#伪装网站
SITES=(
	https://www.linuxmint.com/
	https://mirrors.edge.kernel.org/linuxmint/
	https://muug.ca/mirror/linuxmint/iso/
	https://mirror.csclub.uwaterloo.ca/linuxmint/
	https://mirrors.advancedhosters.com/linuxmint/isos/
	https://mirror.clarkson.edu/linuxmint/iso/images/
	https://mirror.ette.biz/linuxmint/
	https://mirrors.gigenet.com/linuxmint/iso/
	http://mirrors.seas.harvard.edu/linuxmint/
	https://mirror.cs.jmu.edu/pub/linuxmint/images/
	https://mirrors.kernel.org/linuxmint/
	http://linuxfreedom.com/linuxmint/linuxmint.com/
	http://mirror.metrocast.net/linuxmint/
	https://plug-mirror.rcac.purdue.edu/mint-images/
	https://mirrors.sonic.net/mint/isos/
	http://mirror.team-cymru.com/mint/
	https://mirror.pit.teraswitch.com/linuxmint-iso/
	http://mirrors.usinternet.com/mint/images/linuxmint.com/
	https://mirrors.xmission.com/linuxmint/iso/
	https://mirrors.netix.net/LinuxMint/linuxmint-iso/
	https://mirror.telepoint.bg/mint/
	https://mirrors.uni-ruse.bg/linuxmint/iso/
	https://mirrors.nic.cz/linuxmint-cd/
	http://mirror.it4i.cz/mint/isos/
	https://mirror.karneval.cz/pub/linux/linuxmint/iso/
	https://mirror-prg.webglobe.com/linuxmint-cd/linuxmint.com/
	https://mirrors.dotsrc.org/linuxmint-cd/
	http://ftp.klid.dk/ftp/linuxmint/
	https://mirror.crexio.com/linuxmint/isos/
	http://ftp.crifo.org/mint-cd/
	http://linux.darkpenguin.net/distros/mint/
	https://mirror.dogado.de/linuxmint-cd/
	https://mirror.bauhuette.fh-aachen.de/linuxmint-cd/
	https://ftp.fau.de/mint/iso/
	http://mirror.funkfreundelandshut.de/linuxmint/isos/
	https://ftp5.gwdg.de/pub/linux/debian/mint/
	https://ftp-stud.hs-esslingen.de/pub/Mirrors/linuxmint.com/
	https://mirror.as20647.net/linuxmint-iso/
	https://mirror.netcologne.de/linuxmint/iso/
	https://mirror.netzwerge.de/linuxmint/iso/
	https://mirror.pyratelan.org/mint-iso/
	https://ftp.rz.uni-frankfurt.de/pub/mirrors/linux-mint/iso/
	https://mirror.wtnet.de/linuxmint-cd/
	https://repo.greeklug.gr/data/pub/linux/mint/iso/
	http://ftp.otenet.gr/linux/linuxmint/
	http://mirrors.myaegean.gr/linux/linuxmint/
	http://ftp.ntua.gr/pub/linux/linuxmint/
	https://ftp.cc.uoc.gr/mirrors/linux/linuxmint/
	http://mirror.greennet.gl/linuxmint/iso/linuxmint.com/
	https://quantum-mirror.hu/mirrors/linuxmint/iso/
	https://ftp.heanet.ie/pub/linuxmint.com/
	https://mirror.ihost.md/linuxmint/
	https://mirror.koddos.net/linuxmint/packages/
	https://www.debian.org/
	http://ftp.at.debian.org/debian/
	http://debian.anexia.at/debian/
	http://debian.lagis.at/debian/
	http://debian.mur.at/debian/
	http://debian.sil.at/debian/
	http://mirror.alwyzon.net/debian/
	http://ftp.dk.debian.org/debian/
	http://mirror.one.com/debian/
	http://mirrors.dotsrc.org/debian/
	http://ftp2.de.debian.org/debian/
	http://ftp.de.debian.org/debian/
	http://debian.mirror.lrz.de/debian/
	http://debian.netcologne.de/debian/
	http://ftp.gwdg.de/debian/
	http://ftp.halifax.rwth-aachen.de/debian/
	http://ftp.uni-kl.de/debian/
	http://ftp.uni-stuttgart.de/debian/
	http://ftp.is.debian.org/debian/
	http://debian.telecoms.bg/debian/
	http://ftp.uni-sofia.bg/debian/
	http://mirror.telepoint.bg/debian/
	http://ftp.tw.debian.org/debian/
	http://debian.cs.nctu.edu.tw/debian/
	http://opensource.nchc.org.tw/debian/
	http://ftp.hu.debian.org/debian/
	http://ftp.fsn.hu/debian/
	http://ftp.jp.debian.org/debian/
	http://debian-mirror.sakura.ne.jp/debian/
	http://dennou-k.gfd-dennou.org/debian/
	http://dennou-q.gfd-dennou.org/debian/
	http://ftp.jaist.ac.jp/debian/
	http://ftp.nara.wide.ad.jp/debian/
	http://ftp.yz.yamagata-u.ac.jp/debian/
	http://mirrors.xtom.jp/debian/
	http://ftp.pl.debian.org/debian/
	http://ftp.agh.edu.pl/debian/
	http://ftp.task.gda.pl/debian/
	http://debian.gnu.gen.tr/debian/
	http://ftp.agh.edu.pl/debian/
	http://ftp.task.gda.pl/debian/
	http://ftp.fr.debian.org/debian/
	http://debian.proxad.net/debian/
	http://debian.univ-tlse2.fr/debian/
	http://deb-mir1.naitways.net/debian/
	http://mirror.johnnybegood.fr/debian/
	http://ftp.it.debian.org/debian/
	http://ftp.linux.it/debian/
	http://mirror.coganng.com/debian/
	http://mirror.soonkeat.sg/debian/
	http://giano.com.dist.unige.it/debian/
	http://ftp.cz.debian.org/debian/
	http://ftp.debian.cz/debian/
	http://debian.mirror.web4u.cz/
	http://mirror.dkm.cz/debian/
	http://ftp.be.debian.org/debian/
	http://mirror.as35701.net/debian/
	http://ftp.ee.debian.org/debian/
	http://ftp.eenet.ee/debian/
	http://ftp.sk.debian.org/debian/
	http://ftp.debian.sk/debian/
	http://ftp.si.debian.org/debian/
	http://ftp.md.debian.org/debian/
	http://mirror.as43289.net/debian/
	http://ftp.nz.debian.org/debian/
	http://linux.purple-cat.net/debian/
	http://mirror.fsmg.org.nz/debian/
	http://debian.koyanet.lv/debian/
	http://ftp.us.debian.org/debian/
	http://debian-archive.trafficmanager.net/debian/
	http://debian.gtisc.gatech.edu/debian/
	http://debian.osuosl.org/debian/
	http://debian.uchicago.edu/debian/
	http://mirrors.edge.kernel.org/debian/
	http://mirrors.vcea.wsu.edu/debian/
	http://mirrors.wikimedia.org/debian/
	http://mirror.us.oneandone.net/debian/
	http://mirror.flokinet.net/debian/
	http://mirrors.nxthost.com/debian/
	http://mirror1.infomaniak.com/debian/
	http://mirror2.infomaniak.com/debian/
	http://mirror.init7.net/debian/
	http://mirror.iway.ch/debian/
	http://mirror.sinavps.ch/debian/
	http://pkg.adfinis-sygroup.ch/debian/
	http://debian.mirror.root.lu/debian/
	http://ftp.au.debian.org/debian/
	http://debian.mirror.digitalpacific.com.au/debian/
	http://mirror.linux.org.au/debian/
	http://ftp.es.debian.org/debian/
	http://ftp.cica.es/debian/
	http://softlibre.unizar.es/debian/
	http://ulises.hostalia.com/debian/
	http://ftp.uk.debian.org/debian/
	http://debian.mirrors.uk2.net/debian/
	http://free.hands.com/debian/
	http://mirror.lchost.net/debian/
	http://mirror.positive-internet.com/debian/
	http://mirrors.coreix.net/debian/
	http://ftp.nl.debian.org/debian/
	http://debian.snt.utwente.nl/debian/
	http://mirror.i3d.net/debian/
	http://mirror.nl.datapacket.com/debian/
	http://ftp.pt.debian.org/debian/
	http://debian.uevora.pt/debian/
	http://mirrors.up.pt/debian/
	https://ubuntu.com/
	https://www.opensuse.org/
	https://getfedora.org/
	https://www.centos.org/
	https://archlinux.org/
	https://puppylinux.com/
	https://www.freebsd.org/
	https://www.gentoo.org/
	https://www.oracle.com/linux/
	https://www.redhat.com/en/technologies/cloud-computing/openshift/
	https://www.redhat.com/
	https://www.openbsd.org/
	https://www.linuxliteos.com/
	https://www.clearos.com/
	https://www.virtualbox.org/
	https://ftp.nluug.nl/os/Linux/distr/linuxmint/packages/
	https://ftp.icm.edu.pl/pub/Linux/dist/linuxmint/packages/
	https://mirror.fccn.pt/repos/pub/linuxmint_packages/
	https://mirrors.ptisp.pt/linuxmint/
	https://ftp.rnl.tecnico.ulisboa.pt/pub/linuxmint-packages/
	https://mirrors.up.pt/linuxmint-packages/
	http://mint.mirrors.telekom.ro/repos/
	http://mirrors.powernet.com.ru/mint/packages/
	https://mirror.truenetwork.ru/linuxmint-packages/
	http://mirror.pmf.kg.ac.rs/mint/packages.linuxmint.com/
	http://ftp.energotel.sk/pub/linux/linuxmint-packages/
	https://tux.rainside.sk/mint/packages/
	https://mirror.airenetworks.es/linuxmint/packages/
	https://ftp.cixug.es/mint/packages/
	https://ftp.acc.umu.se/mirror/linuxmint.com/packages/
	https://mirrors.c0urier.net/linux/linuxmint/packages/
	https://mirror.linux.pizza/linuxmint/
	https://mirror.zetup.net/linuxmint/packages/
	https://mirror.init7.net/linuxmint/
	https://mirror.turhost.com/linuxmint/repo/
	https://mirror.verinomi.com/linuxmint/packages/
	https://mirrors.ukfast.co.uk/sites/linuxmint.com/packages/
	https://www.mirrorservice.org/sites/packages.linuxmint.com/packages/
	http://ftp.jaist.ac.jp/pub/Linux/linuxmint/packages/
	http://mirror.rise.ph/linuxmint/
	https://mirror.0x.sg/linuxmint/
	https://download.nus.edu.sg/mirror/linuxmint/
	https://ftp.harukasan.org/linuxmint/
	https://ftp.kaist.ac.kr/linuxmint/
	http://free.nchc.org.tw/linuxmint/packages/
	http://ftp.tku.edu.tw/Linux/LinuxMint/linuxmint/
	http://mirror1.ku.ac.th/linuxmint-packages/
	https://mirror.kku.ac.th/linuxmint-packages/
	http://mirror.dc.uz/linuxmint/
	https://mirror.aarnet.edu.au/pub/linuxmint-packages/
	http://mirror.internode.on.net/pub/linuxmint-packages/
	http://ucmirror.canterbury.ac.nz/linux/mint/packages/
	http://mirror.xnet.co.nz/pub/linuxmint/packages/
	https://mint.zero.com.ar/mintpackages/
	http://mint-packages.c3sl.ufpr.br/
	http://mirror.ufscar.br/mint-archive/
	https://mint.itsbrasil.net/packages/
)

#随机选择一个useragent
RandomUserAgent() {
	while true
	do
		UA=`echo "\
		Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/92.0.4515.131 Safari/537.36
		Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/92.0.4515.107 Safari/537.36
		Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:90.0) Gecko/20100101 Firefox/90.0
		Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36
		Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.164 Safari/537.36
		Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/92.0.4515.107 Safari/537.36
		Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/92.0.4515.131 Safari/537.36
		Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.1.1 Safari/605.1.15
		Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.114 Safari/537.36
		Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.1.2 Safari/605.1.15"`
		UserAgent=`echo "$UA"|sed -n ''$(($RANDOM%$(echo "$UA"|wc -l)+1))'p'`
		[ ! -z $"{UserAgent}" ] && break
	done
}

#输出提示信息的函数
colorEcho() {
	echo -e "\n${1}${@:2}${PLAIN}\n"
}

configNeedNginx() {
	which nginx &>/dev/null
	[[ "$?" != "0" ]] && echo no && return
	echo yes
}

needNginx() {
	which nginx &>/dev/null
	[[ "$?" != "0" ]] && echo no && return
	echo yes
}

CONFIG_FILE="/etc/xray/config"
OS=$(hostnamectl | grep -i system | cut -d: -f2)

#检测warp工具是否启动
checkwarp(){
	[[ -n $(wg 2>/dev/null) ]] && colorEcho $RED " 检测到WARP已打开，脚本中断运行" && colorEcho $YELLOW " 请关闭WARP之后再运行本脚本" && exit 1
}

#得到ip地址
get_ip() {
	V6_PROXY=""
	IP=$(curl -s4m8 https://ip.gs)
	[[ "$?" != "0" ]] && IP=$(curl -s6m8 https://ip.gs) && V6_PROXY="true"
	[[ $V6_PROXY != "" ]] && echo -e nameserver 2a01:4f8:c2c:123f::1 > /etc/resolv.conf
}

BT="false"
NGINX_CONF_PATH="/etc/nginx/conf.d/"
# res=$(which bt 2>/dev/null)
# [[ "$res" != "" ]] && BT="true" && NGINX_CONF_PATH="/www/server/panel/vhost/nginx/"

VLESS="false"
TROJAN="false"
TLS="false"
WS="false"
XTLS="false"
KCP="false"

#开启nginx
startNginx() {
	if [[ "$BT" == "false" ]]; then
		systemctl start nginx
	else
		nginx -c /www/server/nginx/conf/nginx.conf
	fi
}

#停止nginx
stopNginx() {
	if [[ "$BT" == "false" ]]; then
		systemctl stop nginx
	else
		res=$(ps aux | grep -i nginx)
		if [[ "$res" != "" ]]; then
			nginx -s stop
		fi
	fi
}

#启动nginx和xray服务
start() {
	res=$(status)
	if [[ $res -lt 2 ]]; then
		colorEcho $RED " Xray未安装，请先安装！"
		return
	fi
	systemctl daemon-reload
	stopNginx
	startNginx
	systemctl restart xray
	sleep 2
	res=$(systemctl status xray | grep Error)
	if [[ "$res" != "" ]]; then
		colorEcho $RED " Xray启动失败，请检查日志或查看端口是否被占用！"
		error_info="${error_info}\nXray启动失败，请检查日志或查看端口是否被占用"
	else
		colorEcho $BLUE " Xray启动成功"
	fi
}

#停止nginx和xray
stop() {
	stopNginx
	systemctl stop xray
	colorEcho $BLUE " Xray停止成功"
}

#获取xray的状态
status() {
	[[ ! -f /usr/local/bin/xray ]] && echo 0 && return
	res=$(systemctl status xray | grep Error)
	[[ -z "$res" ]] && echo 3 && return

	if [[ $(configNeedNginx) != "yes" ]]; then
		echo 3
	else
		res=$(ss -nutlp | grep -i nginx)
		if [[ -z "$res" ]]; then
			echo 4
		else
			echo 5
		fi
	fi
}

#重启nginx和xray
restart() {
	res=$(status)
	if [[ $res -lt 2 ]]; then
		colorEcho $RED " Xray未安装，请先安装！"
		return
	fi
	stop
	start
}

#检测系统类型和系统默认管理工具
checkSystem() {
	result=$(id | awk '{print $1}')
	[[ $EUID -ne 0 ]] && colorEcho $RED " 请以root身份执行该脚本" && exit 1

	res=$(which yum 2>/dev/null)
	if [[ "$?" != "0" ]]; then
		res=$(which apt 2>/dev/null)
		if [[ "$?" != "0" ]]; then
			colorEcho $RED " 不受支持的Linux系统"
			exit 1
		fi
		PMT="apt"
		CMD_INSTALL="apt install -y "
		CMD_REMOVE="apt remove -y "
		CMD_UPGRADE="apt update; apt upgrade -y; apt autoremove -y"
	else
		PMT="yum"
		CMD_INSTALL="yum install -y "
		CMD_REMOVE="yum remove -y "
		CMD_UPGRADE="yum update -y"
	fi
	res=$(which systemctl 2>/dev/null)
	if [[ "$?" != "0" ]]; then
		colorEcho $RED " 系统版本过低，请升级到最新版本"
		exit 1
	fi
}

#检测证书是否存在
check_ssl_t() {

	test ! -e ./ssl && echo -e " ${red}没有找到存放域名证书的目录，请手动创建ssl目录，把域名相关的证书放到ssl目录中。${none} " && exit

	if [[ ! -f ./ssl/${DOMAIN}.crt ]];then
		echo -e "\n${red}没有找到${DOMAIN}.crt 证书，请手动到cf账户创建，然后放到ssl目录中。${none}\n"
		exit
	else
		if [ "$(cat ./ssl/${DOMAIN}.crt | sed -n '/--END /p;/--BEGIN /p' | wc -l )" != "2" ];then
			echo -e "\n${red} ${DOMAIN}.crt 证书内容不完整，请重新到cf账户创建，然后放到ssl目录中。${none}\n"
			exit			
		fi
	fi

	if [ ! -f ./ssl/${DOMAIN}.key ];then
		echo -e "\n${red}没有找到${DOMAIN}.key 证书，请手动到cf账户创建，然后放到ssl目录中。${none}\n"
		exit
	else
		if [ "$(cat ./ssl/${DOMAIN}.key | sed -n '/--END /p;/--BEGIN /p' | wc -l )" != "2" ];then
			echo -e "\n${red} ${DOMAIN}.key 证书内容不完整，请重新到cf账户创建，然后放到ssl目录中。${none}\n"
			exit			
		fi
	fi

}

#判断是否选择websocks协议
needNginx() {
	[[ "$WS" == "false" ]] && echo no && return
	echo yes
}

#获取let免费证书
getCert() {
	mkdir -p /etc/nginx/ssl
	stopNginx
	systemctl stop xray
	if command -v caddy &>/dev/null;then
		systemctl stop caddy
	fi
	res=$(netstat -ntlp | grep -E ':80 |:443 ')
	if [[ "${res}" != "" ]]; then
		colorEcho ${RED} " 其他进程占用了80或443端口，请先关闭再运行一键脚本"
		echo " 端口占用信息如下："
		echo ${res}
		exit 1
	fi
	$CMD_INSTALL socat openssl
	if [[ "$PMT" == "yum" ]]; then
		$CMD_INSTALL cronie
		systemctl start crond
		systemctl enable crond
	else
		$CMD_INSTALL cron
		systemctl start cron
		systemctl enable cron
	fi
	curl -sL https://get.acme.sh | sh -s email=hijk.pw@protonmail.sh
	source ~/.bashrc
	~/.acme.sh/acme.sh --upgrade --auto-upgrade
	~/.acme.sh/acme.sh --set-default-ca --server letsencrypt
	if [[ "$BT" == "false" ]]; then
		if [ -n $V6_PROXY ]; then
			~/.acme.sh/acme.sh --issue -d $DOMAIN --keylength ec-256 --pre-hook "systemctl stop nginx" --post-hook "systemctl restart nginx" --standalone --listen-v6
		else
			~/.acme.sh/acme.sh --issue -d $DOMAIN --keylength ec-256 --pre-hook "systemctl stop nginx" --post-hook "systemctl restart nginx" --standalone
		fi
	else
		~/.acme.sh/acme.sh --issue -d $DOMAIN --keylength ec-256 --pre-hook "nginx -s stop || { echo -n ''; }" --post-hook "nginx -c /www/server/nginx/conf/nginx.conf || { echo -n ''; }" --standalone
	fi
	[[ -f ~/.acme.sh/${DOMAIN}_ecc/ca.cer ]] || {
		colorEcho $RED " 获取证书失败，请截图到TG群反馈"
		exit 1
	}
	CERT_FILE="/etc/nginx/ssl/${DOMAIN}.pem"
	KEY_FILE="/etc/nginx/ssl/${DOMAIN}.key"
	~/.acme.sh/acme.sh --install-cert -d $DOMAIN --ecc \
	--key-file $KEY_FILE \
	--fullchain-file $CERT_FILE \
	--reloadcmd "service nginx force-reload"
	[[ -f $CERT_FILE && -f $KEY_FILE ]] || {
		colorEcho $RED " 获取证书失败，请截图到TG群反馈"
		exit 1
	}
	if command -v caddy &>/dev/null;then
		systemctl restart caddy
	fi
}

#配置nginx文件
configNginx() {
	mkdir -p /usr/share/nginx/html
	if [[ "$ALLOW_SPIDER" == "n" ]]; then
		echo 'User-Agent: *' >/usr/share/nginx/html/robots.txt
		echo 'Disallow: /' >>/usr/share/nginx/html/robots.txt
		ROBOT_CONFIG="    location = /robots.txt {}"
	else
		ROBOT_CONFIG=""
	fi

	if [[ "$BT" == "false" ]]; then
		if [[ ! -f /etc/nginx/nginx.conf.bak ]]; then
			mv /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak
		fi
		res=$(id nginx 2>/dev/null)
		if [[ "$?" != "0" ]]; then
			user="www-data"
		else
			user="nginx"
		fi
		cat >/etc/nginx/nginx.conf <<-EOF
			user $user;
			worker_processes auto;
			#error_log /var/log/nginx/error.log;
			pid /run/nginx.pid;
			
			# Load dynamic modules. See /usr/share/doc/nginx/README.dynamic.
			include /usr/share/nginx/modules/*.conf;
			
			events {
			    worker_connections 1024;
			}
			
			http {
			    log_format  main  '\$remote_addr - \$remote_user [\$time_local] "\$request" '
			                      '\$status \$body_bytes_sent "\$http_referer" '
			                      '"\$http_user_agent" "\$http_x_forwarded_for"';
			
			    access_log  /var/log/nginx/access.log  main;
			    server_tokens off;
			
			    sendfile            on;
			    tcp_nopush          on;
			    tcp_nodelay         on;
			    keepalive_timeout   65;
			    types_hash_max_size 2048;
			    gzip                on;
			
			    include             /etc/nginx/mime.types;
			    default_type        application/octet-stream;
			
			    # Load modular configuration files from the /etc/nginx/conf.d directory.
			    # See http://nginx.org/en/docs/ngx_core_module.html#include
			    # for more information.
			    include /etc/nginx/conf.d/*.conf;
			}
		EOF
	fi

	#判断伪装网址是否为空
	if [[ "$PROXY_URL" == "" ]]; then
		action=""
	else
		action="proxy_ssl_server_name on;
        proxy_pass $PROXY_URL;
        proxy_set_header Accept-Encoding '';
        sub_filter \"$REMOTE_HOST\" \"$DOMAIN\";
        sub_filter_once off;"
		URLPath="/usr/share/nginx/html"
	fi

	if [[ "$TLS" == "true" || "$XTLS" == "true" ]]; then
		mkdir -p ${NGINX_CONF_PATH}
		# VMESS+WS+TLS
		# VLESS+WS+TLS
		#配置Nginx
		if [[ "$WS" == "true" ]]; then
			test ! -e /etc/nginx/ssl && mkdir -p /etc/nginx/ssl
			if [ "${account_class}" == "n" ];then
				if [[ -f ./ssl/${DOMAIN}.crt && -f ./ssl/${DOMAIN}.key ]];then
					cp -rf ./ssl/${DOMAIN}* /etc/nginx/ssl
				else
					echo -e "\n${red}没有找到${DOMAIN} 证书，请手动到cf账户创建，然后放到ssl目录中。${none}\n"
					exit
				fi
				if [[ -f /etc/nginx/ssl/${DOMAIN}.crt && -f /etc/nginx/ssl/${DOMAIN}.key ]];then
					echo -e "${yellow}${DOMAIN}证书导入成功。${none}"
				else
					echo -e "\n${red}${DOMAIN} 证书没有导入成功，请手动复制证书到/etc/nginx/ssl目录中。${none}\n"
					error_info="${error_info}\n${DOMAIN} 证书没有导入成功，请手动复制证书到/etc/nginx/ssl目录中。"
					sleep 3
				fi
				CERT_FILE="/etc/nginx/ssl/${DOMAIN}.crt"
				KEY_FILE="/etc/nginx/ssl/${DOMAIN}.key"
			fi
			cat >${NGINX_CONF_PATH}${DOMAIN}.conf <<-EOF
				server {
				    listen 880;
				    listen [::]:880;
				    server_name ${DOMAIN};
				    return 301 https://\$server_name:${PORT}\$request_uri;
				}
				
				server {
				    listen       ${PORT} ssl http2;
				    listen       [::]:${PORT} ssl http2;
				    server_name ${DOMAIN};
				    charset utf-8;
				
				    # ssl配置
				    ssl_protocols TLSv1.1 TLSv1.2;
				    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE:ECDH:AES:HIGH:!NULL:!aNULL:!MD5:!ADH:!RC4;
				    ssl_ecdh_curve secp384r1;
				    ssl_prefer_server_ciphers on;
				    ssl_session_cache shared:SSL:10m;
				    ssl_session_timeout 10m;
				    ssl_session_tickets off;
				    ssl_certificate $CERT_FILE;
				    ssl_certificate_key $KEY_FILE;
				
				    root ${URLPath};
				    location / {
				        $action
				    }
				    $ROBOT_CONFIG
				
				    location ${WSPATH} {
				      proxy_redirect off;
				      proxy_pass http://127.0.0.1:${XPORT};
				      proxy_http_version 1.1;
				      proxy_set_header Upgrade \$http_upgrade;
				      proxy_set_header Connection "upgrade";
				      proxy_set_header Host \$host;
				      proxy_set_header X-Real-IP \$remote_addr;
				      proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
				    }
				}
			EOF
		else
			# VLESS+TCP+TLS
			# VLESS+TCP+XTLS
			# trojan
			cat >${NGINX_CONF_PATH}${DOMAIN}.conf <<-EOF
				server {
				    listen 80;
				    listen [::]:80;
				    listen 81 http2;
				    server_name ${DOMAIN};
				    root /usr/share/nginx/html;
				    location / {
				        $action
				    }
				    $ROBOT_CONFIG
				}
			EOF
		fi
	fi
}

#获取当前系统版本
version="$(grep '^ID=' /etc/os-release | cut -d '=' -f 2 | sed 's/"//g')"

#iptables防火墙放行
Set_Iptables() {
	if [[ -n ${iptables_path} ]];then
		#检测v2ray或者xray的端口是否是已经放行，如果是的话就不用再放行了。
		if [[ ! -z ${PORT} && -z "$(egrep "\<${PORT}\>" ${iptables_path})" ]];then
			rules_num="$(iptables -nL --line-number | awk '/\<DROP       all\>/ {print int($1)}'| sed -n 1p)"
			[ -n "${rules_num}" ] && iptables -D INPUT ${rules_num} || { PrintFalseInfo "没有获取到禁用入站的规则，请稍后再尝试";exit; }
			iptables -A INPUT -p tcp --dport ${PORT} -j ACCEPT;iptables -A INPUT -j DROP
			if [ "${version}" == "centos" ];then
				#保存iptables添加的规则
				iptables-save >/etc/sysconfig/iptables; ip6tables-save >/etc/sysconfig/ip6tables
				RestartServer iptables; [ $? != 0 ] && Error "iptables防火墙服务没有启动成功，请稍后重新尝试" && exit
			else
				#保存iptables添加的规则
				iptables-save >${iptables_path}; ip6tables-save >${iptables_path%.*}.v6
				#检查iptables规则是否保存上了
				if [[ -f ${iptables_path} && -f ${iptables_path%.*}.v6  ]];then
					PrintTrueInfo "设置iptables防火墙规则成功"
				else
					Error "设置iptables防火墙规则失败，请重新尝试"; exit       
				fi
			fi
			if [[ -f ${iptables_path} && -n "$(egrep "\<${PORT}\>" ${iptables_path})" ]];then
				PrintTrueInfo "nginx 端口 ${PORT} 放行成功"
			else
				PrintFalseInfo "nginx 端口 ${PORT} 没有放行成功，请稍后再尝试 ";exit
			fi
		fi
	fi
}

#ufw防火墙禁用ping入
Input_Ping_Off() {
    sed -i "s/-A ufw-before-input -p icmp --icmp-type destination-unreachable -j ACCEPT/-A ufw-before-input -p icmp --icmp-type destination-unreachable -j DROP/" /etc/ufw/before.rules 2>&1
    sed -i "s/-A ufw-before-input -p icmp --icmp-type source-quench -j ACCEPT/-A ufw-before-input -p icmp --icmp-type source-quench -j DROP/" /etc/ufw/before.rules 2>&1
    sed -i "s/-A ufw-before-input -p icmp --icmp-type time-exceeded -j ACCEPT/-A ufw-before-input -p icmp --icmp-type time-exceeded -j DROP/" /etc/ufw/before.rules 2>&1
    sed -i "s/-A ufw-before-input -p icmp --icmp-type parameter-problem -j ACCEPT/-A ufw-before-input -p icmp --icmp-type parameter-problem -j DROP/" /etc/ufw/before.rules 2>&1
    sed -i "s/-A ufw-before-input -p icmp --icmp-type echo-request -j ACCEPT/-A ufw-before-input -p icmp --icmp-type echo-request -j DROP/" /etc/ufw/before.rules 2>&1

    sed -i "s/-A ufw6-before-input -p icmpv6 --icmpv6-type destination-unreachable -j ACCEPT/-A ufw6-before-input -p icmpv6 --icmpv6-type destination-unreachable -j DROP/" /etc/ufw/before6.rules 2>&1
    sed -i "s/-A ufw6-before-input -p icmpv6 --icmpv6-type packet-too-big -j ACCEPT/-A ufw6-before-input -p icmpv6 --icmpv6-type packet-too-big -j DROP/" /etc/ufw/before6.rules 2>&1
    sed -i "s/-A ufw6-before-input -p icmpv6 --icmpv6-type time-exceeded -j ACCEPT/-A ufw6-before-input -p icmpv6 --icmpv6-type time-exceeded -j DROP/" /etc/ufw/before6.rules 2>&1
    sed -i "s/-A ufw6-before-input -p icmpv6 --icmpv6-type parameter-problem -j ACCEPT/-A ufw6-before-input -p icmpv6 --icmpv6-type parameter-problem -j DROP/" /etc/ufw/before6.rules 2>&1
    sed -i "s/-A ufw6-before-input -p icmpv6 --icmpv6-type echo-request -j ACCEPT/-A ufw6-before-input -p icmpv6 --icmpv6-type echo-request -j DROP/" /etc/ufw/before6.rules 2>&1
    sed -i "s/-A ufw6-before-input -p icmpv6 --icmpv6-type echo-reply -j ACCEPT/-A ufw6-before-input -p icmpv6 --icmpv6-type echo-reply -j DROP/" /etc/ufw/before6.rules 2>&1
    sed -i "s/-A ufw6-before-input -p icmpv6 --icmpv6-type router-solicitation -m hl --hl-eq 255 -j ACCEPT/-A ufw6-before-input -p icmpv6 --icmpv6-type router-solicitation -m hl --hl-eq 255 -j DROP/" /etc/ufw/before6.rules 2>&1
    sed -i "s/-A ufw6-before-input -p icmpv6 --icmpv6-type router-advertisement -m hl --hl-eq 255 -j ACCEPT/-A ufw6-before-input -p icmpv6 --icmpv6-type router-advertisement -m hl --hl-eq 255 -j DROP/" /etc/ufw/before6.rules 2>&1
    sed -i "s/-A ufw6-before-input -p icmpv6 --icmpv6-type neighbor-solicitation -m hl --hl-eq 255 -j ACCEPT/-A ufw6-before-input -p icmpv6 --icmpv6-type neighbor-solicitation -m hl --hl-eq 255 -j DROP/" /etc/ufw/before6.rules 2>&1
    sed -i "s/-A ufw6-before-input -p icmpv6 --icmpv6-type neighbor-advertisement -m hl --hl-eq 255 -j ACCEPT/-A ufw6-before-input -p icmpv6 --icmpv6-type neighbor-advertisement -m hl --hl-eq 255 -j DROP/" /etc/ufw/before6.rules 2>&1
}

# 设置ufw防火墙
Ufw_Firewall() {
	if ! command -v ufw &>/dev/null;then	# 检查ufw防火墙软件是否安装，没有安装则进行安装
		${CMD_INSTALL} ufw; sleep 1	# 安装ufw防火墙并停顿一秒
		if ! command -v ufw &>/dev/null;then
			Error "安装ufw防火墙软件失败，稍后重新尝试一下，或者安装ufw试试" ; return 1 
		fi
	fi

	# 允许访问22端口，以下几条相同，分别是22,80,443,3389,8443端口的访问
    for i in {22,3389,8443,443,80};do ufw allow in $i/tcp; done
    [[ -n ${PORT} && ! ${PORT} =~ 22|3389|8443|443|80 ]] && ufw allow in ${PORT}/tcp    # 判断是否是已经放行的端口，没有放行则进行放行
	#检测端口是否为22，22端口已经放行就不需要再次放行
	[ "${login_port}" != "22" ] && ufw allow in ${login_port}/tcp
	Input_Ping_Off		# 禁用ping入
    ufw default deny incoming	# 默认禁用所有的入站
	ufw default allow outgoing	# 默认允许所有的出站
    echo y | ufw enable		# 启动ufw防火墙
    systemctl restart ufw; systemctl enable ufw; ufw reload  	# 重新加载并重新启动ufw防火墙
    if [ -n "$(ufw status | egrep '\<active\>')" ];then
        PrintTrueInfo "ufw 防火墙启动成功"
    else
        Error "ufw 防火墙启动失败，请重新尝试"; return 1
    fi
}

# 设置iptables防火墙
Iptables_Firewall() {
	if ! command -v iptables &>/dev/null;then	# 检查iptables防火墙软件是否安装，没有安装则进行安装
		${CMD_INSTALL} iptables; sleep 1	# 安装iptables防火墙并停顿一秒
		if ! command -v iptables &>/dev/null;then
			Error "安装iptables防火墙软件失败，稍后重新尝试一下，或者安装ufw试试" ; return 1 
		fi
	fi

    #检测系统是否启动firewalld防火墙
	if [[ ! -z $(systemctl list-units | grep firewalld) ]];then
		systemctl stop firewalld
		systemctl disable firewalld
		if [[ ! -z $(systemctl list-units | grep firewalld) ]];then
			read -sp "$(echo -e "${red}firewalld防火墙没有禁用成功！${none}")"; exit
		else
			PrintTrueInfo "禁用firewalld防火墙成功"
		fi
	fi

	#检测系统是否启动ufw防火墙
	if [[ ! -z $(systemctl list-units | grep ufw) ]];then
		systemctl stop ufw
		systemctl disable ufw
		if [[ ! -z $(systemctl list-units | grep ufw) ]];then
			read -sp "$(echo -e "${red}ufw防火墙没有禁用成功！${none}")"; exit
		else    
			PrintTrueInfo "禁用ufw防火墙成功"
		fi
	fi

	# 清除已有iptables规则
	iptables -F
	iptables -X
	
	# 允许本地回环接口(即运行本机访问本机)
	iptables -A INPUT -i lo -j ACCEPT

	# 允许已建立的或相关连的通行
	iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

	#允许所有本机向外的访问
	iptables -A OUTPUT -j ACCEPT

	# 允许访问22端口，以下几条相同，分别是22,80,443,3389,8443端口的访问
	for i in {22,3389,8443,443,80};do iptables -A INPUT -p tcp --dport $i -j ACCEPT; done

	#检测端口是否为22，22端口已经放行就不需要再次放行
	[ "${login_port}" != "22" ] && iptables -A INPUT -p tcp --dport ${login_port} -j ACCEPT
    [[ -n ${PORT} && ! ${PORT} =~ 22|3389|8443|443|80 ]] &&  iptables -A INPUT -p tcp --dport ${PORT} -j ACCEPT    # 判断是否是已经放行的端口，没有放行则进行放行
	#禁用ping
	iptables -A INPUT -p icmp -m icmp --icmp-type 8 -j DROP

	#防止DoS攻击。允许最多每分钟25个连接，当达到100个连接后，才启用上述25/minute限制。
	iptables -A INPUT -p tcp --dport 80 -m limit --limit 25/minute --limit-burst 100 -j ACCEPT

	#禁止其他未允许的规则访问（注意：如果22端口未加入允许规则，SSH链接会直接断开。）
	iptables -A INPUT -j DROP 
	iptables -A FORWARD -j DROP

	if [[ "${version}" == "centos" ]];then
		#保存iptables添加的规则
		iptables-save >/etc/sysconfig/iptables 
		ip6tables-save >/etc/sysconfig/ip6tables
		systemctl enable iptables
		systemctl restart iptables
		if [ "$?" != "0" ];then
			read -sp "$(echo -e "\n${red}设置iptables防火墙规则失败，请重新尝试${none}\n")";exit
		else
			echo -e "\n${yellow}设置iptables开机启动成功${none}\n"
		fi
	else
		#保存iptables添加的规则
		test ! -e /etc/iptables && mkdir -p /etc/iptables
		iptables-save >/etc/iptables/rules.v4; ip6tables-save >/etc/iptables/rules.v6

		#检查iptables规则是否保存上了
		if [[ -f /etc/iptables/rules.v4 && -f /etc/iptables/rules.v6 ]];then
			echo -e "\n${yellow}设置iptables防火墙规则成功${none}\n"
		else
			read -sp "$(echo -e "\n${red}设置iptables防火墙规则失败，请重新尝试${none}\n")"; exit       
		fi
		systemctl start iptables &>/dev/null
		if [ "$?" == "0" ];then
			systemctl enable iptables; systemctl restart iptables
		else
			cat >/etc/init.d/iptables <<-EOF
			#!/bin/sh -e
			### BEGIN INIT INFO
			# Provides:             iptables
			# Default-Start:        2 3 4 5
			# Default-Stop:         
			### END INIT INFO
			/sbin/iptables-restore < /etc/iptables/rules.v4
			/sbin/ip6tables-restore < /etc/iptables/rules.v6
			EOF
			chmod +x /etc/init.d/iptables
			ln -s /etc/init.d/iptables /etc/rc2.d/S01iptables &>/dev/null
			/etc/init.d/iptables enable
			/etc/init.d/iptables reload

			#检测开机启动配置文件是否添加成功
			if [[ ! -f /etc/init.d/iptables && ! -f /etc/rc2.d/S01iptables ]];then
				PrintFalseInfo "设置iptables开机启动失败，请重新尝试"; exit
			else
				PrintTrueInfo "设置iptables开机启动成功"; return 0
			fi
		fi
	fi
}

#询问使用哪款防火墙软件
Select_Firewall() {
	while :;do
		clear
		PrintTrueInfo "1、ufw防火墙"
		PrintTrueInfo "2、iptables防火墙"
		read -p " 请选择一款防火墙软件来防护VPS，输入序号就可以：" select_fire
		case ${select_fire} in
			1) Ufw_Firewall ;[ $? == 0 ] && break ;;
			2) Iptables_Firewall ;[ $? == 0 ] && break ;;
			*) Error "请按照提示输入"
		esac
	done
}

# ufw防火墙放行
Set_Ufw() {
	[ -n "$(ufw status | egrep "\<${PORT}/tcp\>")" ] && { PrintTrueInfo "caddy端口 ${PORT} 已经放行";sleep 1;return 0; }
	ufw allow in ${PORT}/tcp &>/dev/null;ufw reload &>/dev/null
	if [ -n "$(ufw status | egrep "\<${PORT}/tcp\>")" ];then
		PrintTrueInfo "nginx 端口 ${PORT} 放行成功";
	else
		PrintFalseInfo "nginx 端口 ${PORT} 没有放行成功，请稍后再尝试 ";exit
	fi
}

#检测iptables防火墙路径
Check_Iptable_Path() {
    iptables_path=  # 定义一个iptables配置文件路径变量
	if [[ "${version}" == "centos" ]];then
		#保存iptables添加的规则
		iptables_path="etc/sysconfig/iptables"
    else
        if [ -f /etc/init.d/iptables ];then
            iptables_path="$(awk '/rules.v4/{print $3}' /etc/init.d/iptables)"
            [ -z ${iptables_path} ] && PrintFalseInfo "获取iptables配置文件路径失败，请重新执行脚本试试看" && exit 1
        fi
    fi
}

#安全配置sshd配置文件
set_sshd() {
	if [[ "$(cat /etc/ssh/sshd_config | grep '^PermitEmptyPasswords no')" == "" ]];then
		sed -i '/PermitEmptyPasswords/d' /etc/ssh/sshd_config
		echo 'PermitEmptyPasswords no' >> /etc/ssh/sshd_config
		if [[ "$(cat /etc/ssh/sshd_config | grep '^PermitEmptyPasswords no')" != "" ]];then
			echo -e "\n${yellow}禁用ssh使用空密码登录成功${none}\n"
		else
			echo -e "\n${red}禁用ssh使用空密码登录失败${none}\n"
			erro="${erro}\n禁用ssh使用空密码登录失败"
		fi
	else    
		echo -e "\n${green}已经成功禁用ssh使用空密码登录${none}\n"
	fi

	test_key=
	#设置登录秘钥的权限
	keys_path=$(find /home/ -name 'authorized_keys' | grep '.ssh')
	if [ ! -z "${keys_path}" ] || [ -f /root/.ssh/authorized_keys ]
	then
		echo ""
		echo -e "${yellow}正在更改登录秘钥的权限……${none}"
		echo ""
		for i in ${keys_path}
		do
			test -e ${i} && chmod 600 ${i}
			i=${i%/*}
			test -e ${i} && chmod 100 ${i}
		done
		test -e /root/.ssh/authorized_keys && chmod 600 /root/.ssh/authorized_keys
		test -e /root/.ssh && chmod 100 /root/.ssh
		echo ""
		echo -e "${yellow}更改登录秘钥的权限设置完成${none}"
		echo ""
	else
		echo ""
		echo -e "${red}没有发现登录秘钥，建议使用秘钥登录vps，这样有利于安全！${none}"
		echo ""
		sleep 3
		test_key=1
	fi

	#禁用密码登录
	if [ -z "$(cat /etc/ssh/sshd_config | grep '^PasswordAuthentication no')" ]
	then
		if [ "${test_key}" != "1" ]
		then
			sed -i '/PasswordAuthentication/d' /etc/ssh/sshd_config
			echo 'PasswordAuthentication no' >> /etc/ssh/sshd_config
			if [ ! -z "$(cat /etc/ssh/sshd_config | grep "^PasswordAuthentication no")" ]
			then
				echo -e "\n${yellow}禁用ssh使用密码登录配置修改成功${none}\n"
			else
				echo -e "\n${red}禁用ssh使用密码登录配置没有修改成功！${none}\n"
				erro="${erro}\n禁用ssh使用密码登录配置没有修改成功！"
			fi
		fi
	else    
		echo -e "\n${green}已经成功禁用ssh使用密码登录配置修改${none}\n"
	fi

	#禁用root用户登录
	if [ "$(cat /etc/passwd | grep '/home/' | grep ':/bin/bash')" != "" ];then
		if [ "${test_key}" != "1" ]
		then
			if [ -z "$(cat /etc/ssh/sshd_config | grep "^PermitRootLogin no")" ]
			then
				sed -i '/PermitRootLogin/d' /etc/ssh/sshd_config
				echo "PermitRootLogin no" >> /etc/ssh/sshd_config
				if [ ! -z "$(cat /etc/ssh/sshd_config | grep "^PermitRootLogin no")" ]
				then
					echo -e "\n${yellow}禁用root用户登录成功${none}\n"
				else
					echo -e "\n${red}禁用root用户登录没有成功！${none}\n"
					erro="${erro}\n禁用root用户登录没有成功！"
				fi
			else    
				echo -e "\n${green}已经成功禁用root用户登录${none}\n"
			fi
		fi
	fi
	
	systemctl restart sshd
	if [ "$?" != "0" ];then
		echo -e "\n${red}启动ssh配置文件失败，请手动检查！${none}\n"
		if_reboot=1
	else
		echo -e "\n${yellow}启动ssh配置文件成功${none}\n"
		if_reboot=0
	fi
}

#删除没有用的用户和组
del_nouser() {
	del_user_name=="adm lp sync shutdown halt news uucp operator games gopher ftp"
	del_group_name="lp news uucp games dip pppusers"

	for i in ${del_user_name}
	do
		if [[ ! -z $(cat /etc/passwd | grep "^${i}:") ]];then
			userdel -f $i &>/dev/null
			if [[ ! -z $(cat /etc/passwd | grep "^${i}:") ]];then
				echo -e "\n${red}伪用户 ${i} 没有删除！${none}\n"
				erro="${erro}\n伪用户 ${i} 没有删除！"
			fi
		fi
	done

	for q in ${del_group_name}
	do
		if [[ ! -z $(cat /etc/group | grep "^${q}:") ]];then
			groupdel $q &>/dev/null
			if [[ ! -z $(cat /etc/group | grep "^${q}:") ]];then
				echo -e "\n${red}伪用户组 ${q} 没有删除！${none}\n"
				erro="${erro}\n伪用户组 ${q} 没有删除！"
			fi
		fi
	done

}

#防火墙放行端口
Allow_Port() {
    Check_Iptable_Path
	if [[ -n "$(command -v ufw)" && -n "$(ufw status | egrep '\<active\>')" ]];then
		Set_Ufw		# ufw防火墙放行
	elif [[ -n ${iptables_path} ]];then
		Set_Iptables	# iptables防火墙放行
	else
		Select_Firewall		#选择防火墙
	fi
}

#检测当前VPS端口
Check_Sys_Port() {
	check_port=$(awk '/^Port/{print $2}' /etc/ssh/sshd_config)
	if [[ -n ${check_port}  && ${check_port} =~ ^[0-9]+$ ]];then
		print_info=",检测当前VPS端口为${green} "${check_port}" ${yellow}，直接回车使用检测的端口${none}"
	else
		print_info=""
	fi
}

#安全设置
security_set() {

	clear
	erro=
	echo ""
	echo "* * * * * * * * * * * * * *"
	echo -e "${yellow}\n   VPS系统安全设置${none} \n"
	echo -e "${yellow}\e[1;5m\e[1;32m 请按照提示信息进行操作\e[0m"
	echo "* * * * * * * * * * * * * *"

	#检测当前VPS端口
	Check_Sys_Port

	#设置登录端口
	while :;do
		clear
		echo -en "\n${yellow}请输入SSH登录端口"${print_info}"[按q退出脚本]: ${none}"; read login_port
		[ -z "${login_port}" ] && login_port="${check_port}"
		[ "${login_port}" == q ] && exit
		if [[ -n ${login_port} && ${login_port} =~ ^[0-9]+$ ]];then		# 检查是否纯数字
			if [ -z "$(awk '/Port '${login_port}'/{print $2}' /etc/ssh/sshd_config)" ];then
				Error "输入的端口没有找到，请重新输入一下，可以看一下登录VPS的软件那里填写端口"
			else
				break
			fi
		else
			Error "端口输入的不正确，请重新输入！"
		fi
	done
	Allow_Port		# 防火墙放行端口
	set_sshd		# 设置sshd配置文件
	del_nouser		# 删除没有用的用户和组
}

Unset_Iptables() {
	PrintTrueInfo "开始清理 iptables 防火墙..."
	#获取当前系统版本
	version="$(grep '^ID=' /etc/os-release | cut -d '=' -f 2 | sed 's/"//g')"

	# 清除已有iptables规则
	iptables -F; iptables -X
	
	if [ "${version}" == "centos" ];then
		#删除iptables添加的规则
		if [ -f /etc/sysconfig/iptables ];then
			systemctl stop iptables
			systemctl disable iptables
			rm -rf /etc/sysconfig/iptables 
			test -e /etc/sysconfig/ip6tables && rm -rf /etc/sysconfig/ip6tables
			if [[ -f /etc/sysconfig/iptables && -f /etc/sysconfig/ip6tables ]];then
				PrintTrueInfo "iptables防火墙清理完成。"
			else
				PrintFalseInfo "iptables防火墙没有清理完成。"
			fi
		else
			echo -e "\n${green}iptables防火墙已经清理了。${none}\n"
		fi
		exit		
	else
		#删除开机启动配置文件	
		[ -f /etc/rc2.d/S01iptables ] && rm -rf /etc/rc2.d/S01iptables		
		[ -f /etc/init.d/iptables ] && rm -rf /etc/init.d/iptables
		if [[ -f /etc/init.d/iptables && -f /etc/rc2.d/S01iptables ]];then
			PrintFalseInfo "iptables防火墙没有清理完成。"
		else
			PrintTrueInfo "iptables防火墙清理完成。"
		fi
		
		#删除iptables规则
		if [[ -f /etc/iptables.rules.v4 || -f /etc/iptables.rules.v6 ]];then
			test -e /etc/iptables.rules.v4 && rm -rf /etc/iptables.rules.v4
			test -e /etc/iptables.rules.v6 && rm -rf /etc/iptables.rules.v6		
		elif [ -d /etc/iptables ];then
			rm -rf /etc/iptables
			if [[ -d /etc/iptables ]];then
				PrintFalseInfo "iptables防火墙没有清理完成。"
			else
				PrintTrueInfo "iptables防火墙清理完成。"
			fi
		else
			echo -e "\n${green}iptables防火墙已经清理了。${none}\n"
		fi
		exit			
	fi
}

# 卸载ufw防火墙
Unset_Ufw() {
	PrintTrueInfo "开始禁用 ufw 防火墙..."
	echo y | ufw reset > /tmp/ufwback.log 	# 重置ufw防火墙
	#获取ufw防火墙备份列表
	delete_ufw="$(awk -F"to '" '/Backing up/{print $2}' /tmp/ufwback.log | sed "s/'//g")"
	#删除ufw防火墙备份列表
	for i in ${delete_ufw};do
		[ -f "${i}" ] && rm ${i}
	done
	ufw disable; systemctl stop ufw; systemctl disable ufw	# 禁用ufw防火墙
	if [ -n "$(ufw status | egrep '\<inactive\>')" ];then	#检查ufw防火墙的状态是否禁用成功
        PrintTrueInfo "ufw 防火墙禁用成功"
    else
        Error "ufw 防火墙禁用失败，请重新尝试"; return 1
    fi
}

#清理iptables防火墙
unsecurity_set() {
    Check_Iptable_Path
	if [[ -n "$(command -v ufw)" && -n "$(ufw status | egrep '\<active\>')" ]];then
		Unset_Ufw		# 禁用ufw防火墙
	elif [[ -n ${iptables_path} ]];then
		Unset_Iptables	# 禁用iptables防火墙
	else
		Notifi "没有检测到系统有配置ufw和iptables防火墙，回车后退出脚本"
	fi
}

# 选择防火墙设置
Select_Security_Set() {
	while :;do
		clear
		echo -e "\n${yellow} 1、设置防火墙 ${none}\n"
		echo -e "\n${yellow} 2、清理防火墙设置 ${none}\n"
		echo -en "${yellow}请输入序号[1-2]: ${none}"
		read select_input
		case ${select_input} in
			1) security_set; exit ;;
			2) unsecurity_set; exit ;;
			*) Error "请按照提示输入"; continue ;;
		esac
	done
}

#优化设置
optimize_set() {
	#设置默认登录端口22
	if [ "$(cat /etc/ssh/sshd_config | grep '#Port 22')" == "" ];then
		echo '#Port 22' >> /etc/ssh/sshd_config
		systemctl restart sshd
	fi

	back_port=$(cat /etc/ssh/sshd_config | grep '^Port' | awk '{print $2}')
	if [ -z ${back_port} ];then
	#设置登录端口
		while true
		do
			echo -en "\n${yellow}没有检测到SSH登录端口，请输入SSH登录端口"${print_info}": ${none}"
			read back_port
			if [[ -z ${back_port} || $(echo ${back_port} | sed "s/[0-9]//g") != "" ]];then
				read -sp "$(echo -e "\n${red}输入的不正确请重新输入${none}\n")"
				continue
			fi
			break
		done
	fi

	#校验系统发行版本
	print_verson=$(grep '^PRETTY_NAME=' /etc/os-release | cut -d '=' -f 2)
	[ ! -z "${print_verson}" ] && echo -e "\n${yellow}当前为 ${print_verson} 系统……${none}\n"
	echo -e "\n${green}正在更新系统${none}\n"
	if [[ -f /usr/bin/yum ]]; then
		cmd="yum"
		${cmd} upgrade -y
	elif [[ -f /usr/bin/apt ]]; then
		cmd="apt"
		${cmd} update && ${cmd} upgrade -y
		if [ "$(echo $?)" != "0" ];then
			kill_id=$(ps -aux | grep -i apt | grep -v 'grep' | awk '{print $2}')
			[ ! -z "${kill_id}" ] && kill -9 ${kill_id}
			dpkg --configure -a
		fi
	fi

	#优化内核设置
	if [ "$(cat /etc/sysctl.conf | grep 'net.core.rmem_max = 67108864')" == "" ]
	then
		echo ""
		echo -e "${yellow}正在设置优化内核${none}"
		echo ""
		echo '# max open files
fs.file-max = 51200
# max read buffer
net.core.rmem_max = 67108864
# max write buffer
net.core.wmem_max = 67108864
# default read buffer
net.core.rmem_default = 65536
# default write buffer
net.core.wmem_default = 65536
# max processor input queue
net.core.netdev_max_backlog = 4096
# max backlog
net.core.somaxconn = 4096
# resist SYN flood attacks
net.ipv4.tcp_syncookies = 1
# reuse timewait sockets when safe
net.ipv4.tcp_tw_reuse = 1
# short FIN timeout
net.ipv4.tcp_fin_timeout = 30
# short keepalive time
net.ipv4.tcp_keepalive_time = 1200
# outbound port range
net.ipv4.ip_local_port_range = 10000 65000
# max SYN backlog
net.ipv4.tcp_max_syn_backlog = 4096
# max timewait sockets held by system simultaneously
net.ipv4.tcp_max_tw_buckets = 5000
# TCP receive buffer
net.ipv4.tcp_rmem = 4096 87380 67108864
# TCP write buffer
net.ipv4.tcp_wmem = 4096 65536 67108864
# turn on path MTU discovery
net.ipv4.tcp_mtu_probing = 1' >> /etc/sysctl.conf
		sysctl -p >/dev/null 2>&1
		if [ "$?" != "0" ]
		then
			echo ""
			echo -e "${red}优化内核没有成功${none}"
			echo ""
		else
			echo ""
			echo -e "${green}优化内核成功${none}"
			echo ""
		fi
	else
		echo ""
		echo -e "${green}已经设置优化内核${none}"
		echo ""
	fi

	#安全限制配置文件
	if [ "$(cat /etc/security/limits.conf | grep '* soft nofile 51200')" == "" ]
	then
		echo '* soft nofile 51200
	* hard nofile 51200' >> /etc/security/limits.conf
		if [ "$(cat /etc/security/limits.conf | grep '* soft nofile 51200')" != "" ]
		then
			echo ""
			echo -e "${green}限制文件数量设置完成${none}"
			echo ""
		fi
	else
		echo -e "\n${green}限制文件数量已经设置上了${none}\n"
	fi
	ulimit -SHn 51200
	if [ "$(cat /etc/profile | grep 'ulimit -SHn 51200')" == "" ]
	then
		echo 'ulimit -SHn 51200' >> /etc/profile
		if [ "$(cat /etc/profile | grep 'ulimit -SHn 51200')" == "" ]
		then
			echo -e "\n${green}设置限制文件命令添加到全局变量中${none}\n"        
		fi
	else
		echo -e "\n${green}已经设置限制文件命令添加到全局变量中${none}\n"   
	fi

	#检查sshd_config配置文件是否被修改
	if [ -z "$(cat /etc/ssh/sshd_config | grep "^Port ${back_port}")" ]
	then
		echo -e "\n${yellow}sshd_config配置被修改了，正在还原……${none}\n"
		sed -i "/^Port/d" /etc/ssh/sshd_config
		echo "Port ${back_port}" >> /etc/ssh/sshd_config
		systemctl restart sshd
		if [ ! -z "$(cat /etc/ssh/sshd_config | grep "^Port ${back_port}")" ]
		then
			echo -e "\n${green}sshd_config配置修改成功${none}\n"
		fi
		sed -i -e 's/#HostKey \/etc\/ssh\/ssh_host_rsa_key/HostKey \/etc\/ssh\/ssh_host_rsa_key/g' \
		-e 's/#HostKey \/etc\/ssh\/ssh_host_ecdsa_key/HostKey \/etc\/ssh\/ssh_host_ecdsa_key/g' \
		-e 's/#HostKey \/etc\/ssh\/ssh_host_ed25519_key/HostKey \/etc\/ssh\/ssh_host_ed25519_key/g' \
		-e 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/g' \
		-e 's/#AuthorizedKeysFile/AuthorizedKeysFile/g' /etc/ssh/sshd_config
		set_sshd	#调用设置sshd配置文件函数
	fi
}

#安装xray程序
installXray() {
	rm -rf /tmp/xray
	mkdir -p /tmp/xray
	DOWNLOAD_LINK="https://github.com/XTLS/Xray-core/releases/download/${NEW_VER}/Xray-linux-$(archAffix).zip"
	colorEcho $BLUE " 下载Xray: ${DOWNLOAD_LINK}"
	curl -L -H "Cache-Control: no-cache" -o /tmp/xray/xray.zip ${DOWNLOAD_LINK}
	if [ $? != 0 ]; then
		colorEcho $RED " 下载Xray文件失败，请检查服务器网络设置"
		exit 1
	fi
	systemctl stop xray
	mkdir -p /etc/xray/config /usr/local/share/xray && \
	unzip /tmp/xray/xray.zip -d /tmp/xray
	cp /tmp/xray/xray /usr/local/bin
	cp /tmp/xray/geo* /usr/local/share/xray
	chmod +x /usr/local/bin/xray || {
		colorEcho $RED " Xray安装失败"
		exit 1
	}

	cat >/etc/systemd/system/xray.service <<-EOF
		[Unit]
		Description=Xray Service
		Documentation=https://github.com/xtls
		After=network.target nss-lookup.target
		
		[Service]
		User=root
		#User=nobody
		#CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
		#AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
		NoNewPrivileges=true
		ExecStart=/usr/local/bin/xray run -confdir /etc/xray/config
		Restart=on-failure
		RestartPreventExitStatus=23
		
		[Install]
		WantedBy=multi-user.target
	EOF
	systemctl daemon-reload
	systemctl enable xray.service
}

#追加xray或者v2ray的日志配置文件和出站配置文件
log_outbounds() {
	cat > ${config_dir_path}/01-log.json <<-EOF
	{
	    "log": {
	#        "access": "/var/log/xray/access.log",
	#        "error": "/var/log/xray/error.log",
	        "loglevel": "warning"
	    }
	}
	EOF

	cat > ${config_dir_path}/12-outbounds.json <<-EOF
	{
	    "outbounds": [{
	    "protocol": "freedom",
	    "settings": {}
	    },{
	    "protocol": "blackhole",
	    "settings": {},
	    "tag": "blocked"
	    }]
	}
	EOF
}

trojanConfig() {
	cat > ${config_dir_path}/02-trojan_inbounds.json <<-EOF
	{
	    "inbounds": [{
	    "port": $PORT,
	    "protocol": "trojan",
	    "tag":"TROJAN",
	    "settings": {
	        "clients": [
	        {
	            "password": "$PASSWORD"
	        }
	        ],
	        "fallbacks": [
	        {
	                "alpn": "http/1.1",
	                "dest": 80
	            },
	            {
	                "alpn": "h2",
	                "dest": 81
	            }
	        ]
	    },
	    "streamSettings": {
	        "network": "tcp",
	        "security": "tls",
	        "tlsSettings": {
	            "serverName": "$DOMAIN",
	            "alpn": ["http/1.1", "h2"],
	            "certificates": [
	                {
	                    "certificateFile": "$CERT_FILE",
	                    "keyFile": "$KEY_FILE"
	                }
	            ]
	        }
	    }
	    }]
	}
	EOF
}

trojanXTLSConfig() {
	cat > ${config_dir_path}/03-trojan_XTLS_inbounds.json <<-EOF
	{
	    "inbounds": [{
	    "port": $PORT,
	    "protocol": "trojan",
	    "tag":"TROJANXTLS",
	    "settings": {
	        "clients": [
	        {
	            "password": "$PASSWORD",
	            "flow": "$FLOW"
	        }
	        ],
	        "fallbacks": [
	        {
	                "alpn": "http/1.1",
	                "dest": 80
	            },
	            {
	                "alpn": "h2",
	                "dest": 81
	            }
	        ]
	    },
	    "streamSettings": {
	        "network": "tcp",
	        "security": "xtls",
	        "xtlsSettings": {
	            "serverName": "$DOMAIN",
	            "alpn": ["http/1.1", "h2"],
	            "certificates": [
	                {
	                    "certificateFile": "$CERT_FILE",
	                    "keyFile": "$KEY_FILE"
	                }
	            ]
	        }
	    }
	    }]
	}
	EOF
}

vmessConfig() {
	uuid="$(cat '/proc/sys/kernel/random/uuid')"
	local alterid=$(shuf -i50-80 -n1)
	cat > ${config_dir_path}/04-vmess_inbounds.json <<-EOF
	{
	    "inbounds": [{
	    "port": $PORT,
	    "protocol": "vmess",
	    "tag":"VMESS",
	    "settings": {
	        "clients": [
	        {
	            "id": "$uuid",
	            "level": 1,
	            "alterId": $alterid
	        }
	        ]
	    }
        }]
	}
	EOF
}

vmessKCPConfig() {
	uuid="$(cat '/proc/sys/kernel/random/uuid')"
	local alterid=$(shuf -i50-80 -n1)
	cat > ${config_dir_path}/05-vmess_KCP_inbounds.json <<-EOF
	{
	    "inbounds": [{
	    "port": $PORT,
	    "protocol": "vmess",
	    "tag":"VMESSKCP",
	    "settings": {
	        "clients": [
	        {
	            "id": "$uuid",
	            "level": 1,
	            "alterId": $alterid
	        }
	        ]
	    },
	    "streamSettings": {
	        "network": "mkcp",
	        "kcpSettings": {
	            "uplinkCapacity": 100,
	            "downlinkCapacity": 100,
	            "congestion": true,
	            "header": {
	                "type": "$HEADER_TYPE"
	            },
	            "seed": "$SEED"
	        }
	    }
	    }]
	}
	EOF
}

vmessTLSConfig() {
	uuid="$(cat '/proc/sys/kernel/random/uuid')"
	cat > ${config_dir_path}/06-vmess_TLS_inbounds.json <<-EOF
	{
	    "inbounds": [{
	    "port": $PORT,
	    "protocol": "vmess",
	    "tag":"VMESSTLS",
	    "settings": {
	        "clients": [
	        {
	            "id": "$uuid",
	            "level": 1,
	            "alterId": 0
	        }
	        ],
	        "disableInsecureEncryption": false
	    },
	    "streamSettings": {
	        "network": "tcp",
	        "security": "tls",
	        "tlsSettings": {
	            "serverName": "$DOMAIN",
	            "alpn": ["http/1.1", "h2"],
	            "certificates": [
	                {
	                    "certificateFile": "$CERT_FILE",
	                    "keyFile": "$KEY_FILE"
	                }
	            ]
	        }
	    }
	    }]
	}
	EOF
}

vmessWSConfig() {
	uuid="$(cat '/proc/sys/kernel/random/uuid')"
	local tmp_uuid="$(cat '/proc/sys/kernel/random/uuid')"
	cat > ${config_dir_path}/07-vmess_WS_inbounds.json <<-EOF
	{
	    "inbounds": [{
	    "port": $XPORT,
	    "listen": "127.0.0.1",
	    "protocol": "vmess",
	    "tag":"VMESSWS",
	    "settings": {
	        "clients": [
	             {"id": "$tmp_uuid","level": 1,"alterId": 0},
	            {"id": "$uuid","level": 1,"alterId": 0}
	        ],
	        "disableInsecureEncryption": false
	    },
	    "streamSettings": {
	        "network": "ws",
	        "wsSettings": {
	        "path": "$WSPATH"
	        }
	    }
	    }]
	}
	EOF
}

vlessTLSConfig() {
	uuid="$(cat '/proc/sys/kernel/random/uuid')"
	cat > ${config_dir_path}/08-vless_TLS_inbounds.json <<-EOF
	{
	    "inbounds": [{
	    "port": $PORT,
	    "protocol": "vless",
	    "tag":"VLESSTLS",
	    "settings": {
	        "clients": [
	        {
	            "id": "$uuid",
	            "level": 0
	        }
	        ],
	        "decryption": "none",
	        "fallbacks": [
	            {
	                "alpn": "http/1.1",
	                "dest": 80
	            },
	            {
	                "alpn": "h2",
	                "dest": 81
	            }
	        ]
	    },
	    "streamSettings": {
	        "network": "tcp",
	        "security": "tls",
	        "tlsSettings": {
	            "serverName": "$DOMAIN",
	            "alpn": ["http/1.1", "h2"],
	            "certificates": [
	                {
	                    "certificateFile": "$CERT_FILE",
	                    "keyFile": "$KEY_FILE"
	                }
	            ]
	        }
	    }
	    }]
	}
	EOF
}

vlessXTLSConfig() {
	uuid="$(cat '/proc/sys/kernel/random/uuid')"
	cat > ${config_dir_path}/09-vless_XTLS_inbounds.json <<-EOF
	{
	    "inbounds": [{
	    "port": $PORT,
	    "protocol": "vless",
	    "tag":"VLESSXTLS",
	    "settings": {
	        "clients": [
	        {
	            "id": "$uuid",
	            "flow": "$FLOW",
	            "level": 0
	        }
	        ],
	        "decryption": "none",
	        "fallbacks": [
	            {
	                "alpn": "http/1.1",
	                "dest": 80
	            },
	            {
	                "alpn": "h2",
	                "dest": 81
	            }
	        ]
	    },
	    "streamSettings": {
	        "network": "tcp",
	        "security": "xtls",
	        "xtlsSettings": {
	            "serverName": "$DOMAIN",
	            "alpn": ["http/1.1", "h2"],
	            "certificates": [
	                {
	                    "certificateFile": "$CERT_FILE",
	                    "keyFile": "$KEY_FILE"
	                }
	            ]
	        }
	    }
	    }]
	}
	EOF
}

vlessWSConfig() {
	uuid="$(cat '/proc/sys/kernel/random/uuid')"
	local tmp_uuid="$(cat '/proc/sys/kernel/random/uuid')"
	cat > ${config_dir_path}/10-vless_WS_inbounds.json <<-EOF
	{
	    "inbounds": [{
	    "port": $XPORT,
	    "listen": "127.0.0.1",
	    "protocol": "vless",
	    "tag":"VLESSWS",
	    "settings": {
	        "clients": [
	             {"id": "$tmp_uuid","level": 0},
	            {"id": "$uuid","level": 0}
	        ],
	        "decryption": "none"
	    },
	    "streamSettings": {
	        "network": "ws",
	        "security": "none",
	        "wsSettings": {
	        "path": "$WSPATH"
	        }
	    }
	    }]
	}
	EOF
}

vlessKCPConfig() {
	uuid="$(cat '/proc/sys/kernel/random/uuid')"
	cat > ${config_dir_path}/11-vless_KCP_inbounds.json <<-EOF
	{
	    "inbounds": [{
	    "port": $PORT,
	    "protocol": "vless",
	    "tag":"VLESSKCP",
	    "settings": {
	        "clients": [
	        {
	            "id": "$uuid",
	            "level": 0
	        }
	        ],
	        "decryption": "none"
	    },
	    "streamSettings": {
	        "streamSettings": {
	            "network": "mkcp",
	            "kcpSettings": {
	                "uplinkCapacity": 100,
	                "downlinkCapacity": 100,
	                "congestion": true,
	                "header": {
	                    "type": "$HEADER_TYPE"
	                },
	                "seed": "$SEED"
	            }
	        }
	    }
	    }]
	}
	EOF
}

#配置xray
configXray() {
	mkdir -p /usr/local/xray
	config_dir_path="/etc/xray/config"
	[ ! -f "${config_dir_path}/01-log.json" ] && log_outbounds		#追加xray或者v2ray的日志配置文件和出站配置文件函数
	if [[ "$TROJAN" == "true" ]]; then
		if [[ "$XTLS" == "true" ]]; then
			trojanXTLSConfig
		else
			trojanConfig
		fi
		return 0
	fi
	if [[ "$VLESS" == "false" ]]; then
		# VMESS + kcp
		if [[ "$KCP" == "true" ]]; then
			vmessKCPConfig
			return 0
		fi
		# VMESS
		if [[ "$TLS" == "false" ]]; then
			vmessConfig
		elif [[ "$WS" == "false" ]]; then
			# VMESS+TCP+TLS
			vmessTLSConfig
		# VMESS+WS+TLS
		else
			if [ ! -f "${config_dir_path}/07-vmess_WS_inbounds.json" ];then
				vmessWSConfig
			else
				tmp_path="${config_dir_path}/07-vmess_WS_inbounds.json"
				config_v2id
			fi
		fi
	#VLESS
	else
		if [[ "$KCP" == "true" ]]; then
			vlessKCPConfig
			return 0
		fi
		# VLESS+TCP
		if [[ "$WS" == "false" ]]; then
			# VLESS+TCP+TLS
			if [[ "$XTLS" == "false" ]]; then
				vlessTLSConfig
			# VLESS+TCP+XTLS
			else
				vlessXTLSConfig
			fi
		# VLESS+WS+TLS
		else
			if [ ! -f "${config_dir_path}/10-vless_WS_inbounds.json" ];then
				vlessWSConfig
			else
				tmp_path="${config_dir_path}/10-vless_WS_inbounds.json"
				config_v2id	
			fi
		fi
	fi
}

#显示xary版本号
normalizeVersion() {
	if [ -n "$1" ]; then
		case "$1" in
			v*) echo "$1" ;;
			http*) echo "v1.5.3" ;;
			*) echo "v$1" ;;
		esac
	else
		echo ""
	fi
}

#下载伪装网站
SetUrl() {
	test ! -e /www && mkdir -p /www && chmod 755 /www
	len=${#SITES[@]}
	((len--))
	RandomUserAgent	#获取伪装浏览器指纹信息
	while true; do
		index=$(shuf -i0-${len} -n1)
		URL=${SITES[$index]}
		URLPath=$(echo ${URL} | cut -d/ -f3-)
		if [[ ! -f  "/www/${URLPath}/index.html" ]]; then
			timeout -k 10s 1m wget --user-agent="${UserAgent}" -p  --convert-links --no-check-certificate -P/www ${URL} &>/dev/null
			[ $? != 0 ] && PrintFalseInfo "下载伪装网页失败，等待1秒重新下载" && sleep 1 && continue
		fi
		if [[ -f  "/www/${URLPath}/index.html" ]]; then
			URLPath="/www/${URLPath}"
			break
		fi
	done
	PROXY_URL=	
	colorEcho $BLUE " 伪装网站：$URL"
	echo ""
}

# 获取xray版本： 1: new Xray. 0: no. 1: yes. 2: not installed. 3: check failed.
getVersion() {
	VER=$(/usr/local/bin/xray version | head -n1 | awk '{print $2}')
	RETVAL=$?
	CUR_VER="$(normalizeVersion "$(echo "$VER" | head -n 1 | cut -d " " -f2)")"
	TAG_URL="https://api.github.com/repos/XTLS/Xray-core/releases/latest"
	NEW_VER="$(normalizeVersion "$(curl -s "${TAG_URL}" --connect-timeout 10 | sed 'y/,/\n/' | grep 'tag_name' | awk -F '"' '{print $4}')")"

	if [[ $? -ne 0 ]] || [[ $NEW_VER == "" ]]; then
		colorEcho $RED " 检查Xray版本信息失败，请检查网络"
		return 3
	elif [[ $RETVAL -ne 0 ]]; then
		return 2
	elif [[ $NEW_VER != $CUR_VER ]]; then
		return 1
	fi
	return 0
}

#安装Nginx
installNginx() {
	echo ""
	colorEcho $BLUE " 安装nginx..."
	if [[ "$BT" == "false" ]]; then
		if [[ "$PMT" == "yum" ]]; then
			$CMD_INSTALL epel-release
			if [[ "$?" != "0" ]]; then
				echo '[nginx-stable]
name=nginx stable repo
baseurl=http://nginx.org/packages/centos/$releasever/$basearch/
gpgcheck=1
enabled=1
gpgkey=https://nginx.org/keys/nginx_signing.key
module_hotfixes=true' >/etc/yum.repos.d/nginx.repo
			fi
		fi
		$CMD_INSTALL nginx
		if [[ "$?" != "0" ]]; then
			colorEcho $RED " Nginx安装失败，请截图到TG群反馈"
			exit 1
		fi
		systemctl enable nginx
	else
		res=$(which nginx 2>/dev/null)
		if [[ "$?" != "0" ]]; then
			colorEcho $RED " 您安装了宝塔，请在宝塔后台安装nginx后再运行本脚本"
			exit 1
		fi
	fi
}

#端口随机
PostRodanm() {
	#常用端口列表
	NoPostlist="1024|1025|1026|1027|1030|1031|1033|1034|1036|1070|1071|1074|1080|1110|1125\
	|1203|1204|1206|1222|1233|1234|1243|1245|1273|1289|1290|1333|1334|1335|1336\
	|1349|1350|1371|1372|1374|1376|1377|1378|1380|1381|1386|1387|1388|1389|1390\
	|1391|1392|1393|1394|1395|1396|1397|1398|1399|1433|1434|1492|1509|1512|1524\
	|1600|1645|1701|1731|1801|1807|1900|1912|1981|1999|2000|2001|2003|2023|2049\
	|2115|2140|2500|2504|2565|2583|2801|2847|3024|3128|3129|3150|3210|3306|3333\
	|3456|3457|3527|3700|3996|4000|4060|4092|4133|4134|4141|4142|4143|4145|4321\
	|4333|4349|4350|4351|4453|4454|4455|4456|4457|4480|4500|4547|4555|4590|4672\
	|4752|4800|4801|4802|4848|4849|4950|5000|5001|5006|5007|5022|5050|5051|5052\
	|5137|5150|5154|5190|5191|5192|5193|5222|5225|5226|5232|5250|5264|5265|5269\
	|5306|5321|5400|5401|5402|5405|5409|5410|5415|5416|5417|5421|5423|5427|5432\
	|5550|5569|5599|5600|5601|5631|5632|5673|5675|5676|5678|5679|5720|5729|5730\
	|5731|5732|5742|5745|5746|5755|5757|5766|5767|5768|5777|5800|5801|5802|5803\
	|5900|5901|5902|5903|6000|6001|6002|6003|6004|6005|6006|6007|6008|6009|6010\
	|6011|6012|6013|6014|6015|6016|6017|6018|6019|6020|6021|6022|6023|6024|6025\
	|6026|6027|6028|6029|6030|6031|6032|6033|6034|6035|6036|6037|6038|6039|6040\
	|6041|6042|6043|6044|6045|6046|6047|6048|6049|6050|6051|6052|6053|6054|6055\
	|6056|6057|6058|6059|6060|6061|6062|6063|6267|6400|6401|6455|6456|6471|6505\
	|6506|6507|6508|6509|6510|6566|6580|6581|6582|6588|6631|6667|6668|6670|6671\
	|6699|6701|6788|6789|6841|6842|6883|6939|6969|6970|7000|7002|7003|7004|7005\
	|7006|7007|7008|7009|7011|7012|7013|7014|7015|7020|7021|7100|7121|7300|7301\
	|7306|7307|7308|7323|7511|7588|7597|7626|7633|7674|7675|7676|7720|7743|7789\
	|7797|7798|8000|8001|8007|8008|8009|8010|8011|8022|8080|8081|8082|8118|8121\
	|8122|8181|8225|8311|8351|8416|8417|8473|8668|8786|8787|8954|9000|9001|9002\
	|9021|9022|9023|9024|9025|9026|9101|9102|9103|9111|9217|9281|9282|9346|9400\
	|9401|9402|9594|9595|9800|9801|9802|9872|9873|9874|9875|9899|9909|9911|9989\
	|9990|9991|10000|10001|10005|10008|10067|10113|10115|10116|10167|11000|11113\
	|11233|12076|12223|12345|12346|12361|13223|13224|16959|16969|17027|19191\
	|20000|20001|20034|21554|22222|23444|23456|25793|26262|26263|26274|27374\
	|30100|30129|30303|30999|31337|31338|31339|31666|31789|32770|33333|33434\
	|34324|36865|38201|39681|40412|40421|40422|40423|40426|40843|43210|43190\
	|44321|44322|44334|44442|44443|44445|45576|47262|47624|47806|48003|50505\
	|50766|53001|54320|54321|61466|65000|65301"
	while :;do
		TmpPost=$(shuf -i1024-65000 -n1)
		if [[ ! -z ${TmpPost} && "${TmpPost:0:1}" != "0" && ! ${TmpPost} =~ ${NoPostlist} ]];then
			break
		else
			continue
		fi
	done
}

#获取域名，伪装网址、伪装类型，是否开启bbr加速
getData() {
	if [[ "$TLS" == "true" || "$XTLS" == "true" ]]; then
		answer=y

		#输入域名
		if [ -z "${DOMAIN}" ];then
			while true; do
				echo ""
				read -p "$(echo -e ${YELLOW} 请输入伪装域名：${PLAIN})" DOMAIN
				if [[ -z "${DOMAIN}" ]]; then
					colorEcho ${RED} " 域名输入错误，请重新输入！"
					sleep 2
				else
					break
				fi
			done
		fi
		DOMAIN=${DOMAIN,,}
		#反馈域名的信息
		colorEcho ${BLUE} " 伪装域名(host)：$DOMAIN"
		echo ""

		if [ -z "${account_class}" ];then
			#选择账号类型，是搭建直连账号还是cdn账号。
			while true
			do
				echo -en "${YELLOW}选择搭建账号的类型. ${GREEN}输入 y 是搭建直连账号；输入 n 是搭建cdn账号： ${PLAIN}"
				read account_class
				if [[ "${account_class}" == y || "${account_class}" == n ]];then
					break
				else
					colorEcho ${RED} " 输入错误，请重新输入！"
					sleep 2
				fi
			done
		fi
		
		#根据搭建账号类型进行处理
		if [ ${account_class} == y ];then

			if [[ -f ~/xray.pem && -f ~/xray.key ]]; then
				colorEcho ${BLUE} " 检测到自有证书，将使用其部署"
				CERT_FILE="/etc/nginx/ssl/${DOMAIN}.pem"
				KEY_FILE="/etc/nginx/ssl/${DOMAIN}.key"
			else
				resolve=$(curl -sm8 ipget.net/?ip=${DOMAIN})
				if [ $resolve != $IP ]; then
					colorEcho ${BLUE} "${DOMAIN} 解析结果：${resolve}"
					colorEcho ${RED} " 域名未解析到当前服务器IP(${IP})！"
					exit 1
				fi
			fi
		else
			#检测相关域名证书是否存在
			check_ssl_t			
		fi

	fi
	echo ""

	#判断是否使用了websockt协议，根据需要输入监听端口
	if [[ "$(needNginx)" == "no" ]]; then
		if [[ "$TLS" == "true" ]]; then
			read -p " 请输入xray监听端口[强烈建议443，默认443]：" PORT
			[[ -z "${PORT}" ]] && PORT=443
		else
			PORT=$(shuf -i200-65000 -n1)
			if [[ "${PORT:0:1}" == "0" ]]; then
				colorEcho ${RED} " 端口不能以0开头"
				exit 1
			fi
		fi
		colorEcho ${BLUE} " xray端口：$PORT"
	else
		if [ ${account_class} == y ];then
			PostRodanm	#获取随机的端口
			read -p " 请输入Nginx监听端口[1024-65535之间范围，默认"$TmpPost"]：" PORT
			[[ -z "${PORT}" ]] && PORT=${TmpPost}
			[ "${PORT:0:1}" = "0" ] && colorEcho ${BLUE} " 端口不能以0开头" && exit 1
		else
			PORT=443
		fi
		colorEcho ${BLUE} " Nginx端口：$PORT"
		if [ -z "${XPORT}" ];then
			XPORT=$(shuf -i10000-65000 -n1)
		fi
	fi
	if [[ "$KCP" == "true" ]]; then
		echo ""
		colorEcho $BLUE " 请选择伪装类型："
		echo "   1) 无"
		echo "   2) BT下载"
		echo "   3) 视频通话"
		echo "   4) 微信视频通话"
		echo "   5) dtls"
		echo "   6) wiregard"
		read -p "  请选择伪装类型[默认：无]：" answer
		case $answer in
			2) HEADER_TYPE="utp" ;;
			3) HEADER_TYPE="srtp" ;;
			4) HEADER_TYPE="wechat-video" ;;
			5) HEADER_TYPE="dtls" ;;
			6) HEADER_TYPE="wireguard" ;;
			*) HEADER_TYPE="none" ;;
		esac
		colorEcho $BLUE " 伪装类型：$HEADER_TYPE"
		SEED=$(cat /proc/sys/kernel/random/uuid)
	fi

	#trojan
	if [[ "$TROJAN" == "true" ]]; then
		echo ""
		read -p " 请设置trojan密码（不输则随机生成）:" PASSWORD
		[[ -z "$PASSWORD" ]] && PASSWORD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)
		colorEcho $BLUE " trojan密码：$PASSWORD"
	fi
	if [[ "$XTLS" == "true" ]]; then
		echo ""
		colorEcho $BLUE " 请选择流控模式:"
		echo -e "   1) xtls-rprx-direct [$RED推荐$PLAIN]"
		echo "   2) xtls-rprx-origin"
		read -p "  请选择流控模式[默认:direct]" answer
		[[ -z "$answer" ]] && answer=1
		case $answer in
			1) FLOW="xtls-rprx-direct" ;;
			2) FLOW="xtls-rprx-origin" ;;
			*) colorEcho $RED " 无效选项，使用默认的xtls-rprx-direct" && FLOW="xtls-rprx-direct" ;;
		esac
		colorEcho $BLUE " 流控模式：$FLOW"
	fi

	#伪装路径默认设置为uuid。
	if [[ "${WS}" == "true" ]]; then
		echo ""
		if [ "${WSPATH}" == "" ];then
			ws=$(cat /proc/sys/kernel/random/uuid)
			WSPATH="/$ws"
		fi
		colorEcho ${BLUE} " ws路径：$WSPATH"
	fi

	#选择伪装网站
	if [[ "$TLS" == "true" || "$XTLS" == "true" ]]; then
		echo ""
		SetUrl	#下载伪装网站

		#不允许搜索引擎爬取网站
		ALLOW_SPIDER="n"
		colorEcho $BLUE " 允许搜索引擎：$ALLOW_SPIDER"
	fi

	if [ $print_bbr == true ];then
		echo ""
		read -p " 是否安装BBR(默认安装)?[y/n]:" NEED_BBR
		[[ -z "$NEED_BBR" ]] && NEED_BBR=y
		[[ "$NEED_BBR" == "Y" ]] && NEED_BBR=y
		colorEcho $BLUE " 安装BBR：$NEED_BBR"
	fi
}

#安装bbr加速
installBBR() {
	if [[ "$NEED_BBR" != "y" ]]; then
		INSTALL_BBR=false
		return
	fi
	result=$(lsmod | grep bbr)
	if [[ "$result" != "" ]]; then
		colorEcho $BLUE " BBR模块已安装"
		INSTALL_BBR=false
		return
	fi
	res=$(hostnamectl | grep -i openvz)
	if [[ "$res" != "" ]]; then
		colorEcho $BLUE " openvz机器，跳过安装"
		INSTALL_BBR=false
		return
	fi
	echo "net.core.default_qdisc=fq" >>/etc/sysctl.conf
	echo "net.ipv4.tcp_congestion_control=bbr" >>/etc/sysctl.conf
	sysctl -p
	result=$(lsmod | grep bbr)
	if [[ "$result" != "" ]]; then
		colorEcho $GREEN " BBR模块已启用"
		INSTALL_BBR=false
		return
	fi
	colorEcho $BLUE " 安装BBR模块..."
	if [[ "$PMT" == "yum" ]]; then
		if [[ "$V6_PROXY" == "" ]]; then
			rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org
			rpm -Uvh http://www.elrepo.org/elrepo-release-7.0-4.el7.elrepo.noarch.rpm
			$CMD_INSTALL --enablerepo=elrepo-kernel kernel-ml
			$CMD_REMOVE kernel-3.*
			grub2-set-default 0
			echo "tcp_bbr" >>/etc/modules-load.d/modules.conf
			INSTALL_BBR=true
		fi
	else
		$CMD_INSTALL --install-recommends linux-generic-hwe-16.04
		grub-set-default 0
		echo "tcp_bbr" >>/etc/modules-load.d/modules.conf
		INSTALL_BBR=true
	fi
}

#显示nginx和xray状态信息
statusText() {
	res=$(status)
	case $res in
		2) echo -e ${GREEN}已安装${PLAIN} ${RED}未运行${PLAIN} ;;
		3) echo -e ${GREEN}已安装${PLAIN} ${GREEN}Xray正在运行${PLAIN} ;;
		4) echo -e ${GREEN}已安装${PLAIN} ${GREEN}Xray正在运行${PLAIN}, ${RED}Nginx未运行${PLAIN} ;;
		5) echo -e ${GREEN}已安装${PLAIN} ${GREEN}Xray正在运行, Nginx正在运行${PLAIN} ;;
		*) echo -e ${RED}未安装${PLAIN} ;;
	esac
}

#配置v2ray的id
config_v2id() {
	uuid="$(cat '/proc/sys/kernel/random/uuid')"
	if [ -f "${tmp_path}" ];then
		num_e=$(cat "${tmp_path}" | grep -n "level" | sort -nr | sed -n '1p' | cut -d : -f 1)
		later_line=$(sed -n "${num_e}p" ${tmp_path})
		sed -i "${num_e}d" ${tmp_path}
		let num_e-=1
		sed -i "${num_e}a\ ${later_line}," ${tmp_path}
		let num_e+=1
		if [[ "$VLESS" == "false" ]]; then
			sed -i "${num_e}a\    \    \    {\"id\": \"$uuid\",\"level\": 1,\"alterId\": 0\}" ${tmp_path}
		else
			sed -i "${num_e}a\    \    \    {\"id\": \"$uuid\",\"level\": 0\}" ${tmp_path}
		fi
	fi
}

#删除配置文件中v2ray的id
del_v2id() {
	if [ -f "${tmp_path}" ];then
		num=$(cat "${tmp_path}" | grep -n "${uuid}" | cut -d : -f 1)
		sed -i "${num}d" ${tmp_path}
		num_e=$(cat "${tmp_path}" | grep -n "level" | sort -nr | sed -n '1p' | cut -d : -f 1)
		lat_line=$(sed -n "${num_e}p" ${tmp_path} | sed 's/0},/0}/')
		sed -i "${num_e}d" ${tmp_path}
		let num_e-=1
		sed -i "${num_e}a\ ${lat_line}" ${tmp_path}
	fi
}

#获取VPS的架构
archAffix() {
	case "$(uname -m)" in
		i686 | i386) echo '32' ;;
		x86_64 | amd64) echo '64' ;;
		armv5tel) echo 'arm32-v5' ;;
		armv6l) echo 'arm32-v6' ;;
		armv7 | armv7l) echo 'arm32-v7a' ;;
		armv8 | aarch64) echo 'arm64-v8a' ;;
		mips64le) echo 'mips64le' ;;
		mips64) echo 'mips64' ;;
		mipsle) echo 'mips32le' ;;
		mips) echo 'mips32' ;;
		ppc64le) echo 'ppc64le' ;;
		ppc64) echo 'ppc64' ;;
		ppc64le) echo 'ppc64le' ;;
		riscv64) echo 'riscv64' ;;
		s390x) echo 's390x' ;;
		*) colorEcho $RED " 不支持的CPU架构！" && exit 1;;
	esac

	return 0
}

#得到配置文件信息
getConfigFileInfo() {
	vless="false"
	xtls="false"
	trojan="false"
	protocol="VMess"
	kcp="false"
	CONFIG_FILE="/etc/xray/config"
	if [[ "$TROJAN" == "true" ]]; then
		if [[ "$XTLS" == "true" ]]; then
			CONFIG_FILE="${CONFIG_FILE}/03-trojan_XTLS_inbounds.json"
		else
			CONFIG_FILE="${CONFIG_FILE}/02-trojan_inbounds.json"
		fi
	fi
	if [[ "$VLESS" == "false" ]]; then
		# VMESS + kcp
		if [[ "$KCP" == "true" ]]; then
			CONFIG_FILE="${CONFIG_FILE}/05-vmess_KCP_inbounds.json"
		fi
		# VMESS
		if [[ "$TLS" == "false" ]]; then
			CONFIG_FILE="${CONFIG_FILE}/04-vmess_inbounds.json"
		elif [[ "$WS" == "false" ]]; then
			# VMESS+TCP+TLS
			CONFIG_FILE="${CONFIG_FILE}/06-vmess_TLS_inbounds.json"
		# VMESS+WS+TLS
		else
			CONFIG_FILE="${CONFIG_FILE}/07-vmess_WS_inbounds.json"
		fi
	#VLESS
	else
		if [[ "$KCP" == "true" ]]; then
			CONFIG_FILE="${CONFIG_FILE}/11-vless_KCP_inbounds.json"
		fi
		# VLESS+TCP
		if [[ "$WS" == "false" ]]; then
			# VLESS+TCP+TLS
			if [[ "$XTLS" == "false" ]]; then
				CONFIG_FILE="${CONFIG_FILE}/08-vless_TLS_inbounds.json"
			# VLESS+TCP+XTLS
			else
				CONFIG_FILE="${CONFIG_FILE}/09-vless_XTLS_inbounds.json"
			fi
		# VLESS+WS+TLS
		else
			CONFIG_FILE="${CONFIG_FILE}/10-vless_WS_inbounds.json"
		fi
	fi
	# uid=$(grep id $CONFIG_FILE | head -n1 | cut -d: -f2 | tr -d \",' ')
	uid=${uuid}
	if [ ${WS} == false ];then
		alterid=$(grep alterId $CONFIG_FILE | cut -d: -f2 | tr -d \",' ')
	else
		alterid=0
	fi
	network=$(grep network $CONFIG_FILE | tail -n1 | cut -d: -f2 | tr -d \",' ')
	[[ -z "$network" ]] && network="tcp"
	port="${PORT}" #端口
	if [[ "$KCP" == "true" ]]; then
		type=$(grep header -A 3 $CONFIG_FILE | grep 'type' | cut -d: -f2 | tr -d \",' ')
		seed=$(grep seed $CONFIG_FILE | cut -d: -f2 | tr -d \",' ')
	fi
	vmess=$(grep vmess $CONFIG_FILE)
	if [[ "$vmess" == "" ]]; then
		trojan=$(grep trojan $CONFIG_FILE)
		if [[ "$trojan" == "" ]]; then
			vless="true"
			protocol="VLESS"
		else
			trojan="true"
			password=$(grep password $CONFIG_FILE | cut -d: -f2 | tr -d \",' ')
			protocol="trojan"
		fi
		encryption="none"
		xtls=$(grep xtlsSettings $CONFIG_FILE)
		if [[ "$xtls" != "" ]]; then
			xtls="true"
			flow=$(grep flow $CONFIG_FILE | cut -d: -f2 | tr -d \",' ')
		else
			flow="无"
		fi
	fi
}

#处理重复账号
Delete() {
	if [ -f ./account_link.txt ];then
		[[ -n "$(egrep "\<${DOMAIN}\>" ./account_link.txt)" ]] && sed -in "/\<${DOMAIN}\>/d" ./account_link.txt
		[ -f ./account_link.txtn ] && rm ./account_link.txtn
	fi
}

outputVmess() {
	raw="{
  \"v\":\"2\",
  \"ps\":\"\",
  \"add\":\"$IP\",
  \"port\":\"${port}\",
  \"id\":\"${uid}\",
  \"aid\":\"$alterid\",
  \"net\":\"tcp\",
  \"type\":\"none\",
  \"host\":\"\",
  \"path\":\"\",
  \"tls\":\"\"
}"
	link=$(echo -n ${raw} | base64 -w 0)
	link="vmess://${link}"

	echo -e "   ${BLUE}IP(address): ${PLAIN} ${RED}${IP}${PLAIN}"
	echo -e "   ${BLUE}端口(port)：${PLAIN}${RED}${port}${PLAIN}"
	echo -e "   ${BLUE}id(uuid)：${PLAIN}${RED}${uid}${PLAIN}"
	echo -e "   ${BLUE}额外id(alterid)：${PLAIN} ${RED}${alterid}${PLAIN}"
	echo -e "   ${BLUE}加密方式(security)：${PLAIN} ${RED}auto${PLAIN}"
	echo -e "   ${BLUE}传输协议(network)：${PLAIN} ${RED}${network}${PLAIN}"
	echo -e "   ${BLUE}vmess链接:${PLAIN} $RED$link$PLAIN"
	[ ! -f "${backup}" ] && touch "${backup}"
	echo -e "\nIP地址:${IP} 类型:Vmess 传输协议:${network} 端口(port):${port} xray_id:${uid}\n" >> "${backup}"
	echo -e "${IP}_${network}\n${link}\n\n" >> ./account_link.txt
}

outputVmessKCP() {
	echo -e "   ${BLUE}IP(address): ${PLAIN} ${RED}${IP}${PLAIN}"
	echo -e "   ${BLUE}端口(port)：${PLAIN}${RED}${port}${PLAIN}"
	echo -e "   ${BLUE}id(uuid)：${PLAIN}${RED}${uid}${PLAIN}"
	echo -e "   ${BLUE}额外id(alterid)：${PLAIN} ${RED}${alterid}${PLAIN}"
	echo -e "   ${BLUE}加密方式(security)：${PLAIN} ${RED}auto${PLAIN}"
	echo -e "   ${BLUE}传输协议(network)：${PLAIN} ${RED}${network}${PLAIN}"
	echo -e "   ${BLUE}伪装类型(type)：${PLAIN} ${RED}${type}${PLAIN}"
	echo -e "   ${BLUE}mkcp seed：${PLAIN} ${RED}${seed}${PLAIN}"
	[ ! -f "${backup}" ] && touch "${backup}"
	echo -e "\nIP地址:${IP} 类型:VmessKCP 传输协议:${network} 端口(port):${port} xray_id:${uid}\n" >> "${backup}"
	echo -e "${IP}_${network}\nIP(address):${IP} 端口(port):${port} 传输协议:${network} xray_id:${uid} mkcp seed:${seed}\n\n" >> ./account_link.txt
}

outputTrojan() {
	if [[ "$xtls" == "true" ]]; then
		link="trojan://${password}@${DOMAIN}:${port}#"
		echo -e "   ${BLUE}IP/域名(address): ${PLAIN} ${RED}${DOMAIN}${PLAIN}"
		echo -e "   ${BLUE}端口(port)：${PLAIN}${RED}${port}${PLAIN}"
		echo -e "   ${BLUE}密码(password)：${PLAIN}${RED}${password}${PLAIN}"
		echo -e "   ${BLUE}流控(flow)：${PLAIN}$RED$flow${PLAIN}"
		echo -e "   ${BLUE}加密(encryption)：${PLAIN} ${RED}none${PLAIN}"
		echo -e "   ${BLUE}传输协议(network)：${PLAIN} ${RED}${network}${PLAIN}"
		echo -e "   ${BLUE}底层安全传输(tls)：${PLAIN}${RED}XTLS${PLAIN}"
		echo -e "   ${BLUE}Trojan链接:${PLAIN} $RED$link$PLAIN"
	else
		link="trojan://${password}@${DOMAIN}:${port}#"
		echo -e "   ${BLUE}IP/域名(address): ${PLAIN} ${RED}${DOMAIN}${PLAIN}"
		echo -e "   ${BLUE}端口(port)：${PLAIN}${RED}${port}${PLAIN}"
		echo -e "   ${BLUE}密码(password)：${PLAIN}${RED}${password}${PLAIN}"
		echo -e "   ${BLUE}传输协议(network)：${PLAIN} ${RED}${network}${PLAIN}"
		echo -e "   ${BLUE}底层安全传输(tls)：${PLAIN}${RED}TLS${PLAIN}"
		echo -e "   ${BLUE}Trojan链接:${PLAIN} $RED$link$PLAIN"
	fi
	[ ! -f "${backup}" ] && touch "${backup}"
	echo -e "\n伪装域名:${DOMAIN} 类型:Trojan 传输协议:${network} 底层传输:TLS 端口(port):${port} 密码:${password}\n" >> "${backup}"
	echo -e "${DOMAIN}_${network}\n${link}\n\n" >> ./account_link.txt
}

outputVmessTLS() {
	raw="{
  \"v\":\"2\",
  \"ps\":\"ps_${DOMAIN}\",
  \"add\":\"${DOMAIN}\",
  \"port\":\"${port}\",
  \"id\":\"${uid}\",
  \"aid\":\"$alterid\",
  \"net\":\"${network}\",
  \"type\":\"none\",
  \"host\":\"${DOMAIN}\",
  \"path\":\"\",
  \"tls\":\"tls\"
}"
	link=$(echo -n ${raw} | base64 -w 0)
	link="vmess://${link}"
	echo -e "   ${BLUE}端口(port)：${PLAIN}${RED}${port}${PLAIN}"
	echo -e "   ${BLUE}id(uuid)：${PLAIN}${RED}${uid}${PLAIN}"
	echo -e "   ${BLUE}额外id(alterid)：${PLAIN} ${RED}${alterid}${PLAIN}"
	echo -e "   ${BLUE}加密方式(security)：${PLAIN} ${RED}none${PLAIN}"
	echo -e "   ${BLUE}传输协议(network)：${PLAIN} ${RED}${network}${PLAIN}"
	echo -e "   ${BLUE}伪装域名/主机名(host)/SNI/peer名称：${PLAIN}${RED}${DOMAIN}${PLAIN}"
	echo -e "   ${BLUE}底层安全传输(tls)：${PLAIN}${RED}TLS${PLAIN}"
	echo -e "   ${BLUE}vmess链接: ${PLAIN}$RED$link$PLAIN"
	[ ! -f "${backup}" ] && touch "${backup}"
	echo -e "\n伪装域名:${DOMAIN} 类型:VmessTLS 传输协议:${network} 底层传输:TLS 端口(port):${port} xray_id:${uid}\n" >> "${backup}"
	Delete; echo -e "${DOMAIN}_${network}\n${link}\n\n" >> ./account_link.txt
}

outputVmessWS() {
	raw="{
  \"v\":\"2\",
  \"ps\":\"ps_${DOMAIN}\",
  \"add\":\"${DOMAIN}\",
  \"port\":\"${port}\",
  \"id\":\"${uid}\",
  \"aid\":\"$alterid\",
  \"net\":\"${network}\",
  \"type\":\"none\",
  \"host\":\"${DOMAIN}\",
  \"path\":\"${WSPATH}\",
  \"tls\":\"tls\"
}"
	link=$(echo -n ${raw} | base64 -w 0)
	link="vmess://${link}"

	echo -e "   ${BLUE}端口(port)：${PLAIN}${RED}${port}${PLAIN}"
	echo -e "   ${BLUE}id(uuid)：${PLAIN}${RED}${uid}${PLAIN}"
	echo -e "   ${BLUE}额外id(alterid)：${PLAIN} ${RED}${alterid}${PLAIN}"
	echo -e "   ${BLUE}加密方式(security)：${PLAIN} ${RED}none${PLAIN}"
	echo -e "   ${BLUE}传输协议(network)：${PLAIN} ${RED}${network}${PLAIN}"
	echo -e "   ${BLUE}伪装类型(type)：${PLAIN}${RED}none$PLAIN"
	echo -e "   ${BLUE}伪装域名/主机名(host)/SNI/peer名称：${PLAIN}${RED}${DOMAIN}${PLAIN}"
	echo -e "   ${BLUE}路径(path)：${PLAIN}${RED}${WSPATH}${PLAIN}"
	echo -e "   ${BLUE}底层安全传输(tls)：${PLAIN}${RED}TLS${PLAIN}"
	echo -e "   ${BLUE}vmess链接:${PLAIN} $RED$link$PLAIN"
	[ ! -f "${backup}" ] && touch "${backup}"
	echo -e "\n伪装域名:${DOMAIN} 类型:VmessWS 传输协议:${network} 底层传输:TLS 端口(port):${port} xray_id:${uid} 伪装路径:${WSPATH}\n" >> "${backup}"
	Delete; echo -e "${DOMAIN}_${network}\n${link}\n\n" >> ./account_link.txt
}


#显示信息
showInfo() {
	res=$(status)
	if [[ $res -lt 2 ]]; then
		colorEcho $RED " Xray未安装，请先安装！"
		return 1
	fi

	echo ""
	echo -n -e " ${BLUE}Xray运行状态：${PLAIN}"
	statusText
	echo -e " ${BLUE}Xray配置文件: ${PLAIN} ${RED}${CONFIG_FILE}${PLAIN}"
	colorEcho $BLUE " Xray配置信息："

	getConfigFileInfo

	echo -e "   ${BLUE}协议: ${PLAIN} ${RED}${protocol}${PLAIN}"
	if [[ "$trojan" == "true" ]]; then
		outputTrojan
		return 0
	fi
	if [[ "$vless" == "false" ]]; then
		if [[ "$kcp" == "true" ]]; then
			outputVmessKCP
			return 0
		fi
		if [[ "$TLS" == "false" ]]; then
			outputVmess
		elif [[ "$WS" == "false" ]]; then
			outputVmessTLS
		else
			outputVmessWS
		fi
	else
		if [[ "$kcp" == "true" ]]; then
			echo -e "   ${BLUE}IP(address): ${PLAIN} ${RED}${IP}${PLAIN}"
			echo -e "   ${BLUE}端口(port)：${PLAIN}${RED}${port}${PLAIN}"
			echo -e "   ${BLUE}id(uuid)：${PLAIN}${RED}${uid}${PLAIN}"
			echo -e "   ${BLUE}加密(encryption)：${PLAIN} ${RED}none${PLAIN}"
			echo -e "   ${BLUE}传输协议(network)：${PLAIN} ${RED}${network}${PLAIN}"
			echo -e "   ${BLUE}伪装类型(type)：${PLAIN} ${RED}${type}${PLAIN}"
			echo -e "   ${BLUE}mkcp seed：${PLAIN} ${RED}${seed}${PLAIN}"
			[ ! -f "${backup}" ] && touch "${backup}"
			echo -e "\nIP地址:${IP} 类型:VlessKCP 传输协议:${network} xray_id:${uid}\n" >> "${backup}"
			echo -e "${IP}_${network}\nIP(address):${IP} 端口(port):${port} 传输协议:${network} xray_id:${uid} mkcp seed:${seed}\n\n" >> ./account_link.txt
			return 0
		fi
		if [[ "$xtls" == "true" ]]; then
			link="vless://${uid}@${DOMAIN}:${port}?encryption=none&security=xtls&type=tcp&host=${DOMAIN}&headerType=none&flow=xtls-rprx-direct#PS_${DOMAIN}"
			echo -e " ${BLUE}IP(address): ${PLAIN} ${RED}${IP}${PLAIN}"
			echo -e " ${BLUE}端口(port)：${PLAIN}${RED}${port}${PLAIN}"
			echo -e " ${BLUE}id(uuid)：${PLAIN}${RED}${uid}${PLAIN}"
			echo -e " ${BLUE}流控(flow)：${PLAIN}$RED$flow${PLAIN}"
			echo -e " ${BLUE}加密(encryption)：${PLAIN} ${RED}none${PLAIN}"
			echo -e " ${BLUE}传输协议(network)：${PLAIN} ${RED}${network}${PLAIN}"
			echo -e " ${BLUE}伪装类型(type)：${PLAIN}${RED}none$PLAIN"
			echo -e " ${BLUE}伪装域名/主机名(host)/SNI/peer名称：${PLAIN}${RED}${DOMAIN}${PLAIN}"
			echo -e " ${BLUE}底层安全传输(tls)：${PLAIN}${RED}XTLS${PLAIN}"
			echo -e "   ${BLUE}vless链接:${PLAIN} $RED$link$PLAIN"
			[ ! -f "${backup}" ] && touch "${backup}"
			echo -e "\n伪装域名:${DOMAIN} 类型:VlessXTLS 传输协议:${network} 底层传输:TLS 端口(port):${port} xray_id:${uid} 流控(flow):$flow\n" >> "${backup}"
			Delete; echo -e "${DOMAIN}_${network}\n${link}\n\n" >> ./account_link.txt
		elif [[ "$WS" == "false" ]]; then
			link="vless://${uid}@${DOMAIN}:${port}?security=tls&encryption=none&host=${DOMAIN}&headerType=none&type=tcp#PS_${DOMAIN}"
			echo -e " ${BLUE}IP(address):  ${PLAIN}${RED}${IP}${PLAIN}"
			echo -e " ${BLUE}端口(port)：${PLAIN}${RED}${port}${PLAIN}"
			echo -e " ${BLUE}id(uuid)：${PLAIN}${RED}${uid}${PLAIN}"
			echo -e " ${BLUE}流控(flow)：${PLAIN}$RED$flow${PLAIN}"
			echo -e " ${BLUE}加密(encryption)：${PLAIN} ${RED}none${PLAIN}"
			echo -e " ${BLUE}传输协议(network)：${PLAIN} ${RED}${network}${PLAIN}"
			echo -e " ${BLUE}伪装类型(type)：${PLAIN}${RED}none$PLAIN"
			echo -e " ${BLUE}伪装域名/主机名(host)/SNI/peer名称：${PLAIN}${RED}${DOMAIN}${PLAIN}"
			echo -e " ${BLUE}底层安全传输(tls)：${PLAIN}${RED}TLS${PLAIN}"
			echo -e "   ${BLUE}vless链接:${PLAIN} $RED$link$PLAIN"
			[ ! -f "${backup}" ] && touch "${backup}"
			echo -e "\n伪装域名:${DOMAIN} 类型:Vless 传输协议:${network} 底层传输:TLS 端口(port):${port} xray_id:${uid} 流控(flow):$flow\n" >> "${backup}"
			Delete; echo -e "${DOMAIN}_${network}\n${link}\n\n" >> ./account_link.txt	
		else
			tmpWSPATH=$(echo "${WSPATH}" | sed 's/\///g')
			link="vless://${uid}@${DOMAIN}:${port}?encryption=none&security=tls&type=ws&host=${DOMAIN}&path=%2f${tmpWSPATH}#PS_${DOMAIN}"
			echo -e " ${BLUE}IP(address): ${PLAIN} ${RED}${IP}${PLAIN}"
			echo -e " ${BLUE}端口(port)：${PLAIN}${RED}${port}${PLAIN}"
			echo -e " ${BLUE}id(uuid)：${PLAIN}${RED}${uid}${PLAIN}"
			echo -e " ${BLUE}流控(flow)：${PLAIN}$RED$flow${PLAIN}"
			echo -e " ${BLUE}加密(encryption)：${PLAIN} ${RED}none${PLAIN}"
			echo -e " ${BLUE}传输协议(network)：${PLAIN} ${RED}${network}${PLAIN}"
			echo -e " ${BLUE}伪装类型(type)：${PLAIN}${RED}none$PLAIN"
			echo -e " ${BLUE}伪装域名/主机名(host)/SNI/peer名称：${PLAIN}${RED}${DOMAIN}${PLAIN}"
			echo -e " ${BLUE}路径(path)：${PLAIN}${RED}${WSPATH}${PLAIN}"
			echo -e " ${BLUE}底层安全传输(tls)：${PLAIN}${RED}TLS${PLAIN}"
			echo -e "   ${BLUE}vless链接:${PLAIN} $RED$link$PLAIN"
			[ ! -f "${backup}" ] && touch "${backup}"
			echo -e "\n伪装域名:${DOMAIN} 类型:VlessWS 传输协议:${network} 底层传输:TLS 端口(port):${port} xray_id:${uid} 伪装路径:${WSPATH} 流控(flow):$flow\n" >> "${backup}"
			Delete; echo -e "${DOMAIN}_${network}\n${link}\n\n" >> ./account_link.txt			
			
		fi

	fi
}

#检测批量搭建的域名证书
check_ssl() {
	error_list=
	for i in $(cat ./name.txt)
	do
		if [[ ! -f ./ssl/${i}.crt ]];then
			error_list="${error_list}\n 没有找到${i}.crt 证书。"
		else
			if [ "$(cat ./ssl/${i}.crt | sed -n '/--END /p;/--BEGIN /p' | wc -l )" != "2" ];then
				error_list="${error_list}\n ${i}.crt 证书内容不完整。"			
			fi
		fi

		if [ ! -f ./ssl/${i}.key ];then
			error_list="${error_list}\n 没有找到${i}.key 证书。"
		else
			if [ "$(cat ./ssl/${i}.key | sed -n '/--END /p;/--BEGIN /p' | wc -l )" != "2" ];then
				error_list="${error_list}\n ${i}.key 证书内容不完整。"			
			fi
		fi
	done

	if [ ! -z "${error_list}" ];then
		echo -e "缺少证书或者证书不完整，请到对应的域名中申请一下证书:\n${error_list}\n"
		exit
	fi
	clear

}

#创建文件型swap分区
create_swap() {
	echo ""
	[ -z "${swap_select}" ] && read -p "$(echo -e "是否创建swap文件[y|n] [${magenta}默认是y$none]:")" swap_select
	[ -z "${swap_select}" ] && swap_select=y
	if [ "${swap_select}" == "y" ]
	then
		echo ""
		[ -z "${swap_num}" ] && read -p "$(echo -e "请输入虚拟机内存的大小 [${magenta}默认是4096MB$none]:")" swap_num
		[ -z "${swap_num}" ] && swap_num=4096
		echo ""
		echo -e "${magenta}正在创建swap分区，大小是${swap_num}MB$none"
		echo ""
		dd if=/dev/zero of=/mnt/swap bs=1M count=${swap_num}
		test -e /mnt/swap &&  chmod 600 /mnt/swap || error
		mkswap /mnt/swap
		swapon /mnt/swap
		[ -z "$(swapon -s | grep /mnt/swap)" ] && echo "swap分区没有挂载成功"
		echo '/mnt/swap   swap   swap   defaults  0   0' | tee -a /etc/fstab
		[ -z "$(mount -a)" ] && echo "swap创建成功" || echo "swap创建没有成功"
	elif [ "${swap_select}" == "n" ]
	then
		echo ""
		echo "已选择不安装swap分区"
	fi

}

#获取伪装路径
get_wspath() {
	which xray &>/dev/null
	if [ "$?" == "0" ];then
		CONFIG_FILE="/etc/xray/config"
		if [[ "$TROJAN" == "true" ]]; then
			if [[ "$XTLS" == "true" ]]; then
				CONFIG_FILE="${CONFIG_FILE}/03-trojan_XTLS_inbounds.json"
			else
				CONFIG_FILE="${CONFIG_FILE}/02-trojan_inbounds.json"
			fi
		fi
		if [[ "$VLESS" == "false" ]]; then
			# VMESS + kcp
			if [[ "$KCP" == "true" ]]; then
				CONFIG_FILE="${CONFIG_FILE}/05-vmess_KCP_inbounds.json"
			fi
			# VMESS
			if [[ "$TLS" == "false" ]]; then
				CONFIG_FILE="${CONFIG_FILE}/04-vmess_inbounds.json"
			elif [[ "$WS" == "false" ]]; then
				# VMESS+TCP+TLS
				CONFIG_FILE="${CONFIG_FILE}/06-vmess_TLS_inbounds.json"
			# VMESS+WS+TLS
			else
				CONFIG_FILE="${CONFIG_FILE}/07-vmess_WS_inbounds.json"
			fi
		#VLESS
		else
			if [[ "$KCP" == "true" ]]; then
				CONFIG_FILE="${CONFIG_FILE}/11-vless_KCP_inbounds.json"
			fi
			# VLESS+TCP
			if [[ "$WS" == "false" ]]; then
				# VLESS+TCP+TLS
				if [[ "$XTLS" == "false" ]]; then
					CONFIG_FILE="${CONFIG_FILE}/08-vless_TLS_inbounds.json"
				# VLESS+TCP+XTLS
				else
					CONFIG_FILE="${CONFIG_FILE}/09-vless_XTLS_inbounds.json"
				fi
			# VLESS+WS+TLS
			else
				CONFIG_FILE="${CONFIG_FILE}/10-vless_WS_inbounds.json"
			fi
		fi
		if [ -f "${CONFIG_FILE}" ];then
			WSPATH=$(cat ${CONFIG_FILE} | grep 'path' | sed 's/"//g;s/,//g;s/ //g' | cut -d : -f 2)
			if [ $(echo ${WSPATH} | wc -c) != "38" ];then
				echo -e "\n${red} 没有获取到伪装路径 ${none}"
				exit
			else
				CONFIG_FILE="/etc/xray/config"
			fi
		fi
	else
		echo -e "\n${red}没有安装xray，需要先安装xray${none}\n"
		exit	
	fi
}

#获取xray监听端口
get_Xport() {
	which xray &>/dev/null
	if [ "$?" == "0" ];then
		CONFIG_FILE="/etc/xray/config"
		if [[ "$TROJAN" == "true" ]]; then
			if [[ "$XTLS" == "true" ]]; then
				CONFIG_FILE="${CONFIG_FILE}/03-trojan_XTLS_inbounds.json"
			else
				CONFIG_FILE="${CONFIG_FILE}/02-trojan_inbounds.json"
			fi
		fi
		if [[ "$VLESS" == "false" ]]; then
			# VMESS + kcp
			if [[ "$KCP" == "true" ]]; then
				CONFIG_FILE="${CONFIG_FILE}/05-vmess_KCP_inbounds.json"
			fi
			# VMESS
			if [[ "$TLS" == "false" ]]; then
				CONFIG_FILE="${CONFIG_FILE}/04-vmess_inbounds.json"
			elif [[ "$WS" == "false" ]]; then
				# VMESS+TCP+TLS
				CONFIG_FILE="${CONFIG_FILE}/06-vmess_TLS_inbounds.json"
			# VMESS+WS+TLS
			else
				CONFIG_FILE="${CONFIG_FILE}/07-vmess_WS_inbounds.json"
			fi
		#VLESS
		else
			if [[ "$KCP" == "true" ]]; then
				CONFIG_FILE="${CONFIG_FILE}/11-vless_KCP_inbounds.json"
			fi
			# VLESS+TCP
			if [[ "$WS" == "false" ]]; then
				# VLESS+TCP+TLS
				if [[ "$XTLS" == "false" ]]; then
					CONFIG_FILE="${CONFIG_FILE}/08-vless_TLS_inbounds.json"
				# VLESS+TCP+XTLS
				else
					CONFIG_FILE="${CONFIG_FILE}/09-vless_XTLS_inbounds.json"
				fi
			# VLESS+WS+TLS
			else
				CONFIG_FILE="${CONFIG_FILE}/10-vless_WS_inbounds.json"
			fi
		fi
		if [ -f "${CONFIG_FILE}" ];then
			XPORT=$(cat ${CONFIG_FILE} | grep 'port' | cut -d : -f 2 | sed 's/,//g;s/ //g')
			if [[ -z "${XPORT}" || "$(echo ${XPORT} | sed "s/[0-9]//g")" != "" ]];then
				echo -e "\n${red} 没有获取到xray监听端口 ${none}\n"
				exit
			else
				CONFIG_FILE="/etc/xray/config"
				echo -e "\n${yellow} xray监听端口${XPORT} ${none}\n"
			fi
		fi
	else
		echo -e "\n${red}没有安装xray，需要先安装xray${none}\n"
		exit	
	fi
}

#批量自动安装
auto_install() {
if [[ ! -f ./name.txt || ! -e ./ssl ]];then
	test ! -e ./name.txt && echo -e "\n${red}域名的配置文件name.txt没有找到，已经创建好了${none}\n" && touch ./name.txt
	test ! -e ./ssl && echo -e "\n${red}没有找到存放域名证书的目录ssl，已经创建好了。${none}\n" && mkdir -p ./ssl
	echo "###########################################################"
	echo -e "#                     ${RED}温馨提示${PLAIN}                            #"
	echo -e "# ${YELLOW}    批量搭建需要提前将域名证书存放到ssl目录中。${PLAIN}         #"
	echo -e "# ${YELLOW}    批量搭建需要提前将域名存放到name.txt文档中。${PLAIN}        #"
	echo "###########################################################"
	exit
fi
sed -i "/^$/d" ./name.txt		#删除文档中的空行
sed -i 's/ //g' ./name.txt		#删除文档中的空格
check_ssl		#检查域名需要的证书的函数
optimize_set	#系统优化设置
security_set	#VPS安全设置

# if [ ! -f /usr/bin/vspeed ];then
# 	install_speed_check 1	#安装流量监控脚本
# fi

$PMT clean all
[[ "$PMT" == "apt" ]] && $PMT update
#echo $CMD_UPGRADE | bash
$CMD_INSTALL wget curl sudo vim unzip tar gcc openssl
$CMD_INSTALL net-tools
if [[ "$PMT" == "apt" ]]; then
	$CMD_INSTALL libssl-dev g++
fi
res=$(which unzip 2>/dev/null)
if [[ $? -ne 0 ]]; then
	colorEcho $RED " unzip安装失败，请检查网络"
	exit 1
fi

# #创建swap分区
if [[ ! -f /mnt/swap ]]
then
	swap_select="y"
	swap_num=4096
	create_swap
fi
#判断VPS上是否安装nginx，没有安装就安装上
res=$(which nginx 2>/dev/null)
if [[ "$?" != "0" ]]; then
	installNginx	#安装nginx
fi
colorEcho $BLUE " 安装Xray..."
getVersion		#获取xray版本号
RETVAL="$?"
if [[ $RETVAL == 0 ]]; then
	colorEcho $BLUE " Xray最新版 ${CUR_VER} 已经安装"
elif [[ $RETVAL == 3 ]]; then
	exit 1
else
	colorEcho $BLUE " 安装Xray ${NEW_VER} ，架构$(archAffix)"
	installXray		#安装xray程序
fi

#设置xray监听端口
get_Xport	#获取监听端口
if [ -z "${XPORT}" ];then
	XPORT=$(shuf -i10000-65000 -n1) #生成v2ray的端口
fi

#伪装路径默认设置为uuid。
echo ""
get_wspath		#获取伪装路径
if [ -z "${WSPATH}" ];then
	ws=$(cat /proc/sys/kernel/random/uuid)
	WSPATH="/$ws"
	colorEcho ${BLUE} " ws路径：$WSPATH"
fi

num_print=1
while true
do
	CONFIG_FILE="/etc/xray/config"
	DOMAIN=$(sed -n "${num_print}p" ./name.txt)
	DOMAIN=${DOMAIN,,}
	if [ -z "${DOMAIN}" ];then
		echo ""
		start		#启动nginx和xray
		break
	fi
	account_class=n		#定义账号为CDN账号
	print_bbr="false"	#不显示安装bbr加速选项
	getData		#获取相关信息

	configNginx		#配置nginx
	configXray		#配置xray
	showInfo		#显示信息
	sleep 2
	if [[ ! -f "${NGINX_CONF_PATH}/${DOMAIN}.conf" ]];then
		error_info="${error_info}\n域名 ${DOMAIN} 没有搭建成功！"
	fi
	let num_print+=1
done

#显示没有设置上的选项
if [[ ! -z "${error_info}" ]];then
	echo -e "以下是没有设置上的项目：\n${red}${error_info}${none}\n"
fi

#判断脚本是否需要重启系统
if [ "${if_reboot}" != "0" ];then
	echo -e "${red}\n登录配置文件/etc/ssh/sshd_config文件有错误请检查完后再断开终端，否则登录不上了${none}\n"
	read -sp "回车后退出脚本"
	exit
else
	echo ""
	read -sp "$(echo -e "${green}回车后重启系统${none}")"
	reboot
fi

}

#安装
install() {
	getData		#输入域名、获取伪装网址

	#软件管理器清理+更新软件源列表+安装需要的依赖程序
	$PMT clean all
	[[ "$PMT" == "apt" ]] && $PMT update
	#echo $CMD_UPGRADE | bash
	$CMD_INSTALL wget curl sudo vim unzip tar gcc openssl
	$CMD_INSTALL net-tools
	if [[ "$PMT" == "apt" ]]; then
		$CMD_INSTALL libssl-dev g++
	fi
	res=$(which unzip 2>/dev/null)
	if [[ $? -ne 0 ]]; then
		colorEcho $RED " unzip安装失败，请检查网络"
		exit 1
	fi
	optimize_set		#系统优化设置
	#判断VPS上是否安装nginx，没有安装就安装上
	res=$(which nginx 2>/dev/null)
	if [[ "$?" != "0" ]]; then
		installNginx	#安装nginx
	fi
	
	security_set		#系统安全设置包括防火墙、ssh配置文件设置。
	#开启websockt协议，选择了搭建直连，会自动申请证书。
	if [[ "$TLS" == "true" || "$XTLS" == "true" ]]; then
		if [ "${account_class}" == y ];then
			getCert		#自动申请let免费证书
		fi
	fi
	colorEcho $BLUE " 安装Xray..."
	getVersion		#获取xray版本号
	RETVAL="$?"
	if [[ $RETVAL == 0 ]]; then
		colorEcho $BLUE " Xray最新版 ${CUR_VER} 已经安装"
	elif [[ $RETVAL == 3 ]]; then
		exit 1
	else
		colorEcho $BLUE " 安装Xray ${NEW_VER} ，架构$(archAffix)"
		installXray		#安装xray程序
	fi
	get_wspath	#获取伪装路径
	get_Xport	#获取xray监听端口
	configNginx		#配置nginx
	configXray		#配置xray
	installBBR		#安装bbr加速
	echo ""
	start			#启动xray和nginx

	# if [ ! -f /usr/bin/vspeed ];then
	# 	install_speed_check	1	#安装监控脚本
	# fi

	showInfo		#显示搭建账号的信息
	reboot_check	#检查是否有报错的，没有报错的重启VPS
}

#卸载xary
uninstall() {
	res=$(status)
	if [[ $res -lt 2 ]]; then
		colorEcho $RED " Xray未安装，请先安装！"
		return
	fi
	echo ""
	read -p " 确定卸载Xray？[y/n]：" answer
	if [[ "${answer,,}" == "y" ]]; then
		domain=$(grep Host $CONFIG_FILE | cut -d: -f2 | tr -d \",' ')
		if [[ "$domain" == "" ]]; then
			domain=$(grep serverName $CONFIG_FILE | cut -d: -f2 | tr -d \",' ')
		fi
		stop
		systemctl disable xray
		rm -rf /etc/systemd/system/xray.service
		rm -rf /usr/local/bin/xray
		rm -rf /usr/local/etc/xray
		rm -rf /etc/xray
		if [[ "$BT" == "false" ]]; then
			systemctl disable nginx
			$CMD_REMOVE nginx
			if [[ "$PMT" == "apt" ]]; then
				$CMD_REMOVE nginx-common
			fi
			rm -rf /etc/nginx/nginx.conf
			if [[ -f /etc/nginx/nginx.conf.bak ]]; then
				mv /etc/nginx/nginx.conf.bak /etc/nginx/nginx.conf
			fi
		fi
		rm -rf ${NGINX_CONF_PATH}/*.conf &>/dev/null
		[[ -f ~/.acme.sh/acme.sh ]] && ~/.acme.sh/acme.sh --uninstall
		colorEcho $GREEN " Xray卸载成功"
	fi
}

# 判断
Check_value() {
	#	判断域名
	if [[ -n "$(echo ${DOMAIN}|grep '\.')" \
	&& ${DOMAIN} =~ ^[a-zA-Z0-9][-a-zA-Z0-9]{0,62}(\.[a-zA-Z0-9][-a-zA-Z0-9]{0,62})+[a-zA-Z]+$ ]];then	#检查输入的域名是否符合规则
		echo -e  "\n正在修改 ${DOMAIN}\n"
	else
		error_info="${error_info}\n${DOMAIN}";return 1
	fi	
	# 判断端口
	[[ -z ${port} || ! ${port} =~ ^[0-9]+$ ]] && error_info="${error_info}\n${DOMAIN}" && return 1
	# 判断用户id
	[[ -z "${uid}" ||  "$(echo ${uid} | wc -c )" != "37" ]] && error_info="${error_info}\n${DOMAIN}" && return 1
	# 判断伪装路径
	[[ -z "${WSPATH}" ||  "$(echo ${WSPATH} | wc -c )" != "38" ]] && error_info="${error_info}\n${DOMAIN}" && return 1
    return 0
}

# 批量生成分享链接
Create_Link() {
	[ -f ./account_link.txt ] && rm account_link.txt
	[ ! -f "${backup}" ] && colorEcho $RED " 当前系统没有搭建xray账号" && sleep 2 && return 1
	error_info=	#存放错误日志
	while read line;do
		[ -z "${line}" ] && continue
		DOMAIN="$(echo ${line} | awk -F"[: ]" '{print $2}')"
		network="$(echo ${line} | awk -F"[: ]" '{print $6}')"
		port="$(echo ${line} | awk -F"[: ]" '{print $10}')"
		uid="$(echo ${line} | awk -F"[: ]" '{print $12}')"
		alterid=0
		WSPATH="$(echo ${line} | awk -F"[: ]" '{print $14}')"
		Check_value; [ $? != 0 ] && continue
		raw="{
  \"v\":\"2\",
  \"ps\":\"ps_${DOMAIN}\",
  \"add\":\"${DOMAIN}\",
  \"port\":\"${port}\",
  \"id\":\"${uid}\",
  \"aid\":\"$alterid\",
  \"net\":\"${network}\",
  \"type\":\"none\",
  \"host\":\"${DOMAIN}\",
  \"path\":\"${WSPATH}\",
  \"tls\":\"tls\"
}"
		link=$(echo -n ${raw} | base64 -w 0)
		link="vmess://${link}"
		echo -e "${DOMAIN}_${network}\n${link}\n\n" >> ./account_link.txt
		if [[ -n "$(egrep "\<${DOMAIN}_${network}\>" ./account_link.txt)" ]];then
			echo -e "\n  ${GREEN}生成 ${DOMAIN} 分享链接成功${PLAIN}\n" 
		else
			error_info="${error_info}\n${DOMAIN}"
		fi
	done < "${backup}"
	if [ -n "${error_info}" ];then
		echo -e "下面是没有生成分享链接的域名：\n${error_info}"
		read -sp "回车返回菜单"
	else
		read -sp "全部修改成功，回车返回菜单"
	fi
}

#域名管理
domain_manage() {
	while true
	do
		clear
		echo "###########################################################"
		echo -e "#                     ${RED}域名账号管理${PLAIN}                            #"
		echo "###########################################################"
		echo -e "  ${GREEN}1.${PLAIN}   查看所有账号"
		echo -e "  ${GREEN}2.${PLAIN}   添加域名账号【支持添加VMESS+WS+TLS或者VLESS+WS+TLS账号】${PLAIN}"
		echo -e "  ${GREEN}3.${PLAIN}   删除域名账号"
		echo -e "  ${GREEN}4.${PLAIN}   生成所有账号的分享链接【仅支持vmess】"
		echo -en "\n${yellow}请选择操作[按 q 退出脚本]：${none}"
		read select_num
		case ${select_num} in
			1)
				if [ -f "${backup}" ];then
					cat "${backup}"
				fi
				echo ""
				exit 1
				;;
			2)
				while true
				do
					account_class=
					echo ""
					echo -e "  ${GREEN}1.${PLAIN}   安装Xray-${BLUE}VMESS+WS+TLS${PLAIN}${RED}${PLAIN}"
					echo -e "  ${GREEN}2.${PLAIN}   安装Xray-${BLUE}VLESS+WS+TLS${PLAIN}${RED}${PLAIN}"
					echo -en "\n${yellow}请选择操作[按 q 返回]：${none}"
					read select_account_class
					if [ "${select_account_class}" == "1" ];then
						TLS="true" && WS="true" && print_bbr="false" && VLESS="false"
					elif [ "${select_account_class}" == "2" ];then
						VLESS="true" && TLS="true" && WS="true" && print_bbr="false"
					elif [ "${select_account_class}" == "q" ];then
						break
					else
						echo -e "${red}请按照提示操作${none}"
						sleep 3
						continue
					fi
					DOMAIN=
					get_wspath	#获取伪装路径
					get_Xport	#获取xray监听端口
					getData		#获取域名，伪装网址、伪装类型，是否开启bbr加速
					if [ "${account_class}" == y ];then
						$PMT clean all
						$CMD_INSTALL wget curl sudo vim unzip tar gcc openssl
						$CMD_INSTALL net-tools
						if [[ "$PMT" == "apt" ]]; then
							$CMD_INSTALL libssl-dev g++
						fi
						getCert		#自动申请let免费证书
					fi
					configNginx		#配置nginx
					configXray		#配置xray
					Allow_Port		#防火墙放行端口
					showInfo		#显示搭建账号的信息
					echo ""
					start			#启动xray和nginx
					echo ""
					echo ""
					read -sp "请记录好账号信息，回车后返回菜单"
					break
				done
				;;
			3)
				while true
				do
					test ! -e /etc/nginx/conf.d && echo "VPS中没有检测到域名账号" && sleep 4 && break
					delete_menu=($(ls /etc/nginx/conf.d/))
					[ -z "${delete_menu}" ] && echo "VPS中没有检测到域名账号" && sleep 4 && break
					clear
					deamon_arry_long=${#delete_menu[*]}
					echo ""
					echo -e "请选择 "$yellow"域名配置文件"$none" [${magenta}1-${#delete_menu[*]}$none]"
					echo
					for ((i = 1; i <= ${#delete_menu[*]}; i++)); do
						Stream="$(echo ${delete_menu[$i - 1]} | sed 's/.conf//g')"
						if [ -f "${backup}" ];then
							if [ ! -z "${Stream}" ];then
								domain_class=$(cat "${backup}" | grep "${Stream}" | awk '{print $2}')
							fi
						fi
						if [[ "$i" -le 9 ]]; then
							# echo
							echo -e "$yellow  $i. $none${Stream}\t${domain_class}"
						else
							# echo
							echo -e "$yellow $i. $none${Stream}\t${domain_class}"
						fi
					done
					echo
					echo "删除前请确认清楚！"
					echo ""
					echo -e "${magenta}温馨提示...如果你不想执行选项...按$yellow Ctrl + C $none即可退出"
					echo
					delete_num=
					read -p "$(echo -e "请选择删除的域名，直接输入数值[按 q 返回主菜单]:")" delete_num
					[ -z "$delete_num" ] && echo "输入为空，请重新选择" && continue
					case $delete_num in
						[1-9] | [1-9][0-9] | [1-9][0-9][0-9])
							echo
							let deamon_arry_long+=1
							if [ "${delete_num}" -ge "${deamon_arry_long}" ] || [ "${delete_num}" -le "0" ]
							then
								echo -e "\n${red}输入的数值 ${delete_num} 超过了提示的数值，请重新输入。${none}\n"
								sleep 2
								continue
							fi
							echo
							sites_url_del=
							test -e /etc/nginx/conf.d/${delete_menu[$delete_num - 1]} && rm -rf /etc/nginx/conf.d/${delete_menu[$delete_num - 1]}
							domain=$(echo ${delete_menu[$delete_num - 1]}  | sed 's/.conf//g')
							echo -e "$yellow 删除的域名是： $cyan${domain}$none"
							echo "----------------------------------------------------------------"
							echo
							mport=$(echo ${domain} | cut -d '-' -f 1)
							if [ "$(echo ${mport} | egrep  '443|3389|8443')" != "" ]
							then
								domain="$(echo ${domain} | cut -d '-' -f 2)"
							fi
							domain_class=$(cat "${backup}" | grep "${domain}" | awk '{print $2}') #获取账号类型，vmess/vless
							let line_num=$(cat "${backup}" | grep -n ${domain} | cut -d : -f 1)+1
							test ! -e /etc/nginx/conf.d/${delete_menu[$delete_num - 1]} && test_exist=0 || test_exist=1
							if [ "${test_exist}" == "0" ] 
							then
								if [ -f "${backup}" ];then
									uuid=$(cat "${backup}" | grep "${domain}" | awk '{print $6}' | cut -d : -f 2)
								fi
								if [[ ! -z "${uuid}" && "$(echo ${uuid} | wc -c )" == "37" ]];then
									if [ "$(echo ${domain_class} | grep -i vmess )" != "" ];then
										tmp_path="/etc/xray/config/07-vmess_WS_inbounds.json"
									else
										tmp_path="/etc/xray/config/10-vless_WS_inbounds.json"
									fi
									del_v2id
								fi
								rm -rf /etc/nginx/ssl/${domain}.*	#删除域名的证书
								sed -i "/${domain}/d" ${backup} && sed -i "${line_num}d" ${backup}	#删除备份文档中的账号信息

								if [[ ! -f "/etc/nginx/ssl/${domain}.crt" && ! -f "/etc/nginx/conf.d/${delete_menu[$delete_num - 1]}" && "$(cat ${tmp_path} | grep "${uuid}")" == "" ]];then
									echo -e "\n${yellow}域名删除成功${none}\n"
									start			#启动xray和nginx
								else
									echo -e "\n${red}域名没有删除成功${none}\n"
								fi
								
							else
								echo -e "${red}域名没有删除成功${none}"
							fi
							read -sp "回车后返回菜单"				
							;;
						q)
							break							
							;;
						*)
							echo -e "\n${red}请按照提示操作${none}\n"
							sleep 3
							continue							
							;;
					esac
						
				done		
				;;
			4) Create_Link ;;
			q)
				exit
				;;
			*)
				echo -e "${red}请按照提示操作${none}"
				sleep 3
				continue
				;;

		esac
	done


}

reboot_check() {
	if [[ "${INSTALL_BBR}" == "true" ]]; then
		echo
		echo " 为使BBR模块生效，需要系统重新启动"
		echo
	fi
	if [ ! -z "${error_info}" ];then
		echo ""
		echo -e "以下是安装的过程中出现的错误：\n${error_info}"
		echo ""
		read -sp " 可以按 ctrl + c 取消重启，回车后重启系统"
		reboot
	else
		echo ""
		read -sp " 可以按 ctrl + c 取消重启，回车后重启系统"
		reboot
	fi
}

update() {
	res=$(status)
	[[ $res -lt 2 ]] && colorEcho $RED " Xray未安装，请先安装！" && return
	getVersion
	RETVAL="$?"
	if [[ $RETVAL == 0 ]]; then
		colorEcho $BLUE " Xray最新版 ${CUR_VER} 已经安装"
	elif [[ $RETVAL == 3 ]]; then
		exit 1
	else
		colorEcho $BLUE " 安装Xray ${NEW_VER} ，架构$(archAffix)"
		installXray
		stop
		start
		colorEcho $GREEN " 最新版Xray安装成功！"
	fi
}

#备份v2ray和caddy配置文件
Backup() {
    if [ -f /etc/xray/config/01-log.json ];then
        test -e /tmp/back_xray && rm -rf /tmp/back_xray
		test -e /tmp/back_xray.tar.xz && rm -rf /tmp/back_xray.tar.xz
        test ! -e /tmp/back_xray && mkdir /tmp/back_xray
        cp -rf /etc/xray /tmp/back_xray
    else
        echo -e "\n${red}没有找到v2ray的配置文件${none}\n"
        exit
    fi

    if [[ -f /etc/nginx/nginx.conf && "$(ls /etc/nginx/conf.d)" != "" ]];then
        test ! -e /tmp/back_xray/nginx && mkdir -p /tmp/back_xray/nginx
        cp -rf /etc/nginx/conf.d /etc/nginx/ssl /etc/nginx/nginx.conf /tmp/back_xray/nginx
    else
        echo -e "\n${red}没有找到nginx的配置文件${none}\n"
        exit       
    fi
	if [[ -e /www && "$(ls /www/)" != "" ]];then
		cp -rf /www /tmp/back_xray
	fi
    test -e /tmp/back_xray && cd /tmp/ && tar -Jcf back_xray.tar.xz back_xray
    test -e back_xray.tar.xz && cp back_xray.tar.xz ${path_now}
    if [[ -f ${path_now}/back_xray.tar.xz ]];then
        echo -e "\n${yellow}备份完成，文件名称是back_xray.tar.xz 下载到本地中以后好还原使用\n${none}"
    else
        echo -e "\n${red}备份失败，请重新执行此脚本${none}\n"
    fi
	test -e /tmp/back_xray && rm -rf /tmp/back_xray
	test -e /tmp/back_xray.tar.xz && rm -rf /tmp/back_xray.tar.xz
	exit
}

#还原vray配置文件
Recover() {
    if [[ -f ${path_now}/back_xray.tar.xz ]];then
		#软件管理器清理+更新软件源列表+安装需要的依赖程序
		$PMT clean all
		[[ "$PMT" == "apt" ]] && $PMT update
		#echo $CMD_UPGRADE | bash
		$CMD_INSTALL wget curl sudo vim unzip tar gcc openssl
		$CMD_INSTALL net-tools
		if [[ "$PMT" == "apt" ]]; then
			$CMD_INSTALL libssl-dev g++
		fi
		res=$(which unzip 2>/dev/null)
		if [[ $? -ne 0 ]]; then
			colorEcho $RED " unzip安装失败，请检查网络"
			exit 1
		fi
		optimize_set		#系统优化设置
		security_set		#系统安全设置包括防火墙、ssh配置文件设置。
		# if [ ! -f /usr/bin/vspeed ];then
		# 	install_speed_check 1	#安装流量监控脚本
		# fi
		#判断VPS上是否安装nginx，没有安装就安装上
		res=$(which nginx 2>/dev/null)
		if [[ "$?" != "0" ]]; then
			installNginx	#安装nginx
		fi
		colorEcho $BLUE " 安装Xray..."
		getVersion		#获取xray版本号
		RETVAL="$?"
		if [[ $RETVAL == 0 ]]; then
			colorEcho $BLUE " Xray最新版 ${CUR_VER} 已经安装"
		elif [[ $RETVAL == 3 ]]; then
			exit 1
		else
			colorEcho $BLUE " 安装Xray ${NEW_VER} ，架构$(archAffix)"
			installXray		#安装xray程序
		fi
        
        test -e /tmp/back_xray && rm -rf /tmp/back_xray
		test -e /tmp/back_xray.tar.xz && rm -rf /tmp/back_xray.tar.xz
        cp -rf ${path_now}/back_xray.tar.xz /tmp && cd /tmp
        tar Jxf back_xray.tar.xz
        if [[ -e /tmp/back_xray ]];then
            if [[ -f back_xray/xray/config/01-log.json && -e back_xray/nginx/conf.d ]];then
                test -e /etc/xray && rm -rf /etc/xray
                cp -rf back_xray/xray /etc
                cp -rf back_xray/nginx /etc
				cp -rf back_xray/www /
                systemctl daemon-reload
                start
                if [[ -f /etc/xray/config/01-log.json ]];then
                    echo -e "\n${yellow} xray配置文件还原完成。\n${none}"
                else   
                    echo -e "\n${red} xray配置文件还原失败，请重新执行此脚本${none}\n"
                fi
                if [[ -f /etc/nginx/nginx.conf ]];then
                    echo -e "\n${yellow} nginx 配置文件还原完成。\n${none}"
                else   
                    echo -e "\n${red} nginx 配置文件还原失败，请重新执行此脚本${none}\n"
                fi
                if [[ -e /www && "$(ls /www/)" != "" ]];then
                    echo -e "\n${yellow} 伪装网址 还原完成。\n${none}"
                else   
                    echo -e "\n${red} 伪装网址 还原失败，请重新执行此脚本${none}\n"
                fi
				test -e /tmp/back_xray && rm -rf /tmp/back_xray
				test -e /tmp/back_xray.tar.xz && rm -rf /tmp/back_xray.tar.xz
                exit
            fi
        else
            echo -e "\n${red}没有在tmp目录中发现 back_xray 备份目录${none}\n"
            exit
        fi
    else
        echo -e "\n${red}脚本所在目录中没有找到 back_xray.tar.xz，\
        \n请把备份好的back_xray.tar.xz和脚本放在一起，再执行此脚本${none}\n"
        exit
    fi
}

#备份还原v2ray账号
RecoverBackup() {
	#主程序
	while true;do
		clear
		echo
		echo -e "${yellow}........... VPS备份还原 ..........${none}"
		echo
		echo -e "${yellow} 1. 备份VPS账号${none}"
		echo
		echo -e "${yellow} 2. 还原VPS账号${none}"
		echo
		read -p "$(echo -e "${yellow}输入选择【输入 q 退出】: ${none}")" select_num
		case ${select_num} in
			1)
				Backup
				;;
			2)
				Recover
				;;
			q)
				exit
				;;
			*)
				read -sp "请按照提示输入"
				continue
				;;
		esac   
	done
}

#显示日志
showLog() {
	res=$(status)
	[[ $res -lt 2 ]] && colorEcho $RED " Xray未安装，请先安装！" && return
	journalctl -xen -u xray --no-pager
}















########################自定义增加的项目 开始########################

vps_login() {
	#颜色定义
	purple()                           #紫
	{
		echo -e "\\033[35;1m${*}\\033[0m"
	}
	tyblue()                           #蓝
	{
		echo -e "\\033[36;1m${*}\\033[0m"
	}
	green()                            #绿
	{
		echo -e "\\033[32;1m${*}\\033[0m"
	}
	yellow()                           #黄
	{
		echo -e "\\033[33;1m${*}\\033[0m"
	}
	red()                              #红
	{
		echo -e "\\033[31;1m${*}\\033[0m"
	}
	blue()                             #蓝色
	{
		echo -e "\\033[34;1m${*}\\033[0m"
	}

	usersud_ef(){
	#创建普通用户与删除普通用户\添加和删除sudo权限功能
	clear
	while true
	do
	cat <<-EOF
	╦ ╦┌─┐┬  ┌─┐┌─┐┌┬┐┌─┐  ┌┬┐┌─┐  ┌┬┐┬ ┬┌─┐
	║║║├┤ │  │  │ ││││├┤    │ │ │   │ ├─┤├┤ 
	╚╩╝└─┘┴─┘└─┘└─┘┴ ┴└─┘   ┴ └─┘   ┴ ┴ ┴└─┘	 
		EOF
	echo -e "\e[1;36m         【用户管理功能】\e[0m"
	echo $""
	cat <<-EOF
		A  创建普通用户
		B  删除普通用户
		c  给普通用户添加sudo权限
		D  删除普通用户sudo权限
		X  退出
		EOF
	echo ""
	read -p $(echo -e "\e[1;33m请输入想要的操作选项|A|B|C|D|X|:\e[0m") suaddiokk
	clear
	case "$suaddiokk" in
		a|A)
		clear
		#创建普通用户
		while true
		do
			read -p $(echo -e "\e[1;33m请输入要创建的用户名:\e[0m") newh_osname
			id $newh_osname &>/dev/null
			if [ $? -eq 0 ];then
				   echo -e "这个\e[1;31m$newh_osname\e[0m用户已经存在,请重新输入一个新用户名"
			else
				break
			fi  
		done       
		#read -p $(echo -e "\e[1;33m请输入新用户的密码:\e[0m") newuser_pas
		while true
		do
			echo  
			read -p $(echo -e "\e[1;33m创建输入y，不创建输入n[y/n]:\e[0m") ye_no
			case "$ye_no" in
			yes|y|Yes|YES|Y)
			#判断/目录下是否有home文件夹，如果没有就创建，如果有就不创建。
			test ! -f /home -a ! -d /home && mkdir /home
			sudo useradd -m -s /bin/bash $newh_osname
			#echo "$newuser_pas"|passwd --stdin $newh_osname这条命令过时了，新版系统上无法修改。
			#echo "$newuser_pas"|passwd --stdin $newh_osname 
			#普通用户将要使用密钥登陆，所以设置秘密功能移除掉[echo "$newh_osname:$newuser_pas" | sudo chpasswd]，需要再打开。 
			#echo "$newh_osname:$newuser_pas" | sudo chpasswd
			echo -e "\e[6;32m新用户$newh_osname已经创建成功\e[0;32m"
			sleep 3
			clear
			break    
				;;
				n|no|NO|N)
				clear
				break
				;;
				*)
			echo -e "\e[1;31m请输入正确的选项Y或N\e[0m" ;;
			esac
		done
		 ;;
		 b|B)
		 clear
		#删除普通用户	
		while true
		do
		read -p $(echo -e "\e[1;33m请输入要删除的用户名称:\e[0m") users_d
		cusers_d=$(test -z "$users_d";echo $?)
		id $users_d &>/dev/null
		if [ $? -ne 0 ];then
			echo -e "这个\e[1;31m$users_d\e[0m用户不存在，请重新输入"
		elif [ $cusers_d -ne 1 ];then
			echo -e "\e[1;31m不能为空，请重新输入!!!\e[0m"
		else
			 break
		fi  
		done
		 while true
		 do
		 read -p $(echo -e "\e[1;33m确定删除？[y/n]:\e[0m") users_del
		 case "$users_del" in 
		 y|Y|yes|YES)
		 sudo userdel -r $users_d &>/dev/null
		 sudo sed -i "/^"$users_d"[ \t]*ALL=(ALL:ALL)*[ \t]*NOPASSWD:ALL*/d" /etc/sudoers
		 wait
		 echo -e "    \e[1;31m$users_d\e[0m用户已经被删除,同时被移除sudoers文件"
		 sleep 3
		 clear
		 break
		 ;;
		 *)
		 echo -e "\e[1;31m输入错误提示!!!请输入正确选项y/n:\e[0m"
		 sleep 3
		 esac
		 clear
		 break
		 done
		 ;;
		 c|C)
		clear
		#给普通用户添加sudo权限
		while true
		do
			read -p $(echo -e "\e[1;33m请输入要加入sudo权限的用户名称:\e[0m") hosname
			chosname=$(test -z "$hosname";echo $?)
			id $hosname &>/dev/null
			if [ $? -ne 0 ];then
				   echo -e "这个\e[1;31m$hosname\e[0m用户不存在，请重新输入"
			elif [ $chosname -ne 1 ];then
			   echo -e "\e[1;31m不能为空，请重新输入!!!\e[0m"
			else
			   sudo sed -ri '$a'"$hosname     ALL=(ALL:ALL) NOPASSWD:ALL" /etc/sudoers
			   echo -e "    \e[1;31m$hosname\e[0m用户已经被添加进sudoers文件中"
			   sleep 3
			   clear
			   break
			fi	  
		done
		 ;;
		 d|D)
		 clear
		#删除普通用户sudo权限
		while true
		do
		read -p $(echo -e "\e[1;33m请输入要删除sudo权限的用户名称:\e[0m") hostname
		chostname=$(test -z "$hostname";echo $?)
		id $hostname &>/dev/null
		  if [ $? -ne 0 ];then
				 echo -e "这个\e[1;31m$hostname\e[0m用户不存在，请重新输入"
		  elif [ $chostname -ne 1 ];then
			 echo -e "\e[1;31m不能为空，请重新输入!!!\e[0m"
		  else
			 sudo sed -i "/^"$hostname"[ \t]*ALL=(ALL:ALL)*[ \t]*NOPASSWD:ALL*/d" /etc/sudoers
			 echo -e "    \e[1;31m$hostname\e[0m用户已经被移除sudoers文件"
			 sleep 3
			 clear
			 break
		  fi	  
			done	
		 ;;
		 x|X)
		 menu
		 break;;
		 *)
		 echo -e "\e[1;31m输入错误提示!!!请输入正确选项|A|B|C|D|X|\e[0m";;

	esac
	done
	}

	#重启sshd服务
	sshd_chongqi() {
		clear
		sudo systemctl restart sshd
		wait
		echo "" 
		echo -e "\e[1;36m    重启sshd服务完成\e[0m"
		sleep 1
		echo ""
	}

	#ssh登陆管理功能
	sshd_cheng(){
	clear
	while true
	do

	echo -e "\e[1;33m以下是ssh登陆管理功能\e[0m"
	echo ""
	cat <<-EOF
		A  创建密钥对
		B  开启密钥对登陆
		c  允许密码登陆
		D  禁用密码登陆
		E  允许root登陆
		F  禁用root登陆
		G  给ssh添加登陆新端口
		H  禁用ssh的22端口
		I  删除ssh旧端口
		J  重启sshd服务
		X    退出
		EOF
	echo ""
	read -p $(echo -e "\e[1;33m请输入想要的操作选项|A|B|C|D|X|:\e[0m") ssh_cheng
	clear
	case "$ssh_cheng" in
		 a|A)
		 clear
		#创建密钥对
		while true
		do
		read -p $(echo -e "\e[1;33m请输入普通用户名称:\e[0m") putusers
		aks=$(test -z "$putusers";echo $?)
		id $putusers &>/dev/null
		if [ $? -ne 0 ];then
				 echo -e "这个\e[1;31m$putusers\e[0m用户不存在，请先去创建一个用户或重新输入"
		  elif [ $aks -ne 1 ];then
				 echo -e "\e[1;31m不能为空，请重新输入!!!\e[0m"
		  else
		  break
		fi
		done                 
		  read -p $(echo -e "\e[1;33m确定创建?[y/n]:\e[0m") yes_noo
		 case "$yes_noo" in 
		 y|Y|yes|YES) 
			test ! -f /home/$putusers/.ssh -a ! -d /home/$putusers/.ssh && mkdir /home/$putusers/.ssh
			sudo test ! -f /root/.ssh -a ! -d /root/.ssh && sudo mkdir /root/.ssh
			chown $putusers /home/$putusers/.ssh	    
			test ! -f ./ssh_rkey -a ! -d ./ssh_rkey && mkdir ./ssh_rkey
			rm ./ssh_rkey/* >/dev/null 2>&1
			ssh-keygen -q -t rsa -N '' -f ./ssh_rkey/id_rsa <<<y >/dev/null 2>&1
			mv ./ssh_rkey/id_rsa.pub ./ssh_rkey/authorized_keys
			cp ./ssh_rkey/authorized_keys /home/$putusers/.ssh/
			cp ./ssh_rkey/authorized_keys /root/.ssh/
			chown $putusers /home/$putusers/.ssh/authorized_keys
			chown -R $putusers /home/$putusers/.ssh
			chgrp -R $putusers /home/$putusers/.ssh
			chmod 600 /root/.ssh/authorized_keys
			chmod 600 /home/$putusers/.ssh/authorized_keys
				# 644 = [-rw-r--r--] 4只读
			 chmod 755 ssh_rkey
			 chmod 644 ssh_rkey/*
			 rm ./ssh_rkey/authorized_keys
			wait
			echo -e "\e[1;36m    密钥对设置完成,登陆密钥文件在脚本旁边的ssh_rkey文件夹中，请及时下载到本地系统中去\e[0m"
		 sleep 6
		 clear
		 ;;
		 *)
		 echo -e "\e[1;31m输入错误提示!!!请输入正确选项y/n:\e[0m"
		 sleep 3
		 esac
		 ;;
		 b|B)
		 clear
		#开启密钥对登陆
		sed -i "/^.*[ \t]*PubkeyAuthentication *[ \t]*yes*/d" /etc/ssh/sshd_config
		sed -i "/^.*[ \t]*RSAAuthentication *[ \t]*yes*/d" /etc/ssh/sshd_config 
		sed -i "/^.*[ \t]*AuthorizedKeysFile *[ \t]*.ssh\/authorized_keys*/d" /etc/ssh/sshd_config 
		#替换法：sed -i 's/^.*[ \t]*AuthorizedKeysFile *[ \t]*.ssh\/authorized_keys*/AuthorizedKeysFile     .ssh\/authorized_keys/g' /etc/ssh/sshd_config
		sed -ri '$a'"AuthorizedKeysFile     .ssh\/authorized_keys" /etc/ssh/sshd_config       
		sed -ri '$a'"RSAAuthentication yes" /etc/ssh/sshd_config
		sed -ri '$a'"PubkeyAuthentication yes" /etc/ssh/sshd_config
		echo -e "\e[1;36m    开启密钥对登陆设置完成,重启sshd后生效\e[0m"
		sleep 2
		sshd_chongqi
		 ;;
		 c|C)
		 clear
		#允许密码登陆
			 sed -i 's/^.*[ \t]*PasswordAuthentication *[ \t]*no*/PasswordAuthentication yes/g' /etc/ssh/sshd_config
			 sed -i 's/^.*[ \t]*PasswordAuthentication *[ \t]*yes*/PasswordAuthentication yes/g' /etc/ssh/sshd_config
			 echo -e "\e[1;36m    允许密码登陆设置完成,重启sshd后生效\e[0m"
		 sleep 2
		 sshd_chongqi
		 ;;
		 d|D)
		 clear
		#禁用密码登陆
			 sed -i 's/^.*[ \t]*PasswordAuthentication *[ \t]*yes*/PasswordAuthentication no/g' /etc/ssh/sshd_config
			 sed -i 's/^.*[ \t]*PasswordAuthentication *[ \t]*no*/PasswordAuthentication no/g' /etc/ssh/sshd_config
			 echo -e "\e[1;36m    禁用密码登陆设置完成,重启sshd后生效\e[0m"
		 sleep 2
		 sshd_chongqi
		 ;;
		 e|E)
		 #允许root登陆
		  sudo sed -i "s/.*PermitRootLogin.*/PermitRootLogin yes/g" /etc/ssh/sshd_config
			 echo -e "\e[1;36m    允许root登陆设置完成,重启sshd后生效\e[0m"
		 sleep 2
		 sshd_chongqi
			;;
		 f|F)
		 #禁用root登陆
		 sudo sed -i "s/.*PermitRootLogin.*/PermitRootLogin no/g" /etc/ssh/sshd_config 
			 echo -e "\e[1;36m    禁用root登陆设置完成,重启sshd后生效\e[0m"
		 sleep 2
		sshd_chongqi	 
			;;
		 g|G)
		 #给ssh添加登陆新端口
		while true
		do
		read -p $(echo -e "\e[1;33m请输入新端口20000\50000之间的数值，例如:21350:\e[0m") le_g
		cle_g=$(test -z "$le_g";echo $?)
		if [ $cle_g -ne 1 ];then
			echo -e "\e[1;31m不能为空，请重新输入!!!\e[0m"
		else
			 sudo sed -ri '$a'"Port $le_g" /etc/ssh/sshd_config
			 test ! -f ./ssh_rkey -a ! -d ./ssh_rkey && mkdir ./ssh_rkey
			 echo "ssh新添加的端口是: $le_g" > ./ssh_rkey/port.txt
			 echo -e "ssh新端口是:\e[1;36m($le_g)\e[0m保存在『ssh_rkey/port.txt』文件中;sshd重启后此修改才生效."
			  sleep 3
			sshd_chongqi		  
			  break
		fi  
		done       
			;;
		 h|H)
		 #禁用ssh的22端口
		clear
			echo -e "\e[1;31m提示:如果端口前面是两个2的如22990就不要使用『禁用ssh的22端口』这个功能，会将你的22990端口也删除掉的！！！\e[0m"
		sleep 1
		
					 read -p $(echo -e "\e[1;33m你确定?[y/n]:\e[0m") yes_hyo
					   case "$yes_hyo" in 
						y|Y|yes|YES) 	    
						sudo sed -i "/^.*[ \t]*Port [ \t]*22/d" /etc/ssh/sshd_config                       	                
						wait
						echo -e "\e[1;36m    禁用ssh的22端口设置完成,重启sshd后生效\e[0m"
						sleep 4
						sshd_chongqi
						clear
						  ;;
						   *)
						echo -e "\e[1;31m成功,再见!\e[0m"
						sleep 3
						clear
						esac		         
			;;
		 i|I)
		 #删除ssh旧端口
		while true
		do
		read -p $(echo -e "\e[1;33m请输入SSH的旧端口:\e[0m") por_tt
		cpor_tt=$(test -z "$por_tt";echo $?)
		if [ $cpor_tt -ne 1 ];then
		   echo -e "\e[1;31m不能为空，请重新输入!!!\e[0m"
		else
			  sudo sed -i "/^.*[ \t]*Port [ \t]*"$por_tt"/d" /etc/ssh/sshd_config
			  echo -e "\e[1;36m($por_tt)\e[0m端口已删除;sshd重启后此修改才生效."
			  sleep 2
			  sshd_chongqi
			  break
		fi  
		done           
			;;
		 j|J)	 
		#重启sshd服务
			 clear
			 sleep 1
				 sudo systemctl restart sshd
			 wait
			  echo "" 
				  echo -e "\e[1;36m    重启sshd服务完成\e[0m"
			 sleep 3
		 ;;	 
		 x|X)
		 menu
		 break;;
		 *)
		 echo -e "\e[1;31m输入错误提示!!!请输入正确选项|A|B|C|D|X|\e[0m";;

	esac
	done
	}
	#cheng_Rsa_k与cheng_Vres_key归属于03  密钥修改功能
	cheng_Vres_key(){
	echo ""
	clear
	echo ""
	while true
		do
		read -p $(echo -e "\e[1;33m请输入真实存在的普通用户名称:\e[0m") p_users
		sca_les=$(test -e /home/$p_users/.ssh/authorized_keys;echo $?)
		ak_ds=$(test -z "$p_users";echo $?)
		id $p_users &>/dev/null
		if [ $? -ne 0 ];then
				echo -e "这个\e[1;31m$p_users\e[0m用户不存在，请重新输入"
				   read -p $(echo -e "\e[1;36m返回输入y不返回输入n[y/n]:\e[0m") ye_no
				   case "$ye_no" in
					  yes|y|Yes|YES|Y)

				   clear
			   break    
						 ;;
					   n|no|NO|N)
						clear
						 ;;
						 *)
				  echo -e "\e[1;31m喔!!!请输入正确的选项Y或n\e[0m" ;;
				   esac	         
		  elif [ $ak_ds -ne 1 ];then
				 echo -e "\e[1;31m不能为空，请重新输入!!!\e[0m"
				   read -p $(echo -e "\e[1;36m返回输入y不返回输入n[y/n]:\e[0m") ye_no
				   case "$ye_no" in
					  yes|y|Yes|YES|Y)

				   clear
			   break    
						 ;;
					   n|no|NO|N)
						clear
						 ;;
						 *)
				  echo -e "\e[1;31m喔!!!请输入正确的选项Y或n\e[0m" ;;
				  esac	         
		  elif [ $sca_les -ne 0 ];then
			   echo -e "\e[1;31m'$p_users'用户下的.ssh文件夹里面没有authorized_keys文件说明你目前不能使用这个功能，请选择其他功能.\e[0m"
				   read -p $(echo -e "\e[1;36m返回输入y不返回输入n[y/n]:\e[0m") ye_no
				   case "$ye_no" in
					  yes|y|Yes|YES|Y)

				   clear
			   break    
						 ;;
					   n|no|NO|N)
						clear
						 ;;
						 *)
				  echo -e "\e[1;31m喔!!!请输入正确的选项Y或n\e[0m" ;;
				   esac
	   
		  else
		 while true
				do
			echo 
	cat <<-EOF
	╦ ╦┌─┐┬  ┌─┐┌─┐┌┬┐┌─┐  ┌┬┐┌─┐  ┌┬┐┬ ┬┌─┐
	║║║├┤ │  │  │ ││││├┤    │ │ │   │ ├─┤├┤ 
	╚╩╝└─┘┴─┘└─┘└─┘┴ ┴└─┘   ┴ └─┘   ┴ ┴ ┴└─┘	 
		EOF
	echo -e "\e[1;36m            密钥修改功能\e[0m"
	echo $""	     
		cat <<-EOF
		A  创建ssh新密钥对
		B  进入修改选项
		X  退出此功能
		EOF
		echo ""
		read -p $(echo -e "\e[1;33m请输入操作选项|A|B|X|:\e[0m") or_der
		case "$or_der" in
			 a|A)
					   echo ""
					   read -p $(echo -e "\e[1;33m确定创建?[y/n]:\e[0m") yes_nyo
					   case "$yes_nyo" in 
						y|Y|yes|YES) 	    
						test ! -f ./sshx_key -a ! -d ./sshx_key && mkdir ./sshx_key
						ssh-keygen -q -t rsa -N '' -f ./sshx_key/id_rsa <<<y >/dev/null 2>&1
						 # 644 = [-rw-r--r--] 4只读
						chmod 755 sshx_key
						chmod 644 sshx_key/*
						wait
						echo ""
						echo -e "\e[1;36m    密钥对设置完成,存放在脚本旁边的【sshx_key】文件夹中，请及时下载到本地系统中去\e[0m"
						sleep 6
						clear
						  ;;
						   *)
						echo ""
						echo -e "\e[1;31m巨大的成功,再见!\e[0m"
					   sleep 3
						clear
						esac
		 ;;
			 b|B)
			clear
			cheng_Rsa_k
			 break
		 ;;
		 x|X)
		 clear
		 menu
		 break;;
		 *)
		 echo -e "\e[1;31m输入错误提示!!!请输入正确选项|A|B|X|\e[0m";;

			 esac
			 done
		 break
		fi
	done
	menu 
	}
	#cheng_Rsa_k与cheng_Vres_key归属于03  密钥修改功能
	cheng_Rsa_k(){
	while true
	do
	sshd_chongqi
	echo -e "\e[31;6m           欢迎来到ssh修改选项页 \e[1;0m"
	echo "--------------------------------------------"
	cat <<-EOF
		A  给root/普通用户|添加新登陆密钥
		B  删除root/普通用户|旧登陆密钥
		C  禁用ssh的22端口
		D  给ssh添加登陆新端口
		E  删除ssh旧端口
		F  允许root登陆
		G  禁用root登陆
		H  重启sshd
		X  退出此功能	
		EOF
	echo ""
	read -p $(echo -e "\e[1;33m请输入操作选项|A|B|C|D|E|F|G|H|X|:\e[0m") ac_tiok
	clear
	case "$ac_tiok" in
		#A	给root/普通用户|添加新登陆密钥
		a|A)
		while true
		  do
		echo ""  
		read -p $(echo -e "\e[1;33m请再次输入普通用户名称:\e[0m") p_users
		sca_pub=$(test -e ./sshx_key/id_rsa.pub;echo $?)
			ak_ds=$(test -z "$p_users";echo $?)
		id $p_users &>/dev/null
		if [ $? -ne 0 ];then
				echo ""  
				echo -e "这个\e[1;31m$p_users\e[0m用户不存在，请重新输入"
				   read -p $(echo -e "\e[1;36m返回输入y不返回输入n[y/n]:\e[0m") ye_no
				   case "$ye_no" in
					  yes|y|Yes|YES|Y)

				   clear
			   break    
						 ;;
					   n|no|NO|N)
						clear
						 ;;
						 *)
				  echo -e "\e[1;31m喔!!!请输入正确的选项Y或n\e[0m" ;;
				   esac	         
		  elif [ $ak_ds -ne 1 ];then
				 echo -e "\e[1;31m不能为空，请重新输入!!!\e[0m"
				   read -p $(echo -e "\e[1;36m返回输入y不返回输入n[y/n]:\e[0m") ye_no
				   case "$ye_no" in
					  yes|y|Yes|YES|Y)

				   clear
			   break    
						 ;;
					   n|no|NO|N)
						clear
						 ;;
						 *)
				  echo -e "\e[1;31m喔!!!请输入正确的选项Y或n\e[0m" ;;
				  esac	         
		  elif [ $sca_pub -ne 0 ];then
			   echo -e "\e[1;31m没有./sshx_key/id_rsa.pub文件请先【A创建ssh新密钥对】再来了。\e[0m"
				   read -p $(echo -e "\e[1;36m返回输入y不返回输入n[y/n]:\e[0m") ye_no
				   case "$ye_no" in
					  yes|y|Yes|YES|Y)

				   clear
			   break    
						 ;;
					   n|no|NO|N)
						clear
						 ;;
						 *)
				   echo -e "\e[1;31m喔!!!请输入正确的选项Y或n\e[0m" ;;
				   esac  
		  else		
			rsa_koy=$(cat ./sshx_key/id_rsa.pub)
			echo $rsa_koy | sudo tee -a /home/$p_users/.ssh/authorized_keys >/dev/null 2>&1
				#sudo tee $rsa_koy >> /home/$p_users/.ssh/authorized_keys  //提示权限不够
				echo $rsa_koy | sudo tee -a /root/.ssh/authorized_keys >/dev/null 2>&1
			sudo chown -R $p_users /home/$p_users/.ssh
			sudo chgrp -R $p_users /home/$p_users/.ssh
			sudo chmod 600 /root/.ssh/authorized_keys
				sudo chmod 600 /home/$p_users/.ssh/authorized_keys
			sudo chown $p_users /home/$p_users/.ssh/authorized_keys            	 
		 echo -e "\e[1;36m"更改成功，现在去用新密钥测试登陆吧，如果能正常登陆再回来使用【删除root\/普通用户\|旧登陆密钥】"\e[0m"
		 sleep 4
		 
		break
		fi
		   done
		   ;;  	
		#B	删除root/普通用户|旧登陆密钥（是删除authorized_keys文件中的密钥参数不是删除文件）
		b|B)
		 clear
		 sudo sed -i "1d" /home/$p_users/.ssh/authorized_keys
		 sudo sed -i "1d" /root/.ssh/authorized_keys
			 echo -e "\e[1;36m    『删除root/普通用户|旧登陆密钥』完成，不能再删了。\e[0m"
		 sleep 5  	 
		 ;; 	
		#C	禁用ssh的22端口
		c|C)
		clear
		echo ""  
			echo -e "\e[1;31m提示:如果端口前面是两个2的如22990就不要使用『禁用ssh的22端口』这个功能，会将你的22990端口也删除掉的！！！\e[0m"
		sleep 1
					 echo ""  
					 read -p $(echo -e "\e[1;33m确定创建?[y/n]:\e[0m") yes_hyo
					   case "$yes_hyo" in 
						y|Y|yes|YES) 	    
						sudo sed -i "/^.*[ \t]*Port [ \t]*22/d" /etc/ssh/sshd_config                       	                
						wait
						echo ""  
						echo -e "\e[1;36m    禁用ssh的22端口设置完成,重启sshd后生效\e[0m"
						sleep 6
						clear
						  ;;
						   *)
						echo -e "\e[1;31m巨大的成功,再见!\e[0m"
					   sleep 3
						clear
						esac	        
			;; 	
		#D	给ssh添加登陆新端口
		d|D)
		clear
		while true
		do
		echo ""  
		read -p $(echo -e "\e[1;33m请输入新端口20000\50000之间的数值，例如:21350:\e[0m") leh_g
		cleh_g=$(test -z "$leh_g";echo $?)
		if [ $cleh_g -ne 1 ];then
			echo -e "\e[1;31m不能为空，请重新输入!!!\e[0m"
		else
			 sudo sed -ri '$a'"Port $leh_g" /etc/ssh/sshd_config
			 test ! -f ./sshx_key -a ! -d ./sshx_key && mkdir ./sshx_key
			 echo "ssh新添加的端口是: $leh_g" > ./sshx_key/port.txt
			 echo ""  
			 echo -e "ssh新端口是:\e[1;36m($leh_g)\e[0m保存在『sshx_key/port.txt』文件中;sshd重启后此修改才生效."
			  sleep 3 	
			  break
		fi  
		done       
			;;	
		#E	删除ssh旧端口
		e|E)
		clear
		while true
		do
		echo ""  
		read -p $(echo -e "\e[1;33m请输入SSH的旧端口:\e[0m") por_tt
		cpor_tt=$(test -z "$por_tt";echo $?)
		if [ $cpor_tt -ne 1 ];then
		   echo -e "\e[1;31m不能为空，请重新输入!!!\e[0m"
		else
			  sudo sed -i "/^.*[ \t]*Port [ \t]*"$por_tt"/d" /etc/ssh/sshd_config
			  echo ""  
			  echo -e "\e[1;36m($por_tt)\e[0m端口已删除;sshd重启后此修改才生效."
			  sleep 3 	
			  break
		fi  
		done
		;;   	
		#F	允许root登陆
		f|F)
		clear
			 sudo sed -i "s/.*PermitRootLogin.*/PermitRootLogin yes/g" /etc/ssh/sshd_config
			 echo ""  
			 echo -e "\e[1;36m    允许root登陆设置完成,重启sshd后生效\e[0m"
			 sleep 3
			;; 	
		#G	禁用root登陆
		g|G)
		clear
			 sudo sed -i "s/.*PermitRootLogin.*/PermitRootLogin no/g" /etc/ssh/sshd_config 
			 echo ""  
			 echo -e "\e[1;36m    禁用root登陆设置完成,重启sshd后生效\e[0m"
			 sleep 3     
			;; 	
		#H	重启sshd
		h|H)
		 clear
			 sudo systemctl restart sshd
			 echo ""  
			 echo -e "\e[1;36m    重启sshd服务完成\e[0m"
		 sleep 3
		 ;; 	
		#X	退出此功能
			x|X)
		 clear
		 break;;	 
		 *)
		 echo ""  
		 echo -e "\e[1;31m输入错误提示!!!请输入正确选项|A|B|C|D|E|F|G|H|X|\e[0m";;

	esac
	done
	}
	#防火墙管理功能
	chang_ufwc(){
	clear
	while true
	do
	cat <<-EOF
	╦ ╦┌─┐┬  ┌─┐┌─┐┌┬┐┌─┐  ┌┬┐┌─┐  ┌┬┐┬ ┬┌─┐
	║║║├┤ │  │  │ ││││├┤    │ │ │   │ ├─┤├┤ 
	╚╩╝└─┘┴─┘└─┘└─┘┴ ┴└─┘   ┴ └─┘   ┴ ┴ ┴└─┘	 
	EOF
	echo -e "\e[1;36m            防火墙管理功能\e[0m"
	cat <<-EOF

		 A  安装ufw防火墙
		 B  放行IP或端口
		 C  删除IP或端口
		 D  禁止ping或允许ping
		 E  拒绝所有流量入站
		 F  启动或关闭ufw防火墙
		 G  重新加载ufw配置
		 H  查看端口放行状态与ufw运行状态
		 X  退出此功能
			
		EOF
	read -p $(echo -e "\e[1;33m请输入操作选项|A|B|C|D|E|F|G|H|X|:\e[0m") ab_ufwok
	clear
	case "$ab_ufwok" in


		 #A  安装ufw防火墙
		 a|A) 
		 cat_ufw=$(test -e /lib/systemd/system/ufw.service;echo $?)
		  if [ $cat_ufw -ne 0 ];then
			 echo "开始安装ufw"
				 sudo apt update 
				 sudo apt install ufw                             
				 wait            
			 sudo systemctl start ufw
			 sudo systemctl enable ufw
			 sudo systemctl status ufw --no-pager
			 wait
				  echo -e "\e[1;31mufw安装完成\e[0m"
			 sleep 4
		  else
			 echo ""
			 echo -e "\e[1;31m检测到此系统已经安装过ufw，无须再安装了.\e[0m"
			 sleep 3
		  fi
		 ;;
		 #B  放行IP或端口
		 b|B)
	cat <<-EOF
		^    ^    ^    ^    ^    ^    ^  
	   /w\  /e\  /l\  /c\  /o\  /m\  /e\ 
	  <___><___><___><___><___><___><___>
				 放行IP或端口
	EOF
			 while true
			  do
			   echo ""	      
			   read -p $(echo -e "\e[1;33m输入N为退出,『A』是放行端口『B』是放行IP请输入:\e[0m") ye_no
				   case "$ye_no" in
					  a|A)
					   while true
						 do
						 echo ""
						 read -p $(echo -e "\e[1;36m输入N为退出,请输入要放行的端口:\e[0m") prox_u
						 if [[ $prox_u -gt 19 ]];then
								if [[ $prox_u -eq 53 ]];then
									sudo ufw allow $prox_u/udp 
									wait
									echo ""
									echo "  $prox_u/udp端口已添加,『G重新加载ufw配置』才生效。"
									echo ""                                                                                
								else
									 sudo ufw allow $prox_u/tcp
									 wait
									 echo ""
									 echo "  $prox_u/tcp端口已添加,『G重新加载ufw配置』才生效。"
									 echo ""
								fi
						  elif [[ $prox_u == ""  ]];then
						   echo "输入不能为空，请重新输入."
						  elif [[ "$prox_u" = "n" ]];then
						   echo ""
						   echo "成功-退出此项功能" 
						   echo ""
						   break                     
						  else
						   clear
						   echo ""
						   echo -e "\e[1;31m哎呀！乱输入，这次中奖了吧；请重新输入！\e[0m" 
						   echo ""                      
						  fi 
						  done  
						  ;;
						  b|B)
						   echo ""
						   echo -e "\e[1;31m提示!此项只用于放行内部docker的ip，切勿添加放行外部ip\e[0m" 
						   while true
							  do  
							  echo ""                        
							  read -p $(echo -e "\e[1;36m输入N为退出,请输入要放行的IP:\e[0m") ip_docker 
							   if [[ $ip_docker =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
								soda=$(echo $ip_docker | cut -d "." -f 1,2,3)
								sudo ufw allow from $soda.0/24  >/dev/null 2>&1                            
								wait
								 echo "  $soda.0/24  ip已添加,『G重新加载ufw配置』才生效。"
							 sleep 3                            
								elif [[ "$ip_docker" = "n" ]];then
								echo ""
								echo "成功-退出此项功能" 
								echo ""
								break   
							   else                            
								 clear
								 echo ""
								 echo -e "\e[1;31m哎呀！乱输入，这次中奖了吧；请重新输入！\e[0m" 
								 echo ""
							   fi                          
							done 
							;;
					*)
				   echo -e "\e[1;31m喔!!!请输入正确的选项A或B\e[0m" ;;
				   esac
				   if [[ "$ye_no" = "n" ]];then
					echo ""
					echo "成功-退出此项功能" 
					echo ""
					clear
					break 	
				   fi          	 
			done
		  ;;
		 #C  删除IP或端口
		 c|C)
	cat <<-EOF
		^    ^    ^    ^    ^    ^    ^  
	   /w\  /e\  /l\  /c\  /o\  /m\  /e\ 
	  <___><___><___><___><___><___><___>
				  删除IP或端口
	EOF
			 while true
			  do
			   echo ""	      
			   read -p $(echo -e "\e[1;33m输入N为退出,『A』是删除端口『B』是删除IP请输入:\e[0m") ye_nzo
				   case "$ye_nzo" in
					  a|A)
					   while true
						 do
						 echo ""
						 read -p $(echo -e "\e[1;36m输入N为退出,请输入要删除的端口:\e[0m") prox_ud
						 if [[ $prox_ud -gt 19 ]];then                   
									 sudo ufw delete allow $prox_ud/tcp >/dev/null 2>&1      #删除开放的端口
									 sudo ufw delete deny $prox_ud/tcp >/dev/null 2>&1        #删除关闭的端口
									 sudo ufw delete allow $prox_ud/udp >/dev/null 2>&1        #删除开放UDP的端口
									 sudo ufw delete deny $prox_ud/udp >/dev/null 2>&1        #删除关闭UDP的端口
									 wait
									 echo ""
									 echo "  $prox_ud/tcp端口已删除,『G重新加载ufw配置』才生效。"
									 echo ""
								
						  elif [[ $prox_ud == ""  ]];then
						   echo "输入不能为空，请重新输入."
						  elif [[ "$prox_ud" = "n" ]];then
						   echo ""
						   echo "成功-退出此项功能" 
						   echo ""
						   break                     
						  else                      
						   clear
						   echo ""
						   echo -e "\e[1;31m哎呀！乱输入，这次中奖了吧；请重新输入！\e[0m" 
						   echo ""                      
						  fi 
						  done  
						  ;;
						  b|B)                       
						   while true
							  do
							  echo ""                          
							  read -p $(echo -e "\e[1;36m输入N为退出,请输入要删除的IP:\e[0m") ip_dockerd 
							   if [[ $ip_dockerd =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
								sodad=$(echo $ip_dockerd | cut -d "." -f 1,2,3)                         
								sudo ufw delete allow  from $sodad.0/24 >/dev/null 2>&1
								sudo ufw delete deny  from $sodad.0/24  >/dev/null 2>&1
															
								wait
								 echo "  $sodad.0/24 IP已经删除,『G重新加载ufw配置』才生效。"
							 sleep 3                            
								elif [[ "$ip_dockerd" = "n" ]];then
								echo ""
								echo "成功-退出此项功能" 
								echo ""
								break   
							   else                             
								 clear
								 echo ""
								 echo -e "\e[1;31m哎呀！乱输入，这次中奖了吧；请重新输入！\e[0m" 
								 echo ""
							   fi                          
							done 
							;;
					*)
				   echo -e "\e[1;31m喔!!!请输入正确的选项A或B\e[0m" ;;
				   esac
				   if [[ "$ye_nzo" = "n" ]];then
					echo ""
					echo "成功-退出此项功能" 
					echo ""
					clear
					break 	
				   fi          	 
			done
		  ;; 	 
		 #D  禁止ping或允许ping
		 d|D)
	cat <<-EOF
		^    ^    ^    ^    ^    ^    ^  
	   /w\  /e\  /l\  /c\  /o\  /m\  /e\ 
	  <___><___><___><___><___><___><___>
				 禁止ping&允许ping
	EOF
			 while true
			  do
			   echo ""	      
			   read -p $(echo -e "\e[1;33m输入N为退出,『A』禁用ping『B』允许ping:\e[0m") ye_npo
				   case "$ye_npo" in
						a|A)
					  icmp_ufw=$(test -e /etc/ufw/before.rules;echo $?)
					  if [ $icmp_ufw -ne 0 ];then
								 echo ""
								 echo -e "\e[1;31m检测到此系统/etc/ufw/before.rules下没有配置文件，需要先安装ufw防火墙\e[0m"
								sleep 3
					 else
								#禁用ping
								 sudo sed -i 's/^-A ufw-before-input -p icmp --icmp-type destination-unreachable -j ACCEPT/-A ufw-before-input -p icmp --icmp-type destination-unreachable -j DROP/g' /etc/ufw/before.rules >/dev/null 2>&1
								 sudo sed -i 's/^-A ufw-before-input -p icmp --icmp-type source-quench -j ACCEPT/-A ufw-before-input -p icmp --icmp-type source-quench -j DROP/g' /etc/ufw/before.rules >/dev/null 2>&1
								 sudo sed -i 's/^-A ufw-before-input -p icmp --icmp-type time-exceeded -j ACCEPT/-A ufw-before-input -p icmp --icmp-type time-exceeded -j DROP/g' /etc/ufw/before.rules >/dev/null 2>&1
								 sudo sed -i 's/^-A ufw-before-input -p icmp --icmp-type parameter-problem -j ACCEPT/-A ufw-before-input -p icmp --icmp-type parameter-problem -j DROP/g' /etc/ufw/before.rules >/dev/null 2>&1
								 sudo sed -i 's/^-A ufw-before-input -p icmp --icmp-type echo-request -j ACCEPT/-A ufw-before-input -p icmp --icmp-type echo-request -j DROP/g' /etc/ufw/before.rules >/dev/null 2>&1
							   #不允许别人通过mdns获取系统名：
								 sudo sed -i 's/^-A ufw-before-input -p udp -d 224.0.0.251 --dport 5353 -j ACCEPT/-A ufw-before-input -p udp -d 224.0.0.251 --dport 5353 -j DROP/g' /etc/ufw/before.rules >/dev/null 2>&1
								#关闭upnp
								 sudo sed -i 's/^-A ufw-before-input -p udp -d 239.255.255.250 --dport 1900 -j ACCEPT/-A ufw-before-input -p udp -d 239.255.255.250 --dport 1900 -j DROP/g' /etc/ufw/before.rules >/dev/null 2>&1              
								 sudo sed -i '/^-A ufw-before-input -p udp -d 239.255.255.250 --dport 1900 -j*/{n;s/^.*/-A ufw-before-output -p udp -d 239.255.255.250 --dport 1900 -j DROP/g}' /etc/ufw/before.rules >/dev/null 2>&1 
				  
						  wait
						  echo ""
					  echo -e "\e[1;36m已经禁用ping.『G重新加载ufw配置』才生效。\e[0m"
					  sleep 3 	              
					   fi  
						  ;;
						 b|B)
					   icmp_ufw=$(test -e /etc/ufw/before.rules;echo $?)
					   if [ $icmp_ufw -ne 0 ];then
								  echo ""
								  echo -e "\e[1;31m检测到此系统/etc/ufw/before.rules下没有配置文件，需要先安装ufw防火墙\e[0m"
								  sleep 3
					   else
								 #允许ping
								 sudo sed -i 's/^-A ufw-before-input -p icmp --icmp-type destination-unreachable -j DROP/-A ufw-before-input -p icmp --icmp-type destination-unreachable -j ACCEPT/g' /etc/ufw/before.rules >/dev/null 2>&1
								 sudo sed -i 's/^-A ufw-before-input -p icmp --icmp-type source-quench -j DROP/-A ufw-before-input -p icmp --icmp-type source-quench -j ACCEPT/g' /etc/ufw/before.rules >/dev/null 2>&1
								 sudo sed -i 's/^-A ufw-before-input -p icmp --icmp-type time-exceeded -j DROP/-A ufw-before-input -p icmp --icmp-type time-exceeded -j ACCEPT/g' /etc/ufw/before.rules >/dev/null 2>&1
								 sudo sed -i 's/^-A ufw-before-input -p icmp --icmp-type parameter-problem -j DROP/-A ufw-before-input -p icmp --icmp-type parameter-problem -j ACCEPT/g' /etc/ufw/before.rules >/dev/null 2>&1
								 sudo sed -i 's/^-A ufw-before-input -p icmp --icmp-type echo-request -j DROP/-A ufw-before-input -p icmp --icmp-type echo-request -j ACCEPT/g' /etc/ufw/before.rules >/dev/null 2>&1
								#允许别人通过mdns获取系统名：
								#sudo sed -i 's/^-A ufw-before-input -p udp -d 224.0.0.251 --dport 5353 -j DROP/-A ufw-before-input -p udp -d 224.0.0.251 --dport 5353 -j ACCEPT/g' /etc/ufw/before.rules >/dev/null 2>&1
								#开启upnp
								#sudo sed -i 's/^-A ufw-before-input -p udp -d 239.255.255.250 --dport 1900 -j DROP/-A ufw-before-input -p udp -d 239.255.255.250 --dport 1900 -j ACCEPT/g' /etc/ufw/before.rules >/dev/null 2>&1
							   #sudo sed -i '/^-A ufw-before-input -p udp -d 239.255.255.250 --dport 1900 -j*/{n;s/^.*/ /g}' /etc/ufw/before.rules >/dev/null 2>&1
				  
								wait
								echo ""
								echo -e "\e[1;36m已经允许ping.『G重新加载ufw配置』才生效。\e[0m"
								sleep 3
							fi
						  ;;
					*)
				   echo -e "\e[1;31m喔!!!请输入正确的选项A或B\e[0m" ;;
				   esac
				   if [[ "$ye_npo" = "n" ]];then
					echo ""
					echo "成功-退出此项功能" 
					echo ""
					clear
					break 	
				   fi          	 
			 done
			 ;; 	 
		 #E  拒绝所有流量入站
			e|E)
				  while true
				   do 
	cat <<-EOF 
		^    ^    ^    ^    ^    ^    ^  
	   /w\  /e\  /l\  /c\  /o\  /m\  /e\ 
	  <___><___><___><___><___><___><___>
				 拒绝所有流量入站
	EOF
						 
					  read -p $(echo -e "\e[1;33m你确定关闭?[y/n]:\e[0m") ye_no
					  case "$ye_no" in
					  yes|y|Yes|YES|Y)                  
						 sudo ufw default deny incoming >/dev/null 2>&1
						 wait
						 echo ""
					 echo -e "\e[6;32m拒绝所有流量入站成功\e[32;0m"
					 sleep 3
					 break    
						 ;;
					   n|no|NO|N)
						clear
						break
						 ;;
						 *)
						 echo -e "\e[1;31m喔!!!请输入正确的选项Y或n\e[0m" ;;
					   esac
			   done  	 
		 ;;
		 #F  启动或关闭ufw防火墙
		f|F)
	cat <<-EOF
		^    ^    ^    ^    ^    ^    ^  
	   /w\  /e\  /l\  /c\  /o\  /m\  /e\ 
	  <___><___><___><___><___><___><___>
	  
			  启动ufw规则&关闭ufw规则
	EOF
			 while true
			  do
			   echo ""	      
			   read -p $(echo -e "\e[1;33m输入N为退出,『A』启动ufw『B』关闭ufw请输入:\e[0m") ye_no
				   case "$ye_no" in
					  a|A)
					   echo ""
					   sudo systemctl start ufw
					   sudo systemctl enable ufw >/dev/null 2>&1
					   sudo ufw enable 
					   wait
					   sudo ufw status                   
					   echo -e "\e[1;36m   已启动ufw规则,以上是端口放行状态\e[0m"
					   sleep 5
						 ;;                     
					  b|B)
					   sudo ufw disable
					   sudo ufw status
					   wait
					   echo ""
					   echo -e "\e[1;36m   ufw规则已关闭,以上是端口状态\e[0m"
					   sleep 5
						;;
					*)
				   echo -e "\e[1;31m喔！！！请输入正确的选项A或B\e[0m" ;;
				   esac
				   if [[ "$ye_no" = "n" ]];then
					echo ""
					echo "成功-退出此项功能" 
					echo ""
					clear
					break 	
				   fi          	 
			done
		;;
		 #G  重新加载ufw配置
			g|G)
				  while true
				   do 
	cat <<-EOF 
		^    ^    ^    ^    ^    ^    ^  
	   /w\  /e\  /l\  /c\  /o\  /m\  /e\ 
	  <___><___><___><___><___><___><___>
	  
				 重新加载ufw配置
	EOF
						 
					  read -p $(echo -e "\e[1;33m你确定重新加载?[y/n]:\e[0m") ye_no
					  case "$ye_no" in
					  yes|y|Yes|YES|Y)                  
						 yes | sudo ufw reload  >/dev/null 2>&1
						 wait
						 echo ""
					 echo -e "\e[6;32m重新加载ufw配置成功\e[32;0m"
					 sleep 3
					 break    
						 ;;
					   n|no|NO|N)
						clear
						break
						 ;;
						 *)
						 echo -e "\e[1;31m喔!!!请输入正确的选项Y或n\e[0m" ;;
					   esac
			   done  	 
			;;        
		 #H  查看端口放行状态与ufw运行状态
			h|H)
		 
		 sudo ufw status
		 echo -e "\e[6;31m-------------端口放行状态-------------\e[32;0m"
		 sudo systemctl status ufw --no-pager
		 echo -e "\e[6;32m-------------ufw软件运行状态-------------\e[32;0m"
		 wait
		 echo ""
		 echo ""
		 echo -e "\e[6;32m 以上是端口放行状态与ufw运行状态，7秒后返回主菜单界面\e[32;0m"
		 sleep 7
			;;
		 #X  退出此功能
			x|X)
		 menu
		 break
			;;	 
		 *)
		 echo -e "\e[1;31m输入错误提示!!!请输入正确选项|A|B|C|D|E|F|G|H|X|\e[0m";;        
	esac
	done 
	}
	clear_ccd(){
	clear
				  while true
				   do 
	cat <<-EOF 
		^    ^    ^    ^    ^    ^    ^  
	   /w\  /e\  /l\  /c\  /o\  /m\  /e\ 
	  <___><___><___><___><___><___><___>
	  
				 垃圾 清理 功能
	EOF
					  echo ""	 
					  read -p $(echo -e "\e[1;33m请确定??[y/n]:\e[0m") ye_no
					  case "$ye_no" in
					  yes|y|Yes|YES|Y)                  
							 sudo rm -rf /var/log/* 
							 sudo rm -f /var/log/*/*
							 history -c                        
							  if [[ "$USER" == "root" ]];then                             
								 getent passwd {1000..6000} | sed -n '/\/home\/.*:\/bin\/bash/p' | cut -d: -f1 > ./honame.filx
								  nun_ds=./honame.filx
								  Rlineg=$(wc -l $nun_ds |cut -d' ' -f1)
								   for i in $(seq "$Rlineg")
									do
									 num_b=`head $nun_ds | tail -1`
									 echo "clear" | sudo tee /home/$num_b/.bash_history      
									 sed -i "/$num_b/d" $nun_ds
								   done
								   wait
								   sudo rm -rf ./honame.filx  
								   echo "clear" | sudo tee  /root/.bash_history
								   sudo apt autoremove  >/dev/null 2>&1  
								   wait
									echo -e "\e[6;32m成功清理操作痕迹\e[32;0m"
								sleep 3 
								clear
								menu
								break                                    
							   else
									
									echo "clear" | sudo tee  /home/$USER/.bash_history
									echo "clear" | sudo tee  /root/.bash_history
									sudo apt autoremove  >/dev/null 2>&1
									wait
									echo -e "\e[6;32m成功清理操作痕迹\e[32;0m"
								sleep 3
								clear
								menu
								break                     
							   fi
	   
						 ;;
					   n|no|NO|N)
							   clear
							   menu
							   break
						 ;;
						 *)
						 echo -e "\e[1;31m喔!!!请输入正确的选项Y或n\e[0m" ;;
					   esac
			   done  	 
	}
	vns_tat(){
	clear
	while true
	 do
	cat <<-EOF
	╦ ╦┌─┐┬  ┌─┐┌─┐┌┬┐┌─┐  ┌┬┐┌─┐  ┌┬┐┬ ┬┌─┐
	║║║├┤ │  │  │ ││││├┤    │ │ │   │ ├─┤├┤ 
	╚╩╝└─┘┴─┘└─┘└─┘┴ ┴└─┘   ┴ └─┘   ┴ ┴ ┴└─┘	 
		EOF
	echo -e "\e[1;36m           流量统计功能\e[0m"
	echo ""	     
		cat <<-EOF
		A  安装vnstat软件
		B  查看流量使用情况
		X  退出此功能
		EOF
		read -p $(echo -e "\e[1;33m请输入操作选项|A|B|X|:\e[0m") or_der
		case "$or_der" in
			 a|A)
					   echo ""
					   read -p $(echo -e "\e[1;33m确定安装?[y/n]:\e[0m") yes_nyo
					   case "$yes_nyo" in 
						y|Y|yes|YES) 	    	                 
						 sudo apt update
							 sudo apt-get install vnstat vnstati -y
							 
						 wait
						 echo -e "\e[1;36mvnstat安装完毕\e[0m"
						#默认开机启动
							  sudo update-rc.d vnstat enable
							  sleep 1
						  echo -e "\e[1;36mvnstat已设置开机启动\e[0m"
						  sleep 2
						  sudo sed -i "s/Interface*[ \t]*\"\"*/Interface \"eth0\"/g" /etc/vnstat.conf
						  clear	                  
						  ;;
						   *)
						echo ""
						echo -e "\e[1;32m巨大的成功,vnstat没安装，再见！\e[0m"
						sleep 2
						clear
						esac
		 ;;
			 b|B)
			 vnstat -m
		 echo ""
		 echo -e "\e[1;36m以上是按月份显示的流量使用情况,9秒后自动返回主菜单\e[0m"  
		 echo ""
		 sleep 9
		 clear	 	           
		 ;;       
		 x|X)
		 clear
		 menu
		 break
		 ;;
		 *)
		 clear
		 echo ""
		 echo -e "\e[1;31m输入错误提示!!!请输入正确选项|A|B|X|\e[0m";;
			 esac
			 
	done
	}

	configinf(){
	ver="1.0.2"

	trap _exit INT QUIT TERM

	_red() {
		printf '\033[0;31;31m%b\033[0m' "$1"
	}

	_green() {
		printf '\033[0;31;32m%b\033[0m' "$1"
	}

	_yellow() {
		printf '\033[0;31;33m%b\033[0m' "$1"
	}

	_blue() {
		printf '\033[0;31;36m%b\033[0m' "$1"
	}

	_exists() {
		local cmd="$1"
		if eval type type > /dev/null 2>&1; then
			eval type "$cmd" > /dev/null 2>&1
		elif command > /dev/null 2>&1; then
			command -v "$cmd" > /dev/null 2>&1
		else
			which "$cmd" > /dev/null 2>&1
		fi
		local rt=$?
		return ${rt}
	}

	_exit() {
		_red "\n检测到退出操作，脚本终止！\n"
		# clean up
		rm -fr speedtest.tgz speedtest-cli benchtest_*
		exit 1
	}

	get_opsy() {
		[ -f /etc/redhat-release ] && awk '{print $0}' /etc/redhat-release && return
		[ -f /etc/os-release ] && awk -F'[= "]' '/PRETTY_NAME/{print $3,$4,$5}' /etc/os-release && return
		[ -f /etc/lsb-release ] && awk -F'[="]+' '/DESCRIPTION/{print $2}' /etc/lsb-release && return
	}

	next() {
		printf "%-70s\n" "-" | sed 's/\s/-/g'
	}

	speed_test() {
		local nodeName="$2"
		[ -z "$1" ] && ./speedtest-cli/speedtest --progress=no --accept-license --accept-gdpr > ./speedtest-cli/speedtest.log 2>&1 || \
		./speedtest-cli/speedtest --progress=no --server-id=$1 --accept-license --accept-gdpr > ./speedtest-cli/speedtest.log 2>&1
		if [ $? -eq 0 ]; then
			local dl_speed=$(awk '/Download/{print $3" "$4}' ./speedtest-cli/speedtest.log)
			local up_speed=$(awk '/Upload/{print $3" "$4}' ./speedtest-cli/speedtest.log)
			local latency=$(awk '/Latency/{print $2" "$3}' ./speedtest-cli/speedtest.log)
			if [[ -n "${dl_speed}" && -n "${up_speed}" && -n "${latency}" ]]; then
				printf "\033[0;33m%-18s\033[0;32m%-18s\033[0;31m%-20s\033[0;36m%-12s\033[0m\n" " ${nodeName}" "${up_speed}" "${dl_speed}" "${latency}"
			fi
		fi
	}

	io_test() {
		(LANG=C dd if=/dev/zero of=benchtest_$$ bs=512k count=$1 conv=fdatasync && rm -f benchtest_$$ ) 2>&1 | awk -F, '{io=$NF} END { print io}' | sed 's/^[ \t]*//;s/[ \t]*$//'
	}

	calc_disk() {
		local total_size=0
		local array=$@
		for size in ${array[@]}
		do
			[ "${size}" == "0" ] && size_t=0 || size_t=`echo ${size:0:${#size}-1}`
			[ "`echo ${size:(-1)}`" == "K" ] && size=0
			[ "`echo ${size:(-1)}`" == "M" ] && size=$( awk 'BEGIN{printf "%.1f", '$size_t' / 1024}' )
			[ "`echo ${size:(-1)}`" == "T" ] && size=$( awk 'BEGIN{printf "%.1f", '$size_t' * 1024}' )
			[ "`echo ${size:(-1)}`" == "G" ] && size=${size_t}
			total_size=$( awk 'BEGIN{printf "%.1f", '$total_size' + '$size'}' )
		done
		echo ${total_size}
	}

	check_virt(){
		_exists "dmesg" && virtualx="$(dmesg 2>/dev/null)"
		if _exists "dmidecode"; then
			sys_manu="$(dmidecode -s system-manufacturer 2>/dev/null)"
			sys_product="$(dmidecode -s system-product-name 2>/dev/null)"
			sys_ver="$(dmidecode -s system-version 2>/dev/null)"
		else
			sys_manu=""
			sys_product=""
			sys_ver=""
		fi
		if   grep -qa docker /proc/1/cgroup; then
			virt="Docker"
		elif grep -qa lxc /proc/1/cgroup; then
			virt="LXC"
		elif grep -qa container=lxc /proc/1/environ; then
			virt="LXC"
		elif [[ -f /proc/user_beancounters ]]; then
			virt="OpenVZ"
		elif [[ "${virtualx}" == *kvm-clock* ]]; then
			virt="KVM"
		elif [[ "${cname}" == *KVM* ]]; then
			virt="KVM"
		elif [[ "${cname}" == *QEMU* ]]; then
			virt="KVM"
		elif [[ "${virtualx}" == *"VMware Virtual Platform"* ]]; then
			virt="VMware"
		elif [[ "${virtualx}" == *"Parallels Software International"* ]]; then
			virt="Parallels"
		elif [[ "${virtualx}" == *VirtualBox* ]]; then
			virt="VirtualBox"
		elif [[ -e /proc/xen ]]; then
			if grep -q "control_d" "/proc/xen/capabilities" 2>/dev/null; then
				virt="Xen-Dom0"
			else
				virt="Xen-DomU"
			fi
		elif [ -f "/sys/hypervisor/type" ] && grep -q "xen" "/sys/hypervisor/type"; then
			virt="Xen"
		elif [[ "${sys_manu}" == *"Microsoft Corporation"* ]]; then
			if [[ "${sys_product}" == *"Virtual Machine"* ]]; then
				if [[ "${sys_ver}" == *"7.0"* || "${sys_ver}" == *"Hyper-V" ]]; then
					virt="Hyper-V"
				else
					virt="Microsoft Virtual Machine"
				fi
			fi
		else
			virt="Dedicated"
		fi
	}
	ipv4_info() {
		local org="$(wget -q -T10 -O- ipinfo.io/org)"
		local city="$(wget -q -T10 -O- ipinfo.io/city)"
		local country="$(wget -q -T10 -O- ipinfo.io/country)"
		local region="$(wget -q -T10 -O- ipinfo.io/region)"
		if [[ -n "$org" ]]; then
			echo " ASN组织           : $(_blue "$org")"
		fi
		if [[ -n "$city" && -n "country" ]]; then
			echo " 位置              : $(_blue "$city / $country")"
		fi
		if [[ -n "$region" ]]; then
			echo " 地区              : $(_yellow "$region")"
		fi
		if [[ -z "$org" ]]; then
			echo " 地区              : $(_red "无法获取ISP信息")"
		fi
	}

	print_intro() {
		echo "--------------------- A Bench Script By Misaka No --------------------"
		echo "                     Blog: https://owo.misaka.rest                    "
		echo "版本号：v$ver"
		echo "更新日志：$changeLog"
	}

	# Get System information
	get_system_info() {
		cname=$( awk -F: '/model name/ {name=$2} END {print name}' /proc/cpuinfo | sed 's/^[ \t]*//;s/[ \t]*$//' )
		cores=$( awk -F: '/processor/ {core++} END {print core}' /proc/cpuinfo )
		freq=$( awk -F'[ :]' '/cpu MHz/ {print $4;exit}' /proc/cpuinfo )
		ccache=$( awk -F: '/cache size/ {cache=$2} END {print cache}' /proc/cpuinfo | sed 's/^[ \t]*//;s/[ \t]*$//' )
		tram=$( LANG=C; free -m | awk '/Mem/ {print $2}' )
		uram=$( LANG=C; free -m | awk '/Mem/ {print $3}' )
		swap=$( LANG=C; free -m | awk '/Swap/ {print $2}' )
		uswap=$( LANG=C; free -m | awk '/Swap/ {print $3}' )
		up=$( awk '{a=$1/86400;b=($1%86400)/3600;c=($1%3600)/60} {printf("%d days, %d hour %d min\n",a,b,c)}' /proc/uptime )
		if _exists "w"; then
			load=$( LANG=C; w | head -1 | awk -F'load average:' '{print $2}' | sed 's/^[ \t]*//;s/[ \t]*$//' )
		elif _exists "uptime"; then
			load=$( LANG=C; uptime | head -1 | awk -F'load average:' '{print $2}' | sed 's/^[ \t]*//;s/[ \t]*$//' )
		fi
		opsy=$( get_opsy )
		arch=$( uname -m )
		if _exists "getconf"; then
			lbit=$( getconf LONG_BIT )
		else
			echo ${arch} | grep -q "64" && lbit="64" || lbit="32"
		fi
		kern=$( uname -r )
		disk_size1=($( LANG=C df -hPl | grep -wvE '\-|none|tmpfs|devtmpfs|by-uuid|chroot|Filesystem|udev|docker|snapd' | awk '{print $2}' ))
		disk_size2=($( LANG=C df -hPl | grep -wvE '\-|none|tmpfs|devtmpfs|by-uuid|chroot|Filesystem|udev|docker|snapd' | awk '{print $3}' ))
		disk_total_size=$( calc_disk "${disk_size1[@]}" )
		disk_used_size=$( calc_disk "${disk_size2[@]}" )
		tcpctrl=$( sysctl net.ipv4.tcp_congestion_control | awk -F ' ' '{print $3}' )
	}
	# Print System information
	print_system_info() {
		if [ -n "$cname" ]; then
			echo " CPU 型号          : $(_blue "$cname")"
		else
			echo " CPU 型号          : $(_blue "无法检测到CPU型号")"
		fi
		echo " CPU 核心数        : $(_blue "$cores")"
		if [ -n "$freq" ]; then
			echo " CPU 频率          : $(_blue "$freq MHz")"
		fi
		if [ -n "$ccache" ]; then
			echo " CPU 缓存          : $(_blue "$ccache")"
		fi
		echo " 硬盘空间          : $(_yellow "$disk_total_size GB") $(_blue "($disk_used_size GB 已用)")"
		echo " 内存              : $(_yellow "$tram MB") $(_blue "($uram MB 已用)")"
		echo " Swap              : $(_blue "$swap MB ($uswap MB 已用)")"
		echo " 系统在线时间      : $(_blue "$up")"
		echo " 负载              : $(_blue "$load")"
		echo " 系统              : $(_blue "$opsy")"
		echo " 架构              : $(_blue "$arch ($lbit Bit)")"
		echo " 内核              : $(_blue "$kern")"
		echo " TCP加速方式       : $(_yellow "$tcpctrl")"
		echo " 虚拟化架构        : $(_blue "$virt")"
	}


	print_end_time() {
		end_time=$(date +%s)
		time=$(( ${end_time} - ${start_time} ))
		if [ ${time} -gt 60 ]; then
			min=$(expr $time / 60)
			sec=$(expr $time % 60)
			echo " 总共花费        : ${min} 分 ${sec} 秒"
		else
			echo " 总共花费        : ${time} 秒"
		fi
		date_time=$(date +%Y-%m-%d" "%H:%M:%S)
		echo " 时间          : $date_time"
	}

	! _exists "wget" && _red "Error: wget command not found.\n" && exit 1
	! _exists "free" && _red "Error: free command not found.\n" && exit 1
	start_time=$(date +%s)
	get_system_info
	check_virt
	clear
	print_intro
	next
	print_system_info
	next
	ipv4_info
	next
	print_end_time
	next
	echo -e "\e[1;33m将查询出来的信息用鼠标复制保存到文档中去，以上信息9秒后消失\e[0m"
	sleep 9

	}

	vr_xravy(){
	clear
	while true
	 do
	cat <<-EOF
	╦ ╦┌─┐┬  ┌─┐┌─┐┌┬┐┌─┐  ┌┬┐┌─┐  ┌┬┐┬ ┬┌─┐
	║║║├┤ │  │  │ ││││├┤    │ │ │   │ ├─┤├┤ 
	╚╩╝└─┘┴─┘└─┘└─┘┴ ┴└─┘   ┴ └─┘   ┴ ┴ ┴└─┘	 
		EOF
	echo -e "\e[1;36m           v2ray和xray的UUID管理功能\e[0m"
	echo ""	     
		cat <<-EOF
		A  替换UUID
		B  查看v2ray或xray运行状态
		X  退出此功能
		EOF
		read -p $(echo -e "\e[1;33m请输入操作选项|A|B|X|:\e[0m") or_uuidd
		case "$or_uuidd" in
			 a|A)
					   echo ""
					   read -p $(echo -e "\e[1;33m您确定?[y/n]:\e[0m") yes_nyx
					   case "$yes_nyx" in 
						y|Y|yes|YES) 	    	                 	                 
						 vr_ay=$(sudo systemctl status v2ray --no-pager  > /dev/null 2>&1;echo $?)
						 
						 if [[ "$vr_ay" == "0" ]]; then 	                         
								 tyblue "v2ray，启动状态"
								 pto="v2ray"
						  elif [[ "$vr_ay" == "3" ]]; then
									 echo "" 	                   
								 blue "v2ray没有启动，请将v2ray启动后再来修改"                                
							 elif [[ "$vr_ay" == "4" ]]; then
									 red "没安装v2ray将不会替换v2ray的UUID"
														
						 fi
						 xr_ay=$(sudo systemctl status xray --no-pager  > /dev/null 2>&1;echo $?)
							 if [[ "$xr_ay" == "0" ]]; then
									 tyblue "xray，启动状态"
									 pto="xray"
							 elif [[ "$xr_ay" == "3" ]]; then
									 echo "" 
									 blue "xray没有启动，请将xray启动后再来修改"               
							 elif [[ "$xr_ay" == "4" ]]; then     
									 red "没有安装xray将不会替换xray的UUID"
						 fi
						 #代码执行
						  if  [ "${pto}" == "" ];then
							 red "根据以上判断，没有满足修改UUID的条件，请检查v2ray,xray是否安装或v2ray,xray是否启动，没安装请安装，没启动请将其启动起来"
							 sleep 3
							 vr_xravy
							 break
						  else
							echo "" 
							green "将修改$pto的UUID"
							echo ""
								while true
									 do
								read -p $(echo -e "\e[1;33m请输入需要替换的旧UUID:\e[0m") uu_iDs
								emptytest=$(echo $uu_iDs | grep -E '[ ]' >/dev/null;echo $? )
								wi_et=$(cat /usr/local/etc/$pto/config.json | grep "${uu_iDs}" >/dev/null;echo $?)
								if [[ "$emptytest" == "0" ]];then
										red "输入的用户名不能包含空格。终止此操作请按ctrl+C"
										sleep 2 
								
								elif [ "${uu_iDs}" == "" ]; then    	                                
										red "输入不能为空。终止此操作请按ctrl+C"
										sleep 2 
								
								elif [[ ${#uu_iDs} -le 35 ]] ; then   
										red "输入的UUID字符个数不对，请重新输入。终止此操作请按ctrl+C"
										sleep 2
								elif [[ "$wi_et" == "1" ]];then
									  red "输入的UUID在$pto配置文件中不存在，请重新输入。终止此操作请按ctrl+C"
									  sleep 2   
								else
										green "输入的旧UUID正确，即将进入修改阶段。"
										break 
								fi
								
								done
								
						  fi
							  uuid_a="`uuidgen`"
							  sudo sed -i "s/${uu_iDs}/${uuid_a}/g"  /usr/local/etc/$pto/config.json
							  sleep 1
							  sudo systemctl restart $pto
							  echo ""
							  green "脚本已经对$pto进行重启了"
							  sudo systemctl status $pto  --no-pager 
							  echo ""
							  green "以上是$pto运行状态，如果没有正常启动，请检查问题出在哪里，然后再手动启动"
							  wait
							  
							  yellow "新UUID是$uuid_a"
							  green "在脚本旁边的new_UUID.txt文件中也能找到，请修改完后做好记录"
							  echo "$uuid_a" | tee -a ./new_UUID.txt > /dev/null 2>&1	                     	                      	                      
								  sleep 3                              	                     
						  ;;
						   *)
						echo ""
						echo -e "\e[1;32m巨大的成功,没修改，再见！\e[0m"
						sleep 2
						clear
						esac
		 ;;
			 b|B)
						 vr_ay=$(sudo systemctl status v2ray --no-pager  > /dev/null 2>&1;echo $?)
						 
						 if [[ "$vr_ay" == "0" ]]; then 
								 sudo systemctl status v2ray --no-pager
								 echo "" 
								 tyblue "v2ray运行正常"
								 
						  elif [[ "$vr_ay" == "3" ]]; then
								 sudo systemctl status v2ray --no-pager
								 echo ""  
								 blue "v2ray没有启动"                                
							 elif [[ "$vr_ay" == "4" ]]; then
									 echo "" 
									 red "没安装v2ray"
														
						 fi
						 xr_ay=$(sudo systemctl status xray --no-pager  > /dev/null 2>&1;echo $?)
							 if [[ "$xr_ay" == "0" ]]; then
									 sudo systemctl status xray --no-pager 
									 echo "" 
									 tyblue "xray运行正常"
									 pto="xray"
							 elif [[ "$xr_ay" == "3" ]]; then
									 sudo systemctl status xray --no-pager 
									 echo "" 
									 blue "xray没有启动"               
							 elif [[ "$xr_ay" == "4" ]]; then
									 echo ""      
									 red "没有安装xray"
						fi
						red "9秒后返回主菜单"
						sleep 9 
							clear
		 ;;       
		 x|X)
		 clear
		 menu
		 break
		 ;;
		 *)
		 clear
		 echo ""
		 echo -e "\e[1;31m输入错误提示!!!请输入正确选项|A|B|X|\e[0m";;
			 esac
			 
	done
	}
	#swap分区功能
	swa_disk(){
	clear
	while true
	 do
	cat <<-EOF
	╦ ╦┌─┐┬  ┌─┐┌─┐┌┬┐┌─┐  ┌┬┐┌─┐  ┌┬┐┬ ┬┌─┐
	║║║├┤ │  │  │ ││││├┤    │ │ │   │ ├─┤├┤ 
	╚╩╝└─┘┴─┘└─┘└─┘┴ ┴└─┘   ┴ └─┘   ┴ ┴ ┴└─┘	 
		EOF
	echo -e "\e[1;36m         swap分区功能\e[0m"
	echo ""	     
		cat <<-EOF
		A  新增swap分区
		B  swap分区管理
		X  退出此功能	
		
		EOF
		read -p $(echo -e "\e[1;33m『此功能会默认创建4GB的swap分区用于缓解内存不足』请输入操作选项|A|B|X|:\e[0m") or_der
		case "$or_der" in
			 a|A)
					   echo ""
					   read -p $(echo -e "\e[1;33m您确定?[y/n]:\e[0m") yes_nbx
					   case "$yes_nbx" in 
						y|Y|yes|YES) 	    	                 	                 
						   #swap分区
							   echo $(dd if=/dev/zero of=/mnt/swap bs=1M count=4096)
							   wait
							   echo "swap分区结束,共4GB"
							   test -e /mnt/swap &&  chmod 600 /mnt/swap || error
								echo $(mkswap /mnt/swap)
								echo $(swapon /mnt/swap)
								[ -z "$(swapon -s | grep /mnt/swap)" ] && echo "swap分区没有挂载成功"
								echo '/mnt/swap   swap   swap   defaults  0   0' | tee -a /etc/fstab
								[ -z "$(mount -a)" ] && echo "swap创建成功" || echo "swap创建没有成功"
							   sleep 6
						esac
		 ;;
			 b|B)
					clear
						while true
							 do
							 echo ""
							 echo -e "\e[1;36m       以下是swap分区管理功能\e[0m"
							 echo  
	cat <<-EOF
		A  重新挂载swap分区
		B  查看swap分区状态
		C  !!!占位而已
		D  !!!占位而已
		E  !!!占位而已
		X  退出swap分区管理
		EOF
								  echo ""
								  red "可能你会遇见报错,直接按CTRL+C键终止掉后就不要来用这个功能了。"
								  echo ""
								  read -p $(echo -e "\e[1;33m请输入想要的操作选项|A|B|C|D|X|:\e[0m") actiokm
								  clear
								  case "$actiokm" in
							   a|A)
								clear
								# 重新挂载swap分区
									test -e /mnt/swap &&  chmod 600 /mnt/swap || error
									echo $(mkswap /mnt/swap)
									echo $(swapon /mnt/swap)
									 [ -z "$(swapon -s | grep /mnt/swap)" ] && echo "swap分区没有挂载成功"
									 echo '/mnt/swap   swap   swap   defaults  0   0' | tee -a /etc/fstab
									 [ -z "$(mount -a)" ] && echo "swap创建成功" || echo "swap创建没有成功"
									  sleep 3
							 ;;
								b|B)
							  clear
							  # 
							  configinf
								  sleep 1
								  clear
							  ;;
							c|C)
							   clear
								# 
							   echo -e "\e[1;38m!!!占位而已:\e[0m"
							 ;;
								d|D)
							   clear
								# 
								echo -e "\e[1;38m!!!占位而已:\e[0m"
								 ;;
								e|E)
							   clear
								 # 
								 echo -e "\e[1;38哈哈!!!占位而已,啥都没有写:\e[0m"
								 ;;
							 x|X)
							  
							   break;;
								 *)
								echo -e "\e[1;31m输入错误提示!!!请输入正确选项|A|B|C|D|X|\e[0m";;

								   esac
							 done 
		 ;;       
		 x|X)
		 clear
		 menu
		 break
		 ;;
		 *)
		 clear
		 echo ""
		 echo -e "\e[1;31m输入错误提示!!!请输入正确选项|A|B|X|\e[0m";;
			 esac
			 
	done
	}

	# ╦ ╦┌─┐┬  ┌─┐┌─┐┌┬┐┌─┐  ┌┬┐┌─┐  ┌┬┐┬ ┬┌─┐
	# ║║║├┤ │  │  │ ││││├┤    │ │ │   │ ├─┤├┤ 
	# ╚╩╝└─┘┴─┘└─┘└─┘┴ ┴└─┘   ┴ └─┘   ┴ ┴ ┴└─┘	
	 
	#菜单打印函数定义
	menu(){
	clear
	cat <<-EOF
	EOF
	echo -e "\e[1;36m**********************\e[0m"
	echo -e "\e[1;36m*      V P S 管理    *\e[0m"
	echo -e "\e[1;36m**********************\e[0m"
	echo $""
	cat <<-EOF
	 [1]  系统用户管理
	 [2]  ssh登陆管理
	 [3]  密钥修改功能
	 [4]  ufw防火墙管理功能
	 [5]  流量统计功能
	 [6]  垃圾 清理 功能
	 [7]  vps配置信息查询
	 [8]  v2ray和xray的UUID管理功能
	 [9]  swap分区管理功能		 	
	 [X]  退出脚本
	EOF
	}

	while true
	do
	#用户选择需要操作的内容 
	echo ""
	menu
	echo ""
	read -p $(echo -e "\e[1;32m===========>>请输入您的选项并按回车:\e[0m") action
	clear
	menu	
	case $action in 
		11|help)
		menu
		;;
		1)
		usersud_ef
		;;
		2)
		sshd_cheng
		;;
		3)
		cheng_Vres_key
		;;
		4)
		chang_ufwc
		;;
		5)
		vns_tat
		;;
		6)
		clear_ccd
		;;
		7)
		configinf
		;;
		8)
		vr_xravy
		;;
		9)
		swa_disk
		;;
		x|X)
		exit
		;;

	esac
	done
}


unt_ll() {
	ifInput=
	#检测系统版本，设置cron变量
	verson=$(grep '^ID=' /etc/os-release | cut -d '=' -f 2 | sed 's/"//g')
	print_verson=$(grep '^PRETTY_NAME=' /etc/os-release | cut -d '=' -f 2)
	if [ ${verson} == "centos" ];then
		commd=crond
		cron_config="/var/spool/cron"
	elif [[ ${verson} == "ubuntu" || ${verson} == "debian" ]];then
		commd=cron
		cron_config="/var/spool/cron/crontabs"
	else
		echo ""
	fi
	select=$*
	#卸载流量监控脚本
	echo ""
	echo -e "${yellow}正在卸载监控脚本……${none}"
	echo ""
	test -e /etc/del_sum.sh && rm -rf /etc/del_sum.sh
	test -e /etc/test_sum.sh && rm -rf /etc/test_sum.sh
	test -e /etc/cf && rm -rf /etc/cf
	test -e /usr/bin/vspeed && rm -rf /usr/bin/vspeed
	test -e ${cron_config}/root && sed -i "/del_sum.sh/d;/test_sum.sh/d" ${cron_config}/root
	systemctl disable ${commd}; systemctl stop ${commd}
}


#安装Nginx
install_nginx() {

	#安裝先決條件:
	apt install curl gnupg2 ca-certificates lsb-release ubuntu-keyring -y

	#導入官方 nginx 簽名密鑰，以便 apt 可以驗證包 真實性。 獲取密鑰:
	curl https://nginx.org/keys/nginx_signing.key | gpg --dearmor | sudo tee /usr/share/keyrings/nginx-archive-keyring.gpg >/dev/null

	#驗證下載的文件是否包含正確的密鑰:
	gpg --dry-run --quiet --no-keyring --import --import-options import-show /usr/share/keyrings/nginx-archive-keyring.gpg

	#------------------------------------------------------------------------------------
	#要為穩定的 nginx 包設置 apt 存儲庫， 運行以下命令:1.22.1版本
	echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] http://nginx.org/packages/ubuntu `lsb_release -cs` nginx" | sudo tee /etc/apt/sources.list.d/nginx.list
	#------------------------------------------------------------------------------------
	#設置存儲庫固定以更喜歡我們的包 分發提供的:
	echo -e "Package: #\nPin: origin nginx.org\nPin: release o=nginx\nPin-Priority: 900\n" | sudo tee /etc/apt/preferences.d/99nginx

	#要安裝 nginx，請運行以下命令:
	apt update -y
	apt install nginx -y

	#重启nginx:
	systemctl restart nginx
}



#安装x-ui面板
install_xui() {
	# 卸载流量脚本
	unt_ll
	#更新系统，安装必要组件
	apt update -y && apt upgrade -y
	apt install -y curl && apt install -y socat && apt install -y nano
	
	#开启BBR加速
	echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
	echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
	sysctl -p

	#查看是否已开启BBR加速：
	lsmod | grep bbr
	sleep 1s

	clear && echo && echo 开始安装x-ui面板...
	sleep 2
	mkdir -p /etc/x-ui
	sudo chown ${user_name} /etc/x-ui
	sudo chgrp ${user_name} /etc/x-ui
	
	#安装&升级x-ui面板一键脚本：
	bash <(curl -Ls https://raw.githubusercontent.com/vaxilu/x-ui/master/install.sh)
	# bash <(curl -Ls https://raw.githubusercontent.com/FranzKafkaYu/x-ui/master/install.sh)
	# bash <(curl -Ls https://raw.githubusercontent.com/FranzKafkaYu/x-ui/master/install_en.sh)
	install_nginx
	clear
	acme
	rm -rf acme.sh-master
	rm -f master.tar.gz 
	re_ufw

	# echo 
	# echo -n -e ${green}"请输入已解析好的域名: ${plain}" && read realmname
	# echo 
	# acme2
	# #安装acme：
	# curl https://get.acme.sh | sh
	# #添加软链接：
	# ln -s  /root/.acme.sh/acme.sh /usr/local/bin/acme.sh
	# #切换CA机构： 
	# acme.sh --set-default-ca --server letsencrypt
	# #申请证书： 
	# acme.sh  --issue -d ${realmname} -k ec-256 --webroot  /var/www/html
	# #安装证书：
	# acme.sh --install-cert -d ${realmname} --ecc \
	# --key-file       /etc/x-ui/server.key  \
	# --fullchain-file /etc/x-ui/server.crt \
	# --reloadcmd     "systemctl force-reload nginx"
	
	clear
	echo 安装完毕，按任意键可重启系统，若不打算重启系统请直接关闭终端！
	read -n 1
	clear
	echo 即将重启服务器，重启期间耐心等待3分钟左右....
	sleep 2
	reboot
}



#搭建naiveproxy账号
install_naiveproxy() {
	#搭建naiveproxy账号

	[ "$(id -u)" != "0" ] &&  PrintFalseInfo "需要用root的身份运行此程序或者是用sudo来运行此程序" && exit	#检测是否具有root权限

	red='\e[91m' green='\e[92m' yellow='\e[93m' magenta='\e[95m' cyan='\e[96m' none='\e[0m'

	#定义停留警告界面
	Error() { read -sp "$(echo -e "\n${red}$*${none}\n")"; }

	#定义停留通知界面
	Notifi() { read -sp "$(echo -e "\n${green}$*${none}\n")"; }

	#输出执行成功信息
	PrintTrueInfo() { echo -e "\n${yellow}$*${none}\n"; }

	#输出执行错误信息
	PrintFalseInfo() { echo -e "\n${red}$*${none}\n"; }

	#获取当前系统版本
	version="$(grep '^ID=' /etc/os-release | cut -d '=' -f 2 | sed 's/"//g')"

	#获取用户名
	desktop=/home/$(who | awk '{print $1}') 

	#获取系统版本
	Get_System_Version() {
		case "$(uname -m)" in
			i686 | i386) system_version='32' ;;
			x86_64 | amd64) system_version='64' ;;
			*) PrintFalseInfo " 脚本支持 x32和x64架构，不支持其他的架构！" && exit 1;;
		esac
	}

	#伪装网站
	SITES=(
		https://www.linuxmint.com/
		https://mirrors.edge.kernel.org/linuxmint/
		https://muug.ca/mirror/linuxmint/iso/
		https://mirror.csclub.uwaterloo.ca/linuxmint/
		https://mirrors.advancedhosters.com/linuxmint/isos/
		https://mirror.clarkson.edu/linuxmint/iso/images/
		https://mirror.ette.biz/linuxmint/
		https://mirrors.gigenet.com/linuxmint/iso/
		http://mirrors.seas.harvard.edu/linuxmint/
		https://mirror.cs.jmu.edu/pub/linuxmint/images/
		https://mirrors.kernel.org/linuxmint/
		http://linuxfreedom.com/linuxmint/linuxmint.com/
		http://mirror.metrocast.net/linuxmint/
		https://plug-mirror.rcac.purdue.edu/mint-images/
		https://mirrors.sonic.net/mint/isos/
		http://mirror.team-cymru.com/mint/
		https://mirror.pit.teraswitch.com/linuxmint-iso/
		http://mirrors.usinternet.com/mint/images/linuxmint.com/
		https://mirrors.xmission.com/linuxmint/iso/
		https://mirrors.netix.net/LinuxMint/linuxmint-iso/
		https://mirror.telepoint.bg/mint/
		https://mirrors.uni-ruse.bg/linuxmint/iso/
		https://mirrors.nic.cz/linuxmint-cd/
		http://mirror.it4i.cz/mint/isos/
		https://mirror.karneval.cz/pub/linux/linuxmint/iso/
		https://mirror-prg.webglobe.com/linuxmint-cd/linuxmint.com/
		https://mirrors.dotsrc.org/linuxmint-cd/
		http://ftp.klid.dk/ftp/linuxmint/
		https://mirror.crexio.com/linuxmint/isos/
		http://ftp.crifo.org/mint-cd/
		http://linux.darkpenguin.net/distros/mint/
		https://mirror.dogado.de/linuxmint-cd/
		https://mirror.bauhuette.fh-aachen.de/linuxmint-cd/
		https://ftp.fau.de/mint/iso/
		http://mirror.funkfreundelandshut.de/linuxmint/isos/
		https://ftp5.gwdg.de/pub/linux/debian/mint/
		https://ftp-stud.hs-esslingen.de/pub/Mirrors/linuxmint.com/
		https://mirror.as20647.net/linuxmint-iso/
		https://mirror.netcologne.de/linuxmint/iso/
		https://mirror.netzwerge.de/linuxmint/iso/
		https://mirror.pyratelan.org/mint-iso/
		https://ftp.rz.uni-frankfurt.de/pub/mirrors/linux-mint/iso/
		https://mirror.wtnet.de/linuxmint-cd/
		https://repo.greeklug.gr/data/pub/linux/mint/iso/
		http://ftp.otenet.gr/linux/linuxmint/
		http://mirrors.myaegean.gr/linux/linuxmint/
		http://ftp.ntua.gr/pub/linux/linuxmint/
		https://ftp.cc.uoc.gr/mirrors/linux/linuxmint/
		http://mirror.greennet.gl/linuxmint/iso/linuxmint.com/
		https://quantum-mirror.hu/mirrors/linuxmint/iso/
		https://ftp.heanet.ie/pub/linuxmint.com/
		https://mirror.ihost.md/linuxmint/
		https://mirror.koddos.net/linuxmint/packages/
		https://www.debian.org/
		http://ftp.at.debian.org/debian/
		http://debian.anexia.at/debian/
		http://debian.lagis.at/debian/
		http://debian.mur.at/debian/
		http://debian.sil.at/debian/
		http://mirror.alwyzon.net/debian/
		http://ftp.dk.debian.org/debian/
		http://mirror.one.com/debian/
		http://mirrors.dotsrc.org/debian/
		http://ftp2.de.debian.org/debian/
		http://ftp.de.debian.org/debian/
		http://debian.mirror.lrz.de/debian/
		http://debian.netcologne.de/debian/
		http://ftp.gwdg.de/debian/
		http://ftp.halifax.rwth-aachen.de/debian/
		http://ftp.uni-kl.de/debian/
		http://ftp.uni-stuttgart.de/debian/
		http://ftp.is.debian.org/debian/
		http://debian.telecoms.bg/debian/
		http://ftp.uni-sofia.bg/debian/
		http://mirror.telepoint.bg/debian/
		http://ftp.tw.debian.org/debian/
		http://debian.cs.nctu.edu.tw/debian/
		http://opensource.nchc.org.tw/debian/
		http://ftp.hu.debian.org/debian/
		http://ftp.fsn.hu/debian/
		http://ftp.jp.debian.org/debian/
		http://debian-mirror.sakura.ne.jp/debian/
		http://dennou-k.gfd-dennou.org/debian/
		http://dennou-q.gfd-dennou.org/debian/
		http://ftp.jaist.ac.jp/debian/
		http://ftp.nara.wide.ad.jp/debian/
		http://ftp.yz.yamagata-u.ac.jp/debian/
		http://mirrors.xtom.jp/debian/
		http://ftp.pl.debian.org/debian/
		http://ftp.agh.edu.pl/debian/
		http://ftp.task.gda.pl/debian/
		http://debian.gnu.gen.tr/debian/
		http://ftp.agh.edu.pl/debian/
		http://ftp.task.gda.pl/debian/
		http://ftp.fr.debian.org/debian/
		http://debian.proxad.net/debian/
		http://debian.univ-tlse2.fr/debian/
		http://deb-mir1.naitways.net/debian/
		http://mirror.johnnybegood.fr/debian/
		http://ftp.it.debian.org/debian/
		http://ftp.linux.it/debian/
		http://mirror.coganng.com/debian/
		http://mirror.soonkeat.sg/debian/
		http://giano.com.dist.unige.it/debian/
		http://ftp.cz.debian.org/debian/
		http://ftp.debian.cz/debian/
		http://debian.mirror.web4u.cz/
		http://mirror.dkm.cz/debian/
		http://ftp.be.debian.org/debian/
		http://mirror.as35701.net/debian/
		http://ftp.ee.debian.org/debian/
		http://ftp.eenet.ee/debian/
		http://ftp.sk.debian.org/debian/
		http://ftp.debian.sk/debian/
		http://ftp.si.debian.org/debian/
		http://ftp.md.debian.org/debian/
		http://mirror.as43289.net/debian/
		http://ftp.nz.debian.org/debian/
		http://linux.purple-cat.net/debian/
		http://mirror.fsmg.org.nz/debian/
		http://debian.koyanet.lv/debian/
		http://ftp.us.debian.org/debian/
		http://debian-archive.trafficmanager.net/debian/
		http://debian.gtisc.gatech.edu/debian/
		http://debian.osuosl.org/debian/
		http://debian.uchicago.edu/debian/
		http://mirrors.edge.kernel.org/debian/
		http://mirrors.vcea.wsu.edu/debian/
		http://mirrors.wikimedia.org/debian/
		http://mirror.us.oneandone.net/debian/
		http://mirror.flokinet.net/debian/
		http://mirrors.nxthost.com/debian/
		http://mirror1.infomaniak.com/debian/
		http://mirror2.infomaniak.com/debian/
		http://mirror.init7.net/debian/
		http://mirror.iway.ch/debian/
		http://mirror.sinavps.ch/debian/
		http://pkg.adfinis-sygroup.ch/debian/
		http://debian.mirror.root.lu/debian/
		http://ftp.au.debian.org/debian/
		http://debian.mirror.digitalpacific.com.au/debian/
		http://mirror.linux.org.au/debian/
		http://ftp.es.debian.org/debian/
		http://ftp.cica.es/debian/
		http://softlibre.unizar.es/debian/
		http://ulises.hostalia.com/debian/
		http://ftp.uk.debian.org/debian/
		http://debian.mirrors.uk2.net/debian/
		http://free.hands.com/debian/
		http://mirror.lchost.net/debian/
		http://mirror.positive-internet.com/debian/
		http://mirrors.coreix.net/debian/
		http://ftp.nl.debian.org/debian/
		http://debian.snt.utwente.nl/debian/
		http://mirror.i3d.net/debian/
		http://mirror.nl.datapacket.com/debian/
		http://ftp.pt.debian.org/debian/
		http://debian.uevora.pt/debian/
		http://mirrors.up.pt/debian/
		https://ubuntu.com/
		https://www.opensuse.org/
		https://getfedora.org/
		https://www.centos.org/
		https://archlinux.org/
		https://puppylinux.com/
		https://www.freebsd.org/
		https://www.gentoo.org/
		https://www.oracle.com/linux/
		https://www.redhat.com/en/technologies/cloud-computing/openshift/
		https://www.redhat.com/
		https://www.openbsd.org/
		https://www.linuxliteos.com/
		https://www.clearos.com/
		https://www.virtualbox.org/
		https://ftp.nluug.nl/os/Linux/distr/linuxmint/packages/
		https://ftp.icm.edu.pl/pub/Linux/dist/linuxmint/packages/
		https://mirror.fccn.pt/repos/pub/linuxmint_packages/
		https://mirrors.ptisp.pt/linuxmint/
		https://ftp.rnl.tecnico.ulisboa.pt/pub/linuxmint-packages/
		https://mirrors.up.pt/linuxmint-packages/
		http://mint.mirrors.telekom.ro/repos/
		http://mirrors.powernet.com.ru/mint/packages/
		https://mirror.truenetwork.ru/linuxmint-packages/
		http://mirror.pmf.kg.ac.rs/mint/packages.linuxmint.com/
		http://ftp.energotel.sk/pub/linux/linuxmint-packages/
		https://tux.rainside.sk/mint/packages/
		https://mirror.airenetworks.es/linuxmint/packages/
		https://ftp.cixug.es/mint/packages/
		https://ftp.acc.umu.se/mirror/linuxmint.com/packages/
		https://mirrors.c0urier.net/linux/linuxmint/packages/
		https://mirror.linux.pizza/linuxmint/
		https://mirror.zetup.net/linuxmint/packages/
		https://mirror.init7.net/linuxmint/
		https://mirror.turhost.com/linuxmint/repo/
		https://mirror.verinomi.com/linuxmint/packages/
		https://mirrors.ukfast.co.uk/sites/linuxmint.com/packages/
		https://www.mirrorservice.org/sites/packages.linuxmint.com/packages/
		http://ftp.jaist.ac.jp/pub/Linux/linuxmint/packages/
		http://mirror.rise.ph/linuxmint/
		https://mirror.0x.sg/linuxmint/
		https://download.nus.edu.sg/mirror/linuxmint/
		https://ftp.harukasan.org/linuxmint/
		https://ftp.kaist.ac.kr/linuxmint/
		http://free.nchc.org.tw/linuxmint/packages/
		http://ftp.tku.edu.tw/Linux/LinuxMint/linuxmint/
		http://mirror1.ku.ac.th/linuxmint-packages/
		https://mirror.kku.ac.th/linuxmint-packages/
		http://mirror.dc.uz/linuxmint/
		https://mirror.aarnet.edu.au/pub/linuxmint-packages/
		http://mirror.internode.on.net/pub/linuxmint-packages/
		http://ucmirror.canterbury.ac.nz/linux/mint/packages/
		http://mirror.xnet.co.nz/pub/linuxmint/packages/
		https://mint.zero.com.ar/mintpackages/
		http://mint-packages.c3sl.ufpr.br/
		http://mirror.ufscar.br/mint-archive/
		https://mint.itsbrasil.net/packages/
		https://www.azmovies.net
		https://www.greenmangaming.com
		https://moviemora.com
		https://beauty-upgrade.tw
		https://clipchamp.com
		https://www.vecteezy.com
		https://www.freemusicarchive.org
		https://www.crazygames.com
		https://musopen.org 
		https://animeflick.net
		https://www.accuradio.com
		https://okmusi.com
		https://filmypunjab.com
		https://onlinemovieshindi.com
		https://www.lenskart.com
		https://www.moviecrumbs.net
		https://www.plex.tv
		https://free.nchc.org.tw
		https://www.anime-planet.com
		https://www.flexclip.com
		https://www.videvo.net
		https://ftp.task.gda.pl
		https://mirrors.edge.kernel.org
		https://debian.koyanet.lv
		https://ftp.kaist.ac.kr
		https://mirror.ufscar.br
		https://ftp-stud.hs-esslingen.de
		https://mint.zero.com.ar
		https://mirror.fccn.pt
		https://mirrors.ukfast.co.uk
		https://mirror.netzwerge.de
		https://mirrors.netix.net
		https://linux.purple-cat.net
		https://free.hands.com
		https://ftp.halifax.rwth-aachen.de
		https://mirrors.vcea.wsu.edu
		https://www.freebsd.org
		https://mirror.sinavps.ch
		https://ftp.uni-sofia.bg
		https://mirror.koddos.net
		https://pkg.adfinis-sygroup.ch
		https://mirror.pyratelan.org
		https://mint-packages.c3sl.ufpr.br
		https://dennou-q.gfd-dennou.org
		https://mirror.kku.ac.th
		https://mirror.dogado.de
		https://opensource.nchc.org.tw
		https://mirror.linux.org.au
		https://mirror.zetup.net
		https://mirror.cs.jmu.edu
		https://mirror.karneval.cz
		https://debian.anexia.at
		https://ftp.eenet.ee
		https://ftp.rnl.tecnico.ulisboa.pt
		https://mirrors.usinternet.com
		https://www.gentoo.org
		https://www.mirrorservice.org
		https://mirror.it4i.cz
		https://ftp.acc.umu.se
		https://mirror.one.com
		https://mirrors.xmission.com
		https://www.openbsd.org
		https://www.linuxmint.com
		https://www.redhat.com
		https://mirrors.gigenet.com
		https://www.clearos.com
		https://debian.osuosl.org
		https://quantum-mirror.hu
		https://ftp.es.debian.org
		https://debian.snt.utwente.nl
		https://ftp5.gwdg.de
		https://softlibre.unizar.es
		https://mirrors.up.pt
		https://mirrors.kernel.org
		https://mirror.us.oneandone.net
		https://debian.netcologne.de
		https://mirrors.ptisp.pt
		https://www.opensuse.org
		https://mirror.telepoint.bg
		https://www.virtualbox.org
		https://mirrors.c0urier.net
		https://mirror.ette.biz
		https://mirrors.advancedhosters.com
		https://mirror.alwyzon.net
		https://debian.gnu.gen.tr
		https://mirror.wtnet.de
		https://debian.cs.nctu.edu.tw
	)

	#随机选择一个useragent
	RandomUserAgent() {
		while :;do
			UA=`echo "\
			Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/92.0.4515.131 Safari/537.36
			Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/92.0.4515.107 Safari/537.36
			Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:90.0) Gecko/20100101 Firefox/90.0
			Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36
			Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.164 Safari/537.36
			Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/92.0.4515.107 Safari/537.36
			Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/92.0.4515.131 Safari/537.36
			Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.1.1 Safari/605.1.15
			Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.114 Safari/537.36
			Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.1.2 Safari/605.1.15"`
			UserAgent=`echo "$UA"|sed -n ''$(($RANDOM%$(echo "$UA"|wc -l)+1))'p'`
			[ ! -z $"{UserAgent}" ] && break
		done
	}

	#下载伪装网站
	SetUrl() {
		test ! -e /www && mkdir -p /www && chmod 755 /www
		len=${#SITES[@]}
		((len--))
		echo -e "\n$yellow 正在下载伪装网页...$none\n"
		while true; do
			RandomUserAgent	#获取伪装浏览器指纹信息
			index=$(shuf -i0-${len} -n1)
			URL=${SITES[$index]}
			URLPath=$(echo ${URL} | cut -d/ -f3-)
			if [[ ! -f  "/www/${URLPath}/index.html" ]]; then
				timeout -k 10s 1m wget --user-agent="${UserAgent}" -p  --convert-links --no-check-certificate -P/www ${URL} &>/dev/null
				[ $? != 0 ] && PrintFalseInfo "下载伪装网页失败，等待1秒重新下载" && sleep 1 && continue
			fi
			[[ -f  "/www/${URLPath}/index.html" ]] && { URLPath="/www/${URLPath}";break; }
		done
		echo -e "\n$yellow  伪装网站：${URL}$none\n"
	}

	#得到VPS的ip地址
	Get_Ip() {
		PrintTrueInfo "正在解析域名绑定的IP地址..."
		V6_PROXY=""
		IP=$(curl -s4m8 https://ip.gs)
		[[ "$?" != "0" ]] && IP=$(curl -s6m8 https://ip.gs) && V6_PROXY="true"
		[[ $V6_PROXY != "" ]] && echo -e nameserver 2a01:4f8:c2c:123f::1 > /etc/resolv.conf
		resolve=$(curl -sm8 ipget.net/?ip=${domain});PrintTrueInfo "解析 ${domain} 域名绑定IP地址结果：${resolve}"
		[ $resolve != $IP ] && PrintFalseInfo " 域名未解析到当前服务器IP(${IP})！，请把cloudflare账户中域名DNS中的小云朵调成灰的" && exit 1
		PrintTrueInfo "域名解析到当前服务器IP(${IP})"
	}

	#获得并安装编译好的caddy2程序
	Install_Caddy() {
		[[ $(uname -m 2> /dev/null) != x86_64 ]] &&  { PrintFalseInfo "此脚本请运行在x86_64的系统上"; exit 1; }
		count=1 #统计循环次数
		while :;do
			[ ${count} == 10 ] && PrintFalseInfo "没有成功下载并配置上caddy2程序，正在退出脚本" && exit
			PrintTrueInfo "正在安装编译好naiveproxy插件的caddy2程序......"
			local caddy_link="https://raw.githubusercontent.com/proxysu/Resources/master/Caddy2/caddy2.zip"
			$(which mkdir) -p "/etc/caddy"  #创建caddy的配置文件目录  
			echo "OK" > /etc/caddy/naive
			wget "${caddy_link}" -O /tmp/caddy.zip && unzip /tmp/caddy.zip -d /usr/local/bin/ && $(which chmod) +x /usr/local/bin/caddy
			[ $? != 0 ] && { PrintFalseInfo "下载并安装caddy2没有成功，等待两秒钟重试";sleep 2;let count+=1; continue; }
			Set_Caddy2_Systemd; systemctl daemon-reload; break  #设置caddy的服务配置文件+重新加载服务+跳出循环
		done
	}

	#卸载安装的caddy2程序
	Uninstall_Caddy(){
		if [ -f "/usr/local/bin/caddy" ]; then
			PrintTrueInfo "正在卸载caddy程序......"
			systemctl stop caddy; systemctl disable caddy   #停止caddy服务，并禁用caddy开机启动
			rm -rf /etc/systemd/system/caddy.service	 #删除caddy服务
			rm -rf /usr/bin/caddy; rm -rf /etc/caddy	#删除caddy程序与配置目录
			if [ ! -f /usr/bin/caddy && ! -e /etc/caddy && ! -f /etc/systemd/system/caddy.service ];then
				PrintTrueInfo  "Caddy2卸载完成"
			else
				PrintFalseInfo "Caddy2没有卸载完成，请稍后重试"; exit
			fi
		fi
	}

	#检查端口是否被占用
	Check_Port_Status() {
		#if [[ -n "$(lsof -nP -iTCP:$* -sTCP:LISTEN | egrep -v '\<caddy\>|\<COMMAND\>')" || -f /etc/caddy/sites/naive-${mport}-${domain}.cfg ]];then
		if [[ -n "$(lsof -nP -iTCP:$* -sTCP:LISTEN | egrep -v '\<COMMAND\>')" ]];then
			return 1
		else	
			return 0
		fi
	}

	#检查是被nginx占用的端口
	Check_Nginx_Port() {
		nginx_port=		#定义一个nginx的端口变量
		if Command_Exsit nginx &>/dev/null;then
			nginx_port="$(lsof -nP -iTCP -sTCP:LISTEN | awk -F"[:(]" '/nginx/{a[$2]++;} END{for(i in a)print int(i)}')"
		fi
		[ -n "${nginx_port}" ] && PrintTrueInfo "以下是nginx程序占用的端口，请不要使用这些端口避免发生端口冲突：\n${nginx_port}"
	}

#iptables防火墙放行
Set_Iptables() {
	if [[ -n ${iptables_path} ]];then
		#检测v2ray或者xray的端口是否是已经放行，如果是的话就不用再放行了。
		if [[ ! -z ${mport} && -z "$(egrep "\<${mport}\>" ${iptables_path})" ]];then
			rules_num="$(iptables -nL --line-number | awk '/\<DROP       all\>/ {print int($1)}'| sed -n 1p)"
			[ -n "${rules_num}" ] && iptables -D INPUT ${rules_num} || { PrintFalseInfo "没有获取到禁用入站的规则，请稍后再尝试";exit; }
			iptables -A INPUT -p tcp --dport ${mport} -j ACCEPT;iptables -A INPUT -j DROP
			if [ "${version}" == "centos" ];then
				#保存iptables添加的规则
				iptables-save >/etc/sysconfig/iptables; ip6tables-save >/etc/sysconfig/ip6tables
				RestartServer iptables; [ $? != 0 ] && Error "iptables防火墙服务没有启动成功，请稍后重新尝试" && exit
			else
				#保存iptables添加的规则
				iptables-save >${iptables_path}; ip6tables-save >${iptables_path%.*}.v6
				#检查iptables规则是否保存上了
				if [[ -f ${iptables_path} && -f ${iptables_path%.*}.v6  ]];then
					PrintTrueInfo "设置iptables防火墙规则成功"
				else
					Error "设置iptables防火墙规则失败，请重新尝试"; exit       
				fi
			fi
			if [[ -f ${iptables_path} && -n "$(egrep "\<${mport}\>" ${iptables_path})" ]];then
				PrintTrueInfo "caddy端口 ${mport} 放行成功"
			else
				PrintFalseInfo "caddy端口 ${mport} 没有放行成功，请稍后再尝试 ";exit
			fi
		fi
	fi
}

	#检测当前VPS端口
	Check_Sys_Port() {
		check_port=$(awk '/^Port/{print $2}' /etc/ssh/sshd_config)
		if [[ -n ${check_port}  && ${check_port} =~ ^[0-9]+$ ]];then
			print_info=",检测当前VPS端口为${green} "${check_port}" ${yellow}，直接回车使用检测的端口${none}"
		else
			print_info=""
		fi
	}

	#设置登录端口
	Set_Login_Port() {
		Check_Sys_Port	#获取当前VPS的端口
		while :;do
			clear
			echo -en "\n${yellow}请输入SSH登录端口"${print_info}"[按q退出脚本]: ${none}"; read login_port
			[ -z "${login_port}" ] && login_port="${check_port}"
			[ "${login_port}" == q ] && exit
			if [[ -n ${login_port} && ${login_port} =~ ^[0-9]+$ ]];then		# 检查是否纯数字
				if [ -z "$(awk '/Port '${login_port}'/{print $2}' /etc/ssh/sshd_config)" ];then
					Error "输入的端口没有找到，请重新输入一下，可以看一下登录VPS的软件那里填写端口"
				else
					break
				fi
			else
				Error "端口输入的不正确，请重新输入！"
			fi
		done
	}

	#ufw防火墙禁用ping入
	Input_Ping_Off() {
		sed -i "s/-A ufw-before-input -p icmp --icmp-type destination-unreachable -j ACCEPT/-A ufw-before-input -p icmp --icmp-type destination-unreachable -j DROP/" /etc/ufw/before.rules 2>&1
		sed -i "s/-A ufw-before-input -p icmp --icmp-type source-quench -j ACCEPT/-A ufw-before-input -p icmp --icmp-type source-quench -j DROP/" /etc/ufw/before.rules 2>&1
		sed -i "s/-A ufw-before-input -p icmp --icmp-type time-exceeded -j ACCEPT/-A ufw-before-input -p icmp --icmp-type time-exceeded -j DROP/" /etc/ufw/before.rules 2>&1
		sed -i "s/-A ufw-before-input -p icmp --icmp-type parameter-problem -j ACCEPT/-A ufw-before-input -p icmp --icmp-type parameter-problem -j DROP/" /etc/ufw/before.rules 2>&1
		sed -i "s/-A ufw-before-input -p icmp --icmp-type echo-request -j ACCEPT/-A ufw-before-input -p icmp --icmp-type echo-request -j DROP/" /etc/ufw/before.rules 2>&1

		sed -i "s/-A ufw6-before-input -p icmpv6 --icmpv6-type destination-unreachable -j ACCEPT/-A ufw6-before-input -p icmpv6 --icmpv6-type destination-unreachable -j DROP/" /etc/ufw/before6.rules 2>&1
		sed -i "s/-A ufw6-before-input -p icmpv6 --icmpv6-type packet-too-big -j ACCEPT/-A ufw6-before-input -p icmpv6 --icmpv6-type packet-too-big -j DROP/" /etc/ufw/before6.rules 2>&1
		sed -i "s/-A ufw6-before-input -p icmpv6 --icmpv6-type time-exceeded -j ACCEPT/-A ufw6-before-input -p icmpv6 --icmpv6-type time-exceeded -j DROP/" /etc/ufw/before6.rules 2>&1
		sed -i "s/-A ufw6-before-input -p icmpv6 --icmpv6-type parameter-problem -j ACCEPT/-A ufw6-before-input -p icmpv6 --icmpv6-type parameter-problem -j DROP/" /etc/ufw/before6.rules 2>&1
		sed -i "s/-A ufw6-before-input -p icmpv6 --icmpv6-type echo-request -j ACCEPT/-A ufw6-before-input -p icmpv6 --icmpv6-type echo-request -j DROP/" /etc/ufw/before6.rules 2>&1
		sed -i "s/-A ufw6-before-input -p icmpv6 --icmpv6-type echo-reply -j ACCEPT/-A ufw6-before-input -p icmpv6 --icmpv6-type echo-reply -j DROP/" /etc/ufw/before6.rules 2>&1
		sed -i "s/-A ufw6-before-input -p icmpv6 --icmpv6-type router-solicitation -m hl --hl-eq 255 -j ACCEPT/-A ufw6-before-input -p icmpv6 --icmpv6-type router-solicitation -m hl --hl-eq 255 -j DROP/" /etc/ufw/before6.rules 2>&1
		sed -i "s/-A ufw6-before-input -p icmpv6 --icmpv6-type router-advertisement -m hl --hl-eq 255 -j ACCEPT/-A ufw6-before-input -p icmpv6 --icmpv6-type router-advertisement -m hl --hl-eq 255 -j DROP/" /etc/ufw/before6.rules 2>&1
		sed -i "s/-A ufw6-before-input -p icmpv6 --icmpv6-type neighbor-solicitation -m hl --hl-eq 255 -j ACCEPT/-A ufw6-before-input -p icmpv6 --icmpv6-type neighbor-solicitation -m hl --hl-eq 255 -j DROP/" /etc/ufw/before6.rules 2>&1
		sed -i "s/-A ufw6-before-input -p icmpv6 --icmpv6-type neighbor-advertisement -m hl --hl-eq 255 -j ACCEPT/-A ufw6-before-input -p icmpv6 --icmpv6-type neighbor-advertisement -m hl --hl-eq 255 -j DROP/" /etc/ufw/before6.rules 2>&1
	}

	# 设置ufw防火墙
	Ufw_Firewall() {
		if ! Command_Exsit ufw &>/dev/null;then	# 检查ufw防火墙软件是否安装，没有安装则进行安装
			${manage} install ufw -y; sleep 1	# 安装ufw防火墙并停顿一秒
			if ! Command_Exsit ufw &>/dev/null;then
				Error "安装ufw防火墙软件失败，稍后重新尝试一下，或者安装ufw试试" ; return 1 
			fi
		fi

		# 允许访问22端口，以下几条相同，分别是22,80,443,3389,8443端口的访问
		for i in {22,3389,8443,443,80};do ufw allow in $i/tcp; done
		[[ ! ${mport} =~ 22|3389|8443|443|80 ]] && ufw allow in ${mport}/tcp    # 判断是否是已经放行的端口，没有放行则进行放行
		#检测端口是否为22，22端口已经放行就不需要再次放行
		[ "${login_port}" != "22" ] && ufw allow in ${login_port}/tcp
		Input_Ping_Off		# 禁用ping入
		ufw default deny incoming	# 默认禁用所有的入站
		echo y | ufw enable		# 启动ufw防火墙
		systemctl restart ufw; systemctl enable ufw; ufw reload  	# 重新加载并重新启动ufw防火墙
		if [ -n "$(ufw status | egrep '\<active\>')" ];then
			PrintTrueInfo "ufw 防火墙启动成功"
		else
			Error "ufw 防火墙启动失败，请重新尝试"; return 1
		fi
	}

	# 设置iptables防火墙
	Iptables_Firewall() {
		if ! Command_Exsit iptables &>/dev/null;then	# 检查iptables防火墙软件是否安装，没有安装则进行安装
			${manage} install iptables -y; sleep 1	# 安装iptables防火墙并停顿一秒
			if ! Command_Exsit iptables &>/dev/null;then
				Error "安装iptables防火墙软件失败，稍后重新尝试一下，或者安装ufw试试" ; return 1 
			fi
		fi
		# 清除已有iptables规则
		iptables -F;iptables -X
		
		# 允许本地回环接口(即运行本机访问本机)
		iptables -A INPUT -i lo -j ACCEPT

		# 允许已建立的或相关连的通行
		iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

		#允许所有本机向外的访问
		iptables -A OUTPUT -j ACCEPT

		# 允许访问22端口，以下几条相同，分别是22,80,443,3389,8443端口的访问
		for i in {22,3389,8443,443,80};do iptables -A INPUT -p tcp --dport $i -j ACCEPT; done

		#检测端口是否为22，22端口已经放行就不需要再次放行
		[ "${login_port}" != "22" ] && iptables -A INPUT -p tcp --dport ${login_port} -j ACCEPT
		[[ ! ${mport} =~ 22|3389|8443|443|80 ]] &&  iptables -A INPUT -p tcp --dport ${mport} -j ACCEPT    # 判断是否是已经放行的端口，没有放行则进行放行
		#禁用ping
		iptables -A INPUT -p icmp -m icmp --icmp-type 8 -j DROP

		#防止DoS攻击。允许最多每分钟25个连接，当达到100个连接后，才启用上述25/minute限制。
		iptables -A INPUT -p tcp --dport 80 -m limit --limit 25/minute --limit-burst 100 -j ACCEPT

		#禁止其他未允许的规则访问（注意：如果22端口未加入允许规则，SSH链接会直接断开。）
		iptables -A INPUT -j DROP 
		iptables -A FORWARD -j DROP

		if [[ "${version}" == "centos" ]];then
			#保存iptables添加的规则
			iptables-save >/etc/sysconfig/iptables 
			ip6tables-save >/etc/sysconfig/ip6tables
			systemctl enable iptables
			systemctl restart iptables
			if [ "$?" != "0" ];then
				read -sp "$(echo -e "\n${red}设置iptables防火墙规则失败，请重新尝试${none}\n")";exit
			else
				echo -e "\n${yellow}设置iptables开机启动成功${none}\n"
			fi
		else
			#保存iptables添加的规则
			test ! -e /etc/iptables && mkdir -p /etc/iptables
			iptables-save >/etc/iptables/rules.v4; ip6tables-save >/etc/iptables/rules.v6

			#检查iptables规则是否保存上了
			if [[ -f /etc/iptables/rules.v4 && -f /etc/iptables/rules.v6 ]];then
				echo -e "\n${yellow}设置iptables防火墙规则成功${none}\n"
			else
				read -sp "$(echo -e "\n${red}设置iptables防火墙规则失败，请重新尝试${none}\n")"; exit       
			fi
			systemctl start iptables &>/dev/null
			if [ "$?" == "0" ];then
				systemctl enable iptables; systemctl restart iptables
			else
				cat >/etc/init.d/iptables <<-EOF
				#!/bin/sh -e
				### BEGIN INIT INFO
				# Provides:             iptables
				# Default-Start:        2 3 4 5
				# Default-Stop:         
				### END INIT INFO
				/sbin/iptables-restore < /etc/iptables/rules.v4
				/sbin/ip6tables-restore < /etc/iptables/rules.v6
				EOF
				chmod +x /etc/init.d/iptables
				ln -s /etc/init.d/iptables /etc/rc2.d/S01iptables &>/dev/null
				/etc/init.d/iptables enable
				/etc/init.d/iptables reload

				#检测开机启动配置文件是否添加成功
				if [[ ! -f /etc/init.d/iptables && ! -f /etc/rc2.d/S01iptables ]];then
					PrintFalseInfo "设置iptables开机启动失败，请重新尝试"; exit
				else
					PrintTrueInfo "设置iptables开机启动成功"; return 0
				fi
			fi
		fi
	}

	#询问使用哪款防火墙软件
	Select_Firewall() {
		while :;do
			clear
			PrintTrueInfo "1、ufw防火墙"
			PrintTrueInfo "2、iptables防火墙"
			read -p " 请选择一款防火墙软件来防护VPS，输入序号就可以：" select
			case ${select} in
				1) Set_Login_Port; Ufw_Firewall ;[ $? == 0 ] && break ;;
				2) Set_Login_Port; Iptables_Firewall ;[ $? == 0 ] && break ;;
				*) Error "请按照提示输入"
			esac
		done
	}

	# ufw防火墙放行
	Set_Ufw() {
		[ -n "$(ufw status | egrep "\<${mport}/tcp\>")" ] && { PrintTrueInfo "caddy端口 ${mport} 已经放行";sleep 1;return 0; }
		ufw allow in ${mport}/tcp &>/dev/null;ufw reload &>/dev/null
		if [ -n "$(ufw status | egrep "\<${mport}/tcp\>")" ];then
			PrintTrueInfo "caddy端口 ${mport} 放行成功";
		else
			PrintFalseInfo "caddy端口 ${mport} 没有放行成功，请稍后再尝试 ";exit
		fi
	}

	#检测iptables防火墙路径
	Check_Iptable_Path() {
		iptables_path=  # 定义一个iptables配置文件路径变量
		if [[ "${version}" == "centos" ]];then
			#保存iptables添加的规则
			iptables_path="etc/sysconfig/iptables"
		else
			if [ -f /etc/init.d/iptables ];then
				iptables_path="$(awk '/rules.v4/{print $3}' /etc/init.d/iptables)"
				[ -z ${iptables_path} ] && PrintFalseInfo "获取iptables配置文件路径失败，请重新执行脚本试试看" && exit 1
			fi
		fi
	}

	#防火墙放行端口
	Allow_Port() {
		Check_Iptable_Path
		if [[ -n "$(command -v ufw)" && -n "$(ufw status | egrep '\<active\>')" ]];then
			Set_Ufw		# ufw防火墙放行
		elif [[ -n ${iptables_path} ]];then
			Set_Iptables	# iptables防火墙放行
		else
			Select_Firewall		#选择防火墙
		fi
	}

	#修改nginx默认的http端口
	Change_http() {
		if Command_Exsit nginx &>/dev/null;then
			nginx_path="/etc/nginx/conf.d/"
			domain_config="$(ls ${nginx_path})"
			for i in ${domain_config};do
				[ -z "$(grep 'listen 880;' ${nginx_path}/$i 2>/dev/null)" ] && sed -i "/listen/s/80;/880;/" ${nginx_path}/$i
				[ -n "$(grep 'listen 880;' ${nginx_path}/$i 2>/dev/null)" ] && PrintTrueInfo "$i http端口修改为880成功。" || PrintFalseInfo "$i http端口修改为880失败，稍后重新尝试。"
			done
			RestartServer "nginx"
		fi
	}

	#显示并记录账号
	Print_Account() {
		[ ! -f ./naive_account.txt ] && touch ./naive_account.txt
		if [[ ${answer} == 1 ]];then
			clear
			PrintTrueInfo "域名：${domain}\n端口：${mport}\n用户名：${naive_user}\n密码：${naive_passwd}"
			PrintTrueInfo "Qv2ray导入链接：\nnaive+https://${naive_user}:${naive_passwd}@${domain}:${mport}?padding=true#naive@${domain}:${mport}"
		else
			PrintTrueInfo "域名：${domain}\n端口：${mport}\n用户名：${naive_user}\n密码：${naive_passwd}" >> /tmp/tmp_navie_info.log
			PrintTrueInfo "Qv2ray导入链接：\nnaive+https://${naive_user}:${naive_passwd}@${domain}:${mport}?padding=true#naive@${domain}:${mport}" >> /tmp/tmp_navie_info.log
		fi
		[[ -n "$(egrep "\<${domain}:${mport}\>" ./naive_account.txt)" ]] && sed -in "/\<${domain}\>/d" ./naive_account.txt
		[ -f ./naive_account.txtn ] && rm ./naive_account.txtn
		echo -e "域名：${domain} 端口：${mport} 用户名：${naive_user} 密码：${naive_passwd} Qv2ray导入链接：naive+https://${naive_user}:${naive_passwd}@${domain}:${mport}?padding=true#naive@${domain}:${mport}\n" >> ./naive_account.txt
		[[ ${answer} == 1 ]] && PrintTrueInfo "以上是搭建naive账号信息，请记录好，\n此账号会保存到当前目录的naive_account.txt文档中" && Notifi "以上信息保存好后请按照回车返回主菜单"
	}

	# 重新生成账号信息
	Create_Naive_Account() {
		caddy_path="/etc/caddy/sites/";error_info=		# 定义一个存放caddy路径的变量+定义一个存放错误信息的空变量
		[ -f ./naive_account.txt ] && rm ./naive_account.txt
		config_path="$(ls ${caddy_path} | egrep '^naive')"		# 定义一个存放配置文件的变量
		[ -z "${config_path}" ] && { Error "没有搭建naive账号无法生成，回车后返回"; return; }
		for i in ${config_path};do
			[ ! -f ${caddy_path}${i} ] && error_info="${error_info}\n$i" && continue
			domain="$(awk -F: '{if(NR==1) print $1}' ${caddy_path}${i})"
			mport="$(awk -F: '{if(NR==1) print int($2)}' ${caddy_path}${i})"
			naive_user="$(awk '/basicauth/{print $2}' ${caddy_path}${i})"
			naive_passwd="$(awk '/basicauth/{print $3}' ${caddy_path}${i})"
			if [[ -n "${domain}" && -n "${mport}" && -n "${naive_user}" && -n "${naive_passwd}" ]];then
				PrintTrueInfo "正在处理 ${domain} ..."; Print_Account
			else
				error_info="${error_info}\n$i"
			fi
		done
		if [ -n "${error_info}" ];then
			PrintFalseInfo "以下是没有生成naive账号链接的，其它naive账号生成的链接存放在naive_account.txt文档中：\n${error_info}"
		else
			PrintTrueInfo "搭建的naive链接全部生成完，存储在naive_account.txt文档中."
		fi
		Notifi "回车后返回菜单"
	}

	#输入caddy端口的交互界面
	Caddy_Menu() {
		# caddy端口
		while :;do
			TmpPost=$(shuf -i1024-65000 -n1)	# 清理屏幕+生成一个随机端口
			echo -e "\n* * * * * * * * * * * * * * * * * * * * * * * * *"
			echo "* 输入伪装加密端口，如:443(加密网页端口)、            *"
			echo "* 8443(自定义的加密网页端口)、3389(远程桌面端口)....  *"
			echo "* * * * * * * * * * * * * * * * * * * * * * * * *"
			Check_Nginx_Port #检查nginx端口
			echo ;echo -en "${yellow}请输入一个 伪装加密端口（随机端口：${TmpPost}，输入为空则使用随机端口）：$none"; read mport; mport=${mport:-$TmpPost}
			if [[ "${mport}" =~ ^[1-9]$|^[1-9][0-9]{1,5}$ && "${mport}" -le 65535 ]];then
				Check_Port_Status "${mport}"; [ $? != 0 ] && { Error "输入的 ${mport} 端口被占用了，请重新输入端口";continue; }
			else
				Error "输入的端口的有问题，请重新输入"; continue
			fi
			PrintTrueInfo "输入的caddy端口是： ${mport}" ;break
		done

		# naive用户名和密码
		echo 
		echo "* * * * * * * * * * * * * * * * * * * * * * * * *"
		echo "* 输入naive用户名称和用户密码，                     *"
		echo "* 用户名和密码不建议使用 #、@、:等符号               *"
		echo "* 用户名建议4位往上，密码建议8位往上                 *"
		echo "* * * * * * * * * * * * * * * * * * * * * * * * *"
		naive_user_rand="$(head /dev/urandom | tr -dc a-z0-9 | head -c 8)"
		naive_passwd_rand="$(head /dev/urandom | tr -dc a-z0-9 | head -c 16)"
		for ((i=1;i<5;i++));do
			echo ;echo -en "${yellow}请输入一个naive用户名，默认是：${naive_user_rand} 输入为空则使用随机生成的用户名）：$none"; read naive_user; naive_user=${naive_user:-$naive_user_rand}
			[[ ${naive_user} =~ ^[0-9a-zA-Z]+$ && "$(echo ${naive_user} | wc -c)" -ge 4 ]] && { PrintTrueInfo "输入的用户名是：${naive_user}";break; } || \
			{ Error "输入的用户名位数低或者包含符号，请重新输入";naive_user=;continue; }
		done
		for ((i=1;i<5;i++));do
			echo ;echo -en "${yellow}请输入一个naive用户密码，默认是：${naive_passwd_rand} 输入为空则使用随机生成的用户名）：$none"; read naive_passwd; naive_passwd=${naive_passwd:-$naive_passwd_rand}
			[[ ${naive_passwd} =~ ^[0-9a-zA-Z]+$ && "$(echo ${naive_passwd} | wc -c)" -ge 8 ]] && { PrintTrueInfo "输入的用户名密码是：${naive_passwd}";break; } || \
			{ Error "输入的用户密码位数低或者包含符号，请重新输入";naive_passwd=;continue; }
		done
		[[ -z "${naive_passwd}" || -z "${naive_user}" ]] && Error "输入的用户名和密码不正确，回车后退出脚本，请稍后再尝试。" && exit
	}

	#配置caddy1域名
	ConfigCaddy1() {
		[[ ! -f /etc/caddy/Caddyfile || -z "$(grep 'import sites' /etc/caddy/Caddyfile 2>/dev/null)" ]] && echo 'import sites/*.cfg' > /etc/caddy/Caddyfile
		email="$(((RANDOM << 22)))"	#生成随机邮箱名
		[ ! -e /etc/caddy/sites ] && mkdir -p /etc/caddy/sites
		Allow_Port #放行端口
		SetUrl	#获取伪装网页
		cat > /etc/caddy/sites/naive-${mport}-${domain}.cfg <<-EOF
		$domain:${mport}  {
			root ${URLPath}
			tls ${email}@gmail.com
			forwardproxy {
				basicauth ${naive_user} ${naive_passwd}
				hide_ip
				hide_via
				probe_resistance
				upstream http://127.0.0.1:${naive_port}
			}
		}
		EOF
		if [[ ${answer} == 1 ]];then		# 当选择单个搭建naive账号的时候去修改nginx端口冲突和重启caddy服务，防止批量搭建的时候反复去执行
			Change_http	#修改nginx端口
			sleep 3;RestartServer "caddy"
		fi
		
		Print_Account	#显示账号
	}

	# 获取用户名、端口、用户密码
	Get_Port_Name_Passwd() {
		while :;do
			mport=$(shuf -i10300-65000 -n1)	# 清理屏幕+生成一个随机端口
			if [[ -n "${mport}" && "${mport}" =~ ^[1-9]$|^[1-9][0-9]{1,5}$ && "${mport}" -le 65535 ]];then
				Check_Port_Status "${mport}"; [ $? != 0 ] && { Error "输入的 ${mport} 端口被占用了，请重新输入端口";continue; }
			fi
			PrintTrueInfo "caddy的端口是： ${mport}"
			# naive用户名和密码
			naive_user="$(head /dev/urandom | tr -dc a-z0-9 | head -c 8)"
			naive_passwd="$(head /dev/urandom | tr -dc a-z0-9 | head -c 18)"
			[[ -n "${naive_user}" && -n "${naive_passwd}" ]] && break
		done
	}

	# 批量保存账号
	save_naive() {
		#保存帐号
		if [ ! -e ${desktop}/$(date +%m%d)-创建naive帐号 ]; then
			mkdir -p ${desktop}/$(date +%m%d)-创建naive帐号
			sudo chown $(who | awk '{print $1}') ${desktop}/$(date +%m%d)-创建naive帐号
			sudo chgrp $(who | awk '{print $1}') ${desktop}/$(date +%m%d)-创建naive帐号
		fi
		
		cat > ${desktop}/$(date +%m%d)-创建naive帐号/naive_帐号${i}.txt <<-EOF
			地址：${domain}
			端口：${mport}
			用户名：${naive_user}
			密码：${naive_passwd}
			____________________________________________________
			
			【naive帐号分享链接】：naive+https://${naive_user}:${naive_passwd}@${domain}:${mport}?padding=true#naive-${i}
		EOF
		
		cat >> ${desktop}/$(date +%m%d)-创建naive帐号/【naive_帐号汇总】.txt <<-EOF
			【账号${i}】：
		
			地址：${domain}
			端口：${mport}
			用户名：${naive_user}
			密码：${naive_passwd}

			
			【naive帐号分享链接】：naive+https://${naive_user}:${naive_passwd}@${domain}:${mport}?padding=true#naive-${i}
			____________________________________________________________
			
		EOF
	}

	# 批量添加相同域名不同端口的naive账号，配置caddy1
	Batches_Add_Same_Account() {
		sleep 2		#停留两秒
		[ -f /tmp/tmp_navie_info.log ] && rm /tmp/tmp_navie_info.log	#清理临时存放搭建账号信息的文档
		#输入需要生成的数量
		while :;do
			clear;echo ""; echo -en "${yellow}请输入需要生成 ${domain} 账号的数量：$none"; read quantity
			if [[ -z "${quantity}" || ! ${quantity} =~ ^[1-9]$|^[1-9][0-9]+$ ]];then
				Error "输入的不正确，请按照提示输入，按回车键重新输入！"; continue
			else
				break
			fi
		done
		
		rm -f ${desktop}/$(date +%m%d)-创建naive帐号/【naive_帐号汇总】.txt
		# 循环创建naive账号
		for i in `seq ${quantity}`;do
			Get_Port_Name_Passwd;ConfigCaddy1;save_naive
		done		
		
		if [ -f /tmp/tmp_navie_info.log ];then
			PrintTrueInfo "以下是搭建naive账号信息，请记录好，\n此账号会保存到当前目录的naive_account.txt文档中\n $(cat /tmp/tmp_navie_info.log)"; Notifi "以上信息保存好后请按照回车返回主菜单"
			rm /tmp/tmp_navie_info.log
		else
			Error "没有找到存放批量搭建naive账号的信息文档，账号会存在naive_account.txt文档，请到这个文档中查看，\n回车后返回菜单"
		fi
		Change_http	#修改nginx端口
		sleep 2;RestartServer "caddy"
	}

	# 批量搭建账号没有发现naive文档进行提示
	Print_Error_Info() {
		clear
		PrintTrueInfo "* * * * * * * * * * * * * * * * * * * * * * * * * * * * * *"
		PrintTrueInfo "脚本所在位置没有发现naive.txt文档，请创建naive.txt文档，\n把搭建naive账号的域名复制到naive.txt文档中，一行一个域名。"
		PrintTrueInfo "* * * * * * * * * * * * * * * * * * * * * * * * * * * * * *"
		Notifi "回车后返回主菜单"
	}

	# 批量添加不同域名的naive账号，配置caddy1
	Batches_Add_Different_Account() {
		clear; error=	# 清屏+定义一个存放报错信息的变量
		[ -f /tmp/tmp_navie_info.log ] && rm /tmp/tmp_navie_info.log	#清理临时存放搭建账号信息的文档
		[ ! -f ./naive.txt ] && Print_Error_Info && return 1		# 判断批量搭建naive账号的文档是否存在，不存在则进行提示
		while read line;do		# 批量搭建naive账号
			[ -z "${line}" ] && continue	#发现空行则进行下一个域名
			if [[ ! -z "$(echo ${line}|grep '\.')" \
			&& ${line} =~ ^[a-zA-Z0-9][-a-zA-Z0-9]{0,62}(\.[a-zA-Z0-9][-a-zA-Z0-9]{0,62})+[a-zA-Z]+$ ]];then	#检查输入的域名是否符合规则
				domain="${line}"
			else
				error="${error}\n${line}"; continue
			fi
			PrintTrueInfo "正在搭建 ${domain} ..."
			Get_Port_Name_Passwd; ConfigCaddy1
		done < ./naive.txt
		if [ -f /tmp/tmp_navie_info.log ];then
			PrintTrueInfo "以下是搭建naive账号信息，请记录好，\n此账号会保存到当前目录的naive_account.txt文档中\n $(cat /tmp/tmp_navie_info.log)"; Notifi "以上信息保存好后请按照回车返回主菜单"
			rm /tmp/tmp_navie_info.log
		else
			Error "没有找到存放批量搭建naive账号的信息文档，账号会存在naive_account.txt文档，请到这个文档中查看，\n回车后返回菜单"
		fi
		Change_http	#修改nginx端口
		sleep 2; RestartServer "caddy"
	}

	#安装caddy1程序
	Install_Caddy1() {
		setcap CAP_NET_BIND_SERVICE=+eip /usr/local/bin/caddy
		if Command_Exsit systemctl &>/dev/null; then	# 为caddy程序添加服务配置，检测系统中systemctl服务管理工具，则使用这个服务配置，没有则使用系统默认的服务配置。
			cp -f /tmp/caddy1/init/linux-systemd/caddy.service /lib/systemd/system/
			[ ! -f /lib/systemd/system/caddy.service ] && PrintFalseInfo "caddy服务没有配置上，请稍后再试" && exit
			sed -i "s/on-abnormal/always/" /lib/systemd/system/caddy.service
			sed -i "s/Description=Caddy /Description=Caddy1.0.4-naive/" /lib/systemd/system/caddy.service
			systemctl enable caddy
		else
			cp -f /tmp/caddy1/init/linux-sysvinit/caddy /etc/init.d/caddy
			[ ! -f /etc/init.d/caddy ] && PrintFalseInfo "caddy服务没有配置上，请稍后再试" && exit
			chmod +x /etc/init.d/caddy; update-rc.d -f caddy defaults
		fi
		[ -z "$(grep www-data /etc/passwd)" ] && useradd -M -s /usr/sbin/nologin www-data	# 创建一个caddy使用的用户组
		[ ! -e /etc/ssl/caddy ] && mkdir -p /etc/ssl/caddy && chown -R www-data.www-data /etc/ssl/caddy 	#创建caddy证书的目录
		[ ! -e /etc/caddy ] && mkdir -p /etc/caddy # 创建Caddy需要的配置文件目录
	}

	#下载caddy1程序
	Download_Caddy1() {
		[[ -f /lib/systemd/system/caddy.service && -n "$(grep "Description=Caddy1.0.4-naive" /lib/systemd/system/caddy.service 2>/dev/null)" ]] && PrintTrueInfo "Caddy1已经安装上了" && sleep 3 && return 0
		count=1;while :;do
			PrintTrueInfo "正在下载caddy程序..."
			[ $count == 4 ] && PrintFalseInfo "下载caddy1程序失败，请稍后再尝试" && exit
			[ ! -e /tmp/caddy1 ] && mkdir -p /tmp/caddy1
			if ! wget -P /tmp/caddy1 "https://daofa.cyou/c1/caddy.tar" ;then
				PrintFalseInfo "caddy1程序没有下载完成，停留一秒钟会继续尝试下载" ; sleep 1; let count+=1; continue
			fi
			[[ $(Command_Exsit caddy) ]] && systemctl stop caddy
			tar -xf /tmp/caddy1/caddy.tar -C /tmp/caddy1 && cp -rf /tmp/caddy1/caddy /usr/local/bin
			[ ! -f /usr/local/bin/caddy ] && { PrintFalseInfo "caddy1程序没有安装成功，停留一秒钟会继续尝试安装"; sleep 1; continue; }
			Install_Caddy1; PrintTrueInfo "caddy1程序下载并安装成功"; break
		done
	}

	#检测命令是否存在
	Command_Exsit() {
		command -v $* 2>/dev/null
	}

	#检测系统管理工具
	Check_manage_tool() {
		if Command_Exsit apt &>/dev/null;then	# 检查当前系统的软件包管理工具
			manage="apt" 
		else
			manage="yum"
		fi
	}

	#获取naive版本号
	Get_Naive_Version() {
		count=1
		while :;do
			[ $count == 4 ] && PrintFalseInfo "下载naiveproxy程序失败，请检查系统网络情况，稍后再试" && exit	#循环次数为4次则退出脚本，避免出现死循环
			naive_latest_ver="$(curl -s https://api.github.com/repos/klzgrad/naiveproxy/releases/latest |sed 'y/,/\n/' | awk -F'"' '/tag_name/ {print $4}')"	#获取navie软件版本
			[ -z "${naive_latest_ver}" ] && { PrintFalseInfo "没有获取到naiveproxy最新的稳定版本"; sleep 2;let count+=1; continue; }	#检查获取的版本为空则重新获取
			if [ -f /usr/local/bin/naive ] ;then	#判断系统安装了naive软件，则检查版本
				naive_version="$(/usr/local/bin/naive -version | awk '{print $2}')" #获取当前系统安装的naive软件版本
				[ -z "${naive_version}" ] && break	#检测naive版本为空则跳出循环下载naive程序
				if [ "$(echo ${naive_latest_ver:1} | cut -d - -f1)" != "${naive_version}" ];then
					PrintTrueInfo "发现naive有新版本，${naive_latest_ver:1} "; systemctl stop naive
				else
					PrintTrueInfo "当前系统安装的navie软件是最新版本，版本为：${naive_version} ";sleep 1; return 1
				fi
			fi; break  
		done; Download_Naive #下载naive软件
	}

	#配置naive服务
	Naive_Serive() {
		cat > /etc/systemd/system/naive.service <<-EOF
		[Unit]
		Description=NaiveProxy Server Service
		After=network-online.target

		[Service]
		Type=simple
		User=nobody
		CapabilityBoundingSet=CAP_NET_BIND_SERVICE
		ExecStart=/usr/local/bin/naive /etc/naive/config.json

		[Install]
		WantedBy=multi-user.target
		EOF
		
		sleep 3; systemctl enable naive; RestartServer "naive"
	}

	#启动服务配置
	RestartServer() {
		systemctl daemon-reload
		for ((i=1;i<4;i++));do
			systemctl restart $*
			[ -n "$(systemctl status $* | egrep '\<inactive\>')" ] && continue
			if [ -n "$(systemctl status $* | grep Error)" ];then
				PrintFalseInfo "$* 服务没有重启成功，请稍后在尝试"; sleep 2; return 1
			else
				PrintTrueInfo "$* 服务启动成功。";sleep 2; return 0
			fi
		done
		Error "$* 服务没有启动，请手动启动一下。"
	}

	#配置naive
	ConfigNaive() {
		while :;do
			naive_port=$(shuf -i20001-65535 -n1);[ -n "${naive_port}" ] && break    #随机生成naive监听端口
		done
		[ ! -e /etc/naive ] && mkdir /etc/naive
		cat > /etc/naive/config.json <<-EOF
		{
			"listen": "http://127.0.0.1:${naive_port}",
			"padding": true
		}	
		EOF
		Naive_Serive	# 添加naive服务。
	}

	#下载naiveproxy
	Download_Naive() {
		count=1
		while :;do
			[ $count == 4 ] && PrintFalseInfo "下载naiveproxy程序失败，请检查系统网络情况，稍后再试" && exit	#循环次数为4次则退出脚本，避免出现死循环
			PrintTrueInfo "正在下载naive程序..."
			naive_file_name="/tmp/naive/naive.tar.xz"; [ ! -e /tmp/naive ] && mkdir -p /tmp/naive   #制定下载的naive软件路径+创建存放软件的目录
			naive_download_link="https://github.com/klzgrad/naiveproxy/releases/download/${naive_latest_ver}/naiveproxy-${naive_latest_ver}-linux-x${system_version}.tar.xz"
			if ! wget --no-check-certificate -O "$naive_file_name" $naive_download_link; then   #下载naive程序，并判断是否下载成功
				PrintFalseInfo "naiveproxy程序没有下载成功，过一秒钟会重新尝试"; sleep 2;let count+=1; continue
			fi
			tar -xf ${naive_file_name} -C /tmp/naive	#解压naive程序
			cp /tmp/naive/naiveproxy-${naive_latest_ver}-linux-x${system_version}/naive /usr/local/bin/ ; chmod +x /usr/local/bin/naive	 #复制naive程序到指定的目录中，并赋值执行权限
			[ ! -e /etc/naive ] && mkdir -p /etc/naive			#没有发现naive目录，则创建
			[ ! -f /etc/naive/config.json ] && ConfigNaive     #没有发现naive配置，则进行配置
			break
		done
	}

	#获取域名
	Input_domain() {
		#输入域名=========================================================>
		while :; do
			clear;echo "";read -p "$(echo -e ${yellow} 请输入搭建naive账号的域名，例如：www.domainname.com：${none})" domain
			if [[ ! -z "$(echo ${domain}|grep '\.')" \
			&& ${domain} =~ ^[a-zA-Z0-9][-a-zA-Z0-9]{0,62}(\.[a-zA-Z0-9][-a-zA-Z0-9]{0,62})+[a-zA-Z]+$ ]];then	#检查输入的域名是否符合规则
				break
			else
				PrintFalseInfo " 域名输入错误，请重新输入！"; sleep 2
			fi
		done
		domain=${domain,,}
		PrintTrueInfo " 伪装域名(host)：$domain"	#反馈域名的信息
		Get_Ip	#检查VPS的IP地址
		#输入域名<=====================================================
	}

	#删除naive账号
	Delete_Account() {
		while :;do
			[ ! -e /etc/caddy/sites ] && Error "没有sites的目录" && break
			delete_menu=($(ls /etc/caddy/sites/| grep "^naive"))
			clear;[ -z "${delete_menu}" ] && Error "没有要删除的域名配置文件，请回车后返回主菜单" && break
			deamon_arry_long=${#delete_menu[*]}
			PrintTrueInfo "以下是搭建的naive：[${magenta}1-${#delete_menu[*]}$none]"
			for ((i = 1; i <= ${#delete_menu[*]}; i++)); do
				Stream="$(echo ${delete_menu[$i - 1]} | sed 's/.cfg//g')"
				[[ "$i" -le 9 ]] && echo -e "$yellow  $i. $none${Stream}" || echo -e "$yellow $i. $none${Stream}"
			done
			PrintTrueInfo "删除前请确认清楚！"
			delete_num=; read -p "$(echo -e "请选择删除的域名，直接输入数值【输入 q 返回主菜单】:")" delete_num
			[ -z "$delete_num" ] && PrintFalseInfo "输入为空，请重新选择" && continue
			case $delete_num in
				[1-9] | [1-9][0-9] | [1-9][0-9][0-9])
					let deamon_arry_long+=1
					if [ "${delete_num}" -ge "${deamon_arry_long}" ] || [ "${delete_num}" -le "0" ];then
						PrintFalseInfo "输入的数值 ${delete_num} 超过了提示的数值，请重新输入。" ; sleep 2; continue	
					fi
					domain=$(echo ${delete_menu[$delete_num - 1]} | sed 's/.cfg//')
					PrintTrueInfo "删除的域名是： $domain 正在删除..."
					if [ -f /etc/caddy/sites/${delete_menu[$delete_num - 1]} ];then
						sites_url_del=$(cat /etc/caddy/sites/${delete_menu[$delete_num - 1]} | grep 'root' | awk '{print $2}') 
						rm -rf /etc/caddy/sites/${delete_menu[$delete_num - 1]}
						[ -e "${sites_url_del}" ] && rm -rf "${sites_url_del}"
						test -e /etc/caddy/ssl && rm -rf /etc/caddy/ssl/${domain}.* 2>/dev/null	#删除域名的证书
					else
						Error "要删除的域名没有删除成功，请稍后再删除"; continue
					fi
					[ ! -f /etc/caddy/sites/${delete_menu[$delete_num - 1]} ] && PrintTrueInfo "域名删除成功" || PrintFalseInfo "域名没有删除成功"
					RestartServer "caddy"	#重启服务
					read -p "$(echo -e "(是否需要继续删除域名[y|n](默认为y): [${magenta}Y$none]):") " del_domin
					[[ "${del_domin}" == "n" ]] && break ;;
				"q") break ;;
				*) Error "请按照提示输入" ;;
			esac
		done
	}

	#停止服务
	Stop_Serive() {
		systemctl stop $*; systemctl disable $*
	}

	#卸载naive+caddy
	Uninstall() {
		#卸载naive
		if Command_Exsit naive &>/dev/null;then
			Stop_Serive naive; [ -f /usr/local/bin/naive ] && rm -rf /usr/local/bin/naive
			[ -f /etc/systemd/system/naive.service ] && rm -rf /etc/systemd/system/naive.service
			[ -e /etc/naive ] && rm -rf /etc/naive
			[[ ! -f /usr/local/bin/naive && ! -e /etc/naive ]] && PrintTrueInfo "naive卸载完成。" || PrintFalseInfo "naive没有卸载成功，请重启系统后再尝试"
		else
			PrintTrueInfo "当前系统没有安装naive。"; sleep 2 
		fi
		#删除下载的伪装网页
		rm -rf /www/*
		#卸载caddy
		if Command_Exsit caddy &>/dev/null;then 
			if [[ -z "$(ls /etc/caddy/sites/ | grep -v 'naive' 2>/dev/null)" ]];then
				Stop_Serive caddy ; [ -f /lib/systemd/system/caddy.service ] && rm -rf /lib/systemd/system/caddy.service
				[ -f /usr/local/bin/caddy ] && rm -rf /usr/local/bin/caddy
				[ -e /etc/caddy ] && rm -rf /etc/caddy
				[[ ! -f /usr/local/bin/caddy && ! -e /etc/caddy ]] && PrintTrueInfo "caddy卸载完成。" || PrintFalseInfo "caddy没有卸载成功，请重启系统后再尝试"
			else
				PrintTrueInfo "caddy配置中还有其它的账号就不能卸载caddy程序了"
			fi
		else
			PrintTrueInfo "当前系统没有安装caddy。";sleep 2 
		fi
		Notifi "查看反馈的信息，按回车后退出脚本"
	}

	#获取naive监听端口
	Get_Naive_Port() {
		if [[ $(Command_Exsit naive) && -f /etc/naive/config.json ]];then
			naive_port="$(awk -F'[:"]' '/listen/ {print $7}' /etc/naive/config.json)"
			[[ ${naive_port} =~ ^[0-9]+$ ]] && PrintTrueInfo "naive监听端口：${naive_port}" || { Error "没有获取到naive端口，请重新尝试。";exit; }
		else
			Error "系统中没有安装naive程序，请先安装naive程序" && exit
		fi
	}

	# 安装时的选择菜单
	Install_Menu() {
		while :;do
			clear
			PrintTrueInfo "* * * * * * * * * 选择搭建方式 * * * * * * * * *"
			PrintTrueInfo "1、添加一个naive账号"
			PrintTrueInfo "2、批量添加同域名不同端口的naive账号"
			PrintTrueInfo "3、批量添加不同域名的naive账号"
			read -p " 请按提示选择，输入序号就可以（按q返回主菜单）：" answer
			case $answer in
				1) Input_domain; Caddy_Menu; ConfigCaddy1 ;;
				2) Input_domain; Batches_Add_Same_Account ;;
				3) Batches_Add_Different_Account ;;
				q) return ;;
				*)  Error "请按照提示选择！回车后继续选择";continue ;;
			esac
			break
		done
	}

	#安装naive+caddy
	Install() {
		Get_Naive_Version; Download_Caddy1; Install_Menu
	}

	# 清理wget日志文件
	Clear_Log() {
		rm -f ./wget-log* &>/dev/null
		rm -f ${desktop}/wget-log.* &>/dev/null
	}

	#菜单
	Menu() {
		Clear_Log
		while :;do
			clear; answer=
			echo "#############################################################"
			echo -e "                     ${yellow}搭建naive账号脚本${PLAIN}                      "
			echo -e "${yellow}说明：此脚本使用naiveproxy+caddy1进行组合，暂时不支持caddy2${none}"
			echo "#############################################################"
			if [[ ! $(Command_Exsit naive) || -z $(grep "Description=Caddy1.0.4-naive" /lib/systemd/system/caddy.service 2>/dev/null) ]];then  
				PrintTrueInfo "0、安装naive+caddy1程序并搭建账号"
			else
				PrintTrueInfo "1、添加naive账号"
				PrintTrueInfo "2、批量添加同域名不同端口的naive账号"
				PrintTrueInfo "3、批量添加不同域名的naive账号"
				PrintTrueInfo "4、批量生成已经搭建的naive账号链接"
				PrintTrueInfo "5、删除naive账号"
				PrintTrueInfo "6、更新naive程序"
				PrintTrueInfo "7、卸载naive+caddy1"
				if Command_Exsit nginx &>/dev/null;then
					PrintTrueInfo "8、停止caddy服务"
					PrintTrueInfo "9、解决caddy和nginx端口80冲突"
				fi
			fi
			read -p " 请按提示选择，输入序号就可以（按q退出脚本）：" answer
			case $answer in
				0) Install ;;
				1) Get_Naive_Port; Input_domain; Caddy_Menu; ConfigCaddy1 ;;
				2) Get_Naive_Port; Input_domain; Batches_Add_Same_Account ;;
				3) Get_Naive_Port; Batches_Add_Different_Account ;;
				4) Create_Naive_Account ;;
				5) Delete_Account ;;
				6) Get_Naive_Version; RestartServer "naive"; [ $? != 0 ] && Error "naive服务没有启动成功，请稍后在尝试，回车后返回菜单" || Notifi "naive更新成功，回车后返回菜单" ;;
				7) Uninstall;exit ;;
				8) systemctl stop caddy; [ -n "$(systemctl status caddy | egrep '\<inactive\>')" ] && { PrintTrueInfo "caddy停止成功.";exit; } || { PrintFalseInfo "caddy没有禁用成功.";exit; } ;;
				9) Change_http; RestartServer "caddy" ; Notifi "处理完成，请看反馈信息。回车后返回主菜单" ;;
				q) Clear_Log; exit ;;
				*)  Error "请按照提示选择！"  ;;
			esac
		done
	}

	#安装所需软件
	Install_Softeware() {
		software="curl wget lsof"	# 软件列表
		for i in ${software};do		# 循环安装软件
			if ! Command_Exsit $i &>/dev/null;then	#检查软件不存在则安装
				${manage} install $i -y;${manage} install libnss3 xz-utils -y	#安装软件和组件
			fi
		done
	}
	
	unt_ll	#卸载流量监控脚本
	Clear_Log	# 清理wget日志文件
	Get_System_Version  #获取系统版本号
	Check_manage_tool	# 获取系统管理工具
	Install_Softeware	#安装软件
	Menu	#菜单
}
########################自定义增加的项目 结束########################



########################备份还原xui配置 开始########################
# 备份x-ui相关文件
back_xui() {
	#获取用户名
	user_name=$(who | awk '{print $1}')
	#创建文件夹并给予权限
	mkdir -p ${desktop}/xui_config_back
	sudo chown ${user_name} ${desktop}/xui_config_back/
	sudo chgrp ${user_name} ${desktop}/xui_config_back/
	
	#开始备份文件
	cp -f /etc/nginx/nginx.conf ${desktop}/xui_config_back/
	cp -f /etc/x-ui/x-ui.db ${desktop}/xui_config_back/
	cp /usr/local/x-ui/bin/config.json ${desktop}/xui_config_back/
	
	#备份证书
	cp -f /etc/x-ui/server.crt  ${desktop}/xui_config_back/
	cp -f /etc/x-ui/server.key  ${desktop}/xui_config_back/
	
	clear
	echo -e ${green}"已把文件备份到 "${desktop}/xui_config_back" 目录下！ ${plain}"
	echo ""
	echo -e ${red}"按任意键继续！ ${plain}"
	read -n 1
}

# 还原x-ui相关文件
res_xui() {	
	if [ ! -e ${desktop}/xui_config_back ]; then
		clear
		echo -e ${red}"未检测到备份的文件，请先备份再操作！ ${plain}"
		read -n 1
	else
		cp -f ${desktop}/xui_config_back/nginx.conf /etc/nginx/
		cp -f ${desktop}/xui_config_back/config.json /usr/local/x-ui/bin/
		cp -f ${desktop}/xui_config_back/x-ui.db /etc/x-ui/
		cp -f ${desktop}/xui_config_back/server.* /etc/x-ui/
		
		cp -f ${desktop}/xui_config_back/x-ui.db /etc/nginx/ssl/
		cp -f ${desktop}/xui_config_back/server.* /etc/nginx/ssl/
		
		clear
		echo -e ${green}"已还原文件！ ${plain}"
		echo ""
		echo -e ${red}"按任意键继续！ ${plain}"
		read -n 1
	fi
}

# 重新申请证书
ctr_xui() {
	clear
	echo 
	echo -n -e ${green}"请输入已解析好的域名: ${plain}" && read realmname
	echo 
	#安装acme：
	curl https://get.acme.sh | sh
	#添加软链接：
	ln -s  /root/.acme.sh/acme.sh /usr/local/bin/acme.sh
	#切换CA机构：
	acme.sh --set-default-ca --server letsencrypt
	#申请证书： 
	acme.sh  --issue -d ${realmname} -k ec-256 --webroot  /var/www/html
	#安装证书：
	acme.sh --install-cert -d ${realmname} --ecc \
	--key-file       /etc/x-ui/server.key  \
	--fullchain-file /etc/x-ui/server.crt \
	--reloadcmd     "systemctl force-reload nginx"
}

cp_xui() {
	clear
	desktop=/home/$(who | awk '{print $1}') 
	if [ ! -e ${desktop}/（x-ui相关配置文件） ]; then
		clear
		echo -e ${red}"未检测到"（x-ui相关配置文件）"，请先上传再操作！ ${plain}"
		read -n 1
	else
		cp -f ${desktop}/（x-ui相关配置文件）/nginx.conf /etc/nginx/
		cp -f ${desktop}/（x-ui相关配置文件）/config.json /usr/local/x-ui/bin/
		cp -f ${desktop}/（x-ui相关配置文件）/x-ui.db /etc/x-ui/
		cp -f ${desktop}/（x-ui相关配置文件）/server.* /etc/x-ui/
		
		cp -f /etc/x-ui/server.* /etc/nginx/ssl/
		
		clear
		x-ui restart
		echo ""
		echo -e ${green}"已还原文件！按Q键可退出查看nginx的状态 ${plain}"
		echo ""
		
		systemctl restart nginx #重启Nginx的命令
		systemctl reload nginx #重启Nginx的命令
		systemctl status nginx #查看Nginx运行状态的命令
		clear
		if [ -e ${desktop}/（x-ui相关配置文件） ];then
			rm -rf ${desktop}/（x-ui相关配置文件）
		fi
	fi
}
########################备份还原xui配置 结束########################



#菜单
menu() {
	clear
	echo "#############################################################"
	echo -e "#                     ${RED}Xray一键安装脚本${PLAIN}                      #"
	echo "#############################################################"
	echo ""
	echo -e "  ${GREEN}1.${PLAIN}  更新系统"
	echo -e "  ${GREEN}2.${PLAIN}  防火墙和sshd安全设置"
	echo -e "  ${GREEN}3.${PLAIN}  VPS登录管理"    
	echo " ______________________________________"
	echo ""
	echo -e "  ${GREEN}4.${PLAIN}  安装x-ui面板"
	echo -e "  ${GREEN}5.${PLAIN}  管理naiveproxy"
	echo -e "  ${GREEN}6.${PLAIN}  证书管理页面"
	echo " ______________________________________"
	echo ""
	echo -e "  ${GREEN}7.${PLAIN}  x-ui相关配置文件备份"
	echo -e "  ${GREEN}8.${PLAIN}  x-ui相关配置文件还原"
	echo -e "  ${GREEN}9.${PLAIN}  x-ui复制（x-ui相关配置文件）"
	echo " ______________________________________"
	echo ""
	echo -e "  ${GREEN}0.${PLAIN}   退出"
	echo

	read -p " 请选择操作[0-14]：" answer
	case $answer in
		0) exit 1 ;;
		1) optimize_set ;;
		2) Select_Security_Set ;;
		3) vps_login ;;
		4) install_xui ;;
		5) install_naiveproxy ;;
		6) start_menu "first" ;;
		7) back_xui ;;
		8) res_xui ;;
		9) cp_xui ;;
		*) colorEcho $RED " 请选择正确的操作！" && exit 1 ;;
	esac
}

rm -rf acme.sh-master
rm -f master.tar.gz 
checkSystem
checkwarp
get_ip

action=$1
[[ -z $1 ]] && action=menu
case "$action" in
	menu | update | uninstall | start | restart | stop | showLog) ${action} ;;
	*) echo " 参数错误" && echo " 用法: $(basename $0) [menu|update|uninstall|start|restart|stop|showLog]" ;;
esac

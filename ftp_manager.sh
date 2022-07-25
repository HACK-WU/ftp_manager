#!/bin/bash
########################################
# Author:hackwu
# time:2022年07月24日 星期日 22时28分45秒
# filename:ftp_manager.sh
# Script description:
########################################

#通用操作
#	1、禁止下载
#	2、禁止删除
#
#匿名用户登录、本地用户、
#	1、默认权限，只读
#	2、增删改

set -u

chroot_vsftpd="/etc/vsftpd"     #vsftpd服务，根目录
config_file="$chroot_vsftpd/vsftpd.conf"  #vsftpd服务，配置文件

NODown="download_enable=NO\n"	#禁止下载
NORemove="cmds_allowed=ABOR,CWD,LIST,MDTM,MKD,NLST,PASS,PASV,PORT,PWD,QUIT,RETR,RNFR,RNTO,SIZE,STOR,TYPE,USER,REST,CDUP,HELP,MODE,NOOP,REIN,STAT,STOU,STRU,SYST,FEAT\n"			#禁止删除

##权限标志:
r_NODown="r_NODown"			#只读，并且不能下载,只对匿名用于有效	
r_Upload="r_Upload"			#只读，只能上传文件，这个只对匿名用户有效
rwx="rwx"					#有增删改权限
rwxNORemove="rwxNORemove"	#有增和改的权利，但不能删除
rwxNODown="rwxNODown"		#有增和改的权限，但不能下载
rwxSBIT="rwxSBIT"			#只能对自己的文件进行增删改，他人的文件，无法操作
rwxSBIT_NODown="rwxSBIT_NODown"	#不能对其他人的文件进行操作，并且无法下载。

###########

default_conf="
anonymous_enable=YES\n
local_enable=YES\n
chroot_local_user=YES\n
write_enable=YES\n
allow_writeable_chroot=YES\n
local_umask=022\n
anon_umask=022\n
dirmessage_enable=YES\n
xferlog_enable=YES\n
connect_from_port_20=YES\n
xferlog_std_format=YES\n
listen=NO\n
listen_ipv6=YES\n
pam_service_name=vsftpd\n
userlist_enable=YES\n
tcp_wrappers=YES\n
user_config_dir=/etc/vsftpd/vsftpd_user_conf\n
\n
\n
"
> $config_file					#清空原配置文件
echo -e  $default_conf > $config_file	#写入新的配置文件。

[ -e /etc/vsftpd/vsftpd_user_conf ]||mkdir /etc/vsftpd/vsftpd_user_conf

echo "配置文件初始化完毕：$config_file"

#############################目录授权###################################

function dir_permission {	
	local user=$1
	local dir=$2
	[[ "$1" == "ftp"||"$1" == "anonymous" ]] && chmod 757 $dir ; return 0	#匿名用户授权
	

}

function local_user_dir_permission {
	local user=$1	
	usermod -G $local_ftpgroup	$user		#将用户加入对应的用户组里，以此获得授权		
}

##############################匿名用户配置###################################
function anon_conf {
	local permission=$1				#权限
	local user=ftp					#用户名
	set +u
	[ -z $2 ]&& local anon_root=/var/ftp/pub||local anon_root=$2;echo -e "anon_root=$anon_root" >> $config_file  #指定用户家目录,并写入配置文件
	set -u
	dir_permission ftp $anon_root	#对目录进行授权
#	r_NODown="r_NODown"         #只读，并且不能下载 
#	r_Upload="r_Upload"         #只读，只能上传文件，这个只对匿名用户有效
#	rwx="rwx"                   #有增删改权限
#	rwxNORemove="rwxNORemove"   #有增和改的权利，但不能删除
#	rwxNODown="rwxNODown"       #有增和改的权限，但不能下载
	
	case  permission in
		$r_NODown)  r_NODown	;;
		$r_Upload)	r_Upload	;;
		$rwx)		rwx			;;
		$rwx_NORemove)	rwx_NORemove ;;
		$rwx_NODown)	rwx_NODown   ;;
		*)	echo "没有这个权限;执行失败！！";return 1 ;;
	esac	
	echo "匿名用户配置完成：$permission !"	
	function r_NODown	{
		echo "只读，并且不能下载 "
		echo -e  "$NODown" >> $config_file
	}
	
	function r_Upload {
		echo "只读，只能上传文件"
		echo -e "
		anon_upload_enable=YES
		anon_mkdir_write_enable=YES
		" >> $config_file	
	}

	function rwx {
		echo "有增删改权限"
		echo -e "
		anon_upload_enable=YES
		anon_mkdir_write_enable=YES	
		anon_other_write_enable=YES
		" >> $config_file
	}

	function rwx_NORemove {
		echo "有增和改的权利，但不能删除"
		rwx
		echo -e "$NORemove" >> $config_file
	}
	
	function rwx_NODown {
		echo "有增和改的权限，但不能下载"
		rwx
		echo -e "$NODown" >> $config_file
	}

	
}

##############################本地用户配置########################################
function local_conf {
	local permission=$1				#权限
	set +u
	[ -z $2 ] && local local_root=NO || local local_root=$2;echo -e "local_root=$local_root" >> $config_file;#指定家目录，并写入配置文件。
	set -u
	if [ !  "$local_root" == "NO" ];then	
	local_ftpgroup="ftpgroup"		
	groupadd $local_ftpgroup		#创建用户组
	setfacl -m g:$local_ftpgroup:rwx  $local_root	#对用户目录进行授权
	fi
#	r_NODown="r_NODown"         #只读，并且不能下载 
#	rwx="rwx"                   #有增删改权限
#	rwxNORemove="rwxNORemove"   #有增和改的权利，但不能删除
#	rwxNODown="rwxNODown"       #有增和改的权限，但不能下载
#rwxSBIT="rwxSBIT"			#只能对自己的文件进行增删改，他人的文件，无法操作
#rwxSBIT_NODown="rwxSBIT_NODown"	#不能对其他人的文件进行操作，并且无法下载。

	case  permission in
		$rwx_NORemove)	rwx_NORemove ;;
		$rwx_NODown)	rwx_NODown   ;;
		$rwxSBIT)		rwx_SBIT	;;
		$rwxSBIT_NODown) rwxSBIT_NODown ;;
		*)	echo "没有这个权限;执行失败！！";return 1 ;;
	esac	
	echo "本地用户配置完成: $permission !"
	function rwx_NORemove {
		echo "有增和改的权利，但不能删除"
		echo -e "$NORemove" >> $config_file
	}
	
	function rwx_NODown {
		echo "有增和改的权限，但不能下载"
		echo -e "$NODown" >> $config_file
	}

	function rwxSBIT {
		echo "只能对自己的文件进行增删改，他人的文件，无法操作"
		[ "$local_root" == "NO" ] || chmod o+t $local_root
	}

	function rwxSBIT_NODown {
		echo "不能对其他人的文件进行操作，并且无法下载"
		[ "$local_root" == "NO" ]||chmod o+t $lcoal_root;echo "$NODown" >> $config_file
	}
}

#：###########################用户禁锢白名单########################################


function open_chroot_list {   #开启用户禁锢，白名单
	echo -e "chroot_list_enable=YES\n" >> $config_file	
	echo -e "chroot_list_file=$chroot_vsftpd/chroot_list" >> $config_file
	[ -e $chroot_vsftpd/chroot_list   ] || >$chroot_vsftpd/chroot_list	#创建白名单文件

	echo "用户禁锢，白名单创建完成: $chroot_vsftpd/chroot_list"
}


##################################虚拟用户配置################################
function create_vir_user_db {  #创建虚拟用户密码，数据库类型文件
	user_and_passwd="
	hack\n
	123\n
	lisi\n
	123\n	
	"
	vir_user.txt=$chroot_vsftpd/vir_user.txt	#用户密码，明文文件
	[ -e $vir_user.txt ] $$ echo -e "$user_and_passwd"  >> $vir_users.txt || echo -e "$user_and_passwd" > $vir_user.txt	#存在，就追加，否则就覆盖 	
	db_load -T -t hash -f $vir_user.txt  $chroot_vsftpd/vir_users.db	#数据加密，并产生数据库类型文件
	
	echo "数据库类型文件，创建完毕：$chroor_vsftpd/vir_user.db"	
	chmod 600 $chroot_vsftpd/vir_user.db	#授权完毕	
}

function create_proxy_user {  #创建代理用户
	local proxy_user=virtual
	local proxy_user_home=/var/ftpvirtual	#代理用户家目录
	id $proxy_user && echo "$proxy_user 已经存在，请从新指定虚拟用户名";get_proxy_user  || useradd -d $proxy_user_home -s /sbin/nologin
	
	function get_proxy_user { #获取代理用户名
		while :
		do
		read -p "请输入新的代理用户名称：" new_name
		id $name && echo "$new_name 已经存在";continue||break	#new_name如果存在，再输入一次。否则退出循环
		done
		proxy_user=new_name		#给代理赋予新的用户名
		useradd -d $proxy_user_home -s /sbin/nologin	#给系统添加这个用户

	}
	echo "代理用户$proxy_user 创建完毕"

}

function open_virtual_login {  #开启虚拟用户登录
	local vsftpd.pam=/etc/pam.d/vsftpd.pam
	local vsftpd.pam2=/etc/pam.d/vsftpd.pam2
	local vsftpd=/etc/pam.d/vsftpd
	local pam_service=pam_service_name
	local pam_conf=$1	#$0参数，是vsftpd.pam或者是vsftpd.pam2
	[ -e $vsftpd.pam ] && echo "出错了$vsftpd.pam 已经存在，无法创建！！即将退出程序"; sleep 2;exit
	[ -e $vsftpd.pam2 ] && echo "出错了$vsftpd.pam2 已经存在，无法创建！！即将退出程序"; sleep 2;exit

	local str=$(grep "#" $vsftpd)
	echo -e "
	$str
	auth        required  pam_userdb.so  db=$chroot_vsftpd/vir_user
	account  required  pam_userdb.so  db=$chroot_vsftpd/vir_user	
 	" > $vsftpd.pam						#用于虚拟用户登录的配置文件
	
	echo -e "
	$str
	auth      sufficient  pam_userdb.so  db=$chroot_vsftpd/vir_user
	account  sufficient  pam_userdb.so  db=$chroot_vsftpd/vir_user
	" > $vsftpd.pam2	
	
	grep -v "#" $vsftpd  >> $vsftpd.pam2			#用于本地用户和虚拟用户同时登录的配置文件
	sed -i "s/$pam_service=vsftpd/$pam_service=$pam_conf/g"	$config_file	#更改vsftpd.conf配置文件
	echo "虚拟用户开启完毕！！！"
		
}




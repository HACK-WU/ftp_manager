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
rwx_NORemove="rwx_NORemove"	#有增和改的权利，但不能删除
rwx_NODown="rwx_NODown"		#有增改的权限，但不能下载和删除
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
reverse_lookup_enable=NO\n
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
	[ -d $2  ] || mkdir $2
        chmod $1 $2 	#匿名用户授权
	echo "目录授权完毕："
	ls -l -d $2	

}

function local_user_dir_permission {   #参数:  $1:用户   $2：用户组（可以省略，省略表明未指定默认目录）
	set +u
	if [  -n $2  ];then	
		if !  usermod -G $2 $1;then		#将用户加入对应的用户组里，以此获得授权
			echo -e  "\033[31m出错，自动退出程序！！\033[0m"
			exit
		fi
		echo "用户授权完毕: $1 -G $local_ftpgroup "
	fi	
	set -u	

			
}

##############################匿名用户配置###################################
function anon_conf {
	local permission=$1				#权限
	local user=ftp					#用户名	
	set +u
	[ -z $2 ] && local anon_root=/var/ftp ||local anon_root=$2
	echo -e "anon_root=$anon_root" >> $config_file  #指定用户家目录,并写入配置文件
	set -u

#	r_NODown="r_NODown"         #只读，并且不能下载 
#	r_Upload="r_Upload"         #只读，只能上传文件，这个只对匿名用户有效
#	rwx="rwx"                   #有增删改权限
#	rwxNORemove="rwxNORemove"   #有增和改的权利，但不能删除
#	rwxNODown="rwxNODown"       #有增和改的权限，但不能下载
	
		
	function r_NODown {
		echo "权限： 只读，并且不能下载 "
		echo -e  "$NODown" >> $config_file	
		dir_permission 755 $anon_root/pub	#对目录进行授权
	}
	
	function r_Upload {
		echo -e  "\033[33m权限：可读，只能上传文件\033[0m"
		echo "anon_upload_enable=YES" >> $config_file
		echo "anon_mkdir_write_enable=YES" >> $config_file	
		dir_permission 757 $anon_root/pub	#对目录进行授权
	}

	function rwx {
		echo -e  "\033[33m权限：有增删改权限\033[0m"
		echo "anon_upload_enable=YES" >> $config_file
		echo "anon_mkdir_write_enable=YES" >> $config_file	
		echo "anon_other_write_enable=YES" >> $config_file
		dir_permission 757 $anon_root/pub	#对目录进行授权
	}

	function rwx_NORemove {
		echo -e  "\033[33m权限：有增和改的权利，但不能删除\033[0m"
		rwx >/dev/null
		echo -e "$NORemove" >> $config_file
		dir_permission 757 $anon_root/pub	#对目录进行授权
	}
	
	function rwx_NODown {
		echo -e  "\033[33m权限：有增和改的权限，但不能下载和删除\033[0m"
		rwx_NORemove > /dev/null
		echo -e "$NODown" >> $config_file
		dir_permission 757 $anon_root/pub	#对目录进行授权
	}
	
	case  $permission in
		$r_NODown)  r_NODown	;;
		$r_Upload)	r_Upload	;;
		$rwx)		rwx			;;
		$rwx_NORemove)	rwx_NORemove ;;
		$rwx_NODown)	rwx_NODown   ;;
		*)	echo "没有这个权限;执行失败！！";return 1 ;;
	esac	
	echo "匿名用户配置完成：$permission !"	
}

##############################本地用户配置########################################
function local_conf {	#参数： $1:权限   $2:本地用户  $3:默认根目录(可以省略)
	[ $(grep -c "/sbin/nologin" /etc/shells  ) -eq 0 ] &&  echo "/sbin/nologin" >> /etc/shells 
	local permission=$1				#权限
	set +u
		if [ -z $3  ];then
			local local_root=NO
		else
			local local_root=$3 
			echo -e "local_root=$local_root" >> $config_file;
			mkdir $local_root
		fi
	set -u
	
	if [ !  "$local_root" == "NO" ];then	
		local local_ftpgroup="ftpgroup"		
		groupadd $local_ftpgroup		#创建用户组
		setfacl -m g:$local_ftpgroup:rwx  $local_root	#对用户目录进行授权
		echo "目录授权完毕："
		getfacl -p $local_root | grep "ftpgroup"
		local_user_dir_permission $2 $local_ftpgroup
	fi
	
#	rwx_NORemove="rwx_NORemove"   #有增和改的权利，但不能删除
#	rwx_NODown="rwx_NODown"       #有增和改的权限，但不能下载
#	rwxSBIT="rwxSBIT"			#只能对自己的文件进行增删改，他人的文件，无法操作
#	rwxSBIT_NODown="rwxSBIT_NODown"	#不能对其他人的文件进行操作，并且无法下载。

	function rwx_NORemove {
		echo  -e "\033[33m有增和改的权利，但不能删除\033[0m"
		echo -e "$NORemove" >> $config_file
	}
	
	function rwx_NODown {
		echo -e "\033[33m有增和改的权限，但不能下载和删除\033[m"
		echo -e "$NODown" >> $config_file
		echo -e "$NORemove" >> $config_file
	}

	function rwxSBIT {
		echo -e "\033[33m只能对自己的文件进行增删改，他人的文件，无法操作\033[0m"
		[ "$local_root" == "NO" ] || chmod o+t $local_root
	}

	function rwxSBIT_NODown {
		echo -e "\033[33m不能对其他人的文件进行操作，并且无法下载和删除\033[0m"
		[ "$local_root" == "NO" ] && return 0
		chmod o+t $local_root
		echo -e  "$NODown" >> $config_file
		echo -e "$NORemove" >> $config_file
	}
	
	case  $permission in
		$rwx_NORemove)	rwx_NORemove ;;
		$rwx_NODown)	rwx_NODown   ;;
		$rwxSBIT)	rwxSBIT	;;
		$rwxSBIT_NODown) rwxSBIT_NODown ;;
		*)	echo "没有这个权限;执行失败！！";exit ;;
	esac	
	echo "本地用户配置完成: $permission !"
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
	local user_and_passwd="hack\n123\nlisi\n123\n"

	local vir_user_txt="$chroot_vsftpd/vir_user.txt"	#用户密码，明文文件
	> $vir_user_txt
	[ -e $vir_user_txt ] && echo -e "$user_and_passwd"  >> $vir_user_txt || echo -e "$user_and_passwd" > $vir_user_txt	#存在，就追加，否则就覆盖 	
	db_load -T -t hash -f $vir_user_txt  $chroot_vsftpd/vir_user.db	#数据加密，并产生数据库类型文件
	
	echo "数据库类型文件，创建完毕：$chroot_vsftpd/vir_user.db"	
	chmod 600 $chroot_vsftpd/vir_user.db	#授权完毕	
}

function create_proxy_user {  #创建代理用户
	local proxy_user=virtual
	local proxy_user_home=/var/ftpvirtual	#代理用户家目录
			
	function get_proxy_user { #获取代理用户名
		while :
		do
			read -p "请输入新的代理用户名称：" new_name
			id $new_name &> /dev/null  && echo "$new_name 已经存在"||break	#new_name如果存在，再输入一次。否则退出循环
		done
		useradd -d $proxy_user_home -s /sbin/nologin $new_name &> /dev/null #给系统添加这个用户
		echo "代理用户$new_name创建完毕"

	}
		
	if id $proxy_user &> /dev/null ;then
		declare -l choose	#将choose的值转为小写
		while :
		do
			read -p  "$proxy_user 已经存在，是否需要从新指定用户(Y/N):" choose
			case $choose in
			y) get_proxy_user; break ;;
			n) 	useradd -d $proxy_user_home -s /sbin/nologin $proxy_user
				echo "创建默认代理用户名为： $proxy_user"
				return 0 ;;
			*)  echo "输入错误！"  ;;
			esac
		done	
	else
		useradd -d $proxy_user_home -s /sbin/nologin $proxy_user
		echo "创建默认代理用户名为： $proxy_user"
	fi	

}

function open_virtual_login {  #开启虚拟用户登录
	local vsftpd_pam=/etc/pam.d/vsftpd.pam
	local vsftpd_pam2=/etc/pam.d/vsftpd.pam2
	local vsftpd=/etc/pam.d/vsftpd
	local pam_service=pam_service_name
	local pam_conf=$1	#$0参数，是vsftpd.pam或者是vsftpd.pam2
	[[ "$pam_conf" != "vsftpd.pam" && "$pam_conf" != "vsftpd.pam2"    ]] && echo '$1 参数错误！'&& exit
	[ -e $vsftpd_pam ] && echo -e "\033[31m警告：$vsftpd_pam 已经存在，请手动删除，否则将使用原配置内容\033[0m"
	[ -e $vsftpd_pam2 ] && echo -e  "\033[31m警告：$vsftpd_pam2 已经存在，请手动删除，否则将使用原配置内容\033[0m"

	local str=$(grep "#" $vsftpd)
echo -e "$str
auth        required  pam_userdb.so  db=$chroot_vsftpd/vir_user
account  required  pam_userdb.so  db=$chroot_vsftpd/vir_user	
" > $vsftpd_pam						#用于虚拟用户登录的配置文件
	
echo -e "$str
auth      sufficient  pam_userdb.so  db=$chroot_vsftpd/vir_user
account  sufficient  pam_userdb.so  db=$chroot_vsftpd/vir_user
" > $vsftpd_pam2	
	
	grep -v "#" $vsftpd  >> $vsftpd_pam2			#用于本地用户和虚拟用户同时登录的配置文件
	sed -i "s/$pam_service=vsftpd/$pam_service=$pam_conf/g"	$config_file	#更改vsftpd.conf配置文件
	echo "虚拟用户开启完毕！！！"
}

#local_conf rwxSBIT_NODown zhangsan  
#create_vir_user_db
#create_proxy_user
open_virtual_login vsftpd.pam2
if systemctl status vsftpd > /dev/null ;then
	systemctl restart vsftpd.service
	echo "vsftpd重启完成！！"
else
	systemctl restart vsftpd.service
	echo "vsftp已经启动！！"
fi


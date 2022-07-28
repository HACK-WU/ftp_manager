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

ftp_manager_log=/var/log/ftp_manager.log	#日志功能
[ -f $ftp_manager_log ]||touch /var/log/ftp_manager.log

chroot_vsftpd="/etc/vsftpd"     #vsftpd服务，根目录
config_file="$chroot_vsftpd/vsftpd.conf"  #vsftpd服务，配置文件
FTPUSERS="$chroot_vsftpd/ftpusers"	  #黑名单路径
USER_LIST="$chroot_vsftpd/user_list"


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
function init {
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
userlist_deny=YES\n
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
}

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
	
   function per {			#参数: $1:权限;  $2: 根目录(可以省略) 	
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
		echo -e "\033[33m权限： 只读，并且不能下载\033[0m"
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
	echo  -e  "\033[33m匿名用户配置完成：$permission !\033[0m"	
    }
	
	local permission=$(whiptail --title "匿名用户配置"   --radiolist \
	"请选择权限(回车确认)：" 15 60 6 \
	"read" "只读" ON  \
	"r_NODown" "只读，不能下载" OFF \
	"r_Upload" "只读，允许上传文件" OFF \
	"rwx" "增删改" OFF \
	"rwx_NORemove" "增和改，不能删除" OFF \
	"rwx_NODown" "增和改，不能删除和下载" OFF 3>&1 1>&2 2>&3) #权限选择
       	
	[ "$permission" == "read" ] && return 0

	local chroot_path=$(whiptail --title "默认目录" --inputbox "请输入默认目录绝对路径(/var/ftp)：" 10 60 /var/ftp/ 3>&1 1>&2 2>&3)  #根目录选择
	per $permission $chroot_path  
}

##############################本地用户配置########################################
local_ftpgroup=ftpgroup
function local_conf {	
	
   function per {	#参数： $1:权限    $2:默认根目录(可以省略)
	[ $(grep -c "/sbin/nologin" /etc/shells  ) -eq 0 ] &&  echo "/sbin/nologin" >> /etc/shells 
	local permission=$1				#权限
	set +u
		if [ -z $2  ];then
			local local_root=NO
		else
			local local_root=$2 
			echo -e "local_root=$local_root" >> $config_file;
			mkdir -p  $local_root
		fi
	set -u
	
	if [ !  "$local_root" == "NO" ];then	
		local_ftpgroup="ftpgroup"		
		groupadd $local_ftpgroup		#创建用户组
		setfacl -m g:$local_ftpgroup:rwx  $local_root	#对用户目录进行授权
		echo -e  "目录最大权限以授予\033[33m$local_ftpgroup用户组\033[0m！"
		getfacl -p $local_root | grep "ftpgroup"
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
		rwx) echo "增删改权限！！" ;;
		$rwx_NORemove)	rwx_NORemove ;;
		$rwx_NODown)	rwx_NODown   ;;
		$rwxSBIT)	rwxSBIT	;;
		$rwxSBIT_NODown) rwxSBIT_NODown ;;
		*)	echo "没有这个权限;执行失败！！";exit ;;
	esac	
	echo  -e  "\033[33m本地用户配置完成: $permission !\033[0m"
    }
	
   function chroot_path {	#指定根目录
	local OPTION=$(whiptail --title "Menu Dialog" --menu "Choose your favorite programming language." 15 60 2 \
            "1" "默认家目录" \
	    "2" "手动指定"  3>&1 1>&2 2>&3)
	local exitstate=$?
    	if [[ $OPTION -eq 2 || $exitstate -ne 0 ]];then 		
		local root_path=$(whiptail --title "默认目录" --inputbox "请输入默认目录绝对路径(家目录)：" 10 60 /var/ftp/ 3>&1 1>&2 2>&3)  #根目录选择
		echo "$root_path"
	fi 
   }	
   	# function per   参数： $1:权限    $2:默认根目录(可以省略)
	
	local permission=$(whiptail --title "匿名用户配置"   --radiolist \
	"请选择权限(回车确认)：" 15 60 6 \
	"rwx" "增删改" ON  \
	"rwx_NODown" "增删改，不能下载" OFF \
	"rwx_NORemove" "增和改，不能删除" OFF \
	"rwxSBIT" "增删改，只对自己文件有效" OFF \
	"rwxSBIT_NODown" "增和改，只对自己的文件有效,不能下载" OFF \
	"user_auth" "用户授权" OFF \
	3>&1 1>&2 2>&3) #权限选择
	
	local tag=false	
	if [ "$permission" != "user_auth" ];then
		per  $permission  $(chroot_path)
		tag=true
	fi	

	if [[ "$permission" == "user_auth" || $tag == "true"   ]];then	#用户验证
	# function	local_user_dir_permission  参数:  $1:用户   $2：用户组（可以省略，省略表明未指定默认目录）
	  
	local user_name=$(whiptail --title "用户授权" --inputbox "请输入需要授权的用户名：" 10 60  3>&1 1>&2 2>&3)  #根目录选择
	 if ! id $user_name ;then 
		echo  -e  "\033[31m$user_name 用户不存在\033[0m"
		exit
	 fi
         local_user_dir_permission $user_name  $local_ftpgroup
	fi
		
}

#：###########################用户禁锢白名单########################################


function open_chroot_list {   #开启用户禁锢，白名单
	echo -e "chroot_list_enable=YES\n" >> $config_file	
	echo -e "chroot_list_file=$chroot_vsftpd/chroot_list" >> $config_file
	[ -e $chroot_vsftpd/chroot_list   ] || >$chroot_vsftpd/chroot_list	#创建白名单文件

	echo "用户禁锢，白名单创建完成: $chroot_vsftpd/chroot_list"
}

##############################黑名单配置##############################################
function fun1 {

		whiptail --title "YES/NO" --yesno "user already exits" 10 60 
		echo "你的选择：$?"

}
function ftpusers {	
	local user_name=$(whiptail --title "添加用户到黑名单" --inputbox "请输入禁止登录的用户名：" 10 60  3>&1 1>&2 2>&3)  #根目录选择
	local num=$( cat $FTPUSERS| grep -c "$user_name" )
	
	if [ $num -eq 0 ];then
		echo "$user_name" >> $FTPUSERS
		echo "$user_name写入成功！！"
	else
		echo "$user_name用户已存在" 
	fi	
	#echo "num值为：$num"
}
#############################白名单配置##################################

function userlist {	
	local num=$( grep -c "userlist_deny=YES" $config_file )
	echo "num :$num"	
	if [ $num -eq 1 ];then
		local operation="启用白名单"
		local old_state="userlist_deny=YES"
		local new_state="userlist_deny=NO"
		
	else
		local operation="禁用白名单"
		local old_state="userlist_deny=NO"
		local new_state="userlist_deny=YES"
	fi


	OPTION=$(whiptail --title "白名单配置" --menu "请选择对应的选项：" 15 60 4 \
	    "1" "$operation" \
	    "2" "添加白名单" 3>&1 1>&2 2>&3)
	echo "option: $OPTION"

	 if [ $OPTION -eq 1  ];then
		sed -i "s/$old_state/$new_state/g" $config_file	#更改配置文件
		echo "$operation成功！！"
	fi
	

}
##################################虚拟用户配置################################
function create_vir_user_db {  #创建虚拟用户密码，数据库类型文件
	read -p "手动创建用户密码文件(奇数行：用户名；偶数行：密码)，然后输入文件的路径: "  vir_user_txt
	if [ !  -f $vir_user_txt ];then
		echo -e  "\033[31m该密码文件$vir_user_txt不存在,退出程序！\033[0m"
		exit
	fi
	
	db_load -T -t hash -f $vir_user_txt  $chroot_vsftpd/vir_user.db	#数据加密，并产生数据库类型文件
	
	echo "数据库类型文件，创建完毕：$chroot_vsftpd/vir_user.db"	
	chmod 600 $chroot_vsftpd/vir_user.db	#授权完毕	
}
proxy_user=NULL
function create_proxy_user {  #创建代理用户
	proxy_user=virtual
	local proxy_user_home=/var/ftpvirtual	#代理用户家目录
			
	function get_proxy_user { #获取代理用户名
		while :
		do
			read -p "请输入新的代理用户名称：" new_name
			id $new_name &> /dev/null  && echo "$new_name 已经存在"||break	#new_name如果存在，再输入一次。否则退出循环
		done
		useradd -d $proxy_user_home -s /sbin/nologin $new_name &> /dev/null #给系统添加这个用户
		setfacl -m u:$new_name:rwx $proxy_user_home
		echo "代理用户$new_name创建完毕"
		proxy_user=$new_name
	}
		
	if id $proxy_user &> /dev/null ;then
		declare -l choose	#将choose的值转为小写
		while :
		do
			read -p  "$proxy_user 已经存在，是否需要从新指定用户(Y/N):" choose
			case $choose in
			y) get_proxy_user; break ;;
			n) 	useradd -d $proxy_user_home -s /sbin/nologin $proxy_user
				setfacl -m u:$proxy_user:rwx $proxy_user_home
				echo "创建默认代理用户名为： $proxy_user"
				break ;;
			*)  echo "输入错误！"  ;;
			esac
		done			
	else
		useradd -d $proxy_user_home -s /sbin/nologin $proxy_user
		setfacl -m u:$new_name:rwx $proxy_user_home		
		echo "创建默认代理用户名为： $proxy_user"
	fi	
	chmod 755 $proxy_user_home
	echo "家目录为：$proxy_user_home"
}

function virtual_conf {  #虚拟用户配置
   function open_virtual_login {	#开启虚拟用户登录，
	#参数: $1 用户认证文件名：vsftpd.pam或者是vsftpd.pam2
	#	-vsftpd.pam	开启虚拟用户登录，但不支持本地用户登录
	#       -vaftpd.pam2	开启虚拟用户登录，同时支持本地用户登录

	local vsftpd_pam=/etc/pam.d/vsftpd.pam
	local vsftpd_pam2=/etc/pam.d/vsftpd.pam2
	local vsftpd=/etc/pam.d/vsftpd
	local pam_service=pam_service_name
	local pam_conf=$1	#$0参数，是vsftpd.pam或者是vsftpd.pam2
	[ $pam_conf == "vsftpd.pam" ] && echo -e "\033[34m不支持本地用户登录\033[0m"||echo -e "\033[34m支持本地用户登录\033[0m"
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
	create_vir_user_db	#创建用户密码文件			
	create_proxy_user	#创建代理用户	
	echo "guest_enable=YES" >> $config_file
	echo "guest_username=$proxy_user" >> $config_file
	echo "virtual_use_local_privs=NO" >> $config_file
	echo -e  "\033[33m虚拟用户开启完毕！！！\033[0m"
    }

  OPTION=$(whiptail --title "虚拟用户配置" --radiolist "请选择：" 15 60 3\
    "vsftpd.pam" "不支持本地用户登录" ON \
    "vsftpd.pam2" "支持本地用户登录" OFF \
    "change_vir_passwd" "更改用户密码文件" OFF 3>&1 1>&2 2>&3)
    
  if [ "$OPTION" == "change_vir_passwd" ];then
	create_vir_user_db	#创建新的数据库类型文件
	exit
    fi
    	
	open_virtual_login $OPTION
#  	echo "你得选择是：$OPTION"
}


###########################################启动服务###############################
function start_service {

	if systemctl status vsftpd > /dev/null ;then
		systemctl restart vsftpd.service
		echo "vsftpd重启完成！！"
	else
		systemctl restart vsftpd.service
		echo "vsftp已经启动！！"
	fi

}
######################################显示运行信息###############################
function log_sub {    #日志纪录功能
	echo -e "\033[34m--------------------------------------------------------------------\033[0m"
	IFS=$'\n'
	for item in $logsub
	do
		echo $item 
	done
	
}

###############################################whiptail图形化工具#################
logsub=$(init)
echo -e "\033[34m\n\n++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++\033[0m" >> $ftp_manager_log
echo -e "\033[34m$(date)\033[0m" >> $ftp_manager_log
echo $logsub >>$ftp_manager_log
function menu {
	case $1 in
	1)  	;;
	2) logsub=$(anon_conf);log_sub ;;
	3) logsub=$(local_conf);log_sub	;;
	4) logsub=$(virtual_conf);log_sub ;;
	5) logsub=$(ftpusers);log_sub;exit ;;
	6) logsub=$(userlist);log_sub;exit ;;
	7) logsub=$(open_chroot_list);log_sub;exit ;;
	8)  echo "log_tag=true"; return 0 ;;
	esac	
#	start_service
}

function man {
while : 
do
OPTION=$(whiptail --title "vftpd服务配置管理"  --menu "请选择你以下功能：" 15 70 8\
    "1" "一键配置(默认)" \
    "2" "匿名用户配置(默认：只读；根目录:/var/ftp/)" \
    "3" "本地用户配置(默认：增删改;家目录;用户禁锢;)" \
    "4" "虚拟用户配置(默认：不配置)" \
    "5" "黑名单(默认：启用)" \
    "6" "白名单(默认：禁用)" \
    "7" "用户禁锢白名单(默认：禁用)" \
    "8" "查看日志(位置:/var/log/ftp_manager.log)" 3>&1 1>&2 2>&3)
    exitstatus=$?				#退出的状态
    if [ $exitstatus = 0 ]; then
 	menu  $OPTION
    else
        echo "退出成功！！"
	break		#退出循环
    fi
done
start_service	#启动服务
}


ftp_managerlog=$(man)
#man
function log {    #日志纪录功能

	log_tag=$( echo "$ftp_managerlog" | grep -c "log_tag=true")

	if [ $log_tag -ne 0 ];then
		cat $ftp_manager_log
		echo   ${ftp_managerlog//"tag_log=true"/"" } $>/dev/null
		exit	
	fi

	IFS=$'\n'
	for item in $ftp_managerlog
	do
		echo $item 
		echo $item >>$ftp_manager_log
	done

}

log









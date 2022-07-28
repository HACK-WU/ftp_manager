# vsftpd图形化管理工具

## 概述

- **ftp_manager.sh** 是一款用用于管理和配置vsftpd服务的shell脚本。
- 运行时会显示图形化页面
- 无需手动配置vsftp.conf文件，只需几步简单的操作即可自动完成配置
- 涉及的目录和用户授权，也会由此脚本自动对其授权。
- 操作简单，功能齐全，内置不同需求的各种权限设置。
- 支持三种登录方式，一键配置。
- 还具有日志纪录功能。实时纪录配置的相关操作。
- 菜单页面：
  ![imageq](https://xingqiu-tuchuang-1256524210.cos.ap-shanghai.myqcloud.com/3029image1.png)
- 日志纪录：
  ![imageq](https://xingqiu-tuchuang-1256524210.cos.ap-shanghai.myqcloud.com/3029image2.png)

## 运行环境

- **Centos 7.6**

## 功能

- **一键配置**:会根据菜单上每个选项的默认配置。

  - 回车，即可一键配置。

- **匿名用户配置**：

  - ![imageq](https://xingqiu-tuchuang-1256524210.cos.ap-shanghai.myqcloud.com/3029image3.png)
  - 选中对应的权限，回车会进入根目录设置选项：
    - ![imageq](https://xingqiu-tuchuang-1256524210.cos.ap-shanghai.myqcloud.com/3029image4.png)
    - 可以使用默认的目录，也可以自己设置
  - 回车即可配置，成功，然后会返回首页。
    - 可以继续配置，比如本地用户登录配置
    - 虚拟用户登录配置，写入白名单等，都会生效。

- **本地用户配置**

  - 过程与匿名用户配置类似。
  - 后面也可以选择是默认进入家目录还是自定义目录
    - ![imageq](https://xingqiu-tuchuang-1256524210.cos.ap-shanghai.myqcloud.com/3029image5.png)
  - 用户授权，直接输入用户名即可完成授权。
    - ![imageq](https://xingqiu-tuchuang-1256524210.cos.ap-shanghai.myqcloud.com/3029image6.png)

- **虚拟用户配置**

  - 虚拟用户支持两种模式：
    - 不支持本地用户和虚拟用户同时登录
    - 支持本地用户和虚拟用户同时登录
    - 并且支持实时中途修改虚拟用户所用的用户密码文件
    - ![imageq](https://xingqiu-tuchuang-1256524210.cos.ap-shanghai.myqcloud.com/3029image7.png)

  

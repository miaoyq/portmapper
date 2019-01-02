# 端口映射脚本使用说明

包含四个文件：`env`, `.mapper.conf`, `mapper.sh`, `mapper`，下面详细介绍四个文件的功能用途：
- env
    设置环境变量，包括如下环境变量：
    ```
    DEFAULT_HOST_IP=xx.xx.xx.xx
    DEFAULT_BASE_PORT=20000
    DEFAULT_DEST_PORT=22
    ```
    其中，
    - DEFAULT_HOST_IP：表示默认主机IP；
    - DEFAULT_BASE_PORT：表示主机的默认基础端口号，即在用户不指定host端口号的情况下，host的映射端口号为DEFAULT_BASE_PORT加上某个数（这里取目标IP的最后一个数字，如目标IP为172.120.0.216，则host的端口号为20216）
    - DEFAULT_DEST_PORT：表示需要映射的目标端口号，默认为22，即ssh服务器的默认端口号

- .mapper.conf
    注意，该文件名前面有`.`，默认为隐藏文件，保存端口映射配置信息，用户通过命令添加一条端口映射，在该文件中就会增加一条对应的信息。
    配置格式：
    ```
    xx.xx.xx.xx:20213  172.120.0.213:22
    ```
- mapper.sh
    功能主脚本，用来实现端口映射。包括参数解析，端口映射。用户不要直接使用该脚本

- mapper
    用户执行脚本，其包括4中类型的命令，链表如下：
    ```bash
    Commands:
    start   Set all configuration items to iptables
    add     Add a item to config file, add set it to iptables
    clean   Clean all configuration items
    ?       Print the Commands list
    ```

    其中`add`命令还包含如下参数：
    ```bash
    Options of "add":
    ---
    -hostip   The host IP[OPTIONAL]
    -hostport The host port[OPTIONAL]
    -destip   The destination IP that needs to be mapped
    -destport The destination port that needs to be mapped[OPTIONAL]
    ?         Print the option list
```
    - `start`: 该命令可以将已添加的端口映射信息都写入iptables规则中，主要在开机启动的时候使用，可以手动启动，也可以直接设置在开机启动文件中，让自动生效。
    - `add`: 在配置文件中添加一条映射规则，并立即生效，即直接写入iptables规则中
    - `clean`: 清除配置文件中的所有映射信息



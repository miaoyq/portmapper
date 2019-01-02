#!/bin/sh

basepath=$(cd `dirname $0`; pwd)
configfile=$basepath/.mapper.conf

# 如果配置文件不存在，直接退出
if [ ! -f "$configfile" ];then
    touch $configfile
fi


function VerifyIpAddress(){
    IP=$1
    VALID_CHECK=$(echo $IP|awk -F. '$1<=255&&$2<=255&&$3<=255&&$4<=255{print "yes"}')
    if echo $IP|grep -E "^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$">/dev/null; then
        if [ ${VALID_CHECK:-no} == "yes" ]; then
            echo "ok"
        else
            echo "IP $IP not available!"
        fi
    else
        echo "IP $IP format error!"
    fi
}


function SetPortMap(){
    HOST_IP=$1
    HOST_PORT=$2
    DEST_IP=$3
    DEST_PORT=$4

    iptables  -t nat -A PREROUTING -d ${HOST_IP}/32 -p tcp -m tcp --dport ${HOST_PORT} -j DNAT --to-destination ${DEST_IP}:$DEST_PORT
    iptables -t nat -A POSTROUTING -d ${DEST_IP}/32 -p tcp -m tcp --dport $DEST_PORT -j MASQUERADE
    iptables -A FORWARD -d ${DEST_IP}/32 -p tcp -m tcp --dport $DEST_PORT -j ACCEPT
    iptables -A FORWARD -s ${DEST_IP}/32 -p tcp -m tcp --sport $DEST_PORT -j ACCEPT
}


function AssignHostPort(){
    BASE_PORT=$1
    DEST_IP=$2
    # 获取IP地址的最后一个数字段
    last_num=$(echo ${DEST_IP}|awk -F. '{print $4}')
    port_num=`expr $BASE_PORT + $last_num`
    echo $port_num
}


function VerifyPort(){
    port=$1
    if echo ${port}|grep -E "^[0-9]{1,5}$">/dev/null; then
        if [ $port -gt 65535 ]; then
             echo "The port is larger than 65535"
        fi
    fi

    echo "ok"
}

function VerifyHostPort(){
    host_port=$1
    ret=`VerifyPort ${host_port}`
    if [[ ${ret} == "ok" ]]; then
        if [ ! -f $configfile ]; then
            touch $configfile
        fi

        # 读取需要映射的IP list, 设置IP tables 转换规则
        cat $configfile | while read line
        do
            port=$(echo $line|awk  '{print $1}'|awk -F: '{print $2}')
            if [[ ${port} == $host_port ]]; then
                echo "The port $host_port has been used, please set another port!"
                break
            fi
        done
        echo "ok"
    else
        echo $ret
    fi
}

if [[ ${1} == "start" ]]; then

    # 开始映射前，删除端口映射关系文件
    if [ ! -f "$configfile" ];then
        echo "Can't find '.mapper.conf'!"
        exit 0
    fi

    # 读取需要映射的IP list, 设置IP tables 转换规则
    cat $configfile | while read line
    do
        hip=$(echo $line|awk  '{print $1}'|awk -F: '{print $1}')
        hport=$(echo $line|awk  '{print $1}'|awk -F: '{print $2}')
        dip=$(echo $line|awk  '{print $2}'|awk -F: '{print $1}')
        dport=$(echo $line|awk  '{print $2}'|awk -F: '{print $2}')
        SetPortMap $hip $hport $dip $dport
    done
elif [[ ${1} == "clean" ]]; then
    # 清除端口映射关系文件
    if [ -f "$configfile" ];then
        rm -f $configfile
    fi
elif [[ ${1} == "add" ]]; then
    . $basepath/env
    while true; do
        case "${2}" in
        -hostip)
            shift;
            if [[ -n "${2}" ]]; then
                HOST_IP=${2}
                shift;
            fi
            ;;
        -hostport)
            shift;
            if [[ -n "${2}" ]]; then
                HOST_PORT=${2}
                shift;
            fi
            ;;
        -destip)
            shift;
            if [[ -n "${2}" ]]; then
                DEST_IP=${2}
                shift;
            fi
            ;;
        -destport)
            shift;
            if [[ -n "${2}" ]]; then
                DEST_PORT=${2}
                shift;
            fi
            ;;
        --)
            shift;
            break;
            ;;
       \?)
            echo "Options of \"add\":"
            echo "---"
            echo "-hostip   The host IP[OPTIONAL]"
            echo "-hostport The host port[OPTIONAL]"
            echo "-destip   The destination IP that needs to be mapped"
            echo "-destport The destination port that needs to be mapped[OPTIONAL]"
            echo "?         Print the option list"
            shift;
            exit 0;
            ;;
        *)                 
            echo "Error: Bad option \"$2\"."
            echo "---"
            echo "-hostip   The host IP[OPTIONAL]"
            echo "-hostport The host port[OPTIONAL]"
            echo "-destip   The destination IP that needs to be mapped"
            echo "-destport The destination port that needs to be mapped[OPTIONAL]"
            echo ""
            shift;
            exit 1;
            ;;
        esac
    done

    if [ ! -n "$DEST_IP" ] ;then
        echo "Error: Dest ip can not be null."
        exit 1
    fi

    if [ ! -n "$DEST_PORT" ] ;then
        if [ ! -n "$DEFAULT_BASE_PORT" ] ;then
            echo "Error: Dest port is null, and have no set the default base port!"
            exit 1
        fi

        DEST_PORT=$DEFAULT_DEST_PORT
    fi


    if [ ! -n "$HOST_IP" ] ;then
        if [ ! -n "$DEFAULT_HOST_IP" ] ;then
            echo "Error: Host IP is null, and have no set the default host IP!"
            exit 1
        fi

        HOST_IP=${DEFAULT_HOST_IP}
    fi

    if [ ! -n "$HOST_PORT" ] ;then
        HOST_PORT=`AssignHostPort $DEFAULT_BASE_PORT $DEST_IP`
    fi

    ret=`VerifyHostPort $HOST_PORT`
    if [[ $ret != "ok" ]]; then
        echo "Error: Host port format is error: ${ret} !"
        exit 1
    fi


    SetPortMap ${HOST_IP} $HOST_PORT $DEST_IP $DEST_PORT

    # 存储IP地址和端口映射关系表
    echo "${HOST_IP}:${HOST_PORT}  ${DEST_IP}:$DEST_PORT" >> $configfile
    echo "${HOST_IP}:${HOST_PORT} map to ${DEST_IP}:$DEST_PORT"

elif [[ ${1} == "?" ]]; then
    echo "Commands:"
    echo "start   Set all configuration items to iptables"
    echo "add     Add a item to config file, add set it to iptables"
    echo "clean   Clean all configuration items"
    echo "?       Print the Commands list"    
    echo ""
else
    echo "Please enter the correct command!"
    echo "---"

    echo "start   Set all configuration items to iptables"
    echo "add     Add a item to config file, add set it to iptables"
    echo "clean   Clean all configuration items"
    echo ""
fi

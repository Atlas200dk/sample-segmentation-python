#!/bin/bash
script_path="$( cd "$(dirname "$0")" ; pwd -P )"

remote_host=$1

# ************************check ip****************************************
# Description:  check ip valid or not
# $1: ip
# ******************************************************************************
function check_ip_addr()
{
    ip_addr=$1
    echo ${ip_addr} | grep "^[0-9]\{1,3\}\.\([0-9]\{1,3\}\.\)\{2\}[0-9]\{1,3\}$" > /dev/null
    if [ $? -ne 0 ]
    then
        return 1
    fi

    for num in `echo ${ip_addr} | sed "s/./ /g"`
    do
        if [ $num -gt 255 ] || [ $num -lt 0 ]
        then
            return 1
        fi
   done
   return 0
}

# ************************parse remote port****************************************
# Description:  parse remote port
# ******************************************************************************
function parse_remote_port()
{
    remote_port=`grep HOST_PORT ~/ide_daemon/ide_daemon.cfg | awk -F '=' '{print $2}'`

    if [[ ${remote_port}"X" == "X" ]];then
        remote_port="22118"
    fi
}

# ************************check remote file****************************************
# Description:  upload a file
# $1: remote file(relative ~/xxxxx)
# ******************************************************************************
function check_remote_file()
{
    filePath=$1
    if [ ! -n ${filePath} ];then
        return 1
    fi
    ret=`IDE-daemon-client --host ${remote_host}:${remote_port} --hostcmd "wc -l ${filePath}"`
    if [[ $? -ne 0 ]];then
        return 1
    fi

    return 0
}

# ************************uplooad file****************************************
# Description:  upload a file
# $1: local file(absolute)
# $2: remote file path
# ******************************************************************************
function upload_file()
{
    local_file=$1
    remote_path=$2

    #echo "================================="
    #echo "${local_file}"
    #echo "${remote_path}"

    file_name=`basename ${local_file}`
    remote_file="${remote_path}/${file_name}"

    #check remote path
    check_remote_file ${remote_file}

    #check whether overwrite remote file
    if [[ $? -eq 0 ]];then
        ret=`IDE-daemon-client --host ${remote_host}:${remote_port} --hostcmd "rm ${remote_file}"`
        if [[ $? -ne 0 ]];then
            echo "ERROR: delete ${remote_host}:${remote_file} failed, please check /var/log/syslog for details."
            return 1
        fi
    fi

    ret=`IDE-daemon-client --host ${remote_host}:${remote_port} --hostcmd "mkdir -p ${remote_path}"`
    if [[ $? -ne 0 ]];then
        echo "ERROR: mkdir ${remote_host}:${remote_path} failed, please check /var/log/syslog for details."
        return 1
    fi

    #copy to remote path
    ret=`IDE-daemon-client --host ${remote_host}:${remote_port} --sync ${local_file} ${remote_path}`
    if [[ $? -ne 0 ]];then
        echo "ERROR: sync ${local_file} to ${remote_host}:${remote_path} failed, please check /var/log/syslog for details."
        return 1
    fi
    return 0
}

# ************************uplooad path****************************************
# Description:  upload a file
# $1: local path(absolute)
# $2: remote path
# $3: ignore_local_path(true/false, default=false)
#    #${local_path}
#    #      |-----path1
#    #              |-----path11
#    #                        |----file1
#    #      |-----path2
#    #              |-----file2
#    #true: upload file1 to ${remote_path}/file1
#    #      upload file2 to ${remote_path}/file2
#    #false/empty: upload file1 upload to ${remote_path}/path1/path11/file1
#    #             upload file2 to ${remote_path}/path2/file2
# $4: is_uncompress(true/fase, default:true)
# ******************************************************************************
function upload_path()
{
    local_path=$1
    remote_supper_path=$2
    ignore_local_path=$3

    file_list=`find ${local_path} -name "*"`
    for file in ${file_list}
    do
        if [[ -d ${file} ]];then
            continue
        fi
        file_extension="${file##*.}"
        
        if [[ ${ignore_local_path}"X" == "trueX" ]];then
            remote_file_path=${remote_supper_path}
        else
            remote_file=`echo ${file} | sed "s#${local_path}#${remote_supper_path}#g"`
            remote_file_path=`dirname ${remote_file}`
        fi

        upload_file ${file} ${remote_file_path}
        if [[ $? -ne 0 ]];then
            return 1
        fi
    done

    #create resnet18Result to store result images
    ret=`IDE-daemon-client --host ${remote_host}:${remote_port} --hostcmd "mkdir -p ~/HIAI_PROJECTS/ascend_workspace/sample-segmentation-python/Result"`
    return 0
}

# ******************************************************************************
# Description:  deploy application
# ******************************************************************************
function deploy_app()
{
    if [ -d ${script_path}/segmentationapp ];then
        echo "Deploy app..."
        iRet=`IDE-daemon-client --host ${remote_host}:${remote_port} --hostcmd "rm -rf ~/HIAI_PROJECTS/ascend_workspace/sample-segmentation-python"`
        if [[ $? -ne 0 ]];then
            echo "ERROR: delete ${remote_host}:./sample-segmentation-python failed, please check /var/log/syslog for details."
            return 1
        fi
        upload_path ${script_path}/sample-segmentation-python "~/HIAI_PROJECTS/ascend_workspace/sample-segmentation-python"
        if [[ $? -ne 0 ]];then
            echo "ERROR: upload sample-segmentation-python to developer kit failed!"
            return 1
        fi
    fi
}


main()
{
    check_ip_addr ${remote_host}
    if [[ $? -ne 0 ]];then
        echo "ERROR: invalid host ip, please check your command format: ./deploy.sh host_ip."
        exit 1
    fi

    parse_remote_port

    deploy_app
    if [[ $? -ne 0 ]];then
        exit 1
    fi
    
    echo "Finish to deploy Segmentation python Demo."
    exit 0
}

main $*

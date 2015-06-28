#!/bin/bash
set -e
top_dir=$(cd `dirname $0`; pwd)
echo $top_dir
source $top_dir/dl.conf
echo $bucket
echo $domain

function download()
{
    dl_dir=$1
    cd $dl_dir
    files=`find $dl_dir -name 'origin.md'`
    for file in $files; do
        absolute_dir=`dirname $file`
        echo $absolute_dir
        relative_dir=`echo $file | sed -e "s|$dl_dir||" | xargs dirname`
        echo $relative_dir
        
        #如果需要检查md5
        is_check_md5=0
        tmp=`head -n 1 $file | grep md5sum 2>&1`
        if [ "x""$tmp" != "x" ]; then
            is_check_md5=1
        fi

        thead_line_num=`grep -n "\-|\-" $file | awk -F: '{print $1}'`
        offset=$(($thead_line_num+1))
        tail -n +$offset $file | while read line; do
            i=0
            new_line=""
            http_code=200
            size=""
            md5=""
            for part in `echo $line | sed 's/|/ /g'`; do
                echo $part
                #第一列必须是下载地址
                if [ $i -eq 0 ]; then
                    uri=$part
                    origin_filename=`basename $uri`
                    filename=$origin_filename
                    uri_nopro=${part#*//}
                    target_path=${uri_nopro#*/}
                elif [ $i -eq 1 ]; then
                    #第2列必须是文件名或路径，如果为空的话，将使用下载地址里相同的文件名
                    filename=`basename $part`
                    target_path=.$relative_dir/$part
                    if [ $relative_dir == '/' ]; then
                        target_path=$part
                    fi
                elif [ $i -eq 2 ]; then
                    #第3列是size
                    #如果第2列为空，则第3列必须为空，否则第3变成了第2，会错乱
                    size=$part
                elif [ $i -eq 3 ]; then
                    #第4列是md5
                    expected_md5=$part
                fi
                i=$(($i+1))
            done
            target_dir=""
            if [ $target_path != $filename ]; then
                target_dir=${target_path%/*}
                mkdir -p $target_dir
            fi
            echo 'target_path' $target_path
            echo 'target_dir' $target_dir
            echo ''
            if [ ! -f $dl_dir/$target_dir/files.md ]; then
                echo 'filename|size|md5' > $dl_dir/$target_dir/files.md
                echo '--------|----|---' >> $dl_dir/$target_dir/files.md
            fi

            echo "http://$domain/$target_path"
            http_code=`curl -sI "http://$domain/$target_path" | head -n 1 | awk '{print $2}'`
            if [ $http_code -ne 200 ]; then
                if [ ! -f $dl_dir/$target_path ]; then
                    wget -O $dl_dir/$target_path "$uri"
                fi
                size=`ls -lh $dl_dir/$target_path | awk '{print $5}'`
                md5=`md5sum $dl_dir/$target_path | awk '{print $1}'`
                if [ $is_check_md5 -eq 1 ] && [ "x"$expected_md5 != "x" ]; then
                    if [ $expected_md5 != $md5 ]; then
                        echo "error: md5 not match"
                        exit 1
                    fi
                fi
            fi
 
            echo ${filename/_/\\_}'|'$size'|'$md5 >> $dl_dir/$target_dir/files.md
        done
    done
    return 0
}
tmp=$(download $top_dir/dl)
echo "$tmp"
exit
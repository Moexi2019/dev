#!/bin/bash

exit_check(){
    if  [ $? != 0 ];then
        echo "ERROR!...pleck check it and try again"
        exit 1
    else
        echo "ok...."
    fi
}


echo "安装开始..."
echo "正在读取配置文件变量..."
source ./tro.env.conf
echo "进行环境预检..."
sh tro_pre_check.sh
exit_check


cd ${data_dir}
echo "正在解压安装包..."
unzip ${tgz_name} -x __MACOSX/*
exit_check
sleep 3

echo "正在制作前端目录..."
mkdir -p ${data_dir}/apps/dist/tro
mkdir -p ${data_dir}/apps/dist/cloud

echo "正在复制前端文件到前端目录..."
cp  -rf ${data_dir}/${file_name}/dist/tro/* ${data_dir}/apps/dist/tro
cp  -rf ${data_dir}/${file_name}/dist/cloud/* ${data_dir}/apps/dist/cloud


echo "正在设置前端访问域名或ip..."
sed -i "s/^        var serverUrl .*$/        var serverUrl = 'http:\/\/${web_index_ip}\/tro-web\/api';/g" ${data_dir}/apps/dist/tro/index.html
exit_check
sed -i "s/^        var serverUrl .*$/        var serverUrl = 'http:\/\/${cloud_index_ip}\/tro-cloud\/api';/g" ${data_dir}/apps/dist/cloud/index.html
exit_check


echo "正在获取当前本机nginx配置文件路径..."
a=`nginx -t 2>&1 | grep configuration`
if [ ! -z "$a"  ];then
    b="${a#*file}"
    path_nginx_cfg=`echo $b | awk -F " " '{print $1}'`
    echo $path_nginx_cfg
else
    echo "nginx或nginx命令未安装请检查，处理后可重新安装..."
    exit 1
fi




echo "正在重置nginx配置文件为控制台的配置..."
cat <<EOF >${path_nginx_cfg}
user root;
worker_processes auto;
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    access_log  /var/log/nginx/access.log;
    proxy_read_timeout 240s;
    sendfile            on;
    tcp_nopush          on;
    tcp_nodelay         on;
    keepalive_timeout   65;
    types_hash_max_size 2048;
 
    include             /usr/local/nginx/conf/mime.types;
    default_type        application/octet-stream;

    gzip on;
    gzip_comp_level 3;
    gzip_buffers 320 320k;
    gzip_min_length 40960;
    gzip_types text/plain text/style application/javascript application/x-javascript text/javascript text/css application/json;

    server {
        listen       80;
        server_name  localhost;

        client_max_body_size 200M;

        #前端访问配置
        location / {
            root   /data/apps/dist;
            index  index.html index.htm;
        }

        #web后端
        location /tro-web {
            proxy_pass http://127.0.0.1:10008/tro-web;
        }

        #cloud后端
        location /tro-cloud {
            proxy_pass http://127.0.0.1:10010/tro-cloud;
        }

        ##白名单
        location /tro-web/api/confcenter/wbmnt/query{
            add_header Cache-Control no-store;
            root /opt/tro/conf;
        }

        error_page 500 502 503 504  /50x.html;
        location = /50x.html {
            root   html;
        }
    }
}
EOF

echo "正在新建nginx日志目录为数据目录..."
mkdir ${data_dir}/nginx_log/


echo "正在调整nginx配置并reload..."

echo "dist"
sed -i "s%^.*root   \/data\/apps\/dist.*$%            root   ${data_dir}\/apps\/dist;%g" ${path_nginx_cfg}
exit_check
echo "error_log"
sed -i "s%^.*error_log.*$%error_log  ${data_dir}\/nginx_log\/error.log;%g" ${path_nginx_cfg}
exit_check
echo "access_log"
sed -i "s%^.*access_log.*$%    access_log  ${data_dir}\/nginx_log\/access.log;%g" ${path_nginx_cfg}
exit_check


nginx -t
exit_check
kill -9 `pgrep nginx`
nginx
nginx -s reload
exit_check



echo "正在复制后端文件到后端目录..."
cp -rf ${data_dir}/${file_name}/tro-web ${data_dir}/apps
cp -rf ${data_dir}/${file_name}/tro-cloud ${data_dir}/apps


echo "正在修改tro-web的配置文件..."




echo "tro.cloud.url"
sed -i "s/^tro.cloud.url.*$/tro.cloud.url=http:\/\/${tro_cloud_ip}:10010\/tro-cloud/g" ${data_dir}/apps/tro-web/config/application-web.properties
exit_check

echo "amdb.url.amdb"
sed -i "s/^amdb.url.amdb.*$/amdb.url.amdb=http:\/\/${amdb_host}:10032/g" ${data_dir}/apps/tro-web/config/application-web.properties
exit_check

echo "spring.datasource.url"
sed -i "s/^spring.datasource.url=jdbc:mysql.*$/spring.datasource.url=jdbc:mysql:\/\/${trodb_mysql_host}:3306\/trodb?useUnicode=true\&characterEncoding=UTF-8\&useSSL=false\&allowMultiQueries=true/g" ${data_dir}/apps/tro-web/config/application-web.properties
exit_check

echo "spring.redis.host"
sed -i "s/^spring.redis.host.*$/spring.redis.host=${tro_web_redis_host}/g" ${data_dir}/apps/tro-web/config/application-web.properties
exit_check

echo "spring.influxdb.url"
sed -i "s/^spring.influxdb.url.*$/spring.influxdb.url=http:\/\/${influxdb_host}:8086/g" ${data_dir}/apps/tro-web/config/application-web.properties
exit_check

echo "file.upload.tmp.path"
sed -i "s%^file.upload.tmp.path.*$%file.upload.tmp.path=${data_dir}\/apps\/tro-cloud\/scriptfile\/temp%g" ${data_dir}/apps/tro-web/config/application-web.properties
exit_check

echo "file.upload.script.path"
sed -i "s%^file.upload.script.path.*$%file.upload.script.path=${data_dir}\/nfs_dir%g" ${data_dir}/apps/tro-web/config/application-web.properties
exit_check


echo "tro.config.zk.addr"
sed -i "s/^tro.config.zk.addr.*$/tro.config.zk.addr=${pradar_host_zk01}:2181,${pradar_host_zk02}:2181,${pradar_host_zk03}:2181/g" ${data_dir}/apps/tro-web/config/application-web.properties
exit_check


echo "file.upload.user.data.dir"
sed -i "s%^file.upload.user.data.dir.*$%file.upload.user.data.dir=${data_dir}\/apps\/tro\-web%g"  ${data_dir}/apps/tro-web/config/application-web.properties
exit_check

echo "agent.interactive.tro.web.url"
sed -i "s/^agent.interactive.tro.web.url.*$/agent.interactive.tro.web.url=http:\/\/${tro_web_ip}:10008\/tro-web/g"  ${data_dir}/apps/tro-web/config/application-web.properties
exit_check

echo "patrol.bottleneck.detail"
sed -i "s/^patrol.bottleneck.detail.*$/patrol.bottleneck.detail=http:\/\/${web_index_ip}\/tro\/\#\/bottleneckTable\/bottleneckDetails?exceptionId=/g"  ${data_dir}/apps/tro-web/config/application-web.properties
exit_check

echo "data.path"
sed -i "s%^data.path.*$%data.path=${data_dir}%g"  ${data_dir}/apps/tro-web/config/application-web.properties
exit_check

echo "正在制作软连接并启动tro-web..."
cd ${data_dir}/apps/tro-web/
rm -rf ${data_dir}/apps/tro-web/tro-web.jar
ln -s ${tro_jar} tro-web.jar
sh start.sh


echo "正在将admin.conf文件复制到tro-cloud的配置文件目录..."
cp  ${path_damin_cfg}  ${data_dir}/apps/tro-cloud/config/




echo "正在修改tro-cloud的配置文件..."


echo "host.inner.ip"
sed -i "s/^host.inner.ip.*$/host.inner.ip=${tro_cloud_ip}/g" ${data_dir}/apps/tro-cloud/config/application-cloud.properties
exit_check

echo "nfs.server"
sed -i "s/^nfs.server.*$/nfs.server=${nfs_server}/g" ${data_dir}/apps/tro-cloud/config/application-cloud.properties
exit_check

echo "nfs.file.dir"
sed -i "s%^nfs.file.dir.*$%nfs.file.dir=${nfs_file_dir}%g" ${data_dir}/apps/tro-cloud/config/application-cloud.properties
exit_check

echo "script.temp.path"
sed -i "s%^script.temp.path.*$%script.temp.path=${data_dir}\/apps\/tro-cloud\/scriptfile\/temp%g" ${data_dir}/apps/tro-cloud/config/application-cloud.properties
exit_check

echo "script.path"
sed -i "s%^script.path.*$%script.path=${data_dir}\/nfs_dir%g" ${data_dir}/apps/tro-cloud/config/application-cloud.properties
exit_check



echo "spring.influxdb.url"
sed -i "s/^spring.influxdb.url.*$/spring.influxdb.url=http:\/\/${influxdb_host}:8086/g" ${data_dir}/apps/tro-cloud/config/application-cloud.properties
exit_check

echo "spring.redis.host"
sed -i "s/^spring.redis.host.*$/spring.redis.host=${trodb_cloud_redis_host}/g" ${data_dir}/apps/tro-cloud/config/application-cloud.properties
exit_check

echo "spring.datasource.url"
sed -i "s/^spring.datasource.url=jdbc:mysql.*$/spring.datasource.url=jdbc:mysql:\/\/${trodb_cloud_mysql_host}:3306\/trodb_cloud?useUnicode=true\&characterEncoding=UTF-8\&useSSL=false\&allowMultiQueries=true\&serverTimezone=Asia\/Shanghai/g" ${data_dir}/apps/tro-cloud/config/application-cloud.properties
exit_check

echo "trocloud.path"
sed -i "s%^trocloud.path.*$%trocloud.path=${data_dir}\/apps\/tro\-cloud%g" ${data_dir}/apps/tro-cloud/config/application-cloud.properties
exit_check

echo "tro.cloud.deployment.method"
sed -i "s/^tro.cloud.deployment.method.*$/tro.cloud.deployment.method=${tro_cloud_deployment_method}/g" ${data_dir}/apps/tro-cloud/config/application-cloud.properties
exit_check

echo "pressure.engine.images"
sed -i "s/^pressure.engine.images.*$/pressure.engine.images=${harbor_ip}\/library\/pressure-engine:${pressure_engine_images_version}/g" ${data_dir}/apps/tro-cloud/config/application-cloud.properties
exit_check

echo "pradar.zk.servers"
sed -i "s/^pradar.zk.servers.*$/pradar.zk.servers=${pradar_host_zk01}:2181,${pradar_host_zk02}:2181/g" ${data_dir}/apps/tro-cloud/config/application-cloud.properties
exit_check


echo "zk.servers"
sed -i "s%^zk.servers.*$%zk.servers=${pradar_host_zk01}:2181,${pradar_host_zk02}:2181,${pradar_host_zk03}:2181%g" ${data_dir}/apps/tro-cloud/config/application-cloud.properties
exit_check



echo "正在制作软连接并启动tro-cloud..."
cd ${data_dir}/apps/tro-cloud/
rm -rf ${data_dir}/apps/tro-cloud/tro-cloud.jar
ln -s ${cloud_jar} tro-cloud.jar
sh start.sh


echo "正在等待至少15s的启动时间..."
sleep 15

echo "正在开始检查安装结果..."
tro_check(){
        ps_out=`ps -ef | grep $appname | grep -v 'grep' | grep -v $0`
        result=$(echo $ps_out | grep "$appname")
        if [[ "$result" != "" ]];then
                echo "${appname} is running..."
        else
                echo "${appname} is not running...please check!"
        fi
}
appname="tro-web.jar"
tro_check
appname="tro-cloud.jar"
tro_check






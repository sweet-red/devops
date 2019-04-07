#!/bin/sh

#环境准备
#安装依赖包
yum -y install wget gcc epel-release git

#安装python3.6
yum -y install python36 python36-devel

#建立python虚拟环境
cd /opt
python3.6 -m venv py3
source /opt/py3/bin/activate

#安装jumoserver
cd /opt/
git clone https://github.com/jumpserver/jumpserver.git

#安装以来RPM包
cd /opt/jumpserver/requirements
yum -y install $(cat rpm_requirements.txt)

#安装python依赖库
pip install --upgrade pip setuptools -i https://mirrors.aliyun.com/pypi/simple/
pip install -r requirements.txt -i https://mirrors.aliyun.com/pypi/simple/

#redis
yum -y install redis
systemctl enable redis
systemctl start redis

#mysql
yum -y install mariadb mariadb-devel mariadb-server # centos7下安装的是mariadb
systemctl enable mariadb
systemctl start mariadb

#创建数据库并授权
DB_PASSWORD="YR5Sma5iyTCbKHXnWVMFOtSg"
mysql -uroot -e "create database jumpserver default charset 'utf8'; grant all on jumpserver.* to 'jumpserver'@'127.0.0.1' identified by '$DB_PASSWORD'; flush privileges;"

#修改jumpserver配置文件 && 运行jumpserver
SECRET_KEY="cjlC85Q681tHFpH7HZo6cXDcdkAnB8qTJ5LKJTdijqlMmsMfCy"
echo "SECRET_KEY=$SECRET_KEY" >> ~/.bashrc
BOOTSTRAP_TOKEN="uy6yIRad8WanbZPZ"
echo "BOOTSTRAP_TOKEN=$BOOTSTRAP_TOKEN" >> ~/.bashrc

cd /opt/jumpserver
cp config_example.yml config.yml
sed -i "s/SECRET_KEY:/SECRET_KEY: $SECRET_KEY/g" /opt/jumpserver/config.yml
sed -i "s/BOOTSTRAP_TOKEN:/BOOTSTRAP_TOKEN: $BOOTSTRAP_TOKEN/g" /opt/jumpserver/config.yml
sed -i "s/# DEBUG: true/DEBUG: false/g" /opt/jumpserver/config.yml
sed -i "s/# LOG_LEVEL: DEBUG/LOG_LEVEL: ERROR/g" /opt/jumpserver/config.yml
sed -i "s/# SESSION_EXPIRE_AT_BROWSER_CLOSE: false/SESSION_EXPIRE_AT_BROWSER_CLOSE: true/g" /opt/jumpserver/config.yml
sed -i "s/DB_PASSWORD: /DB_PASSWORD: $DB_PASSWORD/g" /opt/jumpserver/config.yml

cd /opt/jumpserver
./jms start all -d

#安装 SSH Server 和 WebSocket Server: Coco

cd /opt
source /opt/py3/bin/activate
git clone https://github.com/jumpserver/coco.git

cd /opt/coco/requirements
yum -y install $(cat rpm_requirements.txt)
pip install -r requirements.txt -i https://mirrors.aliyun.com/pypi/simple/

#修改配置文件并运行
cd /opt/coco
cp config_example.yml config.yml

sed -i "s/BOOTSTRAP_TOKEN: <PleasgeChangeSameWithJumpserver>/BOOTSTRAP_TOKEN: $BOOTSTRAP_TOKEN/g" /opt/coco/config.yml
sed -i "s/# LOG_LEVEL: INFO/LOG_LEVEL: ERROR/g" /opt/coco/config.yml

./cocod start -d

# 安装 Web Terminal 前端: Luna
cd /opt
wget https://github.com/jumpserver/luna/releases/download/1.4.9/luna.tar.gz

# 如果网络有问题导致下载无法完成可以使用下面地址
#$ wget https://demo.jumpserver.org/download/luna/1.4.9/luna.tar.gz

tar xf luna.tar.gz
chown -R root:root luna

#安装配置nginx
yum install yum-utils -y

cat >/etc/yum.repos.d/nginx.repo << EOF 
[nginx-stable]
name=nginx stable repo
baseurl=http://nginx.org/packages/centos/\$releasever/\$basearch/
gpgcheck=1
enabled=1
gpgkey=https://nginx.org/keys/nginx_signing.key
EOF

yum install -y nginx
rm -rf /etc/nginx/conf.d/default.conf
systemctl enable nginx

cat >/etc/nginx/conf.d/jumpserver.conf << EOF
server {
    listen 80;  # 代理端口, 以后将通过此端口进行访问, 不再通过8080端口
    # server_name demo.jumpserver.org;  # 修改成你的域名或者注释掉

    client_max_body_size 100m;  # 录像及文件上传大小限制

    location /luna/ {
        try_files \$uri / /index.html;
        alias /opt/luna/;  # luna 路径, 如果修改安装目录, 此处需要修改
    }

    location /media/ {
        add_header Content-Encoding gzip;
        root /opt/jumpserver/data/;  # 录像位置, 如果修改安装目录, 此处需要修改
    }

    location /static/ {
        root /opt/jumpserver/data/;  # 静态资源, 如果修改安装目录, 此处需要修改
    }

    location /socket.io/ {
        proxy_pass       http://localhost:5000/socket.io/;  # 如果coco安装在别的服务器, 请填写它的ip
        proxy_buffering off;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        access_log off;
    }

    location /coco/ {
        proxy_pass       http://localhost:5000/coco/;  # 如果coco安装在别的服务器, 请填写它的ip
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        access_log off;
    }

    location /guacamole/ {
        proxy_pass       http://localhost:8081/;  # 如果guacamole安装在别的服务器, 请填写它的ip
        proxy_buffering off;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$http_connection;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        access_log off;
    }

    location / {
        proxy_pass http://localhost:8080;  # 如果jumpserver安装在别的服务器, 请填写它的ip
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
}
EOF

systemctl start nginx
systemctl enable nginx

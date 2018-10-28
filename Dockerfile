# Pgpool2.

FROM alpine:3.5
ENV PGPOOL_VERSION 3.6.1
ENV PG_VERSION 9.6.10-r0
ENV LANG en_US.utf8

RUN set -ex && \
	echo 'http://mirrors.ustc.edu.cn/alpine/v3.5/main' > /etc/apk/repositories && \
	echo 'http://mirrors.ustc.edu.cn/alpine/v3.5/community' >>/etc/apk/repositories && \
	apk add -U tzdata && \
	ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
	echo "Asia/Shanghai" > /etc/timezone && \
	apk add --update --progress libpq postgresql-dev=${PG_VERSION} postgresql-client=${PG_VERSION} \
                                linux-headers gcc make libgcc g++ \
                                libffi-dev python python-dev libffi-dev && \
	apk --update --no-cache add ca-certificates openssl && \
	# centos中安装 pip https://blog.csdn.net/songyu0120/article/details/46804989
	wget -O get-pip.py 'https://bootstrap.pypa.io/get-pip.py' --no-check-certificate && \	
	python get-pip.py  && \
	pip install --no-cache-dir --upgrade --ignore-installed pip && \
	pip --version && \
	pip install Jinja2 && \
	#下载 gosu - https://www.jianshu.com/p/eb9bd494105c
	wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/1.7/gosu-amd64" --no-check-certificate && \
	chmod +x /usr/local/bin/gosu && \
	gosu nobody true
	
RUN mkdir -p /tmp && \
	cd /tmp && \
    wget http://www.pgpool.net/mediawiki/images/pgpool-II-${PGPOOL_VERSION}.tar.gz -O - | tar -xz && \
    chown root:root -R /tmp/pgpool-II-${PGPOOL_VERSION} && \
    cd /tmp/pgpool-II-${PGPOOL_VERSION} && \
    ./configure --prefix=/usr \
                --sysconfdir=/etc/pgpool2 \
                --mandir=/usr/share/man \
                --infodir=/usr/share/info && \
    make && \
    make install && \
    rm -rf /tmp/pgpool-II-${PGPOOL_VERSION} && \
    apk del postgresql-dev linux-headers gcc make libgcc g++ && \	
	mkdir -p /etc/pgpool2 /var/run/pgpool /var/log/pgpool /var/run/postgresql /var/log/postgresql/&& \
    chown postgres /etc/pgpool2 /var/run/pgpool /var/log/pgpool /var/run/postgresql /var/log/postgresql
	

# Post Install Configuration.
ADD bin/configure-pgpool2 /usr/bin/configure-pgpool2
RUN chmod +x /usr/bin/configure-pgpool2

ADD conf/pcp.conf.template /usr/share/pgpool2/pcp.conf.template
ADD conf/pgpool.conf.template /usr/share/pgpool2/pgpool.conf.template
ADD conf/pool_hba.conf /etc/pgpool2/pool_hba.conf
ADD conf/pool_passwd /etc/pgpool2/pool_passwd

# Start the container.
COPY docker-entrypoint.sh /
RUN chmod +x /docker-entrypoint.sh
ENTRYPOINT ["/docker-entrypoint.sh"]

VOLUME /etc/pgpool2

EXPOSE 9999 9898
WORKDIR /etc/pgpool2

CMD ["pgpool","-n", "-f", "/etc/pgpool2/pgpool.conf", "-F", "/etc/pgpool2/pcp.conf", "-a", "/etc/pgpool2/pool_hba.conf"]

## ****************************** 参考资料 *****************************************
## 制作Docker Image: docker build -t idu/pgpool:1.0 .
## 测试alpine:3.5: docker run -a stdin -a stdout -i -t alpine:3.5 /bin/sh
## docker run --name pgpool2 -e PGPOOL_BACKENDS=1:172.17.0.3:5432,2:172.17.0.4:5432 -e PCP_USER=odoo -e PCP_USER_PASSWORD=odoo -p 9999:9999/tcp -p 9898:9898/tcp -p 5432:5432/tcp idu/pgpool:1.0


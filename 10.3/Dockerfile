FROM alpine:3.10

# add our user and group first to make sure their IDs get assigned consistently, regardless of whatever dependencies get added
RUN addgroup -S mysql && adduser -S mysql mysql

# add gosu for easy step-down from root
# https://github.com/tianon/gosu/releases
ENV GOSU_VERSION 1.12

RUN set -ex; \
	apk add --no-cache --virtual .build-deps ca-certificates wget; \
	dpkgArch=$(uname -m); \
	if [ "$dpkgArch" == "armv7l"  ]; then dpkgArch="armhf"; fi; \
	if [ "$dpkgArch" == "aarch64" ]; then dpkgArch="arm64"; fi; \
	if [ "$dpkgArch" == "x86_64"  ]; then dpkgArch="amd64"; fi; \
	wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch"; \
	apk del .build-deps; \
	chmod +x /usr/local/bin/gosu; \
	gosu --version; \
	gosu nobody true

RUN mkdir /docker-entrypoint-initdb.d

# install "pwgen" for randomizing passwords
# install "tzdata" for /usr/share/zoneinfo/
# install "xz-utils" for .sql.xz docker-entrypoint-initdb.d files
RUN set -ex; \
	apk add --no-cache \
		pwgen \
		tzdata \
		bash \
		coreutils \ 
		xz \
	;

# architectures: aarch64 armhf x86_64
ENV MARIADB_MAJOR 10.3
ENV MARIADB_VERSION 10.3.29-r0


# the "/var/lib/mysql" stuff here is because the mysql-server postinst doesn't have an explicit way to disable the mysql_install_db codepath besides having a database already "configured" (ie, stuff in /var/lib/mysql/mysql)
# also, we set debconf keys to make APT a little quieter
RUN set -ex; \
	apk add --no-cache \
		"mariadb=$MARIADB_VERSION" \
		"mariadb-client=$MARIADB_VERSION" \
# mariadb-backup is installed at the same time so that `mysql-common` is only installed once from just mariadb repos
		mariadb-backup \
		socat; \
# my alpine fixes
	ln -sf /usr/share/mariadb /usr/share/mysql; \
	if [ -f /etc/my.cnf ]; then  mv /etc/my.cnf /etc/my.cnf.orig; fi;

COPY ./etc /etc

RUN set -ex; \
# my alpine fixes
	ln -sf /etc/mysql/my.cnf /etc/my.cnf; \
# purge and re-create /var/lib/mysql with appropriate ownership
	rm -rf /var/lib/mysql; \
	mkdir -p /var/lib/mysql /var/run/mysqld; \
	chown -R mysql:mysql /var/lib/mysql /var/run/mysqld; \
# ensure that /var/run/mysqld (used for socket and lock files) is writable regardless of the UID our mysqld instance ends up having at runtime
	chmod 777 /var/run/mysqld; \
# comment out a few problematic configuration values
	find /etc/mysql/ -name '*.cnf' -print0 \
		| xargs -0 grep -lE '^(bind-address|log|user\s)' \
		| xargs -rt sed -Ei 's/^(bind-address|log|user\s)/#&/'; \
# don't reverse lookup hostnames, they are usually another container
	echo '[mysqld]\nskip-host-cache\nskip-name-resolve' > /etc/mysql/conf.d/docker.cnf

VOLUME /var/lib/mysql

COPY docker-entrypoint.sh /usr/local/bin/
RUN ln -s usr/local/bin/docker-entrypoint.sh / # backwards compat
ENTRYPOINT ["docker-entrypoint.sh"]

EXPOSE 3306
CMD ["mysqld"]

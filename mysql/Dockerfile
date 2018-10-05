FROM ubuntu:16.04

ENV DEBIAN_FRONTEND=noninteractive

RUN cd /tmp && \
	apt-get update && \
	apt-get install -y curl dbus lsb-core wget && \
	service dbus start

ADD build.sh /build.sh
RUN bash /build.sh

VOLUME ["/var/lib/mysql"]
 
EXPOSE 3306

WORKDIR /var/run/mysqld

ENV MYSQL_ALLOW_EMPTY_PASSWORD=true

ADD initfile /initfile
ADD provision.sh /provision.sh
RUN bash /provision.sh

USER mysql
CMD ["mysqld"]

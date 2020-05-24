
####################################################################################
# rtmp
####################################################################################

FROM debian:latest
EXPOSE 1935

# update packages and install required ones
RUN apt update && apt upgrade -y && apt install -y --no-install-recommends \
  build-essential \ 
  libpcre3 \ 
  libpcre3-dev \
  zlib1g \
  zlib1g-dev \
  libssl-dev \
  curl \
  wget \
  dnsutils \
  unzip \
  jq \
  ca-certificates \
  valgrind \
  && apt autoclean -y \
  && apt autoremove -y \
  && rm -rf /var/lib/apt/lists/* 


####################################################################################

# ulimit increase (set in docker templats/aws ecs-task-definition too!!)
RUN bash -c 'echo "root hard nofile 16384" >> /etc/security/limits.conf' \
 && bash -c 'echo "root soft nofile 16384" >> /etc/security/limits.conf' \
 && bash -c 'echo "* hard nofile 16384" >> /etc/security/limits.conf' \
 && bash -c 'echo "* soft nofile 16384" >> /etc/security/limits.conf'

# ip/tcp tweaks, disable ipv6
RUN bash -c 'echo "net.core.somaxconn = 8192" >> /etc/sysctl.conf' \
 && bash -c 'echo "net.ipv4.tcp_max_tw_buckets = 1440000" >> /etc/sysctl.conf' \
 && bash -c 'echo "net.ipv6.conf.all.disable_ipv6 = 1" >> /etc/sysctl.conf' \ 
 && bash -c 'echo "net.ipv4.ip_local_port_range = 5000 65000" >> /etc/sysctl.conf' \
 && bash -c 'echo "net.ipv4.tcp_fin_timeout = 15" >> /etc/sysctl.conf' \
 && bash -c 'echo "net.ipv4.tcp_window_scaling = 1" >> /etc/sysctl.conf' \
 && bash -c 'echo "net.ipv4.tcp_syncookies = 1" >> /etc/sysctl.conf' \
 && bash -c 'echo "net.ipv4.tcp_max_syn_backlog = 8192" >> /etc/sysctl.conf' \
 && bash -c 'echo "fs.file-max=65536" >> /etc/sysctl.conf'

####################################################################################
WORKDIR /app/rtmp-server
RUN wget https://nginx.org/download/nginx-1.18.0.tar.gz
RUN wget https://github.com/sfproductlabs/nginx-rtmp-module/archive/dev.zip
RUN tar -zxvf nginx-1.18.0.tar.gz
RUN unzip dev.zip
RUN bash -c 'cd nginx-1.18.0; ./configure --with-http_ssl_module --add-module=../nginx-rtmp-module-dev && make && make install; cd ..;'

RUN echo "rtmp { \
        server { \
                listen 1935; \
                chunk_size 4096; \
                application live { \
                        live on; \
                        record off; \
                } \
        } \
    }" >> /usr/local/nginx/conf/nginx.conf 

####################################################################################


CMD /usr/local/nginx/sbin/nginx 


####################################################################################
# flv
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
  ffmpeg \
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
RUN wget https://github.com/sfproductlabs/nginx-http-flv-module/archive/master.zip
RUN tar -zxvf nginx-1.18.0.tar.gz
RUN unzip master.zip
RUN bash -c 'cd nginx-1.18.0; ./configure --with-http_ssl_module --add-module=../nginx-http-flv-module-master && make && make install; cd ..;'
RUN mkdir /tmp/hls && mkdir /tmp/dash

RUN echo " \
worker_processes  1; #should be 1 for Windows, for it doesn't support Unix domain socket \
#worker_processes  auto; #from versions 1.3.8 and 1.2.5 \
 \
#worker_cpu_affinity  0001 0010 0100 1000; #only available on FreeBSD and Linux \
#worker_cpu_affinity  auto; #from version 1.9.10 \
 \
error_log logs/error.log error; \
 \
#if the module is compiled as a dynamic module and features relevant \
#to RTMP are needed, the command below MUST be specified and MUST be \
#located before events directive, otherwise the module won't be loaded \
#or will be loaded unsuccessfully when NGINX is started \
 \
#load_module modules/ngx_http_flv_live_module.so; \
 \
events { \
    worker_connections  4096; \
} \
 \
http { \
    include       mime.types; \
    default_type  application/octet-stream; \
 \
    keepalive_timeout  65; \
 \
    server { \
        listen       80; \
 \
        location / { \
            root   /var/www; \
            index  index.html index.htm; \
        } \
 \
        error_page   500 502 503 504  /50x.html; \
        location = /50x.html { \
            root   html; \
        } \
 \
        location /live { \
            flv_live on; #open flv live streaming (subscribe) \
            chunked_transfer_encoding  on; #open 'Transfer-Encoding: chunked' response \
 \
            add_header 'Access-Control-Allow-Origin' '*'; #add additional HTTP header \
            add_header 'Access-Control-Allow-Credentials' 'true'; #add additional HTTP header \
        } \
 \
        location /hls { \
            types { \
                application/vnd.apple.mpegurl m3u8; \
                video/mp2t ts; \
            } \
 \
            root /tmp; \
            add_header 'Cache-Control' 'no-cache'; \
        } \
 \
        location /dash { \
            root /tmp; \
            add_header 'Cache-Control' 'no-cache'; \
        } \
 \
        location /stat { \
            #configuration of push & pull status \
 \
            rtmp_stat all; \
            rtmp_stat_stylesheet stat.xsl; \
        } \
 \
        location /stat.xsl { \
            root /var/www/rtmp; #specify in where stat.xsl located \
        } \
 \
        #if JSON style stat needed, no need to specify \
        #stat.xsl but a new directive rtmp_stat_format \
 \
        #location /stat { \
        #    rtmp_stat all; \
        #    rtmp_stat_format json; \
        #} \
 \
        location /control { \
            rtmp_control all; #configuration of control module of rtmp \
        } \
    } \
} \
 \
rtmp_auto_push on; \
rtmp_auto_push_reconnect 1s; \
rtmp_socket_dir /tmp; \
 \
rtmp { \
    out_queue           4096; \
    out_cork            8; \
    max_streams         128; \
    timeout             15s; \
    drop_idle_publisher 15s; \
 \
    log_interval 5s; #interval used by log module to log in access.log, it is very useful for debug \
    log_size     1m; #buffer size used by log module to log in access.log \
 \
    server { \
        listen 1935; \
        chunk_size 4096; \
        #server_name www.test.*; #for suffix wildcard matching of virtual host name \
 \
        application live { \
            live on; \
            gop_cache on; #open GOP cache for reducing the wating time for the first picture of video \
        } \
 \
        application hls { \
            live on; \
            hls on; \
            hls_path /tmp/hls; \
        } \
 \
        application dash { \
            live on; \
            dash on; \
            dash_path /tmp/dash; \
        } \
    } \
 \
} \
" >> /usr/local/nginx/conf/nginx.conf 

####################################################################################


CMD ["/usr/local/nginx/sbin/nginx", "-g", "daemon off;"]


####################################################################################
# flv
####################################################################################

FROM debian:latest
EXPOSE 1935 80

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
RUN bash -c 'echo "root hard nofile 1048575" >> /etc/security/limits.conf' \
 && bash -c 'echo "root soft nofile 1048575" >> /etc/security/limits.conf' \
 && bash -c 'echo "* hard nofile 1048575" >> /etc/security/limits.conf' \
 && bash -c 'echo "* soft nofile 1048575" >> /etc/security/limits.conf' \
 && bash -c 'echo "net.core.somaxconn = 1440000" >> /etc/sysctl.conf'

####################################################################################
WORKDIR /app/rtmp-server
RUN wget https://nginx.org/download/nginx-1.18.0.tar.gz
RUN wget https://github.com/sfproductlabs/nginx-http-flv-module/archive/master.zip
RUN tar -zxvf nginx-1.18.0.tar.gz
RUN unzip master.zip
RUN bash -c 'cd nginx-1.18.0; ./configure --with-http_ssl_module --add-module=../nginx-http-flv-module-master && make && make install; cd ..;'
RUN mkdir /tmp/hls && mkdir /tmp/dash

RUN printf " \n \
worker_processes  1; #should be 1 for Windows, for it doesn't support Unix domain socket \n \
#worker_processes  auto; #from versions 1.3.8 and 1.2.5 \n \
 \n \
#worker_cpu_affinity  0001 0010 0100 1000; #only available on FreeBSD and Linux \n \
#worker_cpu_affinity  auto; #from version 1.9.10 \n \
 \n \
error_log logs/error.log error; \n \
 \n \
#if the module is compiled as a dynamic module and features relevant \n \
#to RTMP are needed, the command below MUST be specified and MUST be \n \
#located before events directive, otherwise the module won't be loaded \n \
#or will be loaded unsuccessfully when NGINX is started \n \
 \n \
#load_module modules/ngx_http_flv_live_module.so; \n \
 \n \
events { \n \
    worker_connections  4096; \n \
} \n \
 \n \
http { \n \
    include       mime.types; \n \
    default_type  application/octet-stream; \n \
 \n \
    keepalive_timeout  65; \n \
 \n \
    server { \n \
        listen       80; \n \
 \n \
        location / { \n \
            root   /var/www; \n \
            index  index.html index.htm; \n \
        } \n \
 \n \
        error_page   500 502 503 504  /50x.html; \n \
        location = /50x.html { \n \
            root   html; \n \
        } \n \
 \n \
        location /live { \n \
            flv_live on; #open flv live streaming (subscribe) \n \
            chunked_transfer_encoding  on; #open 'Transfer-Encoding: chunked' response \n \
 \n \
            add_header 'Access-Control-Allow-Origin' '*'; #add additional HTTP header \n \
            add_header 'Access-Control-Allow-Credentials' 'true'; #add additional HTTP header \n \
        } \n \
 \n \
        location /hls { \n \
            types { \n \
                application/vnd.apple.mpegurl m3u8; \n \
                video/mp2t ts; \n \
            } \n \
 \n \
            root /tmp; \n \
            add_header 'Cache-Control' 'no-cache'; \n \
        } \n \
 \n \
        location /dash { \n \
            root /tmp; \n \
            add_header 'Cache-Control' 'no-cache'; \n \
        } \n \
 \n \
        location /stat { \n \
            #configuration of push & pull status \n \
 \n \
            rtmp_stat all; \n \
            rtmp_stat_stylesheet stat.xsl; \n \
        } \n \
 \n \
        location /stat.xsl { \n \
            root /var/www/rtmp; #specify in where stat.xsl located \n \
        } \n \
 \n \
        #if JSON style stat needed, no need to specify \n \
        #stat.xsl but a new directive rtmp_stat_format \n \
 \n \
        #location /stat { \n \
        #    rtmp_stat all; \n \
        #    rtmp_stat_format json; \n \
        #} \n \
 \n \
        location /control { \n \
            rtmp_control all; #configuration of control module of rtmp \n \
        } \n \
    } \n \
} \n \
 \n \
rtmp_auto_push on; \n \
rtmp_auto_push_reconnect 1s; \n \
rtmp_socket_dir /tmp; \n \
 \n \
rtmp { \n \
    out_queue           4096; \n \
    out_cork            8; \n \
    max_streams         128; \n \
    timeout             15s; \n \
    drop_idle_publisher 15s; \n \
 \n \
    log_interval 5s; #interval used by log module to log in access.log, it is very useful for debug \n \
    log_size     1m; #buffer size used by log module to log in access.log \n \
 \n \
    server { \n \
        listen 1935; \n \
        chunk_size 4096; \n \
        #server_name www.test.*; #for suffix wildcard matching of virtual host name \n \
 \n \
        application live { \n \
            live on; \n \
            gop_cache on; #open GOP cache for reducing the wating time for the first picture of video \n \
        } \n \
 \n \
        application hls { \n \
            live on; \n \
            hls on; \n \
            hls_path /tmp/hls; \n \
        } \n \
 \n \
        application dash { \n \
            live on; \n \
            dash on; \n \
            dash_path /tmp/dash; \n \
        } \n \
    } \n \
 \n \
}" > /usr/local/nginx/conf/nginx.conf 

####################################################################################


CMD ["/usr/local/nginx/sbin/nginx", "-g", "daemon off;"]

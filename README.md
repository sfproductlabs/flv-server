# FLV Server
Run it from dockerhub:
```
sudo docker run -it -p 1935:1935 sfproductlabs/flv-server
```
Or build it using ```#build.sh```

## Install dependencies
### Docker (debian)
```
sudo apt-get update && \
sudo apt-get upgrade -y && \
sudo apt-get install apt-transport-https ca-certificates curl gnupg-agent software-properties-common -y && \
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo apt-key add - && \
sudo apt-key fingerprint 0EBFCD88 && \
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/debian $(lsb_release -cs) stable" && \
sudo apt-get update && \
sudo apt-get install docker-ce docker-ce-cli containerd.io ansible -y
```

#!/bin/bash
cat ~/.DH_TOKEN | sudo docker login --username sfproductlabs --password-stdin
sudo docker tag $(sudo docker images -q | head -1) sfproductlabs/flv-server:latest
sudo docker push sfproductlabs/flv-server:latest
#!/bin/bash

cat <<EOF >.findings.sh
#!/bin/bash

curl --silent --location -O https://secure.eicar.org/eicar.com
sudo chmod 666 /etc/passwd
echo "huhu" > /tmp/huhu.txt
sudo mv /tmp/huhu.txt /etc
EOF

scp -i frankfurt-region-key-pair -o StrictHostKeyChecking=no .findings.sh ubuntu@$(terraform output -raw public_instance_ip):

ssh -i frankfurt-region-key-pair -o StrictHostKeyChecking=no ubuntu@$(terraform output -raw public_instance_ip) \
  'chmod +x ./.findings.sh && ./.findings.sh'

rm .findings.sh
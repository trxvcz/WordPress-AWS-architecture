#!/bin/bash
sudo yum update -y
sudo yum install -y amazon-efs-utils
mkdir -p /var/www/html
# Montowanie systemu plików EFS
mount -t efs -o tls ${efs_id}:/ /var/www/html
# Zapewnienie uprawnień dla webserwera (np. apache/nginx)
chown -R ec2-user:ec2-user /var/www/html
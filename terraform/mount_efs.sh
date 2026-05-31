#!/bin/bash

# 1. Aktualizacja systemu
sudo yum update -y

# 2. Instalacja serwera WWW (Apache), PHP 8.2 oraz narzędzi EFS
sudo yum install -y httpd wget php-fpm php-mysqli php-json php php-devel amazon-efs-utils

# 3. Przygotowanie katalogu i montowanie EFS
mkdir -p /var/www/html
mount -t efs -o tls ${efs_id}:/ /var/www/html

# Dodanie EFS do fstab, aby montował się automatycznie po restarcie instancji
echo "${efs_id}:/ /var/www/html efs _netdev,noresvport,tls,iam 0 0" >> /etc/fstab

# 4. Pobieranie i rozpakowywanie WordPressa (tylko jeśli EFS jest pusty)
if [ ! -f /var/www/html/wp-config-sample.php ]; then
    cd /tmp
    wget https://wordpress.org/latest.tar.gz
    tar -xzf latest.tar.gz
    sudo cp -r wordpress/* /var/www/html/
fi

# 5. Nadanie odpowiednich uprawnień dla serwera Apache
sudo chown -R apache:apache /var/www/html
sudo chmod -R 755 /var/www/html

# 6. Uruchomienie serwera WWW
sudo systemctl start httpd
sudo systemctl enable httpd
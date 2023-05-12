#! /bin/bash
sudo yum install -y httpd
sudo systemctl enable --now httpd
systemctl start httpd
sudo chmod 777 /var/www/html/index.html
echo "<h1>Servidor de apache</h1>" > /var/www/html/index.html
sudo systemctl restart http.service
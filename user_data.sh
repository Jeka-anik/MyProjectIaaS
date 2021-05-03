#!/bin/bash
apt-get -y update
apt-get -y install nginx


myip=`curl http://169.254.169.254/latest/meta-data/local-ipv4`

cat <<EOF > /usr/share/nginx/html/index.html
<html>
<body bgcolor="black">
<h2><font color="gold">Build by Power of Terraform <font color="red"> v0.14</font></h2><br><p>
<font color="green">Server PrivateIP: <font color="aqua">$myip<br><br>
<font color="magenta">
<b>Version 1.0</b>
</body>
</html>
EOF

systemctl restart nginx

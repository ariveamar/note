#!/bin/bash
echo "START SETUP DB"
systemctl disable firewalld --now
setenforce 0
sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
dnf module -y install postgresql:15
dnf install postgresql-contrib -y
postgresql-setup --initdb
systemctl enable --now postgresql
sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" /var/lib/pgsql/data/postgresql.conf ;
echo "host all all all md5" >> /var/lib/pgsql/data/pg_hba.conf ;
systemctl restart postgresql
sudo -u postgres psql -c "CREATE DATABASE mattermost WITH ENCODING 'UTF8' LC_COLLATE='en_US.UTF-8' LC_CTYPE='en_US.UTF-8' TEMPLATE=template0;"
sudo -u postgres psql -c "CREATE USER mmuser WITH PASSWORD 'mmuser-password';"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE mattermost to mmuser;"
sudo -u postgres psql -c "ALTER DATABASE mattermost OWNER TO mmuser;"
sudo -u postgres psql -c "ALTER SCHEMA public OWNER TO mmuser;"
sudo -u postgres psql -c "GRANT USAGE, CREATE ON SCHEMA public TO mmuser;"

echo " END SETUP DB"
echo "START SETUP MATTERMOST"
tar -xvf  mattermost-10.9.1-linux-amd64.tar.gz
sudo mv mattermost /opt
sudo mkdir /opt/mattermost/data
sudo useradd --system --user-group mattermost
sudo chown -R mattermost:mattermost /opt/mattermost
sudo chmod -R g+w /opt/mattermost
cat << EOF > /lib/systemd/system/mattermost.service
[Unit]
Description=Mattermost
After=network.target
After=postgresql.service
BindsTo=postgresql.service

[Service]
Type=notify
ExecStart=/opt/mattermost/bin/mattermost
TimeoutStartSec=3600
KillMode=mixed
Restart=always
RestartSec=10
WorkingDirectory=/opt/mattermost
User=mattermost
Group=mattermost
LimitNOFILE=49152

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo cp /opt/mattermost/config/config.json /opt/mattermost/config/config.defaults.json
sed -i 's/mostest/mmuser-password/g' /opt/mattermost/config/config.json
sed -i 's/ mattermost_test/mattermost/g' /opt/mattermost/config/config.json
systemctl enable  mattermost --now
echo "END SETUP MM"


echo "SETUP NGINX"
sudo touch /etc/nginx/conf.d/mattermost
sudo rm /etc/nginx/conf.d/default
ln -s /etc/nginx/conf.d/mattermost /etc/nginx/conf.d/default.conf
cat << EOF > /etc/nginx/conf.d/mattermost
upstream backend {
   server 127.0.0.1:8065;
   keepalive 32;
}

server {
  listen 80 default_server;
  server_name   mm-ivt.ddns.my.id;
  return 301 https://$server_name$request_uri;
}

server {
   listen 443 ssl http2;
#  listen [::]:443 ssl http2;
   server_name    mm-ivt.ddns.my.id;

   ssl_certificate /etc/letsencrypt/live/mm-ivt.ddns.my.id/fullchain.pem;
   ssl_certificate_key /etc/letsencrypt/live/mm-ivt.ddns.my.id/privkey.pem;
   ssl_session_timeout 1d;

   # Enable TLS versions (TLSv1.3 is required upcoming HTTP/3 QUIC).
   ssl_protocols TLSv1.2 TLSv1.3;

   # Enable TLSv1.3's 0-RTT. Use $ssl_early_data when reverse proxying to
   # prevent replay attacks.
   #
   # @see: https://nginx.org/en/docs/http/ngx_http_ssl_module.html#ssl_early_data
   ssl_early_data on;

   ssl_ciphers 'ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA384';
   ssl_prefer_server_ciphers on;
   ssl_session_cache shared:SSL:50m;
   # HSTS (ngx_http_headers_module is required) (15768000 seconds = six months)
   add_header Strict-Transport-Security max-age=15768000;
   # OCSP Stapling ---
   # fetch OCSP records from URL in ssl_certificate and cache them
   ssl_stapling on;
   ssl_stapling_verify on;

   add_header X-Early-Data $tls1_3_early_data;

   location ~ /api/v[0-9]+/(users/)?websocket$ {
       proxy_set_header Upgrade $http_upgrade;
       proxy_set_header Connection "upgrade";
       client_max_body_size 50M;
       proxy_set_header Host $host;
       proxy_set_header X-Real-IP $remote_addr;
       proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
       proxy_set_header X-Forwarded-Proto $scheme;
       proxy_set_header X-Frame-Options SAMEORIGIN;
       proxy_buffers 256 16k;
       proxy_buffer_size 16k;
       client_body_timeout 60s;
       send_timeout 300s;
       lingering_timeout 5s;
       proxy_connect_timeout 90s;
       proxy_send_timeout 300s;
       proxy_read_timeout 90s;
       proxy_http_version 1.1;
       proxy_pass http://backend;
   }

   location / {
       client_max_body_size 100M;
       proxy_set_header Connection "";
       proxy_set_header Host $host;
       proxy_set_header X-Real-IP $remote_addr;
       proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
       proxy_set_header X-Forwarded-Proto $scheme;
       proxy_set_header X-Frame-Options SAMEORIGIN;
       proxy_buffers 256 16k;
       proxy_buffer_size 16k;
       proxy_read_timeout 600s;
       proxy_http_version 1.1;
       proxy_pass http://backend;
   }
}

# This block is useful for debugging TLS v1.3. Please feel free to remove this
# and use the `$ssl_early_data` variable exposed by NGINX directly should you
# wish to do so.
map $ssl_early_data $tls1_3_early_data {
  "~." $ssl_early_data;
  default "";
}
EOF



cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.backup
cat << EOF > /etc/nginx/nginx.conf
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;

# Load dynamic modules. See /usr/share/doc/nginx/README.dynamic.
include /usr/share/nginx/modules/*.conf;

events {
    worker_connections 1024;
}

http {
    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;

    sendfile            on;
    tcp_nopush          on;
    tcp_nodelay         on;
    keepalive_timeout   65;
    types_hash_max_size 4096;

    include             /etc/nginx/mime.types;
    default_type        application/octet-stream;

    # Load modular configuration files from the /etc/nginx/conf.d directory.
    # See http://nginx.org/en/docs/ngx_core_module.html#include
    # for more information.
    include /etc/nginx/conf.d/*.conf;
}
EOF

mkdir -p /etc/letsencrypt/live/mm-ivt.ddns.my.id/

cat << EOF > /etc/letsencrypt/live/mm-ivt.ddns.my.id/fullchain.pem
-----BEGIN CERTIFICATE-----
MIIDjzCCAxWgAwIBAgISBU+UOU2VV8jdpMh6KaJYd+emMAoGCCqGSM49BAMDMDIx
CzAJBgNVBAYTAlVTMRYwFAYDVQQKEw1MZXQncyBFbmNyeXB0MQswCQYDVQQDEwJF
NTAeFw0yNTA2MjUwNjI3NDlaFw0yNTA5MjMwNjI3NDhaMBwxGjAYBgNVBAMTEW1t
LWl2dC5kZG5zLm15LmlkMFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEHN0gKtYQ
icSJyHKncYJmcdd4zLL8wCLMctfaWFhTIsXyfvZDit07Dky7t+tRtVlzczb4t91J
YaBTjiEn2KpGM6OCAh8wggIbMA4GA1UdDwEB/wQEAwIHgDAdBgNVHSUEFjAUBggr
BgEFBQcDAQYIKwYBBQUHAwIwDAYDVR0TAQH/BAIwADAdBgNVHQ4EFgQU7Ri579qe
1Ns91Cda8nfcMlRdUGYwHwYDVR0jBBgwFoAUnytfzzwhT50Et+0rLMTGcIvS1w0w
MgYIKwYBBQUHAQEEJjAkMCIGCCsGAQUFBzAChhZodHRwOi8vZTUuaS5sZW5jci5v
cmcvMBwGA1UdEQQVMBOCEW1tLWl2dC5kZG5zLm15LmlkMBMGA1UdIAQMMAowCAYG
Z4EMAQIBMC0GA1UdHwQmMCQwIqAgoB6GHGh0dHA6Ly9lNS5jLmxlbmNyLm9yZy8z
OS5jcmwwggEEBgorBgEEAdZ5AgQCBIH1BIHyAPAAdgDtPEvW6AbCpKIAV9vLJOI4
Ad9RL+3EhsVwDyDdtz4/4AAAAZel+wGfAAAEAwBHMEUCIQDP8KQaa8sJ8g7sIf/p
kW5+OQMgRYrZQelat+zVxZ3x4gIgLJcaKw+ISsw0f2E4Ds4eiHiFWx/FpJI/0ZTM
xSa6mb0AdgCvGBoo1oyj4KmKTJxnqwn4u7wiuq68sTijoZ3T+bYDDQAAAZel+wKu
AAAEAwBHMEUCIQC8jeyRNAwoa84YcKZwF4ckV7i8NnuW5qnPmYc5acPbBgIgeN3R
MnryGGSubXI8jsF6wt9LYRS7RkpfLtijfPTUXpUwCgYIKoZIzj0EAwMDaAAwZQIx
ANp+99SssscmWI5ht7qldILuNshViARg/buI6eQ/vEWj7/XULEUaHSc4h84YG5tS
SwIwGjFnTtBtsYa0W2uJGtCvKts+HHOByBr8DHqM+uAjNU4HTyl3+30NqRox13WA
nY69
-----END CERTIFICATE-----
-----BEGIN CERTIFICATE-----
MIIEVzCCAj+gAwIBAgIRAIOPbGPOsTmMYgZigxXJ/d4wDQYJKoZIhvcNAQELBQAw
TzELMAkGA1UEBhMCVVMxKTAnBgNVBAoTIEludGVybmV0IFNlY3VyaXR5IFJlc2Vh
cmNoIEdyb3VwMRUwEwYDVQQDEwxJU1JHIFJvb3QgWDEwHhcNMjQwMzEzMDAwMDAw
WhcNMjcwMzEyMjM1OTU5WjAyMQswCQYDVQQGEwJVUzEWMBQGA1UEChMNTGV0J3Mg
RW5jcnlwdDELMAkGA1UEAxMCRTUwdjAQBgcqhkjOPQIBBgUrgQQAIgNiAAQNCzqK
a2GOtu/cX1jnxkJFVKtj9mZhSAouWXW0gQI3ULc/FnncmOyhKJdyIBwsz9V8UiBO
VHhbhBRrwJCuhezAUUE8Wod/Bk3U/mDR+mwt4X2VEIiiCFQPmRpM5uoKrNijgfgw
gfUwDgYDVR0PAQH/BAQDAgGGMB0GA1UdJQQWMBQGCCsGAQUFBwMCBggrBgEFBQcD
ATASBgNVHRMBAf8ECDAGAQH/AgEAMB0GA1UdDgQWBBSfK1/PPCFPnQS37SssxMZw
i9LXDTAfBgNVHSMEGDAWgBR5tFnme7bl5AFzgAiIyBpY9umbbjAyBggrBgEFBQcB
AQQmMCQwIgYIKwYBBQUHMAKGFmh0dHA6Ly94MS5pLmxlbmNyLm9yZy8wEwYDVR0g
BAwwCjAIBgZngQwBAgEwJwYDVR0fBCAwHjAcoBqgGIYWaHR0cDovL3gxLmMubGVu
Y3Iub3JnLzANBgkqhkiG9w0BAQsFAAOCAgEAH3KdNEVCQdqk0LKyuNImTKdRJY1C
2uw2SJajuhqkyGPY8C+zzsufZ+mgnhnq1A2KVQOSykOEnUbx1cy637rBAihx97r+
bcwbZM6sTDIaEriR/PLk6LKs9Be0uoVxgOKDcpG9svD33J+G9Lcfv1K9luDmSTgG
6XNFIN5vfI5gs/lMPyojEMdIzK9blcl2/1vKxO8WGCcjvsQ1nJ/Pwt8LQZBfOFyV
XP8ubAp/au3dc4EKWG9MO5zcx1qT9+NXRGdVWxGvmBFRAajciMfXME1ZuGmk3/GO
koAM7ZkjZmleyokP1LGzmfJcUd9s7eeu1/9/eg5XlXd/55GtYjAM+C4DG5i7eaNq
cm2F+yxYIPt6cbbtYVNJCGfHWqHEQ4FYStUyFnv8sjyqU8ypgZaNJ9aVcWSICLOI
E1/Qv/7oKsnZCWJ926wU6RqG1OYPGOi1zuABhLw61cuPVDT28nQS/e6z95cJXq0e
K1BcaJ6fJZsmbjRgD5p3mvEf5vdQM7MCEvU0tHbsx2I5mHHJoABHb8KVBgWp/lcX
GWiWaeOyB7RP+OfDtvi2OsapxXiV7vNVs7fMlrRjY1joKaqmmycnBvAq14AEbtyL
sVfOS66B8apkeFX2NY4XPEYV4ZSCe8VHPrdrERk2wILG3T/EGmSIkCYVUMSnjmJd
VQD9F6Na/+zmXCc=
-----END CERTIFICATE-----
EOF

cat << EOF > /etc/letsencrypt/live/mm-ivt.ddns.my.id/privkey.pem
-----BEGIN EC PRIVATE KEY-----
MHcCAQEEIMwhTbThJFg3K8ueJ5TOxL0/00Q2J2H+uoQ1LxjptRIxoAoGCCqGSM49
AwEHoUQDQgAEHN0gKtYQicSJyHKncYJmcdd4zLL8wCLMctfaWFhTIsXyfvZDit07
Dky7t+tRtVlzczb4t91JYaBTjiEn2KpGMw==
-----END EC PRIVATE KEY-----
EOF

systemctl enable nginx --now


#!/bin/bash
dnf module -y install postgresql:15
dnf install postgresql-contrib -y
postgresql-setup --initdb
systemctl enable --now postgresql
sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" /var/lib/pgsql/data/postgresql.conf ;
echo "host      all    all    0.0.0.0/0 md5" >> /var/lib/pgsql/data/pg_hba.conf ;
sudo -u postgres  createuser automation;
sudo -u postgres  createdb automationhub -O automation ;
sudo -u postgres psql -c "ALTER ROLE automation WITH PASSWORD 'P4ssw0rdAAP';"


sudo -u postgres psql -d automationhub -c "CREATE EXTENSION hstore;"  ;
sudo -u postgres psql -c "ALTER ROLE automation WITH SUPERUSER;" ;
systemctl restart postgresql

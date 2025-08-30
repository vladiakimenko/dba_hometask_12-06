#!/bin/bash

mysql -u root -p"$MYSQL_ROOT_PASSWORD" sakila < /db_dump/sakila-schema.sql
mysql -u root -p"$MYSQL_ROOT_PASSWORD" sakila < /db_dump/sakila-data.sql

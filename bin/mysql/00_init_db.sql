DROP DATABASE IF EXISTS sakila;
DROP USER IF EXISTS 'sakila_user'@'%';

CREATE DATABASE sakila;
CREATE USER 'sakila_user'@'%' IDENTIFIED BY 'StrongPassword12345';

GRANT ALL PRIVILEGES ON sakila.* TO 'sakila_user'@'%';
FLUSH PRIVILEGES;

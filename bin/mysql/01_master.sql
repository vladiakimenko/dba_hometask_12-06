CREATE USER 'mysql_replica_user'@'%' IDENTIFIED BY 'StrongPassword12345';
GRANT REPLICATION SLAVE ON *.* TO 'mysql_replica_user'@'%';
FLUSH PRIVILEGES;

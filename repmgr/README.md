# Build the PostgreSQL replication cluster using repmgr

This `Vagrantfile` setup 3 machines (CentOS 7)

* db1 (master)
* db2 (standby, replica)
* client

Install PGDG reposiory, postgresql-9.5, repmgr.

Configure stream replication, repmgr, repmgrd.

## cluter show

```
$ repmgr -f /etc/repmgr/9.5/repmgr.conf cluster show
Role      | Name | Upstream | Connection String
----------+------|----------|------------------------------------------------------
* master  | db1  |          | host=db1 user=repmgr password=reppasswd dbname=repmgr
  standby | db2  | db1      | host=db2 user=repmgr password=reppasswd dbname=repmgr
```

```
repmgr=# select * from repl_nodes;
 id |  type   | upstream_node_id |  cluster  | name |                       conn
info                        | slot_name | priority | active
----+---------+------------------+-----------+------+---------------------------
----------------------------+-----------+----------+--------
  1 | master  |                  | mycluster | db1  | host=db1 user=repmgr passw
ord=reppasswd dbname=repmgr |           |      100 | t
  2 | standby |                1 | mycluster | db2  | host=db2 user=repmgr passw
ord=reppasswd dbname=repmgr |           |      100 | t
(2 rows)

repmgr=# select * from repl_events;
 node_id |      event       | successful |        event_timestamp        |      
                             details                                   
---------+------------------+------------+-------------------------------+------
-----------------------------------------------------------------------
       1 | master_register  | t          | 2016-09-27 23:21:19.532176+09 |
       1 | repmgrd_start    | t          | 2016-09-27 23:21:19.615855+09 |
       2 | standby_clone    | t          | 2016-09-27 23:23:52.959521+09 | Clone
d from host 'db1', port 5432; backup method: pg_basebackup; --force: N
       2 | standby_register | t          | 2016-09-27 23:23:55.19939+09  |
(4 rows)

repmgr=#
```

## promote

Run on standby server.

```
repmgr -f /etc/repmgr/9.5/repmgr.conf standby promote
```

## switch over

Run on standby server.  
This feature require pg_rewind.

```
repmgr -f /etc/repmgr/9.5/repmgr.conf standby switchover
```

## TODO

* Automated failover using repmgrd
* VIP support (follow master)

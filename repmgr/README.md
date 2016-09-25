# repmgr を使った構成のテスト

```
$ repmgr -f /etc/repmgr/9.5/repmgr.conf cluster show
Role      | Name | Upstream | Connection String
----------+------|----------|------------------------------------------------------
* master  | db1  |          | host=db1 user=repmgr password=reppasswd dbname=repmgr
  standby | db2  | db1      | host=db2 user=repmgr password=reppasswd dbname=repmgr
```

## promote

```
repmgr -f /etc/repmgr/9.5/repmgr.conf standby promote
```

## switch over

standby 側で実行する (pg_rewind が必要)

```
repmgr -f /etc/repmgr/9.5/repmgr.conf standby switchover
```

## TODO

* repmgrd での自動化
* VIP 対応

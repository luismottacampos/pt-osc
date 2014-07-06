## 0.1.1

- now compatible with versions 0.5.0 and later of [zdennis/activerecord-import](https://github.com/zdennis/activerecord-import)
- fixed `LoadError` in `ActiveRecord::PtOscMigration`

## 0.1.0

- renamed `PtOscAdapter` -> `MysqlPtOscAdapter` for better compatibility with Rails db Rake tasks.

## 0.0.5

- remove dependence on ActiveSupport/Rails
- can specify log file in `percona` config

## 0.0.4

- Make sure `active_record/migration` is `require`d

## 0.0.3

- `defaults-file` flag can be specified as either an absolute path (has a leading `/`) or a relative path.

## 0.0.2

- fixed bug when `percona` config is not defined in `database.yml`

## 0.0.1

- initial release

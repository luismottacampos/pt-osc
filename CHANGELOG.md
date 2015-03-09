## 0.2.4

- relaxed version requirements for bundler and activerecord-import

## 0.2.3

- a warning will be issued if an `ALTER` command is called outside of a PtOscMigration

## 0.2.2

- fix bugs with string quoting, use shellwords instead
- added integration tests for execution of pt-osc migrations
- support `user` and `password` flags in percona config
- pull `username` and `password` from database config when available

## 0.2.1

- properly quote string values in MySQL commands
- added additional tests

## 0.2.0

- support for setting the [`--check-alter` flag](http://www.percona.com/doc/percona-toolkit/2.1/pt-online-schema-change.html#cmdoption-pt-online-schema-change--%5Bno%5Dcheck-alter)
- internal improvements to the way `percona` options are handled
- removed support for Ruby 1.9.2

## 0.1.3

- fix for loading percona config
- added test coverage for loading run_mode from config

## 0.1.2

- report `adapter_name` as `mysql2` for compatibility with gems that check it (e.g. [mceachen/with_advisory_lock](https://github.com/mceachen/with_advisory_lock))

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

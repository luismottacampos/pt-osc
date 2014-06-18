[![Travis CI](https://travis-ci.org/steverice/pt-osc.svg)](https://travis-ci.org/steverice/pt-osc)
[![Code Climate](https://codeclimate.com/github/steverice/pt-osc.png)](https://codeclimate.com/github/steverice/pt-osc)
[![Code Coverage](https://codeclimate.com/github/steverice/pt-osc/coverage.png)](https://codeclimate.com/github/steverice/pt-osc)

## `pt-online-schema-change` migrations

Runs regular Rails/ActiveRecord migrations via the [Percona Toolkit pt-online-schema-change tool](http://www.percona.com/doc/percona-toolkit/2.1/pt-online-schema-change.html).

## Installation

Add this line to your application's Gemfile:

    gem 'pt-osc'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install pt-osc

## Usage

Set your database adapter to be `pt_osc` in your application's database.yml.
Specify `pt-online-schema-change` flags in a `percona` hash in the config.
e.g.
```yaml
environment:
  host: localhost
  username: root
  database: rails
  percona:
    defaults-file: /etc/mysql/percona-user.cnf
    recursion-method: "'dsn=D=percona,t=slaves'"
```

Additional options for the `percona` hash include:
  - `run_mode`: Specify `'execute'` to actually run `pt-online-schema-change` when the migration runs. Specify `'print'` to output the commands to run to STDOUT instead. Default is `'print'`.

## Caveats

This gem is not considered production ready. There will be bugs.
It is tested against:
- ActiveRecord 3.2 branch
  - Ruby 1.9.2
  - Ruby 2.0.0
  - Ruby 2.1.2

Support for other versions of Ruby or ActiveRecord is unknown and not guaranteed.

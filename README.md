[![Travis CI](https://travis-ci.org/steverice/pt-osc.svg)](https://travis-ci.org/steverice/pt-osc)
[![Code Climate](https://codeclimate.com/github/steverice/pt-osc.png)](https://codeclimate.com/github/steverice/pt-osc)
[![Code Coverage](https://codeclimate.com/github/steverice/pt-osc/coverage.png)](https://codeclimate.com/github/steverice/pt-osc)
[![Gem Version](https://badge.fury.io/rb/pt-osc.svg)](http://badge.fury.io/rb/pt-osc)

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

Set your database adapter to be `mysql_pt_osc` in your application's database.yml.
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

Additional/modified options for the `percona` hash include:
  - `defaults-file`: Can be specified as an absolute path (with leading `/`) or relative (without). Relative paths will be treated as relative to your project's working directory.
  - `run_mode`: Specify `'execute'` to actually run `pt-online-schema-change` when the migration runs. Specify `'print'` to output the commands to run to STDOUT instead. Default is `'print'`.
  - `log`: Specify the file used for logging activity. Can be a relative or absolute path.

#### Migrations

To run migrations with `pt-online-schema-change`, you need to explicitly opt them in by changing their parent class to `ActiveRecord::PtOscMigration`. For instance, if your migration was
```ruby
class CreateTeams < ActiveRecord::Migration
```
you should change it to
```ruby
class CreateTeams < ActiveRecord::PtOscMigration
```
If you have migrations that you do not want to be run with `pt-online-schema-change`, leave the same parent class and they will be run normally.

## Caveats

This gem is not considered production ready. There will be bugs.

##### Compatibility

`pt-osc` is tested against:
- ActiveRecord 3.2 branch
  - Ruby 1.9.2
  - Ruby 1.9.3
  - Ruby 2.0.0
  - Ruby 2.1.2
  - Ruby 2.1 latest

Support for other versions of Ruby or ActiveRecord is unknown and not guaranteed.

`pt-osc` is compatible with versions 0.5.0 and later of [zdennis/activerecord-import](https://github.com/zdennis/activerecord-import). It will not work with earlier versions.

#License and Copyright
Copyright (c) 2014, PagerDuty
All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

* Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

* Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

* Neither the name of [project] nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

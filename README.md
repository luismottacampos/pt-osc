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

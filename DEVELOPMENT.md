
# Development

## Prerequisites

* Ruby ([rbenv](https://github.com/rbenv/rbenv) will pick up the correct version from the `.ruby_version` file)
* Postgres

## Setup

Clone Git submodules:

```bash
git submodule init
git submodule update
```

Install dependencies:

```bash
bundle install
yarn install
```

Create required Postgres user:

```bash
psql postgres -c "CREATE ROLE registry_test WITH LOGIN SUPERUSER PASSWORD 'registry_test' CREATEDB;"
```

The user must be SUPERUSER for Rails fixtures to work.

Setup databases:

```bash
bin/rails db:create
bin/rails db:schema:load
```

Start Rails:

```bash
bin/rails server
```

## Restore a production dump

To replace the development database with a production SQL dump:

```bash
bin/rails db:drop db:create

gzip -dc ../registry-YYMMDD.sql.gz \
  | sed 's/OWNER TO registry;/OWNER TO registry_test;/g' \
  | bin/rails db

bin/rails db:migrate
```

The ownership replacement is needed because production objects belong to the
`registry` Postgres role, while development uses `registry_test`.

## Configuration

### External API's

External API's are disabled in development per default. Enable with `ALLOW_EXTERNAL_APIS=true bin/rails`.


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

## Tag curation

### Review `trait` accepted through `chemonym`

`chemonym` used to be a sub-tag of `trait`, so accepting it also accepted
`trait`. It is now stand-alone (run `bin/rails db:seed` to update the tag),
but the `trait` records accepted that way were kept. To list the names with
an accepted `trait` and `chemonym` but no accepted `phenonym`, run in
`bin/rails console`:

```ruby
accepted = NameTag.joins(:tag).where(status_int: NameTag.status.index(:accepted))
with = ->(slug) { accepted.where(tags: { slug: slug }).select(:name_id) }
Name.where(id: with['trait']).where(id: with['chemonym'])
    .where.not(id: with['phenonym']).includes(name_tags: :tag).order(:name)
    .each do |name|
      trait = name.name_tags.find { |nt| nt.tag.slug == 'trait' }
      how = trait.pre_cascade_status_int ? "via cascade (#{trait.notes})" : 'directly'
      puts "#{name.name}\t/names/#{name.id}\ttrait accepted #{how}"
    end
```

### Review names with several gender tags

Gender tags are mutually exclusive: accepting one removes the other gender
tags on the name, but records created before that rule may still overlap. To
list the names with more than one gender tag (of any status), run in
`bin/rails console`:

```ruby
genders = NameTag.joins(:tag).where(tags: { slug: Tag::GENDER_SLUGS })
ids = genders.group(:name_id).having('COUNT(*) > 1').select(:name_id)
Name.where(id: ids).includes(name_tags: :tag).order(:name).each do |name|
  tags = name.name_tags.select { |nt| nt.tag.gender? }
                       .map { |nt| "#{nt.tag.slug} (#{nt.status})" }
  puts "#{name.name}\t/names/#{name.id}\t#{tags.join(', ')}"
end
```

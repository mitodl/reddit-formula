{% set ENVIRONMENT = salt.grains.get('environment') %}
{% set reddit_oauth = salt.pillar.get('reddit:oauth_client') %}
{% set reddit_admin = salt.pillar.get('reddit:admin_user') %}
{% set pg_user = salt.pillar.get('reddit:ini_config:DEFAULT:db_user') %}
{% set pg_pass = salt.pillar.get('reddit:ini_config:DEFAULT:db_pass') %}

create_reddit_keyspace:
  cmd.script:
    - name: salt://reddit/files/setup_cassandra.py

create_postgresql_functions:
  module.run:
    - name: postgres.psql_query
    - query: |
        WITH functions AS (
            create or replace function hot(ups integer, downs integer, date timestamp with time zone) returns numeric as $$
            select round(cast(log(greatest(abs($1 - $2), 1)) * sign($1 - $2) + (date_part('epoch', $3) - 1134028003) / 45000.0 as numeric), 7)
            $$ language sql immutable;

            create or replace function score(ups integer, downs integer) returns integer as $$
            select $1 - $2
            $$ language sql immutable;

            create or replace function controversy(ups integer, downs integer) returns float as $$
            select CASE WHEN $1 <= 0 or $2 <= 0 THEN 0
            WHEN $1 > $2 THEN power($1 + $2, cast($2 as float) / $1)
            ELSE power($1 + $2, cast($1 as float) / $2)
            END;
            $$ language sql immutable;

            create or replace function ip_network(ip text) returns text as $$
            select substring($1 from E'[\d]+.[\d]+.[\d]+')
            $$ language sql immutable;

            create or replace function base_url(url text) returns text as $$
            select substring($1 from E'(?i)(?:.+?://)?(?:www[\d]*\.)?([^#]*[^#/])/?')
            $$ language sql immutable;

            create or replace function domain(url text) returns text as $$
            select substring($1 from E'(?i)(?:.+?://)?(?:www[\d]*\.)?([^#/]*)/?')
            $$ language sql immutable;
        ) SELECT * FROM functions;
    - host: postgresql.service.consul
    - user: {{ pg_user }}
    - password: {{ pg_pass }}
    - write: True
    - maintenance_db: reddit

seed_reddit_with_admin_and_client:
  file.managed:
    - name: /tmp/seed_reddit_auth.py
    - source: salt://reddit/templates/seed_reddit_auth.py
    - template: jinja
    - mode: 755
    - context:
        account_password: {{ reddit_admin.password }}
        oauth_client_id: {{ reddit_oauth.client_id }}
        oauth_client_secret: {{ reddit_oauth.client_secret }}
  cmd.run:
    - name: /usr/local/bin/reddit-run /tmp/seed_reddit_auth.py
    - require:
        - file: seed_reddit_with_admin_and_client
    - user: deploy

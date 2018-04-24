{% set ENVIRONMENT = salt.grains.get('environment') %}
{% set reddit_oauth = salt.pillar.get('reddit:oauth_client') %}
{% set reddit_admin = salt.pillar.get('reddit:admin_user') %}
{% set system_user = salt.pillar.get('reddit:system_user') %}
{% set pg_user = salt.pillar.get('reddit:ini_config:DEFAULT:db_user') %}
{% set pg_pass = salt.pillar.get('reddit:ini_config:DEFAULT:db_pass') %}

create_reddit_keyspace:
  cmd.script:
    - name: salt://reddit/files/setup_cassandra.py

create_postgresql_functions:
  file.managed:
    - name: /tmp/postgres_functions.sql
    - source: salt://reddit/files/postgres_functions.sql
  cmd.run:
    - name: >-
        psql --host postgresql-reddit.service.consul --username {{ pg_user }} --file /tmp/postgres_functions.sql reddit
    - env:
        - PGPASSWORD: {{ pg_pass }}

seed_reddit_with_admin_and_client:
  file.managed:
    - name: /tmp/seed_reddit_auth.py
    - source: salt://reddit/templates/seed_reddit_auth.py
    - template: jinja
    - mode: 755
    - context:
        admin_name: {{ reddit_admin.username }}
        admin_password: {{ reddit_admin.password }}
        system_name: {{ system_user.username }}
        system_password: {{ system_user.password }}
        oauth_client_id: {{ reddit_oauth.client_id }}
        oauth_client_secret: {{ reddit_oauth.client_secret }}
  cmd.run:
    - name: /usr/local/bin/reddit-run /tmp/seed_reddit_auth.py
    - require:
        - file: seed_reddit_with_admin_and_client
    - user: deploy

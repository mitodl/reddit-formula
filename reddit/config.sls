{% from "reddit/map.jinja" import reddit with context %}

{% for conf_name, val in reddit.queue_config_count.items() %}
set_consumer_count_values:
  file.managed:
    - name: /home/deploy/consumer-count.d/{{ conf_name }}
    - makedirs: True
    - contents: {{ val }}
{% endfor %}

install_geoip_gunicorn_configuration:
  file.managed:
    - name: /etc/gunicorn.d/geoip.conf
    - makedirs: True
    - contents: |
        CONFIG = {
            "mode": "wsgi",
            "working_dir": "$REDDIT_SRC/reddit/scripts",
            "user": "$REDDIT_USER",
            "group": "$REDDIT_USER",
            "args": (
                "--bind=127.0.0.1:5000",
                "--workers=1",
                 "--limit-request-line=8190",
                 "geoip_service:application",
            ),
        }

create_reddit_defaults_configuration:
  file.managed:
    - name: /etc/default/reddit
    - contents: |
        export REDDIT_ROOT=/home/deploy/reddit/r2
        export REDDIT_INI=/home/deploy/reddit/r2/run.ini
        export REDDIT_USER=deploy
        export REDDIT_GROUP=reddit
        export REDDIT_CONSUMER_CONFIG=/home/deploy/consumer-count.d
        alias wrap-job=$REDDIT_SRC/reddit/scripts/wrap-job
        alias manage-consumers=$REDDIT_SRC/reddit/scripts/manage-consumers

{% set reddit_config = salt.pillar.get('reddit:ini_config') %}
{% set reddit_dir = '/home/deploy/src/reddit/r2' %}

write_reddit_config:
  file.managed:
    - name: {{ reddit_dir }}/prod.update
    - source: salt://reddit/templates/conf.ini.jinja
    - template: jinja
    - context:
        settings: {{ reddit_config }}

update_reddit_config:
  cmd.run:
    - name: python updateini.py prod.update run.ini
    - cwd: {{ reddit_dir }}
    - onchanges:
        - file: write_reddit_config

restart_reddit_service:
  cmd.run:
    - name: reddit-restart
    - onchanges:
        - file: write_reddit_config

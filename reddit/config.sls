{% from "reddit/map.jinja" import reddit with context %}

{% for conf_name, val in reddit.queue_config_count.items() %}
set_consumer_count_value_for_{{ conf_name }}:
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
            "working_dir": "/home/deploy/reddit/scripts",
            "user": "deploy",
            "group": "deploy",
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
        alias wrap-job=/home/deploy/reddit/scripts/wrap-job
        alias manage-consumers=/home/deploy/reddit/scripts/manage-consumers
        {% for key, val in salt.pillar.get('reddit:environment', {}).items() %}
        export {{ key }}={{ val }}
        {% endfor %}

create_reddit_log_folder:
  file.directory:
    - name: /var/log/reddit
    - user: deploy
    - group: deploy
    - makedirs: True
    - recurse:
      - user
      - group

{% set reddit_config = salt.pillar.get('reddit:ini_config') %}
{% set websockets_config = salt.pillar.get('reddit:websockets_config') %}
{% set reddit_dir = '/home/deploy/reddit/r2' %}

write_websockets_config:
  file.managed:
    - name: /home/deploy/reddit-service-websockets/run.ini
    - source: salt://reddit/templates/conf.ini.jinja
    - template: jinja
    - context:
        settings: {{ websockets_config }}

write_reddit_config:
  file.managed:
    - name: {{ reddit_dir }}/prod.update
    - source: salt://reddit/templates/conf.ini.jinja
    - template: jinja
    - context:
        settings: {{ reddit_config }}

update_reddit_config:
  cmd.run:
    - name: python updateini.py example.ini prod.update > run.ini
    - cwd: {{ reddit_dir }}
    - onchanges:
        - file: write_reddit_config

restart_reddit_service:
  cmd.run:
    - name: reddit-restart
    - onchanges:
        - file: write_reddit_config
        - file: write_websockets_config

gunicorn_service_running:
  service.running:
    - name: gunicorn
    - enable: True
    - require:
        - file: install_geoip_gunicorn_configuration

run_reddit_start_if_restart_fails:
  cmd.run:
    - name: reddit-start
    - onfail:
        - cmd: restart_reddit_service

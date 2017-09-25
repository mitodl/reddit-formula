{% from "reddit/map.jinja" import reddit with context %}

include:
  - .install
  - .service

reddit-config:
  file.managed:
    - name: {{ reddit.conf_file }}
    - source: salt://reddit/templates/conf.jinja
    - template: jinja
    - watch_in:
      - service: reddit_service_running
    - require:
      - pkg: reddit

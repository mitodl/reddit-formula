{% from "reddit/map.jinja" import reddit with context %}

reddit_service_running:
  service.running:
    - name: {{ reddit.service }}
    - enable: True

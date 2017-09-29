{% from "reddit/map.jinja" import reddit with context %}

gunicorn_service_running:
  service.running:
    - name: gunicorn
    - enable: True

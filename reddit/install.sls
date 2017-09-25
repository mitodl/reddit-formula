{% from "reddit/map.jinja" import reddit with context %}

include:
  - .service

reddit:
  pkg.installed:
    - pkgs: {{ reddit.pkgs }}
    - require_in:
        - service: reddit_service_running

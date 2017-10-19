{% from "reddit/map.jinja" import reddit with context %}

create_mcrouter_configuration:
  file.managed:
    - name: /etc/mcrouter/global.conf
    - makedirs: True
    - contents: |
        {{ reddit.mcrouter_config|json(indent=2)|indent(8) }}

create_mcrouter_default_setting:
  file.managed:
    - name: /etc/default/mcrouter
    - contents: 'MCROUTER_FLAGS="-f /etc/mcrouter/global.conf -L /var/log/mcrouter/mcrouter.log -p 5050 -R /././ --stats-root=/var/mcrouter/stats"'

create_mcrouter_upstart_override:
  file.managed:
    - name: /etc/init/mcrouter.override
    - contents: start on networking or reddit-start

ensure_mcrouter_is_running:
  service.running:
    - name: mcrouter
    - enable: True
    - restart: True
    - onchanges:
        - file: create_mcrouter_configuration

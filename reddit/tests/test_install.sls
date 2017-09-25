{% from "reddit/map.jinja" import reddit with context %}

{% for pkg in reddit.pkgs %}
test_{{pkg}}_is_installed:
  testinfra.package:
    - name: {{ pkg }}
    - is_installed: True
{% endfor %}

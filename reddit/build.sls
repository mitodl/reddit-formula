{% for repo in ['reddit/r2',
                'reddit-i18n',
                'refresh_token',
                'reddit-service-websockets',
                'reddit-service-activity'] %}
build_python_package_for_{{ repo }}:
  pip.installed:
    - editable: /home/deploy/{{ repo }}
    - no_deps: True
    - upgrade: True
{% endfor %}

compile_translation_files:
  cmd.run:
    - name: make -C /home/deploy/reddit-i18n clean all
    - user: deploy

compile_cython_files:
  cmd.run:
    - name: make clean pyx
    - user: deploy
    - cwd: /home/deploy/reddit/r2

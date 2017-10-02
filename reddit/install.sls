{% from "reddit/map.jinja" import reddit with context %}

create_deployment_user:
  user.present:
    - name: deploy
    - shell: /bin/bash
    - home: /home/deploy

create_reddit_group:
  group.present:
    - name: reddit
    - addusers:
        - deploy

add_reddit_ppa:
  pkgrepo.managed:
    - ppa: reddit/ppa

set_preference_to_reddit_ppa_packages:
  file.managed:
    - name: /etc/apt/preferences.d/reddit
    - contents: |
        Package: *
        Pin: release o=LP-PPA-reddit
        Pin-Priority: 600

{% for pkgname in reddit.pkgs %}
install_reddit_package_{{ pkgname }}:
  pkg.installed:
    - name: {{ pkgname }}
    - refresh: True
    - require:
        - file: set_preference_to_reddit_ppa_packages
        - pkgrepo: add_reddit_ppa
{% endfor %}

{% for repo in ['reddit',
                'reddit-i18n',
                'refresh_token',
                'reddit-service-websockets',
                'reddit-service-activity'] %}
clone_{{ repo }}_repository:
  git.latest:
    - name: https://github.com/mitodl/{{ repo }}
    - target: /home/deploy/{{ repo }}
    - user: deploy
{% endfor %}

{% set reddithelpers = {
    'reddit-run': 'exec paster --plugin=r2 run /home/deploy/reddit/r2/run.ini "\$@"',
    'reddit-shell': 'exec paster --plugin=r2 shell /home/deploy/reddit/r2/run.ini',
    'reddit-start': 'initctl emit reddit-start',
    'reddit-stop': 'initctl emit reddit-stop',
    'reddit-restart': 'initctl emit reddit-restart TARGET=${1:-all}',
    'reddit-flush': 'echo flush_all | nc memcached.service.consul 11211',
    'reddit-serve': 'exec paster serve --reload /home/deploy/reddit/r2/run.ini'
} %}

{% for script, contents in reddithelpers.items() %}
create_helper_script_{{ script }}:
  file.managed:
    - name: /usr/local/bin/{{ script }}
    - contents: {{ contents }}
    - mode: 0755
{% endfor %}

create_directory_for_media_assets:
  file.directory:
    - name: /var/www/media/
    - makedirs: True
    - user: deploy
    - group: www-data
    - recurse:
        - user
        - group

install_reddit_upstart_scripts:
  module.run:
    - name: file.copy
    - dst: /etc/init/
    - src: /home/deploy/reddit/upstart/
    - recurse: True

install_websocket_upstart_script:
  file.managed:
    - name: /etc/init/reddit-websockets.conf
    - contents: |
        description "websockets service"

        stop on runlevel [!2345] or reddit-restart all or reddit-restart websockets
        start on runlevel [2345] or reddit-restart all or reddit-restart websockets

        respawn
        respawn limit 10 5
        kill timeout 15

        limit nofile 65535 65535

        exec baseplate-serve2 --bind localhost:9001 /home/deploy/reddit-service-websockets/run.ini

create_redit_cron_configuration:
  file.managed:
    - name: /etc/cron.d/reddit
    - contents: |
        0    3 * * * root /sbin/start --quiet reddit-job-update_sr_names
        30  16 * * * root /sbin/start --quiet reddit-job-update_reddits
        0    * * * * root /sbin/start --quiet reddit-job-update_promos
        */5  * * * * root /sbin/start --quiet reddit-job-clean_up_hardcache
        */2  * * * * root /sbin/start --quiet reddit-job-broken_things
        */2  * * * * root /sbin/start --quiet reddit-job-rising
        0    * * * * root /sbin/start --quiet reddit-job-trylater

        # jobs that recalculate time-limited listings (e.g. top this year)
        PGPASSWORD=password
        */15 * * * * $REDDIT_USER $REDDIT_SRC/reddit/scripts/compute_time_listings link year "['hour', 'day', 'week', 'month', 'year']"
        */15 * * * * $REDDIT_USER $REDDIT_SRC/reddit/scripts/compute_time_listings comment year "['hour', 'day', 'week', 'month', 'year']"

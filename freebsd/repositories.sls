{%- from "freebsd/map.jinja" import freebsd with context %}

{{ freebsd.repositories_dir }}:
  file.directory:
    - user: root
    - group: wheel
    - mode: 755
    - makedirs: True

{% for repo, args in salt['pillar.get']('freebsd:repositories', {}).items() %}

{{ repo }}-config:
  file.managed:
    - name: {{ freebsd.repositories_dir }}/{{ repo }}.conf
    - source: salt://freebsd/files/repo.conf
    - template: jinja
    - user: root
    - group: wheel
    - mode: 644
    - context:
        name: {{ repo }}
        url: {{ args.url }}
        enabled: {{ args.enabled }}
        mirror_type: {{ args.mirror_type }}
        priority: {{ args.priority }}
{%- if signature_type is defined %}
        signature_type: {{ args.signature_type }}
{%- endif %}
{%- if pubkey is defined %}
        pubkey: {{ args.pubkey }}
{%- endif %}

{% endfor %}

repository_update:
  cmd.run:
    - name: pkg update -f
    - onchanges:
      - file: {{ freebsd.repositories_dir }}*

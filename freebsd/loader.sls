{%- from "freebsd/map.jinja" import freebsd with context %}

# Only apply loader.conf settings if we are not inside a jail
{%- if grains['virtual_subtype'] is not defined or grains['virtual_subtype'] is defined and grains['virtual_subtype'] != 'jail' %}

{%- for key, value in pillar.freebsd.loader.get('sysctl', {}).items() %}

freebsd_loader_conf_{{ key }}_sysctl:
  sysctl.present:
    - name: {{ key }}
    - value: {{ value }}
    - config: /boot/loader.conf

{%- endfor %}
{%- for key, value in pillar.freebsd.loader.get('sysrc', {}).items() %}

freebsd_loader_conf_{{ key }}_sysrc:
  sysrc.managed:
    - name: {{ key }}
    - value: {{ value }}
    - file: /boot/loader.conf

{%- endfor %}

{%- endif %}

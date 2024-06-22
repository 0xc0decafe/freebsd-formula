{%- from "freebsd/map.jinja" import freebsd with context %}

# Only apply sysctl settings if we are not inside a jail
{%- if grains['virtual_subtype'] is not defined or grains['virtual_subtype'] is defined and grains['virtual_subtype'] != 'jail' %}

{%- for sysctl_name, sysctl_value in pillar.freebsd.sysctl.get('settings', {}).items() %}

freebsd_kernel_{{ sysctl_name }}:
  sysctl.present:
    - name: {{ sysctl_name }}
    - value: {{ sysctl_value }}
{%- if sysctl_name == "kern.randompid" %}
    - onlyif: test `sysctl -n kern.randompid` -eq 0
{%- endif %}

{%- endfor %}

{%- endif %}

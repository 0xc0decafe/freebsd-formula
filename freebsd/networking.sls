{% from "freebsd/macros.jinja" import configure_interface with context -%}

{% if salt['pillar.get']('freebsd:networking', False) %}
include:
  - freebsd.kernel

{% set networking = salt['pillar.get']('freebsd:networking') %}

{% if networking.gateway is defined %}
{# Enable for next boot #}
freebsd_networking_gateway:
  sysrc.managed:
    - name: gateway_enable
    - value: "YES"
{% endif %} {# if networking.gateway is defined #}

{% if networking.defaultrouter is defined and
      networking.defaultrouter | is_ip and
      grains.get('virtual_subtype', '') != 'jail' %}

freebsd_networking_defaultrouter:
  sysrc.managed:
    - name: defaultrouter
    - value: "{{ networking.defaultrouter }}"

{% endif %} {# if networking.defaultrouter is defined #}

{% if networking.dns is defined %}
resolvconf_config:
  file.managed:
    - name: /etc/resolvconf.conf
    - mode: 0644
    - user: root
    - group: wheel
    - contents:
      - resolvconf="NO"
      {% if networking.dns.search is defined %}
      - search_domains="{{ ' '.join(networking.dns.search) }}"
      {% endif %}
      {% if networking.dns.nameservers is defined %}
      - name_servers="{{ ' '.join(networking.dns.nameservers) }}"
      {% endif %}
  cmd.run:
    - name: resolvconf -u
    - require_in:
      - file: freebsd_networking_dns_config
    - onchanges:
      - file: resolvconf_config

freebsd_networking_dns_config:
  file.managed:
    - name: /etc/resolv.conf
    - mode: 0644
    - user: root
    - group: wheel
    - contents:
      {% if networking.dns.search is defined %}
      - search {{ " ".join(networking.dns.search) }}
      {% endif %}
      {% for dns in networking.dns.nameservers %}
      - nameserver {{ dns }}
      {% endfor %}
{% endif %} {# if networking.dns is defined #}

{% if networking.interfaces is defined %}

{#---------- VLAN INTERFACES ----------#}
{% if networking.vlan_interfaces is defined %}
{% for parent in networking.vlan_interfaces %}

freebsd_networking_vlans_{{parent}}:
  sysrc.managed:
    - name: vlans_{{parent}}
    - value: "{%- for id in salt['pillar.get']('freebsd:networking:vlan_interfaces:' ~ parent) -%}{{ "%s_%s " | format(parent, id) }}{%- endfor -%}"
    # - value: "{%- for id in salt['pillar.get']('freebsd:networking:vlan_interfaces:' ~ parent) -%}{{parent}}_{{id}}{%- if not loop.last -%} {%- endif -%}{%- endfor -%}"

{% for id in salt['pillar.get']('freebsd:networking:vlan_interfaces:' ~ parent) %}

freebsd_networking_vlan_{{parent}}_{{id}}:
  sysrc.managed:
    - name: create_args_{{parent}}_{{id}}
    - value: "vlan {{id}}"

{% endfor %}
{% endfor %}
{% endif %}

{#---------- CLONED INTERFACES ----------#}
{% if networking.interfaces.cloned_interfaces is defined %}
{% set cloned_interfaces = networking.interfaces.cloned_interfaces|join(" ") %}

freebsd_networking_cloned_interfaces:
  sysrc.managed:
    - name: cloned_interfaces
    - value: "{{ cloned_interfaces|lower }}"

{% for interface in networking.interfaces.cloned_interfaces %}
{% set interface_cfg = salt['pillar.get']('freebsd:networking:interfaces:cloned_interfaces:' ~ interface ) %}
{% if interface_cfg.ports is defined %}
{% if interface_cfg.cfg is defined %}
{{ configure_interface(interface, interface_cfg.cfg, interface_cfg.protocol, interface_cfg.ports) }}
{% else %}
{{ configure_interface(interface, None, interface_cfg.protocol, interface_cfg.ports) }}
{% endif %}
{% endif %}

{% if interface_cfg.aliases is defined %}
{% for alias in interface_cfg.aliases %}
{{ configure_interface(interface ~ "_alias" ~ loop.index0, alias) }}
{% endfor %} {# for alias in interface_cfg.aliases #}
{% endif %} {# if interface_cfg.aliases is defined #}

{% endfor %} {# for interface in networking.interfaces.cloned_interfaces #}
{% endif %} {# if networking.interfaces.cloned_interfaces is defined #}

{#---------- REGULAR INTERFACES ----------#}
{% for interface in networking.interfaces if not interface.startswith('cloned_interfaces') %}
{% set interface_cfg = salt['pillar.get']('freebsd:networking:interfaces:' ~ interface ) %}

{% if interface_cfg.aliases is defined %}
{# We need to configure the parent interface as UP #}
{{ configure_interface(interface) }}
{% for alias in interface_cfg.aliases %}
{{ configure_interface(interface ~ "_alias" ~ loop.index0, alias) }}
{% endfor %} {# for alias in interface_cfg.aliases #}
{% else %}
{{ configure_interface(interface, interface_cfg) }}
{% endif %} {# if interface_cfg.aliases is defined #}

{% endfor %} {# for interface in networking.interfaces #}

{% if networking.ipv6_interfaces is defined %}
{#---------- IPV6 INTERFACES ----------#}

freebsd_networking_ipv6_interfaces:
  sysrc.managed:
    - name: ipv6_network_interfaces
    - value: "{{ networking.ipv6_interfaces|join(" ") }}"

{% for interface in networking.ipv6_interfaces %}
{% set interface_cfg = salt['pillar.get']('freebsd:networking:ipv6_interfaces:' ~ interface) %}

{% if interface_cfg.cfg is defined %}
{{ configure_interface(interface ~ "_ipv6", interface_cfg.cfg) }}
{% endif %} {# if interface_cfg.cfg is defined #}

#~ {% if interface_cfg.aliases is defined %}
#~ {% for alias in interface_cfg.aliases %}
#~ {{ configure_interface(interface ~ "_alias" ~ loop.index0, alias) }}
#~ {% endfor %} {# for alias in interface_cfg.aliases #}
#~ {% endif %} {# if interface_cfg.aliases is defined #}

#~ {% if interface_cfg.ifid is defined %}
#~ freebsd_networking_ipv6_{{ interface }}_ifid:
  #~ sysrc.managed:
    #~ - name: interface_ipv6_ifid_{{ interface }}
    #~ - value: {{ interface_cfg.ifid }}
#~ {% endif %} {# if interface_cfg.ifid is defined #}


{% endfor %} {# for interface in networking.ipv6_interfaces #}

{% endif %} {# if interface_cfg.aliases is defined #}

{# Restart netif only if interfaces changed #}
freebsd_network_restart:
  cmd.run:
    - name: |
        exec 0>&- # close stdin
        exec 1>&- # close stdout
        exec 2>&- # close stderr
        nohup /bin/sh -c '/etc/rc.d/netif restart && /etc/rc.d/routing restart' &
        sleep 60
    - ignore_timeout: True
    - onchanges:
      {% if networking.defaultrouter is defined and
            networking.defaultrouter | is_ip and
            grains.get('virtual_subtype', '') != 'jail' %}
      - sysrc: freebsd_networking_defaultrouter
      {% endif %}
      - sysrc: freebsd_networking_ifconfig_*
      {% if networking.interfaces.cloned_interfaces is defined %}
      - sysrc: freebsd_networking_cloned_interfaces
      {% endif %}
      {% if networking.ipv6_interfaces is defined %}
      - sysrc: freebsd_networking_ipv6_interfaces
      {% endif %}
    {%- if salt['pillar.get']('freebsd.kernel', False) %}
    - require:
      {# Make sure we have all needed kernel modules (i.e if_lagg) loaded #}
      - sls: freebsd.kernel
    {%- endif %}

{% endif %} {# if networking.interfaces is defined #}
{% endif %} {# if salt['pillar.get']('freebsd:networking', False) #}

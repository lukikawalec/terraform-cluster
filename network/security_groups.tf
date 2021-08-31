locals {
    rules = flatten(
        [for security_group_name, rules in var.network_rules: 
            [for r in rules: 
                {
                    key = security_group_name
                    direction = r.direction == "in"? "ingress": "egress"
                    remote_ip_prefix = r.remote_addr
                    port_min = replace(tostring(r.port), "-", "") != tostring(r.port) ? split("-", tostring(r.port))[0] : r.port
                    port_max = replace(tostring(r.port), "-", "") != tostring(r.port) ? split("-", tostring(r.port))[1] : r.port
                    protocol = r.protocol
                }
            ]
        ]
    )
    # flatten([for name,items in module.common.common_security_groups: [for i in items: {key=name,dupa=i[1]}]])
}

resource "openstack_networking_secgroup_v2" "security_groups" {
    for_each             = var.network_rules

    name                 = "${var.environment}-${each.key}-sg"
    description          = "${var.environment} - rules for ${each.key}"
    delete_default_rules = "true"
}

resource "openstack_networking_secgroup_rule_v2" "rules" {
    for_each        = { for rule in local.rules: "${rule.key}-${rule.remote_ip_prefix}-[${rule.port_min}-${rule.port_max}]/${rule.protocol}" => rule }

    direction         = each.value.direction
    ethertype         = "IPv4"
    protocol          = each.value.protocol
    port_range_min    = each.value.port_min == "all"? null : each.value.port_min
    port_range_max    = each.value.port_max == "all"? null : each.value.port_max
    remote_ip_prefix  = each.value.remote_ip_prefix
    security_group_id = openstack_networking_secgroup_v2.security_groups[each.value.key].id
}
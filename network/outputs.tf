output "network_names" {
    value = { for key, net in openstack_networking_network_v2.net: key => net.name }
}

output "networks" {
    value = { for key, net in openstack_networking_network_v2.net: key => net }
}

output "subnets" {
    value = { for key, net in openstack_networking_subnet_v2.subnets: key => net }
}

output "cidrs" {
    value = local.cidr_by_names
}

output "security_group_names" {
    value = { for name, group in openstack_networking_secgroup_v2.security_groups: name => group.name }
}

output common_security_groups {
    value = {
        allow_out = [
            ["out", "0.0.0.0/0", 0, "tcp"],
            ["out", "0.0.0.0/0", 0, "tcp"],
            ["out", "0.0.0.0/0", 0, "icmp"]
        ]   
    }
}
module "net" {
    source = "../network"

    environment = var.environment
    dns_servers = var.dns_servers
    external_network_name = var.external_network_name

    networks = { for name, config in var.cluster: name => config.network } 
    network_rules = merge(
        { 
            for name, config in var.cluster: name => 
                concat(
                    try(flatten([for source, ports in config.open_tcp_ports_for: [for port in ports: {direction: "in", remote_addr: source, port: port, protocol: "tcp"}]]), []),
                    try(flatten([for source, ports in config.open_udp_ports_for: [for port in ports: {direction: "in", remote_addr: source, port: port, protocol: "udp"}]]), [])
                )
        }, 
        {for k,v in var.network_rules: k=> [for r in v: {direction: r[0], remote_addr: r[1], port: r[2], protocol: r[3]}]}
        
    )
    # network_rules = merge({ 
    #     for name, config in var.cluster: name => {
    #         in_tcp = can(config.open_tcp_ports_for) ? {
    #             for source, ports in config.open_tcp_ports_for: source => ports
    #         } : {}
    #         in_udp = can(config.open_udp_ports_for) ? {
    #             for source, ports in config.open_udp_ports_for: source => ports 
    #         } : {}
    #     }
    # },{ 
    #     for name, config in var.network_rules: name => {
    #         in_tcp = try(config.in_tcp, {})
    #         in_udp = try(config.in_udp, {})
    #     }
    # })

}

locals {
    machine_defs = flatten([
        for name, config in var.cluster: [
            for idx in range(try(config.count, 1)):
                {
                    name = "${name}${idx + var.index_offset}"
                    flavor_name = config.flavor_name
                    image_name = try(config.image_name, "Centos-8-2004")
                    volume_size = config.volume_size != null ? config.volume_size : 20
                    volume_type = try(config.volume_type, null)
                    fixed_ip = try(length(config.fixed_ips), 0) > idx ? config.fixed_ips[idx] : null
                    generate_fip = try(config.generate_fip, false)
                    floating_ip = try(length(config.floating_ips), 0) > idx ? config.floating_ips[idx] : null
                    availability_zone = try(config.availability_zone, null)
                    network_name = module.net.network_names[name]
                    security_groups = concat(
                        [module.net.security_group_names[name]], 
                        values({for name in try(config.security_groups, []): name => module.net.security_group_names[name]})
                    )
                    attach_volumes = try(config.attach_volumes[idx], null)
                    server_group_key = name
                }
        ]
    ])
}

resource "openstack_compute_servergroup_v2" "server_groups" {
    for_each = { for name, config in var.cluster: name => config }

    name     = "${var.environment}-${each.key}-anti-affinity-group"
    policies = ["anti-affinity"]
}

module "instance" {
    source = "../instance"

    environment = var.environment
    key_pair = var.key_pair
    external_network_name = var.external_network_name

    machines = { for machine in local.machine_defs: machine.name => {
            flavor_name = machine.flavor_name
            image_name = machine.image_name
            volume_size = machine.volume_size
            volume_type = machine.volume_type
            fixed_ip = machine.fixed_ip
            generate_fip = machine.generate_fip
            floating_ip = machine.floating_ip
            availability_zone = machine.availability_zone
            network_name = machine.network_name
            security_groups = machine.security_groups
            attach_volumes = machine.attach_volumes
            server_group = try(openstack_compute_servergroup_v2.server_groups[machine.server_group_key].id, null)
        }
    }
}

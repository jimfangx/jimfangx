# advertised IPs https://berkeley.service-now.com/kb_view.do?sysparm_article=KB0011960
# advertise routes/IPs: https://tailscale.com/docs/features/subnet-routers/how-to/setup
#
# Auto approve new subnets
# "autoApprovers": {
#    "routes": {
#        "0.0.0.0/0": ["tag:subnet-router"],
#        "::/0": ["tag:subnet-router"]
#    }
# }
# 
# advertise the machine to be used for the connector/app & share with any machines tagged with ucb-forward: https://tailscale.com/docs/features/app-connectors/how-to/setup#configure-a-device-as-an-app-connector
tailscale up --advertise-connector --advertise-tags=tag:ucb-forward --advertise-exit-node --advertise-routes=128.32.0.0/16,136.152.0.0/16,169.229.0.0/16,192.31.95.0/24,192.31.105.0/24,192.31.161.0/24,192.31.161.0/24,192.101.42.0/24,192.107.102.0/24,192.195.74.0/24,10.0.0.0/8,2607:f140::/32,10.40.0.0/13,136.152.64.0/19,136.152.214.0/23,2607:f140:400::/48,10.31.0.0/16,136.152.208.0/24,2607:f140:5160::/48,10.56.0.0/13,136.152.209.0/24,2607:f140:6000::/48,136.152.16.0/20,2607:f140:800:1::/64

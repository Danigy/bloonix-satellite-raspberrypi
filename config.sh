# Config file for setup.sh
#
# Please edit all the variables


# Enter the satellite authkey
SATELLITE_AUTHKEY='secret_longer_than_32_characters_bloonix_satellite_authkey'

# State the IP of the router
ROUTER_IP='192.168.88.1'

# Your AS number, find out via:
# whois $(dig +short myip.opendns.com @resolver1.opendns.com) | grep origin | awk '{print $2}'
ORIGIN='AS1234'

# Setup data about the VPN server that is used to forward requests to this Raspberry Pi
VPN_SERVER_IP='123.123.123.123'
VPN_SERVER_PORT='1194'
VPN_SERVER_INTERNAL_IP='10.10.0.1'
VPN_CLIENT_IP='10.10.0.5'
VPN_CLIENT_INTERFACE='tun0'

# SSH public keys to append to /root/.ssh/authorized_keys
SSH_PUBLIC_KEYS=()
SSH_PUBLIC_KEYS+=('ssh-rsa .... foo@example.com')
SSH_PUBLIC_KEYS+=('ssh-rsa .... bar@example.com')

# Domain name for this Raspberry Pi machine
# Note that the AS origin number will be prepended for the fqdn!
DOMAIN='dsl.satellite.example.com'



# No need to modify these variables
REGISTRY="satellitesharing"
BASE_IMAGE="bloonix-satellite:arm"
IMAGE="$REGISTRY/$BASE_IMAGE"
# Name for the container for the Bloonix Satellite
CONTAINER_NAME="BloonixSatellite"

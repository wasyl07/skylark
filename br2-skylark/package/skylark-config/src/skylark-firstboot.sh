#!/bin/sh
set -eu
echo "Skylark first boot initialization..."
mkdir -p /data/ardupilot/logs /data/ardupilot/terrain
mkdir -p /data/skylark/config /data/skylark/network /data/skylark/keys
if [ ! -f /data/skylark/config.json ]; then
    cat > /data/skylark/config.json << 'EOF'
{
    "hostname": "skylark",
    "vehicle_type": "copter",
    "first_boot": true
}
EOF
fi
touch /data/.initialized
echo "First boot complete"

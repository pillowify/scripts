INSTALL_CMD="apt"
GREEN="\033[0;32m"
NC="\033[0m"

init() {
    read -p "Listening Port [443]: " port
    read -p "Destination [www.tesla.com:443]: " dest
    port=${port:-443}
    dest=${dest_domain:-www.tesla.com:443}
    dest_host=$(echo $dest | cut -d':' -f1)
    dest_port=$(echo $dest | cut -d':' -f2)
    ip=$(curl -s -4 ip.sb)
    ${INSTALL_CMD} update
    ${INSTALL_CMD} install -y vim curl wget cron
}

install_sing_box() {
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://sing-box.app/gpg.key -o /etc/apt/keyrings/sagernet.asc
    chmod a+r /etc/apt/keyrings/sagernet.asc
    echo "deb [arch=`dpkg --print-architecture` signed-by=/etc/apt/keyrings/sagernet.asc] https://deb.sagernet.org/ * *" | tee /etc/apt/sources.list.d/sagernet.list > /dev/null
    apt update
    apt install sing-box
    (crontab -l; echo "0 4 * * * systemctl restart sing-box") | crontab -
}

configure_sing_box() {
    sing-box generate reality-keypair > /var/key
    private_key=$(grep "PrivateKey:" /var/key | cut -d' ' -f2)
    public_key=$(grep "PublicKey:" /var/key | cut -d' ' -f2)
    uuid=$(sing-box generate uuid)
    cat > /etc/sing-box/config.json << EOF
{
    "inbounds": [
        {
            "type": "vless",
            "listen": "::",
            "listen_port": ${port},
            "users": [
                {
                    "uuid": "${uuid}",
                    "flow": "xtls-rprx-vision"
                }
            ],
            "tls": {
                "enabled": true,
                "server_name": "${dest_host}",
                "reality": {
                    "enabled": true,
                    "handshake": {
                        "server": "${dest_host}",
                        "server_port": ${dest_port}
                    },
                    "private_key": "${private_key}",
                    "short_id": [
                        ""
                    ]
                }
            }
        }
    ],
    "outbounds": [
        {
            "type": "direct"
        }
    ]
}
EOF
}

launch() {
    systemctl enable sing-box
    systemctl restart sing-box
}

print() {
    echo -e "IP: ${GREEN}${ip}${NC}"
    echo -e "Port: ${GREEN}${port}${NC}"
    echo -e "SNI: ${GREEN}${dest_host}${NC}"
    echo -e "UUID: ${GREEN}${uuid}${NC}"
    echo -e "Public Key: ${GREEN}${public_key}${NC}"
}

main() {
    init
    install_sing_box
    configure_sing_box
    launch
    print
}

main
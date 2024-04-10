INSTALL_CMD="apt"

init() {
    read -p "SNI: " sni
    read -p "Port: " port
    ${INSTALL_CMD} update
    ${INSTALL_CMD} install -y vim curl wget
}

install_xray() {
    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
}

configure_xray() {
    xray x25519 > /var/key
    private_key=$(grep "Private key:" /var/key | cut -d ' ' -f 3)
    public_key=$(grep "Public key:" /var/key | cut -d ' ' -f 3)
    uuid=$(xray uuid)
    cat > /usr/local/etc/xray/config.json << EOF
{
    "inbounds": [
        {
            "port": ${port}, 
            "protocol": "vless",
            "settings": {
                "clients": [
                    {
                        "id": "${uuid}",
                        "flow": "xtls-rprx-vision"
                    }
                ],
                "decryption": "none"
            },
            "streamSettings": {
                "network": "tcp",
                "security": "reality",
                "realitySettings": {
                    "dest": "${sni}:${port}",
                    "serverNames": [
                        "${sni}"
                    ],
                    "privateKey": "${private_key}",
                    "shortIds": [
                        ""
                    ]
                }
            },
            "sniffing": {
                "enabled": true,
                "destOverride": [
                    "http",
                    "tls",
                    "quic"
                ],
                "routeOnly": true
            }
        }
    ],
    "outbounds": [
        {
            "protocol": "freedom"
        }
    ]
}
EOF
}

launch() {
    systemctl restart xray.service
}

print() {
    echo "Port: ${port}"
    echo "SNI: ${sni}"
    echo "UUID: ${uuid}"
    echo "Public Key: ${public_key}"
}

main() {
    init
    install_xray
    configure_xray
    launch
    print
}

main
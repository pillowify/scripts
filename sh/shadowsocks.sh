INSTALL_CMD="apt"
GREEN="\033[0;32m"
NC="\033[0m"

init() {
    read -p "Listening Port [16122]: " port
    port=${port:-16122}
    ip=$(curl -s -4 ip.sb)
    ${INSTALL_CMD} update
    ${INSTALL_CMD} install -y vim curl wget
}

install_sing_box() {
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://sing-box.app/gpg.key -o /etc/apt/keyrings/sagernet.asc
    chmod a+r /etc/apt/keyrings/sagernet.asc
    echo "deb [arch=`dpkg --print-architecture` signed-by=/etc/apt/keyrings/sagernet.asc] https://deb.sagernet.org/ * *" | tee /etc/apt/sources.list.d/sagernet.list > /dev/null
    apt update
    apt install sing-box
}

configure_sing_box() {
    password=$(sing-box generate rand 16 --base64)
    cat > /etc/sing-box/config.json << EOF
{
    "inbounds": [
        {
            "type": "shadowsocks",
            "listen": "::",
            "listen_port": ${port},
            "method": "2022-blake3-aes-128-gcm",
            "password": "${password}",
            "multiplex": {
                "enabled": true
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
    echo -e "Password: ${GREEN}${password}${NC}"
}

main() {
    init
    install_sing_box
    configure_sing_box
    launch
    print
}

main
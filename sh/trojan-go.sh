PATH_ROOT="/opt"
PATH_TROJAN="${PATH_ROOT}/trojan"
PATH_CERT="${PATH_TROJAN}/certificates"
INSTALL_CMD="apt"

init() {
    read -p "Domain name: " domain_name
    read -p "Password: " password
    read -p "CF_Email: " email
    read -p "CF_Key: " key
    export CF_Email=${email}
    export CF_Key=${key}
    ${INSTALL_CMD} update
    ${INSTALL_CMD} install -y vim curl wget unzip git socat nginx
}

get_cert() {
    mkdir -p ${PATH_CERT}
    curl https://get.acme.sh | sh -s email=${email}
    ~/.acme.sh/acme.sh --upgrade --auto-upgrade
    ~/.acme.sh/acme.sh --issue --dns dns_cf -d ${domain_name}
    ~/.acme.sh/acme.sh --install-cert -d ${domain_name} --key-file ${PATH_CERT}/${domain_name}.key --fullchain-file ${PATH_CERT}/${domain_name}.pem
}

install_trojan_go() {
    wget -P ${PATH_TROJAN} https://github.com/p4gefau1t/trojan-go/releases/download/v0.10.6/trojan-go-linux-amd64.zip
    unzip -d ${PATH_TROJAN} ${PATH_TROJAN}/trojan-go-linux-amd64.zip
    rm ${PATH_TROJAN}/trojan-go-linux-amd64.zip
    cat > ${PATH_TROJAN}/config.json << EOF
{
    "run_type": "server",
    "local_addr": "0.0.0.0",
    "local_port": 443,
    "remote_addr": "127.0.0.1",
    "remote_port": 9123,
    "password": [
        "${password}"
    ],
    "ssl": {
        "cert": "${PATH_CERT}/${domain_name}.pem",
        "key": "${PATH_CERT}/${domain_name}.key"
    }
}
EOF
}

get_fake_page() {
    git clone https://github.com/pillowify/fake-nextcloud.git ${PATH_TROJAN}/fake-nextcloud
}

configure_nginx() {
    cat > /etc/nginx/conf.d/trojan-go.conf << EOF
server {
    listen 9123;
    server_name _;
    root ${PATH_TROJAN}/fake-nextcloud;
    index index.html;
}
EOF
    systemctl restart nginx.service
}

create_service() {
    cat > /etc/systemd/system/trojan.service << EOF
[Unit]
Description = trojan server
After = network.target
Wants = network.target

[Service]
Type = simple
ExecStart = ${PATH_TROJAN}/trojan-go -config ${PATH_TROJAN}/config.json

[Install]
WantedBy = multi-user.target
EOF
    (crontab -l; echo "0 4 * * 1 /usr/bin/systemctl restart trojan.service") | crontab -
}

launch() {
    systemctl start trojan.service
    systemctl enable trojan.service
}

main() {
    init
    get_cert
    install_trojan_go
    get_fake_page
    configure_nginx
    create_service
    launch
}

main
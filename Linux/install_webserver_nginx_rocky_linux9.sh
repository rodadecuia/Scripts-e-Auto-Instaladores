#!/bin/bash

echo "Este script é desenvolvido pelo Departamento de TI da empresa Roda de Cuia."
echo "Qualquer utilização do mesmo implica na aceitação dos termos e políticas presentes em https://rodadecuia.com.br."
echo "IMPORTANTE: A utilização é de inteira responsabilidade sua."

# Validação do sistema operacional
if ! grep -q "Rocky Linux 9" /etc/os-release; then
    echo "Este script é compatível somente com o Rocky Linux 9."
    exit 1
fi

# Validação de confirmação
read -p "Estou ciente que a utilização desta instalação pode apagar meus dados já presentes em meu servidor, e que é de minha total responsabilidade fazer backups? (sim/não): " confirm

if [[ "$confirm" != "sim" ]]; then
    echo "Muito obrigado, infelizmente não podemos continuar com a instalação."
    exit 1
fi

# Função para atualizar o sistema
update_system() {
    sudo dnf update -y
}

# Função para instalar MySQL/MariaDB
install_mariadb() {
    sudo dnf install -y mariadb-server
    sudo systemctl enable mariadb
    sudo systemctl start mariadb
}

# Função para instalar Nginx
install_nginx() {
    sudo dnf install -y nginx
    sudo systemctl enable nginx
    sudo systemctl start nginx
}

# Função para instalar PHP 8.3
install_php() {
    sudo dnf install -y epel-release
    sudo dnf install -y https://rpms.remirepo.net/enterprise/remi-release-9.rpm
    sudo dnf module reset php -y
    sudo dnf module enable php:remi-8.3 -y
    sudo dnf install -y php php-fpm php-mysqlnd
    sudo systemctl enable php-fpm
    sudo systemctl start php-fpm
}

# Função para instalar PhpMyAdmin
install_phpmyadmin() {
    sudo dnf install -y phpmyadmin
}

# Função para instalar Certbot
install_certbot() {
    sudo dnf install -y certbot python3-certbot-nginx
}

# Função para configurar o firewall
configure_firewall() {
    sudo firewall-cmd --permanent --zone=public --add-service=http
    sudo firewall-cmd --permanent --zone=public --add-service=https
    sudo firewall-cmd --reload
}

# Função para adicionar um novo vhost no Nginx
add_vhost() {
    read -p "Digite o nome do domínio: " domain
    root_dir="/var/www/html/$domain"

    # Criar o diretório do vhost e aplicar permissões
    sudo mkdir -p $root_dir
    sudo chown -R $USER:$USER $root_dir
    sudo chmod -R 755 /var/www

    sudo tee /etc/nginx/conf.d/$domain.conf > /dev/null <<EOL
server {
    listen 80;
    server_name $domain;
    root $root_dir;

    index index.php index.html index.htm;

    location / {
        try_files \$uri \$uri/ =404;
    }

    location ~ \.php\$ {
        include /etc/nginx/fastcgi_params;
        fastcgi_pass unix:/run/php-fpm/www.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOL

    sudo nginx -t && sudo systemctl reload nginx

    # Gerar certificado SSL usando Certbot
    sudo certbot --nginx -d $domain

    echo "Vhost para $domain criado com sucesso!"
}

# Função para exibir o menu de opções
show_menu() {
    echo -e "\e[32mSelecione a opção de instalação:\e[0m"
    echo -e "\e[34m1. Instalar servidor web (Nginx, PHP, MySQL/MariaDB)\e[0m"
    echo -e "\e[34m2. Instalar PhpMyAdmin\e[0m"
    echo -e "\e[34m3. Adicionar novo vhost no Nginx\e[0m"
    echo -e "\e[34m4. Gerar certificados SSL\e[0m"

    read -p "Digite a opção desejada [1-4]: " option

    case $option in
        1)
            update_system
            install_nginx
            install_php
            install_mariadb
            ;;
        2)
            install_phpmyadmin
            ;;
        3)
            add_vhost
            ;;
        4)
            install_certbot
            ;;
        *)
            echo "Opção inválida!"
            ;;
    esac

    echo "Processo concluído!"
}

# Loop para continuar instalando novas aplicações
while true; do
    show_menu
    read -p "Deseja instalar novas aplicações? (sim/não): " continue_install

    if [[ "$continue_install" != "sim" ]]; then
        echo "Muito obrigado! O script será finalizado."
        break
    fi
done

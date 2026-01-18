#!/usr/bin/env bash

# Скрипт установки и управления мульти-протокольным VPN-сервером
# Поддерживаемые протоколы: VLESS+Reality, Shadowsocks-2022, AmneziaWG

set -euo pipefail

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функция для логирования
log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log_info() {
    log "${GREEN}INFO${NC}: $1"
}

log_warn() {
    log "${YELLOW}WARN${NC}: $1"
}

log_error() {
    log "${RED}ERROR${NC}: $1"
}

# Проверка прав суперпользователя
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Этот скрипт должен быть запущен с правами суперпользователя (sudo)"
        exit 1
    fi
}

# Проверка зависимости
check_dependency() {
    local cmd=$1
    local package=$2
    
    if ! command -v "$cmd" &> /dev/null; then
        log_error "$cmd не найден. Устанавливаю $package..."
        apt-get update
        apt-get install -y "$package"
    else
        log_info "$cmd найден"
    fi
}

# Установка Docker и Docker Compose
install_docker() {
    log_info "Установка Docker и Docker Compose..."
    
    # Удаление старых версий
    apt-get remove -y docker docker-engine docker.io containerd runc || true
    
    # Установка зависимостей
    apt-get update
    apt-get install -y ca-certificates curl gnupg lsb-release
    
    # Добавление официального GPG ключа Docker
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    
    # Установка репозитория Docker
    local codename=$(lsb_release -cs)
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $codename stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Установка Docker Engine
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    
    # Добавление текущего пользователя в группу docker
    usermod -aG docker "${SUDO_USER:-$USER}"
    
    # Запуск и включение Docker
    systemctl enable docker
    systemctl start docker
    
    log_info "Docker и Docker Compose установлены успешно"
}

# Генерация криптографических значений
generate_secrets() {
    log_info "Генерация криптографических значений..."
    
    # Создание .env файла, если он не существует
    if [[ ! -f .env ]]; then
        if [[ -f .env.template ]]; then
            cp .env.template .env
            log_info "Создан .env файл из шаблона"
        else
            log_warn ".env.template не найден, создаю новый .env файл"
            cat > .env << EOF
# Конфигурация VPN-сервера
UUID=$(openssl rand -hex 16)
VMESS_UUID=$(openssl rand -hex 8)-$(openssl rand -hex 4)-$(openssl rand -hex 4)-$(openssl rand -hex 4)-$(openssl rand -hex 12)
PRIVATE_KEY=$(openssl ecparam -genkey -name prime256v1 -noout | openssl ec -outform PEM | sed -n '2,$ p' | tr -d '\n')
PUBLIC_KEY=$(echo "$PRIVATE_KEY" | openssl ec -pubout -outform PEM | sed -n '2,$ p' | tr -d '\n')
SHORT_ID=$(openssl rand -hex 8)
SERVER_NAME=google.com
SNI=$SERVER_NAME
PORT_VLESS=8443
PORT_SHADOWSOCKS=8443
PORT_AMNEZIAWG=51820
PASSWORD_SS=$(openssl rand -base64 32)
WG_PRIVATE_KEY=$(wg genkey)
WG_PUBLIC_KEY=$(echo "$WG_PRIVATE_KEY" | wg pubkey)
WG_PASSWORD=$(openssl rand -hex 16)
EOF
            log_info "Создан .env файл с новыми секретами"
        fi
    fi
    
    # Загрузка переменных из .env
    export $(grep -v '^#' .env | xargs)
    
    log_info "Секреты сгенерированы и загружены"
}

# Создание шаблонов конфигурации (только если файлы не существуют)
create_configs() {
    log_info "Проверка/создание шаблонов конфигурационных файлов..."
    
    # Создание директории configs, если не существует
    mkdir -p configs
    
    # Создание шаблона конфигурации Xray, если он не существует
    if [[ ! -f configs/xray.json.template ]]; then
        cat > configs/xray.json.template << 'EOF'
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "port": ${PORT_VLESS},
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "${UUID}",
            "flow": "xtls-rprx-vision"
          }
        ],
        "decryption": "none",
        "fallbacks": [
          {
            "dest": 80
          }
        ]
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "dest": "${SNI}:8443",
          "xver": 0,
          "uot": 1,
          "cipher": "none",
          "PrivateKey": "${PRIVATE_KEY}",
          "minClientVer": "",
          "maxClientVer": "",
          "maxTimeDiff": 0,
          "shortIds": ["${SHORT_ID}"]
        }
      }
    },
    {
      "port": ${PORT_SHADOWSOCKS},
      "protocol": "shadowsocks",
      "settings": {
        "method": "2022-blake3-aes-128-gcm",
        "password": "${PASSWORD_SS}",
        "udp": true
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
        log_info "Создан шаблон конфигурации Xray"
    else
        log_info "Шаблон конфигурации Xray уже существует, пропускаем создание"
    fi
    
    # Создание шаблона конфигурации AmneziaWG, если он не существует
    if [[ ! -f configs/amnezia.conf.template ]]; then
        cat > configs/amnezia.conf.template << 'EOF'
[Interface]
PrivateKey = ${WG_PRIVATE_KEY}
Address = 10.8.0.1/24
MTU = 1420
Jc = 5-10
Jmin = 100
Jmax = 1000
S1 = 10-20
S2 = 100-200
H1 = 500-1000
H2 = 1000-2000
H3 = 1500-2500
H4 = 2000-3000
[Peer]
PublicKey = ${WG_PUBLIC_KEY}
AllowedIPs = 10.8.0.2/32
PresharedKey = ${WG_PASSWORD}
EOF
        log_info "Создан шаблон конфигурации AmneziaWG"
    else
        log_info "Шаблон конфигурации AmneziaWG уже существует, пропускаем создание"
    fi
}

# Создание docker-compose.yml (только если файл не существует)
create_docker_compose() {
    if [[ ! -f docker-compose.yml ]]; then
        log_info "Создание docker-compose.yml..."
        
        cat > docker-compose.yml << 'EOF'
        services:
  xray:
    image: teddysun/xray
    container_name: xray-core
    restart: unless-stopped
    network_mode: host
    volumes:
      - ./xray_config.json:/etc/xray/config.json:ro
    environment:
      - TZ=UTC
    cap_add:
      - NET_ADMIN
      - NET_RAW
    sysctls:
      - net.core.rmem_max=26214400
      - net.core.wmem_max=26214400

  amnezia-wg:
    image: ghcr.io/amnezia-vpn/amneziawg:latest
    container_name: amnezia-wg
    restart: unless-stopped
    network_mode: host
    volumes:
      - ./amnezia_wg.conf:/etc/amnezia-wg/amnezia_wg.conf:ro
    cap_add:
      - NET_ADMIN
      - NET_RAW
      - SYS_MODULE
    sysctls:
      - net.ipv4.ip_forward=1
      - net.ipv4.conf.all.src_valid_mark=1
EOF

        log_info "Файл docker-compose.yml создан"
    else
        log_info "Файл docker-compose.yml уже существует, пропускаем создание"
    fi
}

# Подготовка конфигурационных файлов
prepare_configs() {
    log_info "Подготовка конфигурационных файлов из шаблонов..."
    
    # Создание директории для конфигураций
    mkdir -p xray amnezia
    
    # Подстановка значений в шаблоны
    if [[ -f configs/xray.json.template ]]; then
        envsubst < configs/xray.json.template > xray_config.json
    else
        log_error "Шаблон конфигурации Xray не найден: configs/xray.json.template"
        exit 1
    fi
    
    if [[ -f configs/amnezia.conf.template ]]; then
        envsubst < configs/amnezia.conf.template > amnezia_wg.conf
    else
        log_error "Шаблон конфигурации AmneziaWG не найден: configs/amnezia.conf.template"
        exit 1
    fi
    
    log_info "Конфигурационные файлы подготовлены"
}

# Настройка UFW
setup_firewall() {
    log_info "Настройка брандмауэра UFW..."
    
    # Установка UFW, если не установлен
    if ! command -v ufw &> /dev/null; then
        apt-get install -y ufw
    fi
    
    # Правила для UFW
    ufw --force reset
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow ssh
    ufw allow ${PORT_VLESS}/tcp
    ufw allow ${PORT_SHADOWSOCKS}/tcp
    ufw allow ${PORT_SHADOWSOCKS}/udp
    ufw allow ${PORT_AMNEZIAWG}/udp
    ufw --force enable
    
    log_info "Брандмауэр UFW настроен"
}

# Запуск сервисов
start_services() {
    log_info "Запуск VPN-сервисов..."
    
    docker compose up -d
    
    # Ждем немного, чтобы контейнеры запустились
    sleep 5
    
    # Проверяем статус контейнеров
    docker compose ps
    
    log_info "Сервисы запущены"
}

# Вывод информации для подключения
show_connection_info() {
    log_info "Информация для подключения:"
    echo ""
    
    # Загрузка переменных
    export $(grep -v '^#' .env | xargs)
    
    # Получение внешнего IP
    local ip=$(curl -s https://api.ipify.org)
    
    # Вывод VLESS ссылки
    echo -e "${BLUE}VLESS + Reality:${NC}"
    local vless_link="vless://${UUID}@${ip}:${PORT_VLESS}?security=reality&sni=${SNI}&fp=chrome&type=tcp&flow=xtls-rprx-vision&sid=${SHORT_ID}#$SERVER_NAME"
    echo "$vless_link"
    echo ""
    
    # Вывод Shadowsocks ссылки
    echo -e "${BLUE}Shadowsocks-2022:${NC}"
    local ss_base64=$(echo -n "2022-blake3-aes-128-gcm:${PASSWORD_SS}@${ip}:${PORT_SHADOWSOCKS}" | base64 -w 0)
    local ss_link="ss://${ss_base64}#${SERVER_NAME}"
    echo "$ss_link"
    echo ""
    
    # Вывод AmneziaWG конфига
    echo -e "${BLUE}AmneziaWG конфиг:${NC}"
    local amnezia_config="[Interface]
PrivateKey = ${WG_PRIVATE_KEY}
Address = 10.8.0.2/32
DNS = 8.8.8.8, 1.1.1.1
MTU = 1420
Jc = 5-10
Jmin = 100
Jmax = 1000
S1 = 10-20
S2 = 100-200
H1 = 500-1000
H2 = 1000-2000
H3 = 1500-2500
H4 = 2000-3000
[Peer]
PublicKey = ${WG_PUBLIC_KEY}
AllowedIPs = 0.0.0.0/0, ::/0
Endpoint = ${ip}:${PORT_AMNEZIAWG}
PersistentKeepalive = 25
PresharedKey = ${WG_PASSWORD}"
    echo "$amnezia_config"
    echo ""
    
    log_info "Подключение к сервисам должно быть доступно в течение 30 секунд"
    
    # Создание файла с инструкциями и ссылками
    create_connection_guide "$ip" "$vless_link" "$ss_link" "$amnezia_config"
}

# Создание файла с инструкциями и ссылками для подключения
create_connection_guide() {
    local ip=$1
    local vless_link=$2
    local ss_link=$3
    local amnezia_config=$4
    
    local guide_file="connection_guide.txt"
    
    cat > "$guide_file" << EOF
ИНСТРУКЦИЯ ПО ПОДКЛЮЧЕНИЮ К VPN-СЕРВЕРУ
===================================

Ваш VPN-сервер успешно установлен и запущен!

ТЕКУЩИЙ IP-АДРЕС СЕРВЕРА: $ip

1. VLESS + REALITY
-------------------
Скопируйте следующую ссылку и добавьте в приложение:

$vless_link

Поддерживаемые приложения:
- Android: v2rayNG, Hiddify
- iOS: Shadowrocket, Quantumult X, Loon
- Windows: Qv2ray, v2rayN
- macOS: Qv2ray, ClashX
- Linux: Qv2ray

2. SHADOWSOCKS-2022
--------------------
Скопируйте следующую ссылку и добавьте в приложение:

$ss_link

Поддерживаемые приложения:
- Android: v2rayNG, Shadowsocks
- iOS: Shadowrocket, Shadowsocks
- Windows: Shadowsocks Windows
- macOS: ShadowsocksX-NG
- Linux: shadowsocks-rust

3. AMNEZIAGW
-------------
Скопируйте следующий конфигурационный файл:

$amnezia_config

Поддерживаемые приложения:
- Все платформы: AmneziaVPN
  Сайт: https://amnezia.org/

АЛЬТЕРНАТИВНЫЙ МЕТОД ДЛЯ AMNEZIAGW:
Сохраните приведенный выше конфигурационный файл с расширением .conf
и импортируйте его в AmneziaVPN.

ДОПОЛНИТЕЛЬНАЯ ИНФОРМАЦИЯ
========================
- Порт VLESS/Reality: $PORT_VLESS
- Порт Shadowsocks: $PORT_SHADOWSOCKS
- Порт AmneziaWG: $PORT_AMNEZIAWG
- Сервер для маскировки: $SERVER_NAME

При возникновении проблем с подключением:
1. Проверьте, что порты открыты в firewall
2. Убедитесь, что службы запущены: docker compose ps
3. Посмотрите логи: docker compose logs xray и docker compose logs amnezia-wg
EOF

    log_info "Файл с инструкциями по подключению создан: $guide_file"
}

# Проверка работоспособности
health_check() {
    log_info "Проверка работоспособности сервисов..."
    
    # Проверка статуса контейнеров
    local containers_status=$(docker compose ps --format "table {{.Name}}\t{{.State}}\t{{.Status}}")
    echo "$containers_status"
    
    # Проверка, запущены ли контейнеры
    if [[ $(docker compose ps -q --filter "status=running" | wc -l) -eq 0 ]]; then
        log_error "Нет запущенных контейнеров"
        return 1
    fi
    
    log_info "Сервисы работают корректно"
}

# Основная функция
main() {
    log_info "Начало установки мульти-протокольного VPN-сервера"
    
    # Убедиться, что у файла есть права на выполнение
    chmod +x "$0" 2>/dev/null || true
    
    check_root
    check_dependency docker docker.io
    check_dependency curl curl
    check_dependency openssl openssl
    check_dependency wg wireguard-tools
    check_dependency envsubst gettext-base
    
    # Проверка занятости порта 8443
    if lsof -Pi :8443 -sTCP:LISTEN -t >/dev/null ; then
        log_error "Порт 8443 уже занят другим приложением. Остановите Nginx/Apache или выберите другой порт."
        exit 1
    fi
    
    # Установка Docker, если не установлен
    if ! command -v docker &> /dev/null; then
        install_docker
    fi
    
    generate_secrets
    create_configs
    create_docker_compose
    prepare_configs
    setup_firewall
    start_services
    show_connection_info
    health_check
    
    log_info "Установка завершена успешно!"
    log_info "Для повторного получения информации о подключении запустите: ./setup.sh --info"
    
    # Если передан аргумент --info, просто показываем информацию о подключении
    if [[ $# -gt 0 && "$1" == "--info" ]]; then
        show_connection_info
    fi
}

# Вызов основной функции
main "$@"

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
    
    if [[ "$cmd" == "wg" ]]; then
        # Для WireGuard проверяем наличие утилиты wg
        if ! command -v "$cmd" &> /dev/null; then
            log_error "$cmd не найден. Устанавливаю $package..."
            apt-get update
            apt-get install -y "$package"
        else
            log_info "$cmd найден"
        fi
    elif [[ "$cmd" == "docker" ]]; then
        # Для Docker проверяем наличие и работоспособность
        if ! command -v "$cmd" &> /dev/null; then
            log_error "$cmd не найден. Устанавливаю $package..."
            apt-get update
            apt-get install -y "$package"
        else
            log_info "$cmd найден"
        fi
        
        # Также проверяем, что Docker daemon запущен
        if ! systemctl is-active --quiet docker; then
            log_info "Docker daemon не запущен, запускаю..."
            systemctl start docker
        fi
    else
        if ! command -v "$cmd" &> /dev/null; then
            log_error "$cmd не найден. Устанавливаю $package..."
            apt-get update
            apt-get install -y "$package"
        else
            log_info "$cmd найден"
        fi
    fi
}

# Проверка зависимости для QR-кодов
check_qr_dependency() {
    if ! command -v qrencode &> /dev/null; then
        echo -e "📦 Устанавливаю qrencode для генерации QR-кодов..."
        apt-get update && apt-get install -y qrencode
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
            
            # Проверяем наличие образа amnezia-vpn/amnezia-wg, если нет - скачиваем
            if ! docker image inspect amnezia-vpn/amnezia-wg &>/dev/null; then
                log_info "Скачиваю Docker образ amnezia-vpn/amnezia-wg..."
                docker pull amnezia-vpn/amnezia-wg
            fi
            
            # Генерируем ключи для AmneziaWG (используем docker, чтобы не ставить утилиты на хост)
            CLIENT_PRIV_KEY=$(docker run --rm amnezia-vpn/amnezia-wg wg genkey)
            CLIENT_PUB_KEY=$(echo "$CLIENT_PRIV_KEY" | docker run --rm -i amnezia-vpn/amnezia-wg wg pubkey)
            SERVER_PRIV_KEY=$(docker run --rm amnezia-vpn/amnezia-wg wg genkey)
            SERVER_PUB_KEY=$(echo "$SERVER_PRIV_KEY" | docker run --rm -i amnezia-vpn/amnezia-wg wg pubkey)

            # Генерируем случайные числа для обфускации (вместо диапазонов)
            JC=$(shuf -i 3-10 -n 1)
            JMIN=$(shuf -i 50-100 -n 1)
            JMAX=$(shuf -i 1000-1200 -n 1)
            S1=$(shuf -i 15-100 -n 1)
            S2=$(shuf -i 100-200 -n 1)
            H1=$(shuf -i 500-1000 -n 1)
            H2=$(shuf -i 1000-2000 -n 1)
            H3=$(shuf -i 1500-2500 -n 1)
            H4=$(shuf -i 2000-3000 -n 1)

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

# AmneziaWG параметры
WG_CLIENT_PRIVATE_KEY=$CLIENT_PRIV_KEY
WG_SERVER_PRIVATE_KEY=$SERVER_PRIV_KEY
WG_CLIENT_PUBLIC_KEY=$CLIENT_PUB_KEY
WG_SERVER_PUBLIC_KEY=$SERVER_PUB_KEY
WG_PASSWORD=$(openssl rand -hex 16)
WG_JC=$JC
WG_JMIN=$JMIN
WG_JMAX=$JMAX
WG_S1=$S1
WG_S2=$S2
WG_H1=$H1
WG_H2=$H2
WG_H3=$H3
WG_H4=$H4
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
    ports:
      - "${PORT_VLESS}:${PORT_VLESS}/tcp"
      - "${PORT_SHADOWSOCKS}:${PORT_SHADOWSOCKS}/tcp"
      - "${PORT_SHADOWSOCKS}:${PORT_SHADOWSOCKS}/udp"
    volumes:
      - ./xray_config.json:/etc/xray/config.json:ro
    environment:
      - TZ=UTC
    cap_add:
      - NET_ADMIN
      - NET_RAW

  amnezia-wg:
    image: ghcr.io/linuxserver/wireguard:latest
    container_name: amnezia-wg
    restart: unless-stopped
    ports:
      - "${PORT_AMNEZIAWG}:${PORT_AMNEZIAWG}/udp"
    volumes:
      - ./amnezia_server.conf:/config/wg0.conf:ro
    cap_add:
      - NET_ADMIN
      - NET_RAW
      - SYS_MODULE
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Etc/UTC
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
    
    # Создание конфигов для AmneziaWG
    # Клиентский конфиг (для импорта в приложение)
    cat > amnezia_client.conf << EOF
[Interface]
PrivateKey = $WG_CLIENT_PRIVATE_KEY
Address = 10.8.0.2/32
DNS = 8.8.8.8, 1.1.1.1
MTU = 1420
Jc = $WG_JC
Jmin = $WG_JMIN
Jmax = $WG_JMAX
S1 = $WG_S1
S2 = $WG_S2
H1 = $WG_H1
H2 = $WG_H2
H3 = $WG_H3
H4 = $WG_H4

[Peer]
PublicKey = $WG_SERVER_PUBLIC_KEY
AllowedIPs = 0.0.0.0/0, ::/0
Endpoint = \$(curl -s https://api.ipify.org):${PORT_AMNEZIAWG}
PersistentKeepalive = 25
PresharedKey = $WG_PASSWORD
EOF
    
    # Серверный конфиг (для Docker контейнера)
    cat > amnezia_server.conf << EOF
[Interface]
PrivateKey = $WG_SERVER_PRIVATE_KEY
Address = 10.8.0.1/24
MTU = 1420
Jc = $WG_JC
Jmin = $WG_JMIN
Jmax = $WG_JMAX
S1 = $WG_S1
S2 = $WG_S2
H1 = $WG_H1
H2 = $WG_H2
H3 = $WG_H3
H4 = $WG_H4

[Peer]
PublicKey = $WG_CLIENT_PUBLIC_KEY
AllowedIPs = 10.8.0.2/32
PresharedKey = $WG_PASSWORD
EOF
    
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

# Функция для отображения QR-кода
print_qr() {
    local name="$1"
    local link="$2"
    
    echo -e "\n========================================================"
    echo -e "   📱 QR-код для: \033[1;32m$name\033[0m"
    echo -e "   (Сканируйте приложением Hiddify / v2rayNG / Streisand)"
    echo -e "========================================================"
    
    # -t ansiutf8 позволяет рисовать QR прямо в терминале
    qrencode -t ansiutf8 "$link"
    
    echo -e "\n⬇️  Или скопируйте ссылку ниже:"
    echo -e "$link\n"
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
    local vless_link="vless://${UUID}@${ip}:${PORT_VLESS}?security=reality&sni=${SNI}&fp=chrome&type=tcp&flow=xtls-rprx-vision&sid=${SHORT_ID}#$SERVER_NAME"
    print_qr "VLESS + Reality" "$vless_link"
    
    # Вывод Shadowsocks ссылки
    local ss_base64=$(echo -n "2022-blake3-aes-128-gcm:${PASSWORD_SS}@${ip}:${PORT_SHADOWSOCKS}" | base64 -w 0)
    local ss_link="ss://${ss_base64}#${SERVER_NAME}"
    print_qr "Shadowsocks 2022" "$ss_link"
    
    # Вывод AmneziaWG конфига
    echo -e "${BLUE}AmneziaWG конфиг:${NC}"
    local amnezia_config=$(cat amnezia_client.conf)
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
    
    # Создаем файл построчно, чтобы избежать проблем с экранированием
    > "$guide_file" cat << EOF
ИНСТРУКЦИЯ ПО ПОДКЛЮЧЕНИЮ К VPN-СЕРВЕРУ
===================================

Ваш VPN-сервер успешно установлен и запущен!

ТЕКУЩИЙ IP-АДРЕС СЕРВЕРА: $ip

1. VLESS + REALITY
-------------------
Скопируйте следующую ссылку и добавьте в приложение:

$vless_link

Или отсканируйте QR-код с помощью приложения Hiddify / v2rayNG / Streisand:

Для генерации QR-кода используйте команду:
qrencode -t ansiutf8 "$vless_link"

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

Или отсканируйте QR-код с помощью приложения Hiddify / v2rayNG / Streisand:

Для генерации QR-кода используйте команду:
qrencode -t ansiutf8 "$ss_link"

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
    local running_containers=$(docker compose ps -q --filter "status=running" | wc -l)
    if [[ $running_containers -eq 0 ]]; then
        log_error "Нет запущенных контейнеров"
        return 1
    elif [[ $running_containers -lt 2 ]]; then
        log_warn "Не все контейнеры запущены. Работает только $running_containers из 2"
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
    check_dependency shuf coreutils
    check_qr_dependency
    
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

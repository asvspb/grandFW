#!/usr/bin/env bash

# Скрипт установки и управления мульти-протокольным VPN-сервером
# Поддерживаемые протоколы: VLESS+Reality, Shadowsocks-2022, AmneziaWG

set -euo pipefail

# Версия скрипта
readonly VERSION="3.0.0"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Загрузка библиотек
source "${SCRIPT_DIR}/../lib/common.sh"
source "${SCRIPT_DIR}/../lib/validation.sh"
source "${SCRIPT_DIR}/../lib/crypto.sh"
source "${SCRIPT_DIR}/../lib/env_loader.sh"
source "${SCRIPT_DIR}/../lib/docker.sh"
source "${SCRIPT_DIR}/../lib/firewall.sh"

# Глобальные переменные
readonly ENV_FILE="${SCRIPT_DIR}/../.env"
readonly ENV_TEMPLATE="${SCRIPT_DIR}/../.env.template"
readonly LOG_FILE="${SCRIPT_DIR}/../setup.log"
readonly BACKUP_DIR="${SCRIPT_DIR}/../backups"

# Значения по умолчанию (инициализируем переменные, чтобы избежать unbound variable)
PORT_VLESS=8443
PORT_SHADOWSOCKS=9443
PORT_AMNEZIAWG=51820
UUID=""
PRIVATE_KEY=""
PUBLIC_KEY=""
SHORT_ID=""
SERVER_NAME="www.google.com"
SNI="www.google.com"
EXTERNAL_IP=""
PASSWORD_SS=""
WG_SERVER_PRIVATE_KEY=""
WG_SERVER_PUBLIC_KEY=""
WG_CLIENT_PRIVATE_KEY=""
WG_CLIENT_PUBLIC_KEY=""
WG_PASSWORD=""
WG_JC=0
WG_JMIN=0
WG_JMAX=0
WG_S1=0
WG_S2=0
WG_H1=0
WG_H2=0
WG_H3=0
WG_H4=0

# Главная функция
main() {
    log_info "=== grandFW Setup v${VERSION} ==="

    # Проверка прав root
    check_root

    # Проверка зависимостей
    check_dependencies

    # Инициализация или загрузка конфигурации
    if [[ -f "$ENV_FILE" ]]; then
        log_info "Найден существующий файл .env"
        load_env_safe "$ENV_FILE"

        # Валидация существующих переменных
        if ! validate_env_vars; then
            log_warn "Обнаружены проблемы с переменными окружения"
            read -p "Пересоздать конфигурацию? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                backup_file "$ENV_FILE"
                initialize_config
            else
                log_error "Невозможно продолжить с некорректной конфигурацией"
                exit 1
            fi
        fi
    else
        log_info "Файл .env не найден, создаю новую конфигурацию"
        initialize_config
        # Загружаем переменные сразу после инициализации
        load_env_safe "$ENV_FILE"
    fi

    # Создание конфигурационных файлов
    create_configs
    prepare_configs

    # Настройка firewall
    setup_firewall "$PORT_VLESS" "$PORT_SHADOWSOCKS" "$PORT_AMNEZIAWG"

    # Запуск сервисов
    start_services

    # Проверка работоспособности
    health_check

    # Вывод информации для подключения
    show_connection_info

    log_info "=== Установка завершена успешно ==="
}

# Проверка зависимостей
check_dependencies() {
    log_info "Проверка зависимостей..."

    check_dependency "docker" "docker.io"
    check_dependency "docker-compose" "docker-compose"
    check_dependency "openssl" "openssl"
    check_dependency "curl" "curl"
    check_dependency "qrencode" "qrencode"
    check_dependency "ufw" "ufw"

    # Проверка WireGuard tools
    if ! command -v wg &> /dev/null; then
        log_warn "WireGuard tools не найдены, устанавливаю..."
        apt-get update -qq
        apt-get install -y wireguard-tools
    fi

    log_info "Все зависимости установлены"
}

# Инициализация конфигурации
initialize_config() {
    log_info "Инициализация конфигурации..."

    # Копирование шаблона
    if [[ ! -f "$ENV_TEMPLATE" ]]; then
        log_error "Файл шаблона $ENV_TEMPLATE не найден"
        exit 1
    fi

    cp "$ENV_TEMPLATE" "$ENV_FILE"

    # Генерация секретов
    generate_all_secrets

    # Получение внешнего IP
    local external_ip=$(get_external_ip)
    if [[ -z "$external_ip" ]]; then
        read -p "Введите внешний IP сервера: " external_ip
        validate_ip "$external_ip" || exit 1
    fi
    export EXTERNAL_IP="$external_ip"

    # Запрос имени сервера для SNI
    read -p "Введите доменное имя для SNI (например, www.google.com): " server_name
    export SERVER_NAME="${server_name:-www.google.com}"
    export SNI="$SERVER_NAME"

    # Сохранение в .env
    save_env_file

    # Установка безопасных прав доступа
    chmod 600 "$ENV_FILE"
    chown root:root "$ENV_FILE"

    log_info "Конфигурация инициализирована"
}

# Сохранение переменных в .env файл
save_env_file() {
    cat > "$ENV_FILE" << EOF
# grandFW Configuration
# Generated: $(date)
# Version: ${VERSION}

# Server Configuration
SERVER_NAME=${SERVER_NAME}
SNI=${SNI}
EXTERNAL_IP=${EXTERNAL_IP}

# Ports
PORT_VLESS=${PORT_VLESS:-8443}
PORT_SHADOWSOCKS=${PORT_SHADOWSOCKS:-9443}
PORT_AMNEZIAWG=${PORT_AMNEZIAWG:-51820}

# VLESS + Reality
UUID=${UUID}
PRIVATE_KEY=${PRIVATE_KEY}
PUBLIC_KEY=${PUBLIC_KEY}
SHORT_ID=${SHORT_ID}

# Shadowsocks-2022
PASSWORD_SS=${PASSWORD_SS}

# AmneziaWG
WG_SERVER_PRIVATE_KEY=${WG_SERVER_PRIVATE_KEY}
WG_SERVER_PUBLIC_KEY=${WG_SERVER_PUBLIC_KEY}
WG_CLIENT_PRIVATE_KEY=${WG_CLIENT_PRIVATE_KEY}
WG_CLIENT_PUBLIC_KEY=${WG_CLIENT_PUBLIC_KEY}
WG_PASSWORD=${WG_PASSWORD}

# AmneziaWG Obfuscation Parameters
WG_JC=${WG_JC}
WG_JMIN=${WG_JMIN}
WG_JMAX=${WG_JMAX}
WG_S1=${WG_S1}
WG_S2=${WG_S2}
WG_H1=${WG_H1}
WG_H2=${WG_H2}
WG_H3=${WG_H3}
WG_H4=${WG_H4}
EOF
}

# Создание шаблонов конфигурации (только если файлы не существуют)
create_configs() {
    log_info "Проверка/создание шаблонов конфигурационных файлов..."
    
    # Удаляем одноимённые директории, если они существуют
    rm -rf configs
    
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
          "dest": "${SNI}:443",
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
    
    # Создание docker-compose.yml (только если файл не существует)
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
    
    # Проверяем, что все необходимые переменные определены
    if [[ -z "${UUID:-}" ]] || [[ -z "${PRIVATE_KEY:-}" ]] || [[ -z "${PUBLIC_KEY:-}" ]] || [[ -z "${SHORT_ID:-}" ]] || [[ -z "${WG_CLIENT_PRIVATE_KEY:-}" ]] || [[ -z "${WG_SERVER_PRIVATE_KEY:-}" ]] || [[ -z "${WG_CLIENT_PUBLIC_KEY:-}" ]] || [[ -z "${WG_SERVER_PUBLIC_KEY:-}" ]] || [[ -z "${WG_PASSWORD:-}" ]] || [[ -z "${WG_JC:-}" ]] || [[ -z "${WG_JMIN:-}" ]] || [[ -z "${WG_JMAX:-}" ]] || [[ -z "${WG_S1:-}" ]] || [[ -z "${WG_S2:-}" ]] || [[ -z "${WG_H1:-}" ]] || [[ -z "${WG_H2:-}" ]] || [[ -z "${WG_H3:-}" ]] || [[ -z "${WG_H4:-}" ]]; then
        log_error "Не все необходимые переменные определены. Пожалуйста, проверьте файл .env"
        exit 1
    fi
    
    # Убедимся, что нет одноимённых директорий, которые могут помешать созданию файлов (КРИТИЧЕСКОЕ ИСПРАВЛЕНИЕ!)
    local files_to_check=(
        "$SCRIPT_DIR/../xray_config.json"
        "$SCRIPT_DIR/../amnezia_client.conf"
        "$SCRIPT_DIR/../amnezia_server.conf"
    )
    
    for item in "${files_to_check[@]}"; do
        if [[ -d "$item" ]]; then
            log_warn "Обнаружена директория вместо файла: $item. Удаляю..."
            rm -rf "$item"
        fi
    done
    
    # Подстановка значений в шаблоны
    if [[ -f "$SCRIPT_DIR/../configs/xray.json.template" ]]; then
        envsubst < "$SCRIPT_DIR/../configs/xray.json.template" > "$SCRIPT_DIR/../xray_config.json"
    else
        log_error "Шаблон конфигурации Xray не найден: configs/xray.json.template"
        exit 1
    fi
    
    # Создание конфигов для AmneziaWG
    # Клиентский конфиг (для импорта в приложение)
    cat > "$SCRIPT_DIR/../amnezia_client.conf" << EOF
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
Endpoint = ${EXTERNAL_IP}:${PORT_AMNEZIAWG}
PersistentKeepalive = 25
PresharedKey = $WG_PASSWORD
EOF
    
    # Серверный конфиг (для Docker контейнера)
    cat > "$SCRIPT_DIR/../amnezia_server.conf" << EOF
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

# Запуск сервисов
start_services() {
    log_info "Запуск VPN-сервисов..."
    
    docker_compose_up "$SCRIPT_DIR/../docker-compose.yml"
    
    # Ждем немного, чтобы контейнеры запустились
    sleep 5
    
    # Проверяем статус контейнеров
    docker compose -p "grandfw" ps
    
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
    
    # Проверяем, что все необходимые переменные определены
    if [[ -z "${UUID:-}" ]] || [[ -z "${PRIVATE_KEY:-}" ]] || [[ -z "${PUBLIC_KEY:-}" ]] || [[ -z "${SHORT_ID:-}" ]] || [[ -z "${WG_CLIENT_PRIVATE_KEY:-}" ]] || [[ -z "${WG_SERVER_PRIVATE_KEY:-}" ]] || [[ -z "${WG_CLIENT_PUBLIC_KEY:-}" ]] || [[ -z "${WG_SERVER_PUBLIC_KEY:-}" ]] || [[ -z "${WG_PASSWORD:-}" ]] || [[ -z "${WG_JC:-}" ]] || [[ -z "${WG_JMIN:-}" ]] || [[ -z "${WG_JMAX:-}" ]] || [[ -z "${WG_S1:-}" ]] || [[ -z "${WG_S2:-}" ]] || [[ -z "${WG_H1:-}" ]] || [[ -z "${WG_H2:-}" ]] || [[ -z "${WG_H3:-}" ]] || [[ -z "${WG_H4:-}" ]]; then
        log_error "Не все необходимые переменные определены. Пожалуйста, проверьте файл .env"
        exit 1
    fi
    
    # Загрузка переменных
    load_env_safe .env
    
    # Вывод VLESS ссылки
    local vless_link="vless://${UUID}@${EXTERNAL_IP}:${PORT_VLESS}?security=reality&sni=${SNI}&fp=chrome&type=tcp&flow=xtls-rprx-vision&sid=${SHORT_ID}#$SERVER_NAME"
    print_qr "VLESS + Reality" "$vless_link"
    
    # Вывод Shadowsocks ссылки
    local ss_base64=$(echo -n "2022-blake3-aes-128-gcm:${PASSWORD_SS}@${EXTERNAL_IP}:${PORT_SHADOWSOCKS}" | base64 -w 0)
    local ss_link="ss://${ss_base64}#${SERVER_NAME}"
    print_qr "Shadowsocks 2022" "$ss_link"
    
    # Вывод AmneziaWG конфига
    echo -e "${BLUE}AmneziaWG конфиг:${NC}"
    local amnezia_config=$(cat amnezia_client.conf)
    echo "$amnezia_config"
    echo ""
    
    log_info "Подключение к сервисам должно быть доступно в течение 30 секунд"
    
    # Создание файла с инструкциями и ссылками
    create_connection_guide "$EXTERNAL_IP" "$vless_link" "$ss_link" "$amnezia_config"
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

# Запуск главной функции
main "$@"

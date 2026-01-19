#!/usr/bin/env bash

# Скрипт для проверки работоспособности VPN-сервера

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

# Проверка, запущен ли Docker
check_docker_running() {
    log_info "Проверка состояния Docker..."
    if ! systemctl is-active --quiet docker; then
        log_error "Docker не запущен"
        return 1
    else
        log_info "Docker запущен"
    fi
}

# Проверка, запущены ли контейнеры
check_containers_running() {
    log_info "Проверка состояния контейнеров..."
    
    # Проверяем, есть ли файл docker-compose.yml
    if [[ ! -f docker-compose.yml ]]; then
        log_error "Файл docker-compose.yml не найден"
        return 1
    fi
    
    # Проверяем статус контейнеров
    local containers_status=$(docker compose ps --format "table {{.Name}}\t{{.State}}\t{{.Status}}" 2>/dev/null || true)
    
    if [[ -z "$containers_status" ]]; then
        log_error "Не удалось получить статус контейнеров"
        return 1
    else
        echo "$containers_status"
    fi
    
    # Проверяем, запущены ли контейнеры
    local running_containers=$(docker compose ps -q --filter "status=running" | wc -l)
    local total_containers=$(docker compose config --services | wc -l)
    
    if [[ $running_containers -eq 0 ]]; then
        log_error "Нет запущенных контейнеров"
        return 1
    elif [[ $running_containers -lt $total_containers ]]; then
        log_warn "Не все контейнеры запущены. Работает $running_containers из $total_containers"
        return 1
    else
        log_info "Все контейнеры работают корректно"
    fi
}

# Проверка портов
check_ports_open() {
    log_info "Проверка открытых портов..."
    
    # Загружаем переменные из .env
    if [[ -f .env ]]; then
        export $(grep -v '^#' .env | xargs)
    else
        log_warn "Файл .env не найден, используем значения по умолчанию"
        export PORT_VLESS=8443
        export PORT_SHADOWSOCKS=8443
        export PORT_AMNEZIAWG=51820
    fi
    
    # Проверяем, прослушиваются ли порты
    local ports_ok=true
    
    if ! netstat -tulnp 2>/dev/null | grep -q ":$PORT_VLESS "; then
        log_warn "Порт $PORT_VLESS не прослушивается"
        ports_ok=false
    else
        log_info "Порт $PORT_VLESS прослушивается"
    fi
    
    if ! netstat -tulnp 2>/dev/null | grep -q ":$PORT_SHADOWSOCKS "; then
        log_warn "Порт $PORT_SHADOWSOCKS не прослушивается"
        ports_ok=false
    else
        log_info "Порт $PORT_SHADOWSOCKS прослушивается"
    fi
    
    if ! netstat -ulnp 2>/dev/null | grep -q ":$PORT_AMNEZIAWG "; then
        log_warn "Порт $PORT_AMNEZIAWG не прослушивается"
        ports_ok=false
    else
        log_info "Порт $PORT_AMNEZIAWG прослушивается"
    fi
    
    if [[ "$ports_ok" == false ]]; then
        return 1
    fi
}

# Проверка конфигурационных файлов
check_config_files() {
    log_info "Проверка конфигурационных файлов..."
    
    local files_ok=true
    
    if [[ ! -f xray_config.json ]]; then
        log_error "Файл xray_config.json не найден"
        files_ok=false
    else
        log_info "Файл xray_config.json существует"
    fi
    
    if [[ ! -f amnezia_client.conf ]]; then
        log_error "Файл amnezia_client.conf не найден"
        files_ok=false
    else
        log_info "Файл amnezia_client.conf существует"
    fi
    
    if [[ ! -f amnezia_server.conf ]]; then
        log_error "Файл amnezia_server.conf не найден"
        files_ok=false
    else
        log_info "Файл amnezia_server.conf существует"
    fi
    
    # Проверяем, что конфигурационные файлы не пусты
    if [[ -f xray_config.json ]] && [[ ! -s xray_config.json ]]; then
        log_error "Файл xray_config.json пуст"
        files_ok=false
    fi
    
    if [[ -f amnezia_client.conf ]] && [[ ! -s amnezia_client.conf ]]; then
        log_error "Файл amnezia_client.conf пуст"
        files_ok=false
    fi
    
    if [[ -f amnezia_server.conf ]] && [[ ! -s amnezia_server.conf ]]; then
        log_error "Файл amnezia_server.conf пуст"
        files_ok=false
    fi
    
    if [[ "$files_ok" == false ]]; then
        return 1
    fi
}

# Проверка .env файла
check_env_file() {
    log_info "Проверка файла .env..."
    
    if [[ ! -f .env ]]; then
        log_error "Файл .env не найден"
        return 1
    fi
    
    # Загружаем переменные из .env
    export $(grep -v '^#' .env | xargs)
    
    # Проверяем, что все критические переменные определены
    local critical_vars=("UUID" "PRIVATE_KEY" "PUBLIC_KEY" "SHORT_ID" 
                        "WG_CLIENT_PRIVATE_KEY" "WG_SERVER_PRIVATE_KEY" 
                        "WG_CLIENT_PUBLIC_KEY" "WG_SERVER_PUBLIC_KEY" 
                        "WG_PASSWORD" "WG_JC" "WG_JMIN" "WG_JMAX" 
                        "WG_S1" "WG_S2" "WG_H1" "WG_H2" "WG_H3" "WG_H4")
    
    local env_ok=true
    
    for var in "${critical_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            log_error "Переменная $var не определена в .env"
            env_ok=false
        fi
    done
    
    if [[ "$env_ok" == false ]]; then
        return 1
    else
        log_info "Все критические переменные в .env определены"
    fi
}

# Основная функция проверки
main() {
    log_info "Начало проверки работоспособности VPN-сервера"
    
    local checks_passed=0
    local total_checks=6
    
    if check_docker_running; then
        ((checks_passed++))
    fi
    
    if check_containers_running; then
        ((checks_passed++))
    fi
    
    if check_ports_open; then
        ((checks_passed++))
    fi
    
    if check_config_files; then
        ((checks_passed++))
    fi
    
    if check_env_file; then
        ((checks_passed++))
    fi
    
    # Проверка, что все основные службы работают
    if docker compose ps --services | while read -r service; do
        if [[ -n "$service" ]]; then
            if docker compose exec "$service" ps aux >/dev/null 2>&1; then
                log_info "Служба $service отвечает"
            else
                log_warn "Служба $service не отвечает"
                continue
            fi
        fi
    done; then
        ((checks_passed++))
    fi
    
    log_info "Проверка завершена: $checks_passed/$total_checks тестов пройдено"
    
    if [[ $checks_passed -eq $total_checks ]]; then
        log_info "VPN-сервер работает корректно"
        exit 0
    else
        log_error "Обнаружены проблемы с VPN-сервером"
        exit 1
    fi
}

# Вызов основной функции
main "$@"
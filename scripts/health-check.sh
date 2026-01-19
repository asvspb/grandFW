#!/usr/bin/env bash

# Скрипт для проверки работоспособности VPN-сервера

set -euo pipefail

# Версия скрипта
readonly VERSION="3.0.0"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Загрузка библиотек
source "${SCRIPT_DIR}/../lib/common.sh"
source "${SCRIPT_DIR}/../lib/validation.sh"
source "${SCRIPT_DIR}/../lib/env_loader.sh"
source "${SCRIPT_DIR}/../lib/docker.sh"

# Константы Docker
readonly DOCKER_PROJECT_NAME="grandfw"
readonly DOCKER_COMPOSE_FILE="${PROJECT_ROOT}/docker-compose.yml"

# Основная функция проверки
main() {
    log_info "Начало проверки работоспособности VPN-сервера v${VERSION}"
    
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
    if check_services_respond; then
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
    if [[ ! -f "$DOCKER_COMPOSE_FILE" ]]; then
        log_error "Файл $DOCKER_COMPOSE_FILE не найден"
        return 1
    fi
    
    # Проверяем статус контейнеров
    local containers_status=$(docker compose -p "$DOCKER_PROJECT_NAME" -f "$DOCKER_COMPOSE_FILE" ps --format "table {{.Name}}\t{{.State}}\t{{.Status}}" 2>/dev/null || true)
    
    if [[ -z "$containers_status" ]]; then
        log_error "Не удалось получить статус контейнеров"
        return 1
    else
        echo "$containers_status"
    fi
    
    # Проверяем, запущены ли контейнеры
    local running_containers=$(docker compose -p "$DOCKER_PROJECT_NAME" -f "$DOCKER_COMPOSE_FILE" ps -q --filter "status=running" | wc -l)
    local total_containers=$(docker compose -p "$DOCKER_PROJECT_NAME" -f "$DOCKER_COMPOSE_FILE" config --services | wc -l 2>/dev/null || echo 2)
    
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
    
    # Загружаем переменные из .env безопасно
    local env_file="${PROJECT_ROOT}/.env"
    if [[ -f "$env_file" ]]; then
        load_env_safe "$env_file"
    else
        log_warn "Файл $env_file не найден, используем значения по умолчанию"
        export PORT_VLESS=8443
        export PORT_SHADOWSOCKS=9443
        export PORT_AMNEZIAWG=51820
    fi
    
    # Проверяем, прослушиваются ли порты
    local ports_ok=true
    
    if ! netstat -tulnp 2>/dev/null | grep -q ":${PORT_VLESS:-8443} "; then
        log_warn "Порт ${PORT_VLESS:-8443} не прослушивается"
        ports_ok=false
    else
        log_info "Порт ${PORT_VLESS:-8443} прослушивается"
    fi
    
    if ! netstat -tulnp 2>/dev/null | grep -q ":${PORT_SHADOWSOCKS:-9443} "; then
        log_warn "Порт ${PORT_SHADOWSOCKS:-9443} не прослушивается"
        ports_ok=false
    else
        log_info "Порт ${PORT_SHADOWSOCKS:-9443} прослушивается"
    fi
    
    if ! netstat -ulnp 2>/dev/null | grep -q ":${PORT_AMNEZIAWG:-51820} "; then
        log_warn "Порт ${PORT_AMNEZIAWG:-51820} не прослушивается"
        ports_ok=false
    else
        log_info "Порт ${PORT_AMNEZIAWG:-51820} прослушивается"
    fi
    
    if [[ "$ports_ok" == false ]]; then
        return 1
    fi
}

# Проверка конфигурационных файлов
check_config_files() {
    log_info "Проверка конфигурационных файлов..."
    
    local files_ok=true
    local xray_config="${PROJECT_ROOT}/xray_config.json"
    local amnezia_client="${PROJECT_ROOT}/amnezia_client.conf"
    local amnezia_server="${PROJECT_ROOT}/amnezia_server.conf"
    
    if [[ ! -f "$xray_config" ]]; then
        log_error "Файл $xray_config не найден"
        files_ok=false
    else
        log_info "Файл $xray_config существует"
    fi
    
    if [[ ! -f "$amnezia_client" ]]; then
        log_error "Файл $amnezia_client не найден"
        files_ok=false
    else
        log_info "Файл $amnezia_client существует"
    fi
    
    if [[ ! -f "$amnezia_server" ]]; then
        log_error "Файл $amnezia_server не найден"
        files_ok=false
    else
        log_info "Файл $amnezia_server существует"
    fi
    
    # Проверяем, что конфигурационные файлы не пусты
    if [[ -f "$xray_config" ]] && [[ ! -s "$xray_config" ]]; then
        log_error "Файл $xray_config пуст"
        files_ok=false
    fi
    
    if [[ -f "$amnezia_client" ]] && [[ ! -s "$amnezia_client" ]]; then
        log_error "Файл $amnezia_client пуст"
        files_ok=false
    fi
    
    if [[ -f "$amnezia_server" ]] && [[ ! -s "$amnezia_server" ]]; then
        log_error "Файл $amnezia_server пуст"
        files_ok=false
    fi
    
    if [[ "$files_ok" == false ]]; then
        return 1
    fi
}

# Проверка .env файла
check_env_file() {
    log_info "Проверка файла .env..."
    
    local env_file="${PROJECT_ROOT}/.env"
    if [[ ! -f "$env_file" ]]; then
        log_error "Файл $env_file не найден"
        return 1
    fi
    
    # Загружаем переменные из .env безопасно
    load_env_safe "$env_file"
    
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
    
    # Дополнительно проверим валидность ключевых параметров
    if [[ -n "${UUID:-}" ]]; then
        validate_uuid "$UUID" || {
            log_error "Невалидный UUID в .env"
            return 1
        }
    fi
    
    if [[ -n "${PORT_VLESS:-}" ]]; then
        validate_port "$PORT_VLESS" "PORT_VLESS" || {
            log_error "Невалидный PORT_VLESS в .env"
            return 1
        }
    fi
    
    if [[ -n "${PORT_SHADOWSOCKS:-}" ]]; then
        validate_port "$PORT_SHADOWSOCKS" "PORT_SHADOWSOCKS" || {
            log_error "Невалидный PORT_SHADOWSOCKS в .env"
            return 1
        }
    fi
    
    if [[ -n "${PORT_AMNEZIAWG:-}" ]]; then
        validate_port "$PORT_AMNEZIAWG" "PORT_AMNEZIAWG" || {
            log_error "Невалидный PORT_AMNEZIAWG в .env"
            return 1
        }
    fi
}

# Проверка, что службы отвечают
check_services_respond() {
    log_info "Проверка отклика служб..."
    
    local services_ok=true
    
    # Получаем список сервисов
    local services=$(docker compose -p "$DOCKER_PROJECT_NAME" -f "$DOCKER_COMPOSE_FILE" ps --services 2>/dev/null || echo "")
    
    if [[ -n "$services" ]]; then
        while read -r service; do
            if [[ -n "$service" ]]; then
                # Пропускаем сервисы, которые не предназначены для выполнения команд
                if [[ "$service" != *"amnezia"* ]]; then
                    if docker compose -p "$DOCKER_PROJECT_NAME" -f "$DOCKER_COMPOSE_FILE" exec "$service" ps aux >/dev/null 2>&1; then
                        log_info "Служба $service отвечает"
                    else
                        log_warn "Служба $service не отвечает"
                        services_ok=false
                    fi
                fi
            fi
        done <<< "$services"
    else
        log_warn "Не удалось получить список сервисов"
        services_ok=false
    fi
    
    if [[ "$services_ok" == false ]]; then
        return 1
    fi
}

# Вызов основной функции
main "$@"

#!/usr/bin/env bash
#
# lib/validation.sh - Функции валидации для grandFW
# Версия: 3.0.0
#

readonly LIB_VALIDATION_VERSION="3.0.0"

# Загрузка зависимостей
if [[ -z "${LIB_COMMON_VERSION}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    source "${SCRIPT_DIR}/common.sh"
fi

#######################################
# Валидация UUID v4
# Arguments:
#   $1 - UUID для проверки
# Returns:
#   0 - UUID валиден
#   1 - UUID невалиден
#######################################
validate_uuid() {
    local uuid=$1
    local uuid_regex='^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'

    if [[ -z "$uuid" ]]; then
        log_error "UUID пустой"
        return 1
    fi

    if [[ ! "$uuid" =~ $uuid_regex ]]; then
        log_error "Некорректный формат UUID: $uuid"
        log_debug "Ожидаемый формат: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (hex)"
        return 1
    fi

    log_debug "UUID валиден: $uuid"
    return 0
}

#######################################
# Валидация номера порта
# Arguments:
#   $1 - номер порта
#   $2 - имя порта для сообщений (опционально)
# Returns:
#   0 - порт валиден
#   1 - порт невалиден
#######################################
validate_port() {
    local port=$1
    local name=${2:-"Port"}

    if [[ -z "$port" ]]; then
        log_error "$name не указан"
        return 1
    fi

    if [[ ! "$port" =~ ^[0-9]+$ ]]; then
        log_error "$name должен быть числом: $port"
        return 1
    fi

    if [[ $port -lt 1 || $port -gt 65535 ]]; then
        log_error "$name вне допустимого диапазона (1-65535): $port"
        return 1
    fi

    log_debug "$name валиден: $port"
    return 0
}

#######################################
# Валидация IPv4 адреса
# Arguments:
#   $1 - IP адрес для проверки
# Returns:
#   0 - IP валиден
#   1 - IP невалиден
#######################################
validate_ip() {
    local ip=$1
    local ip_regex='^([0-9]{1,3}\.){3}[0-9]{1,3}$'

    if [[ -z "$ip" ]]; then
        log_error "IP адрес пустой"
        return 1
    fi

    if [[ ! "$ip" =~ $ip_regex ]]; then
        log_error "Некорректный формат IP адреса: $ip"
        return 1
    fi

    # Проверка каждого октета (должен быть 0-255)
    IFS='.' read -ra OCTETS <<< "$ip"
    for octet in "${OCTETS[@]}"; do
        if [[ $octet -gt 255 ]]; then
            log_error "Некорректный IP адрес: $ip (октет $octet > 255)"
            return 1
        fi
    done

    log_debug "IP адрес валиден: $ip"
    return 0
}

#######################################
# Проверка конфликтов портов
# Arguments:
#   $1 - имя массива с именами переменных портов
# Example:
#   ports=("PORT_VLESS" "PORT_SHADOWSOCKS")
#   check_port_conflicts ports
# Returns:
#   0 - конфликтов нет
#   1 - обнаружен конфликт
#######################################
check_port_conflicts() {
    local -n ports_array=$1
    local -A seen_ports=()
    local conflicts=0

    for port_var in "${ports_array[@]}"; do
        local port_value="${!port_var}"

        if [[ -z "$port_value" ]]; then
            log_warn "Переменная $port_var не определена"
            continue
        fi

        if [[ -n "${seen_ports[$port_value]+isset}" ]]; then
            log_error "Конфликт портов: $port_var ($port_value) конфликтует с ${seen_ports[$port_value]}"
            conflicts=1
        else
            seen_ports["$port_value"]="$port_var"
            log_debug "Порт $port_var=$port_value зарегистрирован"
        fi
    done

    return $conflicts
}

#######################################
# Валидация доменного имени
# Arguments:
#   $1 - доменное имя
# Returns:
#   0 - домен валиден
#   1 - домен невалиден
#######################################
validate_domain() {
    local domain=$1
    local domain_regex='^([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$'

    if [[ -z "$domain" ]]; then
        log_error "Доменное имя пустое"
        return 1
    fi

    if [[ ! "$domain" =~ $domain_regex ]]; then
        log_error "Некорректный формат доменного имени: $domain"
        return 1
    fi

    log_debug "Доменное имя валидно: $domain"
    return 0
}

#######################################
# Валидация base64 строки
# Arguments:
#   $1 - строка для проверки
#   $2 - ожидаемая длина (опционально)
# Returns:
#   0 - строка валидна
#   1 - строка невалидна
#######################################
validate_base64() {
    local str=$1
    local expected_length=$2

    if [[ -z "$str" ]]; then
        log_error "Base64 строка пустая"
        return 1
    fi

    # Проверка формата base64
    if ! echo "$str" | base64 -d &>/dev/null; then
        log_error "Некорректный формат base64"
        return 1
    fi

    # Проверка длины, если указана
    if [[ -n "$expected_length" ]]; then
        local actual_length=${#str}
        if [[ $actual_length -ne $expected_length ]]; then
            log_error "Некорректная длина base64 строки: $actual_length (ожидается $expected_length)"
            return 1
        fi
    fi

    log_debug "Base64 строка валидна"
    return 0
}

#######################################
# Валидация всех обязательных переменных окружения
# Globals:
#   Все переменные из .env файла
# Returns:
#   0 - все переменные валидны
#   1 - обнаружены проблемы
#######################################
validate_env_vars() {
    local errors=0

    log_info "Валидация переменных окружения..."

    # Список обязательных переменных
    local required_vars=(
        "UUID"
        "PRIVATE_KEY"
        "PUBLIC_KEY"
        "SHORT_ID"
        "SERVER_NAME"
        "SNI"
        "PORT_VLESS"
        "PORT_SHADOWSOCKS"
        "PORT_AMNEZIAWG"
        "PASSWORD_SS"
        "WG_CLIENT_PRIVATE_KEY"
        "WG_SERVER_PRIVATE_KEY"
        "WG_CLIENT_PUBLIC_KEY"
        "WG_SERVER_PUBLIC_KEY"
        "WG_PASSWORD"
    )

    # Проверка наличия всех переменных
    local missing_vars=()
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            missing_vars+=("$var")
            errors=1
        fi
    done

    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        log_error "Отсутствуют обязательные переменные: ${missing_vars[*]}"
    fi

    # Валидация UUID
    if [[ -n "${UUID:-}" ]]; then
        validate_uuid "$UUID" || errors=1
    fi

    # Валидация портов
    if [[ -n "${PORT_VLESS:-}" ]]; then
        validate_port "$PORT_VLESS" "PORT_VLESS" || errors=1
    fi

    if [[ -n "${PORT_SHADOWSOCKS:-}" ]]; then
        validate_port "$PORT_SHADOWSOCKS" "PORT_SHADOWSOCKS" || errors=1
    fi

    if [[ -n "${PORT_AMNEZIAWG:-}" ]]; then
        validate_port "$PORT_AMNEZIAWG" "PORT_AMNEZIAWG" || errors=1
    fi

    # Проверка конфликтов портов (только TCP порты)
    if [[ -n "${PORT_VLESS:-}" ]] && [[ -n "${PORT_SHADOWSOCKS:-}" ]]; then
        local tcp_ports=("PORT_VLESS" "PORT_SHADOWSOCKS")
        check_port_conflicts tcp_ports || errors=1
    fi

    # Валидация доменного имени
    if [[ -n "${SERVER_NAME:-}" ]]; then
        validate_domain "$SERVER_NAME" || log_warn "SERVER_NAME может быть некорректным доменом"
    fi

    if [[ $errors -eq 0 ]]; then
        log_info "Все переменные окружения валидны ✓"
        return 0
    else
        log_error "Обнаружены ошибки валидации"
        return 1
    fi
}

# Экспорт функций
export -f validate_uuid validate_port validate_ip validate_domain validate_base64
export -f check_port_conflicts validate_env_vars

log_debug "lib/validation.sh v${LIB_VALIDATION_VERSION} загружена"
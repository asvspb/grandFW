#!/usr/bin/env bash
#
# lib/crypto.sh - Криптографические функции для grandFW
# Версия: 3.0.3
#

readonly LIB_CRYPTO_VERSION="3.0.3"

# Загрузка зависимостей
if [[ -z "${LIB_COMMON_VERSION:-}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    source "${SCRIPT_DIR}/common.sh"
fi

#######################################
# Генерация UUID v4
# Outputs:
#   UUID в lowercase
# Returns:
#   0 - успех
#######################################
generate_uuid() {
    if command -v uuidgen &> /dev/null; then
        uuidgen | tr '[:upper:]' '[:lower:]'
    else
        # Fallback: генерация через /proc/sys/kernel/random/uuid
        if [[ -f /proc/sys/kernel/random/uuid ]]; then
            cat /proc/sys/kernel/random/uuid
        else
            log_error "Невозможно сгенерировать UUID: uuidgen не найден и /proc/sys/kernel/random/uuid недоступен"
            return 1
        fi
    fi
}

#######################################
# Генерация X25519 ключей для Reality
# Использует более надежный метод через DER формат
# Outputs:
#   Две строки: приватный ключ и публичный ключ (base64)
# Returns:
#   0 - успех
#   1 - ошибка генерации
#######################################
generate_x25519_keys() {
    local temp_dir=$(mktemp -d)
    local priv_key_file="${temp_dir}/priv.key"
    
    # Генерация приватного ключа
    if ! openssl genpkey -algorithm X25519 -out "$priv_key_file" 2>/dev/null; then
        log_error "Ошибка генерации X25519 ключа"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Извлечение сырого приватного ключа (последние 32 байта DER формата)
    local priv_base64=$(openssl pkey -in "$priv_key_file" -outform DER 2>/dev/null | tail -c 32 | base64 -w 0)
    
    # Извлечение сырого публичного ключа (последние 32 байта DER формата)
    local pub_base64=$(openssl pkey -in "$priv_key_file" -pubout -outform DER 2>/dev/null | tail -c 32 | base64 -w 0)
    
    rm -rf "$temp_dir"
    
    if [[ ${#priv_base64} -ne 44 ]] || [[ ${#pub_base64} -ne 44 ]]; then
        log_error "Ошибка: сгенерированные X25519 ключи имеют некорректную длину (${#priv_base64}/${#pub_base64})"
        return 1
    fi
    
    echo "$priv_base64"
    echo "$pub_base64"
    return 0
}

#######################################
# Генерация короткого ID (8 hex символов)
# Outputs:
#   8-символьная hex строка
#######################################
generate_short_id() {
    openssl rand -hex 4
}

#######################################
# Генерация пароля для Shadowsocks-2022
# Outputs:
#   Base64 строка (32 байта)
#######################################
generate_ss_password() {
    openssl rand -base64 32
}

#######################################
# Генерация WireGuard ключей
# Outputs:
#   Две строки: приватный ключ и публичный ключ
# Returns:
#   0 - успех
#   1 - wg команда не найдена
#######################################
generate_wg_keys() {
    if ! command -v wg &> /dev/null; then
        log_error "Команда wg не найдена. Установите wireguard-tools"
        return 1
    fi

    local private_key=$(wg genkey | tr -d '[:space:]')
    local public_key=$(echo "$private_key" | wg pubkey | tr -d '[:space:]')

    if [[ ${#private_key} -ne 44 ]] || [[ ${#public_key} -ne 44 ]]; then
        log_error "Ошибка: сгенерированные WireGuard ключи имеют некорректную длину (${#private_key}/${#public_key})"
        return 1
    fi

    echo "$private_key"
    echo "$public_key"
    return 0
}

#######################################
# Генерация WireGuard preshared key
# Outputs:
#   Preshared key
# Returns:
#   0 - успех
#   1 - wg команда не найдена
#######################################
generate_wg_preshared() {
    if ! command -v wg &> /dev/null; then
        log_error "Команда wg не найдена. Установите wireguard-tools"
        return 1
    fi

    local psk=$(wg genpsk | tr -d '[:space:]')
    if [[ ${#psk} -ne 44 ]]; then
        log_error "Ошибка: сгенерированный WireGuard PSK имеет некорректную длину (${#psk})"
        return 1
    fi
    echo "$psk"
    return 0
}

#######################################
# Генерация случайного числа в диапазоне
# Arguments:
#   $1 - минимальное значение (включительно)
#   $2 - максимальное значение (включительно)
# Outputs:
#   Случайное число
#######################################
generate_random_number() {
    local min=$1
    local max=$2
    echo $((RANDOM % (max - min + 1) + min))
}

#######################################
# Генерация всех секретов для проекта
# Globals:
#   Экспортирует все сгенерированные переменные
# Returns:
#   0 - успех
#   1 - ошибка генерации
#######################################
generate_all_secrets() {
    log_info "Генерация криптографических параметров..."

    # UUID для VLESS
    log_debug "Генерация UUID..."
    UUID=$(generate_uuid) || return 1
    export UUID
    log_debug "UUID: $UUID"

    # X25519 ключи для Reality
    log_debug "Генерация X25519 ключей..."
    local x25519_keys=($(generate_x25519_keys)) || return 1
    PRIVATE_KEY="${x25519_keys[0]}"
    PUBLIC_KEY="${x25519_keys[1]}"
    export PRIVATE_KEY PUBLIC_KEY
    log_debug "X25519 ключи сгенерированы"

    # Short ID
    log_debug "Генерация Short ID..."
    SHORT_ID=$(generate_short_id)
    export SHORT_ID
    log_debug "Short ID: $SHORT_ID"

    # Shadowsocks пароль
    log_debug "Генерация Shadowsocks пароля..."
    PASSWORD_SS=$(generate_ss_password)
    export PASSWORD_SS
    log_debug "Shadowsocks пароль сгенерирован"

    # WireGuard ключи сервера
    log_debug "Генерация WireGuard ключей сервера..."
    local wg_server_keys=($(generate_wg_keys)) || return 1
    WG_SERVER_PRIVATE_KEY="${wg_server_keys[0]}"
    WG_SERVER_PUBLIC_KEY="${wg_server_keys[1]}"
    export WG_SERVER_PRIVATE_KEY WG_SERVER_PUBLIC_KEY
    log_debug "WireGuard ключи сервера сгенерированы"

    # WireGuard ключи клиента
    log_debug "Генерация WireGuard ключей клиента..."
    local wg_client_keys=($(generate_wg_keys)) || return 1
    WG_CLIENT_PRIVATE_KEY="${wg_client_keys[0]}"
    WG_CLIENT_PUBLIC_KEY="${wg_client_keys[1]}"
    export WG_CLIENT_PRIVATE_KEY WG_CLIENT_PUBLIC_KEY
    log_debug "WireGuard ключи клиента сгенерированы"

    # WireGuard preshared key
    log_debug "Генерация WireGuard preshared key..."
    WG_PASSWORD=$(generate_wg_preshared) || return 1
    export WG_PASSWORD
    log_debug "WireGuard preshared key сгенерирован"

    # AmneziaWG параметры обфускации
    log_debug "Генерация AmneziaWG параметров обфускации..."
    WG_JC=$(generate_random_number 3 10)
    WG_JMIN=$(generate_random_number 50 100)
    WG_JMAX=$(generate_random_number 1000 1500)
    WG_S1=$(generate_random_number 10 100)
    WG_S2=$(generate_random_number 10 100)
    WG_H1=$(generate_random_number 1 4294967295)
    WG_H2=$(generate_random_number 1 4294967295)
    WG_H3=$(generate_random_number 1 4294967295)
    WG_H4=$(generate_random_number 1 4294967295)

    export WG_JC WG_JMIN WG_JMAX WG_S1 WG_S2 WG_H1 WG_H2 WG_H3 WG_H4
    log_debug "AmneziaWG параметры обфускации сгенерированы"

    # Установка портов по умолчанию, если они не заданы
    export PORT_VLESS="${PORT_VLESS:-8443}"
    export PORT_SHADOWSOCKS="${PORT_SHADOWSOCKS:-9443}"
    export PORT_AMNEZIAWG="${PORT_AMNEZIAWG:-51820}"

    log_info "Все криптографические параметры успешно сгенерированы ✓"
    return 0
}

# Экспорт функций
export -f generate_uuid generate_x25519_keys generate_short_id
export -f generate_ss_password generate_wg_keys generate_wg_preshared
export -f generate_random_number generate_all_secrets

log_debug "lib/crypto.sh v${LIB_CRYPTO_VERSION} загружена"

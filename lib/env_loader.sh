#!/usr/bin/env bash
#
# lib/env_loader.sh - Безопасная загрузка переменных окружения
# Версия: 3.0.0
#

readonly LIB_ENV_LOADER_VERSION="3.0.0"

# Загрузка зависимостей
if [[ -z "${LIB_COMMON_VERSION}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    source "${SCRIPT_DIR}/common.sh"
fi

#######################################
# Безопасная загрузка переменных из .env файла
# Предотвращает command injection
# Arguments:
#   $1 - путь к .env файлу (по умолчанию .env)
# Returns:
#   0 - успех
#   1 - файл не найден или ошибка чтения
#######################################
load_env_safe() {
    local env_file="${1:-.env}"

    if [[ ! -f "$env_file" ]]; then
        log_error "Файл $env_file не найден"
        return 1
    fi

    log_debug "Загрузка переменных из $env_file..."

    local line_number=0
    local loaded_count=0

    while IFS='=' read -r key value || [[ -n "$key" ]]; do
        line_number=$((line_number + 1))

        # Пропускаем пустые строки
        [[ -z "$key" ]] && continue

        # Пропускаем комментарии
        [[ "$key" =~ ^[[:space:]]*# ]] && continue

        # Удаляем пробелы в начале и конце ключа
        key=$(echo "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

        # Пропускаем, если ключ пустой после обрезки
        [[ -z "$key" ]] && continue

        # Удаляем пробелы в начале значения
        value=$(echo "$value" | sed 's/^[[:space:]]*//')

        # Удаляем кавычки из значения (если есть)
        if [[ "$value" =~ ^\"(.*)\"$ ]]; then
            value="${BASH_REMATCH[1]}"
        elif [[ "$value" =~ ^\'(.*)\'$ ]]; then
            value="${BASH_REMATCH[1]}"
        fi

        # Экспортируем переменную БЕЗ выполнения команд
        # Используем declare вместо export для безопасности
        export "$key=$value"
        loaded_count=$((loaded_count + 1))

        log_debug "Загружена переменная: $key"

    done < "$env_file"

    log_info "Загружено $loaded_count переменных из $env_file ✓"
    return 0
}

#######################################
# Сохранение переменных окружения в .env файл
# Arguments:
#   $1 - путь к .env файлу (по умолчанию .env)
# Globals:
#   Все переменные, которые нужно сохранить
# Returns:
#   0 - успех
#   1 - ошибка записи
#######################################
save_env_file() {
    local env_file="${1:-.env}"
    local version="${VERSION:-3.0.0}"

    log_info "Сохранение конфигурации в $env_file..."

    cat > "$env_file" << EOF
# grandFW Configuration
# Generated: $(date)
# Version: ${version}

# Server Configuration
SERVER_NAME=${SERVER_NAME:-}
SNI=${SNI:-}
EXTERNAL_IP=${EXTERNAL_IP:-}

# Ports
PORT_VLESS=${PORT_VLESS:-8443}
PORT_SHADOWSOCKS=${PORT_SHADOWSOCKS:-9443}
PORT_AMNEZIAWG=${PORT_AMNEZIAWG:-51820}

# VLESS + Reality
UUID=${UUID:-}
PRIVATE_KEY=${PRIVATE_KEY:-}
PUBLIC_KEY=${PUBLIC_KEY:-}
SHORT_ID=${SHORT_ID:-}

# Shadowsocks-2022
PASSWORD_SS=${PASSWORD_SS:-}

# AmneziaWG Keys
WG_SERVER_PRIVATE_KEY=${WG_SERVER_PRIVATE_KEY:-}
WG_SERVER_PUBLIC_KEY=${WG_SERVER_PUBLIC_KEY:-}
WG_CLIENT_PRIVATE_KEY=${WG_CLIENT_PRIVATE_KEY:-}
WG_CLIENT_PUBLIC_KEY=${WG_CLIENT_PUBLIC_KEY:-}
WG_PASSWORD=${WG_PASSWORD:-}

# AmneziaWG Obfuscation Parameters
WG_JC=${WG_JC:-}
WG_JMIN=${WG_JMIN:-}
WG_JMAX=${WG_JMAX:-}
WG_S1=${WG_S1:-}
WG_S2=${WG_S2:-}
WG_H1=${WG_H1:-}
WG_H2=${WG_H2:-}
WG_H3=${WG_H3:-}
WG_H4=${WG_H4:-}
EOF

    if [[ $? -eq 0 ]]; then
        # Установка безопасных прав доступа
        chmod 600 "$env_file"
        chown root:root "$env_file" 2>/dev/null || true
        log_info "Конфигурация сохранена в $env_file (права 600) ✓"
        return 0
    else
        log_error "Ошибка сохранения конфигурации в $env_file"
        return 1
    fi
}

# Экспорт функций
export -f load_env_safe save_env_file

log_debug "lib/env_loader.sh v${LIB_ENV_LOADER_VERSION} загружена"
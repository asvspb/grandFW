#!/usr/bin/env bash
#
# lib/firewall.sh - Функции для настройки UFW
# Версия: 3.0.0
#

readonly LIB_FIREWALL_VERSION="3.0.0"

# Загрузка зависимостей
if [[ -z "${LIB_COMMON_VERSION}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    source "${SCRIPT_DIR}/common.sh"
fi

#######################################
# Настройка базовых правил UFW
# Arguments:
#   $1 - порт VLESS (TCP)
#   $2 - порт Shadowsocks (TCP)
#   $3 - порт AmneziaWG (UDP)
#######################################
setup_firewall() {
    local port_vless=$1
    local port_shadowsocks=$2
    local port_amneziawg=$3

    log_info "Настройка firewall (UFW)..."

    # Проверка установки UFW
    if ! command -v ufw &> /dev/null; then
        log_warn "UFW не установлен, устанавливаю..."
        apt-get update -qq && apt-get install -y ufw || {
            log_error "Не удалось установить UFW"
            return 1
        }
    fi

    # Разрешаем SSH (чтобы не потерять доступ)
    log_debug "Разрешаю SSH (порт 22)..."
    ufw allow 22/tcp comment 'SSH' || log_warn "Не удалось добавить правило для SSH"

    # Разрешаем VLESS
    if [[ -n "$port_vless" ]]; then
        log_debug "Разрешаю VLESS (порт $port_vless/tcp)..."
        ufw allow "$port_vless/tcp" comment 'VLESS+Reality' || {
            log_error "Не удалось добавить правило для VLESS"
            return 1
        }
    fi

    # Разрешаем Shadowsocks
    if [[ -n "$port_shadowsocks" ]]; then
        log_debug "Разрешаю Shadowsocks (порт $port_shadowsocks/tcp)..."
        ufw allow "$port_shadowsocks/tcp" comment 'Shadowsocks-2022' || {
            log_error "Не удалось добавить правило для Shadowsocks"
            return 1
        }
    fi

    # Разрешаем AmneziaWG (КРИТИЧЕСКОЕ ИСПРАВЛЕНИЕ!)
    if [[ -n "$port_amneziawg" ]]; then
        log_debug "Разрешаю AmneziaWG (порт $port_amneziawg/udp)..."
        ufw allow "$port_amneziawg/udp" comment 'AmneziaWG' || {
            log_error "Не удалось добавить правило для AmneziaWG"
            return 1
        }
    fi

    # Включаем UFW (если еще не включен)
    if ! ufw status | grep -q "Status: active"; then
        log_info "Включаю UFW..."
        echo "y" | ufw enable || {
            log_error "Не удалось включить UFW"
            return 1
        }
    fi

    log_info "Firewall настроен успешно ✓"
    ufw status numbered
    return 0
}

#######################################
# Открытие порта
# Arguments:
#   $1 - номер порта
#   $2 - протокол (tcp/udp)
#   $3 - комментарий (опционально)
#######################################
open_port() {
    local port=$1
    local protocol=$2
    local comment=${3:-"Custom port"}

    log_info "Открываю порт $port/$protocol..."

    if ufw allow "$port/$protocol" comment "$comment"; then
        log_info "Порт $port/$protocol открыт ✓"
        return 0
    else
        log_error "Не удалось открыть порт $port/$protocol"
        return 1
    fi
}

#######################################
# Закрытие порта
# Arguments:
#   $1 - номер порта
#   $2 - протокол (tcp/udp)
#######################################
close_port() {
    local port=$1
    local protocol=$2

    log_info "Закрываю порт $port/$protocol..."

    if ufw delete allow "$port/$protocol"; then
        log_info "Порт $port/$protocol закрыт ✓"
        return 0
    else
        log_warn "Не удалось закрыть порт $port/$protocol (возможно, правило не существует)"
        return 1
    fi
}

export -f setup_firewall open_port close_port

log_debug "lib/firewall.sh v${LIB_FIREWALL_VERSION} загружена"
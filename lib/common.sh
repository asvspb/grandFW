#!/usr/bin/env bash
#
# lib/common.sh - Общие функции для grandFW
# Версия: 3.0.0
#

# Версия библиотеки
readonly LIB_COMMON_VERSION="3.0.0"

# Цвета для вывода
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Глобальные переменные (могут быть переопределены)
LOG_FILE="${LOG_FILE:-/var/log/grandfw.log}"
DEBUG="${DEBUG:-false}"

#######################################
# Базовая функция логирования
# Arguments:
#   $1 - сообщение для логирования
# Outputs:
#   Пишет в stdout и в LOG_FILE (если определен)
#######################################
log() {
    local message="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo -e "$message"
    
    # Логирование в файл, если LOG_FILE определен и доступен для записи
    if [[ -n "${LOG_FILE}" ]] && [[ -w "$(dirname "${LOG_FILE}")" || -w "${LOG_FILE}" ]]; then
        echo -e "$message" >> "${LOG_FILE}" 2>/dev/null || true
    fi
}

#######################################
# Логирование информационного сообщения
#######################################
log_info() {
    log "${GREEN}[INFO]${NC} $1"
}

#######################################
# Логирование предупреждения
#######################################
log_warn() {
    log "${YELLOW}[WARN]${NC} $1"
}

#######################################
# Логирование ошибки
#######################################
log_error() {
    log "${RED}[ERROR]${NC} $1" >&2
}

#######################################
# Логирование отладочного сообщения
# Выводится только если DEBUG=true
#######################################
log_debug() {
    if [[ "${DEBUG}" == "true" ]]; then
        log "${BLUE}[DEBUG]${NC} $1"
    fi
}

#######################################
# Проверка прав суперпользователя
# Exits:
#   1 - если скрипт запущен не от root
#######################################
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Этот скрипт должен быть запущен с правами суперпользователя (sudo)"
        exit 1
    fi
    log_debug "Проверка прав root: OK"
}

#######################################
# Проверка наличия команды и установка пакета при необходимости
# Arguments:
#   $1 - имя команды для проверки
#   $2 - имя пакета для установки
# Returns:
#   0 - команда доступна или успешно установлена
#   1 - ошибка установки
#######################################
check_dependency() {
    local cmd=$1
    local package=$2
    
    if ! command -v "$cmd" &> /dev/null; then
        log_warn "$cmd не найден. Устанавливаю пакет $package..."
        
        if apt-get update -qq && apt-get install -y "$package"; then
            log_info "$package успешно установлен"
            return 0
        else
            log_error "Не удалось установить $package"
            return 1
        fi
    else
        log_debug "$cmd найден: $(command -v "$cmd")"
        return 0
    fi
}

#######################################
# Создание резервной копии файла
# Arguments:
#   $1 - путь к файлу для резервного копирования
# Globals:
#   BACKUP_DIR - директория для резервных копий (по умолчанию ./backups)
# Returns:
#   0 - резервная копия создана или файл не существует
#   1 - ошибка создания резервной копии
#######################################
backup_file() {
    local file=$1
    local backup_dir="${BACKUP_DIR:-./backups}"
    
    if [[ ! -f "$file" ]]; then
        log_debug "Файл $file не существует, резервная копия не требуется"
        return 0
    fi
    
    # Создаем директорию для резервных копий
    if ! mkdir -p "$backup_dir"; then
        log_error "Не удалось создать директорию для резервных копий: $backup_dir"
        return 1
    fi
    
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="${backup_dir}/$(basename "$file").${timestamp}.bak"
    
    if cp "$file" "$backup_file"; then
        log_info "Создана резервная копия: $backup_file"
        return 0
    else
        log_error "Не удалось создать резервную копию файла $file"
        return 1
    fi
}

#######################################
# Получение внешнего IP адреса с fallback
# Пробует несколько сервисов для надежности
# Outputs:
#   Внешний IP адрес
# Returns:
#   0 - IP успешно получен
#   1 - не удалось получить IP ни от одного сервиса
#######################################
get_external_ip() {
    local ip=""
    local services=(
        "https://api.ipify.org"
        "https://ifconfig.me/ip"
        "https://icanhazip.com"
        "https://api.my-ip.io/ip"
    )

    log_debug "Попытка получить внешний IP адрес..."

    for service in "${services[@]}"; do
        log_debug "Пробую сервис: $service"
        ip=$(curl -s --fail --max-time 5 "$service" 2>/dev/null | tr -d '[:space:]')

        # Проверяем, что получили валидный IPv4
        if [[ -n "$ip" ]] && [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            log_debug "Получен внешний IP: $ip (источник: $service)"
            echo "$ip"
            return 0
        fi
    done

    log_error "Не удалось получить внешний IP автоматически ни от одного сервиса"
    return 1
}

#######################################
# Проверка доступности порта
# Arguments:
#   $1 - номер порта
#   $2 - протокол (tcp/udp, по умолчанию tcp)
# Returns:
#   0 - порт свободен
#   1 - порт занят
#######################################
check_port_available() {
    local port=$1
    local protocol=${2:-tcp}

    if command -v ss &> /dev/null; then
        # Используем ss (современная замена netstat)
        if ss -ln | grep -q ":${port} "; then
            log_debug "Порт $port/$protocol занят"
            return 1
        fi
    elif command -v netstat &> /dev/null; then
        # Fallback на netstat
        if netstat -ln | grep -q ":${port} "; then
            log_debug "Порт $port/$protocol занят"
            return 1
        fi
    else
        log_warn "Ни ss, ни netstat не найдены, невозможно проверить порт"
        return 0  # Предполагаем, что порт свободен
    fi

    log_debug "Порт $port/$protocol свободен"
    return 0
}

#######################################
# Запрос подтверждения у пользователя
# Arguments:
#   $1 - сообщение для отображения
#   $2 - значение по умолчанию (y/n, опционально)
# Returns:
#   0 - пользователь ответил "yes"
#   1 - пользователь ответил "no"
#######################################
confirm() {
    local message=$1
    local default=${2:-n}
    local prompt

    if [[ "$default" == "y" ]]; then
        prompt="[Y/n]"
    else
        prompt="[y/N]"
    fi

    read -p "$message $prompt: " -n 1 -r
    echo

    if [[ -z "$REPLY" ]]; then
        [[ "$default" == "y" ]] && return 0 || return 1
    fi

    [[ $REPLY =~ ^[Yy]$ ]] && return 0 || return 1
}

# Экспорт функций для использования в других скриптах
export -f log log_info log_warn log_error log_debug
export -f check_root check_dependency backup_file
export -f get_external_ip check_port_available confirm

log_debug "lib/common.sh v${LIB_COMMON_VERSION} загружена"
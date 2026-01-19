#!/usr/bin/env bash
#
# lib/docker.sh - Функции для работы с Docker
# Версия: 3.0.1
#

readonly LIB_DOCKER_VERSION="3.0.1"

# Загрузка зависимостей
if [[ -z "${LIB_COMMON_VERSION:-}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    source "${SCRIPT_DIR}/common.sh"
fi

# Константы
readonly DOCKER_PROJECT_NAME="grandfw"

#######################################
# Проверка установки Docker
#######################################
check_docker_installed() {
    if ! command -v docker &> /dev/null; then
        log_error "Docker не установлен"
        return 1
    fi
    log_debug "Docker установлен: $(docker --version)"
    return 0
}

#######################################
# Проверка работы Docker daemon
#######################################
check_docker_running() {
    if ! docker info &> /dev/null; then
        log_error "Docker daemon не запущен"
        return 1
    fi
    log_debug "Docker daemon работает"
    return 0
}

#######################################
# Удаление конфликтующих контейнеров
# Arguments:
#   $@ - имена контейнеров для проверки
#######################################
cleanup_conflicting_containers() {
    local containers=("$@")
    
    for name in "${containers[@]}"; do
        if docker ps -a --format '{{.Names}}' | grep -q "^${name}$"; then
            log_warn "Обнаружен конфликтующий контейнер: $name. Удаляю..."
            docker rm -f "$name" >/dev/null 2>&1 || log_error "Не удалось удалить контейнер $name"
        fi
    done
}

#######################################
# Запуск контейнеров через Docker Compose
# Arguments:
#   $1 - путь к docker-compose.yml (опционально)
#######################################
docker_compose_up() {
    local compose_file="${1:-docker-compose.yml}"

    log_info "Запуск контейнеров (проект: $DOCKER_PROJECT_NAME)..."

    # Очистка перед запуском
    cleanup_conflicting_containers "xray-core" "amnezia-wg"

    if docker compose -p "$DOCKER_PROJECT_NAME" -f "$compose_file" up -d; then
        log_info "Контейнеры успешно запущены ✓"
        return 0
    else
        log_error "Ошибка запуска контейнеров"
        return 1
    fi
}

#######################################
# Остановка контейнеров
#######################################
docker_compose_down() {
    local compose_file="${1:-docker-compose.yml}"

    log_info "Остановка контейнеров..."

    if docker compose -p "$DOCKER_PROJECT_NAME" -f "$compose_file" down; then
        log_info "Контейнеры остановлены ✓"
        return 0
    else
        log_error "Ошибка остановки контейнеров"
        return 1
    fi
}

#######################################
# Перезапуск контейнеров
#######################################
docker_compose_restart() {
    local compose_file="${1:-docker-compose.yml}"

    log_info "Перезапуск контейнеров..."

    if docker compose -p "$DOCKER_PROJECT_NAME" -f "$compose_file" restart; then
        log_info "Контейнеры перезапущены ✓"
        return 0
    else
        log_error "Ошибка перезапуска контейнеров"
        return 1
    fi
}

#######################################
# Получение статуса контейнера
# Arguments:
#   $1 - имя контейнера
#######################################
get_container_status() {
    local container_name=$1
    docker ps --filter "name=$container_name" --format "{{.Status}}"
}

export -f check_docker_installed check_docker_running
export -f cleanup_conflicting_containers
export -f docker_compose_up docker_compose_down docker_compose_restart
export -f get_container_status

log_debug "lib/docker.sh v${LIB_DOCKER_VERSION} загружена"

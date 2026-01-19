# Примеры использования grandFW

## Установка VPN-сервера

### Базовая установка

```bash
# Клонирование репозитория
git clone https://github.com/asvspb/grandFW.git
cd grandFW

# Запуск установки
sudo ./setup.sh
```

### Повторный запуск для получения информации о подключении

```bash
# Повторный запуск скрипта для получения информации о подключении
sudo ./setup.sh
```

## Структура файлов после установки

После успешной установки будут созданы следующие файлы:

```
grandFW/
├── .env                    # Конфиденциальные параметры (600 права)
├── xray_config.json        # Конфигурация Xray
├── amnezia_client.conf     # Конфигурация клиента AmneziaWG
├── amnezia_server.conf     # Конфигурация сервера AmneziaWG
├── connection_guide.txt    # Инструкция по подключению
├── docker-compose.yml      # Docker Compose конфигурация
├── configs/                # Директория с шаблонами
│   └── xray.json.template  # Шаблон конфигурации Xray
└── scripts/                # Скрипты управления
    ├── health-check.sh     # Проверка работоспособности
    ├── update.sh           # Обновление конфигурации
    ├── backup.sh           # Резервное копирование
    └── uninstall.sh        # Удаление
```

## Проверка работоспособности

```bash
# Запуск скрипта проверки
sudo ./scripts/health-check.sh

# Или запуск тестов
./tests/run_tests.sh all
```

## Управление сервисами

### Просмотр статуса контейнеров

```bash
# Проверка статуса контейнеров
docker compose -p grandfw ps

# Проверка статуса конкретного контейнера
docker compose -p grandfw ps xray
docker compose -p grandfw ps amnezia-wg
```

### Просмотр логов

```bash
# Логи Xray
docker compose -p grandfw logs xray

# Логи AmneziaWG
docker compose -p grandfw logs amnezia-wg

# Логи с отслеживанием новых записей
docker compose -p grandfw logs -f xray
```

### Управление сервисами

```bash
# Остановка сервисов
docker compose -p grandfw down

# Запуск сервисов
docker compose -p grandfw up -d

# Перезапуск сервисов
docker compose -p grandfw restart

# Перезапуск конкретного контейнера
docker compose -p grandfw restart xray
```

## Порты, используемые системой

- `8443/TCP` - VLESS + REALITY
- `9443/TCP и 9443/UDP` - Shadowsocks-2022
- `51820/UDP` - AmneziaWG (совместимый с WireGuard)

### Проверка открытых портов

```bash
# Проверка состояния firewall
sudo ufw status

# Проверка прослушиваемых портов
sudo ss -tulnp | grep -E "(8443|9443|51820)"
```

## Файлы конфигурации

### .env

Файл `.env` содержит все криптографические параметры и настройки:

```env
# Конфигурация сервера
SERVER_NAME=www.google.com
SNI=www.google.com
EXTERNAL_IP=1.2.3.4

# Порты
PORT_VLESS=8443
PORT_SHADOWSOCKS=9443
PORT_AMNEZIAWG=51820

# Параметры VLESS + Reality
UUID=550e8400-e29b-41d4-a716-446655440000
PRIVATE_KEY=...
PUBLIC_KEY=...
SHORT_ID=...

# Параметры Shadowsocks-2022
PASSWORD_SS=...

# Параметры AmneziaWG
WG_CLIENT_PRIVATE_KEY=...
WG_SERVER_PRIVATE_KEY=...
WG_CLIENT_PUBLIC_KEY=...
WG_SERVER_PUBLIC_KEY=...
WG_PASSWORD=...
WG_JC=...
WG_JMIN=...
WG_JMAX=...
WG_S1=...
WG_S2=...
WG_H1=...
WG_H2=...
WG_H3=...
WG_H4=...
```

## Поддерживаемые клиенты

### VLESS + REALITY

- **Android**: Hiddify, v2rayNG, Shadowrocket, Qv2ray
- **iOS**: v2rayNG, Shadowrocket, Quantumult X, Loon
- **Windows**: Qv2ray, v2rayN
- **macOS**: Qv2ray, ClashX
- **Linux**: Qv2ray

### Shadowsocks-2022

- **Android**: Shadowsocks, v2rayNG
- **iOS**: Shadowrocket, Shadowsocks
- **Windows**: Shadowsocks Windows
- **macOS**: ShadowsocksX-NG
- **Linux**: shadowsocks-rust

### AmneziaWG

- **Все платформы**: AmneziaVPN (https://amnezia.org/)

## Работа с библиотеками

### Пример использования библиотек в скриптах

```bash
#!/usr/bin/env bash
# Пример использования библиотек

# Загрузка библиотек
source lib/common.sh
source lib/validation.sh
source lib/crypto.sh
source lib/env_loader.sh
source lib/docker.sh
source lib/firewall.sh

# Пример использования функций
log_info "Начало работы скрипта"

# Проверка порта
validate_port "8443" "VLESS_PORT"

# Генерация UUID
local uuid=$(generate_uuid)
validate_uuid "$uuid"

# Загрузка конфигурации
load_env_safe .env

# Проверка Docker
check_docker_running

# Проверка firewall
sudo ufw status
```

## Управление конфигурациями

### Обновление конфигураций

```bash
# Запуск скрипта обновления
sudo ./scripts/update.sh
```

### Резервное копирование

```bash
# Создание резервной копии
sudo ./scripts/backup.sh

# Или вручную
tar -czf vpn-backup-$(date +%F).tar.gz .env connection_guide.txt configs/ docker-compose.yml
```

### Удаление

```bash
# Полное удаление
sudo ./scripts/uninstall.sh

# Или вручную
docker compose -p grandfw down -v
sudo rm -rf .env xray_config.json amnezia_*.conf connection_guide.txt configs/
```

## Устранение неполадок

### Проблемы с подключением

1. **Проверьте, что порты открыты в брандмауэре**:

```bash
sudo ufw status
```

2. **Убедитесь, что службы запущены**:

```bash
docker compose -p grandfw ps
```

3. **Посмотрите логи контейнеров**:

```bash
docker compose -p grandfw logs xray
docker compose -p grandfw logs amnezia-wg
```

### Проверка конфигурации

Вы можете использовать скрипт проверки:

```bash
sudo ./scripts/health-check.sh
```

### Проверка сетевых соединений

```bash
# Проверка прослушиваемых портов
sudo ss -tulnp | grep -E "(8443|9443|51820)"

# Проверка подключения к внешнему IP
curl -s https://api.ipify.org
```

## Работа с тестами

### Запуск всех тестов

```bash
# Запуск всех тестов
./tests/run_tests.sh all

# Запуск unit тестов
./tests/run_tests.sh unit

# Запуск integration тестов
./tests/run_tests.sh integration
```

### Запуск отдельных тестов

```bash
# Запуск конкретного теста
./tests/unit/test_crypto.sh

# Запуск с отладкой
DEBUG=true ./tests/unit/test_validation.sh
```

## Безопасность

### Проверка прав доступа

```bash
# Проверка прав на .env файл
ls -la .env  # Должно быть: -rw------- (600)

# Проверка владельца
stat -c "%U:%G" .env  # Должно быть: root:root
```

### Проверка валидации

```bash
# Запуск валидации переменных окружения
source lib/validation.sh
validate_env_vars
```

## Примеры сценариев использования

### Сценарий 1: Установка на новый сервер

```bash
# 1. Клонирование репозитория
git clone https://github.com/asvspb/grandFW.git
cd grandFW

# 2. Запуск установки
sudo ./setup.sh

# 3. Следование инструкциям по вводу данных
# 4. Получение информации для подключения
```

### Сценарий 2: Обновление конфигурации

```bash
# 1. Резервное копирование
sudo ./scripts/backup.sh

# 2. Обновление конфигурации
sudo ./scripts/update.sh

# 3. Проверка работоспособности
sudo ./scripts/health-check.sh
```

### Сценарий 3: Диагностика проблем

```bash
# 1. Проверка состояния
sudo ./scripts/health-check.sh

# 2. Проверка логов
docker compose -p grandfw logs xray
docker compose -p grandfw logs amnezia-wg

# 3. Запуск тестов
./tests/run_tests.sh all
```
# Установка grandFW VPN-сервера

## Требования

### Системные требования

- **ОС**: Ubuntu 20.04 LTS или новее (или совместимая система)
- **Память**: 1 ГБ свободной оперативной памяти (рекомендуется 2 ГБ)
- **Диск**: 25 ГБ свободного места на диске
- **Права**: Root (или доступ к sudo)
- **Порты**: 8443 (TCP), 9443 (TCP/UDP), 51820 (UDP) - должны быть открыты

### Проверка требований

#### Проверка версии ОС

```bash
cat /etc/os-release
```

#### Проверка наличия sudo

```bash
sudo -v
```

#### Проверка свободного места

```bash
df -h
```

#### Проверка необходимых зависимостей

```bash
# Docker
docker --version

# Docker Compose
docker compose version

# Основные утилиты
curl --version
openssl version
wg --version  # WireGuard tools
```

## Подготовка к установке

### 1. Обновление системы

```bash
sudo apt update && sudo apt upgrade -y
```

### 2. Установка необходимых утилит

```bash
sudo apt install -y curl wget git
```

### 3. Проверка, что порты не заняты

```bash
sudo lsof -i :8443
sudo lsof -i :9443
sudo lsof -i :51820
```

## Архитектура установки

Проект использует модульную архитектуру с разделением на следующие компоненты:

### Библиотеки (lib/)
- `lib/common.sh` - общие функции (логирование, проверки, backup)
- `lib/validation.sh` - валидация данных (UUID, IP, порты)
- `lib/crypto.sh` - криптографические функции
- `lib/env_loader.sh` - безопасная загрузка .env
- `lib/docker.sh` - работа с Docker
- `lib/firewall.sh` - настройка UFW

### Скрипты (scripts/)
- `scripts/setup.sh` - основной скрипт установки
- `scripts/health-check.sh` - проверка работоспособности
- `scripts/update.sh` - обновление конфигураций
- `scripts/backup.sh` - резервное копирование
- `scripts/uninstall.sh` - удаление

## Процесс установки

### 1. Клонирование репозитория

```bash
git clone https://github.com/asvspb/grandFW.git
cd grandFW
```

### 2. Запуск установки

```bash
sudo ./setup.sh
```

## Этапы установки

### 1. Проверка зависимостей

Скрипт автоматически проверит и установит следующие зависимости:

- Docker
- Docker Compose
- curl
- openssl
- wg (WireGuard утилита)
- envsubst
- qrencode (для генерации QR-кодов)
- gettext-base

### 2. Генерация криптографических параметров

Скрипт сгенерирует все необходимые криптографические параметры:

- UUID для VLESS
- Ключи для X25519 (REALITY)
- Краткие ID
- Пароли для Shadowsocks-2022
- Ключи для AmneziaWG
- Параметры обфускации WireGuard

### 3. Создание конфигурационных файлов

- `configs/xray.json.template` - шаблон конфигурации для Xray
- `xray_config.json` - финальная конфигурация для Xray
- `amnezia_client.conf` - клиентская конфигурация для AmneziaWG
- `amnezia_server.conf` - серверная конфигурация для AmneziaWG
- `docker-compose.yml` - конфигурация Docker Compose

### 4. Настройка Docker Compose

Создание и запуск контейнеров:

- `xray-core` - для VLESS+Reality и Shadowsocks-2022
- `amnezia-wg` - для AmneziaWG

### 5. Настройка брандмауэра

Скрипт настроит UFW (Uncomplicated Firewall):

- Порт SSH (обычно 22)
- Порт VLESS (8443/TCP)
- Порт Shadowsocks (9443/TCP и 9443/UDP)
- Порт AmneziaWG (51820/UDP)

### 6. Генерация информации для подключения

- VLESS + REALITY ссылка и QR-код
- Shadowsocks-2022 ссылка и QR-код
- AmneziaWG конфигурационный файл
- Файл `connection_guide.txt` с полной инструкцией

## После установки

### 1. Проверка состояния сервисов

```bash
docker compose -p grandfw ps
```

Все контейнеры должны быть в состоянии "Up".

### 2. Проверка логов

```bash
docker compose -p grandfw logs xray
docker compose -p grandfw logs amnezia-wg
```

### 3. Получение информации о подключении

Повторный запуск скрипта установки покажет информацию для подключения:

```bash
sudo ./setup.sh
```

### 4. Проверка работоспособности

```bash
./scripts/health-check.sh
```

## Повторный запуск и обновления

### Получение информации о подключении

```bash
sudo ./setup.sh
```

### Обновление конфигураций

```bash
sudo ./scripts/update.sh
```

## Рекомендации по безопасности

1. **Храните файл .env в безопасности**
   - Он содержит все криптографические ключи
   - Не делитесь им и не коммитьте в репозиторий
   - Файл автоматически защищен правами доступа 600

2. **Ограничьте доступ к серверу**
   - Используйте SSH-ключи вместо паролей
   - Настройте fail2ban для защиты от брутфорса

3. **Регулярно обновляйте систему**
   - Обновляйте ОС и Docker
   - Проверяйте обновления для Xray и других компонентов

4. **Мониторьте использование ресурсов**
   - Следите за нагрузкой на CPU и RAM
   - Проверяйте логи на предмет подозрительной активности

## Резервное копирование

### Создание резервной копии

```bash
# Использование встроенного скрипта
sudo ./scripts/backup.sh

# Или вручную
tar -czf vpn-backup-$(date +%F).tar.gz .env connection_guide.txt docker-compose.yml configs/ scripts/
```

### Восстановление из резервной копии

```bash
tar -xzf vpn-backup-date.tar.gz
sudo ./setup.sh
```

## Удаление

### Полное удаление VPN-сервера

```bash
docker compose -p grandfw down -v
sudo rm -rf .env xray_config.json amnezia_client.conf amnezia_server.conf connection_guide.txt configs/ scripts/
```

### Использование скрипта удаления

```bash
sudo ./scripts/uninstall.sh
```

## Возможные проблемы и решения

### Проблема: "Port 8443 already in use"

**Решение**: Остановите сервис, использующий порт 8443:

```bash
sudo lsof -i :8443
sudo kill -9 PID
```

Затем перезапустите установку.

### Проблема: "Docker daemon not running"

**Решение**: Запустите Docker вручную:

```bash
sudo systemctl start docker
sudo systemctl enable docker
```

### Проблема: "Permission denied" при работе с Docker

**Решение**: Добавьте пользователя в группу docker:

```bash
sudo usermod -aG docker $USER
newgrp docker
```

### Проблема: "Failed to pull Docker image"

**Решение**: Проверьте подключение к интернету и повторите установку.

### Проблема: "Command not found" для docker compose

**Решение**: Убедитесь, что установлена новая версия Docker Compose (не docker-compose):

```bash
# Проверьте версию
docker compose version

# Если не работает, установите
sudo apt install docker-compose-plugin
```

## Поддержка

Если у вас возникли проблемы с установкой:

1. Проверьте логи: `docker compose -p grandfw logs`
2. Запустите скрипт проверки: `./scripts/health-check.sh`
3. Ознакомьтесь с документацией: `README.md`
4. Проверьте [TROUBLESHOOTING.md](TROUBLESHOOTING.md) для решения проблем
5. Создайте issue в репозитории с описанием проблемы
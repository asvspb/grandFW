# Установка VPN-сервера

## Требования

### Системные требования

- Ubuntu 20.04 LTS или новее (или совместимая система)
- 1 ГБ свободной оперативной памяти
- 25 ГБ свободного места на диске
- Root права (или доступ к sudo)
- Открытые порты: 8443 (TCP) и 51820 (UDP)

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
sudo lsof -i :51820
```

## Процесс установки

### 1. Скачивание скрипта

Если вы клонируете репозиторий:

```bash
git clone https://github.com/your-repo/grandFW.git
cd grandFW
```

Или скачивание одного файла:

```bash
wget https://raw.githubusercontent.com/your-repo/grandFW/main/setup.sh
chmod +x setup.sh
```

### 2. Запуск установки

```bash
sudo ./setup.sh
```

## Этапы установки

### 1. Проверка зависимостей

Скрипт автоматически проверит и установит следующие зависимости:

- Docker
- curl
- openssl
- wg (WireGuard утилита)
- envsubst
- shuf
- qrencode (для генерации QR-кодов)

### 2. Генерация криптографических параметров

Скрипт сгенерирует все необходимые криптографические параметры:

- UUID для VLESS
- Ключи для X25519 (REALITY)
- Краткие ID
- Пароли для Shadowsocks-2022
- Ключи для AmneziaWG
- Параметры обфускации WireGuard

### 3. Создание конфигурационных файлов

- `xray_config.json` - конфигурация для Xray
- `amnezia_client.conf` - клиентская конфигурация для AmneziaWG
- `amnezia_server.conf` - серверная конфигурация для AmneziaWG

### 4. Настройка Docker Compose

Создание и запуск контейнеров:

- `xray-core` - для VLESS+Reality и Shadowsocks-2022
- `amnezia-wg` - для AmneziaWG

### 5. Настройка брандмауэра

Скрипт настроит UFW (Uncomplicated Firewall):

- Порт SSH (обычно 22)
- Порт VLESS/Shadowsocks (8443/TCP)
- Порт AmneziaWG (51820/UDP)

### 6. Генерация информации для подключения

- VLESS + REALITY ссылка и QR-код
- Shadowsocks-2022 ссылка и QR-код
- AmneziaWG конфигурационный файл

## После установки

### 1. Проверка состояния сервисов

```bash
docker compose ps
```

Все контейнеры должны быть в состоянии "Up".

### 2. Проверка логов

```bash
docker compose logs xray
docker compose logs amnezia-wg
```

### 3. Получение информации о подключении

```bash
sudo ./setup.sh --info
```

### 4. Проверка работоспособности

```bash
./health-check.sh
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

## Рекомендации по безопасности

1. **Храните файл .env в безопасности**
   - Он содержит все криптографические ключи
   - Не делитесь им и не коммитьте в репозиторий

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
tar -czf vpn-backup-$(date +%F).tar.gz .env connection_guide.txt docker-compose.yml setup.sh
```

### Восстановление из резервной копии

```bash
tar -xzf vpn-backup-date.tar.gz
sudo ./setup.sh
```

## Удаление

### Полное удаление VPN-сервера

```bash
docker compose down
sudo rm -rf .env xray_config.json amnezia_client.conf amnezia_server.conf connection_guide.txt
```

## Поддержка

Если у вас возникли проблемы с установкой:

1. Проверьте логи: `docker compose logs`
2. Запустите скрипт проверки: `./health-check.sh`
3. Ознакомьтесь с документацией: `README.md`
4. Создайте issue в репозитории с описанием проблемы
# Примеры использования

## Установка VPN-сервера

### Базовая установка

```bash
sudo ./setup.sh
```

### Повторный запуск для получения информации о подключении

```bash
sudo ./setup.sh --info
```

## Структура файлов после установки

После успешной установки будут созданы следующие файлы:

```
├── .env                    # Конфиденциальные параметры
├── xray_config.json        # Конфигурация Xray
├── amnezia_client.conf     # Конфигурация клиента AmneziaWG
├── amnezia_server.conf     # Конфигурация сервера AmneziaWG
├── connection_guide.txt    # Инструкция по подключению
└── health-check.sh         # Скрипт проверки работоспособности
```

## Проверка работоспособности

```bash
./health-check.sh
```

## Управление сервисами

### Просмотр статуса контейнеров

```bash
docker compose ps
```

### Просмотр логов Xray

```bash
docker compose logs xray
```

### Просмотр логов AmneziaWG

```bash
docker compose logs amnezia-wg
```

### Перезапуск сервисов

```bash
docker compose down
docker compose up -d
```

## Порты, используемые системой

- `8443/TCP` - VLESS + REALITY и Shadowsocks-2022
- `51820/UDP` - AmneziaWG (совместимый с WireGuard)

## Файлы конфигурации

### .env

Файл `.env` содержит все криптографические параметры и настройки:

```env
UUID=...                    # UUID для VLESS
PRIVATE_KEY=...             # Приватный ключ для REALITY
PUBLIC_KEY=...              # Публичный ключ для REALITY
SHORT_ID=...                # Краткий ID для REALITY
SERVER_NAME=google.com      # Имя сервера для маскировки
SNI=google.com              # SNI для TLS
PORT_VLESS=8443             # Порт для VLESS
PORT_SHADOWSOCKS=8443       # Порт для Shadowsocks
PORT_AMNEZIAWG=51820        # Порт для AmneziaWG
PASSWORD_SS=...             # Пароль для Shadowsocks-2022

# Параметры AmneziaWG
WG_CLIENT_PRIVATE_KEY=...   # Приватный ключ клиента
WG_SERVER_PRIVATE_KEY=...   # Приватный ключ сервера
WG_CLIENT_PUBLIC_KEY=...    # Публичный ключ клиента
WG_SERVER_PUBLIC_KEY=...    # Публичный ключ сервера
WG_PASSWORD=...             # Пароль (предварительно-общий ключ)
WG_JC=...                   # Параметр обфускации jc
WG_JMIN=...                 # Параметр обфускации jmin
WG_JMAX=...                 # Параметр обфускации jmax
WG_S1=...                   # Параметр обфускации s1
WG_S2=...                   # Параметр обфускации s2
WG_H1=...                   # Параметр обфускации h1
WG_H2=...                   # Параметр обфускации h2
WG_H3=...                   # Параметр обфускации h3
WG_H4=...                   # Параметр обфускации h4
```

## Поддерживаемые клиенты

### VLESS + REALITY

- **Android**: v2rayNG, Hiddify
- **iOS**: Shadowrocket, Quantumult X, Loon
- **Windows**: Qv2ray, v2rayN
- **macOS**: Qv2ray, ClashX
- **Linux**: Qv2ray

### Shadowsocks-2022

- **Android**: v2rayNG, Shadowsocks
- **iOS**: Shadowrocket, Shadowsocks
- **Windows**: Shadowsocks Windows
- **macOS**: ShadowsocksX-NG
- **Linux**: shadowsocks-rust

### AmneziaWG

- **Все платформы**: AmneziaVPN (https://amnezia.org/)

## Устранение неполадок

### Проблемы с подключением

1. **Проверьте, что порты открыты в брандмауэре**:

```bash
sudo ufw status
```

2. **Убедитесь, что службы запущены**:

```bash
docker compose ps
```

3. **Посмотрите логи контейнеров**:

```bash
docker compose logs xray
docker compose logs amnezia-wg
```

### Проверка конфигурации

Вы можете использовать скрипт проверки:

```bash
./health-check.sh
```

### Проверка сетевых соединений

```bash
netstat -tulnp | grep -E "(8443|51820)"
```

## Безопасность

- Все конфиденциальные данные генерируются локально
- Ключи хранятся в файле `.env` с ограниченными правами доступа
- Используется безопасная генерация случайных данных через OpenSSL
- Файл `.gitignore` исключает `.env` из репозитория

## Обновление системы

Поскольку все конфигурации генерируются из параметров в файле `.env`, вы можете легко обновить базовые образы:

```bash
docker compose pull
docker compose up -d
```

## Резервное копирование

Для создания резервной копии системы сохраните следующие файлы:

- `.env` - содержит все криптографические параметры
- `connection_guide.txt` - содержит информацию для подключения
- `docker-compose.yml` - определение сервисов
- `setup.sh` - скрипт установки (на случай обновлений)
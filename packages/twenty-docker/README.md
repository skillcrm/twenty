# SkillCRM - CI/CD и Деплой Конфигурация

Этот пакет содержит полную конфигурацию для развертывания Twenty CRM для проекта SkillCRM в production и stage средах с автоматизированным CI/CD.

## 🎯 Обзор проекта

- **Домен**: skillcrm.ru
- **Stage**: stage.skillcrm.ru
- **Production**: skillcrm.ru
- **База данных**: PostgreSQL (185.185.142.189)
- **Кэш**: Redis (185.185.142.201)
- **Email**: Timeweb SMTP (smtp.timeweb.ru:25)
- **Docker Registry**: skillcrm-register.registry.twcstorage.ru

## 📋 Содержание

- [Быстрый старт](#быстрый-старт)
- [Архитектура](#архитектура)
- [Выбор платформы деплоя](#выбор-платформы-деплоя)
- [Docker Compose деплой](#docker-compose-деплой)
- [Kubernetes деплой](#kubernetes-деплой)
- [Настройка GitHub Secrets](#настройка-github-secrets)
- [Мониторинг](#мониторинг)
- [Бэкапы](#бэкапы)
- [Управление](#управление)
- [Troubleshooting](#troubleshooting)

## 🏗️ Архитектура

```
┌─────────────────┐    ┌─────────────────┐
│   GitHub Repo   │    │  Docker Registry│
│                 │    │ (skillcrm-reg.) │
└─────────┬───────┘    └─────────┬───────┘
          │                      │
          │ CI/CD                │
          ▼                      ▼
┌─────────────────┐    ┌─────────────────┐
│  Kubernetes     │    │  Docker Compose │
│  Cluster        │    │  Servers        │
└─────────┬───────┘    └─────────┬───────┘
          │                      │
          └──────────┬───────────┘
                     │
          ┌─────────────────┐
          │  Shared Services│
          │ PostgreSQL DB   │
          │ Redis Cache     │
          │ Email (Timeweb) │
          └─────────────────┘
```

## 🎯 Выбор платформы деплоя

### Kubernetes (Рекомендуется)
- ✅ Автоматическое масштабирование
- ✅ Высокая доступность
- ✅ Управление секретами
- ✅ Rolling updates
- ✅ Health checks и self-healing

### Docker Compose
- ✅ Простота настройки
- ✅ Подходит для небольших проектов
- ✅ Быстрый старт
- ❌ Ручное масштабирование

## 🚀 Быстрый старт

### Kubernetes деплой

1. **Настройте kubectl** и подключитесь к кластеру
2. **Создайте Docker registry secret** в Kubernetes
3. **Обновите секреты** в `k8s/secret.yaml`
4. **Запушьте код** в ветку `develop` или `main`

### Docker Compose деплой

1. **Настройте GitHub Secrets**
2. **Подготовьте серверы**
3. **Запушьте код** в ветку `develop` или `main`

### 1. Настройка GitHub Secrets

Добавьте следующие секреты в ваш GitHub репозиторий:

#### Docker Registry
```
DOCKER_REGISTRY_USER=skillcrm-register
DOCKER_REGISTRY_TOKEN=eyJhbGciOiJSUzUxMiIsInR5cCI6IkpXVCIsImtpZCI6IjFrYnhacFJNQGJSI0tSbE1xS1lqIn0...
```

#### Yandex Cloud (Kubernetes, exec-auth через yc)

Если kubeconfig использует exec-аутентификацию через `yc`, добавьте секреты:

```
YC_SA_KEY_JSON   # содержимое JSON-ключа сервисного аккаунта (многострочный)
YC_CLOUD_ID      # ID облака (b1g...)
YC_FOLDER_ID     # ID каталога (b1g...)
KUBECONFIG       # kubeconfig (base64 или с экранированными \n)
```

Как получить значения

- Через веб‑консоль YC:
  1) Cloud ID: раздел «Облака», откройте нужное облако → копируйте `cloud_id`.
  2) Folder ID: в облаке откройте нужный каталог → копируйте `folder_id`.
  3) JSON‑ключ сервисного аккаунта: IAM → Сервисные аккаунты → выберите/создайте → Ключи → Создать новый ключ → скачайте JSON и целиком вставьте содержимое в `YC_SA_KEY_JSON`.

- Через CLI:
```bash
# Список облаков (скопируйте cloud_id)
yc resource-manager cloud list

# Список каталогов в облаке (скопируйте folder_id)
yc resource-manager folder list --cloud-id <cloud_id>

# Создать сервисный аккаунт и получить его id
yc iam service-account create --name ci-deployer
yc iam service-account get --name ci-deployer --format json | jq -r .id  # => <sa_id>

# Создать ключ сервисного аккаунта (JSON сохранится в файл)
yc iam key create --service-account-id <sa_id> --output sa-key.json

# Откройте sa-key.json и целиком вставьте содержимое в секрет YC_SA_KEY_JSON
```

Где задать секреты:
- GitHub → Settings → Secrets and variables → Actions → New repository secret.

Альтернатива: статический kubeconfig (без yc)

Если хотите не зависеть от `yc` в CI, вместо `YC_*` используйте три секрета:

```
KUBE_SERVER        # URL API сервера кластера (https://<endpoint>:443)
KUBE_CA_DATA       # base64 содержимое CA сертификата кластера
KUBE_BEARER_TOKEN  # токен доступа
```

Получение описано в руководстве Yandex Cloud: [Статическая конфигурация kubectl](https://yandex.cloud/ru/docs/managed-kubernetes/operations/connect/create-static-conf).


#### База данных и Redis
```
POSTGRESQL_HOST=185.185.142.189
POSTGRESQL_PORT=5432
POSTGRESQL_USER=gen_user
POSTGRESQL_PASSWORD=.Xq3d%e1bZS&63
POSTGRESQL_DBNAME_STAGE=twentycrm_db_dev
POSTGRESQL_DBNAME_PROD=twentycrm_db_prod

REDIS_HOST=185.185.142.201
REDIS_PORT=6379
REDIS_USERNAME=default
REDIS_PASSWORD=%G>_=}%64P&$6Y
```

#### Безопасность
```
APP_SECRET_STAGE=your-stage-secret-key
APP_SECRET_PROD=your-production-secret-key
```

#### Уведомления (опционально)
```
TELEGRAM_BOT_TOKEN=123456789:ABCdefGHIjklMNOpqrSTUvwxyz
TELEGRAM_CHAT_ID=-1001234567890
```

#### Настройка Telegram уведомлений

Для получения уведомлений о статусе деплоя в Telegram:

1. **Создайте Telegram бота:**
   - Найдите `@BotFather` в Telegram
   - Отправьте команду `/newbot`
   - Следуйте инструкциям для создания бота
   - Получите токен бота (формат: `123456789:ABCdefGHIjklMNOpqrSTUvwxyz`)

2. **Получите Chat ID:**
   - Добавьте бота в нужный чат/канал
   - Отправьте любое сообщение боту
   - Перейдите по ссылке: `https://api.telegram.org/bot<YOUR_BOT_TOKEN>/getUpdates`
   - Найдите `chat.id` в ответе (может быть отрицательным для групп)

3. **Добавьте секреты в GitHub:**
   - Перейдите в Settings → Secrets and variables → Actions
   - Добавьте `TELEGRAM_BOT_TOKEN` с токеном бота
   - Добавьте `TELEGRAM_CHAT_ID` с ID чата

### 2. Настройка серверов

На каждом сервере (stage и prod) выполните:

```bash
# Создайте директорию для приложения
sudo mkdir -p /opt/twenty-stage  # для stage
sudo mkdir -p /opt/twenty-prod   # для prod

# Скопируйте файлы конфигурации
sudo cp docker-compose.*.yml /opt/twenty-stage/
sudo cp scripts/* /opt/twenty-stage/
sudo cp env.stage /opt/twenty-stage/.env

sudo cp docker-compose.*.yml /opt/twenty-prod/
sudo cp scripts/* /opt/twenty-prod/
sudo cp env.prod /opt/twenty-prod/.env

# Сделайте скрипты исполняемыми
sudo chmod +x /opt/twenty-stage/scripts/*
sudo chmod +x /opt/twenty-prod/scripts/*

# Установите Docker и Docker Compose
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Войдите в Docker registry
echo "eyJhbGciOiJSUzUxMiIsInR5cCI6IkpXVCIsImtpZCI6IjFrYnhacFJNQGJSI0tSbE1xS1lqIn0.eyJ1c2VyIjoiY2gwNjk3NyIsInR5cGUiOiJhcGlfa2V5IiwiYXBpX2tleV9pZCI6IjkzZGQyZjUwLTFkMzAtNDQyOC1iMDM1LTMxOTA0ZjQ2NTVhYiIsImlhdCI6MTc1ODQ2NTI2M30.RKWoVYd3WqJEPkiAFno_Uv_ig5JoqIgx4QGIfZoOCp7042vvSmzZgs0u62T2Z3PfKjGPxz2XD9ucvlAv5EwtLyrS_HCRt2qq6lfyr1WbMmeztQYJhOwZQ8dCXqa2fdC1m8XRkH0cgJ2ArP5sXONYL4I_0iDiFdHPP91_OuXOHcyIY8SoF_THGF6w08QqF5dqcWleK69UGsK5R2X8JlPBcAphbVoNRHg8K-5mHgydOFA1hSysIg7AfU4zXfxP_kX353E-KCLvChMMuzxc2TQIxu0IghJ0rr23srHNci3ertgTJaJ4-cHMcdmVOOhHy-0rhUWL-68sep9TXCXtnaNRiVpcibR4DOxC3lZ2guhIfjO3ubAxc_0egNA_Ta6gZfr970QFvM27IIl2j4vB_5_vRjhRjLv-icNIA7x3QCwiqK9dU5nqZ-ox9dwTpqdAcPzZHFtod7WkZBde6N4SeeU8jGigUEecBozIvj02TZhhcObMCxjIiVpt4hMI6wAVPeAH" | sudo docker login skillcrm-register.registry.twcstorage.ru -u skillcrm-register --password-stdin
```

### 3. Первый деплой

После настройки секретов и серверов:

1. **Stage деплой**: Запушьте изменения в ветку `develop`
2. **Prod деплой**: Запушьте изменения в ветку `main`

## 📁 Структура проекта

```
packages/twenty-docker/
├── docker-compose.yml              # Базовая конфигурация
├── docker-compose.stage.yml        # Конфигурация для stage
├── docker-compose.prod.yml         # Конфигурация для production
├── docker-compose.monitoring.yml   # Мониторинг и логирование
├── env.stage                       # Переменные окружения для stage
├── env.prod                        # Переменные окружения для production
├── scripts/
│   ├── deploy.sh                   # Основной скрипт деплоя
│   ├── backup.sh                   # Скрипт создания бэкапов
│   ├── rollback.sh                 # Скрипт отката
│   ├── install.sh                  # Оригинальный скрипт установки
│   └── 1-click.sh                  # Быстрая установка
├── monitoring/
│   ├── prometheus.yml              # Конфигурация Prometheus
│   ├── alert_rules.yml             # Правила алертов
│   ├── loki.yml                    # Конфигурация Loki
│   ├── promtail.yml                # Конфигурация Promtail
│   └── alertmanager.yml            # Конфигурация Alertmanager
└── README.md                       # Эта документация
```

## ⚙️ Настройка окружения

### Переменные окружения

Основные переменные, которые нужно настроить:

#### База данных
```bash
POSTGRESQL_HOST=185.185.142.189
POSTGRESQL_PORT=5432
POSTGRESQL_USER=gen_user
POSTGRESQL_PASSWORD=.Xq3d%e1bZS&63
POSTGRESQL_DBNAME=twentycrm_db_dev  # для stage
POSTGRESQL_DBNAME=twentycrm_db_prod # для prod
```

#### Redis
```bash
REDIS_HOST=185.185.142.201
REDIS_PORT=6379
REDIS_USERNAME=default
REDIS_PASSWORD=%G>_=}%64P&$6Y
```

#### Домен и URL
```bash
# Stage
SERVER_URL=https://stage.skillcrm.ru
DOMAIN=stage.skillcrm.ru

# Production
SERVER_URL=https://skillcrm.ru
DOMAIN=skillcrm.ru
```

#### Безопасность
```bash
APP_SECRET=your-secret-key-here
```

### Email конфигурация (опционально)

```bash
EMAIL_FROM_ADDRESS=noreply@skillcrm.ru
EMAIL_FROM_NAME="SkillCRM"
EMAIL_DRIVER=smtp
EMAIL_SMTP_HOST=smtp.gmail.com
EMAIL_SMTP_PORT=587
EMAIL_SMTP_USER=your-email@skillcrm.ru
EMAIL_SMTP_PASSWORD=your-email-password
```

### OAuth конфигурация (опционально)

```bash
# Google OAuth
AUTH_GOOGLE_CLIENT_ID=your-google-client-id
AUTH_GOOGLE_CLIENT_SECRET=your-google-client-secret

# Microsoft OAuth
AUTH_MICROSOFT_CLIENT_ID=your-microsoft-client-id
AUTH_MICROSOFT_CLIENT_SECRET=your-microsoft-client-secret
```

## 🚀 Деплой

### Автоматический деплой

#### Stage среда
- Запушьте изменения в ветку `develop`
- GitHub Actions автоматически соберет Docker образ и задеплоит на stage сервер

#### Production среда
- Запушьте изменения в ветку `main`
- GitHub Actions автоматически соберет Docker образ и задеплоит на prod сервер

### Ручной деплой

```bash
# Stage
./scripts/deploy.sh stage

# Production
./scripts/deploy.sh prod
```

### Проверка статуса

```bash
./scripts/deploy.sh status
```

### Просмотр логов

```bash
./scripts/deploy.sh logs
```

## ☸️ Kubernetes деплой

### Требования

- Kubernetes кластер 1.20+
- NGINX Ingress Controller
- cert-manager для SSL сертификатов
- kubectl настроен и подключен к кластеру

### Быстрый старт

```bash
# 1. Создайте Docker registry secret
kubectl create secret docker-registry skillcrm-registry-secret \
  --docker-server=skillcrm-register.registry.twcstorage.ru \
  --docker-username=skillcrm-register \
  --docker-password=your-docker-token \
  --namespace=twentycrm

# 2. Обновите секреты в k8s/secret.yaml
# 3. Задеплойте
cd packages/twenty-docker/k8s
./deploy.sh prod

# 4. Проверьте статус
kubectl get pods -n twentycrm
```

### Управление

```bash
# Статус
./deploy.sh status prod

# Логи
./deploy.sh logs prod

# Откат
./deploy.sh rollback prod

# Обновление образа
kubectl set image deployment/twentycrm-server \
  server=skillcrm-register.registry.twcstorage.ru/twenty:new-tag \
  -n twentycrm
```

### Структура манифестов

```
k8s/
├── namespace.yaml              # Production namespace
├── secret.yaml                 # Secrets (DB, Redis, Email)
├── configmap.yaml              # Configuration
├── pvc.yaml                    # Persistent storage
├── deployment-server.yaml      # Server deployment (1 replica)
├── deployment-worker.yaml      # Worker deployment (1 replica)
├── service.yaml                # Internal service
├── ingress.yaml                # External access
└── stage/                      # Stage environment files
```

Подробная документация: [k8s/README.md](k8s/README.md)

## 🐳 Docker Compose деплой

### Подготовка серверов

```bash
# Установка Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Создание пользователя deploy
sudo useradd -m -s /bin/bash deploy
sudo usermod -aG docker deploy

# Создание директорий
sudo mkdir -p /opt/twenty-stage /opt/twenty-prod
sudo chown deploy:deploy /opt/twenty-stage /opt/twenty-prod
```

### Деплой

```bash
# Stage
./scripts/deploy.sh stage

# Production
./scripts/deploy.sh prod
```

## 📊 Мониторинг

### Запуск мониторинга

```bash
docker-compose -f docker-compose.monitoring.yml up -d
```

### Доступ к интерфейсам

- **Grafana**: http://your-server:3001 (admin/admin)
- **Prometheus**: http://your-server:9090
- **Alertmanager**: http://your-server:9093
- **Loki**: http://your-server:3100

### Основные метрики

- CPU и память сервера
- Использование диска
- Состояние контейнеров
- Время отклика приложения
- Ошибки базы данных и Redis

## 💾 Бэкапы

### Автоматические бэкапы

Бэкапы создаются автоматически перед каждым деплоем.

### Ручное создание бэкапа

```bash
./scripts/backup.sh
```

### Откат к предыдущей версии

```bash
# Интерактивный выбор бэкапа
./scripts/rollback.sh

# Откат к конкретному бэкапу
./scripts/rollback.sh 20241201_143000
```

### Просмотр доступных бэкапов

```bash
./scripts/backup.sh list
```

## 🔧 Troubleshooting

### Проблемы с деплоем

1. **Проверьте логи GitHub Actions**
2. **Проверьте подключение к серверу**: `ssh deploy@your-server`
3. **Проверьте Docker registry**: `docker login skillcrm-register.registry.twcstorage.ru`

### Проблемы с базой данных

```bash
# Проверьте подключение к базе данных
PGPASSWORD=".Xq3d%e1bZS&63" psql -h 185.185.142.189 -p 5432 -U gen_user -d twentycrm_db_dev -c "SELECT version();"
```

### Проблемы с Redis

```bash
# Проверьте подключение к Redis
redis-cli -h 185.185.142.201 -p 6379 -a "%G>_=}%64P&$6Y" ping
```

### Проблемы с контейнерами

```bash
# Проверьте статус контейнеров
docker-compose ps

# Просмотрите логи
docker-compose logs -f

# Перезапустите сервисы
docker-compose restart
```

### Проблемы с доменом

1. **Проверьте DNS записи**
2. **Проверьте SSL сертификаты**
3. **Проверьте настройки веб-сервера (nginx/apache)**

## 📞 Поддержка

При возникновении проблем:

1. Проверьте логи приложения и контейнеров
2. Убедитесь, что все переменные окружения настроены корректно
3. Проверьте доступность внешних сервисов (база данных, Redis)
4. Обратитесь к команде разработки с подробным описанием проблемы

## 🔐 Безопасность

### Рекомендации по безопасности

1. **Регулярно обновляйте секретные ключи**
2. **Используйте сильные пароли**
3. **Настройте файрвол на серверах**
4. **Регулярно создавайте бэкапы**
5. **Мониторьте логи на предмет подозрительной активности**

### SSL/TLS

Убедитесь, что SSL сертификаты настроены для доменов:
- `skillcrm.ru`
- `stage.skillcrm.ru`

Можно использовать Let's Encrypt или коммерческие сертификаты.

# SkillCRM - Kubernetes Deployment

Конфигурация для развертывания Twenty CRM в Kubernetes кластере.

## 🎯 Обзор

- **Stage**: `stage.twentycrm.ru` в namespace `twentycrm-stage`
- **Production**: `twentycrm.ru` в namespace `twentycrm`
- **Реплики**: по 1 инстансу для server и worker
- **Хранилище**: PersistentVolumeClaim 10Gi
- **Ingress**: NGINX Ingress Controller с SSL

## 📁 Структура файлов

```
k8s/
├── namespace.yaml              # Production namespace
├── secret.yaml                 # Production secrets
├── configmap.yaml              # Production config
├── pvc.yaml                    # Persistent Volume Claim
├── deployment-server.yaml      # Server deployment
├── deployment-worker.yaml      # Worker deployment
├── service.yaml                # Server service
├── ingress.yaml                # Production ingress
├── registry-secret.yaml        # Docker registry secret template
├── deploy.sh                   # Deployment script
└── stage/                      # Stage environment
    ├── namespace.yaml
    ├── secret.yaml
    ├── configmap.yaml
    ├── pvc.yaml
    ├── deployment-server.yaml
    ├── deployment-worker.yaml
    ├── service.yaml
    └── ingress.yaml
```

## 🚀 Быстрый старт

### 1. Настройка kubectl

```bash
# Убедитесь, что kubectl настроен и подключен к кластеру
kubectl cluster-info

# Проверьте доступные namespaces
kubectl get namespaces
```

### 2. Создание Docker registry secret

```bash
# Создайте secret для доступа к Docker registry
kubectl create secret docker-registry twentycrm-registry-secret \
  --docker-server=twentycrm-register.registry.twcstorage.ru \
  --docker-username=twentycrm-register \
  --docker-password=your-docker-token \
  --namespace=twentycrm

# Для stage среды
kubectl create secret docker-registry twentycrm-registry-secret \
  --docker-server=twentycrm-register.registry.twcstorage.ru \
  --docker-username=twentycrm-register \
  --docker-password=your-docker-token \
  --namespace=twentycrm-stage
```

### 3. Обновление секретов

Отредактируйте файлы `secret.yaml` и `stage/secret.yaml` с актуальными значениями:

```yaml
stringData:
  POSTGRESQL_PASSWORD: "your-actual-password"
  REDIS_PASSWORD: "your-actual-redis-password"
  APP_SECRET: "your-actual-app-secret"
  EMAIL_SMTP_PASSWORD: "your-actual-email-password"
```

### 4. Деплой

```bash
# Stage среда
cd packages/twenty-docker/k8s
export DOCKER_REGISTRY_USER=twentycrm-register
export DOCKER_REGISTRY_TOKEN=your-docker-token
./deploy.sh stage

# Production среда
./deploy.sh prod
```

## 🔧 Управление

### Основные команды

```bash
# Статус деплоя
./deploy.sh status stage
./deploy.sh status prod

# Логи
./deploy.sh logs stage
./deploy.sh logs prod

# Откат
./deploy.sh rollback stage
./deploy.sh rollback prod
```

### kubectl команды

```bash
# Проверка подов
kubectl get pods -n twentycrm
kubectl get pods -n twentycrm-stage

# Проверка сервисов
kubectl get services -n twentycrm
kubectl get services -n twentycrm-stage

# Проверка ingress
kubectl get ingress -n twentycrm
kubectl get ingress -n twentycrm-stage

# Логи приложения
kubectl logs -f deployment/twentycrm-server -n twentycrm
kubectl logs -f deployment/twentycrm-stage-server -n twentycrm-stage

# Описание ресурсов
kubectl describe deployment twentycrm-server -n twentycrm
kubectl describe service twentycrm-server -n twentycrm
```

## 🔐 Безопасность

### Секреты

Все чувствительные данные хранятся в Kubernetes Secrets:

- `POSTGRESQL_PASSWORD` - пароль базы данных
- `REDIS_PASSWORD` - пароль Redis
- `APP_SECRET` - секретный ключ приложения
- `EMAIL_SMTP_PASSWORD` - пароль SMTP

### RBAC (опционально)

Для продакшена рекомендуется настроить RBAC:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: twentycrm
  name: twentycrm-deployer
rules:
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list", "update", "patch"]
```

## 📊 Мониторинг

### Health checks

Приложение имеет настроенные health checks:

- **Liveness probe**: `/healthz` каждые 30 секунд
- **Readiness probe**: `/healthz` каждые 10 секунд

### Метрики

Для мониторинга рекомендуется добавить:

- Prometheus ServiceMonitor
- Grafana дашборды
- Алерты через PrometheusRule

## 🔄 Обновления

### Обновление образа

```bash
# Обновить образ в deployment
kubectl set image deployment/twentycrm-server \
  server=twentycrm-register.registry.twcstorage.ru/twenty:new-tag \
  -n twentycrm

# Проверить статус обновления
kubectl rollout status deployment/twentycrm-server -n twentycrm
```

### Откат

```bash
# Откат к предыдущей версии
kubectl rollout undo deployment/twentycrm-server -n twentycrm

# Проверить историю deployments
kubectl rollout history deployment/twentycrm-server -n twentycrm
```

## 🚨 Troubleshooting

### Проблемы с образами

```bash
# Проверить события
kubectl get events -n twentycrm --sort-by='.lastTimestamp'

# Проверить статус подов
kubectl describe pod <pod-name> -n twentycrm
```

### Проблемы с хранилищем

```bash
# Проверить PVC
kubectl get pvc -n twentycrm
kubectl describe pvc twentycrm-storage -n twentycrm

# Проверить PV
kubectl get pv
```

### Проблемы с сетью

```bash
# Проверить ingress
kubectl describe ingress twentycrm-ingress -n twentycrm

# Проверить сервисы
kubectl get endpoints -n twentycrm
```

## 📋 Требования

### Kubernetes кластер

- Kubernetes 1.20+
- NGINX Ingress Controller
- cert-manager (для SSL сертификатов)
- StorageClass для PVC

### Ресурсы

**Минимальные требования:**
- Server: 1 CPU, 1Gi RAM
- Worker: 0.5 CPU, 512Mi RAM
- Storage: 10Gi

**Рекомендуемые:**
- Server: 2 CPU, 2Gi RAM
- Worker: 1 CPU, 1Gi RAM
- Storage: 50Gi

## 🔗 Внешние зависимости

- **PostgreSQL**: 185.185.142.189:5432
- **Redis**: 185.185.142.201:6379
- **Email**: smtp.timeweb.ru:25
- **Docker Registry**: twentycrm-register.registry.twcstorage.ru

## 📞 Поддержка

При возникновении проблем:

1. Проверьте логи: `kubectl logs -f deployment/twentycrm-server -n twentycrm`
2. Проверьте события: `kubectl get events -n twentycrm`
3. Проверьте статус ресурсов: `kubectl get all -n twentycrm`
4. Обратитесь к команде разработки
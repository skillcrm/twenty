# 🚀 Скрипты для локального развертывания в Kubernetes

Набор скриптов для развертывания SkillCRM в Kubernetes кластер с локальной машины разработчика.

## 📋 Обзор вава

Скрипты позволяют:
- ✅ Собирать и загружать Docker образы в registry
- ✅ Развертывать приложения в Kubernetes
- ✅ Проверять статус и здоровье приложений
- ✅ Выполнять откаты к предыдущим версиям
- ✅ Очищать ресурсы

## 🛠️ Доступные скрипты

### 1. `deploy-manager.sh` - Главный менеджер
Универсальный скрипт для управления всеми операциями развертывания.

```bash
# Показать меню
./deploy-manager.sh help

# Полный деплой
./deploy-manager.sh deploy stage v1.2.3

# Быстрый деплой с автогенерацией тега
./deploy-manager.sh quick stage

# Проверка статуса
./deploy-manager.sh status stage --logs

# Откат
./deploy-manager.sh rollback stage 3

# Очистка
./deploy-manager.sh cleanup stage --force
```

### 2. `local-deploy.sh` - Полный деплой
Выполняет полный цикл развертывания: сборка → загрузка → деплой → проверка.

```bash
# Деплой в stage с тегом latest
./local-deploy.sh stage

# Деплой в production с конкретным тегом
./local-deploy.sh prod v1.2.3
```

### 3. `quick-deploy.sh` - Быстрый деплой
Автоматически генерирует тег и выполняет деплой.

```bash
# Быстрый деплой в stage
./quick-deploy.sh stage

# Быстрый деплой в production
./quick-deploy.sh prod
```

### 4. `status.sh` - Проверка статуса
Показывает детальную информацию о состоянии развертывания.

```bash
# Проверка статуса stage
./status.sh stage

# Проверка статуса с логами
./status.sh stage --logs

# Проверка статуса production
./status.sh prod
```

### 5. `rollback.sh` - Откат
Позволяет откатиться к предыдущей версии развертывания.

```bash
# Интерактивный откат
./rollback.sh stage

# Откат к конкретной версии
./rollback.sh stage 3

# Откат к предыдущей версии
./rollback.sh prod previous
```

### 6. `cleanup.sh` - Очистка ресурсов
Удаляет ресурсы Kubernetes и Docker образы.

```bash
# Очистка stage с подтверждением
./cleanup.sh stage

# Очистка production без подтверждения
./cleanup.sh prod --force

# Удалить только приложения
./cleanup.sh stage --force apps
```

## 🔧 Предварительные требования

### Установленные инструменты
```bash
# Docker
docker --version

# kubectl
kubectl version --client

# jq (опционально, для улучшенного вывода)
jq --version
```

### Настройка kubectl
```bash
# Проверка подключения к кластеру
kubectl cluster-info

# Проверка текущего контекста
kubectl config current-context
```

### Настройка Docker Registry
```bash
# Вход в registry
docker login skillcrm-register.registry.twcstorage.ru

# Проверка подключения
docker pull skillcrm-register.registry.twcstorage.ru/twenty:latest
```

## 🚀 Быстрый старт

### 1. Подготовка
```bash
# Перейти в директорию скриптов
cd packages/twenty-docker/scripts

# Проверить права на выполнение
ls -la *.sh
```

### 2. Первый деплой
```bash
# Быстрый деплой в stage
./deploy-manager.sh quick stage

# Проверка статуса
./deploy-manager.sh status stage
```

### 3. Деплой в production
```bash
# Полный деплой с конкретным тегом
./deploy-manager.sh deploy prod v1.0.0

# Проверка здоровья
./deploy-manager.sh health prod
```

## 📊 Мониторинг и отладка

### Проверка статуса
```bash
# Общий статус
./status.sh stage

# Статус с логами
./status.sh stage --logs

# Только логи
./deploy-manager.sh logs stage
```

### Проверка здоровья
```bash
# Проверка здоровья приложения
./deploy-manager.sh health stage

# Проверка подключения к кластеру
kubectl cluster-info

# Проверка namespace
kubectl get namespaces | grep twentycrm
```

## 🔄 Управление версиями

### Генерация тегов
Скрипт `quick-deploy.sh` автоматически генерирует теги в формате:
```
{environment}-{timestamp}-{branch}-{commit}
```

Пример: `stage-20240921-143022-main-a1b2c3d`

### Откат к версии
```bash
# Показать историю версий
kubectl rollout history deployment/twentycrm-stage-server -n twentycrm-stage

# Откат к предыдущей версии
./rollback.sh stage

# Откат к конкретной версии
./rollback.sh stage 3
```

## 🧹 Очистка ресурсов

### Типы очистки
- **namespace** - удаляет весь namespace (по умолчанию)
- **apps** - удаляет только приложения, оставляет namespace
- **all** - удаляет namespace + Docker образы + очищает Docker

### Примеры очистки
```bash
# Очистка stage с подтверждением
./cleanup.sh stage

# Очистка production без подтверждения
./cleanup.sh prod --force

# Удалить только приложения
./cleanup.sh stage --force apps

# Полная очистка
./cleanup.sh stage --force all
```

## 🚨 Troubleshooting

### Проблемы с подключением к кластеру
```bash
# Проверка контекста
kubectl config current-context

# Список контекстов
kubectl config get-contexts

# Переключение контекста
kubectl config use-context your-context
```

### Проблемы с Docker Registry
```bash
# Проверка авторизации
docker login skillcrm-register.registry.twcstorage.ru

# Проверка образа
docker pull skillcrm-register.registry.twcstorage.ru/twenty:latest
```

### Проблемы с деплоем
```bash
# Проверка логов
./deploy-manager.sh logs stage

# Проверка событий
kubectl get events -n twentycrm-stage --sort-by='.lastTimestamp'

# Проверка описания pod
kubectl describe pod -l app=twentycrm -n twentycrm-stage
```

## 📝 Логи и отладка

### Просмотр логов
```bash
# Логи всех pods
./deploy-manager.sh logs stage

# Логи конкретного pod
kubectl logs -f twentycrm-stage-server-xxx -n twentycrm-stage

# Логи с фильтрацией
kubectl logs -l app=twentycrm -n twentycrm-stage | grep ERROR
```

### Отладка проблем
```bash
# Описание pod
kubectl describe pod -l app=twentycrm -n twentycrm-stage

# Описание deployment
kubectl describe deployment twentycrm-stage-server -n twentycrm-stage

# Проверка ресурсов
kubectl top pods -n twentycrm-stage
```

## 🔐 Безопасность

### Рекомендации
1. **Никогда не используйте `--force` в production** без крайней необходимости
2. **Проверяйте статус** после каждого деплоя
3. **Делайте бэкапы** перед критическими изменениями
4. **Мониторьте логи** на предмет ошибок

### Проверка безопасности
```bash
# Проверка прав доступа
kubectl auth can-i create deployments --namespace=twentycrm-stage

# Проверка секретов
kubectl get secrets -n twentycrm-stage
```

## 📞 Поддержка

При возникновении проблем:

1. **Проверьте логи**: `./deploy-manager.sh logs stage`
2. **Проверьте статус**: `./deploy-manager.sh status stage`
3. **Проверьте события**: `kubectl get events -n twentycrm-stage`
4. **Обратитесь к команде разработки**

---

**Готово к использованию!** 🚀

Все скрипты протестированы и готовы для развертывания SkillCRM в Kubernetes.

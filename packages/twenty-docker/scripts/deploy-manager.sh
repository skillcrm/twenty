#!/bin/bash

# Менеджер развертывания в Kubernetes
# Использование: ./deploy-manager.sh [команда] [параметры]

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Функции для цветного вывода
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${PURPLE}================================${NC}"
    echo -e "${PURPLE} $1${NC}"
    echo -e "${PURPLE}================================${NC}"
}

# Проверка, что мы в правильной директории
check_script_location() {
    if [[ ! -f "local-deploy.sh" ]]; then
        print_error "Запустите скрипт из директории scripts/"
        exit 1
    fi
}

# Показать меню
show_menu() {
    print_header "Менеджер развертывания SkillCRM"
    echo ""
    echo "Доступные команды:"
    echo ""
    echo "  🚀 Развертывание:"
    echo "    deploy [stage|prod] [tag]     - Полный деплой"
    echo "    quick [stage|prod]            - Быстрый деплой с автогенерацией тега"
    echo ""
    echo "  📊 Мониторинг:"
    echo "    status [stage|prod] [--logs]  - Проверить статус"
    echo "    logs [stage|prod]             - Показать логи"
    echo ""
    echo "  🔄 Управление:"
    echo "    rollback [stage|prod] [version] - Откат к версии"
    echo "    cleanup [stage|prod] [--force]  - Очистка ресурсов"
    echo ""
    echo "  🛠️  Утилиты:"
    echo "    build [stage|prod] [tag]      - Только сборка и загрузка образа"
    echo "    health [stage|prod]           - Проверка здоровья"
    echo ""
    echo "  ❓ Помощь:"
    echo "    help                          - Показать эту справку"
    echo "    help [команда]                - Подробная справка по команде"
    echo ""
}

# Показать подробную справку по команде
show_command_help() {
    local command=$1
    
    case "$command" in
        "deploy")
            echo "Полный деплой в Kubernetes"
            echo ""
            echo "Использование: deploy [stage|prod] [tag]"
            echo ""
            echo "Параметры:"
            echo "  stage    Деплой в stage среду (по умолчанию)"
            echo "  prod     Деплой в production среду"
            echo "  tag      Тег образа (по умолчанию: latest)"
            echo ""
            echo "Примеры:"
            echo "  deploy stage                    # Деплой stage с тегом latest"
            echo "  deploy prod v1.2.3             # Деплой prod с тегом v1.2.3"
            echo ""
            echo "Процесс:"
            echo "  1. Сборка Docker образа"
            echo "  2. Загрузка в registry"
            echo "  3. Обновление deployment"
            echo "  4. Ожидание готовности"
            echo "  5. Проверка здоровья"
            ;;
        "quick")
            echo "Быстрый деплой с автогенерацией тега"
            echo ""
            echo "Использование: quick [stage|prod]"
            echo ""
            echo "Параметры:"
            echo "  stage    Деплой в stage среду (по умолчанию)"
            echo "  prod     Деплой в production среду"
            echo ""
            echo "Тег генерируется автоматически в формате:"
            echo "  {environment}-{timestamp}-{branch}-{commit}"
            ;;
        "status")
            echo "Проверка статуса развертывания"
            echo ""
            echo "Использование: status [stage|prod] [--logs]"
            echo ""
            echo "Параметры:"
            echo "  stage    Проверить stage среду (по умолчанию)"
            echo "  prod     Проверить production среду"
            echo "  --logs   Показать логи приложений"
            ;;
        "rollback")
            echo "Откат к предыдущей версии"
            echo ""
            echo "Использование: rollback [stage|prod] [version]"
            echo ""
            echo "Параметры:"
            echo "  stage    Откат в stage среду (по умолчанию)"
            echo "  prod     Откат в production среду"
            echo "  version  Конкретная версия (опционально)"
            ;;
        "cleanup")
            echo "Очистка ресурсов"
            echo ""
            echo "Использование: cleanup [stage|prod] [--force]"
            echo ""
            echo "Параметры:"
            echo "  stage    Очистка stage среды (по умолчанию)"
            echo "  prod     Очистка production среды"
            echo "  --force  Пропустить подтверждения"
            ;;
        *)
            print_error "Неизвестная команда: $command"
            echo "Используйте 'help' для списка доступных команд"
            ;;
    esac
}

# Выполнение команды deploy
cmd_deploy() {
    local environment=${1:-stage}
    local tag=${2:-latest}
    
    print_header "Полный деплой в $environment"
    ./local-deploy.sh "$environment" "$tag"
}

# Выполнение команды quick
cmd_quick() {
    local environment=${1:-stage}
    
    print_header "Быстрый деплой в $environment"
    ./quick-deploy.sh "$environment"
}

# Выполнение команды status
cmd_status() {
    local environment=${1:-stage}
    local logs_flag=$2
    
    print_header "Проверка статуса $environment"
    ./status.sh "$environment" "$logs_flag"
}

# Выполнение команды rollback
cmd_rollback() {
    local environment=${1:-stage}
    local version=$2
    
    print_header "Откат $environment"
    ./rollback.sh "$environment" "" "$version"
}

# Выполнение команды cleanup
cmd_cleanup() {
    local environment=${1:-stage}
    local force_flag=$2
    
    print_header "Очистка $environment"
    ./cleanup.sh "$environment" "$force_flag"
}

# Выполнение команды build
cmd_build() {
    local environment=${1:-stage}
    local tag=${2:-latest}
    
    print_header "Сборка образа для $environment"
    
    # Только сборка и загрузка, без деплоя
    local registry="skillcrm-register.registry.twcstorage.ru"
    local image_name="twenty"
    local full_image="$registry/$image_name:$tag"
    
    print_status "Сборка Docker образа..."
    if ! docker build -t "$full_image" -f ../twenty/Dockerfile ..; then
        print_error "Ошибка сборки образа"
        exit 1
    fi
    
    print_status "Загрузка образа в registry..."
    if ! docker push "$full_image"; then
        print_error "Ошибка загрузки образа"
        exit 1
    fi
    
    print_success "Образ успешно загружен: $full_image"
}

# Выполнение команды health
cmd_health() {
    local environment=${1:-stage}
    
    print_header "Проверка здоровья $environment"
    
    local namespace="twentycrm${environment:+-$environment}"
    local service_name="twentycrm${environment:+-$environment}-server"
    
    # Проверка подключения к кластеру
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Не удается подключиться к Kubernetes кластеру"
        exit 1
    fi
    
    # Проверка существования сервиса
    if ! kubectl get service "$service_name" -n "$namespace" &> /dev/null; then
        print_error "Сервис $service_name не существует в namespace $namespace"
        exit 1
    fi
    
    # Получение порта сервиса
    local service_port=$(kubectl get service "$service_name" -n "$namespace" -o jsonpath='{.spec.ports[0].port}')
    
    # Проброс порта для проверки
    print_status "Запуск проброса порта для проверки здоровья..."
    kubectl port-forward service/"$service_name" 8080:"$service_port" -n "$namespace" &
    local port_forward_pid=$!
    
    # Ожидание готовности проброса
    sleep 5
    
    # Проверка здоровья
    local health_url="http://localhost:8080/health"
    if curl -s -f "$health_url" > /dev/null 2>&1; then
        print_success "Приложение здорово"
    else
        print_error "Приложение не отвечает на проверку здоровья"
        kill $port_forward_pid 2>/dev/null || true
        exit 1
    fi
    
    # Остановка проброса порта
    kill $port_forward_pid 2>/dev/null || true
}

# Выполнение команды logs
cmd_logs() {
    local environment=${1:-stage}
    
    print_header "Логи $environment"
    
    local namespace="twentycrm${environment:+-$environment}"
    
    # Проверка подключения к кластеру
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Не удается подключиться к Kubernetes кластеру"
        exit 1
    fi
    
    # Показать логи
    local pods=$(kubectl get pods -n "$namespace" -o jsonpath='{.items[*].metadata.name}')
    for pod in $pods; do
        print_status "Логи Pod: $pod"
        echo "----------------------------------------"
        kubectl logs "$pod" -n "$namespace" --tail=100 || true
        echo ""
    done
}

# Основная функция
main() {
    local command=${1:-help}
    
    # Проверка расположения скрипта
    check_script_location
    
    # Обработка команд
    case "$command" in
        "deploy")
            cmd_deploy "$2" "$3"
            ;;
        "quick")
            cmd_quick "$2"
            ;;
        "status")
            cmd_status "$2" "$3"
            ;;
        "rollback")
            cmd_rollback "$2" "$3"
            ;;
        "cleanup")
            cmd_cleanup "$2" "$3"
            ;;
        "build")
            cmd_build "$2" "$3"
            ;;
        "health")
            cmd_health "$2"
            ;;
        "logs")
            cmd_logs "$2"
            ;;
        "help")
            if [[ -n "$2" ]]; then
                show_command_help "$2"
            else
                show_menu
            fi
            ;;
        *)
            print_error "Неизвестная команда: $command"
            echo ""
            show_menu
            exit 1
            ;;
    esac
}

# Обработка сигналов
trap 'print_error "Прервано пользователем"; exit 1' INT TERM

# Запуск
main "$@"

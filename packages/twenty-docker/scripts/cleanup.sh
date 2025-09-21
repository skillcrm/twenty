#!/bin/bash

# Очистка ресурсов Kubernetes
# Использование: ./cleanup.sh [stage|prod] [--force]

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

# Проверка подключения к кластеру
check_kubectl_connection() {
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Не удается подключиться к Kubernetes кластеру"
        exit 1
    fi
}

# Подтверждение удаления
confirm_deletion() {
    local environment=$1
    local namespace="twentycrm${environment:+-$environment}"
    
    if [[ "$2" != "--force" ]]; then
        print_warning "ВНИМАНИЕ: Вы собираетесь удалить все ресурсы в namespace: $namespace"
        print_warning "Это действие необратимо!"
        echo ""
        echo -n "Вы уверены? Введите 'yes' для подтверждения: "
        read -r confirmation
        
        if [[ "$confirmation" != "yes" ]]; then
            print_status "Отменено пользователем"
            exit 0
        fi
    fi
}

# Удаление namespace (все ресурсы)
delete_namespace() {
    local environment=$1
    local namespace="twentycrm${environment:+-$environment}"
    
    print_status "Удаление namespace: $namespace"
    
    if ! kubectl get namespace "$namespace" &> /dev/null; then
        print_warning "Namespace $namespace не существует"
        return 0
    fi
    
    # Показать ресурсы, которые будут удалены
    print_status "Ресурсы в namespace $namespace:"
    echo "----------------------------------------"
    kubectl get all -n "$namespace" 2>/dev/null || true
    echo ""
    
    # Удаление namespace
    if kubectl delete namespace "$namespace"; then
        print_success "Namespace $namespace удален"
    else
        print_error "Ошибка удаления namespace $namespace"
        exit 1
    fi
}

# Удаление только приложений (оставить namespace)
delete_applications() {
    local environment=$1
    local namespace="twentycrm${environment:+-$environment}"
    
    print_status "Удаление приложений в namespace: $namespace"
    
    if ! kubectl get namespace "$namespace" &> /dev/null; then
        print_warning "Namespace $namespace не существует"
        return 0
    fi
    
    # Удаление deployments
    print_status "Удаление deployments..."
    kubectl delete deployments --all -n "$namespace" 2>/dev/null || true
    
    # Удаление services
    print_status "Удаление services..."
    kubectl delete services --all -n "$namespace" 2>/dev/null || true
    
    # Удаление ingress
    print_status "Удаление ingress..."
    kubectl delete ingress --all -n "$namespace" 2>/dev/null || true
    
    # Удаление configmaps
    print_status "Удаление configmaps..."
    kubectl delete configmaps --all -n "$namespace" 2>/dev/null || true
    
    # Удаление secrets (кроме системных)
    print_status "Удаление secrets..."
    kubectl delete secrets --all -n "$namespace" 2>/dev/null || true
    
    # Удаление PVC
    print_status "Удаление PVC..."
    kubectl delete pvc --all -n "$namespace" 2>/dev/null || true
    
    print_success "Приложения удалены из namespace $namespace"
}

# Очистка образов Docker
cleanup_docker_images() {
    local environment=$1
    local registry="skillcrm-register.registry.twcstorage.ru"
    local image_name="twenty"
    
    print_status "Очистка локальных Docker образов..."
    
    # Удаление локальных образов
    local images=$(docker images "$registry/$image_name" --format "{{.Repository}}:{{.Tag}}" 2>/dev/null || true)
    if [[ -n "$images" ]]; then
        print_status "Найденные образы:"
        echo "$images"
        echo ""
        
        if [[ "$2" != "--force" ]]; then
            echo -n "Удалить локальные образы? (y/N): "
            read -r confirm_images
            
            if [[ "$confirm_images" == "y" || "$confirm_images" == "Y" ]]; then
                docker rmi $images 2>/dev/null || true
                print_success "Локальные образы удалены"
            fi
        else
            docker rmi $images 2>/dev/null || true
            print_success "Локальные образы удалены"
        fi
    else
        print_status "Локальные образы не найдены"
    fi
}

# Очистка неиспользуемых ресурсов Docker
cleanup_docker_system() {
    print_status "Очистка неиспользуемых ресурсов Docker..."
    
    if [[ "$2" != "--force" ]]; then
        echo -n "Выполнить 'docker system prune'? (y/N): "
        read -r confirm_prune
        
        if [[ "$confirm_prune" == "y" || "$confirm_prune" == "Y" ]]; then
            docker system prune -f
            print_success "Docker система очищена"
        fi
    else
        docker system prune -f
        print_success "Docker система очищена"
    fi
}

# Показать статус после очистки
show_status_after_cleanup() {
    local environment=$1
    local namespace="twentycrm${environment:+-$environment}"
    
    print_status "Статус после очистки:"
    echo "----------------------------------------"
    
    # Проверка namespace
    if kubectl get namespace "$namespace" &> /dev/null; then
        print_status "Namespace $namespace существует:"
        kubectl get all -n "$namespace" 2>/dev/null || print_status "Ресурсы в namespace отсутствуют"
    else
        print_status "Namespace $namespace удален"
    fi
    
    echo ""
    
    # Проверка Docker образов
    print_status "Локальные Docker образы:"
    docker images "$registry/$image_name" 2>/dev/null || print_status "Образы не найдены"
}

# Основная функция
main() {
    local environment=${1:-stage}
    local force_flag=$2
    local cleanup_type=${3:-namespace}
    
    # Валидация параметров
    if [[ "$environment" != "stage" && "$environment" != "prod" ]]; then
        print_error "Недопустимая среда: $environment"
        print_error "Используйте: stage или prod"
        exit 1
    fi
    
    print_status "Очистка ресурсов в $environment"
    echo "========================================"
    
    # Проверка подключения
    check_kubectl_connection
    
    # Подтверждение удаления
    confirm_deletion "$environment" "$force_flag"
    
    # Выбор типа очистки
    case "$cleanup_type" in
        "namespace")
            delete_namespace "$environment"
            ;;
        "apps")
            delete_applications "$environment"
            ;;
        "all")
            delete_namespace "$environment"
            cleanup_docker_images "$environment" "$force_flag"
            cleanup_docker_system "$environment" "$force_flag"
            ;;
        *)
            print_error "Недопустимый тип очистки: $cleanup_type"
            print_error "Используйте: namespace, apps, all"
            exit 1
            ;;
    esac
    
    # Показать статус после очистки
    show_status_after_cleanup "$environment"
    
    print_success "Очистка завершена!"
}

# Показать помощь
show_help() {
    echo "Очистка ресурсов Kubernetes"
    echo ""
    echo "Использование:"
    echo "  $0 [stage|prod] [--force] [namespace|apps|all]"
    echo ""
    echo "Параметры:"
    echo "  stage           Очистка stage среды (по умолчанию)"
    echo "  prod            Очистка production среды"
    echo "  --force         Пропустить подтверждения"
    echo "  namespace       Удалить весь namespace (по умолчанию)"
    echo "  apps            Удалить только приложения (оставить namespace)"
    echo "  all             Удалить namespace + Docker образы + очистить Docker"
    echo ""
    echo "Примеры:"
    echo "  $0 stage                                    # Очистка stage с подтверждением"
    echo "  $0 prod --force                             # Очистка prod без подтверждения"
    echo "  $0 stage --force apps                       # Удалить только приложения"
    echo "  $0 prod --force all                         # Полная очистка"
    echo ""
    echo "ВНИМАНИЕ:"
    echo "  - Удаление namespace удаляет ВСЕ ресурсы в нем"
    echo "  - Это действие необратимо"
    echo "  - Используйте --force для автоматического выполнения"
}

# Обработка параметров
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    show_help
    exit 0
fi

# Запуск
main "$@"

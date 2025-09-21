#!/bin/bash

# Откат развертывания в Kubernetes
# Использование: ./rollback.sh [stage|prod] [deployment-name]

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

# Показать историю rollout
show_rollout_history() {
    local environment=$1
    local deployment_name=$2
    local namespace="twentycrm${environment:+-$environment}"
    
    print_status "История rollout для deployment: $deployment_name"
    echo "----------------------------------------"
    
    kubectl rollout history deployment/"$deployment_name" -n "$namespace"
    echo ""
}

# Показать доступные версии для отката
show_available_versions() {
    local environment=$1
    local deployment_name=$2
    local namespace="twentycrm${environment:+-$environment}"
    
    print_status "Доступные версии для отката:"
    echo "----------------------------------------"
    
    # Получение истории rollout в JSON формате
    local history=$(kubectl rollout history deployment/"$deployment_name" -n "$namespace" -o json)
    
    # Извлечение версий
    echo "$history" | jq -r '.items[] | "\(.metadata.annotations."deployment.kubernetes.io/revision") - \(.metadata.creationTimestamp)"' 2>/dev/null || {
        print_warning "jq не установлен, показываем упрощенную историю"
        kubectl rollout history deployment/"$deployment_name" -n "$namespace"
    }
    echo ""
}

# Откат к предыдущей версии
rollback_to_previous() {
    local environment=$1
    local deployment_name=$2
    local namespace="twentycrm${environment:+-$environment}"
    
    print_status "Откат к предыдущей версии deployment: $deployment_name"
    
    if ! kubectl rollout undo deployment/"$deployment_name" -n "$namespace"; then
        print_error "Ошибка отката deployment"
        exit 1
    fi
    
    print_success "Откат инициирован"
}

# Откат к конкретной версии
rollback_to_version() {
    local environment=$1
    local deployment_name=$2
    local version=$3
    local namespace="twentycrm${environment:+-$environment}"
    
    print_status "Откат к версии $version deployment: $deployment_name"
    
    if ! kubectl rollout undo deployment/"$deployment_name" --to-revision="$version" -n "$namespace"; then
        print_error "Ошибка отката к версии $version"
        exit 1
    fi
    
    print_success "Откат к версии $version инициирован"
}

# Ожидание завершения отката
wait_for_rollout() {
    local environment=$1
    local deployment_name=$2
    local namespace="twentycrm${environment:+-$environment}"
    
    print_status "Ожидание завершения отката..."
    
    if ! kubectl rollout status deployment/"$deployment_name" -n "$namespace" --timeout=300s; then
        print_error "Откат не завершился в течение 5 минут"
        print_error "Проверьте статус: kubectl get pods -n $namespace"
        exit 1
    fi
    
    print_success "Откат завершен успешно"
}

# Проверка здоровья после отката
check_health_after_rollback() {
    local environment=$1
    local namespace="twentycrm${environment:+-$environment}"
    local service_name="twentycrm${environment:+-$environment}-server"
    
    print_status "Проверка здоровья после отката..."
    
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
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if curl -s -f "$health_url" > /dev/null 2>&1; then
            print_success "Приложение здорово после отката"
            break
        fi
        
        if [ $attempt -eq $max_attempts ]; then
            print_error "Приложение не отвечает на проверку здоровья после отката"
            kill $port_forward_pid 2>/dev/null || true
            exit 1
        fi
        
        print_status "Попытка $attempt/$max_attempts - ожидание..."
        sleep 10
        attempt=$((attempt + 1))
    done
    
    # Остановка проброса порта
    kill $port_forward_pid 2>/dev/null || true
}

# Показать статус после отката
show_status_after_rollback() {
    local environment=$1
    local deployment_name=$2
    local namespace="twentycrm${environment:+-$environment}"
    
    print_status "Статус после отката:"
    echo "----------------------------------------"
    
    # Статус pods
    kubectl get pods -n "$namespace" -l app=twentycrm
    
    # Статус deployment
    kubectl get deployment "$deployment_name" -n "$namespace"
    
    # Текущая версия
    local current_version=$(kubectl get deployment "$deployment_name" -n "$namespace" -o jsonpath='{.metadata.annotations."deployment.kubernetes.io/revision"}')
    print_status "Текущая версия deployment: $current_version"
}

# Интерактивный выбор версии для отката
interactive_rollback() {
    local environment=$1
    local deployment_name=$2
    local namespace="twentycrm${environment:+-$environment}"
    
    print_status "Интерактивный откат deployment: $deployment_name"
    
    # Показать доступные версии
    show_available_versions "$environment" "$deployment_name"
    
    # Запрос версии для отката
    echo -n "Введите номер версии для отката (или 'previous' для предыдущей версии): "
    read -r version
    
    if [[ "$version" == "previous" || "$version" == "" ]]; then
        rollback_to_previous "$environment" "$deployment_name"
    else
        # Проверка, что версия существует
        if ! kubectl rollout history deployment/"$deployment_name" -n "$namespace" | grep -q "$version"; then
            print_error "Версия $version не найдена"
            exit 1
        fi
        
        rollback_to_version "$environment" "$deployment_name" "$version"
    fi
}

# Основная функция
main() {
    local environment=${1:-stage}
    local deployment_name=${2:-"twentycrm${environment:+-$environment}-server"}
    local version=$3
    local namespace="twentycrm${environment:+-$environment}"
    
    # Валидация параметров
    if [[ "$environment" != "stage" && "$environment" != "prod" ]]; then
        print_error "Недопустимая среда: $environment"
        print_error "Используйте: stage или prod"
        exit 1
    fi
    
    print_status "Откат развертывания в $environment"
    echo "========================================"
    
    # Проверка подключения
    check_kubectl_connection
    
    # Проверка существования deployment
    if ! kubectl get deployment "$deployment_name" -n "$namespace" &> /dev/null; then
        print_error "Deployment $deployment_name не существует в namespace $namespace"
        exit 1
    fi
    
    # Показать текущую историю
    show_rollout_history "$environment" "$deployment_name"
    
    # Выбор версии для отката
    if [[ -n "$version" ]]; then
        # Откат к конкретной версии
        rollback_to_version "$environment" "$deployment_name" "$version"
    else
        # Интерактивный выбор
        interactive_rollback "$environment" "$deployment_name"
    fi
    
    # Ожидание завершения отката
    wait_for_rollout "$environment" "$deployment_name"
    
    # Проверка здоровья
    check_health_after_rollback "$environment"
    
    # Показать статус
    show_status_after_rollback "$environment" "$deployment_name"
    
    print_success "Откат завершен успешно!"
}

# Показать помощь
show_help() {
    echo "Откат развертывания в Kubernetes"
    echo ""
    echo "Использование:"
    echo "  $0 [stage|prod] [deployment-name] [version]"
    echo ""
    echo "Параметры:"
    echo "  stage           Откат в stage среду (по умолчанию)"
    echo "  prod            Откат в production среду"
    echo "  deployment-name Имя deployment для отката (по умолчанию: twentycrm-stage-server или twentycrm-server)"
    echo "  version         Конкретная версия для отката (опционально)"
    echo ""
    echo "Примеры:"
    echo "  $0 stage                                    # Интерактивный откат stage"
    echo "  $0 prod twentycrm-server                    # Интерактивный откат prod deployment"
    echo "  $0 stage twentycrm-stage-server 3          # Откат к версии 3"
    echo "  $0 prod twentycrm-server previous          # Откат к предыдущей версии"
    echo ""
    echo "Интерактивный режим:"
    echo "  Если версия не указана, скрипт покажет доступные версии"
    echo "  и предложит выбрать версию для отката"
}

# Обработка параметров
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    show_help
    exit 0
fi

# Запуск
main "$@"

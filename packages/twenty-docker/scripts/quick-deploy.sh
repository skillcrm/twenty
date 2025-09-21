#!/bin/bash

# Быстрый деплой в Kubernetes
# Использование: ./quick-deploy.sh [stage|prod]

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

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Генерация тега на основе времени
generate_tag() {
    local environment=$1
    local timestamp=$(date +"%Y%m%d-%H%M%S")
    local branch=$(git branch --show-current 2>/dev/null || echo "unknown")
    local commit=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
    
    echo "${environment}-${timestamp}-${branch}-${commit}"
}

# Быстрый деплой
quick_deploy() {
    local environment=${1:-stage}
    
    print_status "Быстрый деплой в $environment"
    
    # Генерация тега
    local tag=$(generate_tag "$environment")
    print_status "Используемый тег: $tag"
    
    # Запуск полного деплоя
    ./local-deploy.sh "$environment" "$tag"
}

# Показать помощь
show_help() {
    echo "Быстрый деплой в Kubernetes"
    echo ""
    echo "Использование:"
    echo "  $0 [stage|prod]"
    echo ""
    echo "Параметры:"
    echo "  stage    Деплой в stage среду (по умолчанию)"
    echo "  prod     Деплой в production среду"
    echo ""
    echo "Примеры:"
    echo "  $0 stage    # Деплой в stage с автогенерированным тегом"
    echo "  $0 prod     # Деплой в production с автогенерированным тегом"
    echo ""
    echo "Тег генерируется автоматически в формате:"
    echo "  {environment}-{timestamp}-{branch}-{commit}"
}

# Основная функция
main() {
    local environment=${1:-stage}
    
    # Валидация параметров
    if [[ "$environment" == "-h" || "$environment" == "--help" ]]; then
        show_help
        exit 0
    fi
    
    if [[ "$environment" != "stage" && "$environment" != "prod" ]]; then
        print_error "Недопустимая среда: $environment"
        print_error "Используйте: stage или prod"
        exit 1
    fi
    
    # Проверка, что мы в правильной директории
    if [[ ! -f "local-deploy.sh" ]]; then
        print_error "Запустите скрипт из директории scripts/"
        exit 1
    fi
    
    # Запуск быстрого деплоя
    quick_deploy "$environment"
}

# Запуск
main "$@"

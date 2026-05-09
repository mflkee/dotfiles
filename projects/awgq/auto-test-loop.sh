#!/bin/bash
# auto-test-loop.sh - Автоматический запуск тестов до успеха

cd ~/projects/awgq

MAX_ATTEMPTS=10
ATTEMPT=1

while [ $ATTEMPT -le $MAX_ATTEMPTS ]; do
    echo "=== Attempt $ATTEMPT/$MAX_ATTEMPTS ==="
    
    # Запускаем тесты
    python test-automation.py
    
    # Проверяем результат
    if [ $? -eq 0 ]; then
        echo "✅ SUCCESS on attempt $ATTEMPT!"
        exit 0
    fi
    
    echo "❌ Failed attempt $ATTEMPT, retrying..."
    echo "Waiting 5 seconds..."
    sleep 5
    
    ATTEMPT=$((ATTEMPT + 1))
done

echo "❌ All $MAX_ATTEMPTS attempts failed"
exit 1

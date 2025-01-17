#! /bin/bash

# Получаем текущий стандартный аудиовыход
current_sink=$(pactl get-default-sink)
echo "Текущий аудиовыход: $current_sink"

# Получаем список всех доступных аудиовыходов и их индексов
sinks=($(pactl list short sinks | awk '{print $2}'))
echo "Доступные аудиовыходы: ${sinks[@]}"

# Определяем количество доступных аудиовыходов
sinks_count=${#sinks[@]}
echo "Количество доступных аудиовыходов: $sinks_count"

# Находим индекс текущего аудиовыхода в массиве sinks
current_sink_index=-1
for i in "${!sinks[@]}"; do
   if [[ "${sinks[$i]}" = "${current_sink}" ]]; then
       current_sink_index=$i
       break
   fi
done

if [ "$current_sink_index" -eq -1 ]; then
    echo "Текущий аудиовыход не найден среди доступных."
    exit 1
fi
echo "Индекс текущего аудиовыхода: $current_sink_index"

# Вычисляем индекс следующего аудиовыхода
next_sink_index=$(( (current_sink_index + 1) % sinks_count ))
echo "Индекс следующего аудиовыхода: $next_sink_index"

# Устанавливаем следующий аудиовыход по умолчанию
next_sink=${sinks[$next_sink_index]}
pactl set-default-sink "$next_sink" || { echo "Не удалось установить следующий аудиовыход"; exit 1; }
echo "Следующий аудиовыход: $next_sink"

# Перемещаем все аудиопотоки на новый аудиовыход
sink_inputs=$(pactl list short sink-inputs | awk '{print $1}')
for input in $sink_inputs; do
    pactl move-sink-input "$input" "$next_sink" || { echo "Не удалось переместить аудиопоток $input"; exit 1; }
done

echo "Аудиовыход изменен на $next_sink"

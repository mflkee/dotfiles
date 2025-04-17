import os
import subprocess
import time
from datetime import datetime, timedelta
import logging

# Настройки
LOG_DIR = "/var/log/nvim_tracker"
DAILY_LOG_FORMAT = "%Y-%m-%d.log"
WEEKLY_SUMMARY_FORMAT = "weekly_summary_%Y-%W.log"
MONTHLY_SUMMARY_FORMAT = "monthly_summary_%Y-%m.log"
YEARLY_SUMMARY_FORMAT = "yearly_summary_%Y.log"

# Создание директории для логов
os.makedirs(LOG_DIR, exist_ok=True)

# Настройка логгера
def setup_logger(log_file):
    logger = logging.getLogger("kitty_tracker")
    logger.setLevel(logging.INFO)  # Уровень INFO для минимизации логов
    handler = logging.FileHandler(log_file)
    formatter = logging.Formatter("[%(asctime)s] %(levelname)s: %(message)s", datefmt="%Y-%m-%d %H:%M:%S")
    handler.setFormatter(formatter)
    logger.addHandler(handler)
    return logger

# Получение текущего фокусированного окна
def get_focused_window():
    try:
        window_id = subprocess.check_output(["bspc", "query", "-N", "-n", "focused"]).decode().strip()
        return window_id if window_id else None  # Если пусто, вернуть None
    except subprocess.CalledProcessError as e:
        return None

# Проверка, является ли окно kitty
def is_kitty_window(window_id):
    if not window_id:
        return False
    try:
        wm_class = subprocess.check_output(["xprop", "-id", window_id, "WM_CLASS"]).decode().strip()
        return "kitty" in wm_class.lower()
    except Exception:
        return False

# Чтение накопленного времени из лога
def read_daily_total(log_file):
    try:
        with open(log_file, "r") as f:
            for line in reversed(f.readlines()):
                if "Total for the day:" in line:
                    total_time_str = line.split(": ")[-1].strip()
                    hours, minutes, seconds = map(int, total_time_str.split(":"))
                    return hours * 3600 + minutes * 60 + seconds
    except FileNotFoundError:
        return 0
    return 0

# Генерация сводок
def generate_summary(logger, log_dir, summary_format, period_func):
    summary_file = os.path.join(log_dir, datetime.now().strftime(summary_format))
    total_time = {}

    # Сбор данных из всех дневных логов
    for log_name in os.listdir(log_dir):
        if log_name.endswith(".log") and not log_name.startswith("summary"):
            log_date = datetime.strptime(log_name.split(".")[0], "%Y-%m-%d")
            period_key = period_func(log_date)
            daily_log_file = os.path.join(log_dir, log_name)

            # Чтение последней строки с "Total for the day"
            try:
                with open(daily_log_file, "r") as f:
                    for line in reversed(f.readlines()):
                        if "Total for the day:" in line:
                            total_time_str = line.split(": ")[-1].strip()
                            hours, minutes, seconds = map(int, total_time_str.split(":"))
                            total_time[period_key] = total_time.get(period_key, 0) + (hours * 3600 + minutes * 60 + seconds)
                            break
            except Exception as e:
                logger.error(f"Error reading {daily_log_file}: {e}")

    # Запись сводки
    with open(summary_file, "w") as f:
        for period, seconds in total_time.items():
            f.write(f"{period}:\n")
            f.write(f"- Total time: {timedelta(seconds=seconds)}\n")

# Основная логика трекинга
def track_kitty_activity():
    daily_log_file = os.path.join(LOG_DIR, datetime.now().strftime(DAILY_LOG_FORMAT))
    logger = setup_logger(daily_log_file)
    start_time = None
    total_daily_time = read_daily_total(daily_log_file)  # Чтение накопленного времени из лога
    previous_focus = None  # Для отслеживания предыдущего состояния

    while True:
        current_time = time.time()
        focused_window = get_focused_window()
        is_current_kitty = is_kitty_window(focused_window)

        # Если текущее окно - kitty и сессия не начата
        if is_current_kitty and start_time is None:
            start_time = current_time
            logger.info("Kitty session started")
            previous_focus = focused_window

        # Если текущее окно не kitty или фокус потерян (None), и сессия активна
        elif not is_current_kitty and start_time is not None:
            elapsed_time = current_time - start_time
            logger.info(f"Kitty session ended after {timedelta(seconds=int(elapsed_time))}")
            total_daily_time += elapsed_time
            logger.info(f"Total for the day: {timedelta(seconds=int(total_daily_time))}")
            start_time = None
            previous_focus = None

        # Если фокус переключился на другое окно kitty
        elif focused_window != previous_focus and start_time is not None:
            # Завершаем предыдущую сессию
            elapsed_time = current_time - start_time
            logger.info(f"Kitty session ended after {timedelta(seconds=int(elapsed_time))}")
            total_daily_time += elapsed_time
            logger.info(f"Total for the day: {timedelta(seconds=int(total_daily_time))}")
            # Начинаем новую сессию, если новое окно - kitty
            if is_current_kitty:
                start_time = current_time
                logger.info("Kitty session started")
                previous_focus = focused_window
            else:
                start_time = None
                previous_focus = None

        time.sleep(1)

if __name__ == "__main__":
    track_kitty_activity()

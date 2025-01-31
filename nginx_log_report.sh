#!/bin/bash

# Файл блокировки для предотвращения параллельных запусков
LOCKFILE="/var/tmp/nginx_log_report.lock"
if [ -f "$LOCKFILE" ]; then
    echo "Скрипт уже выполняется."
    exit 1
fi
touch "$LOCKFILE"

# Файл с последним временем запуска
LAST_RUN_FILE="/var/tmp/nginx_last_run"
CURRENT_TIME=$(date +"%d/%b/%Y:%H:%M:%S")  # Формат для логов Nginx
LOG_FILE="/var/log/nginx/access.log"
ERROR_LOG="/var/log/nginx/error.log"
EMAIL="mpostin@mail.ru"

# Если файла нет, задаем стартовую точку (час назад)
if [ ! -f "$LAST_RUN_FILE" ]; then
    LAST_RUN_TIME=$(date -d "1 hour ago" +"%d/%b/%Y:%H:%M:%S")
else
    LAST_RUN_TIME=$(cat "$LAST_RUN_FILE")
fi
echo "$CURRENT_TIME" > "$LAST_RUN_FILE"

# Фильтрация логов с момента последнего запуска
LOG_TMP=$(mktemp)

# Фильтрация записей из access.log по времени (с момента последнего запуска)
awk -v start="$LAST_RUN_TIME" -v end="$CURRENT_TIME" '
    $4 >= "[" start && $4 <= "[" end {print $0}
' "$LOG_FILE" > "$LOG_TMP"

# 1️⃣ Топ-5 IP с наибольшим числом запросов
TOP_IP=$(awk '{print $1}' "$LOG_TMP" | sort | uniq -c | sort -nr | head -5)

# 2️⃣ Топ-5 URL с наибольшим числом запросов
TOP_URL=$(awk '{print $7}' "$LOG_TMP" | sort | uniq -c | sort -nr | head -5)

# 3️⃣ Ошибки веб-сервера (из error.log)
ERRORS=$(grep -i "error" "$ERROR_LOG" | tail -n 10)

# 4️⃣ Статистика по HTTP-кодам
HTTP_CODES=$(awk '{print $9}' "$LOG_TMP" | sort | uniq -c | sort -nr)

# 📩 Формируем письмо
EMAIL_SUBJECT="Nginx Log Report [$LAST_RUN_TIME - $CURRENT_TIME]"
EMAIL_BODY="
Отчёт по логам Nginx за период: $LAST_RUN_TIME - $CURRENT_TIME

📌 Топ-5 IP:
$TOP_IP

📌 Топ-5 URL:
$TOP_URL

📌 Ошибки сервера:
$ERRORS

📌 HTTP-коды:
$HTTP_CODES
"

# Отправка письма
echo -e "$EMAIL_BODY" | mail -s "$EMAIL_SUBJECT" "$EMAIL"

# Удаляем временные файлы
rm -f "$LOG_TMP"
rm -f "$LOCKFILE"


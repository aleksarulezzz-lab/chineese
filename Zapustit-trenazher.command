#!/bin/bash
# Запускает тренажёр по адресу http://localhost:8765 — так Safari разрешает микрофон,
# а прогресс сохраняется в файл progress.json в этой папке.
cd "$(dirname "$0")" || exit 1
PORT=8765
URL="http://localhost:$PORT/index.html"

# 1. Проверяем, что все файлы на месте
for f in index.html server.py; do
  if [ ! -f "$f" ]; then
    echo "❌ В папке нет файла $f. Положите его рядом с этим файлом запуска."
    read -n 1 -s -r -p "Нажмите любую клавишу, чтобы закрыть..."; exit 1
  fi
done

# 2. Ищем Python 3
PY=""
for p in python3 /usr/bin/python3 /usr/local/bin/python3 /opt/homebrew/bin/python3 /Library/Frameworks/Python.framework/Versions/Current/bin/python3; do
  if command -v "$p" >/dev/null 2>&1 && "$p" -c "import http.server" >/dev/null 2>&1; then PY="$p"; break; fi
done
if [ -z "$PY" ]; then
  echo "❌ На Mac не установлен Python 3 — без него тренажёр не запустится."
  echo "   Скачайте и установите: https://www.python.org/downloads/macos/"
  echo "   (или выполните в Терминале: xcode-select --install), затем запустите этот файл снова."
  open "https://www.python.org/downloads/macos/"
  read -n 1 -s -r -p "Нажмите любую клавишу, чтобы закрыть..."; exit 1
fi

# 3. Если на порту висит старый/чужой сервер без сохранения прогресса — перезапускаем
if lsof -i :$PORT -sTCP:LISTEN >/dev/null 2>&1; then
  if ! curl -s "http://localhost:$PORT/api/progress" | head -c 1 | grep -q '[{n]'; then
    kill $(lsof -ti :$PORT -sTCP:LISTEN) 2>/dev/null
    sleep 1
  fi
fi

# 4. Запускаем сервер и ждём, пока он ответит
if ! lsof -i :$PORT -sTCP:LISTEN >/dev/null 2>&1; then
  "$PY" server.py &
  SERVER_PID=$!
  trap 'kill $SERVER_PID 2>/dev/null' EXIT
fi
for i in $(seq 1 20); do
  curl -s -o /dev/null "http://localhost:$PORT/api/progress" && break
  sleep 0.5
done
if ! curl -s -o /dev/null "http://localhost:$PORT/api/progress"; then
  echo "❌ Сервер не запустился. Сообщение об ошибке — выше в этом окне."
  read -n 1 -s -r -p "Нажмите любую клавишу, чтобы закрыть..."; exit 1
fi

open -a Safari "$URL" 2>/dev/null || open "$URL"
echo "✅ Тренажёр открыт: $URL"
echo "   Прогресс сохраняется в файл progress.json в папке тренажёра."
echo "   Это окно можно свернуть, но НЕ закрывайте его, пока ребёнок занимается —"
echo "   иначе ссылка перестанет открываться."
wait

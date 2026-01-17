#!/bin/bash
echo "[System] Starting Hytale Server..."

(
  while true; do
    echo "[$(date +%T)] Info: Player 'Kweebec' is wandering Orbis"
    sleep 5
  done
) &
LOG_PID=$!

while read -r line; do
  if [ "$line" == "stop" ]; then
    echo "[System] Stopping gracefully..."
    kill $LOG_PID
    exit 0
  fi
  echo "[Console] Received: $line"
done

echo "[System] Connection lost. Shutting down..."
kill $LOG_PID
exit 0

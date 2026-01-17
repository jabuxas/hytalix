#!/bin/bash

echo "[System] Starting Hytale Server..."
sleep 1
echo "[System] Loading World: Orbis..."
sleep 1
echo "[System] Server started on port 25565"

# Loop forever to simulate a running game
while true; do
  echo "[$(date +%T)] Info: Player 'Kweebec' joined the game"
  sleep 3
  echo "[$(date +%T)] Info: Saving world..."
  sleep 5
done

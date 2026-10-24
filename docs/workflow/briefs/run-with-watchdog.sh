#!/bin/zsh
# usage: run-with-watchdog.sh <session-id> <output-file> <log> [brief-file]
id=$1; out=$2; log=$3; brief=$4
cd /Users/adrifadilah/Desktop/pikicam
sess_dir=~/.pi/agent/sessions/--Users-adrifadilah-Desktop-pikicam--
for attempt in {1..8}; do
  [ -s "$out" ] && break
  echo "== attempt $attempt $(date)" >> $log
  if [ -n "$brief" ] && ! ls $sess_dir/*_$id.jsonl >/dev/null 2>&1; then msg="$(cat $brief)"; else msg="Your previous turn was cut off by a network error. Continue the task exactly where you left off, reuse what you already found (your probes and notes are still on disk), and finish by writing the complete output file $out. Do not restart from scratch."; fi
  pi -p --model opencode/space-bunny-free --thinking max -ns -np -xt edit --session-id $id "$msg" >> $log 2>&1 &
  pid=$!
  while kill -0 $pid 2>/dev/null; do
    sleep 60
    f=$(ls -t $sess_dir/*_$id.jsonl 2>/dev/null | head -1)
    age=$(( $(date +%s) - $(/usr/bin/stat -f %m "$f") ))
    if [ $age -gt 900 ]; then echo "== stalled ${age}s, killing" >> $log; kill $pid; sleep 2; kill -9 $pid 2>/dev/null; fi
  done
done
echo "$id finished: $( [ -s $out ] && wc -l < $out || echo MISSING)"

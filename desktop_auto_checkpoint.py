#!/usr/bin/env python3
import os
import subprocess
import time
import signal
from pathlib import Path
from datetime import datetime

# -------- CONFIG --------
PROJECT_DIR = r"C:\Users\alex1\Documents\CookieSimulator"
CHECK_INTERVAL = 180  # seconds (3 minutes)
# ------------------------

def now():
    return datetime.utcnow().isoformat() + "Z"

def git_has_changes():
    try:
        status = subprocess.check_output(
            ["git", "-C", PROJECT_DIR, "status", "--porcelain"]
        ).decode().strip()
        return bool(status)
    except:
        return False

def git_commit_push(message):
    try:
        subprocess.run(["git", "-C", PROJECT_DIR, "add", "-A"])
        subprocess.run(
            ["git", "-C", PROJECT_DIR, "commit", "-m", message],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL
        )
        subprocess.run(
            ["git", "-C", PROJECT_DIR, "push"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL
        )
        print(f"[{now()}] ✓ Auto checkpoint committed & pushed")
    except Exception as e:
        print("Git error:", e)

def graceful_exit(sig, frame):
    print("\nShutting down…")
    if git_has_changes():
        git_commit_push(f"final-checkpoint {now()}")
    exit(0)

signal.signal(signal.SIGINT, graceful_exit)

print("Desktop Auto Checkpoint Running…")
print("Watching:", PROJECT_DIR)
print("Interval:", CHECK_INTERVAL, "seconds")
print("Press CTRL+C to stop.\n")

while True:
    time.sleep(CHECK_INTERVAL)
    if git_has_changes():
        git_commit_push(f"auto-checkpoint {now()}")
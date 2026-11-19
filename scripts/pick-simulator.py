#!/usr/bin/env python3
"""Wählt dynamisch einen verfügbaren Simulator (neueste iOS-Runtime).
Aufruf: pick-simulator.py iphone|ipad  -> gibt 'udid|name|os' aus."""
import json, re, subprocess, sys

kind = sys.argv[1]
prefs = {
    "iphone": ["iPhone 17", "iPhone 16", "iPhone 17 Pro", "iPhone Air"],
    "ipad": ["iPad (A16)", "iPad Air 11-inch (M4)", "iPad Air 11-inch (M3)", "iPad (10th generation)"],
}[kind]
prefix = "iPhone" if kind == "iphone" else "iPad"

data = json.loads(subprocess.check_output(["xcrun", "simctl", "list", "devices", "available", "-j"]))
runtimes = []
for rt, devices in data["devices"].items():
    m = re.search(r"SimRuntime\.iOS-(\d+)-(\d+)(?:-(\d+))?$", rt)
    if m and devices:
        runtimes.append((tuple(int(x or 0) for x in m.groups()), rt, devices))
if not runtimes:
    sys.exit("Keine iOS-Simulator-Runtime gefunden")
runtimes.sort(reverse=True)
for version, rt, devices in runtimes:
    candidates = [d for d in devices if d["name"].startswith(prefix)]
    if not candidates:
        continue
    chosen = next((d for p in prefs for d in candidates if d["name"] == p), candidates[0])
    os_str = f"{version[0]}.{version[1]}" + (f".{version[2]}" if version[2] else "")
    print(f'{chosen["udid"]}|{chosen["name"]}|{os_str}')
    sys.exit(0)
sys.exit(f"Kein {prefix}-Simulator gefunden")

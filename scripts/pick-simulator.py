#!/usr/bin/env python3
"""Wählt dynamisch einen verfügbaren Simulator.

Aufruf: pick-simulator.py iphone|ipad  -> gibt 'udid|name|os' aus.

StoreKit-Tests über `xcodebuild test` laden auf iOS-26.3- und neueren
Simulatoren keine Produkte: die CLI überträgt die .storekit-Datei nicht
(Apple Feedback FB22237318, auch mit Xcode 26.6 / iOS 26.5 noch offen).
iOS 26.2 ist die neueste Runtime, auf der dieselben Tests laufen. Sie wird
bevorzugt; fehlt sie, fällt die Auswahl auf die neueste Runtime zurück.
"""
import json, re, subprocess, sys

kind = sys.argv[1]
prefs = {
    "iphone": ["iPhone 17", "iPhone 16", "iPhone 17 Pro", "iPhone Air"],
    "ipad": ["iPad (A16)", "iPad Air 11-inch (M4)", "iPad Air 11-inch (M3)", "iPad (10th generation)"],
}[kind]
prefix = "iPhone" if kind == "iphone" else "iPad"
# 26.2.x einschließen, 26.3 und neuer auslassen.
STOREKIT_MAX = (26, 2, 99)

data = json.loads(subprocess.check_output(["xcrun", "simctl", "list", "devices", "available", "-j"]))
runtimes = []
for rt, devices in data["devices"].items():
    m = re.search(r"SimRuntime\.iOS-(\d+)-(\d+)(?:-(\d+))?$", rt)
    if m and devices:
        runtimes.append((tuple(int(x or 0) for x in m.groups()), rt, devices))
if not runtimes:
    sys.exit("Keine iOS-Simulator-Runtime gefunden")

def choose(pool):
    for version, rt, devices in sorted(pool, reverse=True):
        candidates = [d for d in devices if d["name"].startswith(prefix)]
        if not candidates:
            continue
        chosen = next((d for p in prefs for d in candidates if d["name"] == p), candidates[0])
        os_str = f"{version[0]}.{version[1]}" + (f".{version[2]}" if version[2] else "")
        print(f'{chosen["udid"]}|{chosen["name"]}|{os_str}', file=sys.stderr)
        print(f'{chosen["udid"]}|{chosen["name"]}|{os_str}')
        return True
    return False

compatible = [r for r in runtimes if r[0] <= STOREKIT_MAX]
if not choose(compatible):
    print("Keine Runtime <= iOS 26.2, verwende die neueste.", file=sys.stderr)
    if not choose(runtimes):
        sys.exit(f"Kein {prefix}-Simulator gefunden")

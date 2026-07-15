#!/usr/bin/env python3
"""Elige el UDID del mejor iPad disponible del simulador (Pro > Air > cualquiera).

Uso: python3 pick_ipad.py [ruta a devices.json de `simctl list -j devices available`]
Imprime el UDID elegido, o nada si no hay iPad (el workflow crea uno en ese caso).
Extraído del heredoc del workflow: un heredoc en columna 0 dentro de `run: |`
rompe el YAML — por eso vive aquí como archivo.
"""
import json
import sys

path = sys.argv[1] if len(sys.argv) > 1 else "/tmp/devices.json"
with open(path) as f:
    data = json.load(f)

ipads = []
for runtime, devs in data.get("devices", {}).items():
    if "iOS" not in runtime:
        continue
    for dev in devs:
        if not dev.get("isAvailable", True):
            continue
        name = dev.get("name", "")
        if "iPad" in name:
            # prioridad: iPad Pro > iPad Air > cualquier iPad
            score = 3 if "Pro" in name else (2 if "Air" in name else 1)
            ipads.append((score, name, dev["udid"]))

ipads.sort(reverse=True)
if ipads:
    print(ipads[0][2])

#!/usr/bin/env python3
"""segment_video.py — Ola GestureProbe, fábrica de tutoriales (carril G-A).

Parsea los marcadores ``GESTURE-STEP N: <herramienta> — <acción>`` que
``GearScenarioTests`` emite con os_log (streamados a ``artifacts/app-log.txt``),
calcula el offset de cada paso relativo al inicio del video de la sesión, y corta
con ffmpeg un clip por paso:

    artifacts/tutorials/NN-<slug-herramienta>.mp4

Además escribe un manifest ``tutorials.json`` (paso, herramienta, acción, rango de
tiempo, archivo).

DEGRADACIÓN ELEGANTE (obligatoria — el step del workflow lleva continue-on-error,
pero este script SIEMPRE sale 0 y hace lo mejor posible):
  - Si no hay ffmpeg: no corta; copia el video completo y escribe el manifest con
    los rangos calculados (el corte se puede hacer local luego).
  - Si el log no tiene GESTURE-STEP o no se puede parsear: sube el video completo y
    un manifest mínimo.
  - Si no hay video: escribe solo el manifest (los rangos siguen siendo útiles).

Uso:
  segment_video.py --video V.mp4 --log app-log.txt --out DIR
"""

import argparse
import json
import os
import re
import shutil
import subprocess
import sys

# GESTURE-STEP con timestamp del log de `simctl spawn ... log stream`.
# Formato típico de la línea de `log stream` (default/compact):
#   2026-07-15 12:34:56.789012-0500  ... GESTURE-STEP 3: Primitivas/Caja — crear caja
# Capturamos: (a) el timestamp HH:MM:SS.ffffff, (b) N, (c) herramienta, (d) acción.
LINE_RE = re.compile(
    r"(?P<h>\d{2}):(?P<m>\d{2}):(?P<s>\d{2})\.(?P<frac>\d+)"
    r".*?GESTURE-STEP\s+(?P<n>\d+):\s*(?P<tool>.+?)\s+[—-]\s+(?P<action>.+?)\s*$"
)

# Fallback: línea SIN timestamp reconocible pero CON el marcador (usaremos índice).
MARK_RE = re.compile(r"GESTURE-STEP\s+(?P<n>\d+):\s*(?P<tool>.+?)\s+[—-]\s+(?P<action>.+?)\s*$")


def log(msg):
    print(f"[segment_video] {msg}", file=sys.stderr)


def slugify(text):
    text = text.strip().lower()
    out = []
    for ch in text:
        if ch.isascii() and (ch.isalnum()):
            out.append(ch)
        else:
            out.append("-")
    s = "".join(out)
    while "--" in s:
        s = s.replace("--", "-")
    return s.strip("-") or "step"


def secs_of(h, m, s, frac):
    # frac es una cadena de dígitos tras el punto; normalizar a fracción de segundo.
    frac_val = float("0." + frac) if frac else 0.0
    return int(h) * 3600 + int(m) * 60 + int(s) + frac_val


def parse_steps(log_path):
    """Devuelve lista de dicts {n, tool, action, abs_secs?} en orden de aparición.

    Si hay timestamps, ``abs_secs`` está presente (segundos absolutos del día). Si no,
    se omite y el caller cae al reparto uniforme.
    """
    steps = []
    if not log_path or not os.path.isfile(log_path):
        log(f"log ausente: {log_path!r}")
        return steps
    try:
        with open(log_path, "r", encoding="utf-8", errors="replace") as f:
            for line in f:
                mt = LINE_RE.search(line)
                if mt:
                    steps.append({
                        "n": int(mt.group("n")),
                        "tool": mt.group("tool").strip(),
                        "action": mt.group("action").strip(),
                        "abs_secs": secs_of(mt.group("h"), mt.group("m"),
                                            mt.group("s"), mt.group("frac")),
                    })
                    continue
                mk = MARK_RE.search(line)
                if mk:
                    steps.append({
                        "n": int(mk.group("n")),
                        "tool": mk.group("tool").strip(),
                        "action": mk.group("action").strip(),
                    })
    except OSError as e:
        log(f"no se pudo leer el log: {e}")
    # Dedup por N conservando el PRIMER hit (el os_log se emite antes de la acción).
    seen = set()
    unique = []
    for st in steps:
        if st["n"] in seen:
            continue
        seen.add(st["n"])
        unique.append(st)
    unique.sort(key=lambda x: x["n"])
    return unique


def video_duration(video_path):
    """Duración del video en segundos vía ffprobe; None si falla."""
    if not shutil.which("ffprobe"):
        return None
    try:
        out = subprocess.run(
            ["ffprobe", "-v", "error", "-show_entries", "format=duration",
             "-of", "default=noprint_wrappers=1:nokey=1", video_path],
            capture_output=True, text=True, timeout=60,
        )
        val = out.stdout.strip()
        return float(val) if val else None
    except (subprocess.SubprocessError, ValueError):
        return None


def compute_ranges(steps, duration):
    """Asigna a cada paso [start, end) en segundos RELATIVOS al inicio del video.

    Estrategia:
      - Con timestamps absolutos: el primer paso ancla t=0 (el video empezó ~antes;
        no tenemos el instante exacto de inicio del recordVideo, así que anclamos al
        primer marcador y desplazamos hacia atrás un pequeño pre-roll). Cada frontera
        es el timestamp del paso siguiente.
      - Sin timestamps: reparto uniforme sobre la duración (o 3s/paso si no hay dur).
    """
    if not steps:
        return []
    have_ts = all("abs_secs" in st for st in steps)
    ranges = []
    PRE_ROLL = 0.8  # segundos antes del marcador para que el clip incluya el gesto entero

    if have_ts:
        base = steps[0]["abs_secs"]
        # Corregir vuelta de medianoche (raro en CI pero barato de cubrir).
        rel = []
        prev = None
        acc = 0.0
        for st in steps:
            t = st["abs_secs"] - base
            if prev is not None and t < prev:
                acc += 86400.0  # cruzó medianoche
            rel.append(t + acc)
            prev = t
        for i, st in enumerate(steps):
            start = max(0.0, rel[i] - PRE_ROLL)
            if i + 1 < len(steps):
                end = max(start + 0.1, rel[i + 1] - PRE_ROLL * 0.5)
            else:
                end = (duration if duration else rel[i] + 6.0)
            ranges.append((start, end))
    else:
        # Reparto uniforme.
        total = duration if duration else 3.0 * len(steps)
        span = total / len(steps)
        for i in range(len(steps)):
            ranges.append((i * span, (i + 1) * span))
    return ranges


def cut_clip(video, start, end, dest):
    """Corta [start,end) con ffmpeg. True si el archivo resultó existente y no vacío."""
    dur = max(0.1, end - start)
    try:
        subprocess.run(
            ["ffmpeg", "-y", "-ss", f"{start:.3f}", "-i", video,
             "-t", f"{dur:.3f}", "-c:v", "libx264", "-preset", "veryfast",
             "-pix_fmt", "yuv420p", "-an", dest],
            capture_output=True, text=True, timeout=180,
        )
    except subprocess.SubprocessError as e:
        log(f"ffmpeg falló en {dest}: {e}")
        return False
    return os.path.isfile(dest) and os.path.getsize(dest) > 0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--video", required=True)
    ap.add_argument("--log", required=True)
    ap.add_argument("--out", required=True)
    args = ap.parse_args()

    os.makedirs(args.out, exist_ok=True)
    manifest_path = os.path.join(args.out, "tutorials.json")

    steps = parse_steps(args.log)
    have_video = os.path.isfile(args.video)
    have_ffmpeg = shutil.which("ffmpeg") is not None
    duration = video_duration(args.video) if have_video else None
    ranges = compute_ranges(steps, duration)

    manifest = {
        "source_video": os.path.basename(args.video) if have_video else None,
        "video_duration_secs": duration,
        "ffmpeg_available": have_ffmpeg,
        "step_count": len(steps),
        "degraded": False,
        "clips": [],
    }

    # Degradación: sin pasos, o sin video, o sin ffmpeg → sube video completo + manifest.
    if not steps or not have_video or not have_ffmpeg:
        reason = []
        if not steps:
            reason.append("sin marcadores GESTURE-STEP")
        if not have_video:
            reason.append("sin video")
        if not have_ffmpeg:
            reason.append("sin ffmpeg")
        manifest["degraded"] = True
        manifest["degraded_reason"] = ", ".join(reason)
        # Anexar los rangos calculados (útiles para corte local posterior).
        for i, st in enumerate(steps):
            start, end = ranges[i] if i < len(ranges) else (None, None)
            manifest["clips"].append({
                "step": st["n"], "tool": st["tool"], "action": st["action"],
                "start_secs": round(start, 3) if start is not None else None,
                "end_secs": round(end, 3) if end is not None else None,
                "file": None,
            })
        # Copiar el video completo al out para que el artifact lo lleve.
        if have_video:
            try:
                shutil.copy2(args.video, os.path.join(args.out, os.path.basename(args.video)))
            except OSError as e:
                log(f"no se pudo copiar el video completo: {e}")
        with open(manifest_path, "w") as f:
            json.dump(manifest, f, indent=2, ensure_ascii=False)
        log(f"DEGRADADO ({manifest['degraded_reason']}): manifest + video completo escritos.")
        return 0

    # Camino feliz: cortar clip por paso.
    for i, st in enumerate(steps):
        start, end = ranges[i]
        fname = f"{st['n']:02d}-{slugify(st['tool'])}.mp4"
        dest = os.path.join(args.out, fname)
        ok = cut_clip(args.video, start, end, dest)
        manifest["clips"].append({
            "step": st["n"], "tool": st["tool"], "action": st["action"],
            "start_secs": round(start, 3), "end_secs": round(end, 3),
            "file": fname if ok else None,
        })
        if not ok:
            manifest["degraded"] = True

    with open(manifest_path, "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=2, ensure_ascii=False)
    log(f"Listo: {len(manifest['clips'])} clips; manifest en {manifest_path}")
    return 0


if __name__ == "__main__":
    # SIEMPRE salir 0: la degradación es parte del contrato (nunca romper el job).
    try:
        sys.exit(main())
    except Exception as e:  # noqa: BLE001 — red de seguridad final
        log(f"error inesperado, degradando a exit 0: {e}")
        sys.exit(0)

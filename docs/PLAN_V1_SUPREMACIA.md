# AppForge Studio → v1.0: Plan de Síntesis y Superioridad (jun-2026)

## Contexto

AppForge Studio será la app 3D todo-en-uno para iPad (escultura + pintura 3D + CAD + animación + export a impresión 3D), gratis y open-source, superior a Shapr3D ($299/año), Nomad Sculpt, Feather3D y uMake/Valence a junio 2026. Nadie unifica las 5 disciplinas. Además es la herramienta de modelado que Tangerine necesita.

**Estado verificado hoy:**
- PR #1 (`f0/wave1-critical-fixes`) → **CI VERDE: build + tests pasando** (primera ejecución real de tests en la historia del repo). Fixes BUG1/2/5/7/9 compilados y validados en Xcode real.
- Zona de código viva confirmada contra `project.yml`: `ios-app/AppForgeStudio/{Core,Features,Sources,Tests}` (141 .swift + 5 .metal compilados).
- Duplicación real detectada: docs canónicos en 2 zonas, workflow fantasma, carpetas muertas, `Hi-Rez-Satin/` (377 .swift sin trackear), archivo `nul`.
- ⚠️ `ios-app/AppForgeStudio/AppForgeStudio/Info.plist` **NO es huérfano**: `project.yml` lo referencia 3× (`INFOPLIST_FILE`). NO se borra.
- Plan maestro existente: `docs/PLAN_MAESTRO_APPFORGE.md` (9 fases, 32 micro-tareas). Este plan lo EXTIENDE, no lo reemplaza.

**Método:** Claude (Fable 5) = arquitecto/orquestador/revisor. Agentes Nexus (DeepSeek pro/flash) = implementación con specs exactos. GitHub Actions macos = único compilador (no hay Mac). Cada ola: specs → Nexus paralelos por archivos disjuntos → revisión de RESUMEN → commit/PR → CI verde = gate.

---

## ETAPA A — Consolidación (esta semana)

### A1. Merge PR #1 a main
- `gh pr merge 1 --squash --delete-branch` → verificar CI verde en main.

### A2. Limpieza F0.T8 — una sola carpeta clara para Andrés y Gotchi
Branch `f0/cleanup`. Operaciones SOLO con `git rm`/`git mv` (recuperables) — NUNCA `Remove-Item -Recurse -Force` (regla de la casa):
1. **Docs canónicos SOLO en raíz del repo.** Fusionar contenido más reciente de cada par (BRAIN: gana el de `ios-app/` 10-jun; GOTCHI: gana raíz; TODO/DECISIONS: fusionar por fecha) → `git rm` de las copias en `ios-app/AppForgeStudio/`.
2. `git rm ios-app/AppForgeStudio/.github/workflows/build.yml` (GitHub lo ignora; solo confunde — el real es el de raíz).
3. Borrar archivo basura `nul` (raíz).
4. **NO tocar:** `AppForgeStudio/Info.plist` (referenciado), `Build/`, `Preview/`, `en.lproj/`, `es.lproj/` (vacíos y no trackeados — inofensivos; `es/en.lproj` se reutilizarán en D3 localización).
5. `Hi-Rez-Satin/` → `git mv` imposible (untracked): `Move-Item` a `vendor/Satin/` + crear `vendor/README.md` ("clon Satin 13.0.0 para vendorización fase FR — aún no compilado; SPM sigue trayendo el oficial"). Añadir `vendor/Satin/` a `.gitignore` por ahora.
6. Consolidar los ~20 docs de análisis de `ios-app/AppForgeStudio/docs/` → `git mv` a `docs/archive/` en raíz.
7. Actualizar GOTCHI.md raíz: nueva regla "docs canónicos SOLO en raíz; código SOLO en ios-app/AppForgeStudio/{Core,Features,Sources,Tests}".
- **Gate:** PR → CI verde (la limpieza no puede romper el build) + `git ls-files ios-app | grep -E '\.md$|\.github'` = 0 resultados canónicos.

---

## ETAPA B — Ejecutar el plan maestro existente (olas Nexus F1→F5)

Secuencia del plan maestro con ruta crítica F1→F2→F4→F5 (F3 y FR paralelizables):
- **W2 (F1):** suite de tests sólida — subir de 49 a ≥65 tests; tests de regresión para los 5 bugs corregidos (layout de structs GPU verificado por test, contador de rebuilds). Gate: CI tests verdes.
- **W3 (F2):** pipeline táctil→sculpt impecable: raycast, brush radius en pantalla, los 2 riesgos residuales de la ola 1 (clave `model.name`→UUID; sculpt path para modelos non-PBR). Gate: CI + captura de simulador en CI (xcrun simctl screenshot como artifact).
- **W4 (F3, paralela):** CAD: conectar CADModeView con los 5 engines, mediciones 3D visibles, historia editable (CADHistoryTree ya existe — integrarla).
- **W5 (F4):** animación keyframes UI + Catmull-Clark + remesh básico.
- **W6 (F5):** Hybrid mode (el diferenciador único) + export 5 formatos con validación watertight.
- **WR (FR, paralela, baja prioridad):** vendorizar Satin desde `vendor/Satin` solo si un bug del framework lo exige antes de v1.

---

## ETAPA C — Mejoras NUEVAS para superioridad real a jun-2026 (gap vs competencia)

Lo que el plan maestro NO tiene y la barra de 2026 exige. Se insertan como fases F5.5 y F6 ampliada:

| # | Mejora | Por qué es la barra 2026 | Dónde |
|---|--------|--------------------------|-------|
| C1 | **Máscaras de escultura + face groups** | Nomad las tiene; sin ellas no hay escultura seria | SculptEngine + UI |
| C2 | **DynTopo real** (densidad adaptativa bajo el pincel), no solo remesh global | Diferencia escultura de juguete vs pro | F4 ampliada |
| C3 | **Apple Pencil Pro completo**: hover preview del pincel, squeeze→menú radial, barrel-roll→rotación de pincel, haptics | Ningún competidor usa los 4; hardware 2024+ ya estándar | MetalView + UI |
| C4 | **120Hz ProMotion + presupuesto de rendimiento**: HUD de fps/draw-calls en debug; budget = 1M tris interactivos a 60fps, UI a 120 | Shapr3D presume fluidez; los fixes BUG2/BUG9 ya pavimentaron esto | SatinRenderer |
| C5 | **Export 3MF con metadata de impresión** + chequeo watertight/manifold automático pre-export | Conecta directo con Tangerine; Nomad no lo hace | ExportService |
| C6 | **Autosave + documentos iCloud/Files + recuperación de crash** | "Seria" = no pierde trabajo jamás; CrashReporter ya existe | Core/Services |
| C7 | **Booleanos CAD en vivo (preview no destructivo)** | Shapr3D los tiene instantáneos; CSG/BSP ya implementado, falta preview | CSG + CADMode |
| C8 | **Localización es/en + onboarding interactivo de 2 min** | Mercado LATAM desatendido por todos los competidores (en inglés) | lproj + UI |
| C9 | **Golden-image tests de render en CI** (screenshot simulador vs referencia, tolerancia perceptual) | Único modo de detectar regresiones visuales sin Mac | CI |

(IA generativa text-to-3D queda explícitamente para v1.1 — v1 compite en solidez, no en gimmicks.)

## ETAPA D — Calidad "absolutamente seria" (gates de v1)

- **D1. Beta en hardware real:** IPA unsigned como artifact de CI (ya existe) → guía SideStore/AltStore (doc `GUIA-SIDELOADING.md` ya existe — actualizarla) → Andrés prueba cada milestone en SU iPad. Feedback como issues.
- **D2. Criterios de v1.0 (todos medibles, todos en CI o en checklist de device):**
  - Escultura: 1M+ tris interactivos, ≥15 pinceles, simetría, máscaras, dyntopo.
  - CAD: sketch+extrude/revolve/fillet, booleanos live, historia editable, constraints.
  - Pintura PBR por capas; Animación keyframes + playback + export.
  - Export STL/OBJ/USDZ/GLTF/STEP/3MF, watertight validado, round-trip sin pérdida.
  - UX: 120Hz UI, Pencil Pro, autosave, undo 50+, es/en, onboarding, 0 crashes en sesión de 1h.
  - ≥120 tests verdes + golden-images en CI.
- **D3. Release:** tag v1.0.0 + GitHub Release con IPA + README/landing + licencia (MIT o GPL — decidir antes del tag) + publicación open-source. App Store solo cuando exista cuenta de developer (no bloquea v1).

---

## Verificación (cada ola, sin excepción)
1. Nexus pega evidencia literal (antes/después + greps) en su RESUMEN.
2. Yo: `git diff --stat` = solo archivos autorizados.
3. PR → `gh run watch` → CI verde (build + tests + screenshots).
4. Milestone de etapa → prueba física en iPad de Andrés vía sideload.
5. BRAIN.md actualizado con riesgos residuales tras cada ola.

## Orden de ejecución inmediato
1. A1 merge PR #1 → 2. A2 limpieza (1 agente Nexus flash con spec quirúrgico) → 3. W2/F1 tests (2 Nexus pro paralelos) → continuar secuencia B con C intercalado donde toca.

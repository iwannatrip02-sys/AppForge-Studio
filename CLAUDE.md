# AppForge Studio

App iOS nativa (Swift/SwiftUI/Metal + kernel OCCT) de CAD + escultura 3D para
iPad. Objetivo actual: **reemplazar a Shapr3D por completo**. Lee `CONTEXT.md`
(lenguaje común + deuda conocida) antes de codear.

Verificación: sin Mac local; el typecheck y los 41 tests corren en CI
(`.github/workflows/build.yml`, ~15 min) → artifact `AppForgeStudio-unsigned-ipa`.
**Nada se declara hecho sin verificar en device** (AltStore, botón `+`).

## Agent skills

### Issue tracker

GitHub Issues (`iwannatrip02-sys/AppForge-Studio`) vía `gh`. Ver `docs/agents/issue-tracker.md`.

### Domain docs

Contexto único: `CONTEXT.md` + `docs/adr/`. Ver `docs/agents/domain.md`.

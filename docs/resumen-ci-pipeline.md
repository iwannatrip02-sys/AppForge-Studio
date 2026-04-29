# Pipeline CI/CD AppForge Studio desde Windows a iPad

## Pipeline creado
- Archivo: `.github/workflows/build-ios.yml` (937 bytes)
- Runner: `macos-14` (gratuito, 2000 min/mes)
- Acción: check out repo → Setup Xcode 15.4 → `xcodebuild` con `CODE_SIGNING_ALLOWED=NO` → empaqueta .ipa → upload artifact
- Sin firma: .ipa firmado manualmente con Apple ID gratuito via AltStore

## Documentación creada
1. `docs/compilacion-desde-windows.md` — análisis de opciones, conclusión: solo CI
2. `docs/compilacion-instalacion-ipad.md` — paso a paso: push → CI genera .ipa → descargar → AltStore

## Pendientes inmediatos
1. Push a main del repo para triggerear build
2. Instalar AltStore en iPad (AltServer desde Windows)
3. Cargar .ipa en iPad y probar

## Decisiones registradas
- `DECISIONS.md` actualizado con entrada del 2026-04-29 sobre pipeline Windows→iPad
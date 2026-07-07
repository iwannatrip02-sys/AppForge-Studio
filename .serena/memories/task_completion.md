# Definición de "done"

Sin Mac local, un cambio NO está terminado hasta que:
1. Análisis estático propio pasa (Serena diagnostics si el LSP Swift está disponible; si no, revisión simbólica de firmas/referencias).
2. Commit + push a una rama y **GitHub Actions verde** (`gh run list`); build simulador + tests XCTest.
3. Si el run falla: `gh run view <id> --log-failed`, extraer líneas `error:` y corregir — no marcar tareas como hechas con CI en rojo.
4. Actualizar TODO.md/BRAIN.md de la raíz cuando se cierre un bug documentado ahí.

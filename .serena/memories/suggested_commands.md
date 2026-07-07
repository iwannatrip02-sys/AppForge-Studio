# Comandos (Windows, sin toolchain Swift local)

- Sí hay chequeo de SINTAXIS local (no typecheck, sin SDK iOS) desde 2026-07-06 — toolchain Swift 6.3.2 Windows:
  `$env:PATH = "C:\Users\USUARIO\AppData\Local\Programs\Swift\Toolchains\6.3.2+Asserts\usr\bin;C:\Users\USUARIO\AppData\Local\Programs\Swift\Runtimes\6.3.2\usr\bin;" + $env:PATH; swiftc -parse <archivo.swift>`
  (sin el runtime en PATH, swiftc muere con 0xC0000135). sourcekit-lsp.exe vive en el mismo bin del toolchain — Serena lo usa como LSP tras reiniciar sesión.
- El typecheck/build/test real sigue siendo: editar → swiftc -parse → commit → push → GitHub Actions.
- Estado CI: `gh run list --limit 5`
- Errores de un run fallido: `gh run view <RUN_ID> --log-failed` y filtrar con `Select-String -Pattern "error:"` (los errores Swift vienen como `file.swift:line:col: error: ...`).
- Artefactos (build.log, IPA): `gh run download <RUN_ID>`
- Repo remoto: `iwannatrip02-sys/AppForge-Studio` (origin).
- Shell por defecto PowerShell 5.1: sin `&&`, usar `;` o `if ($?)`.

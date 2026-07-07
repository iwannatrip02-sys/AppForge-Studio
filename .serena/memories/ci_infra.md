# CI / Infra del simulador — invariantes ganados con sangre (2026-07-07)

Primer verde: run 28858291026 (build + 165 tests + IPA). NO tocar esto sin razón:

- **Firma simulador**: `CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=- OTHER_CODE_SIGN_FLAGS=--deep` en build y test. Sin firma ad-hoc, el simulador iOS 18 rechaza instalar con el error engañoso "Missing bundle ID" (IXErrorDomain 13). `--deep` es necesario porque `default.metallib` en la raíz del .app queda sin firmar si no.
- **Archive device**: ahí SÍ van `CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO` (no hay identidad real).
- **project.yml Resources**: NUNCA `type: folder` — mete un directorio `Resources/` literal dentro del .app y iOS lo clasifica como bundle deep (macOS), busca Contents/Info.plist y la instalación falla con "Missing bundle ID". Recursos como paths individuales; `Localizable.strings` legacy excluido (choca con el .xcstrings).
- **Test bundle**: Info.plist PROPIO (`AppForgeStudioTests-Info.plist`, CFBundlePackageType BNDL) y `PRODUCT_BUNDLE_IDENTIFIER=com.appforgestudio.app.tests` — compartir plist/bundle-id con la app rompe la instalación del test runner.
- **Sources/LegacyCSG NO está en el target** — el CSG real es OCCTSwift; no escribir tests/código contra el Shape BSP legacy.
- **USDZ export**: ModelIO no escribe .usdz en iOS ("Unknown extension") — usar SceneKit: `SCNScene(mdlAsset:).write(to:)`.
- **buildMDLAsset**: buffer empaquetado pos/normal/uv con MDLVertexDescriptor explícito — nunca volcar `Vertex` crudo (contiene UUID y padding → exports con 0 geometría).
- Error de test "Failure Reason: Missing bundle ID" = problema de INSTALACIÓN/estructura del bundle, no del plist fuente.

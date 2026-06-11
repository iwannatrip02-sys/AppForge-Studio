# Guia de Sideloading — AppForge Studio sin Apple Developer

> Como instalar AppForge Studio en tu iPad sin cuenta Apple Developer ($99/ano)
> Solo necesitas tu cuenta Apple gratuita (iCloud)

---

## Opcion 1: AltStore (RECOMENDADA — mas estable)

### Paso 1: Instalar AltStore en tu Mac
1. Descarga AltStore desde https://altstore.io
2. Abre el .dmg y mueve AltServer a Aplicaciones
3. Abre AltServer (aparece en la barra de menu)

### Paso 2: Conectar iPad al Mac
1. Conecta tu iPad por USB al Mac
2. Asegurate que iTunes (en Windows) o Finder (en macOS) reconozca el iPad
3. En el iPad: asegurate que "Buscar mi iPad" este desactivado temporalmente
4. En el iPad: Ajustes > General > VPN y Gestion de Dispositivos > Confiar en el certificado de AltStore

### Paso 3: Compilar AppForgeStudio
En tu Mac, abre Terminal en la carpeta del proyecto:
```bash
cd ruta/a/AppForgeStudio
xcodegen generate
open AppForgeStudio.xcodeproj
```

En Xcode:
1. Selecciona tu equipo personal (tu cuenta Apple gratuita) en Signing & Capabilities
2. Cambia el Bundle Identifier a algo unico: `com.tunombre.appforgestudio`
3. Conecta tu iPad por USB
4. Selecciona tu iPad como destino (no simulator)
5. Cmd+B para compilar (Build)

### Paso 4: Instalar con AltStore
1. Abre AltServer en la barra de menu
2. Ve a tu iPad y abre AltStore
3. En AltStore: ve a la pestana My Apps
4. Toca el + en la esquina superior
5. Busca el .ipa en: `~/Library/Developer/Xcode/DerivedData/AppForgeStudio-*/Build/Products/Debug-iphoneos/`
6. O puedes arrastrar el .app compilado a AltStore

### Alternativa: Generar .ipa desde Xcode
1. Product > Archive
2. En la ventana Organizer, selecciona el archive
3. Clic en "Distribute App" > "Development"
4. Selecciona tu equipo personal
5. Exporta como .ipa
6. Arrastra ese .ipa a AltStore

---

## Opcion 2: Xcode directo (mas rapido, sin AltStore)

1. Conecta iPad por USB al Mac
2. Abre el proyecto en Xcode
3. En Signing & Capabilities:
   - Team: selecciona tu cuenta Apple personal
   - Bundle Identifier: algo unico como `com.tunombre.appforgestudio`
4. Selecciona tu iPad como destino (arriba a la izquierda)
5. Cmd+R — Xcode compila e instala directamente en el iPad
6. **Limitacion:** la app expira en 7 dias
7. Para renovar: vuelve a conectar el iPad y Cmd+R de nuevo

### Renovacion automatica (AltStore)
Si usas AltStore, el SideStore/AltStore renueva automaticamente las apps antes de que expiren, siempre que tu Mac/PC y el iPad esten en la misma red WiFi al menos una vez a la semana.

---

## Opcion 3: SideStore (sin Mac, solo PC con iTunes)

1. Descarga SideStore: https://sidestore.io
2. Instala en tu PC (Windows/Mac)
3. Usa AltServer para SideStore
4. Desde el iPad, SideStore permite instalar .ipa directamente
5. Misma limitacion: renovacion cada 7 dias (automatica si el PC esta en la red)

---

## Como compilar AppForgeStudio para sideloading

### Paso 1: Clonar el repo
```bash
git clone https://github.com/iwannatrip02-sys/AppForge-Studio.git
cd AppForge-Studio
```

### Paso 2: Generar proyecto con XcodeGen
```bash
brew install xcodegen
xcodegen generate
```

### Paso 3: Configurar firma personal
Abre `project.yml` y cambia:
```yaml
DEVELOPMENT_TEAM: ""        # → pon tu Team ID (lo ves en developer.apple.com/account)
PRODUCT_BUNDLE_IDENTIFIER: "com.appforgestudio.app"  # → cambia a "com.tunombre.appforgestudio"
```

O simplemente en Xcode: selecciona tu equipo en Signing & Capabilities.

### Paso 4: Build e instalar
```bash
# Para generar .app (firmado con certificado gratuito de 7 dias):
xcodebuild build \
  -project AppForgeStudio.xcodeproj \
  -scheme AppForgeStudio \
  -destination 'generic/platform=iOS' \
  -configuration Debug \
  CODE_SIGN_STYLE=Automatic \
  DEVELOPMENT_TEAM=TU_TEAM_ID
```

### Como obtener tu Team ID
1. Ve a https://developer.apple.com/account (inicia sesion con tu Apple ID)
2. En la esquina superior derecha, tu nombre > Membership
3. El Team ID aparece como "Team ID" (10 caracteres alfanumericos)
4. Si no ves nada: usa `xcodebuild -showBuildSettings | grep DEVELOPMENT_TEAM` desde tu Mac

---

## Resumen de limitaciones (cuenta gratuita)

| Aspecto | Cuenta gratuita | Apple Developer ($99/ano) |
|---------|----------------|--------------------------|
| Apps instaladas | Max 3 simultaneas | Ilimitadas |
| Expira | 7 dias | 1 ano |
| Renovacion | Manual (AltStore lo automatiza) | Automatica |
| Push notifications | No | Si |
| iCloud | Si | Si |
| App Store | No | Si |

**AppForgeStudio cabe perfectamente en las 3 apps del sideloading gratuito.**

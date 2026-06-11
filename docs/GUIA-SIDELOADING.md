# Guía de Sideloading — AppForge Studio

> **Instalá AppForge Studio en tu iPad sin Apple Developer ($99/año).**
> Solo necesitás una cuenta Apple gratuita (iCloud) y esta guía.
> 100% Windows. 0% Mac.

**Última actualización:** 2026-06-11
**Probado en:** Windows 11 + iPad (iOS 18/19)

---

## Índice

1. [Resumen: qué es el sideloading](#resumen)
2. [Opción A: SideStore (recomendada)](#opción-a--sidestore-recomendada)
3. [Opción B: AltStore Classic (PC necesaria)](#opción-b--altstore-classic-pc-necesaria)
4. [Opción C: Sideloadly (alternativa simple)](#opción-c--sideloadly-alternativa-simple)
5. [Límites reales de la cuenta gratuita](#límites-reales)
6. [Cómo obtener el IPA](#cómo-obtener-el-ipa)
7. [Troubleshooting común](#troubleshooting)
8. [Glosario](#glosario)

---

## Resumen

| Método | Requiere PC tras setup | Renovación | Dificultad |
|--------|----------------------|------------|------------|
| **SideStore** | No (solo setup inicial) | Automática (WiFi) | Media |
| **AltStore Classic** | Sí (misma red WiFi) | Automática (WiFi) | Baja |
| **Sideloadly** | Sí (cada 7 días por USB) | Manual | Baja |

**Recomendación:** SideStore. Después de 20 minutos de setup, no tocás la PC nunca más.
La app se re-firma sola en tu iPad mientras dormís.

---

## Opción A — SideStore (recomendada)

### Cómo funciona

SideStore es un fork de AltStore que **no necesita PC después del setup inicial**.
Usa una configuración VPN local (sin servidor externo) para engañar al sistema
y hacer que el iPad piense que está conectado a un Mac con Xcode. La re-firma
ocurre automáticamente en segundo plano.

### Setup inicial (~20 min, se hace UNA vez)

#### Paso A1: Instalar AltServer en tu PC (Windows)

1. Descargá AltServer desde [altstore.io](https://altstore.io) (bajá la versión Windows)
2. Instalalo. Requiere **iTunes** y **iCloud** (las versiones de escritorio, no la Microsoft Store).
   - **iTunes:** [apple.com/itunes/download](https://www.apple.com/itunes/download/) — instalá la versión `.exe`, NO la de Microsoft Store
   - **iCloud:** [apple.com/icloud](https://www.apple.com/icloud/) — mismo, versión `.exe` directa
3. Abrí iTunes, iniciá sesión con tu Apple ID, conectá el iPad por USB una vez para que se reconozca.
4. Abrí AltServer (aparece como ícono de diamante en la bandeja del sistema, junto al reloj).

#### Paso A2: Instalar SideStore en el iPad

1. Conectá el iPad por USB a la PC.
2. En la PC: clic derecho en el ícono de AltServer → `Install SideStore` → seleccioná tu iPad.
3. Ingresá tu Apple ID y contraseña (se usa para generar el certificado de desarrollo gratuito).
   > **Nota:** Podés usar un Apple ID alternativo si desconfiás. No se comparte con terceros.
4. Esperá ~2 minutos. SideStore aparece en la home de tu iPad.
5. **IMPORTANTE:** La primera vez que abras SideStore en el iPad:
   - Ajustes → General → VPN y Gestión de Dispositivos → Confiar en tu Apple ID
   - Esto habilita el certificado de desarrollo.

#### Paso A3: Configurar el refresco automático

1. Abrí SideStore en el iPad.
2. Andá a la pestaña Settings (engranaje).
3. Activá **"Background Refresh"**.
4. SideStore te va a pedir instalar un perfil VPN. Aceptá.
5. Listo. SideStore re-firmará tus apps cada ~6 días automáticamente.

**El perfil VPN NO envía tráfico a ningún lado.** Es puramente local (127.0.0.1). Solo existe
para que el sistema permita el refresco en segundo plano.

### Instalar AppForge Studio con SideStore

1. Descargá `AppForgeStudio-unsigned.ipa` de GitHub Actions:
   - Ve a [github.com/iwannatrip02-sys/AppForge-Studio/actions](https://github.com/iwannatrip02-sys/AppForge-Studio/actions)
   - Abrí el run más reciente con ✅ verde.
   - Bajá el artifact **"AppForgeStudio-unsigned-ipa"**.
   - Descomprimí el `.zip` → obtenés `AppForgeStudio-unsigned.ipa`.
2. Transferí el `.ipa` al iPad (AirDrop, email, Telegram guardado, o iTunes file sharing).
3. En el iPad: abrí el archivo `.ipa` con SideStore (compartir → SideStore).
4. SideStore la firma con tu certificado gratuito y la instala.
5. **Primera apertura:** Ajustes → General → VPN y Gestión de Dispositivos → Confiar.

### Renovación automática

SideStore refresca las apps cada ~6 días (antes de que expiren a los 7). Para que funcione:
- El iPad debe estar en WiFi al menos una vez cada 5-6 días.
- No necesitás la PC en absoluto tras el setup inicial.
- Si dejás el iPad sin WiFi por más de 7 días, la app expira. Al volver a WiFi, SideStore la re-firma automáticamente.

---

## Opción B — AltStore Classic (PC necesaria)

### Cómo funciona

AltServer corre en tu PC con Windows. Cuando tu iPad está en la misma red WiFi,
AltServer re-firma automáticamente las apps. Necesitás que la PC esté encendida
al menos una vez por semana.

### Setup

#### Paso B1: Instalar AltServer en Windows

Igual que Paso A1 de SideStore: iTunes + iCloud + AltServer.

#### Paso B2: Instalar AltStore en el iPad

1. Conectá iPad por USB a la PC.
2. AltServer (bandeja del sistema) → `Install AltStore` → seleccioná tu iPad.
3. Ingresá tu Apple ID.
4. En el iPad: Ajustes → General → VPN y Gestión → Confiar en el certificado.

#### Paso B3: Instalar AppForge con AltStore

1. Conseguí el `.ipa` como en [Cómo obtener el IPA](#cómo-obtener-el-ipa).
2. Transferilo al iPad (AirDrop, email, Telegram, Files).
3. En AltStore (iPad): pestaña My Apps → botón + → seleccioná el `.ipa`.
4. AltStore la firma y la instala.

#### Refresco

- **Automático:** Con la PC encendida y en la misma WiFi, AltServer re-firma antes de que expiren.
- **Manual:** Conectá el iPad por USB, abrí AltServer → refrescá manualmente.

---

## Opción C — Sideloadly (alternativa simple)

Sideloadly es la opción más directa si no te importa conectar el iPad por USB cada 7 días.

### Setup

1. Descargá [Sideloadly](https://sideloadly.io) para Windows.
2. Instalalo (también requiere iTunes/iCloud como AltStore).
3. Conectá el iPad por USB.
4. Arrastrá `AppForgeStudio-unsigned.ipa` a Sideloadly.
5. Ingresá tu Apple ID.
6. Clic en "Start". La app se instala en el iPad.
7. En el iPad: Ajustes → General → VPN y Gestión → Confiar.

**Para re-firmar cada 7 días:** mismo proceso. Conectás, arrastrás el IPA, clic en Start.
Tarda 2 minutos.

---

## Límites reales

Estos son los límites técnicos de una cuenta Apple **gratuita** (sin Apple Developer):

| Aspecto | Límite | Consecuencia |
|---------|--------|--------------|
| **Duración del certificado** | 7 días | La app deja de abrirse al día 8 si no se re-firma |
| **Apps simultáneas** | 3 | AppForge + SideStore/AltStore ya son 2. Queda 1 slot libre |
| **Bundle IDs por cuenta** | ~10 por año | Cada app sideloaded usa un bundle ID. Si reinstalás mucho, podés topar el límite |
| **Capacidades restringidas** | Sin Push, sin App Groups, sin iCloud avanzado | No afecta a AppForge (no usa esas features) |
| **TestFlight** | No disponible | Requiere cuenta paga ($99/año) |

### Qué pasa cuando expira

- La app se queda en tu iPad pero **no abre** (crash instantáneo al tocarla).
- **No perdés datos.** Las apps sideloaded guardan sus datos en el sandbox, que sobrevive a la expiración.
- Re-firmás con SideStore/AltStore/Sideloadly y la app vuelve a funcionar con todos tus datos intactos.
- Si re-firmás ANTES de que expire, el contador de 7 días se reinicia desde ese momento.

---

## Cómo obtener el IPA

El IPA unsigned se genera automáticamente en cada push a `main` o `develop`.

### Desde GitHub Actions

1. Ve a [Actions](https://github.com/iwannatrip02-sys/AppForge-Studio/actions).
2. Hacé clic en el workflow run más reciente con ✅ (el nombre es un commit message).
3. Bajá hasta la sección **Artifacts**.
4. Descargá **`AppForgeStudio-unsigned-ipa`**.
5. Descomprimí el `.zip` → obtenés `AppForgeStudio-unsigned.ipa`.

### Descarga directa (para testers)

Si no tenés cuenta de GitHub, pedile a alguien del equipo el `.ipa` más reciente.
El archivo suele pesar entre 50 y 200 MB dependiendo de las dependencias compiladas.

### Archivo manual (para developers)

Si tenés un Mac con Xcode, podés generar tu propio IPA firmado:

```bash
git clone https://github.com/iwannatrip02-sys/AppForge-Studio.git
cd AppForge-Studio/ios-app/AppForgeStudio
xcodegen generate
xcodebuild archive \
  -project AppForgeStudio.xcodeproj \
  -scheme AppForgeStudio \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -configuration Debug \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  -archivePath AppForgeStudio.xcarchive
# IPA manual:
mkdir -p Payload
cp -R AppForgeStudio.xcarchive/Products/Applications/*.app Payload/
zip -r AppForgeStudio.ipa Payload/
```

---

## Troubleshooting

### "Unable to verify app" al abrir

**Causa:** El certificado no está confiado o expiró.

1. Ajustes → General → VPN y Gestión de Dispositivos.
2. Buscá tu Apple ID. Si aparece, tocá "Confiar".
3. Si no aparece: la app expiró. Re-firmala con SideStore/AltStore/Sideloadly.
4. Si ya confiaste y sigue fallando: eliminá la app, re-firmá, re-instalá.

### SideStore no refresca automáticamente

1. Verificá que "Background Refresh" está activado en SideStore → Settings.
2. Verificá que el perfil VPN está instalado: Ajustes → General → VPN → SideStore WireGuard.
3. Asegurate de que el iPad estuvo en WiFi en los últimos días. SideStore necesita conexión.
4. Forzá un refresco manual: abrí SideStore, deslizá hacia abajo en My Apps.
5. Si nada funciona: reinstalá el perfil VPN desde SideStore → Settings → desactivá y reactivá Background Refresh.

### AltServer no detecta el iPad

1. Asegurate de que iTunes **versión escritorio** (no Microsoft Store) está instalada.
2. Conectá el iPad por USB una vez y verificá que iTunes lo reconoce.
3. En el iPad, respondé "Confiar" cuando pregunte si confiar en esta computadora.
4. Cerrá y reabrí AltServer.
5. Verificá que iCloud también está instalado y con sesión iniciada (versión escritorio).

### "This Apple ID cannot be used for development"

Este error aparece cuando la cuenta nunca se usó para desarrollo. Se resuelve solo al primer sideload exitoso. Si persiste:

1. Andá a [appleid.apple.com](https://appleid.apple.com) y verificá que tu cuenta no tiene bloqueos.
2. Probá aceptar los términos de desarrollador: [developer.apple.com/account](https://developer.apple.com/account) (iniciá sesión con tu Apple ID gratuito, aceptá el acuerdo si aparece).
3. **Alternativa simple:** creá un Apple ID nuevo y fresco. El proceso de sideloading funciona mejor con cuentas nuevas.

### La app crashea al abrir (inmediato)

Posibles causas:

1. **Certificado expirado** — re-firmá la app.
2. **IPA corrupto** — re-descargalo de GitHub Actions (a veces la descarga se corta).
3. **Arquitectura incorrecta** — VERIFICAR: asegurate de que el IPA se compiló para `iphoneos` (arm64), no para simulador (x86_64). El CI actual compila para device físico con `-sdk iphoneos`.
4. **iOS muy viejo** — AppForge requiere iOS 18+. Si tu iPad tiene iOS 17 o anterior, no va a funcionar. VERIFICAR.

### "Maximum number of apps installed"

Eliminá una de las 3 apps sideloaded que tengas. Recordá que SideStore/AltStore cuenta como 1 app. AppForge sería la segunda. Solo podés tener 3 en total con cuenta gratuita.

---

## Glosario

| Término | Significado |
|---------|-------------|
| **Sideloading** | Instalar una app fuera del App Store, usando un certificado de desarrollo gratuito. |
| **IPA** | iOS App Store Package — el archivo que contiene la app compilada. Equivalente al `.apk` de Android. |
| **Firma / Signing** | Proceso criptográfico que autoriza a una app a ejecutarse en iOS. Sin firma, iOS rechaza la app. |
| **Certificado gratuito** | Apple te da un certificado de desarrollo de 7 días al iniciar sesión con tu Apple ID en Xcode (o AltStore/SideStore). Renovable ilimitadamente. |
| **Re-firma / Refresh** | Volver a firmar la app antes de que expiren los 7 días, reseteando el contador. |
| **Unsigned IPA** | IPA sin firma. No se puede instalar directamente: SideStore/AltStore le agrega tu firma personal. |
| **Bundle ID** | Identificador único de la app (ej: `com.appforgestudio.app`). Dos apps no pueden tener el mismo. |
| **VPN y Gestión** | Sección en Ajustes del iPad donde se gestionan certificados de desarrollo y perfiles. |

---

## Referencias

- [SideStore](https://sidestore.io) — fork de AltStore sin dependencia de PC tras setup.
- [AltStore](https://altstore.io) — el original, requiere PC en misma WiFi.
- [Sideloadly](https://sideloadly.io) — instalador directo USB, ideal para Windows.
- [r/sideloading](https://reddit.com/r/sideloading) — comunidad de ayuda.
- [Apple Developer (gratuito)](https://developer.apple.com/account) — gestión de tu cuenta gratuita.

---

> **Nota para el equipo:** El IPA unsigned se genera en CI con el paso `Archive and Package Unsigned IPA (device)`.
> Si ese paso falla, el IPA no se genera pero el CI sigue verde (build + tests son el gate).
> Revisá el log de archive en los artifacts del workflow si el IPA no aparece.

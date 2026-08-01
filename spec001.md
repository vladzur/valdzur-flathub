# Documento de Definiciones - Repositorio Flatpak con Firebase Hosting

## 1. Visión General del Proyecto

### 1.1 Objetivo
Crear un repositorio Flatpak remoto auto-alojado en Firebase Hosting que permita distribución automática de actualizaciones de aplicaciones Flatpak sin pasar por Flathub.

### 1.2 Stack Tecnológico
- **Build System**: GitHub Actions
- **Hosting**: Firebase Hosting
- **Empaquetado**: Flatpak/OSTree
- **Firma**: GPG
- **Control de Versiones**: Git/GitHub

### 1.3 Flujo de Trabajo
```
Desarrollador → Push a GitHub → GitHub Actions → Build & Sign → Firebase Hosting → Usuarios
```

---

## 2. Estructura del Repositorio

```
flatpak-repo/
├── .github/
│   └── workflows/
│       └── build-deploy.yml
├── apps/
│   ├── app1/
│   │   ├── com.ejemplo.app1.yml
│   │   └── assets/
│   │       ├── icon.svg
│   │       └── metainfo.xml
│   └── app2/
│       └── com.ejemplo.app2.yml
├── repo/                          (generado automáticamente)
├── docs/
│   ├── repo-key.gpg              (clave pública para usuarios)
│   └── setup-guide.md
├── scripts/
│   ├── build-app.sh
│   └── update-repo.sh
├── firebase.json
├── .firebaserc
├── .gitignore
└── README.md
```

---

## 3. Configuraciones Requeridas

### 3.1 Variables de Entorno en GitHub Secrets

| Nombre del Secreto | Descripción | Formato |
|-------------------|-------------|---------|
| `GPG_PRIVATE_KEY` | Clave privada GPG para firmar el repositorio | ASCII Armor (-----BEGIN PGP PRIVATE KEY BLOCK-----) |
| `GPG_KEY_ID` | ID de la clave GPG | String (ej: ABC123DEF456) |
| `FIREBASE_SERVICE_ACCOUNT` | Credenciales de servicio de Firebase | JSON completo |
| `FIREBASE_PROJECT_ID` | ID del proyecto Firebase | String |

### 3.2 Configuración de Firebase

**Archivo: `firebase.json`**
```json
{
  "hosting": {
    "public": "repo",
    "ignore": ["firebase.json", "**/.*", "**/node_modules/**"],
    "headers": [
      {
        "source": "**/*.flatpak",
        "headers": [{"key": "Content-Type", "value": "application/vnd.flatpak"}]
      },
      {
        "source": "summary",
        "headers": [
          {"key": "Content-Type", "value": "application/octet-stream"},
          {"key": "Cache-Control", "value": "max-age=0, must-revalidate"}
        ]
      },
      {
        "source": "summary.sig",
        "headers": [
          {"key": "Content-Type", "value": "application/pgp-signature"},
          {"key": "Cache-Control", "value": "max-age=0, must-revalidate"}
        ]
      }
    ]
  }
}
```

**Archivo: `.firebaserc`**
```json
{
  "projects": {
    "default": "tu-proyecto-firebase-id"
  }
}
```

---

## 4. Manifiestos de Aplicaciones

### 4.1 Estructura de Manifiesto Flatpak

**Ubicación**: `apps/{app-name}/{app-id}.yml`

**Ejemplo de manifiesto**:
```yaml
app-id: com.ejemplo.miapp
runtime: org.freedesktop.Platform
runtime-version: '23.08'
sdk: org.freedesktop.Sdk
command: miapp

finish-args:
  - --share=ipc
  - --socket=fallback-x11
  - --socket=wayland
  - --share=network
  - --device=dri

modules:
  - name: miapp
    buildsystem: cmake-ninja
    sources:
      - type: archive
        url: https://github.com/usuario/miapp/releases/download/v1.0.0/miapp-1.0.0.tar.gz
        sha256: abc123...
```

### 4.2 Metadatos de Aplicación (AppStream)

**Ubicación**: `apps/{app-name}/assets/{app-id}.metainfo.xml`

**Estructura requerida**:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<component type="desktop-application">
  <id>com.ejemplo.miapp</id>
  <name>Mi Aplicación</name>
  <summary>Descripción corta</summary>
  <metadata_license>CC0-1.0</metadata_license>
  <project_license>GPL-3.0+</project_license>
  <description>
    <p>Descripción larga de la aplicación</p>
  </description>
  <launchable type="desktop-id">com.ejemplo.miapp.desktop</launchable>
  <url type="homepage">https://ejemplo.com</url>
  <screenshots>
    <screenshot type="default">
      <image>https://ejemplo.com/screenshot.png</image>
    </screenshot>
  </screenshots>
  <content_rating type="oars-1.1"/>
  <releases>
    <release version="1.0.0" date="2024-01-01"/>
  </releases>
</component>
```

---

## 5. Workflow de GitHub Actions

### 5.1 Triggers

| Evento | Condición | Acción |
|--------|-----------|--------|
| `push` | branch: `main` | Build y deploy automático |
| `workflow_dispatch` | manual | Build y deploy manual |
| `pull_request` | branch: `main` | Solo build (sin deploy) |

### 5.2 Pasos del Workflow

#### Job: `build-and-deploy`

**Paso 1: Checkout**
- Acción: `actions/checkout@v4`

**Paso 2: Instalar dependencias**
```bash
sudo apt-get update
sudo apt-get install -y flatpak flatpak-builder
sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
```

**Paso 3: Importar clave GPG**
- Importar clave privada desde secreto
- Extraer Key ID
- Configurar confianza

**Paso 4: Construir aplicaciones**
- Iterar sobre directorios en `apps/`
- Para cada manifiesto:
  - Ejecutar `flatpak-builder --force-clean --repo=repo --gpg-sign=$GPG_KEY_ID build-dir {manifest}`
  - Copiar metadatos al repositorio

**Paso 5: Actualizar repositorio**
```bash
flatpak build-update-repo repo --gpg-sign=$GPG_KEY_ID
```

**Paso 6: Exportar clave pública**
```bash
gpg --export --armor $GPG_KEY_ID > docs/repo-key.gpg
```

**Paso 7: Deploy a Firebase**
- Acción: `FirebaseExtended/action-hosting-deploy@v0`
- Configuración:
  - `projectId`: desde secreto
  - `entryPoint`: `.`
  - `channelId`: `live` (para producción)

---

## 6. Scripts de Utilidad

### 6.1 Script de Build Local

**Archivo**: `scripts/build-app.sh`

**Propósito**: Construir una aplicación específica localmente

**Parámetros**:
- `$1`: Nombre de la aplicación (directorio en `apps/`)
- `$2`: (Opcional) Key ID de GPG

**Comportamiento**:
1. Validar que el directorio existe
2. Encontrar el manifiesto
3. Ejecutar flatpak-builder
4. Reportar éxito/error

### 6.2 Script de Actualización de Repositorio

**Archivo**: `scripts/update-repo.sh`

**Propósito**: Regenerar el summary del repositorio

**Parámetros**:
- `$1`: Key ID de GPG

**Comportamiento**:
1. Verificar que el directorio `repo/` existe
2. Ejecutar `flatpak build-update-repo`
3. Firmar con GPG

---

## 7. Endpoints y URLs

### 7.1 URLs del Repositorio

| Recurso | URL | Método |
|---------|-----|--------|
| Repositorio base | `https://{project-id}.web.app` | GET |
| Summary | `https://{project-id}.web.app/summary` | GET |
| Summary firmado | `https://{project-id}.web.app/summary.sig` | GET |
| Clave pública | `https://{project-id}.web.app/repo-key.gpg` | GET |
| AppStream data | `https://{project-id}.web.app/appstream/{arch}/appstream.xml` | GET |

### 7.2 Comandos de Usuario

**Añadir repositorio**:
```bash
wget https://{project-id}.web.app/repo-key.gpg
flatpak remote-add --user --gpg-import=repo-key.gpg mi-repo https://{project-id}.web.app
```

**Instalar aplicación**:
```bash
flatpak install mi-repo {app-id}
```

**Actualizar aplicaciones**:
```bash
flatpak update
```

---

## 8. Estructura del Repositorio OSTree

### 8.1 Archivos Generados Automáticamente

```
repo/
├── config
├── objects/
│   ├── 00/
│   ├── 01/
│   └── ...
├── refs/
│   ├── heads/
│   │   └── {app-id}/{arch}/{branch}
│   └── mirrors/
├── summary
├── summary.sig
└── appstream/
    └── {arch}/
        ├── appstream.xml
        └── appstream.xml.gz
```

### 8.2 Refs de Aplicaciones

**Formato**: `{app-id}/{arch}/{branch}`

**Ejemplos**:
- `com.ejemplo.app1/x86_64/stable`
- `com.ejemplo.app2/aarch64/beta`

---

## 9. Consideraciones de Seguridad

### 9.1 Protección de Claves

- **Clave privada**: Solo en GitHub Secrets, nunca en el repositorio
- **Clave pública**: Distribuida públicamente en `docs/repo-key.gpg`
- **Firma**: Obligatoria para todos los commits del repositorio

### 9.2 Validaciones

- Verificar integridad de manifiestos antes del build
- Validar que todas las aplicaciones tienen metadatos AppStream
- Comprobar que el repositorio se firma correctamente

---

## 10. Monitoreo y Logs

### 10.1 Logs de GitHub Actions

- Build logs de cada aplicación
- Errores de flatpak-builder
- Estado de firma GPG
- Resultado del deploy a Firebase

### 10.2 Métricas de Firebase Hosting

- Ancho de banda consumido
- Número de solicitudes
- Archivos más descargados

---

## 11. Plan de Implementación

### Fase 1: Configuración Inicial
1. Generar clave GPG
2. Crear estructura de directorios
3. Configurar Firebase project
4. Crear archivos de configuración básicos

### Fase 2: Desarrollo de Scripts
1. Script de build local
2. Script de actualización de repositorio
3. Validaciones de manifiestos

### Fase 3: GitHub Actions
1. Crear workflow base
2. Configurar secretos
3. Probar con una aplicación de prueba
4. Refinar errores

### Fase 4: Documentación
1. README con instrucciones de instalación
2. Guía para desarrolladores (cómo añadir apps)
3. Troubleshooting común

### Fase 5: Pruebas
1. Prueba end-to-end completa
2. Verificar actualizaciones automáticas
3. Probar en múltiples distribuciones Linux

---

## 12. Requisitos Técnicos

### 12.1 Dependencias del Sistema (GitHub Actions Runner)

- Ubuntu 22.04 o superior
- Flatpak 1.12+
- flatpak-builder 1.2+
- GPG 2.2+
- Node.js 18+ (para Firebase CLI)

### 12.2 Límites de Firebase (Plan Gratuito Spark)

- Almacenamiento: 10 GB
- Transferencia: 360 MB/día
- Solicitudes: Ilimitadas

### 12.3 Límites de GitHub Actions

- Minutos: 2,000 minutos/mes (plan gratuito)
- Almacenamiento: 500 MB
- Tiempo máximo por job: 6 horas

---

## 13. Archivos a Generar

### 13.1 Archivos de Configuración

1. `firebase.json`
2. `.firebaserc`
3. `.gitignore`
4. `.github/workflows/build-deploy.yml`

### 13.2 Scripts

1. `scripts/build-app.sh`
2. `scripts/update-repo.sh`
3. `scripts/validate-manifest.sh`

### 13.3 Documentación

1. `README.md`
2. `docs/setup-guide.md`
3. `docs/developer-guide.md`
4. `docs/troubleshooting.md`

### 13.4 Ejemplos

1. `apps/example-app/com.ejemplo.example.yml`
2. `apps/example-app/assets/com.ejemplo.example.metainfo.xml`

---

## 14. Criterios de Aceptación

- [ ] El workflow se ejecuta sin errores en push a `main`
- [ ] Las aplicaciones se construyen correctamente
- [ ] El repositorio se firma con GPG
- [ ] El deploy a Firebase se completa exitosamente
- [ ] La clave pública es accesible vía HTTPS
- [ ] Los usuarios pueden añadir el repositorio
- [ ] Las aplicaciones se instalan correctamente
- [ ] Las actualizaciones se detectan y aplican

---

## 15. Notas Adicionales

- **Cache de Flatpak**: Considerar usar `actions/cache` para runtimes y dependencias
- **Builds paralelos**: Si hay muchas apps, considerar matrix strategy
- **Notificaciones**: Añadir notificaciones de Slack/Email en caso de fallo
- **Rollback**: Mantener versión anterior del repositorio por si hay problemas

---

**Versión del documento**: 1.0  
**Fecha**: 2026-01-XX  
**Estado**: Definición completa, listo para implementación
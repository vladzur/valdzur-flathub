# Guía para Desarrolladores

Cómo añadir una aplicación al repositorio Flatpak.

## Requisitos previos

1. Tu aplicación debe generar un archivo `.flatpak` (bundle) en su propio pipeline de CI/CD.
2. Debes tener un token de GitHub con permisos `repo` sobre este repositorio.
3. Tu aplicación debe tener un AppStream `metainfo.xml` (recomendado para aparecer en tiendas de apps).

## Añadir una nueva aplicación

### 1. Crear el directorio de la app

```bash
mkdir -p apps/com.ejemplo.miapp/assets
```

### 2. Crear el archivo de metadatos AppStream

Crea `apps/com.ejemplo.miapp/assets/com.ejemplo.miapp.metainfo.xml`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<component type="desktop-application">
  <id>com.ejemplo.miapp</id>
  <name>Mi Aplicación</name>
  <summary>Una breve descripción de la app</summary>

  <metadata_license>CC0-1.0</metadata_license>
  <project_license>MIT</project_license>

  <description>
    <p>Descripción más detallada de lo que hace la aplicación.</p>
  </description>

  <launchable type="desktop-id">com.ejemplo.miapp.desktop</launchable>

  <url type="homepage">https://github.com/usuario/miapp</url>

  <screenshots>
    <screenshot type="default">
      <image>https://ejemplo.com/screenshot.png</image>
      <caption>Vista principal de la aplicación</caption>
    </screenshot>
  </screenshots>

  <content_rating type="oars-1.1" />

  <releases>
    <release version="1.0.0" date="2026-07-31">
      <description>
        <p>Primera versión publicada en el repositorio.</p>
      </description>
    </release>
  </releases>
</component>
```

### 3. Añadir un icono (opcional pero recomendado)

Coloca un `icon.svg` o `icon.png` en `apps/com.ejemplo.miapp/assets/`.

## Integrar el pipeline de tu app

### Opción A: Usando `trigger-publish.sh` (recomendado)

Añade este step al workflow de tu aplicación:

```yaml
- name: Publicar en repositorio Flatpak
  env:
    GH_TOKEN: ${{ secrets.VLADZUR_FLATHUB_TOKEN }}
  run: |
    # Clonar el script trigger
    curl -sSLO https://raw.githubusercontent.com/vladzur/vladzur-flathub/main/scripts/trigger-publish.sh
    chmod +x trigger-publish.sh

    # Disparar el deploy
    ./trigger-publish.sh \
      "com.ejemplo.miapp" \
      "${{ github.ref_name }}" \
      "https://github.com/usuario/miapp/releases/download/${{ github.ref_name }}/miapp.flatpak"
```

### Opción B: Directamente con curl

```yaml
- name: Disparar deploy en vladzur-flathub
  run: |
    curl -X POST \
      -H "Authorization: token ${{ secrets.VLADZUR_FLATHUB_TOKEN }}" \
      -H "Accept: application/vnd.github.v3+json" \
      https://api.github.com/repos/vladzur/vladzur-flathub/dispatches \
      -d '{
        "event_type": "publish-flatpak",
        "client_payload": {
          "app_id": "com.ejemplo.miapp",
          "version": "${{ github.ref_name }}",
          "download_url": "https://github.com/usuario/miapp/releases/download/${{ github.ref_name }}/miapp.flatpak"
        }
      }'
```

## Payload del `repository_dispatch`

| Campo | Tipo | Requerido | Descripción |
|-------|------|-----------|-------------|
| `app_id` | string | Sí | ID de la app Flatpak (ej: `com.ejemplo.miapp`) |
| `version` | string | Sí | Versión de la release (ej: `1.0.0`) |
| `download_url` | string | Sí | URL pública de descarga del archivo `.flatpak` |

## Verificar que funcionó

Después del deploy, verifica:

```bash
# Listar apps disponibles en el remoto
flatpak remote-ls vladzur-repo

# Instalar la app
flatpak install vladzur-repo com.ejemplo.miapp

# Ver la versión instalada
flatpak info com.ejemplo.miapp
```

## Solución de problemas

### El workflow falla en "Importar flatpak al repositorio OSTree"

- Verifica que la URL de descarga es accesible públicamente (sin autenticación).
- Verifica que el archivo `.flatpak` es válido: `flatpak build-import-bundle --help` debe funcionar.
- Asegúrate de que el archivo no está corrupto.

### Error de firma GPG

- Verifica que `GPG_PRIVATE_KEY` y `GPG_KEY_ID` están correctamente configurados en GitHub Secrets.
- La clave privada debe estar en formato ASCII armor (`-----BEGIN PGP PRIVATE KEY BLOCK-----`).

### El deploy a Firebase falla

- Verifica que `FIREBASE_SERVICE_ACCOUNT` contiene el JSON completo de credenciales.
- Verifica que `FIREBASE_PROJECT_ID` coincide con el proyecto en `.firebaserc`.

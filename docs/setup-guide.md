# Guía de Setup Inicial

Esta guía describe los pasos únicos necesarios para poner en marcha el repositorio Flatpak.

## 1. Generar clave GPG

La clave GPG se usa para firmar el repositorio OSTree. Los usuarios usarán la clave pública para verificar la autenticidad de las aplicaciones.

```bash
# Generar un nuevo par de claves GPG (sin passphrase para CI/CD)
gpg --batch --passphrase '' --quick-generate-key "Vladzur Flatpak Repo <flatpak@vladzur.dev>" rsa4096 sign never

# Obtener el Key ID
GPG_KEY_ID=$(gpg --list-secret-keys --keyid-format LONG | grep sec | awk '{print $2}' | awk -F'/' '{print $2}')
echo "GPG Key ID: $GPG_KEY_ID"

# Exportar clave pública (para distribuir a usuarios)
gpg --export --armor "$GPG_KEY_ID" > docs/repo-key.gpg

# Exportar clave privada (para GitHub Secrets)
gpg --export-secret-keys --armor "$GPG_KEY_ID" > /tmp/gpg-private.key
```

> **Importante**: Guarda el Key ID y la clave privada en un lugar seguro. La clave privada solo debe existir en GitHub Secrets.

## 2. Configurar GitHub Secrets

Ve a tu repositorio en GitHub → Settings → Secrets and variables → Actions → New repository secret.

Añade los siguientes secretos:

| Nombre | Valor | Notas |
|--------|-------|-------|
| `GPG_PRIVATE_KEY` | Contenido de `/tmp/gpg-private.key` | El bloque completo `-----BEGIN PGP PRIVATE KEY BLOCK-----` ... `-----END PGP PRIVATE KEY BLOCK-----` |
| `GPG_KEY_ID` | El Key ID obtenido en el paso 1 | Ej: `ABC123DEF4567890` |
| `FIREBASE_SERVICE_ACCOUNT` | JSON de credenciales de Firebase | Descargar desde Firebase Console → Project Settings → Service Accounts → Generate new private key |

## 3. Configurar Firebase

### Instalar Firebase CLI (local, solo para setup inicial)

```bash
npm install -g firebase-tools
```

### Iniciar sesión y seleccionar proyecto

```bash
firebase login
firebase use --add
```

Selecciona tu proyecto Firebase existente.

### Editar `.firebaserc`

Reemplaza `TU_PROYECTO_FIREBASE_ID` con el ID real de tu proyecto Firebase:

```json
{
  "projects": {
    "default": "mi-proyecto-firebase-12345"
  }
}
```

## 4. Primer deploy manual

Para verificar que todo funciona antes del primer push:

```bash
# Crear directorio repo vacío con estructura OSTree mínima
mkdir -p repo
ostree init --mode=archive --repo=repo

# Deploy a Firebase
firebase deploy --only hosting
```

## 5. Verificar que el repo funciona

```bash
# El summary debería ser accesible (aunque vacío al principio)
curl -I https://TU_PROYECTO_ID.web.app/summary

# Añadir el remoto en un sistema con Flatpak
wget https://TU_PROYECTO_ID.web.app/repo-key.gpg
flatpak remote-add --user --gpg-import=repo-key.gpg vladzur-repo https://TU_PROYECTO_ID.web.app
```

## Siguientes pasos

- Lee la [guía para desarrolladores](developer-guide.md) para aprender a añadir aplicaciones.
- Configura el `repository_dispatch` en los pipelines de tus apps usando el [template de integración](integration-template.yml).

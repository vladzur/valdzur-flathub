# Vladzur Flatpak Repository

Repositorio Flatpak auto-alojado para mis aplicaciones. Distribuye automáticamente actualizaciones de apps Flatpak sin depender de Flathub.

Las aplicaciones se construyen en sus propios repositorios y este repo las recibe, las importa al repositorio OSTree, firma los metadatos con GPG y los despliega en Firebase Hosting.

## Cómo usar este repositorio (usuarios finales)

### Añadir el repositorio a Flatpak

```bash
# Descargar la clave pública
wget https://TU_PROYECTO_ID.web.app/repo-key.gpg

# Añadir el remoto
flatpak remote-add --user --gpg-import=repo-key.gpg vladzur-repo https://TU_PROYECTO_ID.web.app

# Verificar que funciona
flatpak remote-ls vladzur-repo
```

### Instalar aplicaciones

```bash
flatpak install vladzur-repo com.ejemplo.miapp
```

### Actualizar aplicaciones

```bash
flatpak update
```

## Arquitectura

```
Pipeline de la app (externo)
    │
    │  repository_dispatch(app_id, version, download_url)
    ▼
Este repo (.github/workflows/publish.yml)
    │
    ├── Descarga .flatpak desde download_url
    ├── flatpak build-import-bundle → repo OSTree
    ├── flatpak build-update-repo --gpg-sign → summary firmado
    └── Deploy a Firebase Hosting
            │
            ▼
    Usuarios: flatpak install/update
```

## Stack

- **Hosting**: Firebase Hosting
- **CI/CD**: GitHub Actions
- **Repositorio**: Flatpak/OSTree
- **Firma**: GPG
- **Arquitectura**: x86_64
- **Branch**: stable

## Documentación

- [Guía de setup inicial](docs/setup-guide.md) — Configurar GPG, Firebase y GitHub Secrets
- [Guía para desarrolladores](docs/developer-guide.md) — Cómo añadir una app al repositorio
- [Guía de usuario](docs/user-guide.md) — Instrucciones para instalar apps
- [Template de integración](docs/integration-template.yml) — Para pipelines de apps externas

## Licencia

MIT

# Guía de Usuario

Cómo instalar y usar aplicaciones desde el repositorio Flatpak de Vladzur.

## Requisitos

- Flatpak instalado en tu sistema
- Conexión a Internet

### Instalar Flatpak (si no lo tienes)

**Ubuntu/Debian:**
```bash
sudo apt install flatpak
```

**Fedora:**
```bash
sudo dnf install flatpak
```

**Arch Linux:**
```bash
sudo pacman -S flatpak
```

## Añadir el repositorio

```bash
# 1. Descargar la clave pública para verificar la autenticidad del repo
wget https://TU_PROYECTO_ID.web.app/repo-key.gpg

# 2. Añadir el remoto (solo para tu usuario, no requiere sudo)
flatpak remote-add --user --gpg-import=repo-key.gpg vladzur-repo https://TU_PROYECTO_ID.web.app

# 3. Verificar que funciona
flatpak remote-ls vladzur-repo
```

## Instalar aplicaciones

```bash
# Buscar apps disponibles
flatpak remote-ls vladzur-repo

# Instalar una app específica
flatpak install vladzur-repo com.ejemplo.miapp

# Ejecutar la app
flatpak run com.ejemplo.miapp
```

## Actualizar aplicaciones

```bash
# Actualizar todas las apps del repositorio
flatpak update

# Actualizar una app específica
flatpak update com.ejemplo.miapp
```

## Desinstalar aplicaciones

```bash
flatpak uninstall com.ejemplo.miapp
```

## Eliminar el repositorio

```bash
flatpak remote-delete vladzur-repo
```

## Soporte

Si encuentras algún problema:

1. Abre un issue en [GitHub](https://github.com/vladzur/vladzur-flathub/issues)
2. Describe el problema, incluyendo:
   - Tu distribución y versión
   - Versión de Flatpak (`flatpak --version`)
   - La app que intentaste instalar
   - El mensaje de error completo

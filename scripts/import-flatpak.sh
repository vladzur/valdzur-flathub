#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# import-flatpak.sh — Importa un archivo .flatpak preconstruido al repositorio OSTree.
#
# Uso:
#   ./import-flatpak.sh <ruta-al-archivo.flatpak> <app-id>
#
# El ref OSTree generado siempre será: app/<app-id>/x86_64/stable
# ---------------------------------------------------------------------------

set -euo pipefail

# --- Constantes ------------------------------------------------------------
readonly REPO_DIR="repo"
readonly ARCH="x86_64"
readonly BRANCH="stable"

# --- Funciones de log (español) --------------------------------------------
log_info()  { echo "[INFO]  $*"; }
log_error() { echo "[ERROR] $*" >&2; }
log_ok()    { echo "[OK]    $*"; }

# --- Validación de argumentos ----------------------------------------------
if [[ $# -lt 2 ]]; then
    echo "Uso: $0 <ruta-al-archivo.flatpak> <app-id>" >&2
    echo "Ejemplo: $0 ./mi-app.flatpak com.ejemplo.miapp" >&2
    exit 1
fi

readonly FLATPAK_FILE="$1"
readonly APP_ID="$2"

# --- Validación de entorno -------------------------------------------------
if ! command -v flatpak &>/dev/null; then
    log_error "flatpak no está instalado. Instálalo con: sudo apt-get install -y flatpak"
    exit 1
fi

# --- Validar que el archivo existe y tiene extensión correcta --------------
if [[ ! -f "$FLATPAK_FILE" ]]; then
    log_error "El archivo '$FLATPAK_FILE' no existe."
    exit 1
fi

if [[ "$FLATPAK_FILE" != *.flatpak ]]; then
    log_error "El archivo debe tener extensión .flatpak: '$FLATPAK_FILE'"
    exit 1
fi

# --- Validar que el archivo es un flatpak bundle válido --------------------
log_info "Validando archivo flatpak: $FLATPAK_FILE"
if ! flatpak build-import-bundle --help &>/dev/null; then
    log_error "La versión de flatpak no soporta 'build-import-bundle'. Requiere flatpak >= 1.10"
    exit 1
fi

# --- Crear directorio repo si no existe ------------------------------------
if [[ ! -d "$REPO_DIR" ]]; then
    log_info "Creando repositorio OSTree en '$REPO_DIR'..."
    mkdir -p "$REPO_DIR"
    if ! ostree init --mode=archive --repo="$REPO_DIR" 2>/dev/null; then
        log_info "El repositorio ya estaba inicializado o no se pudo inicializar. Continuando..."
    fi
fi

# --- Importar el flatpak al repositorio OSTree -----------------------------
readonly OSTREE_REF="app/${APP_ID}/${ARCH}/${BRANCH}"

log_info "Importando '$FLATPAK_FILE' al repositorio OSTree..."
log_info "  App ID:   $APP_ID"
log_info "  Ref:      $OSTREE_REF"

if flatpak build-import-bundle "$REPO_DIR" "$FLATPAK_FILE" 2>&1; then
    log_ok "Flatpak importado correctamente en ref '$OSTREE_REF'"
else
    log_error "Fallo al importar el flatpak bundle."
    exit 1
fi

# --- Verificar que el ref se creó correctamente ----------------------------
if ostree --repo="$REPO_DIR" show "$OSTREE_REF" &>/dev/null; then
    log_ok "Ref '$OSTREE_REF' verificado en el repositorio OSTree."
else
    log_error "No se pudo verificar el ref '$OSTREE_REF' después de la importación."
    exit 1
fi

log_ok "Importación completada exitosamente."

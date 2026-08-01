#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# import-flatpak.sh — Importa un archivo .flatpak preconstruido al repositorio OSTree.
#
# Uso:
#   ./import-flatpak.sh <ruta-al-archivo.flatpak> <app-id>
#
# El ref OSTree se determina automáticamente a partir del bundle importado.
# ---------------------------------------------------------------------------

set -euo pipefail

# --- Constantes ------------------------------------------------------------
readonly REPO_DIR="repo"
readonly ARCH="x86_64"

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
# Guardar los refs actuales para detectar cuáles se crean nuevos
readonly REFS_BEFORE=$(ostree refs --repo="$REPO_DIR" 2>/dev/null | sort || true)

log_info "Importando '$FLATPAK_FILE' al repositorio OSTree..."
log_info "  App ID:   $APP_ID"

if flatpak build-import-bundle "$REPO_DIR" "$FLATPAK_FILE" 2>&1; then
    log_ok "Flatpak importado correctamente."
else
    log_error "Fallo al importar el flatpak bundle."
    exit 1
fi

# --- Detectar el ref creado durante la importación -------------------------
# El bundle puede venir con cualquier branch (master, stable, beta, etc.).
# Buscamos el ref que coincide con app/{app_id}/{arch}/*
readonly REFS_AFTER=$(ostree refs --repo="$REPO_DIR" 2>/dev/null | sort)
readonly REF_PREFIX="app/${APP_ID}/${ARCH}/"

# Encontrar refs nuevos que empiecen con el prefijo esperado
IMPORTED_REF=$(comm -13 <(echo "$REFS_BEFORE") <(echo "$REFS_AFTER") | grep "^${REF_PREFIX}" | head -1)

if [[ -z "$IMPORTED_REF" ]]; then
    # Si no se detectó como nuevo, buscar entre todos los refs
    IMPORTED_REF=$(echo "$REFS_AFTER" | grep "^${REF_PREFIX}" | head -1)
fi

if [[ -z "$IMPORTED_REF" ]]; then
    log_error "No se encontró ningún ref con prefijo '$REF_PREFIX' después de la importación."
    log_error "Refs disponibles en el repositorio:"
    ostree refs --repo="$REPO_DIR" 2>/dev/null || true
    exit 1
fi

log_info "Ref detectado: $IMPORTED_REF"

# --- Verificar que el ref detectado es válido ------------------------------
if ostree --repo="$REPO_DIR" show "$IMPORTED_REF" &>/dev/null; then
    log_ok "Ref '$IMPORTED_REF' verificado en el repositorio OSTree."
else
    log_error "No se pudo verificar el ref '$IMPORTED_REF' después de la importación."
    exit 1
fi

log_ok "Importación completada exitosamente."

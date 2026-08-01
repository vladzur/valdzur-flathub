#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# update-repo.sh — Actualiza el summary del repositorio OSTree y lo firma con GPG.
#
# Uso:
#   ./update-repo.sh <gpg-key-id>
#
# Requisitos:
#   - Repositorio OSTree en 'repo/'
#   - flatpak >= 1.10
#   - Clave GPG importada en el keyring
# ---------------------------------------------------------------------------

set -euo pipefail

# --- Constantes ------------------------------------------------------------
readonly REPO_DIR="repo"

# --- Funciones de log (español) --------------------------------------------
log_info()  { echo "[INFO]  $*"; }
log_error() { echo "[ERROR] $*" >&2; }
log_ok()    { echo "[OK]    $*"; }

# --- Validación de argumentos ----------------------------------------------
if [[ $# -lt 1 ]]; then
    echo "Uso: $0 <gpg-key-id>" >&2
    echo "Ejemplo: $0 ABC123DEF4567890" >&2
    exit 1
fi

readonly GPG_KEY_ID="$1"

# --- Validación de entorno -------------------------------------------------
if ! command -v flatpak &>/dev/null; then
    log_error "flatpak no está instalado."
    exit 1
fi

if ! command -v gpg &>/dev/null; then
    log_error "gpg no está instalado."
    exit 1
fi

# --- Validar que el repositorio existe -------------------------------------
if [[ ! -d "$REPO_DIR" ]]; then
    log_error "El directorio del repositorio '$REPO_DIR' no existe."
    echo "Ejecuta primero 'ostree init --mode=archive --repo=$REPO_DIR' o importa una app con import-flatpak.sh"
    exit 1
fi

if [[ ! -f "$REPO_DIR/config" ]]; then
    log_error "'$REPO_DIR' no parece ser un repositorio OSTree válido (falta config)."
    exit 1
fi

# --- Verificar que la clave GPG está disponible ----------------------------
log_info "Verificando disponibilidad de clave GPG: $GPG_KEY_ID"
if ! gpg --list-secret-keys "$GPG_KEY_ID" &>/dev/null; then
    log_error "La clave GPG '$GPG_KEY_ID' no está disponible en el keyring."
    log_error "Importa la clave primero con: gpg --import <archivo-clave-privada>"
    exit 1
fi
log_ok "Clave GPG '$GPG_KEY_ID' disponible."

# --- Actualizar el repositorio (summary + firma) ---------------------------
log_info "Actualizando summary del repositorio OSTree y firmando con GPG..."

# Construir argumentos para flatpak build-update-repo
#   --generate-static-deltas: genera deltas para actualizaciones incrementales
#   --prune: elimina objetos huérfanos
#   --prune-depth=-1: sin límite de profundidad (prune completo)
UPDATE_ARGS=(
    "$REPO_DIR"
    --gpg-sign="$GPG_KEY_ID"
    --generate-static-deltas
    --prune
    --prune-depth=-1
)

if flatpak build-update-repo "${UPDATE_ARGS[@]}" 2>&1; then
    log_ok "Repositorio actualizado y firmado correctamente."
else
    log_error "Fallo al actualizar el repositorio."
    exit 1
fi

# --- Verificar que summary y summary.sig existen ---------------------------
if [[ -f "$REPO_DIR/summary" ]]; then
    log_ok "Archivo 'summary' generado en '$REPO_DIR/'."
else
    log_error "No se generó 'summary'. Algo falló en build-update-repo."
    exit 1
fi

if [[ -f "$REPO_DIR/summary.sig" ]]; then
    log_ok "Archivo 'summary.sig' (firma) generado en '$REPO_DIR/'."
else
    log_error "No se generó 'summary.sig'. La firma GPG puede haber fallado."
    exit 1
fi

# --- Reportar apps en el repositorio ---------------------------------------
log_info "Aplicaciones en el repositorio:"
flatpak remote-ls --repo="$REPO_DIR" --app 2>/dev/null || true

log_ok "Actualización del repositorio completada exitosamente."

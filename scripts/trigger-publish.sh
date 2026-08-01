#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# trigger-publish.sh — Dispara el workflow publish.yml en vladzur-flathub
#                       desde un pipeline externo.
#
# Uso:
#   ./trigger-publish.sh <app-id> <version> <download-url>
#
# Requiere:
#   - Variable de entorno GITHUB_TOKEN con permisos repo sobre vladzur-flathub
#   - curl
#
# Ejemplo:
#   export GITHUB_TOKEN="ghp_xxxxxxxxxxxx"
#   ./trigger-publish.sh com.ejemplo.miapp 1.0.0 https://github.com/user/repo/releases/download/1.0.0/miapp.flatpak
# ---------------------------------------------------------------------------

set -euo pipefail

# --- Constantes ------------------------------------------------------------
readonly REPO_OWNER="vladzur"
readonly REPO_NAME="vladzur-flathub"
readonly EVENT_TYPE="publish-flatpak"

# --- Funciones de log (español) --------------------------------------------
log_info()  { echo "[INFO]  $*"; }
log_error() { echo "[ERROR] $*" >&2; }
log_ok()    { echo "[OK]    $*"; }

# --- Validación de argumentos ----------------------------------------------
if [[ $# -lt 3 ]]; then
    echo "Uso: $0 <app-id> <version> <download-url>" >&2
    echo "Ejemplo: $0 com.ejemplo.miapp 1.0.0 https://github.com/user/repo/releases/download/1.0.0/miapp.flatpak" >&2
    exit 1
fi

readonly APP_ID="$1"
readonly VERSION="$2"
readonly DOWNLOAD_URL="$3"

# --- Validación de token ---------------------------------------------------
if [[ -z "${GITHUB_TOKEN:-}" ]]; then
    log_error "La variable de entorno GITHUB_TOKEN no está definida."
    echo "  Define un token con permisos 'repo' sobre $REPO_OWNER/$REPO_NAME:" >&2
    echo "  export GITHUB_TOKEN=\"ghp_xxxxxxxxxxxx\"" >&2
    exit 1
fi

# --- Validación de curl ----------------------------------------------------
if ! command -v curl &>/dev/null; then
    log_error "curl no está instalado."
    exit 1
fi

# --- Construir y enviar el payload -----------------------------------------
readonly API_URL="https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/dispatches"

log_info "Disparando deploy en ${REPO_OWNER}/${REPO_NAME}..."
log_info "  App ID:       $APP_ID"
log_info "  Versión:      $VERSION"
log_info "  Download URL: $DOWNLOAD_URL"

# Construir payload JSON
PAYLOAD=$(cat <<EOF
{
  "event_type": "${EVENT_TYPE}",
  "client_payload": {
    "app_id": "${APP_ID}",
    "version": "${VERSION}",
    "download_url": "${DOWNLOAD_URL}"
  }
}
EOF
)

# Enviar repository_dispatch
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
    -X POST \
    -H "Authorization: token ${GITHUB_TOKEN}" \
    -H "Accept: application/vnd.github.v3+json" \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD" \
    "$API_URL")

if [[ "$HTTP_CODE" == "204" ]]; then
    log_ok "Workflow disparado exitosamente (HTTP $HTTP_CODE)."
    log_info "Revisa el progreso en: https://github.com/${REPO_OWNER}/${REPO_NAME}/actions"
else
    log_error "Fallo al disparar el workflow (HTTP $HTTP_CODE)."
    log_error "Verifica que el token tiene permisos 'repo' sobre ${REPO_OWNER}/${REPO_NAME}."
    exit 1
fi

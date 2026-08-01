#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# test_update_repo.sh — Tests unitarios para scripts/update-repo.sh
#
# Prueba:
#   - Validación de argumentos (sin gpg-key-id)
#   - Repositorio inexistente
#   - Que el script es ejecutable
#   - Que usa flatpak build-update-repo con --gpg-sign
# ---------------------------------------------------------------------------

set -euo pipefail

readonly SCRIPT="scripts/update-repo.sh"
readonly TEST_DIR="/tmp/test-update-repo-$$"

TESTS_PASSED=0
TESTS_FAILED=0

# --- Helpers ---------------------------------------------------------------
pass() {
    echo "  ✓ $*"
    ((TESTS_PASSED++)) || true
}

fail() {
    echo "  ✗ $*"
    ((TESTS_FAILED++)) || true
}

setup() {
    mkdir -p "$TEST_DIR"
}

cleanup() {
    rm -rf "$TEST_DIR"
}

# --- Tests -----------------------------------------------------------------

test_script_exists_and_is_executable() {
    echo "[Test] El script existe y es ejecutable"

    if [[ -f "$SCRIPT" ]]; then
        pass "El archivo existe"
    else
        fail "El archivo NO existe en $SCRIPT"
    fi

    if [[ -x "$SCRIPT" ]]; then
        pass "El script tiene permisos de ejecución"
    else
        fail "El script NO tiene permisos de ejecución"
    fi
}

test_rejects_no_arguments() {
    echo "[Test] Rechaza ejecución sin gpg-key-id"

    if ! bash "$SCRIPT" 2>/dev/null; then
        pass "Falló correctamente sin argumentos"
    else
        fail "Debería haber fallado sin argumentos"
    fi
}

test_rejects_missing_repo_directory() {
    echo "[Test] Rechaza cuando no existe repo/"

    # Ejecutar desde un directorio sin repo/
    if ! (cd "$TEST_DIR" && bash "$OLDPWD/$SCRIPT" "FAKEKEY123" 2>/dev/null); then
        pass "Falló correctamente cuando repo/ no existe"
    else
        fail "Debería haber fallado cuando repo/ no existe"
    fi
}

test_rejects_non_ostree_repo() {
    echo "[Test] Rechaza directorio que no es repositorio OSTree"

    mkdir -p "$TEST_DIR/repo"
    # No ejecutamos ostree init, así que repo/ está vacío (sin config)

    if ! (cd "$TEST_DIR" && bash "$OLDPWD/$SCRIPT" "FAKEKEY123" 2>/dev/null); then
        pass "Falló correctamente cuando repo/ no tiene config OSTree"
    else
        fail "Debería haber fallado sin config OSTree"
    fi
}

test_uses_gpg_sign_flag() {
    echo "[Test] Usa --gpg-sign en flatpak build-update-repo"

    if grep -q -- '--gpg-sign' "$SCRIPT"; then
        pass "Contiene --gpg-sign flag"
    else
        fail "Falta --gpg-sign flag en build-update-repo"
    fi
}

test_has_required_functions() {
    echo "[Test] El script contiene las funciones requeridas"

    if grep -q "log_info" "$SCRIPT"; then
        pass "Contiene función log_info"
    else
        fail "Falta función log_info"
    fi

    if grep -q "log_error" "$SCRIPT"; then
        pass "Contiene función log_error"
    else
        fail "Falta función log_error"
    fi

    if grep -q "flatpak build-update-repo" "$SCRIPT"; then
        pass "Usa flatpak build-update-repo"
    else
        fail "No usa flatpak build-update-repo"
    fi
}

test_verifies_summary_files() {
    echo "[Test] Verifica que summary y summary.sig se generan"

    if grep -q "summary" "$SCRIPT"; then
        pass "Verifica existencia de summary"
    else
        fail "No verifica summary"
    fi

    if grep -q "summary.sig" "$SCRIPT"; then
        pass "Verifica existencia de summary.sig"
    else
        fail "No verifica summary.sig"
    fi
}

test_uses_generate_static_deltas() {
    echo "[Test] Usa --generate-static-deltas para eficiencia"

    if grep -q -- '--generate-static-deltas' "$SCRIPT"; then
        pass "Usa --generate-static-deltas"
    else
        fail "No usa --generate-static-deltas"
    fi
}

# --- Runner -----------------------------------------------------------------

main() {
    echo "=============================================="
    echo "  Tests: update-repo.sh"
    echo "=============================================="
    echo ""

    setup
    trap cleanup EXIT

    test_script_exists_and_is_executable
    test_rejects_no_arguments
    test_rejects_missing_repo_directory
    test_rejects_non_ostree_repo
    test_uses_gpg_sign_flag
    test_has_required_functions
    test_verifies_summary_files
    test_uses_generate_static_deltas

    echo ""
    echo "=============================================="
    echo "  Resultados: $TESTS_PASSED pasaron, $TESTS_FAILED fallaron"
    echo "=============================================="

    if [[ $TESTS_FAILED -gt 0 ]]; then
        exit 1
    fi
}

main "$@"

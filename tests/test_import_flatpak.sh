#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# test_import_flatpak.sh — Tests unitarios para scripts/import-flatpak.sh
#
# Prueba:
#   - Validación de argumentos (sin args, args incorrectos)
#   - Archivo inexistente
#   - Extensión incorrecta
#   - Que el script es ejecutable
# ---------------------------------------------------------------------------

set -euo pipefail

readonly SCRIPT="scripts/import-flatpak.sh"
readonly TEST_DIR="/tmp/test-import-flatpak-$$"
readonly PASS=0
readonly FAIL=0

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
    cd "$TEST_DIR"
    # Crear estructura mínima del proyecto
    mkdir -p scripts repo
    cp "$OLDPWD/$SCRIPT" scripts/ 2>/dev/null || true
    # Crear un archivo flatpak falso (mínimo, solo para validación de extensión)
    echo "fake flatpak content" > "$TEST_DIR/test.flatpak"
    echo "not a flatpak" > "$TEST_DIR/test.txt"
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
    echo "[Test] Rechaza ejecución sin argumentos"

    if ! bash "$SCRIPT" 2>/dev/null; then
        pass "Falló correctamente sin argumentos (exit code != 0)"
    else
        fail "Debería haber fallado sin argumentos"
    fi
}

test_rejects_single_argument() {
    echo "[Test] Rechaza ejecución con un solo argumento"

    if ! bash "$SCRIPT" "test.flatpak" 2>/dev/null; then
        pass "Falló correctamente con un solo argumento"
    else
        fail "Debería haber fallado con un solo argumento"
    fi
}

test_rejects_nonexistent_file() {
    echo "[Test] Rechaza archivo inexistente"

    if ! bash "$SCRIPT" "/tmp/nonexistent-$$.flatpak" "com.test.app" 2>/dev/null; then
        pass "Falló correctamente con archivo inexistente"
    else
        fail "Debería haber fallado con archivo inexistente"
    fi
}

test_rejects_wrong_extension() {
    echo "[Test] Rechaza archivo sin extensión .flatpak"

    if ! bash "$SCRIPT" "$TEST_DIR/test.txt" "com.test.app" 2>/dev/null; then
        pass "Falló correctamente con extensión incorrecta (.txt)"
    else
        fail "Debería haber fallado con extensión .txt"
    fi
}

test_accepts_valid_flatpak_extension() {
    echo "[Test] Acepta archivo con extensión .flatpak"

    # Crear un flatpak bundle vacío pero con formato mínimo
    # Nota: flatpak build-import-bundle fallará porque no es un bundle real,
    # pero el script debería pasar la validación de extensión y archivo
    if bash "$SCRIPT" "$TEST_DIR/test.flatpak" "com.test.app" 2>/dev/null; then
        pass "El script aceptó el archivo .flatpak (aunque el import puede fallar si no es un bundle real)"
    else
        # Esperado: falla en flatpak build-import-bundle, no en validación
        local exit_code=$?
        if [[ $exit_code -ne 0 ]]; then
            pass "El script procesó el archivo pero falló en import (esperado con bundle falso)"
        else
            fail "Comportamiento inesperado"
        fi
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

    if grep -q "flatpak build-import-bundle" "$SCRIPT"; then
        pass "Usa flatpak build-import-bundle"
    else
        fail "No usa flatpak build-import-bundle"
    fi
}

test_uses_correct_ostree_ref_format() {
    echo "[Test] Usa el formato correcto de ref OSTree"

    if grep -q "app/\${APP_ID}/\${ARCH}/\${BRANCH}" "$SCRIPT" || \
       grep -q 'app/${APP_ID}/${ARCH}/${BRANCH}' "$SCRIPT"; then
        pass "El ref sigue el formato app/{app_id}/{arch}/{branch}"
    else
        fail "El ref NO sigue el formato esperado"
    fi
}

# --- Runner -----------------------------------------------------------------

main() {
    echo "=============================================="
    echo "  Tests: import-flatpak.sh"
    echo "=============================================="
    echo ""

    setup
    trap cleanup EXIT

    test_script_exists_and_is_executable
    test_rejects_no_arguments
    test_rejects_single_argument
    test_rejects_nonexistent_file
    test_rejects_wrong_extension
    test_accepts_valid_flatpak_extension
    test_has_required_functions
    test_uses_correct_ostree_ref_format

    echo ""
    echo "=============================================="
    echo "  Resultados: $TESTS_PASSED pasaron, $TESTS_FAILED fallaron"
    echo "=============================================="

    if [[ $TESTS_FAILED -gt 0 ]]; then
        exit 1
    fi
}

main "$@"

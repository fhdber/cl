#!/usr/bin/env bash
# Creates a local, self-signed code-signing certificate in your login keychain (once).
# Signing every build with the same certificate keeps macOS privacy permissions
# (Accessibility, Calendar, Camera, Automation) across rebuilds.
set -euo pipefail

NAME="Clipline Local Signing"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"

if security find-certificate -c "${NAME}" "$KEYCHAIN" >/dev/null 2>&1; then
  echo "✓ Zertifikat „${NAME}“ ist schon da"
  exit 0
fi

echo "→ Lege das lokale Signatur-Zertifikat „${NAME}“ an (einmalig) …"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

cat > "$TMP/cert.cnf" <<CNF
[ req ]
distinguished_name = dn
x509_extensions = ext
prompt = no
[ dn ]
CN = ${NAME}
[ ext ]
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
CNF

# Apple's own openssl (LibreSSL) writes a .p12 the keychain can import.
/usr/bin/openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
  -keyout "$TMP/key.pem" -out "$TMP/cert.pem" -config "$TMP/cert.cnf" 2>/dev/null
/usr/bin/openssl pkcs12 -export -inkey "$TMP/key.pem" -in "$TMP/cert.pem" \
  -out "$TMP/cert.p12" -passout pass:clipline -name "${NAME}"

# -T lets codesign use the key without asking every time.
security import "$TMP/cert.p12" -k "$KEYCHAIN" -P clipline -T /usr/bin/codesign >/dev/null
echo "→ macOS fragt jetzt einmal nach deinem Passwort, um dem Zertifikat fürs Signieren zu vertrauen."
security add-trusted-cert -r trustRoot -p codeSign -k "$KEYCHAIN" "$TMP/cert.pem"

echo "✓ Fertig. Ab jetzt behält Clipline seine Freigaben auch nach dem Neu-Bauen."

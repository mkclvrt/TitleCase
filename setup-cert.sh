#!/bin/bash
# Creates a stable, self-signed code-signing certificate in the login keychain
# named "TitleCase Self-Signed". build.sh signs with it when present.
#
# Why: macOS ties Accessibility (and other TCC) permissions to an app's signing
# identity. An ad-hoc signature changes on every rebuild, so the permission gets
# revoked each time. Signing every build with the SAME certificate keeps the
# designated requirement stable, so the grant persists across rebuilds.
#
# The certificate (and its private key) live only in your keychain — nothing
# secret is written to the repo. Run once per machine. Safe to re-run.
set -euo pipefail

CERT_NAME="TitleCase Self-Signed"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"

if security find-identity -p codesigning "$KEYCHAIN" 2>/dev/null | grep -q "$CERT_NAME"; then
    echo "Identity '$CERT_NAME' already exists — nothing to do."
    exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

cat > "$TMP/cs.cnf" <<'EOF'
[ req ]
distinguished_name = dn
x509_extensions    = v3
prompt             = no
[ dn ]
CN = TitleCase Self-Signed
[ v3 ]
basicConstraints   = critical,CA:false
keyUsage           = critical,digitalSignature
extendedKeyUsage   = critical,codeSigning
EOF

echo "==> Generating self-signed code-signing certificate (valid 10 years)…"
openssl req -x509 -newkey rsa:2048 -keyout "$TMP/key.pem" -out "$TMP/cert.pem" \
    -days 3650 -nodes -config "$TMP/cs.cnf" 2>/dev/null

# Import cert and key separately (avoids OpenSSL 3 / Apple PKCS#12 MAC mismatch).
# -A lets codesign use the key without a keychain access prompt.
echo "==> Importing into login keychain…"
security import "$TMP/cert.pem" -k "$KEYCHAIN" -A >/dev/null
security import "$TMP/key.pem"  -k "$KEYCHAIN" -A -T /usr/bin/codesign >/dev/null

echo "==> Done. Identity installed:"
security find-identity -p codesigning "$KEYCHAIN" | grep "$CERT_NAME"

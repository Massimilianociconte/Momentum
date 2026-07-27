#!/usr/bin/env bash
# Genera il keystore di upload per Google Play (telefono + Wear OS) FUORI dal
# repository e stampa le istruzioni per le env var attese dalle build release
# (apps/rallymate/android/app/build.gradle.kts e wear/wearos/app/build.gradle.kts).
#
# Uso:
#   scripts/generate_upload_keystore.sh [directory-destinazione]
#
# Default destinazione: ~/keystores (mai dentro il repo: .gitignore non basta
# come protezione per una chiave di firma).
set -euo pipefail

DEST_DIR="${1:-$HOME/keystores}"
KEYSTORE_PATH="$DEST_DIR/momentum-upload.jks"
KEY_ALIAS="momentum-upload"

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
case "$DEST_DIR" in
  "$REPO_ROOT"*)
    echo "ERRORE: la destinazione è dentro il repository ($REPO_ROOT)." >&2
    echo "Scegli una directory esterna, es. ~/keystores" >&2
    exit 1
    ;;
esac

if ! command -v keytool >/dev/null 2>&1; then
  echo "ERRORE: keytool non trovato. Installa un JDK oppure esporta JAVA_HOME," >&2
  echo 'es.: export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"' >&2
  exit 1
fi

if [ -e "$KEYSTORE_PATH" ]; then
  echo "ERRORE: $KEYSTORE_PATH esiste già. Non lo sovrascrivo." >&2
  exit 1
fi

mkdir -p "$DEST_DIR"
chmod 700 "$DEST_DIR"

echo "Creo il keystore di upload in: $KEYSTORE_PATH"
echo "Ti verranno chieste: password del keystore e dati anagrafici (CN ecc.)."
echo "Usa una password robusta e salvala SUBITO in un password manager."
echo

# PKCS12: stessa password per store e key (standard moderno; le build la
# leggono da due env var separate che qui coincidono).
keytool -genkeypair \
  -keystore "$KEYSTORE_PATH" \
  -storetype PKCS12 \
  -alias "$KEY_ALIAS" \
  -keyalg RSA -keysize 4096 \
  -validity 10000

chmod 600 "$KEYSTORE_PATH"

cat <<EOF

Keystore creato: $KEYSTORE_PATH (alias: $KEY_ALIAS)

Prossimi passi:
1. Salva keystore + password nel password manager (e un backup offline).
2. Prima di ogni build store esporta (senza scriverle in file nel repo):

   export RALLYMATE_ANDROID_KEYSTORE_PATH="$KEYSTORE_PATH"
   export RALLYMATE_ANDROID_KEYSTORE_PASSWORD='<password>'
   export RALLYMATE_ANDROID_KEY_ALIAS="$KEY_ALIAS"
   export RALLYMATE_ANDROID_KEY_PASSWORD='<password>'

3. Verifica: keytool -list -v -keystore "$KEYSTORE_PATH" | head -20
   (annota SHA-256: servirà per confrontare l'upload key in Play Console)
EOF

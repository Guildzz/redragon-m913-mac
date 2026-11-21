#!/bin/bash
# Compila e instala o "Red Dragon M913.app" em /Applications.
set -e
cd "$(dirname "$0")"
swift build -c release --arch arm64 --arch x86_64
BIN=$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/M913
APP="${DESTINO:-/Applications}/Red Dragon M913.app"
pkill -f "Red Dragon M913.app/Contents/MacOS/M913" || true
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/pt-BR.lproj"
cp "$BIN" "$APP/Contents/MacOS/M913"
cp Recursos/redragon.svg Recursos/AppIcon.icns "$APP/Contents/Resources/"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>Red Dragon M913</string>
  <key>CFBundleDevelopmentRegion</key><string>pt-BR</string>
  <key>CFBundleLocalizations</key><array><string>pt-BR</string></array>
  <key>CFBundleDisplayName</key><string>Red Dragon M913</string>
  <key>CFBundleIdentifier</key><string>local.m913.config</string>
  <key>CFBundleExecutable</key><string>M913</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.2.1</string>
  <key>CFBundleVersion</key><string>5</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSSupportsAutomaticTermination</key><false/>
  <key>NSSupportsSuddenTermination</key><false/>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>NSHumanReadableCopyright</key><string>Protocolo: m913-ctl e Redragon M913 Web Configurator (GPL-3.0)</string>
</dict></plist>
PLIST
# Assinatura local com requisito pelo identificador: a liberação de
# Monitoramento de Entrada continua valendo depois de recompilar.
codesign --force --sign - -r='designated => identifier "local.m913.config"' "$APP"
echo "Pronto: $APP"

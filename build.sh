#!/usr/bin/env bash
set -Eeuo pipefail

RAIZ="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

rm -rf "${RAIZ}/dist"
mkdir -p "${RAIZ}/dist"
rm -rf "${RAIZ}/paquete_gatajos/usr"

mkdir -p "${RAIZ}/paquete_gatajos/usr/bin"
mkdir -p "${RAIZ}/paquete_gatajos/usr/share/applications"
mkdir -p "${RAIZ}/paquete_gatajos/usr/share/icons/hicolor/scalable/apps"
mkdir -p "${RAIZ}/paquete_gatajos/usr/share/icons/hicolor/256x256/apps"
mkdir -p "${RAIZ}/paquete_gatajos/usr/share/metainfo"
mkdir -p "${RAIZ}/paquete_gatajos/usr/share/doc/gatajos"
mkdir -p "${RAIZ}/paquete_gatajos/usr/share/man/man1"
mkdir -p "${RAIZ}/paquete_gatajos/usr/share/lintian/overrides"

install -m 0755 "${RAIZ}/gatajos.sh" "${RAIZ}/paquete_gatajos/usr/bin/gatajos"
ln -s gatajos "${RAIZ}/paquete_gatajos/usr/bin/buscar-atajo"
install -m 0644 "${RAIZ}/assets/gatajos.desktop" "${RAIZ}/paquete_gatajos/usr/share/applications/gatajos.desktop"
install -m 0644 "${RAIZ}/assets/gatajos.svg" "${RAIZ}/paquete_gatajos/usr/share/icons/hicolor/scalable/apps/gatajos.svg"
install -m 0644 "${RAIZ}/assets/gatajos-256.png" "${RAIZ}/paquete_gatajos/usr/share/icons/hicolor/256x256/apps/gatajos.png"
install -m 0644 "${RAIZ}/assets/gatajos.appdata.xml" "${RAIZ}/paquete_gatajos/usr/share/metainfo/com.elabuelazotech.gatajos.metainfo.xml"
install -m 0644 "${RAIZ}/debian/copyright" "${RAIZ}/paquete_gatajos/usr/share/doc/gatajos/copyright"
gzip -n -9 -c "${RAIZ}/debian/changelog" > "${RAIZ}/paquete_gatajos/usr/share/doc/gatajos/changelog.Debian.gz"
gzip -n -9 -c "${RAIZ}/assets/gatajos.1" > "${RAIZ}/paquete_gatajos/usr/share/man/man1/gatajos.1.gz"
install -m 0644 "${RAIZ}/debian/gatajos.lintian-overrides" "${RAIZ}/paquete_gatajos/usr/share/lintian/overrides/gatajos"

for script in preinst postinst prerm postrm; do
  rm -f "${RAIZ}/paquete_gatajos/DEBIAN/${script}"
  origen="${RAIZ}/debian/gatajos.${script}"
  if [[ ! -f "${origen}" ]]; then
    origen="${RAIZ}/debian/${script}"
  fi
  if [[ -f "${origen}" ]]; then
    install -m 0755 "${origen}" "${RAIZ}/paquete_gatajos/DEBIAN/${script}"
  fi
done

find "${RAIZ}/paquete_gatajos/usr" -type d -exec chmod 0755 {} +
find "${RAIZ}/paquete_gatajos/usr" -type f -exec chmod 0644 {} +
chmod 0755 "${RAIZ}/paquete_gatajos/usr/bin/gatajos"

(cd "${RAIZ}" && dpkg-deb --build --root-owner-group paquete_gatajos dist/gatajos_1.0-2_all.deb)

if command -v lintian >/dev/null 2>&1; then
  lintian "${RAIZ}/dist/gatajos_1.0-2_all.deb" || true
fi

echo "Paquete: ${RAIZ}/dist/gatajos_1.0-2_all.deb"
echo "SHA256:"
sha256sum "${RAIZ}/dist/gatajos_1.0-2_all.deb"

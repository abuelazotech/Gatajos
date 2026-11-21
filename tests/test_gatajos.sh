#!/bin/bash
set -uo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
GATAJOS="$SCRIPT_DIR/../gatajos.sh"

TEMP_DIR=$(mktemp -d)
trap 'rm -rf -- "$TEMP_DIR"' EXIT
mkdir -p -- "$TEMP_DIR/bin"

cat > "$TEMP_DIR/bin/gsettings" <<'STUB'
#!/bin/bash
case "$1" in
  list-schemas)
    printf '%s\n' \
      org.cinnamon.desktop.keybindings \
      org.cinnamon.desktop.media-keys \
      org.gnome.desktop.default-applications.terminal
    ;;
  get)
    case "$*" in
      *custom-list*)
        printf "%s\n" "['/org/cinnamon/desktop/keybindings/custom-keybindings/custom0/']"
        ;;
      *custom0*name*)
        printf "'Abrir terminal de prueba'\n"
        ;;
      *custom0*binding*)
        printf "'f9'\n"
        ;;
      *custom0*command*)
        printf "'gnome-terminal -- echo hola'\n"
        ;;
      *)
        printf '\n'
        ;;
    esac
    ;;
  list-recursively)
    case "$2" in
      org.cinnamon.desktop.keybindings)
        printf '%s\n' \
          "org.cinnamon.desktop.keybindings.wm switch-to-workspace-1 ['<Control><Alt>1']" \
          "org.cinnamon.desktop.keybindings.wm switch-to-workspace-2 ['alt+c']" \
          "org.cinnamon.desktop.keybindings.wm switch-to-workspace-3 ['disabled']" \
          "org.cinnamon.desktop.keybindings.wm switch-to-workspace-4 []" \
          "org.cinnamon.desktop.keybindings.wm switch-to-workspace-5 ''"
        ;;
      org.cinnamon.desktop.media-keys)
        printf '%s\n' \
          "org.cinnamon.desktop.media-keys.media-key-play ['<Alt>F9']" \
          "org.cinnamon.desktop.media-keys.media-key-stop ['disabled']"
        ;;
      org.gnome.desktop.default-applications.terminal)
        printf '%s\n' \
          "org.gnome.desktop.default-applications.terminal exec ['gnome-terminal']"
        ;;
      *)
        printf '\n'
        ;;
    esac
    ;;
  *)
    printf '\n'
    ;;
esac
exit 0
STUB
chmod +x -- "$TEMP_DIR/bin/gsettings"
export PATH="$TEMP_DIR/bin:$PATH"

fallos=0

paso() {
  printf 'CORRECTO: %s\n' "$1"
}

fallo() {
  printf 'FALLO: %s\n' "$1" >&2
  fallos=$((fallos + 1))
}

comprobar_codigo() {
  local descripcion="$1" esperado="$2" actual="$3"
  if [[ $actual -eq $esperado ]]; then
    paso "$descripcion"
  else
    fallo "$descripcion (código $actual, esperado $esperado)"
  fi
}

printf 'Pruebas de Gatajos 1.0-4\n'

salida=$("$GATAJOS" --version 2>&1); codigo=$?
comprobar_codigo '--version devuelve 0' 0 "$codigo"
if [[ $salida == *'Gatajos 1.0-4'* ]]; then
  paso '--version muestra la versión'
else
  fallo '--version muestra la versión'
fi

salida=$(grep '^Version:' "$SCRIPT_DIR/../paquete_gatajos/DEBIAN/control")
if [[ $salida == 'Version: 1.0-4' ]]; then
  paso 'DEBIAN/control tiene la versión esperada'
else
  fallo 'DEBIAN/control tiene la versión esperada'
fi

dependencias='Depends: libglib2.0-bin, dconf-gsettings-backend, cinnamon-desktop-data'
salida=$(grep '^Depends:' "$SCRIPT_DIR/../paquete_gatajos/DEBIAN/control")
if [[ $salida == "$dependencias" ]]; then
  paso 'DEBIAN/control usa libglib2.0-bin'
else
  fallo 'DEBIAN/control usa libglib2.0-bin'
fi

salida=$(grep '^Depends:' "$SCRIPT_DIR/../debian/control")
if [[ $salida == "$dependencias" ]]; then
  paso 'debian/control usa libglib2.0-bin'
else
  fallo 'debian/control usa libglib2.0-bin'
fi

salida=$("$GATAJOS" --help 2>&1); codigo=$?
comprobar_codigo '--help devuelve 0' 0 "$codigo"
if [[ $salida == *'--buscar'* && $salida == *'--listar'* ]]; then
  paso '--help muestra las opciones'
else
  fallo '--help muestra las opciones'
fi

salida=$("$GATAJOS" --ayuda 2>&1); codigo=$?
comprobar_codigo '--ayuda devuelve 0' 0 "$codigo"
if [[ $salida == *'Códigos de salida'* ]]; then
  paso '--ayuda documenta los códigos de salida'
else
  fallo '--ayuda documenta los códigos de salida'
fi

salida=$("$GATAJOS" f9 2>&1); codigo=$?
comprobar_codigo 'gatajos f9 devuelve 0' 0 "$codigo"
if [[ $salida == *'Coincidencias para f9'* ]]; then
  paso 'gatajos f9 busca sin --buscar'
else
  fallo 'gatajos f9 busca sin --buscar'
fi

salida=$("$GATAJOS" --buscar f9 2>&1); codigo=$?
comprobar_codigo '--buscar f9 devuelve 0' 0 "$codigo"
if [[ $salida == *'Coincidencias para f9'* ]]; then
  paso '--buscar f9 muestra coincidencias'
else
  fallo '--buscar f9 muestra coincidencias'
fi

salida=$("$GATAJOS" --buscar inexistente 2>&1); codigo=$?
comprobar_codigo '--buscar inexistente devuelve 3' 3 "$codigo"
mensaje='No encontré coincidencias en GSettings. Esto no cubre atajos propios de aplicaciones como OBS; verifícalos también en la aplicación.'
if [[ $salida == *"$mensaje"* ]]; then
  paso '--buscar inexistente muestra el aviso esperado'
else
  fallo '--buscar inexistente muestra el aviso esperado'
fi

salida=$("$GATAJOS" --listar 2>&1); codigo=$?
comprobar_codigo '--listar devuelve 0' 0 "$codigo"
if [[ $salida == *$'\t'* && $salida == *'[oculto]'* ]]; then
  paso '--listar muestra TSV y comandos ocultos'
else
  fallo '--listar muestra TSV y comandos ocultos'
fi

salida=$("$GATAJOS" --listar --mostrar-comandos 2>&1); codigo=$?
comprobar_codigo '--listar --mostrar-comandos devuelve 0' 0 "$codigo"
if [[ $salida == *'gnome-terminal -- echo hola'* ]]; then
  paso '--listar --mostrar-comandos muestra el comando'
else
  fallo '--listar --mostrar-comandos muestra el comando'
fi

salida=$("$GATAJOS" --buscar f9 --mostrar-comandos 2>&1); codigo=$?
comprobar_codigo '--buscar --mostrar-comandos devuelve 0' 0 "$codigo"
if [[ $salida == *'gnome-terminal -- echo hola'* ]]; then
  paso '--buscar --mostrar-comandos muestra el comando'
else
  fallo '--buscar --mostrar-comandos muestra el comando'
fi

salida=$("$GATAJOS" --mostrar-comandos </dev/null 2>&1); codigo=$?
comprobar_codigo '--mostrar-comandos sin modo devuelve 1' 1 "$codigo"
if [[ $salida == *'solo se puede usar'* ]]; then
  paso '--mostrar-comandos sin modo explica el error'
else
  fallo '--mostrar-comandos sin modo explica el error'
fi

salida=$("$GATAJOS" --mostrar-comandos f9 2>&1); codigo=$?
comprobar_codigo '--mostrar-comandos con tecla devuelve 1' 1 "$codigo"
if [[ $salida == *'solo se puede usar'* ]]; then
  paso '--mostrar-comandos con tecla explica el error'
else
  fallo '--mostrar-comandos con tecla explica el error'
fi

salida=$("$GATAJOS" f9 --listar 2>&1); codigo=$?
comprobar_codigo 'f9 --listar devuelve 1' 1 "$codigo"
if [[ $salida == *'no se pueden combinar modos'* ]]; then
  paso 'f9 --listar rechaza la combinación'
else
  fallo 'f9 --listar rechaza la combinación'
fi

salida=$("$GATAJOS" --listar f9 2>&1); codigo=$?
comprobar_codigo '--listar f9 devuelve 1' 1 "$codigo"
if [[ $salida == *'no se pueden combinar modos'* ]]; then
  paso '--listar f9 rechaza la combinación'
else
  fallo '--listar f9 rechaza la combinación'
fi

salida=$("$GATAJOS" --mostrar-comandos --buscar 'echo hola' 2>&1); codigo=$?
comprobar_codigo 'la búsqueda no coincide con comandos' 3 "$codigo"
if [[ $salida == *'No encontré coincidencias'* ]]; then
  paso 'la búsqueda ignora la columna de comandos'
else
  fallo 'la búsqueda ignora la columna de comandos'
fi

salida=$("$GATAJOS" --buscar terminal 2>&1); codigo=$?
comprobar_codigo '--buscar por nombre devuelve 0' 0 "$codigo"
if [[ $salida == *'Abrir terminal de prueba'* ]]; then
  paso '--buscar encuentra coincidencias por nombre'
else
  fallo '--buscar encuentra coincidencias por nombre'
fi

salida=$("$GATAJOS" --buscar 'mal|valor' 2>&1); codigo=$?
comprobar_codigo "--buscar 'mal|valor' devuelve 1" 1 "$codigo"
if [[ $salida == *'Error:'* ]]; then
  paso "--buscar 'mal|valor' muestra error en español"
else
  fallo "--buscar 'mal|valor' muestra error en español"
fi

salida=$("$GATAJOS" --buscar --color 2>&1); codigo=$?
comprobar_codigo '--buscar --color devuelve 1' 1 "$codigo"
if [[ $salida == *'Error:'* ]]; then
  paso '--buscar --color es rechazado'
else
  fallo '--buscar --color es rechazado'
fi

salida=$("$GATAJOS" --color 2>&1); codigo=$?
comprobar_codigo 'opción desconocida devuelve 1' 1 "$codigo"
if [[ $salida == *'opción desconocida'* ]]; then
  paso 'opción desconocida muestra error en español'
else
  fallo 'opción desconocida muestra error en español'
fi

salida=$("$GATAJOS" </dev/null 2>&1); codigo=$?
comprobar_codigo 'modo interactivo sin TTY devuelve 0' 0 "$codigo"
if [[ $salida != *'Presiona Enter'* ]]; then
  paso 'modo interactivo sin TTY no espera Enter'
else
  fallo 'modo interactivo sin TTY no espera Enter'
fi

if (( fallos == 0 )); then
  printf 'Todas las pruebas pasaron.\n'
  exit 0
fi

printf 'Pruebas fallidas: %d\n' "$fallos" >&2
exit 1

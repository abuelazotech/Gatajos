#!/bin/bash
set -uo pipefail

VERSION='1.0-5'
MOSTRAR_COMANDOS=0

validar_tecla() {
  local tecla="$1"
  local patron='^[A-Za-z0-9 +<>()_/-]+$'
  if [[ -z $tecla ]]; then
    printf 'Error: la tecla no puede estar vacía.\n' >&2
    return 1
  fi
  if (( ${#tecla} > 60 )); then
    printf 'Error: la tecla no puede superar los 60 caracteres.\n' >&2
    return 1
  fi
  if [[ $tecla == -* ]]; then
    printf 'Error: la tecla no puede empezar con -.\n' >&2
    return 1
  fi
  if [[ ! $tecla =~ $patron ]]; then
    printf 'Error: la tecla solo admite letras, números, espacios y los caracteres + - < > ( ) _ /.\n' >&2
    return 1
  fi
  return 0
}

verificar_entorno() {
  local esquemas
  if ! command -v gsettings >/dev/null 2>&1; then
    printf 'Error: no se encontró gsettings. Gatajos necesita GSettings y está pensado para Linux Mint Cinnamon.\n' >&2
    return 1
  fi
  esquemas=$(gsettings list-schemas 2>/dev/null) || {
    printf 'Error: no se pudo consultar la lista de esquemas GSettings.\n' >&2
    return 1
  }
  if ! grep -Fxq -- 'org.cinnamon.desktop.keybindings' <<< "$esquemas"; then
    printf 'Error: no se encontró el esquema org.cinnamon.desktop.keybindings. Gatajos está pensado para Linux Mint Cinnamon y no puede garantizar otros escritorios.\n' >&2
    return 1
  fi
  return 0
}

esquemas_relevantes() {
  gsettings list-schemas 2>/dev/null | grep -E -- 'keybindings|media-keys|default-applications'
}

leer_atajos() {
  local esquema linea nombre valor comando ruta lista nombre_custom tecla_custom comando_custom
  while IFS= read -r esquema; do
    [[ -n $esquema ]] || continue
    while IFS= read -r linea; do
      [[ -n $linea ]] || continue
      read -r _ nombre valor <<< "$linea"
      [[ -n ${nombre:-} && -n ${valor:-} ]] || continue
      valor=${valor#\[}
      valor=${valor%\]}
      valor=${valor#\'}
      valor=${valor%\'}
      [[ -n $valor && $valor != disabled ]] || continue
      if (( MOSTRAR_COMANDOS == 1 )); then
        comando='-'
      else
        comando='[oculto]'
      fi
      printf 'sistema\t%s\t%s\t%s\n' "$nombre" "$valor" "$comando"
    done < <(gsettings list-recursively "$esquema" 2>/dev/null | grep -E -- 'keybinding|media-key|default-applications' | grep -vF -- '[]' | grep -vF -- "'disabled'" | grep -vF -- "''")
  done < <(esquemas_relevantes)

  lista=$(gsettings get org.cinnamon.desktop.keybindings custom-list 2>/dev/null)
  lista=${lista#\[}
  lista=${lista%\]}
  lista=${lista//\'/ }
  read -ra rutas <<< "$lista"
  for ruta in "${rutas[@]}"; do
    ruta=${ruta%,}
    [[ -n $ruta ]] || continue
    nombre_custom=$(gsettings get "org.cinnamon.desktop.keybindings.custom-keybinding:$ruta" name 2>/dev/null)
    tecla_custom=$(gsettings get "org.cinnamon.desktop.keybindings.custom-keybinding:$ruta" binding 2>/dev/null)
    comando_custom=$(gsettings get "org.cinnamon.desktop.keybindings.custom-keybinding:$ruta" command 2>/dev/null)
    nombre_custom=${nombre_custom#\'}
    nombre_custom=${nombre_custom%\'}
    tecla_custom=${tecla_custom#\'}
    tecla_custom=${tecla_custom%\'}
    comando_custom=${comando_custom#\'}
    comando_custom=${comando_custom%\'}
    [[ -n $nombre_custom && -n $tecla_custom && $tecla_custom != disabled ]] || continue
    if (( MOSTRAR_COMANDOS == 1 )); then
      comando=$comando_custom
    else
      comando='[oculto]'
    fi
    printf 'personalizado\t%s\t%s\t%s\n' "$nombre_custom" "$tecla_custom" "$comando"
  done
  return 0
}

listar_atajos() {
  verificar_entorno || return 1
  leer_atajos
  return 0
}

buscar_atajo() {
  local tecla="$1"
  local resultados termino="${tecla,,}"
  validar_tecla "$tecla" || return 1
  verificar_entorno || return 1
  resultados=$(leer_atajos | awk -F '\t' -v termino="$termino" 'index(tolower($2), termino) || index(tolower($3), termino)')
  if [[ -n $resultados ]]; then
    printf 'Coincidencias para %s:\n' "$tecla"
    printf '%s\n' "$resultados"
    return 0
  fi
  printf 'No encontré coincidencias en GSettings. Esto no cubre atajos propios de aplicaciones como OBS; verifícalos también en la aplicación.\n'
  return 3
}

mostrar_ayuda() {
  printf 'Gatajos %s\n' "$VERSION"
  printf 'Uso: gatajos [opción] [TECLA]\n'
  printf '  Sin opciones: modo interactivo; solo espera Enter si hay terminal.\n'
  printf '  TECLA: forma abreviada de --buscar TECLA.\n'
  printf '  --listar: muestra los atajos detectados en GSettings en formato TSV.\n'
  printf '  --buscar TECLA: busca coincidencias de una tecla o combinación.\n'
  printf '  --mostrar-comandos: muestra comandos junto a --listar o --buscar; puede revelar información sensible.\n'
  printf '  --help, --ayuda: muestra esta ayuda.\n'
  printf '  --version: muestra la versión.\n'
  printf 'Códigos de salida: 0 correcto, 1 error de uso o entorno, 3 sin coincidencias.\n'
  return 0
}

esperar_enter() {
  if [[ -t 0 ]]; then
    printf 'Presiona Enter para salir...\n'
    read -r
  fi
  return 0
}

modo=''
modo_explicito=''
tecla=''

establecer_modo() {
  local nuevo="$1"
  if [[ -n $modo && $modo != "$nuevo" ]]; then
    printf 'Error: no se pueden combinar modos; usa solo uno de --listar, --buscar o TECLA.\n' >&2
    exit 1
  fi
  modo="$nuevo"
}

while (( $# > 0 )); do
  case "$1" in
    --help|--ayuda)
      mostrar_ayuda
      exit 0
      ;;
    --version)
      printf 'Gatajos %s\n' "$VERSION"
      exit 0
      ;;
    --listar)
      establecer_modo 'listar'
      modo_explicito='listar'
      shift
      ;;
    --buscar)
      establecer_modo 'buscar'
      modo_explicito='buscar'
      shift
      if (( $# == 0 )) || [[ $1 == -* ]]; then
        printf 'Error: --buscar necesita una tecla.\n' >&2
        exit 1
      fi
      if [[ -n $tecla ]]; then
        printf 'Error: la tecla ya fue especificada.\n' >&2
        exit 1
      fi
      tecla="$1"
      shift
      ;;
    --mostrar-comandos)
      MOSTRAR_COMANDOS=1
      shift
      ;;
    -*)
      printf 'Error: opción desconocida: %s\n' "$1" >&2
      exit 1
      ;;
    *)
      if [[ -z $tecla ]]; then
        establecer_modo 'buscar'
        tecla="$1"
        shift
      else
        printf 'Error: argumento inesperado: %s\n' "$1" >&2
        exit 1
      fi
      ;;
  esac
done

if (( MOSTRAR_COMANDOS == 1 )) && [[ $modo_explicito != 'listar' && $modo_explicito != 'buscar' ]]; then
  printf 'Error: --mostrar-comandos solo se puede usar con --listar o --buscar.\n' >&2
  exit 1
fi

if [[ -z $modo ]]; then
  verificar_entorno || exit 1
  printf 'Atajos detectados en GSettings:\n'
  leer_atajos
  esperar_enter
  exit 0
fi

if [[ $modo == 'listar' ]]; then
  listar_atajos
  exit $?
fi

buscar_atajo "$tecla"
exit $?

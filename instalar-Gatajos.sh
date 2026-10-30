#!/bin/bash
# ==============================================================================
# Gatajos - El Abuelazo Tech (Versión Final con Arrastrar y Soltar AppImages)
# ==============================================================================

BIN_DIR="$HOME/.local/bin"
APP_DIR="$HOME/.local/share/applications"

mkdir -p "$BIN_DIR"
mkdir -p "$APP_DIR"

cat << 'EOF' > "$BIN_DIR/gatajos"
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# Gatajos - El Abuelazo Tech

import gi
import os
import glob
import subprocess
gi.require_version('Gtk', '3.0')
from gi.repository import Gtk, Gdk

class GuiaAtajosWindow(Gtk.Window):

    def __init__(self):
        super().__init__(title="Gatajos - Guía de Atajos")
        
        self.set_default_size(410, 700)
        self.set_position(Gtk.WindowPosition.NONE)
        self.move(1450, 30) 
        
        self.set_keep_above(True)
        self.stick()
        self.set_skip_taskbar_hint(False)
        self.set_border_width(12)

        prov = Gtk.CssProvider()
        prov.load_from_data(b"""
            window { background-color: #0f172a; }
            label { color: #f8fafc; font-size: 10pt; }
            #header_label { color: #38bdf8; font-weight: bold; font-size: 13pt; }
            #sub_label { color: #94a3b8; font-size: 9pt; }
            #resultado_label { color: #fdba74; font-size: 10pt; font-weight: bold; }
            button { background-color: #0284c7; color: #ffffff; font-weight: bold; border-radius: 4px; padding: 8px; }
            button:hover { background-color: #0369a1; }
            entry { background-color: #1e293b; color: #f8fafc; border: 1px solid #475569; padding: 6px; border-radius: 4px; }
            expander label { color: #38bdf8; font-weight: bold; }
        """)
        Gtk.StyleContext.add_provider_for_screen(Gdk.Screen.get_default(), prov, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)

        vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        self.add(vbox)

        lbl_title = Gtk.Label(label="🧭 Gatajos - Tu Asistente en Linux Mint")
        lbl_title.set_name("header_label")
        lbl_title.set_halign(Gtk.Align.START)
        vbox.pack_start(lbl_title, False, False, 0)

        # Paso 1: Abrir Ajustes
        btn_abrir = Gtk.Button(label="⚙️ Paso 1: Abrir Ajustes de Teclado")
        btn_abrir.set_tooltip_text("Abre la ventana oficial de configuración de teclado de Linux Mint.")
        btn_abrir.connect("clicked", self.on_abrir_ajustes_clicked)
        vbox.pack_start(btn_abrir, False, False, 0)

        # Guía de Ubicación (Paso 2)
        pasos_ubicacion = (
            "<b>📌 Paso 2:</b>\n"
            "Haz clic en la pestaña <b>Atajos de teclado</b>."
        )
        frame_ubi = Gtk.Frame(label=" 🗺️ Navegación ")
        vbox.pack_start(frame_ubi, False, False, 0)
        box_ubi = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=5)
        box_ubi.set_border_width(8)
        frame_ubi.add(box_ubi)
        lbl_ubi = Gtk.Label()
        lbl_ubi.set_markup(pasos_ubicacion)
        lbl_ubi.set_line_wrap(True)
        lbl_ubi.set_halign(Gtk.Align.START)
        box_ubi.pack_start(lbl_ubi, True, True, 0)

        # Sección de Búsqueda de Comandos (Paso 3)
        frame_busca = Gtk.Frame(label=" 🔍 Paso 3: Buscar el Programa ")
        vbox.pack_start(frame_busca, False, False, 0)
        box_busca = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        box_busca.set_border_width(8)
        frame_busca.add(box_busca)

        lbl_inst_busca = Gtk.Label(label="Escribe la aplicación aquí (ej. obs, gimp):")
        lbl_inst_busca.set_name("sub_label")
        lbl_inst_busca.set_halign(Gtk.Align.START)
        box_busca.pack_start(lbl_inst_busca, False, False, 0)

        self.txt_busca = Gtk.Entry()
        self.txt_busca.set_placeholder_text("Ej. obs, gimp...")
        self.txt_busca.set_tooltip_text("Escribe aquí para obtener el comando exacto.")
        self.txt_busca.connect("changed", self.on_buscar_programa)
        box_busca.pack_start(self.txt_busca, False, False, 0)

        self.lbl_resultado = Gtk.Label(label="Escribe arriba para consultar...")
        self.lbl_resultado.set_name("resultado_label")
        self.lbl_resultado.set_line_wrap(True)
        self.lbl_resultado.set_halign(Gtk.Align.START)
        box_busca.pack_start(self.lbl_resultado, False, False, 0)

        self.btn_copiar = Gtk.Button(label="📋 Copiar Comando al Portapapeles")
        self.btn_copiar.set_tooltip_text("Copia el comando para pegarlo con Ctrl + V.")
        self.btn_copiar.connect("clicked", self.on_copiar_comando)
        self.btn_copiar.set_sensitive(False)
        box_busca.pack_start(self.btn_copiar, False, False, 0)

        self.comando_encontrado = ""

        # --- SECCIÓN DESPLEGABLE PARA APPIMAGES MEJORADA ---
        expander_appimage = Gtk.Expander(label="📁 ¿Tu programa es una AppImage? (Haz clic aquí)")
        expander_appimage.set_tooltip_text("Despliega esta sección para ver el truco de cómo configurar programas en AppImage.")
        vbox.pack_start(expander_appimage, False, False, 0)

        box_ai = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        box_ai.set_border_width(8)
        expander_appimage.add(box_ai)

        texto_ai = (
            "Las <i>AppImages</i> no se instalan, son archivos portables.\n"
            "Para crearles un atajo, el comando debe ser la <b>ruta completa</b> de tu archivo.\n\n"
            "<b>Cómo obtener la ruta fácilmente:</b>\n"
            "• <b>Método rápido:</b> Arrastra el archivo de tu AppImage desde tu carpeta y <b>suéltalo directamente</b> dentro de la casilla 'Comando' en Mint.\n"
            "• <b>Método escrito:</b> Escribe la ruta de tu carpeta seguida del nombre exacto.\n\n"
            "<b>Ejemplo práctico:</b>\n"
            "<tt>/home/angelino/APPimages/kdenlive.AppImage</tt>"
        )
        lbl_ai = Gtk.Label()
        lbl_ai.set_markup(texto_ai)
        lbl_ai.set_line_wrap(True)
        lbl_ai.set_halign(Gtk.Align.START)
        box_ai.pack_start(lbl_ai, True, True, 0)
        # --------------------------------------------------

        # Pasos 4 y 5
        pasos_finales = (
            "<b>💡 Pasos 4 y 5 (Crear y Asignar):</b>\n\n"
            "• <b>Paso 4:</b> En la ventana de Mint, ve a <b>Atajos personalizados</b> ➔ <i>Añadir atajo personalizado</i>. Ponle un nombre y pega el comando con <b>Ctrl + V</b> (o arrastra el archivo AppImage allí).\n\n"
            "• <b>Paso 5:</b> Haz clic en <b>'Sin asignar'</b> (o sobre las teclas actuales) y presiona la combinación de teclas que deseas asignarle."
        )

        frame_pasos = Gtk.Frame(label=" 🏁 Creación y Teclas ")
        vbox.pack_start(frame_pasos, True, True, 0)
        box_interno = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=5)
        box_interno.set_border_width(8)
        frame_pasos.add(box_interno)
        lbl_pasos = Gtk.Label()
        lbl_pasos.set_markup(pasos_finales)
        lbl_pasos.set_line_wrap(True)
        lbl_pasos.set_halign(Gtk.Align.START)
        box_interno.pack_start(lbl_pasos, True, True, 0)

        btn_cerrar = Gtk.Button(label="Cerrar Asistente")
        btn_cerrar.connect("clicked", lambda w: self.destroy())
        vbox.pack_start(btn_cerrar, False, False, 0)

    def on_abrir_ajustes_clicked(self, button):
        try:
            subprocess.Popen(["cinnamon-settings", "keyboard"])
        except Exception:
            pass

    def on_buscar_programa(self, entry):
        query = entry.get_text().strip().lower()
        if len(query) < 2:
            self.lbl_resultado.set_text("Escribe al menos 2 letras...")
            self.btn_copiar.set_sensitive(False)
            self.comando_encontrado = ""
            return

        rutas = [
            "/usr/share/applications/*.desktop",
            os.path.expanduser("~/.local/share/applications/*.desktop"),
            "/var/lib/flatpak/exports/share/applications/*.desktop",
            os.path.expanduser("~/.local/share/flatpak/exports/share/applications/*.desktop")
        ]

        encontrado = False
        for patron in rutas:
            for archivo in glob.glob(patron):
                try:
                    with open(archivo, 'r', encoding='utf-8', errors='ignore') as f:
                        contenido = f.read()
                        nombre = ""
                        exec_cmd = ""
                        for linea in contenido.splitlines():
                            if linea.startswith("Name=") and not nombre:
                                nombre = linea.split("=", 1)[1]
                            elif linea.startswith("Exec=") and not exec_cmd:
                                exec_cmd = linea.split("=", 1)[1].split("%")[0].strip()
                        
                        if query in nombre.lower() or query in exec_cmd.lower() or query in archivo.lower():
                            self.comando_encontrado = exec_cmd
                            self.lbl_resultado.set_markup(f"<b>Encontrado:</b> {nombre}\n<b>Comando:</b> <tt>{exec_cmd}</tt>")
                            self.btn_copiar.set_sensitive(True)
                            encontrado = True
                            break
                except Exception:
                    continue
            if encontrado:
                break

        if not encontrado:
            self.lbl_resultado.set_markup(
                "<b>No encontrado en el sistema.</b>\n"
                "Despliega la sección de <i>AppImages</i> abajo para ver el truco."
            )
            self.btn_copiar.set_sensitive(False)
            self.comando_encontrado = ""

    def on_copiar_comando(self, button):
        if self.comando_encontrado:
            clipboard = Gtk.Clipboard.get(Gdk.SELECTION_CLIPBOARD)
            clipboard.set_text(self.comando_encontrado, -1)
            self.lbl_resultado.set_markup("<b>¡Comando copiado!</b>\nPégalo en Mint con <b>Ctrl + V</b>.")

if __name__ == "__main__":
    app = GuiaAtajosWindow()
    app.connect("destroy", Gtk.main_quit)
    app.show_all()
    Gtk.main()
EOF

chmod +x "$BIN_DIR/gatajos"

cat <<EOF > "$APP_DIR/gatajos.desktop"
[Desktop Entry]
Version=1.0
Type=Application
Name=Gatajos
Comment=Guía interactiva de atajos para Linux Mint
Exec=$BIN_DIR/gatajos
Icon=input-keyboard
Terminal=false
Categories=Utility;System;
EOF

update-desktop-database "$APP_DIR" 2>/devnull

zenity --info --title="El Abuelazo Tech" --text="¡Instalación completada con éxito!\n\nYa puedes buscar 'Gatajos' directamente en tu Menú de Inicio." --width=350
exit 0

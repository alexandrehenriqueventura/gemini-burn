"""
Launcher da Janela Flutuante Nativa usando GTK 4 + WebKitGTK 6.0 no Zorin OS.
Apresenta suporte a:
  - Transparência total (glassmorphism) e cantos arredondados.
  - Instância única: clicar no ícone da barra superior mostra/oculta (toggle) instantaneamente.
  - Ocultamento automático ao clicar fora (comportamento de menu popup da barra).
  - Alça de arraste via Gtk.WindowHandle.
"""

import sys
import os

_app_instance = None
_window_instance = None
_is_pinned = False

def set_pinned(val: bool):
    global _is_pinned
    _is_pinned = val

def is_pinned() -> bool:
    return _is_pinned

def toggle_window():
    global _window_instance
    if _window_instance is None:
        return
    from gi.repository import GLib
    def _do_toggle():
        if _window_instance.is_visible():
            _window_instance.set_visible(False)
        else:
            _window_instance.set_visible(True)
            _window_instance.present()
        return False
    GLib.idle_add(_do_toggle)

def hide_window():
    global _window_instance
    if _window_instance is None:
        return
    from gi.repository import GLib
    def _do_hide():
        _window_instance.set_visible(False)
        return False
    GLib.idle_add(_do_hide)

def show_window():
    global _window_instance
    if _window_instance is None:
        return
    from gi.repository import GLib
    def _do_show():
        _window_instance.set_visible(True)
        _window_instance.present()
        return False
    GLib.idle_add(_do_show)

def run_gtk_widget(port: int = 5678, start_hidden: bool = False):
    global _app_instance, _window_instance

    try:
        import gi
        gi.require_version("Gtk", "4.0")
        gi.require_version("Gdk", "4.0")
        gi.require_version("WebKit", "6.0")
        from gi.repository import Gtk, Gdk, WebKit, GLib, Gio
    except Exception as e:
        print(f"[Aviso] WebKitGTK/GTK4 não disponível: {e}")
        return False

    from . import server
    server.set_window_controller({
        "toggle": toggle_window,
        "hide": hide_window,
        "show": show_window
    })

    app = Gtk.Application(
        application_id="com.andreporto.geminiburn",
        flags=Gio.ApplicationFlags.FLAGS_NONE
    )
    _app_instance = app

    def on_activate(application):
        global _window_instance
        if _window_instance is None:
            win = Gtk.ApplicationWindow(application=application)
            win.set_title("Gemini Burn Widget")
            win.set_default_size(360, 560)
            win.set_decorated(False)
            win.set_resizable(False)

            # Aplicar CSS de fundo transparente para a janela GTK
            css_provider = Gtk.CssProvider()
            css_provider.load_from_data(b"""
                window, window.background {
                    background: transparent;
                }
            """)
            display = Gdk.Display.get_default()
            if display:
                Gtk.StyleContext.add_provider_for_display(
                    display,
                    css_provider,
                    Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
                )

            # Cria a visualização WebKit com suporte a fundo transparente
            web_view = WebKit.WebView()
            transparent_rgba = Gdk.RGBA()
            transparent_rgba.parse("rgba(0,0,0,0)")
            web_view.set_background_color(transparent_rgba)

            # Configurações do WebKit
            settings = web_view.get_settings()
            settings.set_enable_javascript(True)
            settings.set_enable_developer_extras(False)

            # Carrega a URL do servidor local
            web_view.load_uri(f"http://127.0.0.1:{port}/")

            # Coloca a WebView dentro de um WindowHandle para possibilitar arrastar a janela
            handle = Gtk.WindowHandle()
            handle.set_child(web_view)
            win.set_child(handle)

            _window_instance = win
            if not start_hidden:
                win.present()
        else:
            # Já existe uma janela: alterna visibilidade
            if _window_instance.is_visible():
                _window_instance.set_visible(False)
            else:
                _window_instance.set_visible(True)
                _window_instance.present()

    app.connect("activate", on_activate)
    app.run(None)
    return True

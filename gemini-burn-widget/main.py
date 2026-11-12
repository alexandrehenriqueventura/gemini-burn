#!/usr/bin/env python3
"""
Ponto de Entrada Principal para o Gemini Burn Monitor no Zorin OS.
Suporta modos:
  --widget   (Padrão) Janela flutuante nativa GTK 4 / WebKitGTK
  --browser  Janela de aplicação independente via navegador
  --web      Apenas servidor web em background (http://127.0.0.1:5678)
  --cli      Painel ao vivo no terminal estilo htop/btop
  --record   Registrar manualmente uma chamada de API
"""

import sys
import os
import argparse
import webbrowser
import subprocess
import time

from gemini_burn import parser, server, tracker

def open_app_window(port: int):
    """Tenta abrir via GTK 4 / WebKitGTK. Caso falhe, usa modo App do Chrome/Brave."""
    # 1. Tentativa com GTK 4 Nativo
    try:
        from gemini_burn.widget_gtk import run_gtk_widget
        success = run_gtk_widget(port=port)
        if success:
            return
    except Exception as e:
        print(f"[Info] GTK 4 direto indisponível ({e}). Tentando lançador de navegador...")

    # 2. Fallback: Janela App do Chrome ou Brave
    url = f"http://127.0.0.1:{port}/"
    browsers = ["google-chrome", "brave-browser", "chromium-browser", "firefox"]
    for b in browsers:
        if subprocess.run(["which", b], capture_output=True).returncode == 0:
            if "firefox" in b:
                subprocess.Popen([b, "--new-window", url])
            else:
                subprocess.Popen([b, f"--app={url}", "--window-size=360,560", "--window-position=50,50"])
            print(f"[Sucesso] Widget iniciado via {b} em modo janela compacta!")
            return

    # 3. Fallback genérico: abre navegador padrão
    webbrowser.open(url)
    print(f"[Sucesso] Widget aberto no navegador padrão: {url}")

def main():
    argp = argparse.ArgumentParser(description="Gemini Burn • Monitor de Tokens e Requisições do Antigravity")
    argp.add_argument("--widget", action="store_true", help="Iniciar widget flutuante nativo de desktop (padrão)")
    argp.add_argument("--toggle", action="store_true", help="Alternar exibição da janela flutuante (mostrar/ocultar)")
    argp.add_argument("--hide", action="store_true", help="Ocultar a janela flutuante")
    argp.add_argument("--web", action="store_true", help="Iniciar apenas o micro-servidor HTTP local")
    argp.add_argument("--browser", action="store_true", help="Abrir em janela app do navegador")
    argp.add_argument("--cli", action="store_true", help="Exibir dashboard interativo no terminal")
    argp.add_argument("--port", type=int, default=5678, help="Porta do servidor HTTP (padrão: 5678)")

    
    # Argumentos para registrar chamadas de API avulsas
    argp.add_argument("--record", action="store_true", help="Registrar uma chamada avulsa de API no banco local")
    argp.add_argument("--model", type=str, default="gemini-1.5-flash", help="Nome do modelo usado na chamada")
    argp.add_argument("--tokens-in", type=int, default=0, help="Tokens de entrada (prompt)")
    argp.add_argument("--tokens-out", type=int, default=0, help="Tokens de saída (geração)")
    argp.add_argument("--cost", type=float, default=0.0, help="Custo estimado em USD")

    args = argp.parse_args()

    # Caso seja apenas registro avulso
    if args.record:
        tracker.record_call(
            model=args.model,
            tokens_in=args.tokens_in,
            tokens_out=args.tokens_out,
            source="manual_cli",
            cost_usd=args.cost
        )
        print(f"✓ Chamada gravada: {args.model} | {args.tokens_in + args.tokens_out} tokens")
        return

    # Inicia micro-servidor local
    cfg = parser.load_config()
    port = args.port or cfg.get("port", 5678)

    # Alternar visibilidade da janela (se já estiver em execução)
    if args.toggle:
        import urllib.request
        req = urllib.request.Request(
            f"http://127.0.0.1:{port}/api/toggle",
            data=b"{}",
            headers={"Content-Type": "application/json"}
        )
        try:
            with urllib.request.urlopen(req, timeout=1) as resp:
                if resp.status == 200:
                    return
        except Exception:
            # Se não estiver rodando, inicia normalmente
            pass

    # Ocultar janela
    if args.hide:
        import urllib.request
        req = urllib.request.Request(
            f"http://127.0.0.1:{port}/api/hide",
            data=b"{}",
            headers={"Content-Type": "application/json"}
        )
        try:
            urllib.request.urlopen(req, timeout=1)
        except Exception:
            pass
        return


    # Modo Terminal
    if args.cli:
        from gemini_burn.cli import render_cli_dashboard
        render_cli_dashboard()
        return

    # Inicia servidor HTTP em background
    httpd = server.start_server(port=port, daemon=True)
    print(f"🔥 Gemini Burn Server rodando em http://127.0.0.1:{port}/")

    # Modo somente Servidor Web
    if args.web:
        print("Pressione Ctrl+C para encerrar o servidor.")
        try:
            while True:
                time.sleep(1)
        except KeyboardInterrupt:
            print("\nServidor encerrado.")
            return

    # Modo Navegador Forçado
    if args.browser:
        url = f"http://127.0.0.1:{port}/"
        webbrowser.open(url)
        try:
            while True:
                time.sleep(1)
        except KeyboardInterrupt:
            return

    # Modo Widget Desktop (Padrão)
    open_app_window(port)

if __name__ == "__main__":
    main()

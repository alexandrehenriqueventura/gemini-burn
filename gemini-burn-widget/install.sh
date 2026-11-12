#!/usr/bin/env bash
# ==============================================================================
# Script de Instalação e Configuração do Gemini Burn Widget (Linux / GNOME)
# Suporta execução local (./install.sh) ou remota (curl -sSL ... | bash)
# ==============================================================================

set -e

REPO_URL="https://github.com/andreporto/gemini-burn-widget.git"
DEFAULT_INSTALL_DIR="$HOME/.local/share/gemini-burn"

echo "🔥 [Gemini Burn] Iniciando instalação do monitor para Linux / GNOME..."

# 1. Determina o diretório da aplicação (local ou clone remoto)
if [ -n "${BASH_SOURCE[0]}" ] && [ -f "$(dirname "${BASH_SOURCE[0]}")/main.py" ]; then
    APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    echo "✓ Executando a partir do repositório local: $APP_DIR"
else
    echo "📦 Baixando Gemini Burn para $DEFAULT_INSTALL_DIR..."
    mkdir -p "$DEFAULT_INSTALL_DIR"
    if [ -d "$DEFAULT_INSTALL_DIR/.git" ]; then
        cd "$DEFAULT_INSTALL_DIR" && git pull --quiet
    else
        git clone --quiet "$REPO_URL" "$DEFAULT_INSTALL_DIR"
    fi
    APP_DIR="$DEFAULT_INSTALL_DIR"
fi

# 2. Checagem do ambiente Python 3
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 não encontrado! Por favor, instale o Python 3 na sua distribuição."
    exit 1
fi
echo "✓ Python 3 detectado: $(python3 --version)"

# 3. Permissões de execução
chmod +x "$APP_DIR/main.py"

# 4. Criar diretórios de dados e configuração do usuário
mkdir -p "$HOME/.gemini-burn"
mkdir -p "$HOME/.local/share/applications"
mkdir -p "$HOME/.config/systemd/user"
mkdir -p "$HOME/.local/share/gnome-shell/extensions/gemini-burn@andreporto"

# 5. Instalar Extensão nativa do GNOME Shell (Barra Superior)
EXT_DIR="$HOME/.local/share/gnome-shell/extensions/gemini-burn@andreporto"
sed "s|const REPO_DIR = .*|const REPO_DIR = '$APP_DIR';|g" "$APP_DIR/gnome-extension/extension.js" > "$EXT_DIR/extension.js"
cp "$APP_DIR/gnome-extension/metadata.json" "$EXT_DIR/"
cp "$APP_DIR/gnome-extension/stylesheet.css" "$EXT_DIR/"
echo "✓ Extensão GNOME instalada em $EXT_DIR"

# 6. Instalar serviço de background no Systemd (User space - não requer sudo)
SERVICE_FILE="$HOME/.config/systemd/user/gemini-burn.service"
cat <<EOF > "$SERVICE_FILE"
[Unit]
Description=Gemini Burn - Monitor de Requisições e Tokens do Antigravity
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 $APP_DIR/main.py --web
Restart=on-failure
RestartSec=5s
Environment="PYTHONUNBUFFERED=1"

[Install]
WantedBy=default.target
EOF

systemctl --user daemon-reload
systemctl --user enable --now gemini-burn.service 2>/dev/null || true
echo "✓ Serviço em segundo plano configurado e iniciado no systemd"

# 7. Instalar atalho no menu de aplicativos do desktop
DESKTOP_ENTRY="$HOME/.local/share/applications/gemini-burn.desktop"
cat <<EOF > "$DESKTOP_ENTRY"
[Desktop Entry]
Name=Gemini Burn
Comment=Widget de Monitoramento de Tokens e Requisições do Gemini e Antigravity
Exec=/usr/bin/python3 $APP_DIR/main.py --widget
Icon=utilities-system-monitor
Terminal=false
Type=Application
Categories=Development;Utility;System;Monitor;
StartupNotify=true
EOF
chmod +x "$DESKTOP_ENTRY"
echo "✓ Atalho de aplicativo instalado em $DESKTOP_ENTRY"

# 8. Tentar ativar a extensão GNOME caso a sessão suporte
if command -v gnome-extensions &> /dev/null; then
    gnome-extensions enable gemini-burn@andreporto 2>/dev/null || true
fi

echo ""
echo "🎉 Instalação concluída com sucesso!"
echo "=================================================================="
echo "📌 Barra Superior (GNOME Shell):"
echo "   A extensão 'gemini-burn@andreporto' foi ativada."
echo "   (Caso seja a primeira instalação, pode ser necessário reiniciar"
echo "   a sessão para o GNOME carregar a extensão pela primeira vez)."
echo ""
echo "🚀 Formas de Uso:"
echo "   • Menu na Barra Superior: Clique no ícone de fogo na barra."
echo "   • Painel Web Local:       http://127.0.0.1:5678/"
echo "   • Widget Flutuante:       $APP_DIR/main.py --widget"
echo "   • Terminal CLI ao Vivo:   $APP_DIR/main.py --cli"
echo "=================================================================="

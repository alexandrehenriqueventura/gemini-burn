# Guia de Contribuição • Gemini Burn 🚀

Obrigado pelo interesse em contribuir com o **Gemini Burn**! Este projeto é 100% open-source e mantido pela comunidade de desenvolvedores Linux e entusiastas de IA.

---

## 💡 Como você pode contribuir?

Você pode ajudar de diversas maneiras:
- 🐛 **Reportar Bugs:** Encontrou algum comportamento inesperado, erro de cálculo de tokens ou falha de layout? Abra uma [Issue](https://github.com/andremporto/gemini-burn-widget/issues).
- ✨ **Sugerir Funcionalidades:** Tem uma ideia de métrica, atalho ou recurso novo? Compartilhe conosco!
- 🎨 **Melhorias de Design:** Aperfeiçoamento dos estilos CSS (efeitos de blur, temas adicionais, suporte a modo claro/escuro).
- 🐧 **Suporte a Novas Plataformas:** Adaptações para KDE Plasma (Plasmoid), applets do Cinnamon/XFCE ou empacotamento (.deb, Flatpak, Arch AUR).
- 📝 **Documentação e Tradução:** Melhorias no README, tutoriais e traduções.

---

## 🛠️ Ambiente de Desenvolvimento Local

### 1. Clonar o Repositório
```bash
git clone https://github.com/andremporto/gemini-burn-widget.git
cd gemini-burn-widget
```

### 2. Estrutura do Projeto
```text
├── assets/                  # Imagens oficiais, preview e banners
├── gemini_burn/             # Núcleo em Python
│   ├── parser.py            # Varredura de logs do Antigravity IDE
│   ├── server.py            # Micro-servidor HTTP local e daemon
│   ├── tracker.py           # Banco de dados SQLite para chamadas manuais
│   ├── cli.py               # Interface de terminal (TUI)
│   └── templates/index.html # Dashboard web local
├── gnome-extension/         # Extensão nativa GNOME Shell
│   ├── extension.js         # Lógica da interface na barra e dropdown
│   ├── stylesheet.css       # Estilos CSS (Apple Glassmorphism)
│   └── metadata.json        # Metadados e compatibilidade do GNOME
├── install.sh               # Script de instalação universal
└── main.py                  # Ponto de entrada CLI e lançador
```

### 3. Testar a Extensão do GNOME
Para testar alterações na extensão em tempo real:

1. Crie um link simbólico para a pasta de extensões do seu usuário:
   ```bash
   ln -s "$(pwd)/gnome-extension" "$HOME/.local/share/gnome-shell/extensions/gemini-burn@andreporto"
   ```

2. Recarregue a extensão:
   ```bash
   gnome-extensions disable gemini-burn@andreporto
   gnome-extensions enable gemini-burn@andreporto
   ```

3. Acompanhe os logs da extensão em tempo real:
   ```bash
   journalctl -f -o cat /usr/bin/gnome-shell | grep "Gemini Burn"
   ```

> [!NOTE]
> No GNOME Shell sob **Wayland**, alterações em arquivos `.js` exigem encerrar a sessão (Logout) para recarregar o módulo da memória, enquanto alterações no `stylesheet.css` entram em vigor instantaneamente ao desativar e reativar a extensão.

---

## 🔀 Fluxo de Pull Requests

1. **Crie um Fork** do projeto no GitHub.
2. **Crie uma Branch** temática para a sua modificação:
   ```bash
   git checkout -b minha-feature-incrivel
   ```
3. **Faça seus Commits** seguindo o padrão de commits convencionais:
   - `feat: adiciona suporte a limite personalizado de tokens`
   - `fix: corrige alinhamento do gráfico semanal no GNOME 47`
   - `docs: atualiza instruções de instalação no Fedora`
4. **Envie para o seu Fork:**
   ```bash
   git push origin minha-feature-incrivel
   ```
5. **Abra um Pull Request** no repositório principal descrevendo o que foi alterado e como testar.

---

## 📜 Código de Conduta

Seja respeitoso, inclusivo e construtivo. Todos os níveis de experiência são muito bem-vindos!

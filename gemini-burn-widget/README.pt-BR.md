# 🔥 Gemini Burn • Antigravity Desktop Monitor

<p align="center">
  <img src="assets/social_preview.png" alt="Gemini Burn • Antigravity Desktop Monitor" width="100%" style="border-radius: 16px; box-shadow: 0 20px 40px rgba(0,0,0,0.5);" />
</p>

<p align="center">
  <a href="README.md">English</a> · <b>Português (BR)</b> · <a href="README.es.md">Español</a> · <a href="README.zh-CN.md">简体中文</a> · <a href="README.ru.md">Русский</a>
</p>

<p align="center">
  <b>Monitor de consumo de requisições, tokens e taxa de queima do Gemini e Antigravity para Linux.</b><br>
  Construído com a estética refinada dos <b>Apple Widgets</b> (macOS Sonoma / iOS), efeito glassmorphism e integração nativa com o <b>GNOME Shell</b>.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Platform-Linux%20%7C%20GNOME%2045%2B-blue?style=flat-square&logo=linux" alt="Platform" />
  <img src="https://img.shields.io/badge/Python-3.10%2B-brightgreen?style=flat-square&logo=python" alt="Python" />
  <img src="https://img.shields.io/badge/Style-Apple%20HIG%20Dark-black?style=flat-square&logo=apple" alt="Apple Design" />
  <img src="https://img.shields.io/badge/License-MIT-orange?style=flat-square" alt="License" />
</p>

---

## ✨ Destaques e Funcionalidades

- 🍏 **Design Inspirado nos Widgets da Apple:** 
  - Fundo geral translúcido em `#2f2f2f` com efeito *glassmorphism* e *backdrop blur*.
  - Cards internos em preto obsidiana `#151515` com cantos contínuos (*squircles* com `border-radius: 20px`) e micro-bordas de iluminação especular.
  - Tipografia limpa com espaçamento óptico (*optical tracking*).
- 🚦 **Cores Dinâmicas e Rótulos Inteligentes (Apple HIG):**
  - 🟢 **0% a 49% • `Ativo ⚡` (Apple System Green `#30D158`):** Consumo seguro, ritmo estável e interface em verde.
  - 🟡 **50% a 69% • `Moderado ⚡` (Apple System Yellow `#FFD60A`):** Alerta preventivo ao ultrapassar a metade da cota diária.
  - 🔴 **70% em diante • `Fervendo 🔥` (Apple System Red `#FF453A`):** Ritmo intenso de queima e aproximação do limite diário.
  - 🎯 **Harmonia Visual Absoluta:** O rótulo de status, a barra de progresso, a velocidade horária (`req/h`) e a porcentagem mudam em perfeita sincronia visual.
- ⚡ **Rastreamento Automático Local (Zero Configuração):**
  - Analisa diretamente os logs locais do Antigravity (`~/.gemini/antigravity/brain/` e `~/.gemini/antigravity-ide/brain/`).
  - Não requer chaves de API para monitorar seu fluxo do Antigravity.
  - Captura os tokens reais de entrada/saída ou calcula estimativas precisas por contexto.
- 📈 **Métricas de Ritmo & Histórico:**
  - **Semana de Calendário:** Contabilização semanal acumulada iniciando na segunda-feira às 00:00:00.
  - **Burn Rate Horário:** Medição contínua em tempo real de requisições e tokens consumidos por hora.
  - **Histórico dos 7 Dias:** Mini gráfico de barras com pico de requisições e destaque inteligente no dia de hoje.
  - **Contador de Ferramentas:** Registro das *tools* e comandos executados pelos agentes.
- 🎛️ **Multi-Modos de Exibição:**
  1. **Menu na Barra Superior (Extensão GNOME Shell):** Fica discretamente ao lado do relógio/ícones na bandeja e desce o card completo com 1 clique.
  2. **Dashboard Web Local:** Acesse em qualquer navegador via `http://127.0.0.1:5678/`.
  3. **Widget Desktop Flutuante:** Janela independente nativa GTK 4 / WebKitGTK.
  4. **Painel CLI no Terminal:** Interface de console em tempo real estilo `htop`/`btop`.

---

## 🚀 Instalação Rápida (1 Comando)

Você pode instalar o Gemini Burn diretamente pelo terminal com um único comando (não requer `sudo`):

```bash
curl -sSL https://raw.githubusercontent.com/andreporto/gemini-burn-widget/main/install.sh | bash
```

### O que o instalador faz automaticamente:
1. Instala a extensão nativa do GNOME Shell em `~/.local/share/gnome-shell/extensions/gemini-burn@andreporto/`.
2. Cria e ativa o serviço em segundo plano no `systemd --user` (inicia sozinho ao ligar o PC).
3. Cria o atalho no menu de aplicativos do sistema.

> [!IMPORTANT]
> ### ⚠️ Atenção para Usuários de Wayland (Zorin OS, Ubuntu, Fedora)
> No **Wayland** (padrão nas versões modernas do GNOME 45+), o processo do GNOME Shell é o compositor gráfico direto do sistema. Por questões de estabilidade, o GNOME **bloqueia o reinício do shell em tempo de execução** (o antigo atalho `Alt + F2` seguido de `r` do X11 não funciona no Wayland).
>
> **O que você precisa saber:**
> - Ao instalar a extensão pela primeira vez ou atualizar seus arquivos visuais (`extension.js` ou `stylesheet.css`), o GNOME mantém o código JavaScript antigo cacheado na memória RAM durante a sessão ativa.
> - **Como contornar:** Basta **Encerrar a Sessão (Log out)** e entrar novamente no seu usuário (ou reiniciar a máquina). No novo login, o GNOME Shell carregará automaticamente os arquivos atualizados do disco.

---

## 🛠️ Instalação Manual via Git

Caso prefira inspecionar e rodar o repositório clonado localmente:

```bash
# 1. Clonar o repositório
git clone https://github.com/andreporto/gemini-burn-widget.git
cd gemini-burn-widget

# 2. Executar o instalador local
./install.sh
```

---

## 🖥️ Modos de Uso

| Modo | Comando | Descrição |
| :--- | :--- | :--- |
| **Barra Superior** | Clique no ícone `🔥` na barra | Menu popup nativo com métricas ao vivo |
| **Painel Web** | `./main.py --web` | Abre o servidor local em `http://127.0.0.1:5678/` |
| **Widget Flutuante** | `./main.py --widget` | Janela de desktop arrastável |
| **Terminal (CLI)** | `./main.py --cli` | Dashboard interativo no terminal |

---

## ⚙️ Gerenciamento do Serviço (Systemd)

O serviço roda em segundo plano sem privilégios de root:

```bash
# Verificar status do coletor de métricas
systemctl --user status gemini-burn.service

# Reiniciar o serviço
systemctl --user restart gemini-burn.service

# Parar o serviço
systemctl --user stop gemini-burn.service
```

---

## 🔒 Privacidade e Segurança

- **100% Local e Offline:** Nenhum dado, prompt, token ou histórico sai da sua máquina.
- **Leitura Segura:** Apenas faz leitura passiva das estatísticas geradas pelo seu fluxo de trabalho no Antigravity.
- **Banco de Dados Local:** Configurações e métricas avulsas são armazenadas em `~/.gemini-burn/`.

---

## 🤝 Como Contribuir

Contribuições da comunidade são super bem-vindas! Se você deseja reportar um bug, sugerir novas métricas ou enviar melhorias de código:

1. Faça um **Fork** do projeto.
2. Crie uma branch para sua modificação (`git checkout -b feature/minha-melhoria`).
3. Faça o commit das suas alterações (`git commit -m 'feat: adiciona nova funcionalidade'`).
4. Envie para o seu fork (`git push origin feature/minha-melhoria`).
5. Abra um **Pull Request**.

Para instruções detalhadas de como configurar o ambiente de desenvolvimento local, testar a extensão no GNOME Shell e acompanhar logs, consulte nosso [Guia de Contribuição (CONTRIBUTING.md)](CONTRIBUTING.md).

---

## ☕ Apoie o Projeto

Se o **Gemini Burn** te ajuda no seu fluxo de desenvolvimento e você deseja apoiar a continuidade do projeto, considere me pagar um cafézinho! ☕

<p align="left">
  <img src="https://img.shields.io/badge/PIX-Apoiar%20via%20PIX-32BCAD?style=for-the-badge&logo=pix&logoColor=white" alt="Apoie via Pix" />
</p>

> **Chave PIX (Aleatória):**  
> `883e07ea-968b-44eb-ba00-4ee5cef1221d`  
> *(Qualquer quantia é muito bem-vinda e ajuda a manter novos recursos saindo do forno! 🔥)*

---

## 📄 Licença

Distribuído sob a licença [MIT](LICENSE). Desenvolvido para a comunidade open source de desenvolvedores.


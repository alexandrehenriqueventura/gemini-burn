"""
Modo de Monitoramento em Terminal (CLI) com Estética Dark / Cyberpunk Minimalista.
Exibe métricas em tempo real com blocos Unicode e cores ANSI, perfeito para tmux ou abas de terminal.
"""

import time
import sys
import os
from . import parser

# Cores ANSI
C_RESET = "\033[0m"
C_BOLD = "\033[1m"
C_DIM = "\033[2m"
C_ORANGE = "\033[38;5;208m"
C_RED = "\033[38;5;196m"
C_PURPLE = "\033[38;5;141m"
C_CYAN = "\033[38;5;45m"
C_GREEN = "\033[38;5;48m"
C_GRAY = "\033[38;5;242m"
C_BG_CARD = "\033[48;5;234m"

def render_progress_bar(pct: float, width: int = 24) -> str:
    filled = int((pct / 100.0) * width)
    filled = max(0, min(width, filled))
    empty = width - filled
    bar = f"{C_ORANGE}{'█' * filled}{C_GRAY}{'░' * empty}{C_RESET}"
    return bar

def render_cli_dashboard():
    try:
        while True:
            metrics = parser.collect_metrics()
            t = metrics["today"]
            w = metrics["week"]
            p = metrics["pace"]
            s = metrics["session"]
            spark = metrics["sparkline"]

            # Limpa terminal e posiciona cursor no topo
            sys.stdout.write("\033[2J\033[H")

            out = []
            out.append(f"{C_BOLD}{C_ORANGE}  🔥 GEMINI BURN {C_RESET}{C_GRAY}• Antigravity Desktop Monitor{C_RESET}")
            out.append(f"{C_GRAY}  ──────────────────────────────────────────────────{C_RESET}")
            
            # Linha de Status
            out.append(f"  Status: {C_GREEN}● CONECTADO{C_RESET}   Atualizado: {C_CYAN}{metrics['updated_at']}{C_RESET}   Ritmo: {p['label']}")
            out.append("")

            # Card Hoje
            out.append(f"  {C_BOLD}HOJE (DAILY BURN){C_RESET}")
            out.append(f"  Requisições: {C_BOLD}{C_ORANGE}{t['reqs']}{C_RESET} / {t['limit']}   Tokens: {C_PURPLE}~{t['total_tokens_fmt']}{C_RESET} ({t['tokens_in_fmt']} in • {t['tokens_out_fmt']} out)")
            out.append(f"  Progresso:   {render_progress_bar(t['pct'])} {C_BOLD}{t['pct']}%{C_RESET}")
            out.append(f"  Velocidade:  {C_CYAN}{p['reqs_hour']} reqs/h{C_RESET} nos últimos 60 minutos")
            out.append("")

            # Card Semana
            out.append(f"  {C_BOLD}SEMANA ATUAL{C_RESET}")
            out.append(f"  Total Reqs:  {C_BOLD}{w['reqs']}{C_RESET} reqs        Tokens: {C_PURPLE}~{w['total_tokens_fmt']}{C_RESET}")
            out.append("")

            # Mini Gráfico 7 Dias
            out.append(f"  {C_BOLD}HISTÓRICO 7 DIAS{C_RESET}")
            spark_line = "  "
            blocks = [" ", " ", "▂", "▃", "▄", "▅", "▆", "▇", "█"]
            max_r = max([d["reqs"] for d in spark] + [10])
            for d in spark:
                val = d["reqs"]
                idx = min(len(blocks) - 1, int((val / max_r) * (len(blocks) - 1)))
                b = blocks[idx]
                if d["is_today"]:
                    spark_line += f"{C_ORANGE}{C_BOLD}{b} Hoje{C_RESET} "
                else:
                    spark_line += f"{C_GRAY}{b} {d['label']}{C_RESET} "
            out.append(spark_line)
            out.append("")

            # Sessão Ativa
            out.append(f"  {C_BOLD}SESSÃO & WORKFLOW{C_RESET}")
            out.append(f"  Modelo:      {C_CYAN}{s['model']}{C_RESET}")
            out.append(f"  Conversa:    {C_GRAY}{s['active_conv_short']}{C_RESET} (atividade: {s['last_active']})")
            out.append(f"  Ferramentas: {C_GRAY}{s['tools_count']} execuções de ações{C_RESET}")
            out.append("")
            out.append(f"{C_GRAY}  [Pressione Ctrl+C para sair • Web: http://127.0.0.1:{metrics['config']['port']}]{C_RESET}")

            print("\n".join(out), flush=True)
            time.sleep(3)
    except KeyboardInterrupt:
        print(f"\n{C_GRAY}Monitor finalizado.{C_RESET}")

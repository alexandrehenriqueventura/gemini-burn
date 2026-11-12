"""
Módulo de Varredura e Cálculo de Métricas do Antigravity & Gemini Burn.
Lê os registros do Antigravity (~/.gemini/antigravity-ide/brain/) com cache
incremental baseado em mtime e unifica com as chamadas de API salvas no SQLite.
"""

import os
import glob
import json
import re
from datetime import datetime, timezone, timedelta
from typing import Dict, Any, List

from . import tracker

# Configuração e caminhos padrão
CONFIG_DIR = os.path.expanduser("~/.gemini-burn")
CONFIG_PATH = os.path.join(CONFIG_DIR, "config.json")
DEFAULT_CONFIG = {
    "daily_request_limit": 500,
    "daily_token_limit": 50_000_000,
    "refresh_interval_sec": 5,
    "always_on_top": True,
    "chars_per_token": 4.0,
    "port": 5678,
    "theme": "dark_modern"
}

# Cache de arquivos para leitura incremental rápida
_FILE_CACHE: Dict[str, Dict[str, Any]] = {}

def load_config() -> Dict[str, Any]:
    os.makedirs(CONFIG_DIR, exist_ok=True)
    if os.path.exists(CONFIG_PATH):
        try:
            with open(CONFIG_PATH, "r", encoding="utf-8") as f:
                data = json.load(f)
                cfg = DEFAULT_CONFIG.copy()
                cfg.update(data)
                return cfg
        except Exception:
            pass
    # Se não existe, cria padrão
    try:
        with open(CONFIG_PATH, "w", encoding="utf-8") as f:
            json.dump(DEFAULT_CONFIG, f, indent=2)
    except Exception:
        pass
    return DEFAULT_CONFIG.copy()

def save_config(new_cfg: Dict[str, Any]):
    os.makedirs(CONFIG_DIR, exist_ok=True)
    cfg = load_config()
    cfg.update(new_cfg)
    with open(CONFIG_PATH, "w", encoding="utf-8") as f:
        json.dump(cfg, f, indent=2)
    return cfg

def format_tokens(n: int) -> str:
    """Formata contagem de tokens em notação compacta (K, M, B)."""
    if n >= 1_000_000_000:
        return f"{n / 1_000_000_000:.2f}B"
    if n >= 1_000_000:
        return f"{n / 1_000_000:.2f}M"
    if n >= 1_000:
        return f"{n / 1_000:.1f}K"
    return str(n)

def get_time_ago(dt: datetime) -> str:
    """Gera texto amigável de tempo decorrido em português."""
    now = datetime.now(dt.tzinfo or timezone.utc)
    diff = now - dt
    secs = int(diff.total_seconds())
    if secs < 0:
        return "agora mesmo"
    if secs < 60:
        return f"há {secs}s"
    mins = secs // 60
    if mins < 60:
        return f"há {mins}m"
    hours = mins // 60
    if hours < 24:
        return f"há {hours}h"
    days = hours // 24
    return f"há {days}d"

def parse_transcript_file(file_path: str, chars_per_tok: float = 4.0):
    """
    Analisa um arquivo transcript_full.jsonl ou transcript.jsonl.
    Retorna chamadas detalhadas com timestamp, tokens e modelo.
    """
    global _FILE_CACHE
    mtime = os.path.getmtime(file_path)
    size = os.path.getsize(file_path)

    # Checagem de cache
    cache_entry = _FILE_CACHE.get(file_path)
    if cache_entry and cache_entry["mtime"] == mtime and cache_entry["size"] == size:
        return cache_entry["data"]

    events = []
    tools_count = 0
    models_found = {}
    accumulated_chars = 0
    latest_event_dt = None

    try:
        with open(file_path, "r", encoding="utf-8", errors="ignore") as f:
            for line in f:
                if not line.strip():
                    continue
                try:
                    row = json.loads(line)
                except Exception:
                    continue

                stype = row.get("type")
                source = row.get("source")
                content = row.get("content") or ""
                thinking = row.get("thinking") or ""
                c_len = len(content) + len(thinking)
                accumulated_chars += c_len

                # Rastreamento de modelo especificado
                if stype == "USER_INPUT" and "Model Selection" in content:
                    match = re.search(r"Model Selection\` from .*? to (.*?)\.", content)
                    if match:
                        mod = match.group(1).strip()
                        models_found[mod] = models_found.get(mod, 0) + 1

                # Ferramentas executadas pelo agente
                if source == "MODEL" and stype not in ("PLANNER_RESPONSE",):
                    tools_count += 1

                # Cada resposta do planejador é uma requisição enviada ao Gemini
                if stype == "PLANNER_RESPONSE":
                    cat = row.get("created_at")
                    if cat:
                        try:
                            # Converte UTC para horário local da máquina
                            dt_utc = datetime.fromisoformat(cat.replace("Z", "+00:00"))
                            dt_local = dt_utc.astimezone()
                            if latest_event_dt is None or dt_local > latest_event_dt:
                                latest_event_dt = dt_local

                            # Se o log já contém tokens exatos reportados pelo Antigravity, usa-os
                            if "input_tokens" in row and row["input_tokens"] is not None:
                                in_tokens = int(row.get("input_tokens") or 0)
                                out_tokens = int(row.get("output_tokens") or 0)
                            else:
                                in_tokens = int(accumulated_chars / chars_per_tok)
                                out_tokens = int(c_len / chars_per_tok)

                            events.append({
                                "dt": dt_local,
                                "tokens_in": in_tokens,
                                "tokens_out": out_tokens,
                                "total_tokens": in_tokens + out_tokens
                            })
                        except Exception:
                            pass
    except Exception:
        pass

    result = {
        "events": events,
        "tools_count": tools_count,
        "models": models_found,
        "latest_dt": latest_event_dt
    }

    _FILE_CACHE[file_path] = {
        "mtime": mtime,
        "size": size,
        "data": result
    }
    return result

def collect_metrics() -> Dict[str, Any]:
    """Coleta e compila todas as métricas em formato unificado para UI/API."""
    config = load_config()
    chars_per_tok = float(config.get("chars_per_token", 4.0))
    daily_req_limit = int(config.get("daily_request_limit", 500))

    # 1. Localizar todos os diretórios brain do Antigravity (~/.gemini/*/brain)
    brain_dirs = glob.glob(os.path.expanduser("~/.gemini/*/brain"))
    for fallback_path in [
        os.path.expanduser("~/.gemini/antigravity/brain"),
        os.path.expanduser("~/.gemini/antigravity-ide/brain"),
    ]:
        if os.path.exists(fallback_path) and fallback_path not in brain_dirs:
            brain_dirs.append(fallback_path)

    # Mapear as conversas ativas/arquivadas unificadas
    conv_map: Dict[str, str] = {}
    for b_dir in brain_dirs:
        for conv_path in glob.glob(os.path.join(b_dir, "*")):
            if not os.path.isdir(conv_path):
                continue
            conv_id = os.path.basename(conv_path)
            logs_dir = os.path.join(conv_path, ".system_generated", "logs")
            if not os.path.exists(logs_dir):
                continue
            tf = os.path.join(logs_dir, "transcript_full.jsonl")
            t = os.path.join(logs_dir, "transcript.jsonl")
            target_file = tf if os.path.exists(tf) else (t if os.path.exists(t) else None)
            if target_file:
                # Se já vimos esse conv_id em outro diretório, mantém o arquivo com mtime mais recente
                if conv_id not in conv_map or os.path.getmtime(target_file) > os.path.getmtime(conv_map[conv_id]):
                    conv_map[conv_id] = target_file

    daily_map = {}
    weekly_map = {}
    all_models = {}
    total_tools = 0
    active_conv_id = None
    latest_activity_dt = None

    now_local = datetime.now().astimezone()
    one_hour_ago = now_local - timedelta(hours=1)
    reqs_last_hour = 0
    tokens_last_hour = 0

    # Processar dados de cada conversa
    for conv_id, t_file in conv_map.items():
        parsed = parse_transcript_file(t_file, chars_per_tok=chars_per_tok)
        
        total_tools += parsed["tools_count"]
        for m_name, count in parsed["models"].items():
            all_models[m_name] = all_models.get(m_name, 0) + count

        if parsed["latest_dt"]:
            if latest_activity_dt is None or parsed["latest_dt"] > latest_activity_dt:
                latest_activity_dt = parsed["latest_dt"]
                active_conv_id = conv_id

        for ev in parsed["events"]:
            dt = ev["dt"]
            d_str = dt.strftime("%Y-%m-%d")
            w_str = dt.strftime("%Y-W%W")

            if dt >= one_hour_ago:
                reqs_last_hour += 1
                tokens_last_hour += ev["total_tokens"]

            if d_str not in daily_map:
                daily_map[d_str] = {"reqs": 0, "tokens_in": 0, "tokens_out": 0}
            daily_map[d_str]["reqs"] += 1
            daily_map[d_str]["tokens_in"] += ev["tokens_in"]
            daily_map[d_str]["tokens_out"] += ev["tokens_out"]

            if w_str not in weekly_map:
                weekly_map[w_str] = {"reqs": 0, "tokens_in": 0, "tokens_out": 0}
            weekly_map[w_str]["reqs"] += 1
            weekly_map[w_str]["tokens_in"] += ev["tokens_in"]
            weekly_map[w_str]["tokens_out"] += ev["tokens_out"]

    # 2. Mesclar dados de chamadas manuais/avulsas do SQLite
    try:
        api_summary = tracker.get_api_calls_summary()
        for d_str, val in api_summary["daily"].items():
            if d_str not in daily_map:
                daily_map[d_str] = {"reqs": 0, "tokens_in": 0, "tokens_out": 0}
            daily_map[d_str]["reqs"] += val["reqs"]
            daily_map[d_str]["tokens_in"] += val["tokens_in"]
            daily_map[d_str]["tokens_out"] += val["tokens_out"]

        for w_str, val in api_summary["weekly"].items():
            if w_str not in weekly_map:
                weekly_map[w_str] = {"reqs": 0, "tokens_in": 0, "tokens_out": 0}
            weekly_map[w_str]["reqs"] += val["reqs"]
            weekly_map[w_str]["tokens_in"] += val["tokens_in"]
            weekly_map[w_str]["tokens_out"] += val["tokens_out"]
    except Exception:
        pass

    # 3. Métricas de Hoje
    today_key = now_local.strftime("%Y-%m-%d")
    t_data = daily_map.get(today_key, {"reqs": 0, "tokens_in": 0, "tokens_out": 0})

    t_in = t_data["tokens_in"]
    t_out = t_data["tokens_out"]
    t_total = t_in + t_out
    daily_pct = min(100.0, round((t_data["reqs"] / max(1, daily_req_limit)) * 100, 1))

    # 4. Histórico dos últimos 7 dias (para mini-gráfico e métrica da semana móvel)
    days_labels = ["Seg", "Ter", "Qua", "Qui", "Sex", "Sáb", "Dom"]
    last_7_days = []
    for i in range(6, -1, -1):
        target_day = now_local - timedelta(days=i)
        t_key = target_day.strftime("%Y-%m-%d")
        day_weekday = days_labels[target_day.weekday()]
        day_stat = daily_map.get(t_key, {"reqs": 0, "tokens_in": 0, "tokens_out": 0})
        is_today = (i == 0)
        last_7_days.append({
            "date": t_key,
            "label": "Hoje" if is_today else day_weekday,
            "reqs": day_stat["reqs"],
            "tokens": day_stat["tokens_in"] + day_stat["tokens_out"],
            "tokens_fmt": format_tokens(day_stat["tokens_in"] + day_stat["tokens_out"]),
            "is_today": is_today
        })

    # Métricas da Semana Calendário (Inicia na Segunda-feira às 00:00:00 até o momento atual)
    start_of_week_date = (now_local - timedelta(days=now_local.weekday())).date()
    w_reqs = 0
    w_total = 0
    for d_str, d_val in daily_map.items():
        try:
            d_obj = datetime.strptime(d_str, "%Y-%m-%d").date()
            if start_of_week_date <= d_obj <= now_local.date():
                w_reqs += d_val["reqs"]
                w_total += (d_val["tokens_in"] + d_val["tokens_out"])
        except Exception:
            pass

    # Harmonia total de rótulo e cor (Apple HIG):
    # - < 50% (Verde): Ativo ⚡ (ou Ocioso 💤 se sem atividade recente)
    # - 50% a 69% (Amarelo): Moderado ⚡
    # - >= 70% (Vermelho): Fervendo 🔥
    if daily_pct >= 70:
        pace_label = "Fervendo 🔥"
        pace_class = "fire"
    elif daily_pct >= 50:
        pace_label = "Moderado ⚡"
        pace_class = "moderate"
    elif reqs_last_hour > 0:
        pace_label = "Ativo ⚡"
        pace_class = "active"
    else:
        pace_label = "Ocioso 💤"
        pace_class = "idle"

    # Modelo dominante
    model_name = "Gemini 3.8 Flash"
    if all_models:
        model_name = max(all_models.items(), key=lambda x: x[1])[0]

    time_ago_str = get_time_ago(latest_activity_dt) if latest_activity_dt else "nenhuma"

    metrics_result = {
        "status": "connected",
        "updated_at": now_local.strftime("%H:%M:%S"),
        "today": {
            "reqs": t_data["reqs"],
            "tokens_in": t_in,
            "tokens_out": t_out,
            "total_tokens": t_total,
            "tokens_in_fmt": format_tokens(t_in),
            "tokens_out_fmt": format_tokens(t_out),
            "total_tokens_fmt": format_tokens(t_total),
            "limit": daily_req_limit,
            "pct": daily_pct
        },
        "week": {
            "reqs": w_reqs,
            "total_tokens": w_total,
            "total_tokens_fmt": format_tokens(w_total)
        },
        "pace": {
            "reqs_hour": reqs_last_hour,
            "tokens_hour_fmt": format_tokens(tokens_last_hour),
            "label": pace_label,
            "class": pace_class
        },
        "session": {
            "active_conv": active_conv_id or "idle",
            "active_conv_short": (active_conv_id[:8] + "...") if active_conv_id else "idle",
            "model": model_name,
            "tools_count": total_tools,
            "last_active": time_ago_str
        },
        "sparkline": last_7_days,
        "config": config
    }

    # Persiste em cache JSON para consumo instantâneo pela extensão GNOME
    try:
        stats_file = os.path.join(CONFIG_DIR, "stats.json")
        with open(stats_file, "w", encoding="utf-8") as sf:
            json.dump(metrics_result, sf, indent=2)
    except Exception:
        pass

    return metrics_result


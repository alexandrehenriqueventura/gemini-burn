"""
Módulo de Rastreamento e Armazenamento em SQLite para o Gemini Burn.
Gerencia o banco de dados local ~/.gemini-burn/metrics.db para persistência de
métricas de chamadas diretas de API (Google AI Studio) e cache unificado.
"""

import os
import sqlite3
from datetime import datetime, timezone

DB_DIR = os.path.expanduser("~/.gemini-burn")
DB_PATH = os.path.join(DB_DIR, "metrics.db")

def get_connection():
    os.makedirs(DB_DIR, exist_ok=True)
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn

def init_db():
    with get_connection() as conn:
        conn.execute("""
            CREATE TABLE IF NOT EXISTS api_calls (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp TEXT NOT NULL,
                source TEXT NOT NULL, -- 'gemini_api', 'ai_studio', 'antigravity_manual'
                model TEXT NOT NULL,
                tokens_in INTEGER DEFAULT 0,
                tokens_out INTEGER DEFAULT 0,
                total_tokens INTEGER DEFAULT 0,
                cost_usd REAL DEFAULT 0.0,
                status TEXT DEFAULT 'success'
            )
        """)
        conn.execute("CREATE INDEX IF NOT EXISTS idx_timestamp ON api_calls(timestamp);")
        conn.commit()

def record_call(model: str, tokens_in: int = 0, tokens_out: int = 0, source: str = "gemini_api", cost_usd: float = 0.0):
    """Registra uma chamada avulsa à API do Gemini."""
    init_db()
    total = tokens_in + tokens_out
    now_iso = datetime.now(timezone.utc).isoformat()
    with get_connection() as conn:
        conn.execute("""
            INSERT INTO api_calls (timestamp, source, model, tokens_in, tokens_out, total_tokens, cost_usd)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        """, (now_iso, source, model, tokens_in, tokens_out, total, cost_usd))
        conn.commit()

def get_api_calls_summary():
    """Retorna o resumo agregado de chamadas registradas manualmente no banco."""
    init_db()
    daily_stats = {}
    weekly_stats = {}
    
    with get_connection() as conn:
        rows = conn.execute("SELECT timestamp, tokens_in, tokens_out, total_tokens FROM api_calls").fetchall()
        for r in rows:
            ts = r["timestamp"]
            try:
                dt = datetime.fromisoformat(ts).astimezone()
                d_str = dt.strftime("%Y-%m-%d")
                w_str = dt.strftime("%Y-W%W")

                if d_str not in daily_stats:
                    daily_stats[d_str] = {"reqs": 0, "tokens_in": 0, "tokens_out": 0}
                daily_stats[d_str]["reqs"] += 1
                daily_stats[d_str]["tokens_in"] += r["tokens_in"]
                daily_stats[d_str]["tokens_out"] += r["tokens_out"]

                if w_str not in weekly_stats:
                    weekly_stats[w_str] = {"reqs": 0, "tokens_in": 0, "tokens_out": 0}
                weekly_stats[w_str]["reqs"] += 1
                weekly_stats[w_str]["tokens_in"] += r["tokens_in"]
                weekly_stats[w_str]["tokens_out"] += r["tokens_out"]
            except Exception:
                continue

    return {
        "daily": daily_stats,
        "weekly": weekly_stats
    }

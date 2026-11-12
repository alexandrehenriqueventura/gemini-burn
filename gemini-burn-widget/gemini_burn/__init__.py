"""
Gemini Burn - Widget e Monitor de Requisições / Tokens para Gemini e Antigravity IDE.
"""

__version__ = "1.0.0"
__author__ = "André Porto"

from .parser import collect_metrics, load_config, save_config
from .tracker import record_call
from .server import start_server

# .claude/delegate.py
import subprocess
import sys
import os
import re

# APIs MT5 que le modèle local ne doit jamais toucher
MT5_DANGEROUS_PATTERNS = [
    r'\bOrderSend\b', r'\bOrderModify\b', r'\bOrderClose\b',
    r'\bPositionSelect\b', r'\bPositionGet',
    r'\bCopyRates\b', r'\bCopyBuffer\b',
    r'\biMA\b', r'\biRSI\b', r'\biATR\b', r'\biMACD\b',
    r'\bSymbolInfoDouble\b', r'\bAccountInfoDouble\b',
    r'\bOnTick\b', r'\bOnTrade\b',
]

def is_safe_to_delegate(task: str, file_path: str) -> tuple[bool, str]:
    """Vérifie que ni la tâche ni le fichier ne touchent aux APIs MT5."""
    
    # Vérifier la description de la tâche
    for pattern in MT5_DANGEROUS_PATTERNS:
        if re.search(pattern, task, re.IGNORECASE):
            return False, f"La tâche mentionne une API MT5 : {pattern}"
    
    # Vérifier si c'est un fichier MQL5
    if file_path.endswith(('.mq5', '.mqh')):
        # Lire le fichier et vérifier le contexte
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
            
            # Compter les APIs MT5 présentes
            api_count = sum(
                1 for p in MT5_DANGEROUS_PATTERNS 
                if re.search(p, content)
            )
            
            if api_count > 5:
                return False, f"Fichier complexe ({api_count} APIs MT5 détectées) — laisser Claude traiter"
        except:
            pass
    
    return True, "OK"

def delegate_to_aider(task: str, files: list[str]) -> str:
    
    # Vérification de sécurité pour les fichiers MQL5
    for f in files:
        safe, reason = is_safe_to_delegate(task, f)
        if not safe:
            return f"⚠️ Délégation refusée : {reason}\nTraiter avec Claude directement."
    
    cmd = [
        "aider",
        "--model", "ollama/qwen2.5-coder:7b",
        "--no-git",
        "--yes",
        "--message", task,
        *files
    ]
    
    env = os.environ.copy()
    env["OLLAMA_API_BASE"] = "http://localhost:11434"
    
    result = subprocess.run(cmd, capture_output=True, text=True, env=env)
    
    if result.returncode == 0:
        return f"✅ Délégué au modèle local\n{result.stdout}"
    else:
        return f"❌ Erreur Aider : {result.stderr}"

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python delegate.py 'tâche' fichier.mq5")
        sys.exit(1)
    
    task = sys.argv[1]
    files = sys.argv[2:]
    print(delegate_to_aider(task, files))

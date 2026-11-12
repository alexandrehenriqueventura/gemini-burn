# Apple Design System & Guidelines (Web)

Este documento define os padrões visuais, tokens de estilo e princípios de interação física inspirados no ecossistema Apple (macOS / iOS / iPadOS) para interfaces web modernas, com foco em Dark Mode, superfícies de vidro fosco (glassmorphism) e microinterações táteis.

---

## 1. Princípios Fundamentais (Apple HIG & Fluid Interfaces)

1. **Feedback Imediato (Kill Latency)**: Toda interação táctil ou clique deve responder no instante do `pointerdown` / `:active`, nunca esperando o término do clique ou transições artificiais.
2. **Superfícies Físicas e Profundidade**: Uso de camadas translúcidas com desfoque de fundo (*frosted glass*), saturação acentuada e realces sutis de borda interna (*inner glow / stroke*).
3. **Curvatura Contínua (Squircle)**: Cantos arredondados contínuos e generosos (`border-radius` entre 14px e 28px).
4. **Tipografia do Sistema**: Priorizar fontes nativas da Apple (`SF Pro Display`, `SF Pro Text`, `SF Mono`), com suavização `-webkit-font-smoothing: antialiased`.
5. **Movimento Baseado em Molas (Spring Physics)**: Transições interruptíveis usando curvas de aceleração Apple (`cubic-bezier(0.16, 1, 0.3, 1)`) ou molas criticamente amortecidas (*damping 1.0*).

---

## 2. Design Tokens (CSS Variables)

Sempre que implementar componentes ou folhas de estilo, utilize os tokens abaixo como base:

```css
:root {
  /* Tipografia */
  --font-sans: -apple-system, BlinkMacSystemFont, 'SF Pro Display', 'SF Pro Text', 'Plus Jakarta Sans', system-ui, sans-serif;
  --font-mono: 'SF Mono', 'JetBrains Mono', Menlo, Consolas, monospace;

  /* Superfícies & Glassmorphism */
  --apple-bg-base: #1c1c1e;
  --apple-bg-secondary: #151515;
  --apple-glass-surface: rgba(47, 47, 47, 0.85);
  --apple-glass-card: rgba(255, 255, 255, 0.04);
  --apple-glass-card-hover: rgba(255, 255, 255, 0.08);

  /* Bordas e Realces */
  --apple-border: rgba(255, 255, 255, 0.12);
  --apple-border-hover: rgba(255, 255, 255, 0.22);
  --apple-border-subtle: rgba(255, 255, 255, 0.06);

  /* Cores de Texto */
  --apple-text-primary: #f5f5f7;
  --apple-text-secondary: #a1a1a6;
  --apple-text-muted: #86868b;

  /* Acentos de Sistema Apple */
  --apple-blue: #0a84ff;
  --apple-orange: #ff9f0a;
  --apple-red: #ff453a;
  --apple-green: #30d158;
  --apple-purple: #af52de;
  --apple-indigo: #5e5ce6;
  --apple-pink: #ff375f;

  /* Gradientes Dinâmicos */
  --apple-gradient-accent: linear-gradient(135deg, #4f46e5 0%, #06b6d4 100%);
  --apple-gradient-flame: linear-gradient(135deg, #ff9f0a 0%, #ff453a 100%);

  /* Raios de Arredondamento (Squircle) */
  --radius-pill: 9999px;
  --radius-sm: 8px;
  --radius-md: 14px;
  --radius-lg: 18px;
  --radius-xl: 26px;

  /* Easing & Sombras */
  --apple-ease: cubic-bezier(0.16, 1, 0.3, 1);
  --apple-shadow-elevation: 0 24px 50px -10px rgba(0, 0, 0, 0.65), 0 0 0 1px rgba(255, 255, 255, 0.12) inset;
}
```

---

## 3. Padrões de Componentes

### 3.1 Container Principal / Modal Glass
```css
.apple-glass-container {
  background: var(--apple-glass-surface);
  backdrop-filter: blur(30px) saturate(190%);
  -webkit-backdrop-filter: blur(30px) saturate(190%);
  border: 1px solid var(--apple-border);
  border-radius: var(--radius-xl);
  box-shadow: var(--apple-shadow-elevation);
  padding: 16px;
  transition: all 0.25s var(--apple-ease);
}
```

### 3.2 Cards Internos
```css
.apple-card {
  background: var(--apple-glass-card);
  border: 1px solid var(--apple-border-subtle);
  border-radius: var(--radius-md);
  padding: 14px;
  transition: all 0.2s var(--apple-ease);
}

.apple-card:hover {
  background: var(--apple-glass-card-hover);
  border-color: var(--apple-border-hover);
}
```

### 3.3 Botões com Resposta Táctil Instantânea
```css
.apple-button {
  font-family: var(--font-sans);
  font-size: 13px;
  font-weight: 600;
  color: var(--apple-text-primary);
  background: rgba(255, 255, 255, 0.08);
  border: 1px solid var(--apple-border);
  border-radius: var(--radius-sm);
  padding: 8px 16px;
  cursor: pointer;
  outline: none;
  transition: transform 0.1s var(--apple-ease), background 0.15s ease, border-color 0.15s ease;
}

.apple-button:hover {
  background: rgba(255, 255, 255, 0.14);
  border-color: var(--apple-border-hover);
}

/* Compressão táctil imediata no clique */
.apple-button:active {
  transform: scale(0.96);
  background: rgba(255, 255, 255, 0.18);
}
```

### 3.4 Badges / Indicadores de Status (Pill)
```css
.apple-badge {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 4px 10px;
  border-radius: var(--radius-pill);
  font-size: 11px;
  font-weight: 600;
  letter-spacing: 0.02em;
  background: rgba(255, 255, 255, 0.06);
  border: 1px solid var(--apple-border-subtle);
  color: var(--apple-text-secondary);
}

.apple-badge.warning {
  background: rgba(255, 159, 10, 0.12);
  border-color: rgba(255, 159, 10, 0.3);
  color: var(--apple-orange);
}

.apple-badge.danger {
  background: rgba(255, 69, 58, 0.12);
  border-color: rgba(255, 69, 58, 0.3);
  color: var(--apple-red);
}

.apple-badge.success {
  background: rgba(48, 209, 88, 0.12);
  border-color: rgba(48, 209, 88, 0.3);
  color: var(--apple-green);
}
```

---

## 4. Diretrizes de Animação e Física

- **Sem tempos de espera artificiais**: Evite durações acima de 300ms para microinterações.
- **Interrupção**: Qualquer animação em andamento deve permitir ser revertida ou interrompida pelo usuário imediatamente sem travar o input.
- **Transições Suaves**: Para elementos que redimensionam ou expandem, mantenha sempre a curva `--apple-ease` (`cubic-bezier(0.16, 1, 0.3, 1)`).


import Clutter from 'gi://Clutter';
import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import GObject from 'gi://GObject';
import St from 'gi://St';

import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as PanelMenu from 'resource:///org/gnome/shell/ui/panelMenu.js';
import * as PopupMenu from 'resource:///org/gnome/shell/ui/popupMenu.js';
import { Extension, gettext as _ } from 'resource:///org/gnome/shell/extensions/extension.js';

function _getRepoDir() {
    const home = GLib.get_home_dir();
    const candidates = [
        GLib.build_filenamev([home, '.local', 'share', 'gemini-burn']),
        GLib.build_filenamev([home, 'Documentos', 'GitHub', 'gemini-burn-widget']),
        GLib.build_filenamev([home, 'Documents', 'GitHub', 'gemini-burn-widget'])
    ];
    for (const d of candidates) {
        if (GLib.file_test(GLib.build_filenamev([d, 'main.py']), GLib.FileTest.EXISTS)) {
            return d;
        }
    }
    return candidates[0];
}
const REPO_DIR = _getRepoDir();
const STATS_FILE = GLib.build_filenamev([GLib.get_home_dir(), '.gemini-burn', 'stats.json']);

const GeminiBurnIndicator = GObject.registerClass({
    GTypeName: 'GeminiBurnIndicator',
}, class GeminiBurnIndicator extends PanelMenu.Button {
    _init(extension) {
        super._init(0.5, 'Gemini Burn Indicator', false);
        this._extension = extension;

        // Container visual no painel superior (NÃO pode ser reativo para permitir que o clique atinja este PanelMenu.Button)
        this._panelBox = new St.BoxLayout({
            style_class: 'panel-status-menu-box',
            reactive: false,
            can_focus: false,
            track_hover: false,
            y_align: Clutter.ActorAlign.CENTER
        });

        this._flameLabel = new St.Label({
            text: '🔥',
            reactive: false,
            can_focus: false,
            y_align: Clutter.ActorAlign.CENTER
        });

        this._statsLabel = new St.Label({
            text: 'Carregando...',
            style_class: 'gemini-burn-panel-label',
            reactive: false,
            can_focus: false,
            y_align: Clutter.ActorAlign.CENTER
        });

        this._panelBox.add_child(this._flameLabel);
        this._panelBox.add_child(this._statsLabel);
        this.add_child(this._panelBox);

        // Garante interatividade no botão
        this.reactive = true;
        this.can_focus = true;
        this.track_hover = true;

        // Estiliza o menu dropdown
        this.menu.box.add_style_class_name('gemini-burn-menu');

        // Carregamento inicial de métricas
        this._currentData = this._loadStatsFromDisk();
        this._updatePanelDisplay();

        // Constrói os elementos da interface do menu popup (uma única vez)
        this._buildMenu();
        this._updateMenuValues();

        // Ao abrir o menu, recarrega os dados e dispara uma coleta assíncrona imediata
        this.menu.connect('open-state-changed', (menu, isOpen) => {
            if (isOpen) {
                this._currentData = this._loadStatsFromDisk();
                this._updatePanelDisplay();
                this._updateMenuValues();
                this._runParserAsync();
            }
        });

        // Loop contínuo de atualização periódica do painel e do menu
        let tickCount = 0;
        this._timeoutId = GLib.timeout_add_seconds(GLib.PRIORITY_DEFAULT, 4, () => {
            tickCount++;
            this._currentData = this._loadStatsFromDisk();
            this._updatePanelDisplay();
            if (this.menu && this.menu.isOpen) {
                this._updateMenuValues();
            }
            // A cada 3 ciclos (~12 segundos), ou se o menu estiver aberto, dispara parser assíncrono como garantia
            if ((this.menu && this.menu.isOpen) || tickCount % 3 === 0) {
                this._runParserAsync();
            }
            return GLib.SOURCE_CONTINUE;
        });
    }

    vfunc_event(event) {
        if (event.type() === Clutter.EventType.BUTTON_PRESS) {
            if (event.get_button() === Clutter.BUTTON_PRIMARY || event.get_button() === Clutter.BUTTON_MIDDLE) {
                if (this.menu) {
                    this.menu.toggle();
                    return Clutter.EVENT_STOP;
                }
            }
        } else if (event.type() === Clutter.EventType.TOUCH_BEGIN) {
            if (this.menu) {
                this.menu.toggle();
                return Clutter.EVENT_STOP;
            }
        }
        return Clutter.EVENT_PROPAGATE;
    }

    _loadStatsFromDisk() {
        try {
            const statsFile = (typeof STATS_FILE !== 'undefined')
                ? STATS_FILE
                : GLib.build_filenamev([GLib.get_home_dir(), '.gemini-burn', 'stats.json']);
            if (GLib.file_test(statsFile, GLib.FileTest.EXISTS)) {
                const [ok, contents] = GLib.file_get_contents(statsFile);
                if (ok) {
                    const decoder = new TextDecoder('utf-8');
                    return JSON.parse(decoder.decode(contents));
                }
            }
        } catch (e) {
            console.error('[Gemini Burn] Erro ao carregar stats.json: ' + e);
        }
        return null;
    }

    _updatePanelDisplay() {
        if (!this._currentData || !this._currentData.today) {
            this._statsLabel.text = 'Ocioso';
            return;
        }
        const today = this._currentData.today;
        this._statsLabel.text = `${today.reqs || 0} reqs | ${today.total_tokens_fmt || '0'}`;
    }

    _runParserAsync() {
        try {
            const proc = Gio.Subprocess.new(
                ['python3', '-c', `import sys; sys.path.insert(0, '${REPO_DIR}'); from gemini_burn import parser; parser.collect_metrics()`],
                Gio.SubprocessFlags.NONE
            );
            proc.wait_async(null, (source, res) => {
                try {
                    source.wait_finish(res);
                    this._currentData = this._loadStatsFromDisk();
                    this._updatePanelDisplay();
                    this._updateMenuValues();
                } catch (e) {
                    console.error('[Gemini Burn] Erro pós parser async: ' + e);
                }
            });
        } catch (e) {
            console.error('[Gemini Burn] Falha ao lançar parser async: ' + e);
        }
    }

    _buildMenu() {
        this.menu.removeAll();

        // 1. Cabeçalho Estilizado com Botão de Atualizar Apple
        const headerItem = new PopupMenu.PopupBaseMenuItem({
            reactive: false,
            can_focus: false,
            style_class: 'gemini-burn-menu-item'
        });
        const headerBox = new St.BoxLayout({
            x_expand: true,
            y_align: Clutter.ActorAlign.CENTER,
            style_class: 'gemini-burn-header-box'
        });

        const brandBox = new St.BoxLayout({ vertical: true, x_expand: true });
        const titleLabel = new St.Label({ text: '🔥 GEMINI BURN', style_class: 'gemini-burn-title' });
        const subLabel = new St.Label({ text: 'Antigravity Workflow Monitor', style_class: 'gemini-burn-subtitle' });
        brandBox.add_child(titleLabel);
        brandBox.add_child(subLabel);
        headerBox.add_child(brandBox);

        // Botão Ícone de Atualizar Discreto no Canto Superior Direito (Apple Style)
        const btnRefresh = new St.Button({
            style_class: 'gemini-burn-btn-apple-refresh',
            reactive: true,
            can_focus: true,
            track_hover: true,
            y_align: Clutter.ActorAlign.CENTER,
            x_align: Clutter.ActorAlign.END
        });
        const refreshIcon = new St.Icon({
            icon_name: 'view-refresh-symbolic',
            icon_size: 13,
            style_class: 'gemini-burn-refresh-icon'
        });
        btnRefresh.set_child(refreshIcon);
        btnRefresh.connect('clicked', () => {
            this._runParserAsync();
        });
        headerBox.add_child(btnRefresh);

        headerItem.add_child(headerBox);
        this.menu.addMenuItem(headerItem);

        // 2. Card Hero: Consumo de Hoje
        const heroItem = new PopupMenu.PopupBaseMenuItem({
            reactive: false,
            can_focus: false,
            style_class: 'gemini-burn-menu-item'
        });
        const heroCard = new St.BoxLayout({ vertical: true, x_expand: true, style_class: 'gemini-burn-card' });

        const heroTopRow = new St.BoxLayout({ x_expand: true });
        const heroTitle = new St.Label({ text: 'CONSUMO DE HOJE', style_class: 'gemini-burn-label-muted', x_expand: true });
        this._uiHeroPacePill = new St.Label({ text: 'Ativo ⚡', style_class: 'gemini-burn-pct' });
        heroTopRow.add_child(heroTitle);
        heroTopRow.add_child(this._uiHeroPacePill);
        heroCard.add_child(heroTopRow);

        const bigRow = new St.BoxLayout({ x_expand: true, y_align: Clutter.ActorAlign.CENTER });
        const leftBig = new St.BoxLayout({ vertical: true, x_expand: true });
        const reqsBox = new St.BoxLayout({ y_align: Clutter.ActorAlign.CENTER });
        this._uiHeroReqsNum = new St.Label({ text: '0', style_class: 'gemini-burn-big-num' });
        const reqsUnit = new St.Label({ text: 'reqs', style_class: 'gemini-burn-unit' });
        reqsBox.add_child(this._uiHeroReqsNum);
        reqsBox.add_child(reqsUnit);
        this._uiHeroTokensSub = new St.Label({ text: '~0 tokens', style_class: 'gemini-burn-subtext' });
        leftBig.add_child(reqsBox);
        leftBig.add_child(this._uiHeroTokensSub);
        bigRow.add_child(leftBig);

        const rightBig = new St.BoxLayout({ vertical: true });
        rightBig.set_x_align(Clutter.ActorAlign.END);
        const velBox = new St.BoxLayout({ y_align: Clutter.ActorAlign.CENTER });
        velBox.set_x_align(Clutter.ActorAlign.END);
        this._uiHeroVelNum = new St.Label({ text: '0', style_class: 'gemini-burn-big-num orange' });
        const velUnit = new St.Label({ text: 'req/h', style_class: 'gemini-burn-unit' });
        velBox.add_child(this._uiHeroVelNum);
        velBox.add_child(velUnit);
        this._uiHeroSplitSub = new St.Label({ text: '0 in • 0 out', style_class: 'gemini-burn-subtext' });
        rightBig.add_child(velBox);
        rightBig.add_child(this._uiHeroSplitSub);
        bigRow.add_child(rightBig);

        heroCard.add_child(bigRow);

        // Barra de Progresso
        const barBg = new St.BoxLayout({ style_class: 'gemini-burn-progress-bg', x_expand: true });
        this._uiProgressBarFill = new St.BoxLayout({ style_class: 'gemini-burn-progress-fill' });
        this._uiProgressBarFill.set_width(4);
        barBg.add_child(this._uiProgressBarFill);
        heroCard.add_child(barBg);

        const progressLabels = new St.BoxLayout({ x_expand: true });
        this._uiProgLeft = new St.Label({ text: '0 de 500 reqs diárias', style_class: 'gemini-burn-label-muted', x_expand: true });
        this._uiProgRight = new St.Label({ text: '0%', style_class: 'gemini-burn-pct' });
        progressLabels.add_child(this._uiProgLeft);
        progressLabels.add_child(this._uiProgRight);
        heroCard.add_child(progressLabels);

        heroItem.add_child(heroCard);
        this.menu.addMenuItem(heroItem);

        // 3. Mini Cards Duplos
        const gridItem = new PopupMenu.PopupBaseMenuItem({
            reactive: false,
            can_focus: false,
            style_class: 'gemini-burn-menu-item'
        });
        const gridContainer = new St.BoxLayout({
            vertical: false,
            x_expand: true,
            style_class: 'gemini-burn-grid-container',
            style: 'spacing: 10px;'
        });

        const cardWeek = new St.BoxLayout({ vertical: true, x_expand: true, style_class: 'gemini-burn-grid-card' });
        cardWeek.add_child(new St.Label({ text: 'SEMANA ATUAL', style_class: 'gemini-burn-label-muted' }));
        this._uiWeekReqs = new St.Label({ text: '0 reqs', style_class: 'gemini-burn-val-mono' });
        this._uiWeekTokens = new St.Label({ text: '~0 tokens', style_class: 'gemini-burn-subtext' });
        cardWeek.add_child(this._uiWeekReqs);
        cardWeek.add_child(this._uiWeekTokens);
        gridContainer.add_child(cardWeek);

        const cardTools = new St.BoxLayout({ vertical: true, x_expand: true, style_class: 'gemini-burn-grid-card' });
        cardTools.add_child(new St.Label({ text: 'FERRAMENTAS', style_class: 'gemini-burn-label-muted' }));
        this._uiToolsCount = new St.Label({ text: '0 tools', style_class: 'gemini-burn-val-mono' });
        this._uiToolsLast = new St.Label({ text: 'última: agora', style_class: 'gemini-burn-subtext' });
        cardTools.add_child(this._uiToolsCount);
        cardTools.add_child(this._uiToolsLast);
        gridContainer.add_child(cardTools);

        gridItem.add_child(gridContainer);
        this.menu.addMenuItem(gridItem);

        // 4. Mini Gráfico de Barras dos 7 Dias
        const chartItem = new PopupMenu.PopupBaseMenuItem({
            reactive: false,
            can_focus: false,
            style_class: 'gemini-burn-menu-item'
        });
        const chartCard = new St.BoxLayout({ vertical: true, x_expand: true, style_class: 'gemini-burn-card' });

        const chartTop = new St.BoxLayout({ x_expand: true });
        chartTop.add_child(new St.Label({ text: 'HISTÓRICO RECENTE (7 DIAS)', style_class: 'gemini-burn-label-muted', x_expand: true }));
        this._uiChartPeak = new St.Label({ text: 'pico: 0 reqs', style_class: 'gemini-burn-subtext' });
        chartTop.add_child(this._uiChartPeak);
        chartCard.add_child(chartTop);

        this._uiBarsRow = new St.BoxLayout({ vertical: false, x_expand: true, y_align: Clutter.ActorAlign.END });
        this._uiBarsRow.set_height(48);
        chartCard.add_child(this._uiBarsRow);

        chartItem.add_child(chartCard);
        this.menu.addMenuItem(chartItem);

        // 5. Modelo e Sessão Ativa
        const sessionItem = new PopupMenu.PopupBaseMenuItem({
            reactive: false,
            can_focus: false,
            style_class: 'gemini-burn-menu-item'
        });
        const sessionBox = new St.BoxLayout({ vertical: false, x_expand: true, y_align: Clutter.ActorAlign.CENTER, style_class: 'gemini-burn-card' });

        const sessLeft = new St.BoxLayout({ vertical: true, x_expand: true });
        this._uiSessionModel = new St.Label({ text: '● Gemini 3', style_class: 'gemini-burn-title' });
        this._uiSessionConv = new St.Label({ text: 'ID: idle', style_class: 'gemini-burn-subtext' });
        sessLeft.add_child(this._uiSessionModel);
        sessLeft.add_child(this._uiSessionConv);
        sessionBox.add_child(sessLeft);

        const sessBadgeBox = new St.BoxLayout({
            style_class: 'gemini-burn-badge',
            y_align: Clutter.ActorAlign.CENTER,
            x_align: Clutter.ActorAlign.END
        });
        const sessBadgeLabel = new St.Label({
            text: 'Antigravity IDE',
            style_class: 'gemini-burn-badge-label',
            y_align: Clutter.ActorAlign.CENTER,
            x_align: Clutter.ActorAlign.CENTER
        });
        sessBadgeBox.add_child(sessBadgeLabel);
        sessionBox.add_child(sessBadgeBox);

        sessionItem.add_child(sessionBox);
        this.menu.addMenuItem(sessionItem);
    }

    _updateMenuValues() {
        if (!this._currentData) return;

        const d = this._currentData;
        const today = d.today || {};
        const week = d.week || {};
        const pace = d.pace || {};
        const session = d.session || {};
        const sparkline = d.sparkline || [];

        const pct = Math.min(100.0, today.pct || 0);

        // Sistema de Cores Dinâmico Apple HIG (Dark Mode System Colors)
        // Até 49%: Apple System Green (#30D158)
        // 50% a 69%: Apple System Yellow (#FFD60A)
        // 70%+: Apple System Red (#FF453A)
        let tierColor, tierBg;
        if (pct >= 70) {
            tierColor = '#FF453A'; // Apple System Red
            tierBg = 'rgba(255, 69, 58, 0.18)';
        } else if (pct >= 50) {
            tierColor = '#FFD60A'; // Apple System Yellow
            tierBg = 'rgba(255, 214, 10, 0.16)';
        } else {
            tierColor = '#30D158'; // Apple System Green
            tierBg = 'rgba(48, 209, 88, 0.16)';
        }

        // 1. Hero Card
        if (this._uiHeroPacePill) {
            this._uiHeroPacePill.text = pace.label || 'Ativo ⚡';
            this._uiHeroPacePill.set_style(`color: ${tierColor};`);
        }
        if (this._uiHeroReqsNum) this._uiHeroReqsNum.text = `${today.reqs || 0}`;
        if (this._uiHeroTokensSub) this._uiHeroTokensSub.text = `~${today.total_tokens_fmt || '0'} tokens`;
        if (this._uiHeroVelNum) {
            this._uiHeroVelNum.text = `${pace.reqs_hour || 0}`;
            this._uiHeroVelNum.set_style(`color: ${tierColor};`);
        }
        if (this._uiHeroSplitSub) this._uiHeroSplitSub.text = `${today.tokens_in_fmt || '0'} in • ${today.tokens_out_fmt || '0'} out`;

        if (this._uiProgressBarFill) {
            const fillWidth = Math.max(4, Math.round(280 * (pct / 100.0)));
            const safeWidth = Number.isFinite(fillWidth) ? fillWidth : 4;
            this._uiProgressBarFill.set_width(safeWidth);
            this._uiProgressBarFill.set_style(`background-color: ${tierColor};`);
        }
        if (this._uiProgLeft) this._uiProgLeft.text = `${today.reqs || 0} de ${today.limit || 500} reqs diárias`;
        if (this._uiProgRight) {
            this._uiProgRight.text = `${pct}%`;
            this._uiProgRight.set_style(`color: ${tierColor};`);
        }

        // 3. Mini Cards
        if (this._uiWeekReqs) this._uiWeekReqs.text = `${week.reqs || 0} reqs`;
        if (this._uiWeekTokens) this._uiWeekTokens.text = `~${week.total_tokens_fmt || '0'} tokens`;
        if (this._uiToolsCount) this._uiToolsCount.text = `${session.tools_count || 0} tools`;
        if (this._uiToolsLast) this._uiToolsLast.text = `última: ${session.last_active || 'agora'}`;

        // 4. Sparkline (7 dias)
        if (this._uiBarsRow && sparkline.length > 0) {
            this._uiBarsRow.remove_all_children();
            const maxReqs = Math.max(...sparkline.map(s => s.reqs || 0), 10);
            if (this._uiChartPeak) this._uiChartPeak.text = `pico: ${maxReqs} reqs`;

            sparkline.forEach(day => {
                const col = new St.BoxLayout({ vertical: true, x_expand: true, y_align: Clutter.ActorAlign.END });
                const barHeight = Math.max(4, Math.round(((day.reqs || 0) / maxReqs) * 32));
                const safeHeight = Number.isFinite(barHeight) ? barHeight : 4;

                const fill = new St.BoxLayout({
                    style_class: `gemini-burn-bar-fill ${day.is_today ? 'today' : ''}`
                });
                fill.set_height(safeHeight);
                if (day.is_today) {
                    fill.set_style(`background-color: ${tierColor};`);
                }
                col.add_child(fill);

                const lbl = new St.Label({
                    text: day.label,
                    style_class: `gemini-burn-bar-label ${day.is_today ? 'today' : ''}`
                });
                lbl.set_x_align(Clutter.ActorAlign.CENTER);
                if (day.is_today) {
                    lbl.set_style(`color: ${tierColor}; font-weight: 700;`);
                }
                col.add_child(lbl);

                this._uiBarsRow.add_child(col);
            });
        }

        // 5. Sessão Ativa
        if (this._uiSessionModel) this._uiSessionModel.text = `● ${session.model || 'Gemini 3'}`;
        if (this._uiSessionConv) this._uiSessionConv.text = `ID: ${session.active_conv_short || 'idle'}`;
    }

    destroy() {
        if (this._timeoutId) {
            GLib.source_remove(this._timeoutId);
            this._timeoutId = null;
        }
        super.destroy();
    }
});

export default class GeminiBurnExtension extends Extension {
    enable() {
        this._indicator = new GeminiBurnIndicator(this);
        Main.panel.addToStatusArea('gemini-burn', this._indicator, 1, 'right');
    }

    disable() {
        if (this._indicator) {
            this._indicator.destroy();
            this._indicator = null;
        }
    }
}

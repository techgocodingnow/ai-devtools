// AgentToolKit · root app

const TWEAK_DEFAULTS = /*EDITMODE-BEGIN*/{
  "theme": "dark",
  "density": "regular",
  "accent": "violet",
  "sidebarLayout": "default"
}/*EDITMODE-END*/;

const ACCENTS = {
  violet: { primary: 'oklch(0.66 0.16 282)', soft: 'oklch(0.66 0.16 282 / 0.16)' },
  blue:   { primary: 'oklch(0.66 0.16 232)', soft: 'oklch(0.66 0.16 232 / 0.16)' },
  green:  { primary: 'oklch(0.66 0.16 152)', soft: 'oklch(0.66 0.16 152 / 0.16)' },
  amber:  { primary: 'oklch(0.72 0.15 78)',  soft: 'oklch(0.72 0.15 78 / 0.16)' },
};

const initialState = {
  // navigation
  screen: 'library',     // library | item-detail | marketplace | marketplace-settings | groups | agents | onboarding
  openItemId: null,
  detailTab: 'overview',
  showOnboarding: false,

  // workspace
  workspace: 'mcp',
  wsMenuOpen: false,
  workspaces: WORKSPACES,

  // data
  items: ITEMS,
  agents: AGENTS,
  groups: GROUPS,
  marketplaces: MARKETPLACES,
  marketplaceFeed: MARKETPLACE_FEED,
  hooks: HOOKS,
  hookEvents: HOOK_EVENTS,

  // library filters
  kindFilter: null,      // skill | plugin | mcp
  groupFilter: null,
  statusFilter: 'all',   // all | enabled | disabled | issues
  viewMode: 'list',
  search: '',

  // marketplace filters
  marketKindFilter: null,
  marketSource: 'all',

  // groups
  selectedGroup: 'design',

  // hooks
  hookEventFilter: null,
  hookAgentFilter: null,
  hookStatusFilter: 'all',
  selectedHookId: null,
  showHookForm: false,
  collapsedEvents: {},

  // misc
  scanning: false,
};

function reducer(state, action) {
  switch (action.type) {
    case 'nav': return {
      ...state,
      screen: action.screen,
      kindFilter: action.kindFilter ?? null,
      groupFilter: action.groupFilter ?? null,
      wsMenuOpen: false,
      openItemId: null,
    };
    case 'toggle-ws-menu': return { ...state, wsMenuOpen: !state.wsMenuOpen };
    case 'switch-ws': return { ...state, workspace: action.workspace, wsMenuOpen: false };
    case 'set-search': return { ...state, search: action.search };
    case 'set-status-filter': return { ...state, statusFilter: action.statusFilter };
    case 'set-view-mode': return { ...state, viewMode: action.viewMode };
    case 'open-item': return { ...state, screen: 'item-detail', openItemId: action.itemId, detailTab: 'overview' };
    case 'set-detail-tab': return { ...state, detailTab: action.detailTab };
    case 'toggle-enabled': {
      const items = state.items.map((it) => it.id === action.itemId
        ? { ...it, enabled: { ...it.enabled, [state.workspace]: action.value } } : it);
      return { ...state, items };
    }
    case 'set-scope-enabled': {
      const items = state.items.map((it) => it.id === action.itemId
        ? { ...it, enabled: { ...it.enabled, [action.ws]: action.value } } : it);
      return { ...state, items };
    }
    case 'install-scope': {
      const items = state.items.map((it) => it.id === action.itemId
        ? { ...it, scopes: { ...it.scopes, [action.ws]: true }, enabled: { ...it.enabled, [action.ws]: true } } : it);
      return { ...state, items };
    }
    case 'toggle-marketplace': {
      const marketplaces = state.marketplaces.map((m) => m.id === action.id ? { ...m, enabled: action.value } : m);
      return { ...state, marketplaces };
    }
    case 'set-market-kind': return { ...state, marketKindFilter: action.marketKindFilter };
    case 'set-market-source': return { ...state, marketSource: action.marketSource };
    case 'select-group': return { ...state, selectedGroup: action.selectedGroup };
    case 'set-hook-event':  return { ...state, hookEventFilter: action.hookEventFilter };
    case 'set-hook-agent':  return { ...state, hookAgentFilter: action.hookAgentFilter };
    case 'set-hook-status': return { ...state, hookStatusFilter: action.hookStatusFilter };
    case 'select-hook':     return { ...state, selectedHookId: action.hookId };
    case 'set-hook-form':   return { ...state, showHookForm: action.showHookForm };
    case 'toggle-event': {
      const collapsedEvents = { ...state.collapsedEvents, [action.eventId]: !state.collapsedEvents[action.eventId] };
      return { ...state, collapsedEvents };
    }
    case 'toggle-hook': {
      const hooks = state.hooks.map((h) => h.id === action.hookId
        ? { ...h, enabled: { ...h.enabled, [state.workspace]: action.value } } : h);
      return { ...state, hooks };
    }
    case 'set-hook-scope': {
      const hooks = state.hooks.map((h) => h.id === action.hookId
        ? { ...h, enabled: { ...h.enabled, [action.ws]: action.value } } : h);
      return { ...state, hooks };
    }
    case 'add-hook-scope': {
      const hooks = state.hooks.map((h) => h.id === action.hookId
        ? { ...h, scopes: { ...h.scopes, [action.ws]: true }, enabled: { ...h.enabled, [action.ws]: true } } : h);
      return { ...state, hooks };
    }
    case 'rescan': {
      // simulate
      setTimeout(() => action.done && action.done(), 1800);
      return { ...state, scanning: true };
    }
    case 'rescan-done': return { ...state, scanning: false };
    case 'show-onboarding': return { ...state, showOnboarding: true };
    case 'finish-onboarding': return { ...state, showOnboarding: false };
    default: return state;
  }
}

function App() {
  const [t, setTweak] = useTweaks(TWEAK_DEFAULTS);
  const [state, dispatch] = React.useReducer(reducer, initialState);

  // apply accent
  React.useEffect(() => {
    const a = ACCENTS[t.accent] || ACCENTS.violet;
    document.documentElement.style.setProperty('--accent', a.primary);
    document.documentElement.style.setProperty('--accent-soft', a.soft);
  }, [t.accent]);

  // theme class
  React.useEffect(() => {
    document.documentElement.classList.toggle('theme-light', t.theme === 'light');
    document.documentElement.classList.toggle('theme-dark', t.theme !== 'light');
  }, [t.theme]);

  // density attr
  React.useEffect(() => {
    document.documentElement.dataset.density = t.density;
  }, [t.density]);

  // rescan effect
  React.useEffect(() => {
    if (!state.scanning) return;
    const id = setTimeout(() => dispatch({ type: 'rescan-done' }), 1800);
    return () => clearTimeout(id);
  }, [state.scanning]);

  // outside-click for workspace menu
  React.useEffect(() => {
    if (!state.wsMenuOpen) return;
    const f = (e) => {
      if (!e.target.closest('.ws-picker')) dispatch({ type: 'toggle-ws-menu' });
    };
    setTimeout(() => document.addEventListener('mousedown', f), 0);
    return () => document.removeEventListener('mousedown', f);
  }, [state.wsMenuOpen]);

  const ws = state.workspaces.find((w) => w.id === state.workspace);
  const screenLabels = {
    'library': 'Library',
    'item-detail': 'Library',
    'marketplace': 'Marketplace',
    'marketplace-settings': 'Sources',
    'groups': 'Groups',
    'agents': 'Agents',
    'hooks': 'Hooks',
  };

  return (
    <div className="app-root">
      <div className="mac-window"
           style={{
             width: '94vw', height: '92vh', maxWidth: 1440, maxHeight: 940,
             gridTemplateColumns: (t.sidebarLayout === 'compact' ? '180px' : t.sidebarLayout === 'wide' ? '260px' : '224px') + ' 1fr',
           }}
           data-screen-label={screenLabels[state.screen] || state.screen}>

        {/* titlebar spans both columns */}
        <div className="titlebar" style={{ gridTemplateColumns: (t.sidebarLayout === 'compact' ? '180px' : t.sidebarLayout === 'wide' ? '260px' : '224px') + ' 1fr' }}>
          <div className="tl-row">
            <span className="tl c" /><span className="tl m" /><span className="tl x" />
          </div>
          <div className="title-center">
            <span className="crumb head">AgentToolKit</span>
            <span className="sep">/</span>
            <span className="crumb">{ws.name}</span>
            <span className="sep">/</span>
            <span className="crumb">{screenLabels[state.screen] || state.screen}</span>
            {state.openItemId && state.screen === 'item-detail' && (
              <>
                <span className="sep">/</span>
                <span className="crumb">{state.items.find((i) => i.id === state.openItemId)?.name}</span>
              </>
            )}
            <div className="right">
              <Btn ghost sm onClick={() => dispatch({ type: 'show-onboarding' })} title="Show onboarding">
                <Icons.info size={12} />
              </Btn>
              <Btn ghost sm onClick={() => dispatch({ type: 'nav', screen: 'agents' })} title="Agents">
                <Icons.cube size={12} />
              </Btn>
              <div className="scope-chip">
                <span className={ws.scope === 'global' ? 'dot ok' : 'dot mcp'} />
                {ws.scope === 'global' ? 'global scope' : 'project scope'}
              </div>
            </div>
          </div>
        </div>

        {/* sidebar */}
        <Sidebar state={state} dispatch={dispatch} />

        {/* main content + status bar */}
        <div style={{ display: 'flex', flexDirection: 'column', height: '100%', minHeight: 0, overflow: 'hidden' }}>
          <div style={{ flex: 1, overflow: 'hidden', display: 'flex', flexDirection: 'column' }}>
            {state.screen === 'library'              && <Library state={state} dispatch={dispatch} />}
            {state.screen === 'item-detail'          && <ItemDetail state={state} dispatch={dispatch} />}
            {state.screen === 'marketplace'          && <Marketplace state={state} dispatch={dispatch} />}
            {state.screen === 'marketplace-settings' && <MarketplaceSettings state={state} dispatch={dispatch} />}
            {state.screen === 'groups'               && <GroupsScreen state={state} dispatch={dispatch} />}
            {state.screen === 'agents'               && <AgentsScreen state={state} dispatch={dispatch} />}
            {state.screen === 'hooks'                && <HooksScreen state={state} dispatch={dispatch} />}
          </div>
          <StatusBar state={state} />
        </div>

        {/* onboarding modal */}
        {state.showOnboarding && (
          <div className="scrim" onClick={() => dispatch({ type: 'finish-onboarding' })}>
            <div onClick={(e) => e.stopPropagation()}>
              <OnboardingScreen state={state} dispatch={dispatch} />
            </div>
          </div>
        )}
      </div>

      {/* Tweaks */}
      <TweaksPanel title="Tweaks">
        <TweakSection label="Appearance" />
        <TweakRadio label="Theme" value={t.theme}
                    options={['dark', 'light']}
                    onChange={(v) => setTweak('theme', v)} />
        <TweakRadio label="Density" value={t.density}
                    options={['compact', 'regular', 'comfy']}
                    onChange={(v) => setTweak('density', v)} />
        <TweakRadio label="Accent" value={t.accent}
                    options={['violet', 'blue', 'green', 'amber']}
                    onChange={(v) => setTweak('accent', v)} />
        <TweakRadio label="Sidebar" value={t.sidebarLayout}
                    options={['compact', 'default', 'wide']}
                    onChange={(v) => setTweak('sidebarLayout', v)} />

        <TweakSection label="Demo" />
        <TweakButton label="Replay onboarding" secondary
                     onClick={() => dispatch({ type: 'show-onboarding' })} />
        <TweakButton label="Trigger rescan"
                     onClick={() => dispatch({ type: 'rescan' })} />
      </TweaksPanel>
    </div>
  );
}

function StatusBar({ state }) {
  const total = state.items.filter((it) => it.scopes[state.workspace]).length;
  const enabled = state.items.filter((it) => it.scopes[state.workspace] && it.enabled[state.workspace]).length;
  const issues = state.items.filter((it) => it.scopes[state.workspace] && (it.status === 'warn' || it.status === 'err')).length;
  const ws = state.workspaces.find((w) => w.id === state.workspace);

  return (
    <div className="statusbar">
      <span><span className={ws.scope === 'global' ? 'dot ok' : 'dot mcp'} /> {ws.path}</span>
      <span>·</span>
      <span>{enabled}/{total} enabled</span>
      {issues > 0 && <><span>·</span><span style={{ color: 'var(--warn)' }}>{issues} issue{issues > 1 ? 's' : ''}</span></>}
      <div className="right">
        <span>3 agents detected</span>
        <span>·</span>
        <span>auto-sync 2m ago</span>
        <span>·</span>
        <span><span className="dot ok" /> online</span>
      </div>
    </div>
  );
}

ReactDOM.createRoot(document.getElementById('root')).render(<App />);

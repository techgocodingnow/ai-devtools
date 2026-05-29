// AgentToolKit · Hooks management screen
//
// Hooks are user-defined shell commands, HTTP endpoints, or LLM prompts that
// run at specific points in an agent's lifecycle. This screen groups them by
// event, with per-workspace enable + scope toggles like the rest of the app.

const HOOK_TYPE_COLORS = {
  command: 'oklch(0.72 0.13 152)',
  http:    'oklch(0.70 0.13 232)',
  prompt:  'oklch(0.66 0.16 282)',
  agent:   'oklch(0.74 0.13 78)',
};

function HooksScreen({ state, dispatch }) {
  const { hooks, hookEvents, workspace, workspaces, agents, search, hookEventFilter, hookAgentFilter, hookStatusFilter, selectedHookId, showHookForm, collapsedEvents } = state;
  const ws = workspaces.find((w) => w.id === workspace);

  const filtered = hooks.filter((h) => {
    if (!h.scopes[workspace]) return false;
    if (hookEventFilter && h.event !== hookEventFilter) return false;
    if (hookAgentFilter && !h.agents.includes(hookAgentFilter)) return false;
    if (hookStatusFilter === 'enabled' && !h.enabled[workspace]) return false;
    if (hookStatusFilter === 'disabled' && h.enabled[workspace]) return false;
    if (hookStatusFilter === 'untrusted' && h.trusted) return false;
    if (hookStatusFilter === 'issues' && h.status === 'ok') return false;
    if (search) {
      const s = search.toLowerCase();
      if (!h.id.includes(s) && !h.command.toLowerCase().includes(s) && !h.matcher.toLowerCase().includes(s) &&
          !h.description.toLowerCase().includes(s) && !h.event.includes(s)) return false;
    }
    return true;
  });

  // group by event
  const byEvent = {};
  filtered.forEach((h) => { (byEvent[h.event] = byEvent[h.event] || []).push(h); });
  const eventsInOrder = hookEvents.filter((e) => byEvent[e.id]);

  const totalEnabled = filtered.filter((h) => h.enabled[workspace]).length;
  const untrusted = filtered.filter((h) => !h.trusted).length;
  const issues = filtered.filter((h) => h.status === 'err' || h.status === 'warn').length;

  const selected = hooks.find((h) => h.id === selectedHookId);

  return (
    <div style={{ display: 'flex', flexDirection: 'column', height: '100%' }}>
      {/* Toolbar */}
      <div className="toolbar" style={{ borderBottom: 'none', paddingTop: 8, height: 'auto', minHeight: 44, paddingBottom: 4, flexWrap: 'wrap' }}>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 2, minWidth: 0 }}>
          <div style={{ fontSize: 15, fontWeight: 600, whiteSpace: 'nowrap' }}>Hooks</div>
          <div style={{ fontSize: 11, color: 'var(--fg-3)', whiteSpace: 'nowrap' }}>
            {filtered.length} hooks across {eventsInOrder.length} events · {totalEnabled} active in <span style={{ color: 'var(--accent)' }}>{ws.name}</span>
            {untrusted > 0 && <> · <span style={{ color: 'var(--err)' }}>{untrusted} untrusted</span></>}
            {issues > 0 && <> · <span style={{ color: 'var(--warn)' }}>{issues} need attention</span></>}
          </div>
        </div>
        <div className="spacer" />
        <div className="search-wrap" style={{ minWidth: 140, flex: '0 1 200px' }}>
          <Icons.search size={12} />
          <input className="input search" placeholder="Search hooks…" style={{ width: '100%' }}
                 value={search} onChange={(e) => dispatch({ type: 'set-search', search: e.target.value })} />
        </div>
        <div className="seg">
          <div className={'s-btn' + ((hookStatusFilter || 'all') === 'all' ? ' on' : '')}
               onClick={() => dispatch({ type: 'set-hook-status', hookStatusFilter: 'all' })}>All</div>
          <div className={'s-btn' + (hookStatusFilter === 'enabled' ? ' on' : '')}
               onClick={() => dispatch({ type: 'set-hook-status', hookStatusFilter: 'enabled' })}>On</div>
          <div className={'s-btn' + (hookStatusFilter === 'untrusted' ? ' on' : '')}
               onClick={() => dispatch({ type: 'set-hook-status', hookStatusFilter: 'untrusted' })}>
            Untrusted {untrusted > 0 && <span style={{ background: 'var(--err)', color: 'white', borderRadius: 8, padding: '0 5px', fontSize: 10 }}>{untrusted}</span>}
          </div>
          <div className={'s-btn' + (hookStatusFilter === 'issues' ? ' on' : '')}
               onClick={() => dispatch({ type: 'set-hook-status', hookStatusFilter: 'issues' })}>Issues</div>
        </div>
        <div className="seg">
          <div className={'s-btn' + (!hookAgentFilter ? ' on' : '')}
               onClick={() => dispatch({ type: 'set-hook-agent', hookAgentFilter: null })}>All agents</div>
          {agents.map((a) => (
            <div key={a.id} className={'s-btn' + (hookAgentFilter === a.id ? ' on' : '')}
                 onClick={() => dispatch({ type: 'set-hook-agent', hookAgentFilter: a.id })}>
              <span style={{ width: 12, height: 12, borderRadius: 3, background: a.color, color: 'white',
                             display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
                             fontSize: 7, fontWeight: 700, fontFamily: 'var(--font-mono)' }}>{a.initials}</span>
              {a.name.split(' ')[0]}
            </div>
          ))}
        </div>
        <Btn sm onClick={() => dispatch({ type: 'set-hook-form', showHookForm: true })}>
          <Icons.plus size={12} />New hook
        </Btn>
      </div>

      {/* Untrusted banner */}
      {untrusted > 0 && (
        <div style={{ margin: '0 16px 8px', padding: '8px 12px', borderRadius: 8,
                      background: 'oklch(0.66 0.20 25 / 0.12)', border: '0.5px solid oklch(0.66 0.20 25 / 0.4)',
                      display: 'flex', alignItems: 'center', gap: 10, flexShrink: 0 }}>
          <Icons.alert size={14} style={{ color: 'var(--err)' }} />
          <div style={{ flex: 1, fontSize: 11.5 }}>
            <b style={{ color: 'var(--err)' }}>{untrusted} hook{untrusted > 1 ? 's' : ''} from new sources need review</b>
            <span className="muted" style={{ marginLeft: 8 }}>
              Untrusted hooks won't fire until you read the command and approve them.
            </span>
          </div>
          <Btn sm ghost>Review all</Btn>
        </div>
      )}

      {/* Body: list + detail */}
      <div style={{ flex: 1, display: 'grid', gridTemplateColumns: selected ? 'minmax(420px, 1fr) 340px' : '1fr', overflow: 'hidden', minHeight: 0 }}>
        <div style={{ overflow: 'auto', padding: '4px 16px 16px', minHeight: 0 }}>
          {eventsInOrder.map((ev) => (
            <HookEventSection key={ev.id} event={ev} hooks={byEvent[ev.id]} state={state} dispatch={dispatch}
                              collapsed={!!collapsedEvents[ev.id]} agents={agents} />
          ))}
          {filtered.length === 0 && (
            <div style={{ padding: 60, textAlign: 'center', color: 'var(--fg-3)' }}>
              <Icons.zap size={28} style={{ opacity: 0.4 }} />
              <div style={{ marginTop: 14, fontSize: 13 }}>No hooks match your filters.</div>
              <div style={{ marginTop: 4, fontSize: 11.5 }}>Try clearing the search or switch to <b>Global</b> scope.</div>
            </div>
          )}

          {/* Lifecycle map — shows which events are wired up vs. empty */}
          <HookLifecycleMap state={state} dispatch={dispatch} />
        </div>

        {selected && <HookDetailPanel hook={selected} workspaces={workspaces} agents={agents} dispatch={dispatch} />}
      </div>

      {showHookForm && <HookForm state={state} dispatch={dispatch} />}
    </div>
  );
}

function HookEventSection({ event, hooks, state, dispatch, collapsed, agents }) {
  const enabledCount = hooks.filter((h) => h.enabled[state.workspace]).length;
  const cadenceColor = { session: 'oklch(0.66 0.13 282)', turn: 'oklch(0.70 0.13 232)', tool: 'oklch(0.72 0.13 152)', async: 'oklch(0.74 0.13 78)' }[event.cadence];

  return (
    <div style={{ marginTop: 12 }}>
      <div className="section-h" style={{ marginBottom: 6, cursor: 'default', gap: 8 }}
           onClick={() => dispatch({ type: 'toggle-event', eventId: event.id })}>
        <Icons.chev size={10} style={{ transform: collapsed ? 'none' : 'rotate(90deg)', color: 'var(--fg-3)', transition: 'transform 0.12s' }} />
        <h2 style={{ fontFamily: 'var(--font-mono)', fontSize: 12, fontWeight: 600 }}>{event.label}</h2>
        <Pill style={{ borderColor: 'transparent', background: cadenceColor + '22', color: cadenceColor, height: 16 }}>
          {event.cadence}
        </Pill>
        <span className="count">{enabledCount}/{hooks.length} active</span>
        <div className="spacer" />
        <div style={{ display: 'flex', gap: 3 }}>
          {event.agents.map((aid) => {
            const a = agents.find((x) => x.id === aid);
            return <span key={aid} title={a?.name}
                         style={{ width: 14, height: 14, borderRadius: 3, background: a?.color, color: 'white',
                                  display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
                                  fontSize: 7, fontWeight: 700, fontFamily: 'var(--font-mono)' }}>{a?.initials}</span>;
          })}
        </div>
        <span className="muted" style={{ fontSize: 11, maxWidth: 280, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
          {event.desc}
        </span>
      </div>
      {!collapsed && (
        <div style={{ border: '0.5px solid var(--line)', borderRadius: 'var(--radius-lg)', overflow: 'hidden', background: 'var(--bg-panel)' }}>
          {hooks.map((h, i) => (
            <HookRow key={h.id} hook={h} agents={agents} state={state} dispatch={dispatch} last={i === hooks.length - 1} />
          ))}
        </div>
      )}
    </div>
  );
}

function HookRow({ hook, agents, state, dispatch, last }) {
  const enabled = hook.enabled[state.workspace];
  const selected = state.selectedHookId === hook.id;
  const typeColor = HOOK_TYPE_COLORS[hook.type];
  return (
    <div onClick={() => dispatch({ type: 'select-hook', hookId: hook.id })}
         style={{
           display: 'grid',
           gridTemplateColumns: '28px minmax(80px, 150px) minmax(180px, 1fr) 78px 90px 76px 28px',
           gap: 10, alignItems: 'center',
           padding: '8px 12px',
           borderBottom: last ? 'none' : '0.5px solid var(--line-soft)',
           background: selected ? 'var(--accent-soft)' : 'transparent',
           cursor: 'default', fontSize: 11.5,
         }}>
      <Switch sm value={enabled} onChange={(v) => dispatch({ type: 'toggle-hook', hookId: hook.id, value: v })} />

      {/* matcher */}
      <div style={{ display: 'flex', alignItems: 'center', gap: 6, minWidth: 0 }}>
        <span style={{ width: 4, height: 4, borderRadius: '50%', background: typeColor, flexShrink: 0 }} />
        <span className="mono" style={{ color: 'var(--fg-2)', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
          {hook.matcher === '*' ? <span className="muted">any tool</span> : hook.matcher}
        </span>
      </div>

      {/* command preview */}
      <div style={{ display: 'flex', flexDirection: 'column', minWidth: 0, gap: 2 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
          {!hook.trusted && <span title="Untrusted source"><Icons.shield size={11} style={{ color: 'var(--err)' }} /></span>}
          {hook.status === 'warn' && <Icons.alert size={11} style={{ color: 'var(--warn)' }} />}
          {hook.status === 'err' && <Icons.alert size={11} style={{ color: 'var(--err)' }} />}
          <span className="mono" style={{ color: enabled ? 'var(--fg)' : 'var(--fg-3)', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis', fontSize: 11 }}>
            {hook.command}
          </span>
        </div>
        <div className="muted" style={{ fontSize: 10.5, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
          {hook.id}
          {hook.source !== 'user' && <> · from <span style={{ color: 'var(--accent)' }}>{hook.source}</span></>}
        </div>
      </div>

      {/* type */}
      <span className="mono" style={{ color: typeColor, fontSize: 10.5, textTransform: 'uppercase', letterSpacing: '0.04em' }}>
        {hook.type}{hook.async && '·async'}
      </span>

      {/* agent compat */}
      <div style={{ display: 'flex', gap: 2 }}>
        {hook.agents.map((aid) => {
          const a = agents.find((x) => x.id === aid);
          return <span key={aid} title={a?.name}
                       style={{ width: 16, height: 16, borderRadius: 3, background: a?.color, color: 'white',
                                display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
                                fontSize: 8, fontWeight: 700, fontFamily: 'var(--font-mono)' }}>{a?.initials}</span>;
        })}
      </div>

      {/* last fired + rate */}
      <div style={{ display: 'flex', flexDirection: 'column', gap: 1, fontSize: 10.5, color: 'var(--fg-3)', textAlign: 'right' }}>
        <span>{hook.lastFired}</span>
        <span className="mono" style={{ fontSize: 9.5, color: 'var(--fg-4)' }}>{hook.firesPerHour}/h</span>
      </div>

      <Btn ghost sm icon onClick={(e) => { e.stopPropagation(); }} title="More"><Icons.more size={12} /></Btn>
    </div>
  );
}

function HookDetailPanel({ hook, workspaces, agents, dispatch }) {
  const typeColor = HOOK_TYPE_COLORS[hook.type];
  return (
    <div className="detail-side" style={{ borderLeft: '0.5px solid var(--line)' }}>
      <div className="row" style={{ marginBottom: 12, gap: 8 }}>
        <Icons.zap size={14} style={{ color: typeColor }} />
        <span className="mono" style={{ fontWeight: 600, fontSize: 12.5 }}>{hook.id}</span>
        <div className="spacer" />
        <Btn ghost sm icon onClick={() => dispatch({ type: 'select-hook', hookId: null })}><Icons.x size={12} /></Btn>
      </div>

      <p style={{ margin: '0 0 14px', fontSize: 12, color: 'var(--fg-2)', lineHeight: 1.5 }}>{hook.description}</p>

      {hook.warning && (
        <div style={{ padding: '8px 10px', borderRadius: 6, marginBottom: 12,
                      background: hook.trusted ? 'oklch(0.78 0.14 78 / 0.15)' : 'oklch(0.66 0.20 25 / 0.15)',
                      border: '0.5px solid ' + (hook.trusted ? 'oklch(0.78 0.14 78 / 0.4)' : 'oklch(0.66 0.20 25 / 0.4)'),
                      fontSize: 11.5, color: hook.trusted ? 'var(--warn)' : 'var(--err)',
                      display: 'flex', gap: 8, alignItems: 'flex-start' }}>
          <Icons.alert size={12} />
          <div style={{ flex: 1 }}>{hook.warning}</div>
        </div>
      )}

      {!hook.trusted && (
        <div className="card" style={{ padding: 12, marginBottom: 12, borderColor: 'oklch(0.66 0.20 25 / 0.4)', background: 'oklch(0.66 0.20 25 / 0.06)' }}>
          <div className="row" style={{ marginBottom: 8 }}>
            <Icons.shield size={13} style={{ color: 'var(--err)' }} />
            <b style={{ fontSize: 12 }}>Untrusted source</b>
          </div>
          <p style={{ margin: '0 0 10px', fontSize: 11.5, color: 'var(--fg-2)', lineHeight: 1.5 }}>
            This hook was added by <span className="mono">{hook.source}</span> and hasn't been reviewed yet.
            Read the command, then trust to allow it to fire.
          </p>
          <div className="row" style={{ gap: 6 }}>
            <Btn primary sm><Icons.shieldOk size={12} />Trust hook</Btn>
            <Btn ghost sm danger>Block</Btn>
          </div>
        </div>
      )}

      <div className="subtitle" style={{ marginBottom: 6 }}>Configuration</div>
      <dl style={{ marginBottom: 14 }}>
        <dt>Event</dt>     <dd className="mono">{hook.event}</dd>
        <dt>Matcher</dt>   <dd className="mono">{hook.matcher}</dd>
        <dt>Type</dt>      <dd className="mono" style={{ color: typeColor }}>{hook.type}{hook.async && ' (async)'}</dd>
        <dt>Timeout</dt>   <dd className="mono">{(hook.timeout / 1000).toFixed(1)} s</dd>
        <dt>Source</dt>    <dd>{hook.source}</dd>
        <dt>Last fired</dt><dd>{hook.lastFired}</dd>
        <dt>Rate</dt>      <dd className="mono">{hook.firesPerHour} / hour</dd>
      </dl>

      <div className="subtitle" style={{ marginBottom: 6 }}>Command</div>
      <pre className="code" style={{ fontSize: 11, marginBottom: 14, whiteSpace: 'pre-wrap', wordBreak: 'break-all' }}>{hook.command}</pre>

      <div className="subtitle" style={{ marginBottom: 6 }}>Scopes</div>
      <div className="col" style={{ gap: 1, marginBottom: 14 }}>
        {workspaces.map((w) => (
          <div key={w.id} className="row" style={{ padding: '5px 8px', borderRadius: 5, background: hook.scopes[w.id] ? 'var(--bg-elev)' : 'transparent' }}>
            <div className={'ws-ico' + (w.scope === 'global' ? ' global' : '')}
                 style={{ width: 16, height: 16, fontSize: 9, borderRadius: 4, ...(w.color ? { background: `linear-gradient(135deg, ${w.color}, oklch(0.45 0.06 ${100 + w.id.length * 30}))` } : {}) }}>
              {w.initials}
            </div>
            <span style={{ fontSize: 11.5, color: hook.scopes[w.id] ? 'var(--fg)' : 'var(--fg-3)' }}>{w.name}</span>
            <span className="spacer" />
            {hook.scopes[w.id]
              ? <Switch sm value={hook.enabled[w.id]} onChange={(v) => dispatch({ type: 'set-hook-scope', hookId: hook.id, ws: w.id, value: v })} />
              : <Btn ghost sm icon onClick={() => dispatch({ type: 'add-hook-scope', hookId: hook.id, ws: w.id })}><Icons.plus size={11} /></Btn>}
          </div>
        ))}
      </div>

      <div className="subtitle" style={{ marginBottom: 6 }}>Recent invocations</div>
      <div className="card" style={{ padding: 0, overflow: 'hidden', marginBottom: 14 }}>
        {[
          { t: '14s ago', dur: '42ms',  exit: 0, mtx: 'Edit' },
          { t: '38s ago', dur: '38ms',  exit: 0, mtx: 'Edit' },
          { t: '1m ago',  dur: '51ms',  exit: 0, mtx: 'Write' },
          { t: '3m ago',  dur: '120ms', exit: hook.status === 'err' ? 2 : 0, mtx: 'Edit' },
        ].map((i, idx, arr) => (
          <div key={idx} className="row" style={{ padding: '6px 10px', borderBottom: idx < arr.length - 1 ? '0.5px solid var(--line-soft)' : 'none', fontSize: 11 }}>
            <span className={'dot ' + (i.exit === 0 ? 'ok' : 'err')} />
            <span className="mono" style={{ minWidth: 50 }}>{i.mtx}</span>
            <span className="spacer" />
            <span className="muted">{i.dur}</span>
            <span className="muted">·</span>
            <span className="muted">{i.t}</span>
          </div>
        ))}
      </div>

      <div className="row" style={{ gap: 6 }}>
        <Btn ghost sm><Icons.edit size={12} />Edit</Btn>
        <Btn ghost sm><Icons.copy size={12} />Duplicate</Btn>
        <Btn ghost sm><Icons.terminal size={12} />Test run</Btn>
        <div className="spacer" />
        <Btn ghost sm danger><Icons.trash size={12} /></Btn>
      </div>
    </div>
  );
}

// Lifecycle map — shows every supported event and how many hooks fire on it.
// Quick visual to spot un-instrumented events.
function HookLifecycleMap({ state, dispatch }) {
  const { hooks, hookEvents, workspace, agents } = state;
  return (
    <div style={{ marginTop: 24 }}>
      <div className="section-h">
        <Icons.workspace size={12} />
        <h2>Agent lifecycle</h2>
        <span className="count">{hookEvents.length} events supported</span>
        <div className="spacer" />
        <span className="muted" style={{ fontSize: 11 }}>Click any event to filter — empty events have no hooks wired up.</span>
      </div>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(160px, 1fr))', gap: 6 }}>
        {hookEvents.map((ev) => {
          const list = hooks.filter((h) => h.event === ev.id && h.scopes[workspace] && h.enabled[workspace]);
          const cadenceColor = { session: 'oklch(0.66 0.13 282)', turn: 'oklch(0.70 0.13 232)', tool: 'oklch(0.72 0.13 152)', async: 'oklch(0.74 0.13 78)' }[ev.cadence];
          const empty = list.length === 0;
          return (
            <div key={ev.id} className="card hover" style={{
              padding: 10, gap: 4, display: 'flex', flexDirection: 'column',
              opacity: empty ? 0.55 : 1, borderColor: empty ? 'var(--line-soft)' : 'var(--line)',
            }}
            onClick={() => dispatch({ type: 'set-hook-event', hookEventFilter: ev.id })}>
              <div className="row" style={{ gap: 6 }}>
                <span style={{ width: 5, height: 5, borderRadius: '50%', background: cadenceColor }} />
                <span className="mono" style={{ fontSize: 11, fontWeight: 500 }}>{ev.label}</span>
                <div className="spacer" />
                <span style={{ fontSize: 11, fontWeight: 600, color: empty ? 'var(--fg-4)' : 'var(--fg)' }}>{list.length}</span>
              </div>
              <div className="row" style={{ gap: 3 }}>
                {ev.agents.map((aid) => {
                  const a = agents.find((x) => x.id === aid);
                  return <span key={aid} title={a?.name}
                               style={{ width: 12, height: 12, borderRadius: 3, background: a?.color, color: 'white',
                                        display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
                                        fontSize: 7, fontWeight: 700, fontFamily: 'var(--font-mono)' }}>{a?.initials}</span>;
                })}
                <div className="spacer" />
                <span className="muted" style={{ fontSize: 9.5, textTransform: 'uppercase', letterSpacing: '0.05em' }}>{ev.cadence}</span>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}

function HookForm({ state, dispatch }) {
  const [eventId, setEventId] = React.useState('post_tool');
  const [matcher, setMatcher] = React.useState('Edit|Write');
  const [type, setType] = React.useState('command');
  const [command, setCommand] = React.useState('');
  const [timeout, setTimeout_] = React.useState(5000);
  const [isAsync, setAsync] = React.useState(false);
  const ev = state.hookEvents.find((e) => e.id === eventId);

  return (
    <div className="scrim" onClick={() => dispatch({ type: 'set-hook-form', showHookForm: false })}>
      <div className="modal" style={{ width: 580 }} onClick={(e) => e.stopPropagation()}>
        <div className="modal-h">
          <Icons.zap size={14} style={{ color: 'var(--accent)' }} />
          <h3>New hook</h3>
          <div className="spacer" />
          <Btn ghost sm icon onClick={() => dispatch({ type: 'set-hook-form', showHookForm: false })}><Icons.x size={12} /></Btn>
        </div>
        <div className="modal-body">
          <div>
            <div className="subtitle" style={{ marginBottom: 6, fontSize: 10 }}>Event</div>
            <select className="input" style={{ width: '100%', height: 32, fontFamily: 'var(--font-mono)' }}
                    value={eventId} onChange={(e) => setEventId(e.target.value)}>
              {state.hookEvents.map((e) => (
                <option key={e.id} value={e.id}>{e.label} — {e.desc}</option>
              ))}
            </select>
            <div style={{ marginTop: 6, fontSize: 11, color: 'var(--fg-3)' }}>
              Supported by: {ev?.agents.map((aid) => state.agents.find((a) => a.id === aid)?.name).join(', ')} · cadence: <span className="mono">{ev?.cadence}</span>
            </div>
          </div>

          <div className="row" style={{ gap: 10, alignItems: 'flex-start' }}>
            <div style={{ flex: 1 }}>
              <div className="subtitle" style={{ marginBottom: 6, fontSize: 10 }}>Matcher (regex on tool name)</div>
              <input className="input" style={{ width: '100%', height: 32, fontFamily: 'var(--font-mono)' }}
                     value={matcher} onChange={(e) => setMatcher(e.target.value)}
                     placeholder='e.g. "Bash" or "Edit|Write|MultiEdit", * for all' />
              <div style={{ marginTop: 6, fontSize: 11, color: 'var(--fg-3)' }}>
                Common matchers: <span className="mono">Bash · Edit · Write · MultiEdit · Read · WebFetch · *</span>
              </div>
            </div>
            <div style={{ width: 140 }}>
              <div className="subtitle" style={{ marginBottom: 6, fontSize: 10 }}>Type</div>
              <select className="input" style={{ width: '100%', height: 32 }} value={type} onChange={(e) => setType(e.target.value)}>
                <option value="command">command</option>
                <option value="http">http</option>
                <option value="prompt">prompt</option>
                <option value="agent">agent</option>
              </select>
            </div>
          </div>

          <div>
            <div className="subtitle" style={{ marginBottom: 6, fontSize: 10 }}>{type === 'http' ? 'Endpoint URL' : type === 'prompt' || type === 'agent' ? 'Prompt' : 'Shell command'}</div>
            <textarea className="input" style={{ width: '100%', minHeight: 64, padding: '8px 10px', fontFamily: 'var(--font-mono)', resize: 'vertical' }}
                      value={command} onChange={(e) => setCommand(e.target.value)}
                      placeholder={type === 'http' ? 'http://localhost:8080/hooks/...' : 'npx prettier --write "$CLAUDE_TOOL_INPUT_FILE_PATH"'} />
            <div style={{ marginTop: 6, fontSize: 11, color: 'var(--fg-3)' }}>
              JSON event payload arrives on stdin. Exit code 2 blocks the action.
            </div>
          </div>

          <div className="row" style={{ gap: 12 }}>
            <div style={{ flex: 1 }}>
              <div className="subtitle" style={{ marginBottom: 6, fontSize: 10 }}>Timeout</div>
              <div className="row" style={{ gap: 6 }}>
                <input type="number" className="input" style={{ width: 90, height: 32 }} value={timeout} step={500} min={500} onChange={(e) => setTimeout_(Number(e.target.value))} />
                <span className="muted">ms</span>
              </div>
            </div>
            <div style={{ flex: 1 }}>
              <div className="subtitle" style={{ marginBottom: 6, fontSize: 10 }}>Run mode</div>
              <div className="row" style={{ gap: 8 }}>
                <Switch value={isAsync} onChange={setAsync} />
                <span style={{ fontSize: 12 }}>Run async (don't block the loop)</span>
              </div>
            </div>
          </div>

          <div className="card" style={{ padding: 10, marginTop: 4, background: 'var(--bg-panel)' }}>
            <div className="subtitle" style={{ marginBottom: 6, fontSize: 10 }}>Preview · <span className="mono" style={{ textTransform: 'none' }}>~/.claude/settings.json</span></div>
            <pre className="code" style={{ fontSize: 11, padding: 10, background: 'var(--bg-window)' }}>{`{
  `}<span className="k">"hooks"</span>{`: {
    `}<span className="k">{`"${ev?.label}"`}</span>{`: [{
      `}<span className="k">"matcher"</span>{`: `}<span className="s">{`"${matcher}"`}</span>{`,
      `}<span className="k">"hooks"</span>{`: [{
        `}<span className="k">"type"</span>{`: `}<span className="s">{`"${type}"`}</span>{`,
        `}<span className="k">"command"</span>{`: `}<span className="s">{`"${command || '…'}"`}</span>{`,
        `}<span className="k">"timeout"</span>{`: `}<span className="n">{timeout}</span>{isAsync ? `,
        ` : ''}{isAsync && <><span className="k">"async"</span>{`: `}<span className="n">true</span></>}{`
      }]
    }]
  }
}`}</pre>
          </div>
        </div>
        <div className="modal-foot">
          <Btn ghost sm onClick={() => dispatch({ type: 'set-hook-form', showHookForm: false })}>Cancel</Btn>
          <Btn primary sm><Icons.check size={12} />Add hook</Btn>
        </div>
      </div>
    </div>
  );
}

window.HooksScreen = HooksScreen;

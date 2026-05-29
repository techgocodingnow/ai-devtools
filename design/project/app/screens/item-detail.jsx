// AgentToolKit · Item Detail screen

function ItemDetail({ state, dispatch }) {
  const { items, workspaces, agents, groups, openItemId, detailTab } = state;
  const item = items.find((it) => it.id === openItemId);
  if (!item) return null;
  const group = groups.find((g) => g.id === item.group);

  const tabs = [
    { id: 'overview',     label: 'Overview' },
    { id: 'config',       label: 'Configuration' },
    { id: 'permissions',  label: 'Permissions' },
    { id: 'logs',         label: 'Activity' },
    { id: 'source',       label: 'Source' },
  ];

  return (
    <div style={{ display: 'flex', flexDirection: 'column', height: '100%' }}>
      <div className="toolbar">
        <Btn ghost sm onClick={() => dispatch({ type: 'nav', screen: 'library' })}><Icons.chev size={12} style={{ transform: 'rotate(180deg)' }} />Library</Btn>
        <div style={{ width: 0.5, height: 16, background: 'var(--line)' }} />
        <ItemGlyph item={item} size={22} />
        <div style={{ fontWeight: 600, fontSize: 13 }}>{item.name}</div>
        <span className="mono muted">v{item.version}</span>
        <Pill kind={item.kind}>{item.kind}</Pill>
        {item.status !== 'ok' && (
          <Pill style={{ background: item.status === 'err' ? 'oklch(0.66 0.20 25 / 0.18)' : 'oklch(0.78 0.14 78 / 0.18)',
                        color: item.status === 'err' ? 'var(--err)' : 'var(--warn)', borderColor: 'transparent' }}>
            <Icons.alert size={10} />{item.warning || 'Needs attention'}
          </Pill>
        )}
        <div className="spacer" />
        <Btn sm ghost><Icons.refresh size={12} />Check for updates</Btn>
        <Btn sm><Icons.edit size={12} />Edit</Btn>
        <Btn sm danger><Icons.trash size={12} />Remove…</Btn>
      </div>

      <div className="detail-grid" style={{ flex: 1, overflow: 'hidden' }}>
        <div className="detail-main">
          <div className="tabs" style={{ marginBottom: 14 }}>
            {tabs.map((t) => (
              <div key={t.id} className={'tab' + (detailTab === t.id ? ' active' : '')}
                   onClick={() => dispatch({ type: 'set-detail-tab', detailTab: t.id })}>
                {t.label}
              </div>
            ))}
          </div>

          {detailTab === 'overview'    && <OverviewTab item={item} group={group} />}
          {detailTab === 'config'      && <ConfigTab item={item} />}
          {detailTab === 'permissions' && <PermissionsTab item={item} />}
          {detailTab === 'logs'        && <LogsTab item={item} />}
          {detailTab === 'source'      && <SourceTab item={item} />}
        </div>

        <ItemDetailSide item={item} workspaces={workspaces} agents={agents} dispatch={dispatch} />
      </div>
    </div>
  );
}

function OverviewTab({ item, group }) {
  const desc = item.description
    || ({
        skill: 'A reusable agent instruction set — prompts, tools and helpers — packaged as a folder under SKILLS/.',
        plugin: 'A locally-installed plugin that extends the agent with custom commands, tool implementations or pre/post hooks.',
        mcp: 'An MCP server that exposes an external service to the agent over the Model Context Protocol.',
    }[item.kind]);

  return (
    <div className="col" style={{ gap: 14 }}>
      <p style={{ margin: 0, fontSize: 13, lineHeight: 1.55, color: 'var(--fg-2)' }}>{desc}</p>

      <div className="row" style={{ gap: 8, flexWrap: 'wrap' }}>
        {group && <Pill><span className="dot" style={{ background: group.color }} />{group.name}</Pill>}
        <Pill><Icons.shieldOk size={10} /> Signed by {item.vendor}</Pill>
        <Pill>Updated {item.updated}</Pill>
        {item.size !== '—' && <Pill>{item.size}</Pill>}
      </div>

      <div>
        <div className="subtitle" style={{ marginBottom: 6 }}>Capabilities</div>
        <div className="col" style={{ gap: 4 }}>
          {(item.kind === 'mcp' ? CONN_CAPS : item.kind === 'skill' ? SKILL_CAPS : PLUGIN_CAPS).map((c, i) => (
            <div key={i} className="row" style={{ gap: 8, fontSize: 12, color: 'var(--fg-2)' }}>
              <Icons.check size={12} style={{ color: 'var(--ok)' }} />
              <span style={{ fontFamily: 'var(--font-mono)', fontSize: 11 }}>{c.name}</span>
              <span className="muted">{c.desc}</span>
            </div>
          ))}
        </div>
      </div>

      <div>
        <div className="subtitle" style={{ marginBottom: 6 }}>Files</div>
        <div className="card" style={{ padding: 0, overflow: 'hidden' }}>
          {FILES.map((f, i) => (
            <div key={i} className="row" style={{ padding: '6px 12px', borderBottom: i < FILES.length - 1 ? '0.5px solid var(--line-soft)' : 'none', fontSize: 11.5 }}>
              <Icons.box size={11} className="muted" />
              <span className="mono">{f.path}</span>
              <span className="spacer" />
              <span className="muted">{f.size}</span>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

const SKILL_CAPS = [
  { name: 'instruction.md', desc: 'core prompt loaded when skill is invoked' },
  { name: 'tools.json', desc: 'declares helper tools the skill defines' },
  { name: 'examples/*', desc: 'reference examples seeded into agent context' },
];
const PLUGIN_CAPS = [
  { name: 'manifest.json', desc: 'declares commands + hook surface area' },
  { name: 'pre-tool-use', desc: 'hooks before tool invocations' },
  { name: 'commands.*', desc: 'registers /commands in the agent CLI' },
];
const CONN_CAPS = [
  { name: 'mcp.stdio', desc: 'spawns server via stdio transport' },
  { name: 'auth.oauth2', desc: 'requires OAuth handshake on first use' },
  { name: 'tools', desc: '12 callable tools exposed over MCP' },
];
const FILES = [
  { path: 'manifest.json', size: '482 B' },
  { path: 'instruction.md', size: '4.2 KB' },
  { path: 'tools/read.py',  size: '1.1 KB' },
  { path: 'tools/parse.py', size: '3.4 KB' },
  { path: 'examples/sample.pdf', size: '128 KB' },
];

function ConfigTab({ item }) {
  return (
    <div className="col" style={{ gap: 14 }}>
      <div className="card" style={{ padding: 0, overflow: 'hidden' }}>
        <div className="row" style={{ padding: '10px 14px', borderBottom: '0.5px solid var(--line-soft)' }}>
          <Icons.cog size={12} className="muted" />
          <span style={{ fontWeight: 600, fontSize: 12 }}>config.json</span>
          <span className="spacer" />
          <Btn ghost sm><Icons.copy size={12} /></Btn>
          <Btn ghost sm><Icons.edit size={12} />Edit</Btn>
        </div>
        <pre className="code" style={{ border: 'none', borderRadius: 0, padding: '12px 16px' }}>
{`{
  `}<span className="k">"name"</span>{`: `}<span className="s">{`"${item.name}"`}</span>{`,
  `}<span className="k">"version"</span>{`: `}<span className="s">{`"${item.version}"`}</span>{`,
  `}<span className="k">"agents"</span>{`: [${item.agents.map((a) => `"${a}"`).join(', ')}],
  `}<span className="k">"timeout_ms"</span>{`: `}<span className="n">30000</span>{`,
  `}<span className="k">"max_concurrent"</span>{`: `}<span className="n">3</span>{`,
  `}<span className="c">{`// Edit this file directly in the editor`}</span>{`
  `}<span className="k">"options"</span>{`: {
    `}<span className="k">"verbose"</span>{`: `}<span className="n">false</span>{`,
    `}<span className="k">"telemetry"</span>{`: `}<span className="n">true</span>{`
  }
}`}
        </pre>
      </div>

      <div>
        <div className="subtitle" style={{ marginBottom: 8 }}>Environment</div>
        <div className="col" style={{ gap: 6 }}>
          {[['LOG_LEVEL', 'info'], ['MAX_TOKENS', '8192'], ['CACHE_DIR', '~/.cache/agent/' + item.id]].map(([k, v]) => (
            <div key={k} className="row" style={{ fontSize: 11.5 }}>
              <span className="mono" style={{ color: 'var(--fg-3)', width: 130 }}>{k}</span>
              <span className="mono">{v}</span>
              <span className="spacer" />
              <Btn ghost sm icon><Icons.edit size={11} /></Btn>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

function PermissionsTab({ item }) {
  const perms = [
    { area: 'Filesystem',  scope: 'Read-only',        paths: ['./*', '~/.cache'], ok: true },
    { area: 'Network',     scope: 'Outbound HTTPS',   paths: ['api.' + item.id + '.com'], ok: true },
    { area: 'Shell',       scope: 'Denied',           paths: [], ok: true },
    { area: 'Secrets',     scope: '1 secret',         paths: ['ATK_' + item.id.toUpperCase().replace(/-/g, '_') + '_TOKEN'], ok: true },
  ];
  return (
    <div className="col" style={{ gap: 10 }}>
      {perms.map((p) => (
        <div key={p.area} className="card" style={{ padding: 12 }}>
          <div className="row">
            <Icons.shield size={13} style={{ color: p.scope === 'Denied' ? 'var(--fg-3)' : 'var(--accent)' }} />
            <div style={{ fontWeight: 600, fontSize: 12.5 }}>{p.area}</div>
            <span className="spacer" />
            <Pill>{p.scope}</Pill>
          </div>
          {p.paths.length > 0 && (
            <div className="col" style={{ marginTop: 8, gap: 2 }}>
              {p.paths.map((path, i) => (
                <span key={i} className="mono muted" style={{ fontSize: 11 }}>{path}</span>
              ))}
            </div>
          )}
        </div>
      ))}
    </div>
  );
}

function LogsTab({ item }) {
  const logs = [
    { t: '13:42:08', lvl: 'info',  msg: 'tool.invoke parse_pdf(input.pdf) → 12 pages' },
    { t: '13:42:06', lvl: 'info',  msg: 'tool.invoke read_pdf(input.pdf) → 482 KB' },
    { t: '13:39:51', lvl: 'warn',  msg: 'cache miss for ' + item.id + '/result-2a4f, refetching' },
    { t: '13:38:14', lvl: 'info',  msg: 'loaded skill ' + item.id + ' v' + item.version + ' (142 KB)' },
    { t: '11:02:33', lvl: 'error', msg: 'request timed out after 30000ms (host: api.local)' },
    { t: 'Yest 18:22', lvl: 'info',  msg: 'enabled in workspace mcp-tooling' },
  ];
  return (
    <pre className="code" style={{ padding: 14, fontSize: 11.5, lineHeight: 1.75 }}>
      {logs.map((l, i) => (
        <div key={i}>
          <span className="c">[{l.t}]</span>{' '}
          <span style={{ color: l.lvl === 'error' ? 'var(--err)' : l.lvl === 'warn' ? 'var(--warn)' : 'oklch(0.74 0.13 290)' }}>
            {l.lvl.padEnd(5, ' ')}
          </span>{' '}
          <span style={{ color: 'var(--fg-2)' }}>{l.msg}</span>
        </div>
      ))}
    </pre>
  );
}

function SourceTab({ item }) {
  return (
    <div className="col" style={{ gap: 14 }}>
      <div className="card" style={{ padding: 14 }}>
        <div className="subtitle" style={{ marginBottom: 8 }}>Installed from</div>
        <div className="row">
          <Icons.shop size={14} className="muted" />
          <span style={{ fontWeight: 600, fontSize: 12.5 }}>
            {item.vendor.startsWith('community') ? 'Community Hub' : item.vendor.startsWith('kuro') ? 'kuro/tools' : 'Anthropic Official'}
          </span>
          <Pill accent>{item.vendor.startsWith('community') ? 'community' : 'verified'}</Pill>
        </div>
        <div className="mono muted" style={{ marginTop: 8, fontSize: 11 }}>
          https://hub.agenttools.dev/{item.vendor}/{item.id}
        </div>
      </div>
      <div className="card" style={{ padding: 14 }}>
        <div className="subtitle" style={{ marginBottom: 8 }}>Local install path</div>
        <div className="mono" style={{ fontSize: 11.5, color: 'var(--fg)' }}>
          ~/.agent/{item.kind === 'skill' ? 'skills' : item.kind === 'plugin' ? 'plugins' : 'mcp'}/{item.id}/
        </div>
      </div>
    </div>
  );
}

function ItemDetailSide({ item, workspaces, agents, dispatch }) {
  return (
    <div className="detail-side">
      <div className="subtitle" style={{ marginBottom: 8 }}>Scopes</div>
      <div className="col" style={{ gap: 1, marginBottom: 14 }}>
        {workspaces.map((w) => (
          <div key={w.id} className="row" style={{ padding: '5px 8px', borderRadius: 5, background: item.scopes[w.id] ? 'var(--bg-elev)' : 'transparent' }}>
            <div className={'ws-ico' + (w.scope === 'global' ? ' global' : '')}
                 style={{ width: 16, height: 16, fontSize: 9, borderRadius: 4, ...(w.color ? { background: `linear-gradient(135deg, ${w.color}, oklch(0.45 0.06 ${100 + w.id.length * 30}))` } : {}) }}>
              {w.initials}
            </div>
            <span style={{ fontSize: 11.5, color: item.scopes[w.id] ? 'var(--fg)' : 'var(--fg-3)' }}>{w.name}</span>
            <span className="spacer" />
            {item.scopes[w.id] ? (
              <Switch sm value={item.enabled[w.id]}
                      onChange={(v) => dispatch({ type: 'set-scope-enabled', itemId: item.id, ws: w.id, value: v })} />
            ) : (
              <Btn ghost sm onClick={() => dispatch({ type: 'install-scope', itemId: item.id, ws: w.id })}><Icons.plus size={11} /></Btn>
            )}
          </div>
        ))}
      </div>

      <div className="subtitle" style={{ marginBottom: 8 }}>Supported agents</div>
      <div className="col" style={{ gap: 4, marginBottom: 14 }}>
        {agents.map((a) => {
          const on = item.agents.includes(a.id);
          return (
            <div key={a.id} className="row" style={{ fontSize: 11.5, opacity: on ? 1 : 0.4 }}>
              <span style={{ width: 16, height: 16, borderRadius: 4, background: a.color, color: 'white',
                             display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
                             fontSize: 8, fontWeight: 700, fontFamily: 'var(--font-mono)' }}>{a.initials}</span>
              <span>{a.name}</span>
              <span className="spacer" />
              {on ? <Icons.check size={11} style={{ color: 'var(--ok)' }} /> : <Icons.x size={10} className="muted" />}
            </div>
          );
        })}
      </div>

      <div className="subtitle" style={{ marginBottom: 8 }}>Metadata</div>
      <dl>
        <dt>ID</dt>            <dd className="mono">{item.id}</dd>
        <dt>Vendor</dt>        <dd>{item.vendor}</dd>
        <dt>Version</dt>       <dd className="mono">{item.version}</dd>
        <dt>Group</dt>         <dd>{item.group || '—'}</dd>
        <dt>Size</dt>          <dd>{item.size}</dd>
        <dt>Updated</dt>       <dd>{item.updated}</dd>
        {item.auth && <><dt>Auth</dt><dd>{item.auth}</dd></>}
      </dl>
    </div>
  );
}

window.ItemDetail = ItemDetail;

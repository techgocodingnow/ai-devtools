// AgentToolKit · Marketplace + Marketplace Settings + Groups + Agents + Onboarding

function Marketplace({ state, dispatch }) {
  const { marketplaces, marketplaceFeed, items, marketKindFilter, marketSource, search } = state;

  const filtered = marketplaceFeed.filter((m) => {
    if (marketKindFilter && marketKindFilter !== 'all' && m.kind !== marketKindFilter) return false;
    if (marketSource && marketSource !== 'all' && m.market !== marketSource) return false;
    if (search) {
      const s = search.toLowerCase();
      if (!m.name.toLowerCase().includes(s) && !m.vendor.toLowerCase().includes(s) && !m.description.toLowerCase().includes(s)) return false;
    }
    return true;
  });

  const installedIds = new Set(items.map((i) => i.id));

  return (
    <div style={{ display: 'flex', flexDirection: 'column', height: '100%' }}>
      <div className="toolbar" style={{ borderBottom: 'none' }}>
        <div>
          <div style={{ fontSize: 15, fontWeight: 600 }}>Marketplace</div>
          <div style={{ fontSize: 11, color: 'var(--fg-3)' }}>
            {marketplaces.filter((m) => m.enabled).reduce((s, m) => s + m.items, 0).toLocaleString()} items across {marketplaces.filter((m) => m.enabled).length} sources
          </div>
        </div>
        <div className="spacer" />
        <div className="search-wrap">
          <Icons.search size={12} />
          <input className="input search" placeholder="Search the marketplace…" style={{ width: 260 }}
                 value={search} onChange={(e) => dispatch({ type: 'set-search', search: e.target.value })} />
        </div>
        <Btn sm ghost><Icons.refresh size={12} />Sync now</Btn>
      </div>

      <div className="content">
        {/* Hero strip — featured + filters */}
        <div className="card elev" style={{
          padding: 18, marginBottom: 14,
          background: 'linear-gradient(135deg, oklch(0.22 0.04 282 / 0.7), var(--bg-elev))',
          borderColor: 'oklch(0.66 0.16 282 / 0.3)',
        }}>
          <div className="row" style={{ alignItems: 'flex-start', gap: 16 }}>
            <div style={{ flex: 1 }}>
              <Pill accent>Featured</Pill>
              <h3 style={{ margin: '8px 0 4px', fontSize: 16, fontWeight: 600 }}>Stripe MCP · official</h3>
              <p style={{ margin: 0, fontSize: 12, color: 'var(--fg-2)', maxWidth: 460 }}>
                Manage products, prices, subscriptions and refunds directly from your agent.
                Verified by Stripe, ships with type-safe tool definitions.
              </p>
              <div className="row" style={{ marginTop: 12, gap: 14, fontSize: 11.5, color: 'var(--fg-3)' }}>
                <span><Icons.download size={11} /> 8,142 installs</span>
                <span><Icons.starFill size={11} style={{ color: 'oklch(0.78 0.13 78)' }} /> 4.9</span>
                <span><Icons.shieldOk size={11} style={{ color: 'var(--ok)' }} /> verified</span>
              </div>
            </div>
            <Btn primary><Icons.download size={12} />Install</Btn>
          </div>
        </div>

        {/* Filter row */}
        <div className="row" style={{ marginBottom: 10, gap: 8, flexWrap: 'wrap' }}>
          <div className="seg">
            {['all', 'skill', 'plugin', 'mcp'].map((k) => (
              <div key={k} className={'s-btn' + ((marketKindFilter || 'all') === k ? ' on' : '')}
                   onClick={() => dispatch({ type: 'set-market-kind', marketKindFilter: k === 'all' ? null : k })}>
                {({ all: 'All kinds', skill: 'Skills', plugin: 'Plugins', mcp: 'MCP servers' }[k])}
              </div>
            ))}
          </div>
          <div className="seg">
            <div className={'s-btn' + ((marketSource || 'all') === 'all' ? ' on' : '')}
                 onClick={() => dispatch({ type: 'set-market-source', marketSource: 'all' })}>All sources</div>
            {marketplaces.filter((m) => m.enabled).map((m) => (
              <div key={m.id} className={'s-btn' + (marketSource === m.id ? ' on' : '')}
                   onClick={() => dispatch({ type: 'set-market-source', marketSource: m.id })}>
                <span className="dot" style={{ background: m.kind === 'official' ? 'var(--accent)' : m.kind === 'community' ? 'oklch(0.74 0.13 152)' : m.kind === 'github' ? 'oklch(0.66 0.005 270)' : 'oklch(0.66 0.16 320)' }} />
                {m.name}
              </div>
            ))}
          </div>
          <div className="spacer" />
          <Btn ghost sm><Icons.filter size={12} />More filters</Btn>
          <Btn ghost sm><Icons.sort size={12} />Top this week</Btn>
        </div>

        {/* Cards */}
        <div className="grid">
          {filtered.map((m) => {
            const installed = installedIds.has(m.id);
            const marketObj = marketplaces.find((x) => x.id === m.market);
            return (
              <div key={m.id} className="card hover" style={{ padding: 14 }}>
                <div className="row" style={{ alignItems: 'flex-start', gap: 10, marginBottom: 8 }}>
                  <ItemGlyph item={{ kind: m.kind, name: m.name }} size={36} />
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <div className="row" style={{ gap: 6 }}>
                      <span style={{ fontWeight: 600, fontSize: 13 }}>{m.name}</span>
                      {m.verified && <Icons.shieldOk size={12} style={{ color: 'var(--accent)' }} />}
                    </div>
                    <div className="mono muted" style={{ fontSize: 10.5, marginTop: 1 }}>{m.vendor}</div>
                  </div>
                  <Pill kind={m.kind}>{m.kind}</Pill>
                </div>
                <p style={{ margin: '6px 0 12px', fontSize: 11.5, color: 'var(--fg-2)', lineHeight: 1.5 }}>{m.description}</p>
                <div className="row" style={{ justifyContent: 'space-between' }}>
                  <div className="row" style={{ gap: 10, fontSize: 10.5, color: 'var(--fg-3)' }}>
                    <span><Icons.download size={10} /> {m.installs}</span>
                    <span><Icons.starFill size={10} style={{ color: 'oklch(0.78 0.13 78)' }} /> {m.stars}</span>
                    <span><Icons.globe size={10} /> {marketObj?.name || m.market}</span>
                  </div>
                  {installed ? (
                    <Pill><Icons.check size={10} style={{ color: 'var(--ok)' }} />Installed</Pill>
                  ) : (
                    <Btn sm><Icons.download size={11} />Install</Btn>
                  )}
                </div>
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
}

function MarketplaceSettings({ state, dispatch }) {
  const { marketplaces } = state;
  return (
    <div style={{ display: 'flex', flexDirection: 'column', height: '100%' }}>
      <div className="toolbar" style={{ borderBottom: 'none' }}>
        <div>
          <div style={{ fontSize: 15, fontWeight: 600 }}>Sources</div>
          <div style={{ fontSize: 11, color: 'var(--fg-3)' }}>Manage marketplace providers and repositories</div>
        </div>
        <div className="spacer" />
        <Btn sm><Icons.plus size={12} />Add source…</Btn>
      </div>

      <div className="content">
        <div className="card" style={{ padding: 0, overflow: 'hidden', marginBottom: 14 }}>
          {marketplaces.map((m, i) => (
            <div key={m.id} className="row" style={{
              padding: '14px 16px',
              borderBottom: i < marketplaces.length - 1 ? '0.5px solid var(--line-soft)' : 'none',
              gap: 14,
            }}>
              <Glyph label={m.kind === 'official' ? 'A' : m.kind === 'community' ? 'C' : m.kind === 'github' ? 'GH' : m.kind === 'private' ? 'I' : '·'}
                     color={m.kind === 'official' ? 'var(--accent)' : m.kind === 'community' ? 'oklch(0.62 0.16 152)' : m.kind === 'github' ? 'oklch(0.30 0.005 270)' : 'oklch(0.62 0.16 320)'}
                     size={32} />
              <div style={{ flex: 1, minWidth: 0 }}>
                <div className="row" style={{ gap: 6 }}>
                  <span style={{ fontWeight: 600, fontSize: 13 }}>{m.name}</span>
                  <Pill kind={null}>{m.kind}</Pill>
                  {m.trust === 'verified' && <Pill accent><Icons.shieldOk size={10} />verified</Pill>}
                  {m.trust === 'community' && <Pill>community</Pill>}
                  {m.trust === 'pinned' && <Pill><Icons.shield size={10} />pinned commit</Pill>}
                  {m.trust === 'private' && <Pill><Icons.shield size={10} />private</Pill>}
                </div>
                <div className="row" style={{ gap: 14, marginTop: 4, fontSize: 11, color: 'var(--fg-3)' }}>
                  <span className="mono">{m.url}</span>
                  <span>{m.items.toLocaleString()} items</span>
                  <span>last sync: {m.lastSync}</span>
                </div>
              </div>
              <Btn ghost sm><Icons.refresh size={12} /></Btn>
              <Btn ghost sm><Icons.edit size={12} /></Btn>
              <Switch value={m.enabled} onChange={(v) => dispatch({ type: 'toggle-marketplace', id: m.id, value: v })} />
              <Btn ghost sm icon><Icons.more size={14} /></Btn>
            </div>
          ))}
        </div>

        {/* Add source form preview (always visible — designers love forms) */}
        <div className="card" style={{ padding: 18 }}>
          <div className="subtitle" style={{ marginBottom: 10 }}>Add a new source</div>
          <div className="row" style={{ gap: 8, marginBottom: 10 }}>
            {['Marketplace URL', 'GitHub repo', 'Local folder', 'Internal registry'].map((t, i) => (
              <div key={t} className={'btn sm' + (i === 1 ? ' primary' : '')}>{t}</div>
            ))}
          </div>
          <div className="col" style={{ gap: 10 }}>
            <div className="row" style={{ gap: 12 }}>
              <div style={{ flex: 1 }}>
                <div className="subtitle" style={{ marginBottom: 4, fontSize: 10 }}>Repository</div>
                <input className="input" style={{ width: '100%' }} placeholder="owner/repo or https://github.com/…" defaultValue="anthropic-tools/awesome-skills" />
              </div>
              <div style={{ width: 160 }}>
                <div className="subtitle" style={{ marginBottom: 4, fontSize: 10 }}>Branch / tag</div>
                <input className="input" style={{ width: '100%' }} defaultValue="main" />
              </div>
            </div>
            <div className="row" style={{ gap: 12 }}>
              <div style={{ flex: 1 }}>
                <div className="subtitle" style={{ marginBottom: 4, fontSize: 10 }}>Display name</div>
                <input className="input" style={{ width: '100%' }} defaultValue="Awesome Skills (community)" />
              </div>
              <div style={{ width: 160 }}>
                <div className="subtitle" style={{ marginBottom: 4, fontSize: 10 }}>Trust level</div>
                <select className="input" style={{ width: '100%' }} defaultValue="pinned">
                  <option value="verified">Verified</option>
                  <option value="community">Community</option>
                  <option value="pinned">Pinned commit only</option>
                </select>
              </div>
            </div>
            <div className="row" style={{ gap: 8, marginTop: 4 }}>
              <Switch value={true} onChange={() => {}} />
              <span style={{ fontSize: 11.5, color: 'var(--fg-2)' }}>Auto-sync every 24h</span>
              <span className="spacer" />
              <Btn ghost sm>Cancel</Btn>
              <Btn sm primary><Icons.plus size={12} />Add source</Btn>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

function GroupsScreen({ state, dispatch }) {
  const { groups, items } = state;
  return (
    <div style={{ display: 'flex', flexDirection: 'column', height: '100%' }}>
      <div className="toolbar" style={{ borderBottom: 'none' }}>
        <div>
          <div style={{ fontSize: 15, fontWeight: 600 }}>Groups</div>
          <div style={{ fontSize: 11, color: 'var(--fg-3)' }}>
            Bundle related items to enable/disable as a unit
          </div>
        </div>
        <div className="spacer" />
        <Btn sm><Icons.plus size={12} />New group</Btn>
      </div>

      <div className="content">
        <div className="row" style={{ gap: 14, alignItems: 'stretch' }}>
          <div className="card" style={{ width: 320, padding: 0, overflow: 'hidden', flexShrink: 0 }}>
            {groups.map((g) => {
              const inGroup = items.filter((it) => it.group === g.id);
              return (
                <div key={g.id} className="group-row" onClick={() => dispatch({ type: 'select-group', selectedGroup: g.id })}
                     style={state.selectedGroup === g.id ? { background: 'var(--bg-active)' } : {}}>
                  <div className="g-ico" style={{ background: g.color }}>
                    {g.name.split(' ').map((w) => w[0]).join('').slice(0, 2)}
                  </div>
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <div style={{ fontSize: 12.5, fontWeight: 600 }}>{g.name}</div>
                    <div style={{ fontSize: 11, color: 'var(--fg-3)' }}>{inGroup.length} items</div>
                  </div>
                  <Switch sm value={true} />
                </div>
              );
            })}
          </div>

          <div className="card" style={{ flex: 1, padding: 18 }}>
            {(() => {
              const g = groups.find((x) => x.id === (state.selectedGroup || groups[0].id));
              const inGroup = items.filter((it) => it.group === g.id);
              return (
                <>
                  <div className="row" style={{ alignItems: 'flex-start' }}>
                    <div className="g-ico" style={{ background: g.color, width: 36, height: 36, fontSize: 13 }}>
                      {g.name.split(' ').map((w) => w[0]).join('').slice(0, 2)}
                    </div>
                    <div style={{ flex: 1, marginLeft: 12 }}>
                      <div style={{ fontSize: 15, fontWeight: 600 }}>{g.name}</div>
                      <div style={{ fontSize: 11.5, color: 'var(--fg-3)', marginTop: 2 }}>{g.description}</div>
                    </div>
                    <Btn ghost sm><Icons.edit size={12} />Rename</Btn>
                    <Btn ghost sm><Icons.cog size={12} />Settings</Btn>
                  </div>

                  <div className="subtitle" style={{ marginTop: 18, marginBottom: 8 }}>Members · {inGroup.length}</div>
                  <div className="col" style={{ gap: 0 }}>
                    {inGroup.map((it) => (
                      <div key={it.id} className="row" style={{ padding: '8px 10px', borderRadius: 6, gap: 10 }}>
                        <ItemGlyph item={it} size={22} />
                        <div style={{ flex: 1 }}>
                          <div style={{ fontSize: 12, fontWeight: 500 }}>{it.name}</div>
                          <div className="mono muted" style={{ fontSize: 10.5 }}>{it.vendor} · v{it.version}</div>
                        </div>
                        <Pill kind={it.kind}>{it.kind}</Pill>
                        <Btn ghost sm icon><Icons.minus size={12} /></Btn>
                      </div>
                    ))}
                    <div className="row" style={{ padding: '8px 10px', borderRadius: 6, color: 'var(--fg-3)', cursor: 'default' }}>
                      <Icons.plus size={12} /> <span style={{ fontSize: 11.5 }}>Add item to group…</span>
                    </div>
                  </div>
                </>
              );
            })()}
          </div>
        </div>
      </div>
    </div>
  );
}

function AgentsScreen({ state, dispatch }) {
  const { agents, items, scanning } = state;
  return (
    <div style={{ display: 'flex', flexDirection: 'column', height: '100%' }}>
      <div className="toolbar" style={{ borderBottom: 'none' }}>
        <div>
          <div style={{ fontSize: 15, fontWeight: 600 }}>Agents</div>
          <div style={{ fontSize: 11, color: 'var(--fg-3)' }}>
            Auto-detected from <span className="mono">PATH</span>, common install locations, and config files
          </div>
        </div>
        <div className="spacer" />
        <Btn sm ghost onClick={() => dispatch({ type: 'rescan' })}>
          <Icons.scan size={12} />{scanning ? 'Scanning…' : 'Rescan'}
        </Btn>
      </div>

      <div className="content">
        {scanning && (
          <div className="card" style={{ padding: 14, marginBottom: 12, display: 'flex', alignItems: 'center', gap: 12 }}>
            <div style={{ flex: 1 }}>
              <div className="row" style={{ marginBottom: 6 }}>
                <Icons.scan size={12} style={{ color: 'var(--accent)' }} />
                <span style={{ fontSize: 12, fontWeight: 500 }}>Scanning system for installed agents…</span>
                <span className="spacer" />
                <span className="mono muted" style={{ fontSize: 11 }}>14 of 24 paths</span>
              </div>
              <div className="scan-bar"><i /></div>
            </div>
          </div>
        )}

        {agents.map((a) => {
          const supported = items.filter((it) => it.agents.includes(a.id));
          return (
            <div key={a.id} className="card" style={{ padding: 16, marginBottom: 10 }}>
              <div className="row" style={{ gap: 14, alignItems: 'flex-start' }}>
                <Glyph label={a.initials} color={a.color} size={44} radius={10} />
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div className="row" style={{ gap: 8 }}>
                    <div style={{ fontSize: 14, fontWeight: 600 }}>{a.name}</div>
                    <Pill><span className={'dot ' + (a.detected ? 'ok' : 'off')} />{a.detected ? 'detected' : 'not found'}</Pill>
                    <span className="mono muted" style={{ fontSize: 11 }}>v{a.version}</span>
                  </div>
                  <div className="mono muted" style={{ fontSize: 11, marginTop: 4 }}>{a.binary}</div>
                  <div className="row" style={{ gap: 18, marginTop: 10, fontSize: 11.5, color: 'var(--fg-2)' }}>
                    <span><b>{supported.length}</b> compatible items</span>
                    <span><b>{a.supports.length}</b> kinds supported: {a.supports.join(', ')}</span>
                    <span>config: <span className="mono">~/.config/{a.id}/</span></span>
                  </div>
                  <div className="row" style={{ marginTop: 10, gap: 4 }}>
                    {supported.slice(0, 8).map((it) => <ItemGlyph key={it.id} item={it} size={20} />)}
                    {supported.length > 8 && <Pill>+{supported.length - 8} more</Pill>}
                  </div>
                </div>
                <div className="col" style={{ alignItems: 'flex-end', gap: 6 }}>
                  <Btn sm><Icons.terminal size={12} />Open shell</Btn>
                  <Btn ghost sm><Icons.cog size={12} />Configure</Btn>
                </div>
              </div>
            </div>
          );
        })}

        <div className="card" style={{ padding: 16, borderStyle: 'dashed', borderWidth: 1, opacity: 0.7, textAlign: 'center' }}>
          <Icons.plus size={16} className="muted" />
          <div style={{ marginTop: 6, fontSize: 12.5, fontWeight: 500 }}>Add a custom agent</div>
          <div style={{ fontSize: 11, color: 'var(--fg-3)', marginTop: 2 }}>Point at any binary or config dir to register a new agent.</div>
        </div>
      </div>
    </div>
  );
}

function OnboardingScreen({ state, dispatch }) {
  const { agents } = state;
  return (
    <div className="onb">
      <div className="onb-card">
        <div className="onb-mark">⌘</div>
        <h1>Welcome to AgentToolKit<span className="v">v1.0</span></h1>
        <p className="lead">
          A single place to manage every skill, plugin and MCP server across all your AI coding agents —
          globally, or per-project.
        </p>

        <div className="subtitle" style={{ marginBottom: 8 }}>Detected on this machine</div>
        <div className="col" style={{ gap: 0 }}>
          {agents.map((a) => (
            <div key={a.id} className="agent-pick">
              <div className="a-ico" style={{ background: a.color }}>{a.initials}</div>
              <div className="a-info">
                <div className="a-name">{a.name} <span className="muted" style={{ fontWeight: 400, marginLeft: 4 }}>v{a.version}</span></div>
                <div className="a-meta">{a.binary}</div>
              </div>
              <Pill><span className="dot ok" />detected</Pill>
              <Switch value={true} />
            </div>
          ))}
        </div>

        <div className="card" style={{ marginTop: 14, padding: 12, background: 'var(--bg-panel)' }}>
          <div className="row" style={{ gap: 10 }}>
            <Icons.info size={14} style={{ color: 'var(--accent)' }} />
            <div style={{ fontSize: 11.5, color: 'var(--fg-2)', lineHeight: 1.5 }}>
              AgentToolKit will read configurations from each agent's standard install directory.
              We never upload your local config or secrets.
            </div>
          </div>
        </div>

        <div className="row" style={{ marginTop: 18, justifyContent: 'flex-end', gap: 8 }}>
          <Btn ghost sm onClick={() => dispatch({ type: 'finish-onboarding' })}>Skip</Btn>
          <Btn primary onClick={() => dispatch({ type: 'finish-onboarding' })}>
            Get started <Icons.chev size={12} />
          </Btn>
        </div>
      </div>
    </div>
  );
}

Object.assign(window, { Marketplace, MarketplaceSettings, GroupsScreen, AgentsScreen, OnboardingScreen });

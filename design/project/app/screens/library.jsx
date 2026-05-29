// AgentToolKit · Library (main browse screen)

function Library({ state, dispatch }) {
  const { items, workspace, workspaces, kindFilter, groupFilter, groups, agents, search, viewMode, statusFilter } = state;
  const ws = workspaces.find((w) => w.id === workspace);

  const filtered = items.filter((it) => {
    if (!it.scopes[workspace]) return false;
    if (kindFilter && it.kind !== kindFilter) return false;
    if (groupFilter && it.group !== groupFilter) return false;
    if (statusFilter === 'enabled' && !it.enabled[workspace]) return false;
    if (statusFilter === 'disabled' && it.enabled[workspace]) return false;
    if (statusFilter === 'issues' && it.status !== 'warn' && it.status !== 'err') return false;
    if (search) {
      const s = search.toLowerCase();
      if (!it.name.toLowerCase().includes(s) && !it.vendor.toLowerCase().includes(s) && !it.id.includes(s)) return false;
    }
    return true;
  });

  const issueCount = filtered.filter((it) => it.status === 'warn' || it.status === 'err').length;

  // group by kind for grouped view
  const byKind = { skill: [], plugin: [], mcp: [] };
  filtered.forEach((it) => byKind[it.kind].push(it));

  const headerTitle = kindFilter
    ? ({ skill: 'Skills', plugin: 'Plugins', mcp: 'MCP servers' }[kindFilter])
    : (groupFilter ? groups.find((g) => g.id === groupFilter)?.name : 'All items');

  return (
    <div style={{ display: 'flex', flexDirection: 'column', height: '100%' }}>
      {/* Library sub-toolbar */}
      <div className="toolbar" style={{ borderBottom: 'none', paddingTop: 8, height: 'auto', minHeight: 44, paddingBottom: 4, flexWrap: 'wrap' }}>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 2, minWidth: 0 }}>
          <div style={{ fontSize: 15, fontWeight: 600, whiteSpace: 'nowrap' }}>{headerTitle}</div>
          <div style={{ fontSize: 11, color: 'var(--fg-3)', whiteSpace: 'nowrap' }}>
            {filtered.length} {filtered.length === 1 ? 'item' : 'items'} · <span style={{ color: 'var(--accent)' }}>{ws.name}</span>
            {issueCount > 0 && <> · <span style={{ color: 'var(--warn)' }}>{issueCount} need attention</span></>}
          </div>
        </div>
        <div className="spacer" />
        <div className="search-wrap" style={{ minWidth: 140, flex: '0 1 220px' }}>
          <Icons.search size={12} />
          <input className="input search" placeholder="Search items…" style={{ width: '100%' }}
                 value={search} onChange={(e) => dispatch({ type: 'set-search', search: e.target.value })} />
        </div>
        <div className="seg">
          <div className={'s-btn' + (statusFilter === 'all' ? ' on' : '')}
               onClick={() => dispatch({ type: 'set-status-filter', statusFilter: 'all' })}>All</div>
          <div className={'s-btn' + (statusFilter === 'enabled' ? ' on' : '')}
               onClick={() => dispatch({ type: 'set-status-filter', statusFilter: 'enabled' })}>On</div>
          <div className={'s-btn' + (statusFilter === 'disabled' ? ' on' : '')}
               onClick={() => dispatch({ type: 'set-status-filter', statusFilter: 'disabled' })}>Off</div>
          <div className={'s-btn' + (statusFilter === 'issues' ? ' on' : '')}
               onClick={() => dispatch({ type: 'set-status-filter', statusFilter: 'issues' })}>
            Issues {issueCount > 0 && <span style={{ background: 'var(--err)', color: 'white', borderRadius: 8, padding: '0 5px', fontSize: 10 }}>{issueCount}</span>}
          </div>
        </div>
        <div className="seg">
          <div className={'s-btn' + (viewMode === 'list' ? ' on' : '')} onClick={() => dispatch({ type: 'set-view-mode', viewMode: 'list' })}><Icons.list size={12} /></div>
          <div className={'s-btn' + (viewMode === 'grid' ? ' on' : '')} onClick={() => dispatch({ type: 'set-view-mode', viewMode: 'grid' })}><Icons.grid size={12} /></div>
        </div>
        <Btn sm><Icons.download size={12} />Install…</Btn>
      </div>

      {/* List or grid */}
      <div className="content" style={{ paddingTop: 4 }}>
        {viewMode === 'list' && !kindFilter && !groupFilter ? (
          <>
            {['skill', 'plugin', 'mcp'].map((k) => byKind[k].length > 0 && (
              <LibrarySection key={k} kind={k} items={byKind[k]} agents={agents} workspace={workspace} dispatch={dispatch} />
            ))}
          </>
        ) : viewMode === 'list' ? (
          <LibraryTable items={filtered} agents={agents} workspace={workspace} dispatch={dispatch} />
        ) : (
          <LibraryGrid items={filtered} agents={agents} workspace={workspace} dispatch={dispatch} />
        )}

        {filtered.length === 0 && (
          <div style={{ padding: 60, textAlign: 'center', color: 'var(--fg-3)' }}>
            <Icons.search size={32} style={{ opacity: 0.4 }} />
            <div style={{ marginTop: 14, fontSize: 13 }}>No items match your filters.</div>
            <div style={{ marginTop: 4, fontSize: 11.5 }}>Try clearing the search or changing scope to <b>Global</b>.</div>
          </div>
        )}
      </div>
    </div>
  );
}

function LibrarySection({ kind, items, agents, workspace, dispatch }) {
  const label = { skill: 'Skills', plugin: 'Plugins', mcp: 'MCP servers' }[kind];
  return (
    <div style={{ marginBottom: 18 }}>
      <div className="section-h">
        <span className={'dot ' + kind} />
        <h2>{label}</h2>
        <span className="count">{items.length}</span>
        <div className="spacer" />
        <Btn ghost sm onClick={() => dispatch({ type: 'nav', screen: 'library', kindFilter: kind })}>
          View all <Icons.chev size={11} />
        </Btn>
      </div>
      <LibraryTable items={items} agents={agents} workspace={workspace} dispatch={dispatch} />
    </div>
  );
}

function LibraryTable({ items, agents, workspace, dispatch }) {
  return (
    <div style={{ border: '0.5px solid var(--line)', borderRadius: 'var(--radius-lg)', overflow: 'hidden', background: 'var(--bg-panel)' }}>
      <div style={{ overflowX: 'auto' }}>
      <table className="tbl" style={{ minWidth: 760 }}>
        <thead>
          <tr>
            <th style={{ width: 32 }}></th>
            <th>Name</th>
            <th style={{ width: 80 }}>Kind</th>
            <th style={{ width: 130 }}>Vendor</th>
            <th style={{ width: 64 }}>Version</th>
            <th style={{ width: 96 }}>Agents</th>
            <th style={{ width: 110 }}>Updated</th>
            <th style={{ width: 80 }}>Status</th>
            <th style={{ width: 50, textAlign: 'right' }}></th>
          </tr>
        </thead>
        <tbody>
          {items.map((it) => (
            <LibraryRow key={it.id} item={it} agents={agents} workspace={workspace} dispatch={dispatch} />
          ))}
        </tbody>
      </table>
      </div>
    </div>
  );
}

function LibraryRow({ item, agents, workspace, dispatch }) {
  const enabled = item.enabled[workspace];
  return (
    <tr onClick={() => dispatch({ type: 'open-item', itemId: item.id })}>
      <td><Switch sm value={enabled} onChange={(v) => dispatch({ type: 'toggle-enabled', itemId: item.id, value: v })} /></td>
      <td>
        <div className="row" style={{ gap: 9 }}>
          <ItemGlyph item={item} size={22} />
          <div style={{ display: 'flex', flexDirection: 'column', minWidth: 0 }}>
            <div style={{ fontWeight: 500, color: enabled ? 'var(--fg)' : 'var(--fg-3)', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{item.name}</div>
            <div className="mono muted" style={{ fontSize: 10.5, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{item.id}</div>
          </div>
        </div>
      </td>
      <td><Pill kind={item.kind}>{item.kind}</Pill></td>
      <td className="muted" style={{ fontSize: 11.5 }}>{item.vendor}</td>
      <td className="mono">{item.version}</td>
      <td>
        <div style={{ display: 'flex', gap: 2 }}>
          {item.agents.map((aid) => {
            const a = agents.find((x) => x.id === aid);
            return (
              <span key={aid} title={a?.name}
                    style={{ width: 18, height: 18, borderRadius: 4, background: a?.color, color: 'white',
                             display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
                             fontSize: 8.5, fontWeight: 700, fontFamily: 'var(--font-mono)' }}>
                {a?.initials}
              </span>
            );
          })}
        </div>
      </td>
      <td className="muted" style={{ fontSize: 11.5 }}>{item.updated}</td>
      <td>
        <div className="row" style={{ gap: 6 }}>
          <StatusDot status={item.status} />
          <span style={{ fontSize: 11.5, color: item.status === 'err' ? 'var(--err)' : item.status === 'warn' ? 'var(--warn)' : 'var(--fg-2)' }}>
            {item.status === 'ok' ? (enabled ? 'Enabled' : 'Disabled') :
             item.status === 'warn' ? 'Warning' :
             item.status === 'err' ? 'Error' : 'Off'}
          </span>
        </div>
      </td>
      <td style={{ textAlign: 'right' }}>
        <Btn ghost sm icon onClick={(e) => { e.stopPropagation(); }}><Icons.more size={14} /></Btn>
      </td>
    </tr>
  );
}

function LibraryGrid({ items, agents, workspace, dispatch }) {
  return (
    <div className="grid">
      {items.map((it) => {
        const enabled = it.enabled[workspace];
        return (
          <div key={it.id} className="card hover" onClick={() => dispatch({ type: 'open-item', itemId: it.id })}>
            <div className="row" style={{ alignItems: 'flex-start', gap: 10 }}>
              <ItemGlyph item={it} size={32} />
              <div style={{ flex: 1, minWidth: 0 }}>
                <div className="row" style={{ gap: 6 }}>
                  <div style={{ fontWeight: 600, fontSize: 13 }}>{it.name}</div>
                  {it.status === 'warn' && <Icons.alert size={12} style={{ color: 'var(--warn)' }} />}
                  {it.status === 'err' && <Icons.alert size={12} style={{ color: 'var(--err)' }} />}
                </div>
                <div className="mono muted" style={{ fontSize: 10.5, marginTop: 1 }}>{it.vendor} · v{it.version}</div>
              </div>
              <Switch sm value={enabled} onChange={(v) => dispatch({ type: 'toggle-enabled', itemId: it.id, value: v })} />
            </div>
            <div className="row" style={{ marginTop: 10, justifyContent: 'space-between' }}>
              <Pill kind={it.kind}>{it.kind}</Pill>
              <div style={{ display: 'flex', gap: 2 }}>
                {it.agents.map((aid) => {
                  const a = agents.find((x) => x.id === aid);
                  return (
                    <span key={aid} title={a?.name}
                          style={{ width: 16, height: 16, borderRadius: 3, background: a?.color, color: 'white',
                                   display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
                                   fontSize: 8, fontWeight: 700, fontFamily: 'var(--font-mono)' }}>
                      {a?.initials}
                    </span>
                  );
                })}
              </div>
            </div>
          </div>
        );
      })}
    </div>
  );
}

window.Library = Library;

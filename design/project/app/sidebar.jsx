// AgentToolKit · sidebar with workspace picker + nav

function Sidebar({ state, dispatch }) {
  const { workspace, screen, kindFilter, groupFilter, items, groups, workspaces, wsMenuOpen } = state;
  const ws = workspaces.find((w) => w.id === workspace);

  // counts by kind, filtered to this workspace
  const countFor = (kind) => items.filter((it) => it.kind === kind && it.scopes[workspace]).length;

  const NavItem = ({ id, icon, label, count, active, badge }) => (
    <div className={'sb-item' + (active ? ' active' : '')}
         onClick={() => dispatch({ type: 'nav', screen: id })}>
      <span className="ico">{icon}</span>
      <span>{label}</span>
      {badge && <span className="pill" style={{ height: 16, fontSize: 9.5, padding: '0 5px', marginLeft: 6 }}>{badge}</span>}
      {count != null && <span className="count">{count}</span>}
    </div>
  );

  const isLibraryKind = (k) => screen === 'library' && kindFilter === k;

  return (
    <div className="sidebar">
      {/* workspace picker */}
      <div className="ws-picker" onClick={() => dispatch({ type: 'toggle-ws-menu' })} style={{ position: 'relative' }}>
        <div className={'ws-ico' + (ws.scope === 'global' ? ' global' : '')}
             style={ws.color ? { background: `linear-gradient(135deg, ${ws.color}, oklch(0.45 0.06 ${100 + ws.id.length * 30}))` } : {}}>
          {ws.initials}
        </div>
        <div className="ws-info">
          <div className="ws-name">{ws.name}</div>
          <div className="ws-sub">{ws.path}</div>
        </div>
        <Icons.swap size={12} />

        {wsMenuOpen && (
          <div className="menu" style={{ position: 'absolute', top: 48, left: 0, right: 0, width: 'auto', minWidth: 0 }}
               onClick={(e) => e.stopPropagation()}>
            <div className="m-section">Switch workspace</div>
            {workspaces.map((w) => (
              <div key={w.id} className="m-item" onClick={() => dispatch({ type: 'switch-ws', workspace: w.id })}>
                <div className={'ws-ico' + (w.scope === 'global' ? ' global' : '')}
                     style={{ width: 18, height: 18, fontSize: 9, borderRadius: 4, ...(w.color ? { background: `linear-gradient(135deg, ${w.color}, oklch(0.45 0.06 ${100 + w.id.length * 30}))` } : {}) }}>
                  {w.initials}
                </div>
                <span style={{ flex: 1 }}>{w.name}</span>
                {w.scope === 'global' && <Pill>global</Pill>}
                {w.id === workspace && <Icons.check size={12} />}
              </div>
            ))}
            <div className="m-sep" />
            <div className="m-item muted"><Icons.plus size={12} />Open project folder…</div>
            <div className="m-item muted"><Icons.cog size={12} />Workspace settings</div>
          </div>
        )}
      </div>

      <div style={{ padding: '4px 0' }} />

      {/* main nav */}
      <NavItem id="library"   icon={<Icons.layers />}    label="Library"             count={countFor('skill') + countFor('plugin') + countFor('mcp')}
               active={screen === 'library' && !kindFilter} />

      <div className="sb-section">Categories</div>
      <div className={'sb-item' + (isLibraryKind('skill') ? ' active' : '')}
           onClick={() => dispatch({ type: 'nav', screen: 'library', kindFilter: 'skill' })}>
        <span className="dot skill" style={{ marginLeft: 1, marginRight: 1 }} />
        <span>Skills</span>
        <span className="count">{countFor('skill')}</span>
      </div>
      <div className={'sb-item' + (isLibraryKind('plugin') ? ' active' : '')}
           onClick={() => dispatch({ type: 'nav', screen: 'library', kindFilter: 'plugin' })}>
        <span className="dot plugin" style={{ marginLeft: 1, marginRight: 1 }} />
        <span>Plugins</span>
        <span className="count">{countFor('plugin')}</span>
      </div>
      <div className={'sb-item' + (isLibraryKind('mcp') ? ' active' : '')}
           onClick={() => dispatch({ type: 'nav', screen: 'library', kindFilter: 'mcp' })}>
        <span className="dot mcp" style={{ marginLeft: 1, marginRight: 1 }} />
        <span>MCP servers</span>
        <span className="count">{countFor('mcp')}</span>
      </div>
      <div className={'sb-item' + (screen === 'hooks' ? ' active' : '')}
           onClick={() => dispatch({ type: 'nav', screen: 'hooks' })}>
        <span className="dot hook" style={{ marginLeft: 1, marginRight: 1 }} />
        <span>Hooks</span>
        <span className="count">{state.hooks.filter((h) => h.scopes[workspace] && h.enabled[workspace]).length}</span>
      </div>

      <div className="sb-section">
        <span>Groups</span>
        <span className="add" onClick={() => dispatch({ type: 'nav', screen: 'groups' })}><Icons.plus size={10} /></span>
      </div>
      {groups.slice(0, 6).map((g) => (
        <div key={g.id}
             className={'sb-item' + (screen === 'library' && groupFilter === g.id ? ' active' : '')}
             onClick={() => dispatch({ type: 'nav', screen: 'library', groupFilter: g.id })}>
          <span className="dot" style={{ background: g.color, marginLeft: 1, marginRight: 1 }} />
          <span style={{ overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{g.name}</span>
          <span className="count">{g.items}</span>
        </div>
      ))}

      <div className="sb-section">Discover</div>
      <NavItem id="marketplace"          icon={<Icons.shop />}   label="Marketplace"   active={screen === 'marketplace'} badge="124 new" />
      <NavItem id="marketplace-settings" icon={<Icons.globe />}  label="Sources"       active={screen === 'marketplace-settings'} />

      <div className="sb-section">System</div>
      <NavItem id="agents" icon={<Icons.cube />}    label="Agents"   active={screen === 'agents'} />
      <NavItem id="groups" icon={<Icons.folder />}  label="Groups"   active={screen === 'groups'} count={groups.length} />

      <div style={{ flex: 1 }} />

      {/* footer: user */}
      <div className="sb-item" style={{ marginBottom: 6 }}>
        <span className="ico"><Icons.user /></span>
        <span>kuro</span>
        <span className="count"><Icons.cog size={12} /></span>
      </div>
    </div>
  );
}

window.Sidebar = Sidebar;

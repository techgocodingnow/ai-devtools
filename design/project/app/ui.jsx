// AgentToolKit · shared UI primitives

function Btn({ children, primary, ghost, danger, sm, icon, onClick, disabled, title, style }) {
  const cls = ['btn',
    primary && 'primary',
    ghost && 'ghost',
    danger && 'danger',
    sm && 'sm',
    icon && 'icon'].filter(Boolean).join(' ');
  return (
    <button type="button" className={cls} onClick={onClick} disabled={disabled} title={title} style={style}>
      {children}
    </button>
  );
}

function Switch({ value, onChange, sm }) {
  return (
    <button type="button" className={'switch' + (sm ? ' sm' : '')}
            data-on={value ? '1' : '0'} role="switch" aria-checked={!!value}
            onClick={(e) => { e.stopPropagation(); onChange && onChange(!value); }} />
  );
}

function Pill({ children, kind, accent, style }) {
  return <span className={'pill' + (kind ? ' ' + kind : '') + (accent ? ' accent' : '')} style={style}>{children}</span>;
}

function CategoryDot({ kind }) {
  return <span className={'dot ' + kind} />;
}

function StatusDot({ status }) {
  return <span className={'dot ' + status} />;
}

// Glyph rendered as flat colored tile with letters — used for items + agents + workspaces.
function Glyph({ label, color, size = 28, radius = 7, font }) {
  const hue = color || hashColor(label);
  return (
    <div style={{
      width: size, height: size, borderRadius: radius,
      background: hue,
      color: 'white',
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      fontFamily: font || 'var(--font-display)',
      fontSize: Math.max(10, size * 0.42),
      fontWeight: 700, letterSpacing: '-0.02em',
      flexShrink: 0,
      boxShadow: '0 1px 0 rgba(255,255,255,0.12) inset, 0 1px 2px rgba(0,0,0,0.2)',
    }}>{label}</div>
  );
}

// Item glyph rendered by kind — skill/plugin/mcp.
function ItemGlyph({ item, size = 28 }) {
  const palette = {
    skill:     ['oklch(0.74 0.16 152)', 'oklch(0.55 0.18 152)'],
    plugin:    ['oklch(0.78 0.14 78)',  'oklch(0.60 0.17 78)'],
    mcp: ['oklch(0.74 0.14 232)', 'oklch(0.55 0.17 232)'],
  }[item.kind] || ['#888', '#555'];
  const initials = item.name.split(/[\s-]+/).slice(0, 2).map((w) => w[0]).join('').slice(0, 2).toUpperCase();
  return (
    <div style={{
      width: size, height: size, borderRadius: 7,
      background: `linear-gradient(135deg, ${palette[0]}, ${palette[1]})`,
      color: 'white', display: 'flex', alignItems: 'center', justifyContent: 'center',
      fontFamily: 'var(--font-display)', fontWeight: 700, fontSize: Math.max(10, size * 0.36),
      flexShrink: 0,
      boxShadow: '0 1px 0 rgba(255,255,255,0.18) inset, 0 1px 2px rgba(0,0,0,0.2)',
    }}>{initials}</div>
  );
}

function hashColor(seed) {
  let h = 0;
  for (let i = 0; i < seed.length; i++) h = (h * 31 + seed.charCodeAt(i)) | 0;
  const hue = Math.abs(h) % 360;
  return `oklch(0.66 0.14 ${hue})`;
}

// Tooltip-ish hover label (simple)
function useHover() {
  const [h, setH] = React.useState(false);
  return [h, { onMouseEnter: () => setH(true), onMouseLeave: () => setH(false) }];
}

// Click-outside hook for menus
function useClickOutside(ref, onClose) {
  React.useEffect(() => {
    const f = (e) => { if (ref.current && !ref.current.contains(e.target)) onClose(); };
    document.addEventListener('mousedown', f);
    return () => document.removeEventListener('mousedown', f);
  }, [onClose]);
}

// Scope checkbox row (used in detail panel)
function ScopeCheck({ label, mono, checked, onChange, indent, dim }) {
  return (
    <label style={{
      display: 'flex', alignItems: 'center', gap: 8,
      padding: '5px 6px', borderRadius: 5, cursor: 'default',
      paddingLeft: indent ? 18 : 6,
      opacity: dim ? 0.5 : 1,
    }}>
      <input type="checkbox" checked={checked} onChange={(e) => onChange && onChange(e.target.checked)}
             style={{ margin: 0, accentColor: 'var(--accent)' }} />
      <span style={{ fontSize: 12, color: 'var(--fg)' }}>{label}</span>
      {mono && <span className="mono muted" style={{ marginLeft: 'auto' }}>{mono}</span>}
    </label>
  );
}

Object.assign(window, { Btn, Switch, Pill, CategoryDot, StatusDot, Glyph, ItemGlyph, hashColor, useClickOutside, ScopeCheck });

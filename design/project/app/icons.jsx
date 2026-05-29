// AgentToolKit · inline SVG icon set (24x24 grid, stroke=1.5)

const Ic = ({ d, fill, size = 14, stroke = 1.5, viewBox = "0 0 24 24", className = '', style = {} }) => (
  <svg width={size} height={size} viewBox={viewBox} fill="none"
       stroke="currentColor" strokeWidth={stroke}
       strokeLinecap="round" strokeLinejoin="round"
       className={className} style={style}>
    {fill ? <path d={d} fill="currentColor" stroke="none" /> : <path d={d} />}
  </svg>
);

const Icons = {
  search:    (p) => <Ic d="M11 19a8 8 0 1 1 0-16 8 8 0 0 1 0 16Zm10 2-4.35-4.35" {...p} />,
  chev:      (p) => <Ic d="M9 6l6 6-6 6" {...p} />,
  chevDown:  (p) => <Ic d="M6 9l6 6 6-6" {...p} />,
  chevUp:    (p) => <Ic d="M6 15l6-6 6 6" {...p} />,
  swap:      (p) => <Ic d="M7 7h11l-3-3M17 17H6l3 3" {...p} />,
  plus:      (p) => <Ic d="M12 5v14M5 12h14" {...p} />,
  minus:     (p) => <Ic d="M5 12h14" {...p} />,
  x:         (p) => <Ic d="M6 6l12 12M18 6L6 18" {...p} />,
  check:     (p) => <Ic d="M5 12l5 5L20 7" {...p} />,
  more:      (p) => <Ic d="M6 12h.01M12 12h.01M18 12h.01" stroke={2.5} {...p} />,
  cog:       (p) => <Ic d="M12 15.5a3.5 3.5 0 1 0 0-7 3.5 3.5 0 0 0 0 7Zm8.5-3.5c0 .7-.07 1.38-.21 2.03l1.93 1.5-2 3.46-2.3-.91a8.5 8.5 0 0 1-3.51 2.03L13.9 22h-4l-.5-2.39a8.5 8.5 0 0 1-3.51-2.03l-2.3.91-2-3.46 1.93-1.5A8.5 8.5 0 0 1 3.5 12c0-.7.07-1.38.21-2.03l-1.93-1.5 2-3.46 2.3.91a8.5 8.5 0 0 1 3.51-2.03L10.1 2h4l.5 2.39a8.5 8.5 0 0 1 3.51 2.03l2.3-.91 2 3.46-1.93 1.5c.13.65.21 1.33.21 2.03Z" {...p} />,
  box:       (p) => <Ic d="M3 7l9-4 9 4-9 4-9-4Zm0 0v10l9 4 9-4V7" {...p} />,
  zap:       (p) => <Ic d="M13 2L3 14h7l-1 8 10-12h-7l1-8Z" {...p} />,
  plug:      (p) => <Ic d="M9 7V2m6 5V2M5 12h14v3a5 5 0 0 1-5 5h-4a5 5 0 0 1-5-5v-3Zm6 8v2m2-2v2" {...p} />,
  folder:    (p) => <Ic d="M3 6a2 2 0 0 1 2-2h4l2 2h8a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V6Z" {...p} />,
  globe:     (p) => <Ic d="M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18Zm0 0c-2.5-3-4-6-4-9s1.5-6 4-9m0 18c2.5-3 4-6 4-9s-1.5-6-4-9M3 12h18" {...p} />,
  shop:      (p) => <Ic d="M3 9l1.5-5h15L21 9M3 9v10a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V9M3 9h18M9 14h6" {...p} />,
  layers:    (p) => <Ic d="M12 2 2 7l10 5 10-5-10-5Zm-10 11 10 5 10-5M2 18l10 5 10-5" {...p} />,
  user:      (p) => <Ic d="M16 20v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2M14 6a3 3 0 1 1-6 0 3 3 0 0 1 6 0Z" {...p} />,
  star:      (p) => <Ic d="M12 2l3 7 7 .5-5.5 4.5L18 21l-6-3.5L6 21l1.5-7L2 9.5 9 9l3-7Z" {...p} />,
  starFill:  (p) => <Ic d="M12 2l3 7 7 .5-5.5 4.5L18 21l-6-3.5L6 21l1.5-7L2 9.5 9 9l3-7Z" fill {...p} />,
  download:  (p) => <Ic d="M12 4v12m0 0l-5-5m5 5l5-5M4 20h16" {...p} />,
  upload:    (p) => <Ic d="M12 20V8m0 0l-5 5m5-5l5 5M4 4h16" {...p} />,
  trash:     (p) => <Ic d="M4 7h16M9 7V4h6v3m1 0v13a1 1 0 0 1-1 1H9a1 1 0 0 1-1-1V7m3 4v6m4-6v6" {...p} />,
  refresh:   (p) => <Ic d="M3 12a9 9 0 0 1 15-6.7L21 8m0-5v5h-5M21 12a9 9 0 0 1-15 6.7L3 16m0 5v-5h5" {...p} />,
  link:      (p) => <Ic d="M10 14a5 5 0 0 0 7 0l3-3a5 5 0 0 0-7-7l-1 1m-1 8a5 5 0 0 0-7 0l-3 3a5 5 0 0 0 7 7l1-1" {...p} />,
  shield:    (p) => <Ic d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10Z" {...p} />,
  shieldOk:  (p) => <Ic d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10ZM9 12l2 2 4-4" {...p} />,
  alert:     (p) => <Ic d="M12 9v4m0 4h.01M5.07 19h13.86c1.54 0 2.5-1.67 1.73-3L13.73 4a2 2 0 0 0-3.46 0L3.34 16c-.77 1.33.19 3 1.73 3Z" {...p} />,
  info:      (p) => <Ic d="M12 22a10 10 0 1 0 0-20 10 10 0 0 0 0 20Zm0-13v6m0-9v.01" {...p} />,
  power:     (p) => <Ic d="M18.36 5.64a9 9 0 1 1-12.72 0M12 3v9" {...p} />,
  filter:    (p) => <Ic d="M3 5h18l-7 9v6l-4-2v-4L3 5Z" {...p} />,
  sort:      (p) => <Ic d="M7 5v14m0 0l-3-3m3 3l3-3M17 19V5m0 0l-3 3m3-3l3 3" {...p} />,
  grip:      (p) => <Ic d="M9 6h.01M9 12h.01M9 18h.01M15 6h.01M15 12h.01M15 18h.01" stroke={2.5} {...p} />,
  external: (p) => <Ic d="M14 4h6v6M20 4l-9 9M14 14v5a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V11a1 1 0 0 1 1-1h5" {...p} />,
  copy:     (p) => <Ic d="M8 4h10a2 2 0 0 1 2 2v10M16 8H6a2 2 0 0 0-2 2v10a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V10a2 2 0 0 0-2-2Z" {...p} />,
  list:     (p) => <Ic d="M8 6h13M8 12h13M8 18h13M3 6h.01M3 12h.01M3 18h.01" {...p} />,
  grid:     (p) => <Ic d="M3 3h7v7H3V3Zm11 0h7v7h-7V3ZM3 14h7v7H3v-7Zm11 0h7v7h-7v-7Z" {...p} />,
  edit:     (p) => <Ic d="M12 20h9M3 20l4-1 13-13a2 2 0 0 0-3-3L4 16l-1 4Z" {...p} />,
  scan:     (p) => <Ic d="M3 7V5a2 2 0 0 1 2-2h2M17 3h2a2 2 0 0 1 2 2v2M21 17v2a2 2 0 0 1-2 2h-2M7 21H5a2 2 0 0 1-2-2v-2M7 12h10" {...p} />,
  terminal: (p) => <Ic d="M3 4h18a1 1 0 0 1 1 1v14a1 1 0 0 1-1 1H3a1 1 0 0 1-1-1V5a1 1 0 0 1 1-1Zm3 5l3 3-3 3m6 0h5" {...p} />,
  history:  (p) => <Ic d="M3 12a9 9 0 1 0 3-6.7M3 4v5h5M12 8v5l3 2" {...p} />,
  workspace: (p) => <Ic d="M3 7l9-4 9 4M3 7v10l9 4 9-4V7M3 7l9 4m0 0l9-4m-9 4v10" {...p} />,
  database: (p) => <Ic d="M4 6c0-1.7 3.6-3 8-3s8 1.3 8 3-3.6 3-8 3-8-1.3-8-3Zm0 0v12c0 1.7 3.6 3 8 3s8-1.3 8-3V6m-16 6c0 1.7 3.6 3 8 3s8-1.3 8-3" {...p} />,
  branch:   (p) => <Ic d="M6 3v12m0 0a3 3 0 1 0 0 6 3 3 0 0 0 0-6Zm0-12a3 3 0 1 0 0 6 3 3 0 0 0 0-6Zm12 0v6a3 3 0 0 1-3 3H6m12-9a3 3 0 1 0 0 6 3 3 0 0 0 0-6Z" {...p} />,
  cube:     (p) => <Ic d="M21 16V8a2 2 0 0 0-1-1.7l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.7l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16Zm-9-13.4 9 5.2M3 8.8l9 5.2v9.8m9-15-9 5.2" {...p} />,
};

window.Icons = Icons;

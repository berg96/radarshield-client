// frame.jsx — RadarShield client: brand tokens, device frames, logo, icons
// Exports to window: RS (tokens), Phone, WinWindow, RSLogo, Icon

const RS = {
  navy:    '#0d1b2a',
  navy2:   '#0b1622',
  panel:   '#12243a',
  panel2:  '#16304d',
  line:    'rgba(255,255,255,0.08)',
  line2:   'rgba(255,255,255,0.14)',
  ink:     '#eef3f9',
  dim:     '#b7c4d3',
  mute:    '#7f8fa3',
  amber:   '#ffb703',
  // connection states
  off:     '#7c8ba0',
  connecting: '#ffb703',
  connected:  '#2fc98a',
  error:   '#f4736b',
  font:    "'Inter', system-ui, sans-serif",
  display: "'Manrope', system-ui, sans-serif",
};

// ─────────────────────────────────────────────────────────────
// Icon set (inline SVG, 24x24 stroke)
// ─────────────────────────────────────────────────────────────
const RS_PATHS = {
  power:   'M12 3v9 M7.5 6.5a8 8 0 1 0 9 0',
  shield:  'M12 2l8 4v6c0 5-3.5 9-8 10-4.5-1-8-5-8-10V6l8-4z',
  shieldcheck: 'M12 2l8 4v6c0 5-3.5 9-8 10-4.5-1-8-5-8-10V6l8-4z|M9 12l2 2 4-4',
  gear:    'M12 15a3 3 0 1 0 0-6 3 3 0 0 0 0 6z|M19.4 15a1.6 1.6 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.6 1.6 0 0 0-2.7 1.1V21a2 2 0 0 1-4 0v-.1A1.6 1.6 0 0 0 6.6 19.5l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1A1.6 1.6 0 0 0 4.6 14H4.5a2 2 0 0 1 0-4h.1a1.6 1.6 0 0 0 1.1-2.7l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.6 1.6 0 0 0 1.8.3H10.5a1.6 1.6 0 0 0 1-1.5V4.5a2 2 0 0 1 4 0v.1a1.6 1.6 0 0 0 2.7 1.1l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.6 1.6 0 0 0-.3 1.8V10.5a1.6 1.6 0 0 0 1.5 1H21a2 2 0 0 1 0 4h-.1a1.6 1.6 0 0 0-1.5 1z',
  logout:  'M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4|M16 17l5-5-5-5|M21 12H9',
  link:    'M10 13a5 5 0 0 0 7 0l3-3a5 5 0 0 0-7-7l-1 1|M14 11a5 5 0 0 0-7 0l-3 3a5 5 0 0 0 7 7l1-1',
  clipboard:'M9 4h6a1 1 0 0 1 1 1v1H8V5a1 1 0 0 1 1-1z|M8 6H6a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8a2 2 0 0 0-2-2h-2',
  check:   'M20 6L9 17l-5-5',
  chevron: 'M9 6l6 6-6 6',
  globe:   'M12 22a10 10 0 1 0 0-20 10 10 0 0 0 0 20z|M2 12h20|M12 2a15 15 0 0 1 4 10 15 15 0 0 1-4 10 15 15 0 0 1-4-10 15 15 0 0 1 4-10z',
  x:       'M18 6L6 18|M6 6l12 12',
  minus:   'M5 12h14',
  square:  'M5 5h14v14H5z',
  alert:   'M12 9v4|M12 17h.01|M10.3 3.9l-8 14A2 2 0 0 0 4 21h16a2 2 0 0 0 1.7-3L13.7 3.9a2 2 0 0 0-3.4 0z',
  refresh: 'M3 12a9 9 0 0 1 15-6.7L21 8|M21 3v5h-5|M21 12a9 9 0 0 1-15 6.7L3 16|M3 21v-5h5',
  language:'M5 8h14|M9 5l-1 3M12 5v3|M4 13l4 8 4-8|M5.5 17h5|M14 21l3-8 3 8|M14.7 19h4.6',
  info:    'M12 22a10 10 0 1 0 0-20 10 10 0 0 0 0 20z|M12 16v-4|M12 8h.01',
  user:    'M20 21a8 8 0 1 0-16 0|M12 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8z',
  sliders: 'M4 21v-7|M4 10V3|M12 21v-9|M12 8V3|M20 21v-5|M20 12V3|M1 14h6|M9 8h6|M17 16h6',
  bolt:    'M13 2L3 14h7l-1 8 10-12h-7l1-8z',
  clock:   'M12 22a10 10 0 1 0 0-20 10 10 0 0 0 0 20z|M12 6v6l4 2',
};

function Icon({ name, size = 24, color = 'currentColor', stroke = 2, fill = 'none', style }) {
  const d = RS_PATHS[name] || '';
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill={fill} stroke={color}
         strokeWidth={stroke} strokeLinecap="round" strokeLinejoin="round" style={style}>
      {d.split('|').map((p, i) => <path key={i} d={p} />)}
    </svg>
  );
}

// ─────────────────────────────────────────────────────────────
// RadarShield logo mark — shield + R (amber on dark / dark on amber)
// ─────────────────────────────────────────────────────────────
function RSLogo({ size = 28, amberBg = false }) {
  const shieldFill = amberBg ? RS.amber : 'none';
  const shieldStroke = amberBg ? 'none' : RS.amber;
  const rColor = amberBg ? RS.navy : RS.amber;
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" style={{ display: 'block' }}>
      <path d="M12 1.5l8.5 4.2v6.3c0 5.3-3.7 9.4-8.5 10.5-4.8-1.1-8.5-5.2-8.5-10.5V5.7L12 1.5z"
            fill={shieldFill} stroke={shieldStroke} strokeWidth={amberBg ? 0 : 1.6} strokeLinejoin="round" />
      <text x="12" y="16.5" textAnchor="middle" fontFamily="Manrope, Arial Black, sans-serif"
            fontWeight="900" fontSize="12" fill={rColor} letterSpacing="-0.5">R</text>
    </svg>
  );
}

// ─────────────────────────────────────────────────────────────
// Phone frame — full-bleed navy, white status bar, gesture pill
// ─────────────────────────────────────────────────────────────
function Phone({ children, width = 300, label, bg = RS.navy, time = '9:41' }) {
  const h = Math.round(width * 2.06);
  return (
    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 14 }}>
      <div style={{
        width, height: h, borderRadius: width * 0.11, position: 'relative',
        background: bg, overflow: 'hidden',
        border: '9px solid #05090f',
        boxShadow: '0 30px 70px -20px rgba(0,0,0,0.55), 0 0 0 1px rgba(255,255,255,0.04) inset',
        fontFamily: RS.font, boxSizing: 'border-box',
        display: 'flex', flexDirection: 'column',
      }}>
        {/* status bar */}
        <div style={{
          height: width * 0.13, flexShrink: 0, display: 'flex', alignItems: 'center',
          justifyContent: 'space-between', padding: `0 ${width * 0.06}px`,
          position: 'relative', zIndex: 5,
        }}>
          <span style={{ color: RS.ink, fontSize: width * 0.046, fontWeight: 600, letterSpacing: 0.2 }}>{time}</span>
          <div style={{
            position: 'absolute', left: '50%', top: width * 0.05, transform: 'translateX(-50%)',
            width: width * 0.30, height: width * 0.065, borderRadius: 100, background: '#05090f',
          }} />
          <div style={{ display: 'flex', alignItems: 'center', gap: width * 0.018, color: RS.ink }}>
            <Icon name="globe" size={width * 0.05} stroke={2.2} />
            <svg width={width * 0.07} height={width * 0.05} viewBox="0 0 24 16"><rect x="1" y="3" width="20" height="10" rx="2.5" fill="none" stroke={RS.ink} strokeWidth="1.6"/><rect x="3" y="5" width="14" height="6" rx="1" fill={RS.ink}/><rect x="22" y="6" width="1.6" height="4" rx="0.8" fill={RS.ink}/></svg>
          </div>
        </div>
        {/* screen content */}
        <div style={{ flex: 1, position: 'relative', overflow: 'hidden', display: 'flex', flexDirection: 'column' }}>
          {children}
        </div>
        {/* gesture pill */}
        <div style={{ height: width * 0.08, flexShrink: 0, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
          <div style={{ width: width * 0.32, height: width * 0.013, borderRadius: 100, background: 'rgba(255,255,255,0.4)' }} />
        </div>
      </div>
      {label && <div style={{ fontFamily: RS.display, fontSize: 14, fontWeight: 600, color: '#3a4656' }}>{label}</div>}
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// Windows 11 style window — compact, button centered, not fullscreen
// ─────────────────────────────────────────────────────────────
function WinWindow({ children, width = 460, height = 520, label }) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 14 }}>
      <div style={{
        width, height, borderRadius: 10, overflow: 'hidden', background: RS.navy,
        border: '1px solid rgba(255,255,255,0.10)',
        boxShadow: '0 40px 90px -30px rgba(0,0,0,0.6)',
        fontFamily: RS.font, display: 'flex', flexDirection: 'column', boxSizing: 'border-box',
      }}>
        {/* title bar */}
        <div style={{
          height: 40, flexShrink: 0, display: 'flex', alignItems: 'center',
          justifyContent: 'space-between', padding: '0 0 0 14px',
          background: RS.navy2, borderBottom: `1px solid ${RS.line}`,
        }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 9 }}>
            <RSLogo size={17} />
            <span style={{ color: RS.dim, fontSize: 12.5, fontWeight: 600, fontFamily: RS.display }}>RadarShield</span>
          </div>
          <div style={{ display: 'flex', height: '100%' }}>
            {['minus', 'square', 'x'].map((n, i) => (
              <div key={n} style={{
                width: 44, height: '100%', display: 'flex', alignItems: 'center', justifyContent: 'center',
                color: RS.mute,
              }}>
                <Icon name={n} size={n === 'square' ? 11 : 13} stroke={1.6} />
              </div>
            ))}
          </div>
        </div>
        {/* content */}
        <div style={{ flex: 1, position: 'relative', overflow: 'hidden', display: 'flex', flexDirection: 'column' }}>
          {children}
        </div>
      </div>
      {label && <div style={{ fontFamily: RS.display, fontSize: 14, fontWeight: 600, color: '#3a4656' }}>{label}</div>}
    </div>
  );
}

Object.assign(window, { RS, Icon, RSLogo, Phone, WinWindow });

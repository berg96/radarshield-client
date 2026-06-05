// screens.jsx — RadarShield client screens + the PowerButton centerpiece
// Depends on window.RS, Icon, RSLogo (from frame.jsx)
// Exports: PowerButton, MainScreen, SplashScreen, OnboardingScreen,
//          SettingsScreen, ExpiredScreen, AdvancedStub, STATE_INFO

// hex -> rgba
function withA(hex, a) {
  const h = hex.replace('#', '');
  const r = parseInt(h.substring(0, 2), 16);
  const g = parseInt(h.substring(2, 4), 16);
  const b = parseInt(h.substring(4, 6), 16);
  return `rgba(${r},${g},${b},${a})`;
}

// one-time keyframes
(function injectRSStyles() {
  if (document.getElementById('rs-kf')) return;
  const s = document.createElement('style');
  s.id = 'rs-kf';
  s.textContent = `
    @keyframes rs-spin { to { transform: rotate(360deg); } }
    @keyframes rs-sonar {
      0%   { transform: scale(1);   opacity: 0.55; }
      70%  { opacity: 0; }
      100% { transform: scale(1.9); opacity: 0; }
    }
    @keyframes rs-breathe {
      0%,100% { transform: scale(1);    }
      50%     { transform: scale(1.035); }
    }
    @keyframes rs-pulse-soft {
      0%,100% { opacity: 0.5; }
      50%     { opacity: 1; }
    }
    .rs-tap { -webkit-tap-highlight-color: transparent; user-select: none; cursor: pointer; }
    .rs-tap:active .rs-core { transform: scale(0.96); }
  `;
  document.head.appendChild(s);
})();

const STATE_INFO = {
  off:        { word: 'Пуск',          sub: 'Нажмите, чтобы подключиться',         icon: 'power',        key: 'off' },
  connecting: { word: 'Подключаюсь…',  sub: 'Устанавливаем защищённое соединение', icon: 'power',        key: 'connecting' },
  connected:  { word: 'Подключено',    sub: 'Соединение защищено',                  icon: 'shieldcheck',  key: 'connected' },
  error:      { word: 'Не получилось',  sub: 'Нажмите ещё раз',                      icon: 'alert',        key: 'error' },
};

function stateColor(state, connectedColor, connectingColor) {
  if (state === 'off') return RS.off;
  if (state === 'connecting') return connectingColor || RS.connecting;
  if (state === 'connected') return connectedColor || RS.connected;
  if (state === 'error') return RS.error;
  return RS.off;
}

// ─────────────────────────────────────────────────────────────
// PowerButton — the centerpiece. style: minimal | radar | glow
// ─────────────────────────────────────────────────────────────
function PowerButton({ state = 'off', styleVariant = 'radar', connectedColor = RS.connected, connectingColor = RS.connecting, size = 200, onTap }) {
  const color = stateColor(state, connectedColor, connectingColor);
  const info = STATE_INFO[state];
  const active = state === 'connected';
  const connecting = state === 'connecting';

  // core circle styling per variant
  const ring = Math.max(2, size * 0.018);
  const coreBase = {
    width: size, height: size, borderRadius: '50%',
    display: 'flex', alignItems: 'center', justifyContent: 'center',
    position: 'relative', boxSizing: 'border-box',
    transition: 'background 600ms ease, border-color 600ms ease, box-shadow 600ms ease, transform 180ms ease',
  };
  let coreStyle;
  if (styleVariant === 'glow') {
    coreStyle = {
      ...coreBase,
      background: `radial-gradient(circle at 50% 42%, ${withA(color, 0.45)}, ${withA(color, 0.12)} 70%)`,
      border: `${ring}px solid ${withA(color, 0.9)}`,
      boxShadow: `0 0 ${size * 0.5}px ${withA(color, active ? 0.55 : 0.4)}, 0 0 ${size * 0.16}px ${withA(color, 0.6)} inset`,
    };
  } else if (styleVariant === 'minimal') {
    coreStyle = {
      ...coreBase,
      background: withA(color, 0.12),
      border: `${ring}px solid ${withA(color, 0.85)}`,
      boxShadow: 'none',
    };
  } else { // radar
    coreStyle = {
      ...coreBase,
      background: `radial-gradient(circle at 50% 45%, ${withA(color, 0.22)}, ${withA(color, 0.06)} 72%)`,
      border: `${ring}px solid ${withA(color, 0.85)}`,
      boxShadow: `0 0 ${size * 0.22}px ${withA(color, active ? 0.4 : 0.22)}`,
    };
  }

  const breathe = active ? 'rs-breathe 4s ease-in-out infinite' : 'none';

  return (
    <div className="rs-tap" onClick={onTap} style={{
      display: 'flex', flexDirection: 'column', alignItems: 'center',
      position: 'relative', width: size * 1.2, height: size * 1.2,
      justifyContent: 'center',
    }}>
      {/* sonar rings (radar variant, when connecting/connected) */}
      {styleVariant === 'radar' && (connecting || active) && [0, 1, 2].map(i => (
        <div key={i} style={{
          position: 'absolute', width: size, height: size, borderRadius: '50%',
          border: `${Math.max(1.5, size * 0.01)}px solid ${color}`,
          animation: `rs-sonar ${connecting ? 2.2 : 3.4}s ease-out ${i * (connecting ? 0.73 : 1.13)}s infinite`,
          pointerEvents: 'none',
        }} />
      ))}
      {/* glow variant ambient pulse when connecting */}
      {styleVariant === 'glow' && connecting && (
        <div style={{
          position: 'absolute', width: size * 1.4, height: size * 1.4, borderRadius: '50%',
          background: `radial-gradient(circle, ${withA(color, 0.3)}, transparent 65%)`,
          animation: 'rs-pulse-soft 1.4s ease-in-out infinite', pointerEvents: 'none',
        }} />
      )}

      {/* spinner arc while connecting */}
      {connecting && (
        <div style={{
          position: 'absolute', width: size + ring * 6, height: size + ring * 6, borderRadius: '50%',
          border: `${ring}px solid transparent`, borderTopColor: color, borderRightColor: withA(color, 0.4),
          animation: 'rs-spin 1s linear infinite', pointerEvents: 'none',
        }} />
      )}

      {/* core */}
      <div className="rs-core" style={{ ...coreStyle, animation: breathe }}>
        <Icon name={info.icon} size={size * 0.34} color={color} stroke={state === 'off' ? 2.4 : 2.6}
              style={{ transition: 'color 600ms ease' }} />
      </div>
    </div>
  );
}

// status text under the button
function StatusText({ state, connectedColor, connectingColor }) {
  const color = stateColor(state, connectedColor, connectingColor);
  const info = STATE_INFO[state];
  return (
    <div style={{ textAlign: 'center', marginTop: 6 }}>
      <div style={{
        fontFamily: RS.display, fontWeight: 800, fontSize: 24, letterSpacing: '-0.02em', whiteSpace: 'nowrap',
        color: state === 'off' ? RS.ink : color, transition: 'color 600ms ease',
      }}>{info.word}</div>
      <div style={{ color: RS.mute, fontSize: 14, marginTop: 6, maxWidth: 240, marginLeft: 'auto', marginRight: 'auto', lineHeight: 1.4 }}>
        {info.sub}
      </div>
    </div>
  );
}

// corner menu (gear opens settings / advanced; user logout)
function CornerMenu({ onSettings, onLogout }) {
  const btn = {
    width: 42, height: 42, borderRadius: 12, display: 'flex', alignItems: 'center', justifyContent: 'center',
    background: RS.panel, border: `1px solid ${RS.line}`, color: RS.dim, cursor: 'pointer',
  };
  return (
    <div style={{ display: 'flex', gap: 10 }}>
      <div style={btn} onClick={onLogout} title="Выйти из аккаунта"><Icon name="logout" size={19} stroke={2} /></div>
      <div style={btn} onClick={onSettings} title="Настройки"><Icon name="gear" size={19} stroke={2} /></div>
    </div>
  );
}

// small location chip
function LocationChip({ text = 'Россия · авто' }) {
  return (
    <div style={{
      display: 'inline-flex', alignItems: 'center', gap: 8, padding: '8px 14px',
      borderRadius: 999, background: RS.panel, border: `1px solid ${RS.line}`, color: RS.dim, fontSize: 13.5, fontWeight: 500,
    }}>
      <Icon name="globe" size={15} stroke={2} color={RS.amber} /> {text}
      <Icon name="chevron" size={14} stroke={2} color={RS.mute} />
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// MAIN screen
// ─────────────────────────────────────────────────────────────
function MainScreen({ state = 'off', styleVariant = 'radar', connectedColor = RS.connected, connectingColor = RS.connecting, extras = {}, onTap, onSettings, onLogout, onLocationTap, onDetails, btnSize = 200, sessionTime = '00:14:32' }) {
  const showTimer = extras.showTimer && state === 'connected';
  return (
    <div style={{ flex: 1, display: 'flex', flexDirection: 'column', padding: '14px 18px 22px', position: 'relative' }}>
      {/* top row: brand + corner menu */}
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 9 }}>
          <RSLogo size={22} />
          <span style={{ fontFamily: RS.display, fontWeight: 700, fontSize: 16, color: RS.ink, letterSpacing: '-0.01em' }}>RadarShield</span>
        </div>
        <CornerMenu onSettings={onSettings} onLogout={onLogout} />
      </div>

      {/* shield indicator pill */}
      {extras.showShield && (
        <div style={{ display: 'flex', justifyContent: 'center', marginTop: 16 }}>
          <div style={{
            display: 'inline-flex', alignItems: 'center', gap: 7, padding: '6px 12px', borderRadius: 999,
            background: state === 'connected' ? withA(connectedColor, 0.14) : RS.panel,
            border: `1px solid ${state === 'connected' ? withA(connectedColor, 0.4) : RS.line}`,
            color: state === 'connected' ? connectedColor : RS.mute, fontSize: 12.5, fontWeight: 600,
            transition: 'all 500ms ease',
          }}>
            <Icon name="shield" size={13} stroke={2.2} /> {state === 'connected' ? 'Защита активна' : 'Защита выключена'}
          </div>
        </div>
      )}

      {/* center button + status */}
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 4 }}>
        <PowerButton state={state} styleVariant={styleVariant} connectedColor={connectedColor} connectingColor={connectingColor} size={btnSize} onTap={onTap} />
        <StatusText state={state} connectedColor={connectedColor} connectingColor={connectingColor} />
        {state === 'connected' && onDetails && (
          <div onClick={onDetails} className="rs-tap" style={{ display: 'inline-flex', alignItems: 'center', gap: 6, marginTop: 10, padding: '6px 12px', borderRadius: 999, background: RS.panel, border: `1px solid ${RS.line}`, color: RS.dim, fontSize: 12.5, fontWeight: 600, cursor: 'pointer' }}>
            <Icon name="info" size={14} stroke={2} color={RS.amber} /> Детали соединения
          </div>
        )}
        {showTimer && (
          <div style={{ display: 'inline-flex', alignItems: 'center', gap: 7, marginTop: 12, color: RS.dim, fontSize: 14, fontFamily: RS.display, fontWeight: 600 }}>
            <Icon name="clock" size={15} stroke={2} color={RS.mute} /> {sessionTime}
          </div>
        )}
      </div>

      {/* bottom: location */}
      <div style={{ display: 'flex', justifyContent: 'center', minHeight: 38 }}>
        {extras.showLocation && (
          <div onClick={onLocationTap} className={onLocationTap ? 'rs-tap' : ''} style={{ cursor: onLocationTap ? 'pointer' : 'default' }}>
            <LocationChip />
          </div>
        )}
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// SPLASH
// ─────────────────────────────────────────────────────────────
function SplashScreen() {
  return (
    <div style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 22, position: 'relative' }}>
      {/* faint radar rings */}
      {[0.5, 0.74, 1.0].map((s, i) => (
        <div key={i} style={{
          position: 'absolute', width: 320 * s, height: 320 * s, borderRadius: '50%',
          border: `1px solid ${withA(RS.amber, 0.12 - i * 0.025)}`,
        }} />
      ))}
      <div style={{ position: 'relative', filter: `drop-shadow(0 0 26px ${withA(RS.amber, 0.4)})` }}>
        <RSLogo size={92} />
      </div>
      <div style={{ fontFamily: RS.display, fontWeight: 800, fontSize: 27, color: RS.ink, letterSpacing: '-0.02em' }}>RadarShield</div>
      <div style={{ position: 'absolute', bottom: 40, display: 'flex', gap: 6 }}>
        {[0, 1, 2].map(i => (
          <div key={i} style={{ width: 7, height: 7, borderRadius: '50%', background: RS.amber, animation: `rs-pulse-soft 1.2s ease-in-out ${i * 0.2}s infinite` }} />
        ))}
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// ONBOARDING — paste subscription link
// ─────────────────────────────────────────────────────────────
function OnboardingScreen({ filled = false, onContinue, onPaste }) {
  return (
    <div style={{ flex: 1, display: 'flex', flexDirection: 'column', padding: '20px 22px 26px' }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 9, marginTop: 6 }}>
        <RSLogo size={24} />
        <span style={{ fontFamily: RS.display, fontWeight: 700, fontSize: 16, color: RS.ink }}>RadarShield</span>
      </div>

      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', justifyContent: 'center', gap: 0 }}>
        <div style={{ width: 60, height: 60, borderRadius: 18, background: withA(RS.amber, 0.12), border: `1px solid ${withA(RS.amber, 0.3)}`, display: 'flex', alignItems: 'center', justifyContent: 'center', marginBottom: 22 }}>
          <Icon name="link" size={26} color={RS.amber} stroke={2} />
        </div>
        <h2 style={{ fontFamily: RS.display, fontWeight: 800, fontSize: 25, color: RS.ink, margin: 0, letterSpacing: '-0.02em', lineHeight: 1.15 }}>Вставьте ссылку<br/>подписки</h2>
        <p style={{ color: RS.dim, fontSize: 14.5, lineHeight: 1.5, marginTop: 12, marginBottom: 26 }}>
          Откройте нашего бота в Telegram и скопируйте ссылку. Вставьте её сюда — остальное сделаем сами.
        </p>

        {/* input */}
        <div onClick={onPaste} className="rs-tap" style={{
          display: 'flex', alignItems: 'center', gap: 10, padding: '15px 16px', borderRadius: 14,
          background: RS.panel, border: `1.5px solid ${filled ? withA(RS.amber, 0.5) : RS.line2}`,
          transition: 'border-color 300ms ease',
        }}>
          <Icon name="link" size={18} color={RS.mute} stroke={2} />
          <span style={{ flex: 1, fontSize: 14.5, color: filled ? RS.ink : RS.mute, fontFamily: 'ui-monospace, monospace', overflow: 'hidden', whiteSpace: 'nowrap', textOverflow: 'ellipsis' }}>
            {filled ? 'rs://sub/8f3a…k29q' : 'rs://подписка…'}
          </span>
          <div onClick={(e) => { e.stopPropagation(); onPaste && onPaste(); }} style={{ display: 'flex', alignItems: 'center', gap: 6, padding: '6px 10px', borderRadius: 9, background: withA(RS.amber, 0.14), color: RS.amber, fontSize: 12.5, fontWeight: 700, cursor: 'pointer' }}>
            <Icon name="clipboard" size={14} stroke={2} /> Вставить
          </div>
        </div>
      </div>

      {/* continue */}
      <button onClick={onContinue} style={{
        width: '100%', padding: '16px', borderRadius: 14, border: 'none',
        background: filled ? RS.amber : withA('#ffffff', 0.07),
        color: filled ? RS.navy : RS.mute, fontFamily: RS.display, fontWeight: 700, fontSize: 16,
        cursor: 'pointer', transition: 'all 300ms ease', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8,
      }}>
        Продолжить <Icon name="chevron" size={18} stroke={2.4} />
      </button>
      <div style={{ textAlign: 'center', marginTop: 16, color: RS.mute, fontSize: 13 }}>
        Нет ссылки? <span style={{ color: RS.amber, fontWeight: 600 }}>Открыть Telegram-бота</span>
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// SETTINGS — hidden zone, simple list
// ─────────────────────────────────────────────────────────────
function SettingRow({ icon, title, sub, right, danger, onClick }) {
  return (
    <div onClick={onClick} className={onClick ? 'rs-tap' : ''} style={{ display: 'flex', alignItems: 'center', gap: 14, padding: '15px 16px' }}>
      <div style={{ width: 38, height: 38, borderRadius: 11, background: danger ? withA(RS.error, 0.12) : RS.panel2, display: 'flex', alignItems: 'center', justifyContent: 'center', color: danger ? RS.error : RS.amber, flexShrink: 0 }}>
        <Icon name={icon} size={18} stroke={2} />
      </div>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ fontSize: 15, color: danger ? RS.error : RS.ink, fontWeight: 500 }}>{title}</div>
        {sub && <div style={{ fontSize: 12.5, color: RS.mute, marginTop: 2 }}>{sub}</div>}
      </div>
      {right}
    </div>
  );
}

function Toggle({ on }) {
  return (
    <div style={{ width: 44, height: 26, borderRadius: 99, background: on ? RS.amber : 'rgba(255,255,255,0.14)', position: 'relative', transition: 'background 200ms', flexShrink: 0 }}>
      <div style={{ position: 'absolute', top: 3, left: on ? 21 : 3, width: 20, height: 20, borderRadius: '50%', background: '#fff', transition: 'left 200ms' }} />
    </div>
  );
}

function SettingsScreen({ onBack, onSplitTunnel, onDiagnostics, onLocation }) {
  const [killSwitch, setKill] = React.useState(false);
  const [statusNotif, setNotif] = React.useState(true);
  return (
    <div style={{ flex: 1, display: 'flex', flexDirection: 'column', overflowY: 'auto' }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 14, padding: '16px 18px' }}>
        <div onClick={onBack} className="rs-tap" style={{ width: 38, height: 38, borderRadius: 11, background: RS.panel, border: `1px solid ${RS.line}`, display: 'flex', alignItems: 'center', justifyContent: 'center', color: RS.dim, cursor: 'pointer', transform: 'scaleX(-1)' }}>
          <Icon name="chevron" size={18} stroke={2.2} />
        </div>
        <span style={{ fontFamily: RS.display, fontWeight: 800, fontSize: 21, color: RS.ink }}>Настройки</span>
      </div>

      {/* account card */}
      <div style={{ margin: '6px 16px 14px', padding: 16, borderRadius: 16, background: RS.panel, border: `1px solid ${RS.line}`, display: 'flex', alignItems: 'center', gap: 13 }}>
        <div style={{ width: 44, height: 44, borderRadius: '50%', background: withA(RS.amber, 0.14), display: 'flex', alignItems: 'center', justifyContent: 'center', color: RS.amber }}>
          <Icon name="user" size={22} stroke={2} />
        </div>
        <div style={{ flex: 1 }}>
          <div style={{ fontSize: 15, color: RS.ink, fontWeight: 600 }}>Подписка активна</div>
          <div style={{ fontSize: 12.5, color: RS.mute, marginTop: 2 }}>до 14 июля 2026 · 5 ГБ из 50</div>
        </div>
        <div style={{ fontSize: 12.5, fontWeight: 700, color: RS.amber }}>Продлить</div>
      </div>

      {/* connection group */}
      <div style={{ fontSize: 12, color: RS.mute, fontWeight: 600, letterSpacing: '0.04em', textTransform: 'uppercase', margin: '4px 22px 8px' }}>Соединение</div>
      <div style={{ background: RS.panel, margin: '0 16px', borderRadius: 16, border: `1px solid ${RS.line}`, overflow: 'hidden' }}>
        <SettingRow icon="globe" title="Локация" sub="Россия · авто" onClick={onLocation} right={<Icon name="chevron" size={18} color={RS.mute} stroke={2} />} />
        <div style={{ height: 1, background: RS.line, marginLeft: 68 }} />
        <SettingRow icon="bolt" title="Автоподключение" sub="При запуске системы" right={<Toggle on={true} />} />
        <div style={{ height: 1, background: RS.line, marginLeft: 68 }} />
        <SettingRow icon="shield" title="Kill-switch" sub="Блокировать интернет, если VPN отключился" right={<div onClick={() => setKill(v => !v)} className="rs-tap"><Toggle on={killSwitch} /></div>} />
        <div style={{ height: 1, background: RS.line, marginLeft: 68 }} />
        <SettingRow icon="sliders" title="Раздельный туннель" sub="Какие приложения идут мимо VPN" onClick={onSplitTunnel} right={<Icon name="chevron" size={18} color={RS.mute} stroke={2} />} />
      </div>

      {/* app group */}
      <div style={{ fontSize: 12, color: RS.mute, fontWeight: 600, letterSpacing: '0.04em', textTransform: 'uppercase', margin: '18px 22px 8px' }}>Приложение</div>
      <div style={{ background: RS.panel, margin: '0 16px', borderRadius: 16, border: `1px solid ${RS.line}`, overflow: 'hidden' }}>
        <SettingRow icon="info" title="Уведомление о статусе" sub="Постоянная нотификация VPN" right={<div onClick={() => setNotif(v => !v)} className="rs-tap"><Toggle on={statusNotif} /></div>} />
        <div style={{ height: 1, background: RS.line, marginLeft: 68 }} />
        <SettingRow icon="language" title="Язык" sub="Русский" right={<Icon name="chevron" size={18} color={RS.mute} stroke={2} />} />
        <div style={{ height: 1, background: RS.line, marginLeft: 68 }} />
        <SettingRow icon="refresh" title="Диагностика" sub="Журнал и помощь поддержке" onClick={onDiagnostics} right={<Icon name="chevron" size={18} color={RS.mute} stroke={2} />} />
        <div style={{ height: 1, background: RS.line, marginLeft: 68 }} />
        <SettingRow icon="info" title="О приложении" sub="Версия 1.0.0" right={<Icon name="chevron" size={18} color={RS.mute} stroke={2} />} />
      </div>

      <div style={{ background: RS.panel, margin: '14px 16px 18px', borderRadius: 16, border: `1px solid ${RS.line}`, overflow: 'hidden' }}>
        <SettingRow icon="logout" title="Выйти из аккаунта" danger />
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// EXPIRED — subscription ended
// ─────────────────────────────────────────────────────────────
function ExpiredScreen({ onRenew }) {
  return (
    <div style={{ flex: 1, display: 'flex', flexDirection: 'column', padding: '18px 22px 26px' }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 9, marginTop: 6 }}>
        <RSLogo size={22} />
        <span style={{ fontFamily: RS.display, fontWeight: 700, fontSize: 16, color: RS.ink }}>RadarShield</span>
      </div>
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', textAlign: 'center' }}>
        <div style={{ position: 'relative', marginBottom: 26 }}>
          <div style={{ width: 130, height: 130, borderRadius: '50%', background: withA(RS.off, 0.1), border: `2px solid ${withA(RS.off, 0.3)}`, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <Icon name="clock" size={56} color={RS.off} stroke={1.8} />
          </div>
        </div>
        <h2 style={{ fontFamily: RS.display, fontWeight: 800, fontSize: 24, color: RS.ink, margin: 0, letterSpacing: '-0.02em' }}>Подписка закончилась</h2>
        <p style={{ color: RS.dim, fontSize: 14.5, lineHeight: 1.5, marginTop: 12, maxWidth: 260 }}>
          Продлите подписку, чтобы снова пользоваться защищённым соединением. Это займёт минуту.
        </p>
      </div>
      <button onClick={onRenew} style={{
        width: '100%', padding: 16, borderRadius: 14, border: 'none', background: RS.amber, color: RS.navy,
        fontFamily: RS.display, fontWeight: 700, fontSize: 16, cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8,
      }}>
        Продлить подписку <Icon name="chevron" size={18} stroke={2.4} />
      </button>
      <div style={{ textAlign: 'center', marginTop: 16, color: RS.mute, fontSize: 13 }}>
        Оплата через <span style={{ color: RS.ink, fontWeight: 600 }}>Telegram-бота</span>
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// ADVANCED stub (FLClash-style hint)
// ─────────────────────────────────────────────────────────────
function AdvancedStub() {
  const rows = ['Германия · Франкфурт', 'Нидерланды · Амстердам', 'Финляндия · Хельсинки', 'США · Нью-Йорк'];
  return (
    <div style={{ flex: 1, display: 'flex', flexDirection: 'column', padding: '14px 14px' }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '4px 4px 14px' }}>
        <Icon name="sliders" size={18} color={RS.amber} stroke={2} />
        <span style={{ fontFamily: RS.display, fontWeight: 700, fontSize: 15, color: RS.ink }}>Продвинутый режим</span>
        <span style={{ marginLeft: 'auto', fontSize: 11, color: RS.mute, padding: '3px 8px', borderRadius: 6, background: RS.panel, border: `1px solid ${RS.line}` }}>FLClash</span>
      </div>
      <div style={{ display: 'flex', gap: 7, marginBottom: 12, flexWrap: 'wrap' }}>
        {['Прокси', 'Профили', 'Маршруты', 'Логи'].map((t, i) => (
          <div key={t} style={{ fontSize: 11.5, padding: '6px 10px', borderRadius: 8, background: i === 0 ? withA(RS.amber, 0.14) : RS.panel, color: i === 0 ? RS.amber : RS.mute, border: `1px solid ${i === 0 ? withA(RS.amber, 0.3) : RS.line}`, fontWeight: 600 }}>{t}</div>
        ))}
      </div>
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: 8 }}>
        {rows.map((r, i) => (
          <div key={r} style={{ display: 'flex', alignItems: 'center', gap: 11, padding: '12px 14px', borderRadius: 12, background: RS.panel, border: `1px solid ${i === 0 ? withA(RS.connected, 0.4) : RS.line}` }}>
            <div style={{ width: 9, height: 9, borderRadius: '50%', background: i === 0 ? RS.connected : RS.mute }} />
            <span style={{ flex: 1, fontSize: 13.5, color: RS.ink }}>{r}</span>
            <span style={{ fontSize: 12, color: RS.mute, fontFamily: 'ui-monospace, monospace' }}>{[24, 38, 52, 121][i]} ms</span>
          </div>
        ))}
      </div>
      <div style={{ textAlign: 'center', fontSize: 12, color: RS.mute, padding: 10 }}>Технический UI для опытных пользователей</div>
    </div>
  );
}

Object.assign(window, {
  PowerButton, MainScreen, SplashScreen, OnboardingScreen, SettingsScreen, ExpiredScreen, AdvancedStub, STATE_INFO, withA,
  SettingRow, Toggle, LocationChip, stateColor,
});

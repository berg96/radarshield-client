// screens2.jsx — "advanced-in-our-style" screens per BRIEF-advanced
// Depends on window.RS, Icon, RSLogo, Flag, withA, Toggle, SettingRow
// Exports: LocationScreen, ConnectionDetails, DiagnosticsScreen, SplitTunnelScreen

const { useState: useS2 } = React;

// shared sub-header with back
function SubHeader({ title, onBack, action }) {
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 14, padding: '16px 18px', flexShrink: 0 }}>
      <div onClick={onBack} className="rs-tap" style={{ width: 38, height: 38, borderRadius: 11, background: RS.panel, border: `1px solid ${RS.line}`, display: 'flex', alignItems: 'center', justifyContent: 'center', color: RS.dim, cursor: 'pointer', transform: 'scaleX(-1)' }}>
        <Icon name="chevron" size={18} stroke={2.2} />
      </div>
      <span style={{ fontFamily: RS.display, fontWeight: 800, fontSize: 21, color: RS.ink, flex: 1 }}>{title}</span>
      {action}
    </div>
  );
}

// signal quality bars
function Signal({ level = 3, color = RS.connected }) {
  return (
    <div style={{ display: 'flex', alignItems: 'flex-end', gap: 2, height: 14 }}>
      {[6, 9, 12, 14].map((h, i) => (
        <div key={i} style={{ width: 3, height: h, borderRadius: 1, background: i < level ? color : 'rgba(255,255,255,0.16)' }} />
      ))}
    </div>
  );
}

function pingColor(ms) {
  if (ms == null) return RS.mute;
  if (ms < 40) return RS.connected;
  if (ms < 90) return RS.amber;
  return '#e8915b';
}

// ─────────────────────────────────────────────────────────────
// 1. LOCATION / SERVER PICKER
// ─────────────────────────────────────────────────────────────
const NODES = [
  { code: 'DE', country: 'Германия', city: 'Франкфурт', ping: 24, level: 4 },
  { code: 'NL', country: 'Нидерланды', city: 'Амстердам', ping: 38, level: 4 },
  { code: 'FI', country: 'Финляндия', city: 'Хельсинки', ping: 52, level: 3 },
  { code: 'US', country: 'США', city: 'Нью-Йорк', ping: 121, level: 2 },
];

function LocationScreen({ onBack, selected = 'auto', onSelect, loading = false, downNode = null }) {
  const [sel, setSel] = useS2(selected);
  const [pinging, setPinging] = useS2(loading);
  const pick = (k) => { setSel(k); onSelect && onSelect(k); };
  const refresh = () => { setPinging(true); setTimeout(() => setPinging(false), 1400); };

  const Radio = ({ on }) => (
    <div style={{ width: 20, height: 20, borderRadius: '50%', border: `2px solid ${on ? RS.connected : RS.line2}`, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0, transition: 'border-color 200ms' }}>
      {on && <div style={{ width: 10, height: 10, borderRadius: '50%', background: RS.connected }} />}
    </div>
  );

  return (
    <div style={{ flex: 1, display: 'flex', flexDirection: 'column' }}>
      <SubHeader title="Локация" onBack={onBack}
        action={<div onClick={refresh} className="rs-tap" style={{ width: 38, height: 38, borderRadius: 11, background: RS.panel, border: `1px solid ${RS.line}`, display: 'flex', alignItems: 'center', justifyContent: 'center', color: pinging ? RS.amber : RS.dim, cursor: 'pointer' }}>
          <Icon name="refresh" size={18} stroke={2} style={pinging ? { animation: 'rs-spin 1s linear infinite' } : null} />
        </div>} />

      <div style={{ flex: 1, overflowY: 'auto', padding: '0 16px 16px' }}>
        {/* AUTO */}
        <div onClick={() => pick('auto')} className="rs-tap" style={{
          display: 'flex', alignItems: 'center', gap: 13, padding: '15px 16px', borderRadius: 14, marginBottom: 14,
          background: sel === 'auto' ? withA(RS.connected, 0.08) : RS.panel,
          border: `1.5px solid ${sel === 'auto' ? withA(RS.connected, 0.45) : RS.line}`, transition: 'all 200ms',
        }}>
          <div style={{ width: 38, height: 38, borderRadius: 11, background: withA(RS.amber, 0.14), display: 'flex', alignItems: 'center', justifyContent: 'center', color: RS.amber, flexShrink: 0 }}>
            <Icon name="bolt" size={19} stroke={2} />
          </div>
          <div style={{ flex: 1 }}>
            <div style={{ fontSize: 15, color: RS.ink, fontWeight: 600 }}>Авто</div>
            <div style={{ fontSize: 12.5, color: RS.mute, marginTop: 2 }}>Лучший сервер по скорости</div>
          </div>
          <Radio on={sel === 'auto'} />
        </div>

        <div style={{ fontSize: 12, color: RS.mute, fontWeight: 600, letterSpacing: '0.04em', textTransform: 'uppercase', margin: '4px 6px 8px' }}>Серверы</div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
          {NODES.map((n) => {
            const down = downNode === n.code;
            const on = sel === n.code;
            return (
              <div key={n.code} onClick={() => !down && pick(n.code)} className={down ? '' : 'rs-tap'} style={{
                display: 'flex', alignItems: 'center', gap: 11, padding: '13px 14px', borderRadius: 14,
                background: on ? withA(RS.connected, 0.08) : RS.panel,
                border: `1.5px solid ${on ? withA(RS.connected, 0.45) : RS.line}`,
                opacity: down ? 0.5 : 1, transition: 'all 200ms',
              }}>
                <Flag code={n.code} size={26} />
                <div style={{ flex: 1, minWidth: 0, overflow: 'hidden' }}>
                  <div style={{ fontSize: 14.5, color: RS.ink, fontWeight: 600, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{n.country}</div>
                  <div style={{ fontSize: 12, color: RS.mute, marginTop: 1, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{n.city}</div>
                </div>
                {down ? (
                  <span style={{ fontSize: 12, color: RS.mute, flexShrink: 0 }}>недоступен</span>
                ) : (
                  <div style={{ display: 'flex', alignItems: 'center', gap: 8, flexShrink: 0 }}>
                    <Signal level={n.level} color={pingColor(n.ping)} />
                    <span style={{ fontSize: 11.5, fontFamily: 'ui-monospace, monospace', color: pinging ? RS.mute : pingColor(n.ping), minWidth: 34, textAlign: 'right' }}>
                      {pinging ? '···' : `${n.ping} ms`}
                    </span>
                  </div>
                )}
                {!down && <Radio on={on} />}
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// 2. CONNECTION DETAILS (bottom sheet)
// ─────────────────────────────────────────────────────────────
function ConnectionDetails({ onClose, onChangeServer, server = { code: 'DE', country: 'Германия', city: 'Франкфурт' }, ip = '5.181.20.114', session = '00:14:32', up = '48,2 МБ', down = '312,7 МБ' }) {
  const Stat = ({ icon, label, value, mono }) => (
    <div style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '13px 0' }}>
      <div style={{ width: 34, height: 34, borderRadius: 10, background: RS.panel2, display: 'flex', alignItems: 'center', justifyContent: 'center', color: RS.amber, flexShrink: 0 }}>
        <Icon name={icon} size={16} stroke={2} />
      </div>
      <span style={{ flex: 1, fontSize: 13.5, color: RS.dim }}>{label}</span>
      <span style={{ fontSize: 13.5, color: RS.ink, fontWeight: 600, fontFamily: mono ? 'ui-monospace, monospace' : RS.font }}>{value}</span>
    </div>
  );
  return (
    <div style={{ position: 'absolute', inset: 0, zIndex: 30, display: 'flex', flexDirection: 'column', justifyContent: 'flex-end' }}>
      <div onClick={onClose} style={{ position: 'absolute', inset: 0, background: 'rgba(0,0,0,0.5)' }} />
      <div style={{ position: 'relative', background: RS.navy2, borderTop: `1px solid ${RS.line2}`, borderRadius: '22px 22px 0 0', padding: '12px 20px 24px', boxShadow: '0 -20px 50px rgba(0,0,0,0.4)' }}>
        <div style={{ width: 40, height: 4, borderRadius: 99, background: 'rgba(255,255,255,0.2)', margin: '0 auto 18px' }} />
        <div style={{ display: 'flex', alignItems: 'center', gap: 11, marginBottom: 6 }}>
          <div style={{ width: 9, height: 9, borderRadius: '50%', background: RS.connected, boxShadow: `0 0 10px ${RS.connected}` }} />
          <span style={{ fontFamily: RS.display, fontWeight: 800, fontSize: 19, color: RS.ink }}>Соединение защищено</span>
        </div>
        <div style={{ marginTop: 8 }}>
          <Stat icon="globe" label="Сервер" value={<span style={{ display: 'inline-flex', alignItems: 'center', gap: 7, whiteSpace: 'nowrap' }}><Flag code={server.code} size={18} />{server.country}</span>} />
          <div style={{ height: 1, background: RS.line }} />
          <Stat icon="user" label="Город" value={server.city} />
          <div style={{ height: 1, background: RS.line }} />
          <Stat icon="user" label="Ваш видимый IP" value={ip} mono />
          <div style={{ height: 1, background: RS.line }} />
          <Stat icon="shield" label="Протокол" value="Защищённый" />
          <div style={{ height: 1, background: RS.line }} />
          <Stat icon="clock" label="Время сессии" value={session} mono />
          <div style={{ height: 1, background: RS.line }} />
          <div style={{ display: 'flex', gap: 10, padding: '13px 0 4px' }}>
            <div style={{ flex: 1, display: 'flex', alignItems: 'center', gap: 9, padding: '10px 12px', borderRadius: 11, background: RS.panel, border: `1px solid ${RS.line}` }}>
              <Icon name="download" size={16} color={RS.connected} stroke={2.2} />
              <div><div style={{ fontSize: 11, color: RS.mute }}>Загружено</div><div style={{ fontSize: 13.5, color: RS.ink, fontWeight: 600, fontFamily: 'ui-monospace, monospace' }}>{down}</div></div>
            </div>
            <div style={{ flex: 1, display: 'flex', alignItems: 'center', gap: 9, padding: '10px 12px', borderRadius: 11, background: RS.panel, border: `1px solid ${RS.line}` }}>
              <Icon name="upload" size={16} color={RS.amber} stroke={2.2} />
              <div><div style={{ fontSize: 11, color: RS.mute }}>Отправлено</div><div style={{ fontSize: 13.5, color: RS.ink, fontWeight: 600, fontFamily: 'ui-monospace, monospace' }}>{up}</div></div>
            </div>
          </div>
        </div>
        <button onClick={onChangeServer} style={{ width: '100%', marginTop: 16, padding: 15, borderRadius: 13, border: `1px solid ${RS.line2}`, background: RS.panel, color: RS.ink, fontFamily: RS.display, fontWeight: 700, fontSize: 15, cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8 }}>
          <Icon name="swap" size={17} stroke={2} color={RS.amber} /> Сменить сервер
        </button>
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// 3. DIAGNOSTICS / LOG
// ─────────────────────────────────────────────────────────────
const LOG = [
  { t: '14:32:08', kind: 'ok', text: 'Подключено · Германия, Франкфурт' },
  { t: '14:32:06', kind: 'info', text: 'Проверка серверов — выбран лучший' },
  { t: '14:31:50', kind: 'off', text: 'Отключено пользователем' },
  { t: '11:08:22', kind: 'err', text: 'Сервер не ответил — переключение' },
  { t: '11:08:19', kind: 'ok', text: 'Подключено · Нидерланды, Амстердам' },
];
const LOG_COLOR = { ok: RS.connected, info: RS.amber, off: RS.mute, err: RS.error };

function DiagnosticsScreen({ onBack }) {
  const [copied, setCopied] = useS2(false);
  const copy = () => { setCopied(true); setTimeout(() => setCopied(false), 1800); };
  return (
    <div style={{ flex: 1, display: 'flex', flexDirection: 'column' }}>
      <SubHeader title="Диагностика" onBack={onBack} />
      <div style={{ flex: 1, overflowY: 'auto', padding: '0 16px 16px' }}>
        {/* status card */}
        <div style={{ padding: 16, borderRadius: 16, background: RS.panel, border: `1px solid ${RS.line}`, marginBottom: 14 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
            <div style={{ width: 9, height: 9, borderRadius: '50%', background: RS.connected }} />
            <span style={{ fontSize: 14.5, color: RS.ink, fontWeight: 600 }}>Последнее подключение — успешно</span>
          </div>
          <div style={{ display: 'flex', gap: 24, marginTop: 14 }}>
            <div><div style={{ fontSize: 11.5, color: RS.mute }}>Версия</div><div style={{ fontSize: 13.5, color: RS.dim, fontWeight: 600, marginTop: 3, fontFamily: 'ui-monospace, monospace' }}>1.0.0 (build 142)</div></div>
            <div><div style={{ fontSize: 11.5, color: RS.mute }}>ID устройства</div><div style={{ fontSize: 13.5, color: RS.dim, fontWeight: 600, marginTop: 3, fontFamily: 'ui-monospace, monospace' }}>RS-7F3A-K29Q</div></div>
          </div>
        </div>

        <div style={{ fontSize: 12, color: RS.mute, fontWeight: 600, letterSpacing: '0.04em', textTransform: 'uppercase', margin: '4px 6px 8px' }}>Журнал событий</div>
        <div style={{ background: RS.panel, borderRadius: 14, border: `1px solid ${RS.line}`, overflow: 'hidden' }}>
          {LOG.map((e, i) => (
            <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '12px 15px', borderTop: i ? `1px solid ${RS.line}` : 'none' }}>
              <div style={{ width: 8, height: 8, borderRadius: '50%', background: LOG_COLOR[e.kind], flexShrink: 0 }} />
              <span style={{ flex: 1, fontSize: 13, color: RS.dim }}>{e.text}</span>
              <span style={{ fontSize: 11.5, color: RS.mute, fontFamily: 'ui-monospace, monospace' }}>{e.t}</span>
            </div>
          ))}
        </div>
      </div>

      <div style={{ padding: '8px 16px 18px', display: 'flex', flexDirection: 'column', gap: 10 }}>
        <button onClick={copy} style={{ width: '100%', padding: 15, borderRadius: 13, border: 'none', background: copied ? withA(RS.connected, 0.18) : RS.amber, color: copied ? RS.connected : RS.navy, fontFamily: RS.display, fontWeight: 700, fontSize: 15, cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8, transition: 'all 200ms' }}>
          <Icon name={copied ? 'check' : 'copy'} size={17} stroke={2.2} /> {copied ? 'Скопировано' : 'Скопировать для поддержки'}
        </button>
        <button style={{ width: '100%', padding: 15, borderRadius: 13, border: `1px solid ${RS.line2}`, background: 'transparent', color: RS.dim, fontFamily: RS.display, fontWeight: 700, fontSize: 15, cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8 }}>
          <Icon name="send" size={16} stroke={2} color={RS.amber} /> Отправить в Telegram-бот
        </button>
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// 4. SPLIT TUNNELING (Android)
// ─────────────────────────────────────────────────────────────
const APPS = [
  { name: 'Сбербанк', color: '#21a038', letter: 'С', on: false },
  { name: 'Telegram', color: '#2aabee', letter: 'T', on: true },
  { name: 'Госуслуги', color: '#ee3f58', letter: 'Г', on: false },
  { name: 'YouTube', color: '#ff0000', letter: 'Y', on: true },
  { name: 'WhatsApp', color: '#25d366', letter: 'W', on: true },
  { name: 'Тинькофф', color: '#ffdd2d', letter: 'Т', dark: true, on: false },
  { name: 'Instagram', color: '#e1306c', letter: 'I', on: true },
  { name: 'Ozon', color: '#005bff', letter: 'O', on: true },
];

function SplitTunnelScreen({ onBack }) {
  const [mode, setMode] = useS2('exclude'); // exclude | include
  const [apps, setApps] = useS2(APPS);
  const [q, setQ] = useS2('');
  const toggle = (i) => setApps(a => a.map((x, j) => j === i ? { ...x, on: !x.on } : x));
  const shown = apps.filter(a => a.name.toLowerCase().includes(q.toLowerCase()));

  return (
    <div style={{ flex: 1, display: 'flex', flexDirection: 'column' }}>
      <SubHeader title="Раздельный туннель" onBack={onBack} />

      {/* mode segmented */}
      <div style={{ padding: '0 16px 12px' }}>
        <div style={{ display: 'flex', gap: 4, padding: 4, borderRadius: 12, background: RS.panel, border: `1px solid ${RS.line}` }}>
          {[['exclude', 'Все, кроме выбранных'], ['include', 'Только выбранные']].map(([k, lbl]) => (
            <div key={k} onClick={() => setMode(k)} className="rs-tap" style={{ flex: 1, textAlign: 'center', padding: '9px 8px', borderRadius: 9, fontSize: 12.5, fontWeight: 600, cursor: 'pointer', background: mode === k ? RS.amber : 'transparent', color: mode === k ? RS.navy : RS.dim, transition: 'all 200ms' }}>{lbl}</div>
          ))}
        </div>
        <div style={{ fontSize: 12, color: RS.mute, marginTop: 9, lineHeight: 1.4, padding: '0 4px' }}>
          {mode === 'exclude' ? 'Отмеченные приложения пойдут напрямую, мимо VPN.' : 'Только отмеченные приложения пойдут через VPN.'}
        </div>
      </div>

      {/* search */}
      <div style={{ padding: '0 16px 12px' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '11px 14px', borderRadius: 12, background: RS.panel, border: `1px solid ${RS.line}` }}>
          <Icon name="search" size={17} color={RS.mute} stroke={2} />
          <input value={q} onChange={e => setQ(e.target.value)} placeholder="Поиск приложения" style={{ flex: 1, border: 'none', background: 'transparent', color: RS.ink, fontSize: 14, fontFamily: RS.font, outline: 'none' }} />
        </div>
      </div>

      {/* list */}
      <div style={{ flex: 1, overflowY: 'auto', padding: '0 16px 16px' }}>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
          {shown.map((a) => {
            const realIdx = apps.indexOf(a);
            return (
              <div key={a.name} onClick={() => toggle(realIdx)} className="rs-tap" style={{ display: 'flex', alignItems: 'center', gap: 13, padding: '11px 14px', borderRadius: 13, background: RS.panel, border: `1px solid ${a.on ? withA(RS.amber, 0.3) : RS.line}`, transition: 'border-color 200ms' }}>
                <div style={{ width: 38, height: 38, borderRadius: 10, background: a.color, display: 'flex', alignItems: 'center', justifyContent: 'center', color: a.dark ? '#1a1208' : '#fff', fontWeight: 800, fontSize: 17, fontFamily: RS.display, flexShrink: 0 }}>{a.letter}</div>
                <span style={{ flex: 1, fontSize: 14.5, color: RS.ink, fontWeight: 500 }}>{a.name}</span>
                <Toggle on={a.on} />
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
}

Object.assign(window, { LocationScreen, ConnectionDetails, DiagnosticsScreen, SplitTunnelScreen });

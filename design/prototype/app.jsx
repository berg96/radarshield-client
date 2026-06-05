// app.jsx — RadarShield VPN client: canvas layout, live prototype, tweaks
// Depends on frame.jsx + screens.jsx + tweaks-panel.jsx

const { useState, useEffect, useRef } = React;

const TWEAK_DEFAULTS = /*EDITMODE-BEGIN*/{
  "buttonStyle": "radar",
  "connectedColor": "#2fc98a",
  "connectingColor": "#ffcc33",
  "showLocation": true,
  "showShield": false,
  "showTimer": true
}/*EDITMODE-END*/;

// ── section + frame caption helpers ───────────────────────────
function Section({ title, desc, children }) {
  return (
    <div style={{ marginBottom: 64 }}>
      <div style={{ marginBottom: 26 }}>
        <h2 style={{ fontFamily: RS.display, fontWeight: 800, fontSize: 22, color: '#0f1d2e', margin: 0, letterSpacing: '-0.02em' }}>{title}</h2>
        {desc && <p style={{ color: '#5a6b7d', fontSize: 14.5, margin: '8px 0 0', maxWidth: 620, lineHeight: 1.5 }}>{desc}</p>}
      </div>
      {children}
    </div>
  );
}

function Row({ children, gap = 36 }) {
  return <div style={{ display: 'flex', flexWrap: 'wrap', gap, alignItems: 'flex-start' }}>{children}</div>;
}

// ── LIVE interactive prototype ────────────────────────────────
function LiveApp({ t }) {
  const [screen, setScreen] = useState('main'); // main|onboarding|settings|expired|splash|location|diagnostics|split
  const [conn, setConn] = useState('off');
  const [filled, setFilled] = useState(false);
  const [details, setDetails] = useState(false);
  const [loc, setLoc] = useState('auto');
  const timer = useRef(null);

  const connectingColor = t.connectingColor || RS.connecting;
  const connectedColor = t.connectedColor || RS.connected;
  const extras = { showLocation: t.showLocation, showShield: t.showShield, showTimer: t.showTimer };

  function clearT() { if (timer.current) { clearTimeout(timer.current); timer.current = null; } }
  useEffect(() => () => clearT(), []);

  function tapButton() {
    if (conn === 'off' || conn === 'error') {
      setConn('connecting');
      clearT();
      timer.current = setTimeout(() => setConn('connected'), 1700);
    } else if (conn === 'connected') {
      setConn('off');
    } else if (conn === 'connecting') {
      clearT(); setConn('off');
    }
  }

  let body;
  if (screen === 'splash') body = <SplashScreen />;
  else if (screen === 'onboarding') body = <OnboardingScreen filled={filled} onPaste={() => setFilled(true)} onContinue={() => filled && setScreen('main')} />;
  else if (screen === 'settings') body = <SettingsScreen onBack={() => setScreen('main')} onLocation={() => setScreen('location')} onSplitTunnel={() => setScreen('split')} onDiagnostics={() => setScreen('diagnostics')} />;
  else if (screen === 'expired') body = <ExpiredScreen onRenew={() => {}} />;
  else if (screen === 'location') body = <LocationScreen onBack={() => setScreen('main')} selected={loc} onSelect={setLoc} />;
  else if (screen === 'diagnostics') body = <DiagnosticsScreen onBack={() => setScreen('settings')} />;
  else if (screen === 'split') body = <SplitTunnelScreen onBack={() => setScreen('settings')} />;
  else body = (
    <MainScreen state={conn} styleVariant={t.buttonStyle} connectedColor={connectedColor} connectingColor={connectingColor}
                extras={extras} onTap={tapButton} onSettings={() => setScreen('settings')}
                onLocationTap={() => setScreen('location')} onDetails={() => setDetails(true)}
                onLogout={() => { setFilled(false); setScreen('onboarding'); }} btnSize={186} />
  );

  const chips = [
    ['main', 'Главный'], ['location', 'Локация'], ['settings', 'Настройки'],
    ['split', 'Разд. туннель'], ['diagnostics', 'Диагностика'],
    ['onboarding', 'Онбординг'], ['expired', 'Истекло'], ['splash', 'Сплеш'],
  ];

  return (
    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 18 }}>
      <Phone width={300}>
        {body}
        {details && screen === 'main' && (
          <ConnectionDetails onClose={() => setDetails(false)} onChangeServer={() => { setDetails(false); setScreen('location'); }} />
        )}
      </Phone>
      {/* nav chips */}
      <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8, justifyContent: 'center', maxWidth: 340 }}>
        {chips.map(([k, lbl]) => (
          <div key={k} onClick={() => { setDetails(false); setScreen(k); }} style={{
            fontSize: 12.5, fontWeight: 600, padding: '7px 12px', borderRadius: 9, cursor: 'pointer',
            background: screen === k ? '#0f1d2e' : '#fff', color: screen === k ? '#fff' : '#5a6b7d',
            border: `1px solid ${screen === k ? '#0f1d2e' : '#d8dee6'}`, fontFamily: RS.font,
          }}>{lbl}</div>
        ))}
      </div>
      {screen === 'main' && (
        <div style={{ fontSize: 13, color: '#5a6b7d', textAlign: 'center', maxWidth: 320 }}>
          Нажмите кнопку: <b style={{ color: RS.off }}>серый</b> → <b style={{ color: connectingColor }}>жёлтый</b> → <b style={{ color: connectedColor }}>зелёный</b>.
          {' '}<span onClick={() => { clearT(); setConn('error'); }} style={{ color: RS.error, cursor: 'pointer', borderBottom: `1px dashed ${RS.error}` }}>Показать ошибку</span>
        </div>
      )}
    </div>
  );
}

// ── static board phone ────────────────────────────────────────
function BoardPhone({ state, t, label, width = 248 }) {
  const extras = { showLocation: t.showLocation, showShield: t.showShield, showTimer: t.showTimer };
  return (
    <Phone width={width} label={label}>
      <MainScreen state={state} styleVariant={t.buttonStyle} connectedColor={t.connectedColor} connectingColor={t.connectingColor}
                  extras={extras} onTap={() => {}} onSettings={() => {}} onLogout={() => {}} btnSize={width * 0.56} />
    </Phone>
  );
}

// ── App root ──────────────────────────────────────────────────
function App() {
  const [t, setTweak] = useTweaks(TWEAK_DEFAULTS);
  const greenSel = (t.connectedColor || RS.connected).toLowerCase() === RS.connected;

  return (
    <div style={{ minHeight: '100vh', background: '#eef1f5', padding: '46px 48px 80px', boxSizing: 'border-box' }}>
      {/* header */}
      <div style={{ maxWidth: 1200, margin: '0 auto 52px' }}>
        <div style={{ display: 'inline-flex', alignItems: 'center', gap: 10, padding: '6px 14px 6px 8px', borderRadius: 999, background: RS.navy, marginBottom: 20 }}>
          <RSLogo size={22} />
          <span style={{ fontFamily: RS.display, fontWeight: 700, fontSize: 14, color: RS.ink }}>RadarShield</span>
          <span style={{ fontSize: 12, color: RS.mute, borderLeft: `1px solid ${RS.line2}`, paddingLeft: 10 }}>VPN-клиент</span>
        </div>
        <h1 style={{ fontFamily: RS.display, fontWeight: 800, fontSize: 38, color: '#0f1d2e', margin: 0, letterSpacing: '-0.03em' }}>Дизайн клиента — одна кнопка на весь экран</h1>
        <p style={{ color: '#5a6b7d', fontSize: 16, lineHeight: 1.55, margin: '14px 0 0', maxWidth: 680 }}>
          Радикальная простота для неискушённого пользователя: «нажал — работает». Статус соединения читается по цвету
          кнопки — <b style={{ color: RS.off }}>серый</b> (отключено) → <b style={{ color: t.connectingColor }}>жёлтый</b> (подключается) →
          {' '}<b style={{ color: t.connectedColor }}>зелёный</b> (подключено). Всё техническое спрятано в «продвинутый режим».
          Включите <b>Tweaks</b> (справа), чтобы переключить стиль кнопки и элементы экрана.
        </p>
      </div>

      <div style={{ maxWidth: 1200, margin: '0 auto' }}>
        {/* LIVE */}
        <Section title="Основной поток — интерактивно"
                 desc="Живой прототип. Нажмите кнопку «Пуск» — пройдёт цикл подключения с морфингом цвета и радар-пульсом. Чипами ниже можно переключаться между всеми экранами.">
          <LiveApp t={t} />
        </Section>

        {/* STATES BOARD */}
        <Section title="Состояния кнопки"
                 desc="Четыре ключевых состояния основного экрана. Цвет и подпись меняются синхронно; всё остальное на экране неизменно.">
          <Row gap={28}>
            <BoardPhone state="off" t={t} label="1 · Отключено" />
            <BoardPhone state="connecting" t={t} label="2 · Подключается" />
            <BoardPhone state="connected" t={t} label="3 · Подключено" />
            <BoardPhone state="error" t={t} label="4 · Ошибка" />
          </Row>
        </Section>

        {/* SCREENS */}
        <Section title="Онбординг и сервисные экраны"
                 desc="Первый запуск — вставка ссылки подписки из Telegram-бота. Настройки расширены: kill-switch, уведомление о статусе, точки входа в раздельный туннель и диагностику.">
          <Row gap={28}>
            <Phone width={248} label="Сплеш"><SplashScreen /></Phone>
            <Phone width={248} label="Онбординг"><OnboardingScreen filled={false} onPaste={() => {}} onContinue={() => {}} /></Phone>
            <Phone width={248} label="Настройки"><SettingsScreen onBack={() => {}} onLocation={() => {}} onSplitTunnel={() => {}} onDiagnostics={() => {}} /></Phone>
            <Phone width={248} label="Подписка истекла"><ExpiredScreen onRenew={() => {}} /></Phone>
          </Row>
        </Section>

        {/* ADVANCED-IN-OUR-STYLE */}
        <Section title="Продвинутые экраны — в нашем стиле"
                 desc="Чужой интерфейс FLClash убран полностью. Всё нужное перерисовано: выбор сервера с живым пингом, детали соединения (шторка), диагностика для поддержки и раздельный туннель.">
          <Row gap={28}>
            <Phone width={300} label="Выбор локации"><LocationScreen onBack={() => {}} selected="auto" onSelect={() => {}} /></Phone>
            <Phone width={300} label="Детали соединения">
              <MainScreen state="connected" styleVariant={t.buttonStyle} connectedColor={t.connectedColor} connectingColor={t.connectingColor}
                          extras={{ showLocation: t.showLocation, showShield: t.showShield, showTimer: t.showTimer }}
                          onTap={() => {}} onSettings={() => {}} onLogout={() => {}} btnSize={168} />
              <ConnectionDetails onClose={() => {}} onChangeServer={() => {}} />
            </Phone>
            <Phone width={300} label="Диагностика"><DiagnosticsScreen onBack={() => {}} /></Phone>
            <Phone width={300} label="Раздельный туннель"><SplitTunnelScreen onBack={() => {}} /></Phone>
          </Row>
        </Section>

        {/* WINDOWS */}
        <Section title="Windows — компактное окно"
                 desc="Та же кнопка по центру окна, без растягивания на весь монитор. Заголовок окна с управляющими кнопками, та же цветовая логика.">
          <Row gap={36}>
            <WinWindow width={440} height={530} label="Главный · подключено">
              <MainScreen state="connected" styleVariant={t.buttonStyle} connectedColor={t.connectedColor} connectingColor={t.connectingColor}
                          extras={{ showLocation: t.showLocation, showShield: t.showShield, showTimer: t.showTimer }}
                          onTap={() => {}} onSettings={() => {}} onLogout={() => {}} btnSize={158} />
            </WinWindow>
            <WinWindow width={440} height={530} label="Главный · отключено">
              <MainScreen state="off" styleVariant={t.buttonStyle} connectedColor={t.connectedColor} connectingColor={t.connectingColor}
                          extras={{ showLocation: t.showLocation, showShield: t.showShield, showTimer: t.showTimer }}
                          onTap={() => {}} onSettings={() => {}} onLogout={() => {}} btnSize={158} />
            </WinWindow>
          </Row>
        </Section>
      </div>

      {/* TWEAKS */}
      <TweaksPanel>
        <TweakSection label="Кнопка" />
        <TweakRadio label="Стиль" value={t.buttonStyle}
                    options={['radar', 'glow', 'minimal']}
                    onChange={(v) => setTweak('buttonStyle', v)} />
        <TweakColor label="Цвет «подключено»" value={t.connectedColor}
                    options={[RS.connected, RS.amber]}
                    onChange={(v) => setTweak('connectedColor', v)} />
        <TweakColor label="Цвет «подключается»" value={t.connectingColor}
                    options={['#ffcc33', RS.amber, '#c79a3e']}
                    onChange={(v) => setTweak('connectingColor', v)} />
        <TweakSection label="Элементы экрана" />
        <TweakToggle label="Локация (Россия · авто)" value={t.showLocation} onChange={(v) => setTweak('showLocation', v)} />
        <TweakToggle label="Бейдж «защита активна»" value={t.showShield} onChange={(v) => setTweak('showShield', v)} />
        <TweakToggle label="Таймер сессии" value={t.showTimer} onChange={(v) => setTweak('showTimer', v)} />
      </TweaksPanel>
    </div>
  );
}

ReactDOM.createRoot(document.getElementById('root')).render(<App />);

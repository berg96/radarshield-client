// RadarShield — own full-screen shell: one-button main + onboarding + our own
// advanced screens (settings / location / diagnostics / connection details),
// navigated by an internal view stack so the FlClash chrome never shows.
// Design source: design/prototype (v2). Wired to the real core via the same
// providers/actions the stock FlClash screens use.
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/plugins/app.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/proxies/common.dart' show delayTest;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── brand tokens (design/prototype frame.jsx) ────────────────────
class _RS {
  static const navy = Color(0xFF0D1B2A);
  static const navy2 = Color(0xFF0B1622);
  static const panel = Color(0xFF12243A);
  static const panel2 = Color(0xFF16304D);
  static const line = Color(0x14FFFFFF); // white 8%
  static const line2 = Color(0x24FFFFFF); // white 14%
  static const ink = Color(0xFFEEF3F9);
  static const dim = Color(0xFFB7C4D3);
  static const mute = Color(0xFF7F8FA3);
  static const amber = Color(0xFFFFB703);
  static const off = Color(0xFF7C8BA0);
  static const connecting = Color(0xFFFFB703);
  static const connected = Color(0xFF2FC98A);
  static const error = Color(0xFFF4736B);
}

enum _PowerState { off, connecting, connected }

// internal screen stack (our own, no FlClash nav)
enum _RSView { home, settings, location, diagnostics, language, splitTunnel }

class RadarShieldMainScreen extends ConsumerStatefulWidget {
  const RadarShieldMainScreen({super.key});

  @override
  ConsumerState<RadarShieldMainScreen> createState() =>
      _RadarShieldMainScreenState();
}

class _RadarShieldMainScreenState extends ConsumerState<RadarShieldMainScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  final TextEditingController _subCtrl = TextEditingController();

  _RSView _view = _RSView.home;
  // status-notification toggle is still visual (Android requires the VPN
  // notification; there is no core setting to suppress it)
  bool _statusNotif = true;
  // lazily-loaded installed-app list for the split-tunnel screen
  Future<List<Package>>? _packagesFuture;
  // guards a one-shot disconnect when the subscription turns out expired
  bool _stoppedForExpiry = false;
  bool _refreshingSub = false;
  // zero-config: a default subscription URL baked in at build time (see
  // setup.dart / env.json). Empty when unset → manual onboarding.
  static const _defaultSub = String.fromEnvironment('RS_DEFAULT_SUB');
  bool _autoImportTried = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _subCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _pulse.dispose();
    _subCtrl.dispose();
    super.dispose();
  }

  void _go(_RSView v) => setState(() => _view = v);

  _PowerState _resolveState(bool isStart, CoreStatus status) {
    if (status == CoreStatus.connecting) return _PowerState.connecting;
    if (isStart && status == CoreStatus.connected) return _PowerState.connected;
    return _PowerState.off;
  }

  Color _color(_PowerState s) {
    switch (s) {
      case _PowerState.connecting:
        return _RS.connecting;
      case _PowerState.connected:
        return _RS.connected;
      case _PowerState.off:
        return _RS.off;
    }
  }

  void _toggle(bool hasProfile) {
    if (!hasProfile) return;
    final next = !ref.read(isStartProvider);
    debouncer.call(FunctionTag.updateStatus, () {
      globalState.container
          .read(setupActionProvider.notifier)
          .updateStatus(next, isInit: !ref.read(initProvider));
    }, duration: commonDuration);
  }

  // First-run onboarding: paste the sub-link → canonical add flow.
  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty) {
      globalState.showMessage(
        message: const TextSpan(
          text: 'Буфер пуст — скопируйте ссылку подписки из Telegram-бота',
        ),
      );
      return;
    }
    _subCtrl.text = text;
  }

  void _addSub() {
    final url = _subCtrl.text.trim();
    if (url.isEmpty) return;
    ref.read(profilesActionProvider.notifier).addProfileFormURL(url);
  }

  @override
  Widget build(BuildContext context) {
    final hasProfile =
        ref.watch(profilesProvider.select((state) => state.isNotEmpty));

    if (!hasProfile) {
      // Zero-config: if a default sub is baked in, import it once and show a
      // brief bootstrap screen. On failure (network) we fall through to manual
      // onboarding so the user is never stuck.
      if (_defaultSub.isNotEmpty && !_autoImportTried) {
        _autoImportTried = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(profilesActionProvider.notifier).addProfileFormURL(
                _defaultSub,
              );
        });
        return _bootstrapView();
      }
      _view = _RSView.home;
      return _onboardingView();
    }

    final info = ref.watch(currentProfileProvider)?.subscriptionInfo;
    if (_isExpired(info)) {
      _ensureStoppedForExpiry();
      return _expiredView(info!);
    }
    _stoppedForExpiry = false;

    switch (_view) {
      case _RSView.settings:
        return _settingsView();
      case _RSView.location:
        return _locationView();
      case _RSView.diagnostics:
        return _diagnosticsView();
      case _RSView.language:
        return _languageView();
      case _RSView.splitTunnel:
        return _splitTunnelView();
      case _RSView.home:
        return _homeView();
    }
  }

  // ─────────────────────────────────────────────────────────────
  // HOME (power button)
  // ─────────────────────────────────────────────────────────────
  Widget _homeView() {
    final isStart = ref.watch(isStartProvider);
    final status = ref.watch(coreStatusProvider);
    final hasProfile =
        ref.watch(profilesProvider.select((state) => state.isNotEmpty));
    final state = _resolveState(isStart, status);
    final color = _color(state);

    return Material(
      color: _RS.navy,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
          child: Column(
            children: [
              _topBar(),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _powerButton(state, color, () => _toggle(hasProfile)),
                    const SizedBox(height: 22),
                    _statusText(state, color),
                    if (state == _PowerState.connected) _detailsPill(),
                    if (state == _PowerState.connected) _sessionTimer(),
                  ],
                ),
              ),
              _locationChip(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Row(
          children: [
            _Logo(size: 24),
            SizedBox(width: 9),
            Text(
              'RadarShield',
              style: TextStyle(
                color: _RS.ink,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
        Row(
          children: [
            _cornerButton(Icons.logout, _confirmLogout),
            const SizedBox(width: 10),
            _cornerButton(Icons.settings_outlined, () => _go(_RSView.settings)),
          ],
        ),
      ],
    );
  }

  Widget _cornerButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: _RS.panel,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _RS.line),
        ),
        child: Icon(icon, size: 19, color: _RS.dim),
      ),
    );
  }

  Widget _powerButton(_PowerState state, Color color, VoidCallback onTap) {
    const size = 200.0;
    final active = state == _PowerState.connected;
    final connecting = state == _PowerState.connecting;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: size * 1.25,
        height: size * 1.25,
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (_, _) {
            return Stack(
              alignment: Alignment.center,
              children: [
                if (connecting || active)
                  ..._sonarRings(size, color, connecting),
                if (connecting)
                  SizedBox(
                    width: size + 24,
                    height: size + 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 4,
                      valueColor: AlwaysStoppedAnimation(color),
                      backgroundColor: color.withValues(alpha: 0.18),
                    ),
                  ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeInOut,
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      center: const Alignment(0, -0.1),
                      colors: [
                        color.withValues(alpha: 0.22),
                        color.withValues(alpha: 0.06),
                      ],
                      stops: const [0.0, 0.72],
                    ),
                    border: Border.all(
                      color: color.withValues(alpha: 0.85),
                      width: 3.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: active ? 0.4 : 0.22),
                        blurRadius: size * 0.22,
                      ),
                    ],
                  ),
                  child: Icon(
                    active ? Icons.shield_outlined : Icons.power_settings_new,
                    size: size * 0.34,
                    color: color,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _sonarRings(double size, Color color, bool connecting) {
    const count = 3;
    return List.generate(count, (i) {
      final phase = (_pulse.value + i / count) % 1.0;
      final scale = 1.0 + phase * 0.9;
      final opacity = (1.0 - phase) * 0.5;
      return Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: Container(
          width: size * scale,
          height: size * scale,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 1.5),
          ),
        ),
      );
    });
  }

  Widget _statusText(_PowerState state, Color color) {
    final (word, sub) = switch (state) {
      _PowerState.off => ('Пуск', 'Нажмите, чтобы подключиться'),
      _PowerState.connecting => (
          'Подключаюсь…',
          'Устанавливаем защищённое соединение'
        ),
      _PowerState.connected => ('Подключено', 'Соединение защищено'),
    };
    return Column(
      children: [
        Text(
          word,
          style: TextStyle(
            color: state == _PowerState.off ? _RS.ink : color,
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          sub,
          textAlign: TextAlign.center,
          style: const TextStyle(color: _RS.mute, fontSize: 14),
        ),
      ],
    );
  }

  Widget _detailsPill() {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: GestureDetector(
        onTap: _showDetails,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _RS.panel,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: _RS.line),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.info_outline, size: 14, color: _RS.amber),
              SizedBox(width: 6),
              Text(
                'Детали соединения',
                style: TextStyle(
                  color: _RS.dim,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sessionTimer() {
    return Consumer(
      builder: (_, ref, _) {
        final runTime = ref.watch(runTimeProvider);
        final text = utils.getTimeText(runTime);
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.schedule, size: 15, color: _RS.mute),
              const SizedBox(width: 7),
              Text(
                text,
                style: const TextStyle(
                  color: _RS.dim,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _locationChip() {
    return GestureDetector(
      onTap: () => _go(_RSView.location),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: _RS.panel,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: _RS.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.public, size: 15, color: _RS.amber),
            const SizedBox(width: 8),
            Text(
              _currentServerLabel(),
              style: const TextStyle(
                color: _RS.dim,
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right, size: 16, color: _RS.mute),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // ONBOARDING
  // ─────────────────────────────────────────────────────────────
  // Brief branded loader shown while the baked-in subscription is imported.
  Widget _bootstrapView() {
    return const Material(
      color: _RS.navy,
      child: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Logo(size: 56),
              SizedBox(height: 22),
              Text(
                'RadarShield',
                style: TextStyle(
                  color: _RS.ink,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              SizedBox(height: 26),
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.4, color: _RS.amber),
              ),
              SizedBox(height: 14),
              Text(
                'Настраиваем подключение…',
                style: TextStyle(color: _RS.mute, fontSize: 13.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _onboardingView() {
    final filled = _subCtrl.text.trim().isNotEmpty;
    // SafeArea reserves the system navigation bar (home.dart keeps the bottom
    // inset on the dashboard); add the keyboard inset so the paste field and
    // footer lift above the keyboard when it opens.
    final keyboard = MediaQuery.of(context).viewInsets.bottom;
    return Material(
      color: _RS.navy,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(22, 18, 22, 18 + keyboard),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  _Logo(size: 24),
                  SizedBox(width: 9),
                  Text(
                    'RadarShield',
                    style: TextStyle(
                      color: _RS.ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints:
                          BoxConstraints(minHeight: constraints.maxHeight),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: _RS.amber.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                  color: _RS.amber.withValues(alpha: 0.3)),
                            ),
                            child: const Icon(Icons.link,
                                color: _RS.amber, size: 26),
                          ),
                          const SizedBox(height: 22),
                          const Text(
                            'Вставьте ссылку\nподписки',
                            style: TextStyle(
                              color: _RS.ink,
                              fontSize: 25,
                              fontWeight: FontWeight.w800,
                              height: 1.15,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Откройте нашего бота в Telegram и скопируйте '
                            'ссылку. Вставьте её сюда — остальное сделаем сами.',
                            style: TextStyle(
                                color: _RS.dim, fontSize: 14.5, height: 1.5),
                          ),
                          const SizedBox(height: 26),
                          _subInput(filled),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: filled ? _addSub : null,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color:
                        filled ? _RS.amber : Colors.white.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Продолжить',
                        style: TextStyle(
                          color: filled ? _RS.navy : _RS.mute,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.chevron_right,
                          size: 20, color: filled ? _RS.navy : _RS.mute),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: () => ref
                    .read(profilesActionProvider.notifier)
                    .addProfileFormQrCode(),
                behavior: HitTestBehavior.opaque,
                child: const Center(
                  child: Text(
                    'Сканировать QR-код →',
                    style: TextStyle(
                      color: _RS.mute,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _subInput(bool filled) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
      decoration: BoxDecoration(
        color: _RS.panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: filled ? _RS.amber.withValues(alpha: 0.5) : _RS.line2,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.link, size: 18, color: _RS.mute),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _subCtrl,
              style: const TextStyle(
                color: _RS.ink,
                fontSize: 14,
                fontFamily: 'monospace',
              ),
              cursorColor: _RS.amber,
              decoration: const InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: 'rs://подписка…',
                hintStyle: TextStyle(color: _RS.mute, fontSize: 14),
              ),
            ),
          ),
          GestureDetector(
            onTap: _pasteFromClipboard,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              decoration: BoxDecoration(
                color: _RS.amber.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.content_paste, size: 14, color: _RS.amber),
                  SizedBox(width: 6),
                  Text(
                    'Вставить',
                    style: TextStyle(
                      color: _RS.amber,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // shared chrome
  // ─────────────────────────────────────────────────────────────
  Widget _subHeader(String title, VoidCallback onBack, {Widget? action}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 6),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: _RS.panel,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: _RS.line),
              ),
              child: const Icon(Icons.chevron_left, size: 20, color: _RS.dim),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: _RS.ink,
                fontSize: 21,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          ?action,
        ],
      ),
    );
  }

  Widget _rsToggle(bool on, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 44,
        height: 26,
        decoration: BoxDecoration(
          color: on ? _RS.amber : Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(99),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 180),
          alignment: on ? Alignment.centerRight : Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: Container(
              width: 20,
              height: 20,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _primaryButton(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _RS.amber,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: _RS.navy,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _settingRow({
    required IconData icon,
    required String title,
    String? sub,
    Widget? trailing,
    VoidCallback? onTap,
    bool danger = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: danger
                    ? _RS.error.withValues(alpha: 0.12)
                    : _RS.panel2,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon,
                  size: 18, color: danger ? _RS.error : _RS.amber),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      color: danger ? _RS.error : _RS.ink,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (sub != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        sub,
                        style: const TextStyle(fontSize: 12.5, color: _RS.mute),
                      ),
                    ),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }

  Widget _group(List<Widget> rows) {
    final children = <Widget>[];
    for (var i = 0; i < rows.length; i++) {
      if (i > 0) {
        children.add(const Padding(
          padding: EdgeInsets.only(left: 68),
          child: Divider(height: 1, thickness: 1, color: _RS.line),
        ));
      }
      children.add(rows[i]);
    }
    return Container(
      decoration: BoxDecoration(
        color: _RS.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _RS.line),
      ),
      child: Column(children: children),
    );
  }

  Widget _groupLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 18, 6, 8),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          color: _RS.mute,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  static const _chevron =
      Icon(Icons.chevron_right, size: 18, color: _RS.mute);

  // ─────────────────────────────────────────────────────────────
  // SETTINGS
  // ─────────────────────────────────────────────────────────────
  Widget _settingsView() {
    final profile = ref.watch(currentProfileProvider);
    final info = profile?.subscriptionInfo;
    final locale = ref.watch(appSettingProvider).locale;
    final autoRun = ref.watch(appSettingProvider.select((s) => s.autoRun));
    final killSwitch = ref.watch(vpnSettingProvider.select((s) => s.killSwitch));
    final pkg = globalState.packageInfo;

    return Material(
      color: _RS.navy,
      child: SafeArea(
        child: Column(
          children: [
            _subHeader('Настройки', () => _go(_RSView.home)),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                children: [
                  _accountCard(info),
                  _groupLabel('Соединение'),
                  _group([
                    _settingRow(
                      icon: Icons.public,
                      title: 'Локация',
                      sub: _currentServerLabel(),
                      trailing: _chevron,
                      onTap: () => _go(_RSView.location),
                    ),
                    _settingRow(
                      icon: Icons.bolt,
                      title: 'Автоподключение',
                      sub: 'При запуске приложения',
                      trailing: _rsToggle(
                          autoRun,
                          () => ref
                              .read(appSettingProvider.notifier)
                              .update((s) => s.copyWith(autoRun: !autoRun))),
                    ),
                    _settingRow(
                      icon: Icons.shield_outlined,
                      title: 'Kill-switch',
                      sub: 'Не выпускать трафик мимо VPN при разрыве',
                      trailing: _rsToggle(
                          killSwitch,
                          () => ref
                              .read(vpnSettingProvider.notifier)
                              .update((s) =>
                                  s.copyWith(killSwitch: !killSwitch))),
                    ),
                    _settingRow(
                      icon: Icons.tune,
                      title: 'Раздельный туннель',
                      sub: _splitTunnelLabel(),
                      trailing: _chevron,
                      onTap: () {
                        _packagesFuture ??= ref
                            .read(systemActionProvider.notifier)
                            .getPackages();
                        _go(_RSView.splitTunnel);
                      },
                    ),
                  ]),
                  _groupLabel('Приложение'),
                  _group([
                    _settingRow(
                      icon: Icons.notifications_none,
                      title: 'Уведомление о статусе',
                      sub: 'Постоянная нотификация VPN',
                      trailing: _rsToggle(
                          _statusNotif, () => setState(() => _statusNotif = !_statusNotif)),
                    ),
                    _settingRow(
                      icon: Icons.language,
                      title: 'Язык',
                      sub: _localeLabel(locale),
                      trailing: _chevron,
                      onTap: () => _go(_RSView.language),
                    ),
                    _settingRow(
                      icon: Icons.troubleshoot,
                      title: 'Диагностика',
                      sub: 'Журнал и помощь поддержке',
                      trailing: _chevron,
                      onTap: () => _go(_RSView.diagnostics),
                    ),
                    _settingRow(
                      icon: Icons.info_outline,
                      title: 'О приложении',
                      sub: 'Версия ${pkg.version} (${pkg.buildNumber})',
                    ),
                  ]),
                  const SizedBox(height: 14),
                  _group([
                    _settingRow(
                      icon: Icons.logout,
                      title: 'Выйти из аккаунта',
                      danger: true,
                      onTap: _confirmLogout,
                    ),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _accountCard(SubscriptionInfo? info) {
    final hasInfo = info != null && (info.total > 0 || info.expire > 0);
    final used = info == null ? 0 : info.upload + info.download;
    final sub = hasInfo
        ? '${info.expire > 0 ? 'до ${_fmtDate(info.expire)} · ' : ''}'
            '${used.traffic.show} из ${info.total > 0 ? info.total.traffic.show : '∞'}'
        : 'Данные подписки подтянутся после обновления';
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _RS.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _RS.line),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _RS.amber.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person_outline, color: _RS.amber, size: 22),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasInfo ? 'Подписка активна' : 'Подписка',
                  style: const TextStyle(
                    fontSize: 15,
                    color: _RS.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sub,
                  style: const TextStyle(fontSize: 12.5, color: _RS.mute),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // LANGUAGE (real appSetting.locale)
  // ─────────────────────────────────────────────────────────────
  // null = follow system; otherwise a locale code stored verbatim.
  static const _localeOptions = <String?>[null, 'ru', 'en'];

  String _localeLabel(String? code) {
    switch (code) {
      case null:
      case '':
        return 'Системный';
      case 'ru':
        return 'Русский';
      case 'en':
        return 'English';
      default:
        return code;
    }
  }

  Widget _languageView() {
    final current = ref.watch(appSettingProvider.select((s) => s.locale));
    return Material(
      color: _RS.navy,
      child: SafeArea(
        child: Column(
          children: [
            _subHeader('Язык', () => _go(_RSView.settings)),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                children: [
                  _groupLabel('Язык интерфейса'),
                  _group([
                    for (final code in _localeOptions)
                      _settingRow(
                        icon: code == null
                            ? Icons.smartphone
                            : Icons.translate,
                        title: _localeLabel(code),
                        trailing: ((current ?? '') == (code ?? ''))
                            ? const Icon(Icons.check, color: _RS.amber, size: 20)
                            : null,
                        onTap: () => ref
                            .read(appSettingProvider.notifier)
                            .update((s) => s.copyWith(locale: code)),
                      ),
                  ]),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(4, 14, 4, 0),
                    child: Text(
                      'Системный — приложение следует языку телефона.',
                      style: TextStyle(fontSize: 12.5, color: _RS.mute),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // SPLIT TUNNEL (real vpn.accessControlProps)
  // ─────────────────────────────────────────────────────────────
  String _splitTunnelLabel() {
    final ac = ref.read(vpnSettingProvider).accessControlProps;
    if (!ac.enable) return 'Выключен — весь трафик через VPN';
    final n = ac.currentList.length;
    final mode = ac.mode == AccessControlMode.acceptSelected
        ? 'только выбранные'
        : 'кроме выбранных';
    return 'Включён · $n прил. · $mode';
  }

  void _toggleApp(String packageName) {
    ref.read(vpnSettingProvider.notifier).update((s) {
      final ac = s.accessControlProps;
      final set = Set<String>.from(ac.currentList)..addOrRemove(packageName);
      return s.copyWith(
          accessControlProps: ac.copyWithNewList(set.toList()));
    });
  }

  Widget _splitTunnelView() {
    final ac = ref.watch(vpnSettingProvider.select((s) => s.accessControlProps));
    return Material(
      color: _RS.navy,
      child: SafeArea(
        child: Column(
          children: [
            _subHeader('Раздельный туннель', () => _go(_RSView.settings)),
            Expanded(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                    child: _group([
                      _settingRow(
                        icon: Icons.alt_route,
                        title: 'Раздельный туннель',
                        sub: 'Часть приложений идёт мимо VPN',
                        trailing: _rsToggle(
                          ac.enable,
                          () => ref
                              .read(vpnSettingProvider.notifier)
                              .update((s) => s.copyWith(
                                  accessControlProps: s.accessControlProps
                                      .copyWith(enable: !ac.enable))),
                        ),
                      ),
                    ]),
                  ),
                  if (ac.enable) ...[
                    _modeSelector(ac.mode),
                    Expanded(child: _appList(ac)),
                  ] else
                    const Expanded(
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Text(
                            'Включите, чтобы выбрать приложения,\nкоторые ходят мимо VPN.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13.5, color: _RS.mute),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _modeSelector(AccessControlMode mode) {
    Widget chip(String label, AccessControlMode m) {
      final on = mode == m;
      return Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => ref.read(vpnSettingProvider.notifier).update((s) =>
              s.copyWith(
                  accessControlProps:
                      s.accessControlProps.copyWith(mode: m))),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              color: on ? _RS.amber.withValues(alpha: 0.16) : _RS.panel,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: on ? _RS.amber : _RS.line),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.25,
                color: on ? _RS.amber : _RS.dim,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
      child: Row(
        children: [
          chip('Только выбранные\nчерез VPN', AccessControlMode.acceptSelected),
          chip('Выбранные\nмимо VPN', AccessControlMode.rejectSelected),
        ],
      ),
    );
  }

  Widget _appList(AccessControlProps ac) {
    return FutureBuilder<List<Package>>(
      future: _packagesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: CircularProgressIndicator(color: _RS.amber),
          );
        }
        final packages = (snapshot.data ?? []).getViewList(
          pinedList: const [],
          sortType: AccessSortType.name,
          isFilterSystemApp: ac.isFilterSystemApp,
          isFilterNonInternetApp: ac.isFilterNonInternetApp,
        );
        if (packages.isEmpty) {
          return const Center(
            child: Text('Нет приложений',
                style: TextStyle(color: _RS.mute, fontSize: 13)),
          );
        }
        final selected = ac.currentList.toSet();
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 24),
          itemCount: packages.length,
          itemExtent: 64,
          itemBuilder: (_, i) {
            final p = packages[i];
            final on = selected.contains(p.packageName);
            return _appRow(p, on);
          },
        );
      },
    );
  }

  Widget _appRow(Package p, bool on) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _toggleApp(p.packageName),
      child: Row(
        children: [
          SizedBox(
            width: 38,
            height: 38,
            child: FutureBuilder<ImageProvider?>(
              future: app?.getPackageIcon(p.packageName),
              builder: (_, snap) {
                if (snap.data == null) {
                  return Container(
                    decoration: BoxDecoration(
                      color: _RS.panel2,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(Icons.android,
                        size: 18, color: _RS.mute),
                  );
                }
                return ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: Image(
                      image: snap.data!,
                      gaplessPlayback: true,
                      width: 38,
                      height: 38),
                );
              },
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  p.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 14.5,
                      color: _RS.ink,
                      fontWeight: FontWeight.w500),
                ),
                Text(
                  p.packageName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11.5, color: _RS.mute),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _rsToggle(on, () => _toggleApp(p.packageName)),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // EXPIRED GATE (real SubscriptionInfo)
  // ─────────────────────────────────────────────────────────────
  bool _isExpired(SubscriptionInfo? info) {
    if (info == null) return false;
    final nowS = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final timeUp = info.expire > 0 && nowS >= info.expire;
    final dataUp = info.total > 0 && (info.upload + info.download) >= info.total;
    return timeUp || dataUp;
  }

  void _ensureStoppedForExpiry() {
    if (_stoppedForExpiry) return;
    _stoppedForExpiry = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ref.read(isStartProvider)) {
        ref.read(setupActionProvider.notifier).updateStatus(false);
      }
    });
  }

  // Build the payment page URL from the user's own bound subscription link.
  // The sub token already encodes the (HMAC-signed) tg_id, so the landing's
  // /pay resolves the user from ?sub=<token> and redirects to the signed
  // uid+sig page — no @username search needed.
  String _payUrl() {
    final url = ref.read(currentProfileProvider)?.url ?? '';
    final uri = Uri.tryParse(url);
    final origin = (uri != null && uri.hasScheme && uri.host.isNotEmpty)
        ? '${uri.scheme}://${uri.host}'
        : 'https://radarshield.mooo.com';
    final i = url.indexOf('/sub/');
    if (i != -1) {
      final token = url.substring(i + 5).split('/').first.split('?').first;
      if (token.isNotEmpty) {
        return '$origin/pay?sub=${Uri.encodeComponent(token)}';
      }
    }
    return '$origin/pay';
  }

  Future<void> _refreshSubscription() async {
    final profile = ref.read(currentProfileProvider);
    if (profile == null || _refreshingSub) return;
    setState(() => _refreshingSub = true);
    try {
      await ref
          .read(profilesActionProvider.notifier)
          .updateProfile(profile, showLoading: false);
    } catch (_) {
      globalState.showMessage(
        message: const TextSpan(text: 'Не удалось обновить — проверьте сеть'),
      );
    } finally {
      if (mounted) setState(() => _refreshingSub = false);
    }
  }

  Widget _expiredView(SubscriptionInfo info) {
    final nowS = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final timeUp = info.expire > 0 && nowS >= info.expire;
    final title = timeUp ? 'Подписка истекла' : 'Трафик исчерпан';
    final detail = timeUp
        ? (info.expire > 0 ? 'Действовала до ${_fmtDate(info.expire)}' : '')
        : 'Использовано ${(info.upload + info.download).traffic.show}'
            ' из ${info.total.traffic.show}';
    return Material(
      color: _RS.navy,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            children: [
              const Row(
                children: [
                  _Logo(size: 24),
                  SizedBox(width: 9),
                  Text(
                    'RadarShield',
                    style: TextStyle(
                      color: _RS.ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: _RS.amber.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        timeUp ? Icons.timer_off_outlined : Icons.data_usage,
                        color: _RS.amber,
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      title,
                      style: const TextStyle(
                        color: _RS.ink,
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (detail.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        detail,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: _RS.dim, fontSize: 13.5),
                      ),
                    ],
                    const SizedBox(height: 6),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        'Продлите подписку на сайте, затем обновите.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: _RS.mute, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              _primaryButton(
                'Продлить подписку',
                () => globalState.openUrl(_payUrl()),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _refreshingSub ? null : _refreshSubscription,
                child: Container(
                  width: double.infinity,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _RS.panel,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _RS.line2),
                  ),
                  child: _refreshingSub
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.2, color: _RS.amber),
                        )
                      : const Text(
                          'Я продлил — обновить',
                          style: TextStyle(
                            color: _RS.ink,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: _confirmLogout,
                child: const Text(
                  'Сменить подписку',
                  style: TextStyle(color: _RS.mute, fontSize: 13.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // LOCATION (real proxy group)
  // ─────────────────────────────────────────────────────────────
  Widget _locationView() {
    final group = _serverGroup();
    return Material(
      color: _RS.navy,
      child: SafeArea(
        child: Column(
          children: [
            _subHeader(
              'Локация',
              () => _go(_RSView.home),
              action: GestureDetector(
                onTap: group == null
                    ? null
                    : () => delayTest(group.all, group.testUrl),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: _RS.panel,
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: _RS.line),
                  ),
                  child: const Icon(Icons.refresh, size: 18, color: _RS.dim),
                ),
              ),
            ),
            Expanded(
              child: group == null || group.all.isEmpty
                  ? const Center(
                      child: Text(
                        'Серверы появятся после загрузки подписки',
                        style: TextStyle(color: _RS.mute, fontSize: 14),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemCount: group.all.length,
                      itemBuilder: (_, i) => _serverRow(group, group.all[i]),
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _serverRow(Group group, Proxy proxy) {
    final selected = group.now == proxy.name;
    final ping =
        ref.watch(delayProvider(proxyName: proxy.name, testUrl: group.testUrl));
    return GestureDetector(
      onTap: () {
        ref
            .read(profilesActionProvider.notifier)
            .updateCurrentSelectedMap(group.name, proxy.name);
        ref
            .read(proxiesActionProvider.notifier)
            .changeProxyDebounce(group.name, proxy.name);
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? _RS.connected.withValues(alpha: 0.08) : _RS.panel,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? _RS.connected.withValues(alpha: 0.45) : _RS.line,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                proxy.name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14.5,
                  color: _RS.ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              ping == null ? '—' : '$ping ms',
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                color: _pingColor(ping),
              ),
            ),
            const SizedBox(width: 10),
            _radio(selected),
          ],
        ),
      ),
    );
  }

  Widget _radio(bool on) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: on ? _RS.connected : _RS.line2, width: 2),
      ),
      child: on
          ? Center(
              child: Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: _RS.connected,
                  shape: BoxShape.circle,
                ),
              ),
            )
          : null,
    );
  }

  // ─────────────────────────────────────────────────────────────
  // DIAGNOSTICS
  // ─────────────────────────────────────────────────────────────
  Widget _diagnosticsView() {
    final pkg = globalState.packageInfo;
    final logs = ref.watch(logsProvider).list;
    final recent = logs.reversed.take(14).toList();
    return Material(
      color: _RS.navy,
      child: SafeArea(
        child: Column(
          children: [
            _subHeader('Диагностика', () => _go(_RSView.settings)),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _RS.panel,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _RS.line),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Версия ${pkg.version} (build ${pkg.buildNumber})',
                          style: const TextStyle(
                            fontSize: 14.5,
                            color: _RS.ink,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Журнал событий ядра — приложите к обращению в поддержку.',
                          style: TextStyle(fontSize: 12.5, color: _RS.mute),
                        ),
                      ],
                    ),
                  ),
                  _groupLabel('Журнал событий'),
                  Container(
                    decoration: BoxDecoration(
                      color: _RS.panel,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _RS.line),
                    ),
                    child: recent.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(18),
                            child: Text(
                              'Пока пусто',
                              style: TextStyle(color: _RS.mute, fontSize: 13),
                            ),
                          )
                        : Column(
                            children: [
                              for (var i = 0; i < recent.length; i++) ...[
                                if (i > 0)
                                  const Divider(
                                      height: 1, thickness: 1, color: _RS.line),
                                _logRow(recent[i]),
                              ],
                            ],
                          ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
              child: GestureDetector(
                onTap: () => _copyLogs(logs),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(
                    color: _RS.amber,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.copy, size: 17, color: _RS.navy),
                      SizedBox(width: 8),
                      Text(
                        'Скопировать для поддержки',
                        style: TextStyle(
                          color: _RS.navy,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _logRow(Log log) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: _logColor(log.logLevel),
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              log.payload,
              style: const TextStyle(fontSize: 12.5, color: _RS.dim),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // CONNECTION DETAILS (bottom sheet)
  // ─────────────────────────────────────────────────────────────
  void _showDetails() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Consumer(
        builder: (_, ref, _) {
          final traffic = ref.watch(totalTrafficProvider);
          final runTime = ref.watch(runTimeProvider);
          return Container(
            decoration: const BoxDecoration(
              color: _RS.navy2,
              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
              border: Border(top: BorderSide(color: _RS.line2)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      decoration: const BoxDecoration(
                        color: _RS.connected,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 11),
                    const Text(
                      'Соединение защищено',
                      style: TextStyle(
                        color: _RS.ink,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _detailRow(Icons.public, 'Сервер', _currentServerLabel()),
                _detailRow(Icons.schedule, 'Время сессии',
                    utils.getTimeText(runTime)),
                _detailRow(Icons.download, 'Загружено',
                    traffic.down.traffic.show),
                _detailRow(
                    Icons.upload, 'Отправлено', traffic.up.traffic.show),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).pop();
                    _go(_RSView.location);
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    decoration: BoxDecoration(
                      color: _RS.panel,
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: _RS.line2),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.swap_horiz, size: 18, color: _RS.amber),
                        SizedBox(width: 8),
                        Text(
                          'Сменить сервер',
                          style: TextStyle(
                            color: _RS.ink,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _RS.panel2,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: _RS.amber),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 13.5, color: _RS.dim),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13.5,
              color: _RS.ink,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // helpers
  // ─────────────────────────────────────────────────────────────
  Group? _serverGroup() {
    final groups = ref.watch(groupsProvider);
    Group? selector;
    Group? any;
    for (final g in groups) {
      if (g.hidden == true) continue;
      any ??= g;
      if (g.type == GroupType.Selector && selector == null) selector = g;
    }
    return selector ?? any;
  }

  String _currentServerLabel() {
    final group = _serverGroup();
    final now = group?.now;
    if (now == null || now.isEmpty) return 'Россия · авто';
    return now;
  }

  void _confirmLogout() async {
    final ok = await globalState.showMessage(
      title: 'Выйти из аккаунта',
      message: const TextSpan(
        text: 'Подписка будет удалена из приложения. Продолжить?',
      ),
    );
    if (ok != true) return;
    final profile = ref.read(currentProfileProvider);
    if (profile != null) {
      await ref.read(profilesActionProvider.notifier).deleteProfile(profile.id);
    }
    _go(_RSView.home);
  }

  Future<void> _copyLogs(List<Log> logs) async {
    final text = logs.map((l) => '[${l.logLevel.name}] ${l.payload}').join('\n');
    await Clipboard.setData(ClipboardData(text: text));
    globalState.showMessage(
      message: const TextSpan(text: 'Журнал скопирован'),
    );
  }

  Color _pingColor(int? ms) {
    if (ms == null) return _RS.mute;
    if (ms < 40) return _RS.connected;
    if (ms < 90) return _RS.amber;
    return const Color(0xFFE8915B);
  }

  Color _logColor(LogLevel level) {
    switch (level) {
      case LogLevel.error:
        return _RS.error;
      case LogLevel.warning:
        return _RS.amber;
      case LogLevel.info:
        return _RS.connected;
      default:
        return _RS.mute;
    }
  }

  String _fmtDate(int epochSeconds) {
    final d = DateTime.fromMillisecondsSinceEpoch(epochSeconds * 1000);
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return '$dd.$mm.${d.year}';
  }
}

// ── logo mark: shield outline + amber R ─────────────────────────
class _Logo extends StatelessWidget {
  final double size;
  const _Logo({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _LogoPainter()),
    );
  }
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w * 0.5, h * 0.06)
      ..lineTo(w * 0.88, h * 0.24)
      ..lineTo(w * 0.88, h * 0.52)
      ..cubicTo(w * 0.88, h * 0.74, w * 0.72, h * 0.90, w * 0.5, h * 0.95)
      ..cubicTo(w * 0.28, h * 0.90, w * 0.12, h * 0.74, w * 0.12, h * 0.52)
      ..lineTo(w * 0.12, h * 0.24)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.07
        ..strokeJoin = StrokeJoin.round
        ..color = _RS.amber,
    );
    final tp = TextPainter(
      text: TextSpan(
        text: 'R',
        style: TextStyle(
          color: _RS.amber,
          fontSize: w * 0.5,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset((w - tp.width) / 2, (h - tp.height) / 2));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

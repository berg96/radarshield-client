// RadarShield main screen — the one-button centerpiece.
// Self-contained dark "navy" look so it renders correctly regardless of the
// app ThemeData. Wired to the real core: isStartProvider / coreStatusProvider /
// runTimeProvider, toggled via setupAction.updateStatus (same path as the stock
// StartButton). Design source: design/SPEC.md + design/prototype.
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── brand tokens (design/SPEC.md) ────────────────────────────────
class _RS {
  static const navy = Color(0xFF0D1B2A);
  static const panel = Color(0xFF12243A);
  static const line = Color(0x14FFFFFF); // white 8%
  static const ink = Color(0xFFEEF3F9);
  static const dim = Color(0xFFB7C4D3);
  static const mute = Color(0xFF7F8FA3);
  static const amber = Color(0xFFFFB703);
  static const off = Color(0xFF7C8BA0);
  static const connecting = Color(0xFFFFB703);
  static const connected = Color(0xFF2FC98A);
}

enum _PowerState { off, connecting, connected }

class RadarShieldMainScreen extends ConsumerStatefulWidget {
  const RadarShieldMainScreen({super.key});

  @override
  ConsumerState<RadarShieldMainScreen> createState() =>
      _RadarShieldMainScreenState();
}

class _RadarShieldMainScreenState extends ConsumerState<RadarShieldMainScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

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
    if (!hasProfile) {
      // No subscription yet → route to the Profiles page so the user can paste
      // their sub-link. This is the interim onboarding path until a dedicated
      // onboarding / zero-config flow lands.
      ref.read(currentPageLabelProvider.notifier).toPage(PageLabel.profiles);
      return;
    }
    final next = !ref.read(isStartProvider);
    debouncer.call(FunctionTag.updateStatus, () {
      globalState.container
          .read(setupActionProvider.notifier)
          .updateStatus(next, isInit: !ref.read(initProvider));
    }, duration: commonDuration);
  }

  // First-run onboarding: read the sub-link from the clipboard and hand it to
  // the canonical add flow (shows progress, lands on Profiles with the new sub).
  Future<void> _pasteSub() async {
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
    ref.read(profilesActionProvider.notifier).addProfileFormURL(text);
  }

  @override
  Widget build(BuildContext context) {
    final isStart = ref.watch(isStartProvider);
    final status = ref.watch(coreStatusProvider);
    final hasProfile =
        ref.watch(profilesProvider.select((state) => state.isNotEmpty));

    // No subscription yet → show our own onboarding instead of the power UI.
    if (!hasProfile) return _onboardingView();

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

  // ── top bar: brand + corner menu ───────────────────────────────
  Widget _topBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            const _Logo(size: 24),
            const SizedBox(width: 9),
            Text(
              'RadarShield',
              style: const TextStyle(
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
            _cornerButton(Icons.logout, () {
              globalState.showMessage(
                message: const TextSpan(text: 'Выход из аккаунта — скоро'),
              );
            }),
            const SizedBox(width: 10),
            _cornerButton(Icons.settings_outlined, () {
              ref
                  .read(currentPageLabelProvider.notifier)
                  .toPage(PageLabel.tools);
            }),
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

  // ── the power button ───────────────────────────────────────────
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
                // sonar rings while connecting / connected
                if (connecting || active)
                  ..._sonarRings(size, color, connecting),
                // connecting spinner arc
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
                // core circle (color morph)
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
    final count = 3;
    return List.generate(count, (i) {
      // staggered phase per ring
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

  // ── status text ────────────────────────────────────────────────
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
    return Container(
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
            'Россия · авто',
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
    );
  }

  // ── first-run onboarding (paste subscription link) ─────────────
  Widget _onboardingView() {
    return Material(
      color: _RS.navy,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const _Logo(size: 24),
                  const SizedBox(width: 9),
                  const Text(
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
                          color: _RS.amber.withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Icon(Icons.link, color: _RS.amber, size: 26),
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
                      'Откройте нашего бота в Telegram и скопируйте ссылку. '
                      'Вставьте её сюда — остальное сделаем сами.',
                      style: TextStyle(
                        color: _RS.dim,
                        fontSize: 14.5,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: _pasteSub,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: _RS.amber,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.content_paste, color: _RS.navy, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Вставить ссылку из буфера',
                        style: TextStyle(
                          color: _RS.navy,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: () => ref
                    .read(currentPageLabelProvider.notifier)
                    .toPage(PageLabel.profiles),
                behavior: HitTestBehavior.opaque,
                child: const Center(
                  child: Text(
                    'Ввести вручную или по QR →',
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

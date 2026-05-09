import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tradepact/core/models/trade_model.dart';
import 'package:tradepact/core/services/auth_service.dart';
import 'package:tradepact/core/services/gemini_service.dart';
import 'package:tradepact/core/services/premium_service.dart';
import 'package:tradepact/core/services/storage_service.dart';
import 'package:tradepact/core/services/trade_repository.dart';
import 'package:tradepact/core/theme/app_theme.dart';
import 'package:uuid/uuid.dart';

// ---------------------------------------------------------------------------
// Form state
// ---------------------------------------------------------------------------

class _AddTradeFormState {
  final String pair;
  final String direction;
  final String entry;
  final String sl;
  final String tp;
  final String exitPrice;
  final String lots;
  final String mood;
  final String reason;
  final bool followedPlan;
  final bool respectedSL;
  final String session;
  final String notes;
  final String screenshotUrl;
  final bool isLoading;
  final bool isParsingScreenshot;

  const _AddTradeFormState({
    this.pair = 'XAUUSD',
    this.direction = 'BUY',
    this.entry = '',
    this.sl = '',
    this.tp = '',
    this.exitPrice = '',
    this.lots = '',
    this.mood = 'neutral',
    this.reason = 'setup',
    this.followedPlan = false,
    this.respectedSL = false,
    this.session = 'London',
    this.notes = '',
    this.screenshotUrl = '',
    this.isLoading = false,
    this.isParsingScreenshot = false,
  });

  double get _entryVal => double.tryParse(entry) ?? 0;
  double get _slVal => double.tryParse(sl) ?? 0;
  double get _tpVal => double.tryParse(tp) ?? 0;
  double get _exitVal => double.tryParse(exitPrice) ?? 0;
  double get _lotsVal => double.tryParse(lots) ?? 0;

  double get calculatedPnl {
    if (_exitVal == 0 || _entryVal == 0 || _lotsVal == 0) return 0;
    const multipliers = {
      'XAUUSD': 100.0,
      'EURUSD': 10.0,
      'GBPUSD': 10.0,
      'USDJPY': 10.0,
      'other': 10.0,
    };
    final m = multipliers[pair] ?? 10.0;
    final rawPnl = direction == 'BUY'
        ? (_exitVal - _entryVal) * _lotsVal * m
        : (_entryVal - _exitVal) * _lotsVal * m;
    return double.parse(rawPnl.toStringAsFixed(2));
  }

  double get calculatedRR {
    if (_entryVal == 0 || _slVal == 0 || _tpVal == 0) return 0;
    final risk = (_entryVal - _slVal).abs();
    if (risk == 0) return 0;
    return double.parse(
        ((_tpVal - _entryVal).abs() / risk).toStringAsFixed(2));
  }

  String get autoResult {
    final p = calculatedPnl;
    if (p > 0) return 'WIN';
    if (p < 0) return 'LOSS';
    return 'BE';
  }

  _AddTradeFormState copyWith({
    String? pair,
    String? direction,
    String? entry,
    String? sl,
    String? tp,
    String? exitPrice,
    String? lots,
    String? mood,
    String? reason,
    bool? followedPlan,
    bool? respectedSL,
    String? session,
    String? notes,
    String? screenshotUrl,
    bool? isLoading,
    bool? isParsingScreenshot,
  }) {
    return _AddTradeFormState(
      pair: pair ?? this.pair,
      direction: direction ?? this.direction,
      entry: entry ?? this.entry,
      sl: sl ?? this.sl,
      tp: tp ?? this.tp,
      exitPrice: exitPrice ?? this.exitPrice,
      lots: lots ?? this.lots,
      mood: mood ?? this.mood,
      reason: reason ?? this.reason,
      followedPlan: followedPlan ?? this.followedPlan,
      respectedSL: respectedSL ?? this.respectedSL,
      session: session ?? this.session,
      notes: notes ?? this.notes,
      screenshotUrl: screenshotUrl ?? this.screenshotUrl,
      isLoading: isLoading ?? this.isLoading,
      isParsingScreenshot: isParsingScreenshot ?? this.isParsingScreenshot,
    );
  }
}

// autoDispose so the form resets every time the screen is opened fresh.
final _addTradeFormProvider =
    StateProvider.autoDispose<_AddTradeFormState>((ref) {
  return const _AddTradeFormState();
});

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class AddTradeScreen extends ConsumerStatefulWidget {
  /// Non-null when editing an existing trade.
  final TradeModel? editingTrade;

  const AddTradeScreen({super.key, this.editingTrade});

  @override
  ConsumerState<AddTradeScreen> createState() => _AddTradeScreenState();
}

class _AddTradeScreenState extends ConsumerState<AddTradeScreen> {
  final ImagePicker _picker = ImagePicker();
  Uint8List? _pickedImageBytes;
  String? _editingTradeId;

  // Controllers keep TextFormFields in sync for edit pre-fill.
  late final TextEditingController _entryCtrl;
  late final TextEditingController _slCtrl;
  late final TextEditingController _tpCtrl;
  late final TextEditingController _exitCtrl;
  late final TextEditingController _lotsCtrl;
  late final TextEditingController _notesCtrl;

  @override
  void initState() {
    super.initState();
    final trade = widget.editingTrade;
    _editingTradeId = trade?.id;

    _entryCtrl = TextEditingController(
        text: trade != null && trade.entry != 0
            ? trade.entry.toString()
            : '');
    _slCtrl = TextEditingController(
        text: trade != null && trade.sl != 0 ? trade.sl.toString() : '');
    _tpCtrl = TextEditingController(
        text: trade != null && trade.tp != 0 ? trade.tp.toString() : '');
    _exitCtrl = TextEditingController(
        text: trade != null && trade.exitPrice != 0
            ? trade.exitPrice.toString()
            : '');
    _lotsCtrl = TextEditingController(
        text: trade != null && trade.lots != 0
            ? trade.lots.toString()
            : '');
    _notesCtrl =
        TextEditingController(text: trade?.notes ?? '');

    if (trade != null) {
      // Set Riverpod form state before the first build so chip selectors
      // and toggle fields render the correct initial values.
      ref.read(_addTradeFormProvider.notifier).state = _AddTradeFormState(
        pair: trade.pair,
        direction: trade.direction,
        entry: _entryCtrl.text,
        sl: _slCtrl.text,
        tp: _tpCtrl.text,
        exitPrice: _exitCtrl.text,
        lots: _lotsCtrl.text,
        mood: trade.mood,
        reason: trade.reason,
        followedPlan: trade.followedPlan,
        respectedSL: trade.respectedSL,
        session: trade.session,
        notes: _notesCtrl.text,
        screenshotUrl: trade.screenshotUrl,
      );
    }
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _slCtrl.dispose();
    _tpCtrl.dispose();
    _exitCtrl.dispose();
    _lotsCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  // ---- Screenshot picking --------------------------------------------------

  void _showImageSourceSheet() {
    final isPremium =
        ref.read(isPremiumProvider).valueOrNull ?? false;
    if (!isPremium) {
      context.push('/paywall');
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined,
                  color: AppColors.gold),
              title: Text('Take Photo', style: AppTextStyles.labelMedium),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined,
                  color: AppColors.gold),
              title: Text('Choose from Gallery',
                  style: AppTextStyles.labelMedium),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final xFile = await _picker.pickImage(
        source: source, maxWidth: 1024, imageQuality: 80);
    if (xFile == null || !mounted) return;

    final bytes = await xFile.readAsBytes();
    setState(() => _pickedImageBytes = bytes);

    // Auto-parse screenshot with Gemini.
    ref.read(_addTradeFormProvider.notifier).state =
        ref.read(_addTradeFormProvider).copyWith(isParsingScreenshot: true);

    final parsed =
        await ref.read(geminiServiceProvider).parseChartScreenshot(bytes);

    if (!mounted) return;

    if (parsed != null) {
      debugPrint('[AddTradeScreen] Received parsed data: $parsed');
      final pair = parsed['pair'] as String?;
      final direction = parsed['direction'] as String?;
      final entry = (parsed['entry'] as num?)?.toDouble();
      final sl = (parsed['sl'] as num?)?.toDouble();
      final tp = (parsed['tp'] as num?)?.toDouble();

      // Sync controllers so TextFormFields display the parsed values.
      if (entry != null && entry != 0) {
        _entryCtrl.text = entry.toString();
      }
      if (sl != null && sl != 0) _slCtrl.text = sl.toString();
      if (tp != null && tp != 0) _tpCtrl.text = tp.toString();

      final current = ref.read(_addTradeFormProvider);
      ref.read(_addTradeFormProvider.notifier).state = current.copyWith(
        pair: (pair != null && pair.isNotEmpty) ? pair : null,
        direction: (direction != null && direction.isNotEmpty) ? direction : null,
        entry: entry != null && entry != 0 ? entry.toString() : null,
        sl: sl != null && sl != 0 ? sl.toString() : null,
        tp: tp != null && tp != 0 ? tp.toString() : null,
        isParsingScreenshot: false,
      );
    } else {
      debugPrint('[AddTradeScreen] Gemini returned null or failed to parse.');
      ref.read(_addTradeFormProvider.notifier).state =
          ref.read(_addTradeFormProvider).copyWith(isParsingScreenshot: false);
    }
  }

  // ---- Save ----------------------------------------------------------------

  Future<void> _save(BuildContext context) async {
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;

    final form = ref.read(_addTradeFormProvider);

    // Basic validation: entry and exit price must be filled.
    final entry = double.tryParse(form.entry) ?? 0;
    final exit = double.tryParse(form.exitPrice) ?? 0;
    final lots = double.tryParse(form.lots) ?? 0;
    if (entry == 0 || exit == 0 || lots == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Entry, exit price, and lots are required.'),
          backgroundColor: AppColors.loss,
        ),
      );
      return;
    }

    // Free-tier check: max 20 trades for non-premium users on new trades.
    final isPremium = ref.read(isPremiumProvider).valueOrNull ?? false;
    if (!isPremium && _editingTradeId == null) {
      final stats = ref.read(userStatsProvider).valueOrNull;
      if (stats != null && stats.totalTrades >= 20) {
        if (context.mounted) context.push('/paywall');
        return;
      }
    }

    ref.read(_addTradeFormProvider.notifier).state =
        form.copyWith(isLoading: true);

    try {
      final tradeId = _editingTradeId ?? const Uuid().v4();

      // Upload screenshot if a new image was picked.
      String screenshotUrl = form.screenshotUrl;
      if (_pickedImageBytes != null) {
        screenshotUrl = await ref
            .read(storageServiceProvider)
            .uploadScreenshot(uid, tradeId, _pickedImageBytes!);
      }

      final trade = TradeModel(
        id: tradeId,
        pair: form.pair,
        direction: form.direction,
        entry: double.tryParse(form.entry) ?? 0,
        sl: double.tryParse(form.sl) ?? 0,
        tp: double.tryParse(form.tp) ?? 0,
        exitPrice: double.tryParse(form.exitPrice) ?? 0,
        result: form.autoResult,
        pnl: form.calculatedPnl,
        rr: form.calculatedRR,
        lots: double.tryParse(form.lots) ?? 0,
        mood: form.mood,
        reason: form.reason,
        followedPlan: form.followedPlan,
        respectedSL: form.respectedSL,
        session: form.session,
        notes: form.notes,
        screenshotUrl: screenshotUrl,
        timestamp: widget.editingTrade?.timestamp ?? DateTime.now(),
      );

      final repo = ref.read(tradeRepositoryProvider);
      if (_editingTradeId != null) {
        await repo.updateTrade(uid, trade);
      } else {
        await repo.addTrade(uid, trade);
      }

      HapticFeedback.mediumImpact();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                _editingTradeId != null ? 'Trade updated.' : 'Trade saved.'),
            backgroundColor: AppColors.win,
          ),
        );
        // Edit mode: pop back to detail screen. Add mode: go to trade list.
        if (_editingTradeId != null) {
          context.pop();
        } else {
          context.go('/trades');
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: AppColors.loss,
          ),
        );
      }
      ref.read(_addTradeFormProvider.notifier).state =
          ref.read(_addTradeFormProvider).copyWith(isLoading: false);
    }
  }

  // ---- Build ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final form = ref.watch(_addTradeFormProvider);
    final isEditing = _editingTradeId != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Trade' : 'Log Trade'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Screenshot picker — shown first so Gemini can pre-fill fields.
            _ScreenshotPicker(
              pickedBytes: _pickedImageBytes,
              existingUrl: form.screenshotUrl,
              isParsing: form.isParsingScreenshot,
              onPickTap: _showImageSourceSheet,
            ),
            const SizedBox(height: 20),
            const _SectionLabel('Instrument'),
            const SizedBox(height: 8),
            _PairSelector(form: form),
            const SizedBox(height: 20),
            const _SectionLabel('Direction'),
            const SizedBox(height: 8),
            _DirectionToggle(form: form),
            const SizedBox(height: 20),
            const _SectionLabel('Prices'),
            const SizedBox(height: 8),
            _PriceFields(
              form: form,
              entryCtrl: _entryCtrl,
              slCtrl: _slCtrl,
              tpCtrl: _tpCtrl,
              exitCtrl: _exitCtrl,
              lotsCtrl: _lotsCtrl,
            ),
            const SizedBox(height: 20),
            _PnLDisplay(form: form),
            const SizedBox(height: 20),
            const _SectionLabel('Session'),
            const SizedBox(height: 8),
            _SessionSelector(form: form),
            const SizedBox(height: 20),
            const _SectionLabel('Psychology'),
            const SizedBox(height: 8),
            _MoodSelector(form: form),
            const SizedBox(height: 16),
            _ReasonSelector(form: form),
            const SizedBox(height: 16),
            _DisciplineToggles(form: form),
            const SizedBox(height: 20),
            const _SectionLabel('Notes'),
            const SizedBox(height: 8),
            _NotesField(notesCtrl: _notesCtrl, form: form),
            const SizedBox(height: 32),
            _SaveButton(
              form: form,
              onSave: () => _save(context),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Screenshot picker widget
// ---------------------------------------------------------------------------

class _ScreenshotPicker extends StatelessWidget {
  final Uint8List? pickedBytes;
  final String existingUrl;
  final bool isParsing;
  final VoidCallback onPickTap;

  const _ScreenshotPicker({
    required this.pickedBytes,
    required this.existingUrl,
    required this.isParsing,
    required this.onPickTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget content;

    if (isParsing) {
      content = const SizedBox(
        height: 140,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppColors.gold),
              SizedBox(height: 12),
              Text('Parsing chart...', style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              )),
            ],
          ),
        ),
      );
    } else if (pickedBytes != null) {
      content = Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(
              pickedBytes!,
              width: double.infinity,
              height: 160,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: onPickTap,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.border),
                ),
                child: const Icon(Icons.edit, size: 14, color: AppColors.gold),
              ),
            ),
          ),
        ],
      );
    } else if (existingUrl.isNotEmpty) {
      content = Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              existingUrl,
              width: double.infinity,
              height: 160,
              fit: BoxFit.cover,
              loadingBuilder: (_, child, progress) =>
                  progress == null ? child : const SizedBox(height: 160),
              errorBuilder: (_, __, ___) => const SizedBox(height: 0),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: onPickTap,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.border),
                ),
                child: const Icon(Icons.edit, size: 14, color: AppColors.gold),
              ),
            ),
          ),
        ],
      );
    } else {
      // Empty state — tap to pick.
      content = GestureDetector(
        onTap: onPickTap,
        child: Container(
          height: 80,
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: AppColors.border, style: BorderStyle.solid),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.add_photo_alternate_outlined,
                  color: AppColors.gold, size: 22),
              const SizedBox(width: 8),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Add Chart Screenshot',
                      style: AppTextStyles.labelMedium
                          .copyWith(color: AppColors.gold)),
                  Text('Gemini will auto-fill trade fields  ✨',
                      style: AppTextStyles.caption),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return content;
  }
}

// ---------------------------------------------------------------------------
// Shared section label
// ---------------------------------------------------------------------------

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: AppTextStyles.labelSmall
          .copyWith(fontSize: 11, letterSpacing: 1.2),
    );
  }
}

// ---------------------------------------------------------------------------
// Pair selector
// ---------------------------------------------------------------------------

class _PairSelector extends ConsumerWidget {
  final _AddTradeFormState form;
  const _PairSelector({required this.form});

  static const _pairs = ['XAUUSD', 'EURUSD', 'GBPUSD', 'USDJPY', 'other'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _pairs.map((p) {
        final selected = form.pair == p;
        return GestureDetector(
          onTap: () => ref.read(_addTradeFormProvider.notifier).state =
              form.copyWith(pair: p),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? AppColors.gold : AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: selected ? AppColors.gold : AppColors.border),
            ),
            child: Text(
              p,
              style: AppTextStyles.numberSmall.copyWith(
                color: selected
                    ? AppColors.background
                    : AppColors.textPrimary,
                fontSize: 13,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ---------------------------------------------------------------------------
// Direction toggle
// ---------------------------------------------------------------------------

class _DirectionToggle extends ConsumerWidget {
  final _AddTradeFormState form;
  const _DirectionToggle({required this.form});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Expanded(child: _btn('BUY', AppColors.win, ref)),
        const SizedBox(width: 12),
        Expanded(child: _btn('SELL', AppColors.loss, ref)),
      ],
    );
  }

  Widget _btn(String dir, Color color, WidgetRef ref) {
    final selected = form.direction == dir;
    return GestureDetector(
      onTap: () => ref.read(_addTradeFormProvider.notifier).state =
          form.copyWith(direction: dir),
      child: Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? color.withAlpha(40) : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          dir,
          style: AppTextStyles.labelMedium.copyWith(
            color: selected ? color : AppColors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Price fields — uses controllers so edit-mode pre-fills work correctly.
// ---------------------------------------------------------------------------

class _PriceFields extends ConsumerWidget {
  final _AddTradeFormState form;
  final TextEditingController entryCtrl;
  final TextEditingController slCtrl;
  final TextEditingController tpCtrl;
  final TextEditingController exitCtrl;
  final TextEditingController lotsCtrl;

  const _PriceFields({
    required this.form,
    required this.entryCtrl,
    required this.slCtrl,
    required this.tpCtrl,
    required this.exitCtrl,
    required this.lotsCtrl,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void update(_AddTradeFormState s) =>
        ref.read(_addTradeFormProvider.notifier).state = s;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
                child: _numField('Entry', entryCtrl,
                    (v) => update(form.copyWith(entry: v)))),
            const SizedBox(width: 12),
            Expanded(
                child: _numField('Lots', lotsCtrl,
                    (v) => update(form.copyWith(lots: v)))),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
                child: _numField('Stop Loss', slCtrl,
                    (v) => update(form.copyWith(sl: v)))),
            const SizedBox(width: 12),
            Expanded(
                child: _numField('Take Profit', tpCtrl,
                    (v) => update(form.copyWith(tp: v)))),
          ],
        ),
        const SizedBox(height: 12),
        _numField('Exit Price', exitCtrl,
            (v) => update(form.copyWith(exitPrice: v))),
      ],
    );
  }

  Widget _numField(
      String label, TextEditingController ctrl, ValueChanged<String> onChanged) {
    return TextFormField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
      ],
      style: AppTextStyles.numberSmall,
      onChanged: onChanged,
      decoration: InputDecoration(labelText: label),
    );
  }
}

// ---------------------------------------------------------------------------
// P&L display
// ---------------------------------------------------------------------------

class _PnLDisplay extends StatelessWidget {
  final _AddTradeFormState form;
  const _PnLDisplay({required this.form});

  @override
  Widget build(BuildContext context) {
    final pnl = form.calculatedPnl;
    final rr = form.calculatedRR;
    final pnlColor = pnl > 0
        ? AppColors.win
        : pnl < 0
            ? AppColors.loss
            : AppColors.textSecondary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(child: _col('P&L',
              '${pnl >= 0 ? '+' : ''}\$${pnl.toStringAsFixed(2)}', pnlColor)),
          Expanded(child: _col('R:R',
              rr == 0 ? '--' : '1:${rr.toStringAsFixed(2)}', null)),
          Expanded(child: _col('Result', form.autoResult, pnlColor)),
        ],
      ),
    );
  }

  Widget _col(String label, String value, Color? color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.labelSmall),
        const SizedBox(height: 4),
        Text(value,
            style: AppTextStyles.numberMedium
                .copyWith(color: color ?? AppColors.textPrimary)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Session selector
// ---------------------------------------------------------------------------

class _SessionSelector extends ConsumerWidget {
  final _AddTradeFormState form;
  const _SessionSelector({required this.form});

  static const _sessions = ['London', 'New York', 'Asia', 'Other'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _sessions.map((s) {
        final selected = form.session == s;
        return GestureDetector(
          onTap: () => ref.read(_addTradeFormProvider.notifier).state =
              form.copyWith(session: s),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.gold.withAlpha(30)
                  : AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: selected ? AppColors.gold : AppColors.border),
            ),
            child: Text(
              s,
              style: AppTextStyles.labelMedium.copyWith(
                color: selected
                    ? AppColors.gold
                    : AppColors.textSecondary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ---------------------------------------------------------------------------
// Mood selector
// ---------------------------------------------------------------------------

class _MoodSelector extends ConsumerWidget {
  final _AddTradeFormState form;
  const _MoodSelector({required this.form});

  static const _moods = {
    'confident': '😎',
    'anxious': '😰',
    'bored': '😑',
    'revenge': '😤',
    'neutral': '😐',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Mood',
            style: AppTextStyles.labelSmall
                .copyWith(fontSize: 11, letterSpacing: 1.2)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _moods.entries.map((e) {
            final selected = form.mood == e.key;
            final isDangerous = e.key == 'revenge' || e.key == 'anxious';
            return GestureDetector(
              onTap: () => ref.read(_addTradeFormProvider.notifier).state =
                  form.copyWith(mood: e.key),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: selected
                      ? (isDangerous
                          ? AppColors.loss.withAlpha(30)
                          : AppColors.gold.withAlpha(30))
                      : AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected
                        ? (isDangerous ? AppColors.loss : AppColors.gold)
                        : AppColors.border,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(e.value,
                        style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 6),
                    Text(
                      e.key,
                      style: AppTextStyles.labelMedium.copyWith(
                        color: selected
                            ? (isDangerous
                                ? AppColors.loss
                                : AppColors.gold)
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Reason selector
// ---------------------------------------------------------------------------

class _ReasonSelector extends ConsumerWidget {
  final _AddTradeFormState form;
  const _ReasonSelector({required this.form});

  static const _reasons = ['setup', 'impulse', 'FOMO', 'other'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Trade Reason',
            style: AppTextStyles.labelSmall
                .copyWith(fontSize: 11, letterSpacing: 1.2)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _reasons.map((r) {
            final selected = form.reason == r;
            final isDangerous = r == 'impulse' || r == 'FOMO';
            return GestureDetector(
              onTap: () => ref.read(_addTradeFormProvider.notifier).state =
                  form.copyWith(reason: r),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: selected
                      ? (isDangerous
                          ? AppColors.loss.withAlpha(30)
                          : AppColors.gold.withAlpha(30))
                      : AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected
                        ? (isDangerous ? AppColors.loss : AppColors.gold)
                        : AppColors.border,
                  ),
                ),
                child: Text(
                  r,
                  style: AppTextStyles.labelMedium.copyWith(
                    color: selected
                        ? (isDangerous ? AppColors.loss : AppColors.gold)
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Discipline toggles
// ---------------------------------------------------------------------------

class _DisciplineToggles extends ConsumerWidget {
  final _AddTradeFormState form;
  const _DisciplineToggles({required this.form});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _row(
            'Followed plan',
            form.followedPlan,
            '40 pts',
            (v) => ref.read(_addTradeFormProvider.notifier).state =
                form.copyWith(followedPlan: v),
          ),
          const Divider(height: 1),
          _row(
            'Respected SL',
            form.respectedSL,
            '30 pts',
            (v) => ref.read(_addTradeFormProvider.notifier).state =
                form.copyWith(respectedSL: v),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, bool value, String pts,
      ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.labelMedium),
                Text(pts,
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.gold)),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Notes field
// ---------------------------------------------------------------------------

class _NotesField extends ConsumerWidget {
  final _AddTradeFormState form;
  final TextEditingController notesCtrl;
  const _NotesField({required this.form, required this.notesCtrl});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TextFormField(
      controller: notesCtrl,
      maxLines: 3,
      style: AppTextStyles.bodyMedium,
      onChanged: (v) => ref.read(_addTradeFormProvider.notifier).state =
          form.copyWith(notes: v),
      decoration: const InputDecoration(
        hintText: 'What did you observe? Anything noteworthy...',
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Save button
// ---------------------------------------------------------------------------

class _SaveButton extends StatelessWidget {
  final _AddTradeFormState form;
  final VoidCallback onSave;
  const _SaveButton({required this.form, required this.onSave});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: (form.isLoading || form.isParsingScreenshot) ? null : onSave,
      child: form.isLoading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.background,
              ),
            )
          : const Text('Save Trade'),
    );
  }
}

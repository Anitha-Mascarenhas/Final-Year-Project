import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../state/locale_provider.dart';
import '../state/session_provider.dart';
import '../state/vitals_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/image_picker_helper.dart';
import '../utils/l10n_extension.dart';
import '../utils/pdf_exporter.dart';
import '../widgets/interactive_eye_logo.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  final String childName;
  final String? childId;
  final VoidCallback? onLogout;
  final bool initialHistoryView;

  const ProfileScreen({
    Key? key,
    this.childName = 'Aarav',
    this.childId,
    this.onLogout,
    this.initialHistoryView = false,
  }) : super(key: key);

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isDarkMode = false;
  bool _isHistoryView = false;
  int _historyMetricIndex = 0;

  Color get _pageBackground =>
      _isDarkMode ? const Color(0xFF14241B) : const Color(0xFFEEF3ED);
  Color get _primaryText =>
      _isDarkMode ? const Color(0xFFE8F2EA) : const Color(0xFF0C2417);
  Color get _secondaryText =>
      _isDarkMode ? const Color(0xFFA9C0B1) : const Color(0xFF556D5E);
  Color get _cardColor => _isDarkMode ? const Color(0xFF1D3528) : Colors.white;
  Color get _cardBorder =>
      _isDarkMode ? const Color(0xFF34513F) : const Color(0xFFE2EAE2);
  Color get _softSurface =>
      _isDarkMode ? const Color(0xFF294535) : const Color(0xFFF4F7F4);
  Color get _dividerColor =>
      _isDarkMode ? const Color(0xFF34513F) : const Color(0xFFF0F4F0);

  String _childName = 'Aarav';
  String _age = 'Not recorded';
  String _parentName = 'Not recorded';
  String _accountType = 'Premium Account';

  @override
  void initState() {
    super.initState();
    _childName = widget.childName;
    _isHistoryView = widget.initialHistoryView;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final session = ref.read(sessionProvider);
      final id = widget.childId ?? session.childId;
      if (id != null && session.accessToken != null) {
        ref
            .read(vitalsProvider.notifier)
            .loadForChild(id, session.accessToken!)
            .then<void>((_) {}, onError: (_) {});
      }
    });
  }

  Future<void> _pickChildImage() async {
    try {
      final bytes = await pickImageBytes();
      if (bytes != null && mounted) {
        ref.read(childProfileImageProvider.notifier).setImage(bytes);
      }
    } catch (e) {
      debugPrint('Error picking child image: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppThemeTransition(
      isDark: _isDarkMode,
      child: Scaffold(
        backgroundColor: _pageBackground,
        body: SafeArea(
          child: Column(
            children: [
              _buildTopBar(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(
                      left: 18, right: 18, top: 6, bottom: 130),
                  child: _isHistoryView
                      ? _buildHistoryView()
                      : _buildProfileView(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back, color: _primaryText),
                onPressed: () {
                  if (widget.initialHistoryView &&
                      Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  } else if (_isHistoryView) {
                    setState(() => _isHistoryView = false);
                  } else if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  }
                },
              ),
              InteractiveEyeLogo(width: 26, color: _primaryText),
              const SizedBox(width: 6),
              Text(
                _isHistoryView
                    ? l10n.childHistoryTitle
                    : l10n.childProfileTitle,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: _primaryText,
                ),
              ),
            ],
          ),
          Row(
            children: [
              GestureDetector(
                onTap: () => setState(() => _isDarkMode = !_isDarkMode),
                child: Container(
                  width: 54,
                  height: 28,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: _isDarkMode
                        ? const Color(0xFF294535)
                        : const Color(0xFFDFE8DF),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _isDarkMode
                          ? const Color(0xFF45624E)
                          : const Color(0xFFCEDECE),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: _isDarkMode
                        ? MainAxisAlignment.end
                        : MainAxisAlignment.start,
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: _isDarkMode
                              ? const Color(0xFF0F3827)
                              : const Color(0xFF2AE196),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _isDarkMode ? Icons.nightlight_round : Icons.wb_sunny,
                          size: 13,
                          color: _isDarkMode
                              ? Colors.white
                              : const Color(0xFF0C2417),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                radius: 16,
                backgroundColor: _isDarkMode
                    ? const Color(0xFF2AE196)
                    : const Color(0xFF0C2417),
                child: Icon(
                  Icons.person_outline,
                  size: 16,
                  color: _isDarkMode ? const Color(0xFF0C2417) : Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfileView() {
    final latest = ref.watch(latestVitalsProvider);
    _age = latest?.formattedAge ?? 'Not recorded';
    final l10n = context.l10n;
    final childImageBytes = ref.watch(childProfileImageProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // AARAV'S PROFILE
        Text(
          l10n.profileHeader(_childName.toUpperCase()),
          style: TextStyle(
            fontSize: 44,
            fontWeight: FontWeight.w900,
            color: _primaryText,
            height: 0.94,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 12),

        // CHILD HISTORY
        Card(
          color: _cardColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: _cardBorder),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => setState(() => _isHistoryView = true),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.history_rounded, color: Color(0xFF059669)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.childHistoryTitle,
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: _primaryText)),
                        const SizedBox(height: 3),
                        Text('View previous screenings and health records',
                            style:
                                TextStyle(fontSize: 12, color: _secondaryText)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: _secondaryText),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 01 CHILD PROFILE
        _buildSectionHeader(l10n.secChildProfile),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _cardBorder),
          ),
          child: Row(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _pickChildImage,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: _softSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _isDarkMode
                          ? const Color(0xFF45624E)
                          : const Color(0xFFD8E3D8),
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: childImageBytes != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.memory(
                                childImageBytes,
                                fit: BoxFit.cover,
                              ),
                              Positioned(
                                right: 6,
                                bottom: 6,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.65),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.edit,
                                    size: 13,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate_outlined,
                                size: 28, color: _secondaryText),
                            const SizedBox(height: 4),
                            Text(l10n.noPhoto,
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    color: _secondaryText,
                                    letterSpacing: 0.8)),
                          ],
                        ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_childName,
                            style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: _primaryText)),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          onPressed: _showEditChildModal,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    _infoRow(l10n.ageLabel.toUpperCase(), _age),
                    const SizedBox(height: 3),
                    _infoRow(
                        'HEIGHT', latest?.formattedHeight ?? 'Not recorded'),
                    const SizedBox(height: 3),
                    _infoRow(
                        'WEIGHT', latest?.formattedWeight ?? 'Not recorded'),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // 02 PARENT / ACCOUNT
        _buildSectionHeader(l10n.secParentAccount),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _cardBorder),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_parentName,
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: _primaryText)),
                  const SizedBox(height: 2),
                  Text(_accountType,
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: _secondaryText)),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18),
                onPressed: _showEditParentModal,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // 03 PREFERENCES
        _buildSectionHeader(l10n.secPreferences),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _cardBorder),
          ),
          child: Column(
            children: [
              _menuItem('01', Icons.notifications_none, l10n.notifications),
              Divider(height: 1, color: _dividerColor),
              _menuItem('02', Icons.settings_outlined, l10n.appSettings),
              Divider(height: 1, color: _dividerColor),
              _menuItem('03', Icons.people_outline, l10n.manageProfiles),
              Divider(height: 1, color: _dividerColor),
              _buildLanguageSelector(context),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // 04 SUPPORT
        _buildSectionHeader(l10n.secSupport),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _cardBorder),
          ),
          child: Column(
            children: [
              _menuItem('01', Icons.help_outline, l10n.helpCenter),
              Divider(height: 1, color: _dividerColor),
              _menuItem('02', Icons.shield_outlined, l10n.privacySecurity),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // 05 Sign Out
        GestureDetector(
          onTap: widget.onLogout ??
              () => Navigator.of(context).popUntil((route) => route.isFirst),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text('05',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: _secondaryText)),
                  const SizedBox(width: 10),
                  Text(l10n.signOut,
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: _primaryText)),
                ],
              ),
              Icon(Icons.logout, color: _primaryText, size: 24),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildLanguageSelector(BuildContext context) {
    final l10n = context.l10n;
    final currentLocale = ref.watch(localeProvider);

    final languages = [
      {'code': 'en', 'name': 'English'},
      {'code': 'hi', 'name': 'हिन्दी'},
      {'code': 'kn', 'name': 'ಕನ್ನಡ'},
    ];

    final selectedLangName = languages.firstWhere(
      (l) => l['code'] == currentLocale.languageCode,
      orElse: () => languages[0],
    )['name']!;

    return GestureDetector(
      onTap: () => _showLanguageModal(context),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text('04',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _secondaryText)),
                const SizedBox(width: 12),
                Icon(Icons.language_rounded, size: 18, color: _primaryText),
                const SizedBox(width: 10),
                Text(
                  l10n.selectLanguage,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: _primaryText),
                ),
              ],
            ),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2DE099).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: const Color(0xFF2DE099).withOpacity(0.4)),
                  ),
                  child: Text(
                    selectedLangName,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: _isDarkMode
                          ? const Color(0xFF2DE099)
                          : const Color(0xFF0C2417),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Icon(Icons.chevron_right, size: 18, color: _secondaryText),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showLanguageModal(BuildContext context) {
    final l10n = context.l10n;
    final currentLocale = ref.read(localeProvider);

    final options = [
      {'code': 'en', 'name': 'English', 'sub': 'Default'},
      {'code': 'hi', 'name': 'हिन्दी', 'sub': 'Hindi'},
      {'code': 'kn', 'name': 'ಕನ್ನಡ', 'sub': 'Kannada'},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.selectLanguage,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: _primaryText,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close_rounded, color: _secondaryText),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ...options.map((opt) {
                    final isSelected =
                        opt['code'] == currentLocale.languageCode;
                    return GestureDetector(
                      onTap: () {
                        ref
                            .read(localeProvider.notifier)
                            .setLocale(Locale(opt['code']!));
                        Navigator.pop(ctx);
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF2DE099).withOpacity(0.12)
                              : _softSurface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF2DE099)
                                : _cardBorder,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Text(
                                  opt['name']!,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: isSelected
                                        ? const Color(0xFF2DE099)
                                        : _primaryText,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '(${opt['sub']})',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: _secondaryText,
                                  ),
                                ),
                              ],
                            ),
                            if (isSelected)
                              const Icon(
                                Icons.check_circle_rounded,
                                color: Color(0xFF2DE099),
                                size: 22,
                              ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _monthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return months[(month - 1).clamp(0, 11)];
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'pm' : 'am';
    return '$hour:$minute $period';
  }

  Future<void> _exportHistoryPdf() async {
    final records = ref.read(vitalsProvider);
    final now = DateTime.now();
    final pdf = pw.Document();
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(42),
      build: (context) => [
        pw.Text('PoshanEye',
            style: pw.TextStyle(fontSize: 25, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        pw.Text('Child health record', style: const pw.TextStyle(fontSize: 18)),
        pw.SizedBox(height: 4),
        pw.Text('Generated ${DateFormat('d MMM yyyy, h:mm a').format(now)}'),
        pw.SizedBox(height: 18),
        pw.Text('Child: $_childName',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 12),
        if (records.isEmpty)
          pw.Text(
              'No screening or health measurements have been recorded for this child.')
        else ...[
          pw.Text('Screening and measurement history',
              style:
                  pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          ...records.expand((record) => <pw.Widget>[
                pw.SizedBox(height: 8),
                pw.Text(DateFormat('d MMM yyyy, h:mm a').format(record.date),
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text(
                    'Age: ${record.formattedAge}    Gender: ${record.gender}'),
                pw.Text(
                    'Height: ${record.formattedHeight}    Weight: ${record.formattedWeight}    BMI: ${record.formattedBmi}'),
                pw.Text(
                    'MUAC: ${VitalsRecord.value(record.muacCm, 'cm')}    Head circumference: ${VitalsRecord.value(record.headCircumferenceCm, 'cm')}    Waist: ${VitalsRecord.value(record.waistCm, 'cm')}'),
                pw.Text('Status: ${record.status}'),
                if (record.prediction != null)
                  pw.Text('AI screening result: ${record.prediction}'),
                if (record.confidence != null)
                  pw.Text(
                      'Model confidence score: ${(record.confidence! * 100).toStringAsFixed(1)}% (model score, not a clinical probability)'),
                if (record.risk != null)
                  pw.Text('Risk / status: ${record.risk}'),
                if (record.recommendation != null)
                  pw.Text('Recommendation: ${record.recommendation}'),
                pw.Divider(color: PdfColors.grey400),
              ]),
        ],
        pw.SizedBox(height: 20),
        pw.Text(
            'This report contains records available in PoshanEye at the time of export.',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
      ],
    ));
    try {
      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename:
            'PoshanEye_${_childName.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_')}_record.pdf',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF is ready to share or save.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Could not create or share the PDF. Please try again.')),
        );
      }
      debugPrint('PDF export failed: $error');
    }
  }

  Widget _buildHistoryView() {
    final vitalsList = ref.watch(vitalsProvider).toList();
    final historyError = ref.watch(vitalsHistoryErrorProvider);
    final latest = ref.watch(latestVitalsProvider);
    final session = ref.watch(sessionProvider);
    final childId = widget.childId ?? session.childId ?? 'Not recorded';
    final age = latest?.formattedAge ?? 'Not recorded';
    final gender = latest?.gender ?? 'Not recorded';
    final status = latest?.status ?? 'Not recorded';
    final height = latest?.formattedHeight ?? 'Not recorded';
    final weight = latest?.formattedWeight ?? 'Not recorded';
    final muac = VitalsRecord.value(latest?.muacCm, 'cm');
    final bmi = latest?.formattedBmi ?? 'Not recorded';
    final lastScreened = latest?.recordedAt == null
        ? 'Not recorded'
        : DateFormat('d MMM yyyy').format(latest!.recordedAt!);

    final metrics = [
      {
        'label': 'HEIGHT',
        'value': latest?.formattedHeight ?? 'Not recorded',
        'icon': Icons.straighten,
        'idx': '01 / 05'
      },
      {
        'label': 'WEIGHT',
        'value': latest?.formattedWeight ?? 'Not recorded',
        'icon': Icons.scale,
        'idx': '02 / 05'
      },
      {
        'label': 'AGE',
        'value': latest?.formattedAge ?? 'Not recorded',
        'icon': Icons.calendar_today,
        'idx': '03 / 05'
      },
      {
        'label': 'GENDER',
        'value': latest?.gender ?? 'Not recorded',
        'icon': Icons.person_outline,
        'idx': '04 / 05'
      },
      {
        'label': 'BMI',
        'value': latest?.formattedBmi ?? 'Not recorded',
        'icon': Icons.monitor_weight_outlined,
        'idx': '05 / 05'
      },
    ];
    final activeIndex = _historyMetricIndex.clamp(0, metrics.length - 1);
    final active = metrics[activeIndex];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text('CHILD HISTORY',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: _secondaryText,
                letterSpacing: 1.5)),
        const SizedBox(height: 2),
        Text(_childName,
            style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: _primaryText)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color:
                _isDarkMode ? const Color(0xFF214A35) : const Color(0xFFE8F5E8),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: _isDarkMode
                    ? const Color(0xFF4B9962)
                    : const Color(0xFFBCE4BC)),
          ),
          child: Text('Health status : ${latest?.status ?? "Not recorded"}',
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF065F46))),
        ),
        const SizedBox(height: 10),
        Text('A clear record of growth measurements and screenings.',
            style: TextStyle(fontSize: 13, color: _secondaryText)),
        const SizedBox(height: 14),

        // Export PDF Action Button
        ElevatedButton.icon(
          onPressed: () {
            PdfReportHelper.generateAndExportReport(
              childId: childId,
              childName: _childName,
              age: age,
              gender: gender,
              guardianName: _parentName,
              status: status,
              height: height,
              weight: weight,
              muac: muac,
              bmiOrZScore: bmi,
              lastScreened: lastScreened,
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryForest,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
          label: const Text(
            'Export PDF Report',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 16),

        // CURRENT DETAILS (01 / 05)
        Align(
            alignment: Alignment.centerLeft,
            child: _buildSectionHeader('CURRENT DETAILS',
                right: active['idx'] as String)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => setState(() =>
              _historyMetricIndex = (_historyMetricIndex + 1) % metrics.length),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: _cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(active['icon'] as IconData, color: _secondaryText),
                const SizedBox(height: 10),
                Text(active['label'] as String,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: _secondaryText,
                        letterSpacing: 1)),
                const SizedBox(height: 4),
                Text(active['value'] as String,
                    style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: _primaryText)),
                const SizedBox(height: 12),
                Row(
                  children: List.generate(
                      metrics.length,
                      (i) => Container(
                            margin: const EdgeInsets.only(right: 6),
                            width: i == activeIndex ? 22 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: i == activeIndex
                                  ? const Color(0xFF10B981)
                                  : (_isDarkMode
                                      ? const Color(0xFF45624E)
                                      : const Color(0xFFD0DDD0)),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          )),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),

        // PREVIOUS SCANS & RECORDS
        Align(
            alignment: Alignment.centerLeft,
            child: _buildSectionHeader('PREVIOUS SCANS & RECORDS',
                right:
                    '${vitalsList.length.toString().padLeft(2, '0')} entries')),
        const SizedBox(height: 8),
        if (historyError != null)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: _cardBorder),
            ),
            child: Column(children: [
              Text('Unable to load screening history.',
                  style: TextStyle(color: _secondaryText)),
              TextButton(
                onPressed: (widget.childId ?? session.childId) == null || session.accessToken == null
                    ? null
                    : () => ref.read(vitalsProvider.notifier)
                        .loadForChild(widget.childId ?? session.childId!, session.accessToken!),
                child: const Text('Retry'),
              ),
            ]),
          )
        else if (vitalsList.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: _cardBorder),
            ),
            child: Center(
              child: Text('No vitals records logged yet.',
                  style: TextStyle(color: _secondaryText)),
            ),
          )
        else
          ...vitalsList.map((record) {
            final dateStr =
                "${record.date.day} ${_monthName(record.date.month)} ${record.date.year}, ${_formatTime(record.date)}";
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: _cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('LOGGED VITALS',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: _secondaryText)),
                      Text(dateStr,
                          style:
                              TextStyle(fontSize: 11.5, color: _secondaryText)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                      'MUAC: ${VitalsRecord.value(record.muacCm, 'cm')}  •  Head circumference: ${VitalsRecord.value(record.headCircumferenceCm, 'cm')}  •  Waist: ${VitalsRecord.value(record.waistCm, 'cm')}',
                      style: TextStyle(fontSize: 12, color: _secondaryText)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(record.status,
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: _primaryText)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFF10B981).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(record.gender ?? 'Not recorded',
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F3827))),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _statCol('HEIGHT', record.formattedHeight),
                      _statCol('WEIGHT', record.formattedWeight),
                      _statCol('BMI', record.formattedBmi),
                      _statCol('AGE', record.formattedAge),
                    ],
                  ),
                  if (record.prediction != null) ...[
                    const SizedBox(height: 10),
                    Text('AI screening: ${record.prediction}',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, color: _primaryText)),
                    if (record.confidence != null)
                      Text('Confidence: ${(record.confidence! * 100).toStringAsFixed(1)}%',
                          style: TextStyle(color: _secondaryText)),
                  ],
                  if (record.risk != null)
                    Text('Risk / status: ${record.risk}',
                        style: TextStyle(color: _secondaryText)),
                  if (record.probabilities.isNotEmpty)
                    Text('Class scores: ${record.probabilities.entries.map((e) => '${e.key} ${(e.value * 100).toStringAsFixed(1)}%').join(' • ')}',
                        style: TextStyle(color: _secondaryText, fontSize: 12)),
                  if (record.recommendation != null) ...[
                    const SizedBox(height: 4),
                    Text(record.recommendation!,
                        style: TextStyle(color: _secondaryText, height: 1.35)),
                  ],
                ],
              ),
            );
          }).toList(),
        const SizedBox(height: 18),

        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _exportHistoryPdf,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.forestGreen,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(50),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.picture_as_pdf, size: 18),
              SizedBox(width: 8),
              Text('Export PDF report',
                  style:
                      TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildSectionHeader(String title, {String right = '/'}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: _secondaryText,
                letterSpacing: 0.8)),
        Text(right,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: _secondaryText)),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: _secondaryText,
                letterSpacing: 0.6)),
        Text(value,
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                color: _primaryText)),
      ],
    );
  }

  Widget _menuItem(String num, IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(num,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _secondaryText)),
              const SizedBox(width: 12),
              Icon(icon, size: 18, color: _primaryText),
              const SizedBox(width: 10),
              Text(title,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: _primaryText)),
            ],
          ),
          Icon(Icons.chevron_right, size: 18, color: _secondaryText),
        ],
      ),
    );
  }

  Widget _statCol(String label, String val) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: _secondaryText)),
        const SizedBox(height: 2),
        Text(val,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: _primaryText)),
      ],
    );
  }

  void _showEditChildModal() {
    final nameCtrl = TextEditingController(text: _childName);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('Edit child profile',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Name')),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _childName = nameCtrl.text;
              });
              Navigator.pop(ctx);
            },
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }

  void _showEditParentModal() {
    final parentCtrl = TextEditingController(text: _parentName);
    final typeCtrl = TextEditingController(text: _accountType);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('Edit parent account',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: parentCtrl,
                decoration: const InputDecoration(labelText: 'Parent name')),
            TextField(
                controller: typeCtrl,
                decoration: const InputDecoration(labelText: 'Account type')),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _parentName = parentCtrl.text;
                _accountType = typeCtrl.text;
              });
              Navigator.pop(ctx);
            },
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }
}

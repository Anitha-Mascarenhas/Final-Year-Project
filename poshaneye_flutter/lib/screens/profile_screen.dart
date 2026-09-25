import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/vitals_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/image_picker_helper.dart';
import '../widgets/interactive_eye_logo.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  final String childName;
  final VoidCallback? onLogout;
  final bool initialHistoryView;

  const ProfileScreen({
    Key? key,
    this.childName = 'Aarav',
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
  String _age = '2 years, 3 months';
  String _gender = 'Boy';
  String _status = 'On Track';
  String _parentName = 'Sarah & Leo';
  String _accountType = 'Premium Account';

  @override
  void initState() {
    super.initState();
    _childName = widget.childName;
    _isHistoryView = widget.initialHistoryView;
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
                  if (_isHistoryView) {
                    setState(() => _isHistoryView = false);
                  } else {
                    Navigator.of(context).pop();
                  }
                },
              ),
              InteractiveEyeLogo(width: 26, color: _primaryText),
              const SizedBox(width: 6),
              Text(
                _isHistoryView ? 'Child History' : 'Child Profile',
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
    final childImageBytes = ref.watch(childProfileImageProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // AARAV'S PROFILE
        Text(
          "${_childName.toUpperCase()}'S\nPROFILE",
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
        GestureDetector(
          onTap: () => setState(() => _isHistoryView = true),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              border: Border.symmetric(
                horizontal: BorderSide(
                  color: _isDarkMode
                      ? const Color(0xFF34513F)
                      : const Color(0xFFD8E3D8),
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'CHILD HISTORY',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                    color: _secondaryText,
                    letterSpacing: 1.2,
                  ),
                ),
                Row(
                  children: [
                    Text('01—05',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _secondaryText)),
                    Icon(Icons.chevron_right, size: 18, color: _secondaryText),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 01 CHILD PROFILE
        _buildSectionHeader('01 CHILD PROFILE'),
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
                            Text('NO PHOTO',
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
                    _infoRow('AGE', _age),
                    const SizedBox(height: 3),
                    _infoRow('GENDER', _gender),
                    const SizedBox(height: 3),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('STATUS',
                            style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: _secondaryText,
                                letterSpacing: 0.6)),
                        Text(_status,
                            style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF10B981))),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // 02 PARENT / ACCOUNT
        _buildSectionHeader('02 PARENT / ACCOUNT'),
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
        _buildSectionHeader('03 PREFERENCES'),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _cardBorder),
          ),
          child: Column(
            children: [
              _menuItem('01', Icons.notifications_none, 'Notifications'),
              Divider(height: 1, color: _dividerColor),
              _menuItem('02', Icons.settings_outlined, 'App Settings'),
              Divider(height: 1, color: _dividerColor),
              _menuItem('03', Icons.people_outline, 'Manage Profiles'),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // 04 SUPPORT
        _buildSectionHeader('04 SUPPORT'),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _cardBorder),
          ),
          child: Column(
            children: [
              _menuItem('01', Icons.help_outline, 'Help Center'),
              Divider(height: 1, color: _dividerColor),
              _menuItem('02', Icons.shield_outlined, 'Privacy & Security'),
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
                  Text('Sign Out',
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

  String _monthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[(month - 1).clamp(0, 11)];
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'pm' : 'am';
    return '$hour:$minute $period';
  }

  Widget _buildHistoryView() {
    final vitalsList = ref.watch(vitalsProvider);
    final latest = vitalsList.isNotEmpty ? vitalsList.first : null;

    final metrics = [
      {
        'label': 'HEIGHT',
        'value': latest?.formattedHeight ?? '92.5 cm',
        'icon': Icons.straighten,
        'idx': '01 / 05'
      },
      {
        'label': 'WEIGHT',
        'value': latest?.formattedWeight ?? '14.2 kg',
        'icon': Icons.scale,
        'idx': '02 / 05'
      },
      {
        'label': 'AGE',
        'value': latest?.formattedAge ?? '2y 3m',
        'icon': Icons.calendar_today,
        'idx': '03 / 05'
      },
      {
        'label': 'GENDER',
        'value': latest?.gender ?? 'Boy',
        'icon': Icons.person_outline,
        'idx': '04 / 05'
      },
      {
        'label': 'BMI',
        'value': latest?.formattedBmi ?? '16.6',
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
          child: Text('Health status : ${latest?.status ?? "Healthy"}',
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF065F46))),
        ),
        const SizedBox(height: 10),
        Text('A clear record of growth, scans, and clinical notes.',
            style: TextStyle(fontSize: 13, color: _secondaryText)),
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
                right: '${vitalsList.length.toString().padLeft(2, '0')} entries')),
        const SizedBox(height: 8),
        if (vitalsList.isEmpty)
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
                          style: TextStyle(fontSize: 11.5, color: _secondaryText)),
                    ],
                  ),
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
                        padding:
                            const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(record.gender,
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
                ],
              ),
            );
          }).toList(),
        const SizedBox(height: 18),

        // DOCTOR'S PRESCRIPTION
        Align(
            alignment: Alignment.centerLeft,
            child:
                _buildSectionHeader("DOCTOR'S PRESCRIPTION", right: '03 / 03')),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Continue the current care plan',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: _primaryText)),
              const SizedBox(height: 6),
              Text(
                  'Keep regular meals, hydration, and outdoor play consistent. Bring this record to the next pediatric review.',
                  style: TextStyle(
                      fontSize: 13, color: _secondaryText, height: 1.4)),
              const SizedBox(height: 10),
              Text('📄 REVIEW AT NEXT VISIT',
                  style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                      color: _secondaryText)),
            ],
          ),
        ),
        const SizedBox(height: 20),

        ElevatedButton(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('PDF Report exported successfully')),
            );
          },
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
    final ageCtrl = TextEditingController(text: '2');
    final genderCtrl = TextEditingController(text: _gender.toLowerCase());
    final statusCtrl = TextEditingController(text: _status);

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
              TextField(
                  controller: ageCtrl,
                  decoration: const InputDecoration(labelText: 'Age')),
              TextField(
                  controller: genderCtrl,
                  decoration: const InputDecoration(labelText: 'Gender')),
              TextField(
                  controller: statusCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Growth status')),
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
                _age = '${ageCtrl.text} years, 3 months';
                _gender = genderCtrl.text;
                _status = statusCtrl.text;
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

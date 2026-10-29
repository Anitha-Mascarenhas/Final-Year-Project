import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../widgets/topo_header.dart';
import 'main_scaffold.dart';
import 'ai_scan_screen.dart';
import 'profile_screen.dart';
import 'role_selection_screen.dart';
import '../utils/pdf_exporter.dart';

class HealthcareChildRecord {
  final String id;
  final String name;
  final int ageMonths;
  final String gender;
  final String guardianName;
  final String lastScreened;
  final String riskStatus;
  final String riskLevel; // 'low', 'medium', 'high'
  final String muac;
  final String weight;
  final String height;
  final String zScore;

  const HealthcareChildRecord({
    required this.id,
    required this.name,
    required this.ageMonths,
    required this.gender,
    required this.guardianName,
    required this.lastScreened,
    required this.riskStatus,
    required this.riskLevel,
    required this.muac,
    required this.weight,
    required this.height,
    required this.zScore,
  });

  String get dropdownLabel => '$id - $name';
}

class HealthcareDashboardScreen extends StatefulWidget {
  const HealthcareDashboardScreen({super.key});

  @override
  State<HealthcareDashboardScreen> createState() =>
      _HealthcareDashboardScreenState();
}

class _HealthcareDashboardScreenState extends State<HealthcareDashboardScreen> {
  static const List<HealthcareChildRecord> _children = [
    HealthcareChildRecord(
      id: 'CHILD001',
      name: 'Aarav',
      ageMonths: 24,
      gender: 'Male',
      guardianName: 'Sunita Sharma',
      lastScreened: '24 Sep 2026',
      riskStatus: 'Normal / Adequate',
      riskLevel: 'low',
      muac: '14.2 cm',
      weight: '12.4 kg',
      height: '88.5 cm',
      zScore: '-0.4',
    ),
    HealthcareChildRecord(
      id: 'CHILD002',
      name: 'Aadhya',
      ageMonths: 18,
      gender: 'Female',
      guardianName: 'Rajesh Patel',
      lastScreened: '15 Aug 2026',
      riskStatus: 'Moderate SAM / Monitor',
      riskLevel: 'high',
      muac: '11.8 cm',
      weight: '9.2 kg',
      height: '78.0 cm',
      zScore: '-2.1',
    ),
    HealthcareChildRecord(
      id: 'CHILD003',
      name: 'Ananya',
      ageMonths: 30,
      gender: 'Female',
      guardianName: 'Meera Reddy',
      lastScreened: '10 Jul 2026',
      riskStatus: 'Mild Stunting',
      riskLevel: 'medium',
      muac: '13.1 cm',
      weight: '11.5 kg',
      height: '85.2 cm',
      zScore: '-1.2',
    ),
    HealthcareChildRecord(
      id: 'CHILD004',
      name: 'Vihaan',
      ageMonths: 12,
      gender: 'Male',
      guardianName: 'Amit Verma',
      lastScreened: '01 Sep 2026',
      riskStatus: 'Normal / Adequate',
      riskLevel: 'low',
      muac: '14.5 cm',
      weight: '9.8 kg',
      height: '75.0 cm',
      zScore: '+0.1',
    ),
  ];

  late HealthcareChildRecord _selectedChild;

  @override
  void initState() {
    super.initState();
    _selectedChild = _children.first;
  }

  Color _getRiskColor(String level) {
    switch (level) {
      case 'high':
        return const Color(0xFFE53935);
      case 'medium':
        return const Color(0xFFFB8C00);
      case 'low':
      default:
        return AppColors.primaryForest;
    }
  }

  Color _getRiskBgColor(String level) {
    switch (level) {
      case 'high':
        return const Color(0xFFFFEBEE);
      case 'medium':
        return const Color(0xFFFFF3E0);
      case 'low':
      default:
        return const Color(0xFFEAF1E9);
    }
  }

  void _navigateToChildHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileScreen(
          childName: _selectedChild.name,
          childId: _selectedChild.id,
          initialHistoryView: true,
        ),
      ),
    );
  }

  void _navigateToAiScan() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AiScanScreen(
          childName: _selectedChild.name,
          childId: _selectedChild.id,
        ),
      ),
    );
  }

  void _logout() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final riskColor = _getRiskColor(_selectedChild.riskLevel);
    final riskBg = _getRiskBgColor(_selectedChild.riskLevel);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Action Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.cardSurface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.primaryForest.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(
                          Icons.badge_rounded,
                          size: 16,
                          color: AppColors.primaryForest,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'HW001 | St. Jude Center',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _logout,
                    tooltip: 'Sign Out',
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.logout_rounded,
                        size: 20,
                        color: Colors.redAccent,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Header Widget
              const TopoHeader(
                title: 'Clinical Dashboard',
                subtitle:
                    'Select a child record to review anthropometrics, WHO growth curves, and screening history.',
              ),
              const SizedBox(height: 24),

              // Doctor info card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.cardSurface,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor:
                          AppColors.primaryForest.withValues(alpha: 0.15),
                      child: const Icon(
                        Icons.medical_services_rounded,
                        color: AppColors.primaryForest,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Dr. Priya Nair',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Senior Pediatric Nutritionist',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSubtle,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primaryForest.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        '4 Records',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryForest,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Dropdown Selection Header
              const Text(
                'SELECT PATIENT RECORD',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                  color: AppColors.textSubtle,
                ),
              ),
              const SizedBox(height: 10),

              // Dropdown Input Card
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppColors.primaryForest.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryForest.withValues(alpha: 0.05),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<HealthcareChildRecord>(
                    value: _selectedChild,
                    isExpanded: true,
                    icon: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppColors.primaryForest,
                      size: 28,
                    ),
                    dropdownColor: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    items: _children.map((child) {
                      return DropdownMenuItem<HealthcareChildRecord>(
                        value: child,
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primaryForest
                                    .withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.person_rounded,
                                size: 18,
                                color: AppColors.primaryForest,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              child.dropdownLabel,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textDark,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (record) {
                      if (record != null) {
                        setState(() => _selectedChild = record);
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Selected Patient Overview Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Child Title Header
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor:
                              AppColors.primaryForest.withValues(alpha: 0.1),
                          child: Text(
                            _selectedChild.name[0],
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primaryForest,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_selectedChild.id} - ${_selectedChild.name}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textDark,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${_selectedChild.gender} • ${_selectedChild.ageMonths} months • Guardian: ${_selectedChild.guardianName}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSubtle,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 16),

                    // Malnutrition Status Badge
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Expanded(
                          child: Text(
                            'Current Malnutrition Status',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSubtle,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: riskBg,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: riskColor.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              _selectedChild.riskStatus,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: riskColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Vitals Grid
                    Row(
                      children: [
                        Expanded(
                          child: _buildVitalTile(
                            label: 'Weight',
                            value: _selectedChild.weight,
                            icon: Icons.monitor_weight_outlined,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildVitalTile(
                            label: 'Height',
                            value: _selectedChild.height,
                            icon: Icons.height_rounded,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _buildVitalTile(
                            label: 'MUAC',
                            value: _selectedChild.muac,
                            icon: Icons.straighten_rounded,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildVitalTile(
                            label: 'WHO Z-Score',
                            value: _selectedChild.zScore,
                            icon: Icons.analytics_outlined,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Icon(
                          Icons.history_toggle_off_rounded,
                          size: 16,
                          color: AppColors.textSubtle,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Last Clinical Assessment: ${_selectedChild.lastScreened}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSubtle,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Divider(height: 1),
                    const SizedBox(height: 14),
                    InkWell(
                      onTap: () {
                        PdfReportHelper.generateAndExportReport(
                          childId: _selectedChild.id,
                          childName: _selectedChild.name,
                          age: '${_selectedChild.ageMonths} months',
                          gender: _selectedChild.gender,
                          guardianName: _selectedChild.guardianName,
                          status: _selectedChild.riskStatus,
                          height: _selectedChild.height,
                          weight: _selectedChild.weight,
                          muac: _selectedChild.muac,
                          bmiOrZScore: _selectedChild.zScore,
                          lastScreened: _selectedChild.lastScreened,
                        );
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.primaryForest
                              .withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppColors.primaryForest
                                .withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(
                              Icons.picture_as_pdf_rounded,
                              size: 18,
                              color: AppColors.primaryForest,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Export PDF Clinical Report',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryForest,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Action Buttons
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _navigateToChildHistory,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryForest,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'View Child History (${_selectedChild.name})',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Icon(Icons.arrow_forward_rounded, size: 20),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: _navigateToAiScan,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryForest,
                    side: const BorderSide(
                      color: AppColors.primaryForest,
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.camera_alt_outlined, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Perform AI Scan for ${_selectedChild.name}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVitalTile({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primaryForest),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSubtle,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

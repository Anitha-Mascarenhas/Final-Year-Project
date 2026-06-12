import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeroCard(),
        const SizedBox(height: 32),
        _buildNearbyHospitals(),
        const SizedBox(height: 32),
        _buildNutritionAwareness(),
        const SizedBox(height: 32),
        _buildRecentActivity(),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildHeroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primary, AppTheme.primaryContainer],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Good morning, Parent',
            style: GoogleFonts.montserrat(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppTheme.secondaryFixed,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'AI SYSTEM READY',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Daily Nutrition Goal',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '75%',
                      style: GoogleFonts.montserrat(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: 0.75,
                    minHeight: 8,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.secondaryFixed),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '1 SCAN REMAINING FOR TODAY\'S CHECK',
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    color: Colors.white.withOpacity(0.6),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNearbyHospitals() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Nearby Hospitals',
                style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.onSurface)),
            TextButton(
              onPressed: () {},
              child: Text('View Map',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.primary)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _HospitalCard(
          name: 'City Pediatrics Clinic',
          distance: '0.8 miles away • Open 24/7',
          onTap: () {},
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.warning_amber_rounded),
            label: Text('Emergency Contact',
                style: GoogleFonts.montserrat(fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorContainer,
              foregroundColor: AppTheme.onErrorContainer,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNutritionAwareness() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Nutrition Awareness',
            style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.onSurface)),
        const SizedBox(height: 12),
        SizedBox(
          height: 240,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _AwarenessCard(
                tag: 'Vitamins',
                title: 'The power of Green leafy vegetables',
                description: 'Iron and Folate are essential for cognitive growth in early childhood...',
                imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuDg77ah5RUy6Nz6ZrBem0RlRGtrctOWQNVni-tD6sGmZn2h7pgpvcLkRVyBKkvrdnVwr4bHdzz85eADwIJV6XPpBn8OEWOquDodJx_Uwm6UYQ_HIigkwWP2cyknWAgy90Whhe51rveqN3s6QtkSbGx8dbeF2TpxXzWdy75fFvyhBHAKjgvaEBMuNizpOd9OKQfofkcgUuRklw0MjfLoN67pS8vxwKW2Zt7kOJMQCK-xk2ie2K3bKXBdRNXUTjpG7kPbigF94HeZHjQX',
                tagColor: AppTheme.secondaryContainer,
                tagTextColor: AppTheme.onSecondaryContainer,
              ),
              const SizedBox(width: 16),
              _AwarenessCard(
                tag: 'Calcium',
                title: 'Stronger bones with dairy alternatives',
                description: 'Discover how calcium-rich seeds can boost your child\'s height...',
                imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuBmpiGkjsy8LNn-smF6Sa7rZMxCp76NdFgX9F-7rrwTQMB0xYFg4vkyeTzyfSE9TbF9dS7clQ7j0yYVdTXTROkSjQ5GmyPQVSJf8GQ0tdHQQvr5HXYzz7XkAsRnBqvlRkthqFId6LuytE6RjTtpZNawAV02TLNaPvf9iq3kvx5MgqGQLulinOf06OoQldrHgcJFNjsB9typOtjtTNDdMyI7mhIEBu-EkMwagUr3tevgQMheCPckEg3jfXwg-7TLaPuW6ME060KZBL1h',
                tagColor: AppTheme.primaryFixed,
                tagTextColor: AppTheme.primary,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRecentActivity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Recent Activity',
            style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.onSurface)),
        const SizedBox(height: 12),
        _ActivityItem(
          icon: Icons.camera_alt,
          title: 'Meal Scan: Breakfast',
          subtitle: 'High in Protein • 8:45 AM Today',
          trailing: Text('+12 pts',
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.secondary)),
          iconBgColor: AppTheme.tertiaryFixed,
          iconColor: AppTheme.onTertiaryContainer,
        ),
        const SizedBox(height: 10),
        _ActivityItem(
          icon: Icons.description_outlined,
          title: 'Weekly Report Generated',
          subtitle: 'Improving trend in Vitamin A • Yesterday',
          trailing: Icon(Icons.download, size: 18, color: Colors.grey[400]),
          iconBgColor: AppTheme.primaryFixed,
          iconColor: AppTheme.primary,
        ),
      ],
    );
  }
}

class _HospitalCard extends StatelessWidget {
  final String name;
  final String distance;
  final VoidCallback onTap;

  const _HospitalCard({required this.name, required this.distance, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.primaryFixed,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.local_hospital_outlined, color: AppTheme.primary, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.onSurface)),
                  const SizedBox(height: 2),
                  Text(distance,
                      style: GoogleFonts.inter(fontSize: 12, color: AppTheme.onSurfaceVariant)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.outlineVariant, size: 20),
          ],
        ),
      ),
    );
  }
}

class _AwarenessCard extends StatelessWidget {
  final String tag;
  final String title;
  final String description;
  final String imageUrl;
  final Color tagColor;
  final Color tagTextColor;

  const _AwarenessCard({
    required this.tag,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.tagColor,
    required this.tagTextColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Image.network(
              imageUrl,
              height: 120,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                height: 120,
                color: AppTheme.surfaceContainerHigh,
                child: const Icon(Icons.image, size: 40, color: AppTheme.outlineVariant),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: tagColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(tag.toUpperCase(),
                      style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: tagTextColor, letterSpacing: 1)),
                ),
                const SizedBox(height: 6),
                Text(title,
                    style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.onSurface),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(description,
                    style: GoogleFonts.inter(fontSize: 11, color: AppTheme.onSurfaceVariant),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;
  final Color iconBgColor;
  final Color iconColor;

  const _ActivityItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.iconBgColor,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: iconBgColor, shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.onSurface)),
                Text(subtitle,
                    style: GoogleFonts.inter(fontSize: 11, color: AppTheme.onSurfaceVariant)),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

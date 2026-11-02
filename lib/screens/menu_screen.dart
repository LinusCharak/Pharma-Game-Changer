import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/menu_data.dart';
import '../data/product_catalog.dart';
import '../models/menu_item.dart';
import '../models/product.dart';
import '../models/user_profile.dart';
import '../theme/app_theme.dart';
import '../widgets/decorative_title.dart';
import '../widgets/menu_tile.dart';
import '../widgets/product_grid.dart';
import 'login_screen.dart';


class MenuScreen extends StatelessWidget {
  final UserProfile profile;

  const MenuScreen({
    super.key,
    required this.profile,
  });

  @override
  Widget build(BuildContext context) {
    final features = buildMenuFeatures();
    final tabCount = 1 + productCatalog.length;

    return DefaultTabController(
      length: tabCount,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              _WelcomeHeader(name: profile.fullName),

              Container(
                color: AppColors.primary,
                child: TabBar(
                  isScrollable: true,
                  labelColor: const Color(0xFFEC407A),
                  unselectedLabelColor: Colors.white,
                  indicatorColor: Colors.white,
                  indicatorWeight: 2,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  tabs: [
                    const Tab(text: 'UTILITIES'),
                    ...productCatalog.map(
                      (c) => Tab(
                        text: c.tabLabel.toUpperCase(),
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: TabBarView(
                  children: [
                    _UtilitiesTab(features: features),

                    ...productCatalog.map(
                      (c) => _CategoryTab(category: c),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WelcomeHeader extends StatelessWidget {
  final String name;

  const _WelcomeHeader({
    required this.name,
  });

  void _logout(BuildContext context) {
    // Logout does NOT clear the daily Supabase-authenticated session
    // (cached_user_profile / last_successful_supabase_login_date).
    // Supabase authentication is required once per calendar day; if the
    // user logs out and back in on that same day, re-entry must still
    // use that day's already-completed authentication, with no new
    // Supabase call. Only a new calendar day (or a corrupted/missing
    // cache) requires a fresh login -- see LoginScreen._initialize().
    //
    // requireManualLogin: true means LoginScreen must NOT auto-navigate
    // back into Menu just because today's session is still valid -- the
    // user has to explicitly press Sign In first. That explicit Sign In
    // still won't call Supabase if today's login already happened.
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.primary,
      padding: const EdgeInsets.symmetric(
        vertical: 14,
        horizontal: 16,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Column(
            children: [
              const Text(
                'Welcome',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '"$name"',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          Positioned(
            right: 0,
            child: IconButton(
              icon: const Icon(
                Icons.logout,
                color: Colors.white,
              ),
              tooltip: 'Logout',
              onPressed: () => _logout(context),
            ),
          ),
        ],
      ),
    );
  }
}


// ============================================================
// UTILITIES TAB
// ============================================================

class _UtilitiesTab extends StatefulWidget {
  final List<MenuFeature> features;

  const _UtilitiesTab({
    required this.features,
  });

  @override
  State<_UtilitiesTab> createState() => _UtilitiesTabState();
}

class _UtilitiesTabState extends State<_UtilitiesTab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _slideAnimation;

  bool _showHint = false;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _slideAnimation = Tween<double>(
      begin: 0,
      end: -90,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    _checkAndShowDailyHint();
  }

  Future<void> _checkAndShowDailyHint() async {
    final prefs = await SharedPreferences.getInstance();

    final today = _todayKey();
    final lastShownDate = prefs.getString('menu_swipe_hint_date');

    // Already shown today.
    if (lastShownDate == today) {
      return;
    }

    // Mark it immediately so rebuilding the screen today
    // does not trigger the animation again.
    await prefs.setString(
      'menu_swipe_hint_date',
      today,
    );

    if (!mounted) return;

    // Let the menu render completely before starting.
    await Future<void>.delayed(
      const Duration(milliseconds: 700),
    );

    if (!mounted) return;

    setState(() {
      _showHint = true;
    });

    // Small delay before the first movement.
    await Future<void>.delayed(
      const Duration(milliseconds: 250),
    );

    if (!mounted) return;

    // First nudge: left -> back.
    await _animationController.forward();

    if (!mounted) return;

    await _animationController.reverse();

    if (!mounted) return;

    // Short pause between the two nudges.
    await Future<void>.delayed(
      const Duration(milliseconds: 180),
    );

    if (!mounted) return;

    // Second nudge: left -> back.
    await _animationController.forward();

    if (!mounted) return;

    await _animationController.reverse();

    if (!mounted) return;

    setState(() {
      _showHint = false;
    });
  }

  String _todayKey() {
    final now = DateTime.now();

    return '${now.year}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 20),

          const DecorativeTitle('Utilities'),

          const SizedBox(height: 16),

          LayoutBuilder(
            builder: (context, constraints) {
              final columns =
                  Breakpoints.gridColumns(constraints.maxWidth);

              return AnimatedBuilder(
                animation: _slideAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(
                      _slideAnimation.value,
                      0,
                    ),
                    child: child,
                  );
                },
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                  ),
                  itemCount: widget.features.length,
                  gridDelegate:
                      SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.0,
                  ),
                  itemBuilder: (context, index) {
                    final feature = widget.features[index];

                    return MenuTile(
                      label: feature.label,
                      icon: feature.icon,
                      color: feature.color,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: feature.screenBuilder,
                          ),
                        );
                      },
                    );
                  },
                ),
              );
            },
          ),

          // Small visual cue only while the animation is running.
          if (_showHint) ...[
            const SizedBox(height: 8),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.swipe,
                  size: 20,
                  color: Colors.grey,
                ),
                SizedBox(width: 6),
                Text(
                  'Swipe to explore more',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}


// ============================================================
// PRODUCT CATEGORY TAB
// ============================================================

class _CategoryTab extends StatelessWidget {
  final ProductCategory category;

  const _CategoryTab({
    required this.category,
  });

  @override
  Widget build(BuildContext context) {
    final isSingles = category.tabLabel == 'Singles';

    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 20),

          DecorativeTitle(
            isSingles
                ? category.title.toUpperCase()
                : category.title,
            color: isSingles
                ? const Color(0xFF43A047)
                : const Color(0xFFE53935),
          ),

          const SizedBox(height: 16),

          ProductGrid(
            products: category.products,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            spacing: isSingles ? 12 : 3,
            fixedColumns: isSingles ? 2 : null,
          ),
        ],
      ),
    );
  }
}

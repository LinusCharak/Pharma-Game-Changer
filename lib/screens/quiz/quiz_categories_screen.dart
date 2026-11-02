import 'package:flutter/material.dart';
import '../../models/quiz_category.dart';
import '../../services/quiz_service.dart';
import '../../theme/app_theme.dart';
import 'quiz_screen.dart';

/// Lists the quiz topics from `quiz_catergories` (originally the Airtable
/// "Categories" table, read in Quiz_Loading). Tapping a topic starts the
/// quiz for that product.
class QuizCategoriesScreen extends StatefulWidget {
  const QuizCategoriesScreen({super.key});

  @override
  State<QuizCategoriesScreen> createState() => _QuizCategoriesScreenState();
}

class _QuizCategoriesScreenState extends State<QuizCategoriesScreen> {
  late Future<List<QuizCategory>> _future;

  @override
  void initState() {
    super.initState();
    _future = QuizService.instance.fetchCategories();
  }

  Future<void> _refresh() async {
    final next = QuizService.instance.fetchCategories();
    setState(() => _future = next);
    await next;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Start Quiz')),
      body: FutureBuilder<List<QuizCategory>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _MessageState(
              icon: Icons.wifi_off,
              message: "Couldn't load quiz topics.\n${snapshot.error}",
              onRetry: _refresh,
            );
          }
          final categories = snapshot.data ?? const [];
          if (categories.isEmpty) {
            return _MessageState(
              icon: Icons.quiz_outlined,
              message: 'No quiz topics found yet.',
              onRetry: _refresh,
            );
          }
          final width = MediaQuery.of(context).size.width;
          final columns = Breakpoints.gridColumns(width).clamp(2, 4).toInt();
          return RefreshIndicator(
            onRefresh: _refresh,
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.82,
              ),
              itemCount: categories.length,
              itemBuilder: (context, i) {
                final category = categories[i];
                return _CategoryCard(
                  category: category,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => QuizScreen(category: category),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final QuizCategory category;
  final VoidCallback onTap;
  const _CategoryCard({required this.category, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: [
            Expanded(
              child: category.imageAsset != null
                  ? Padding(
                      padding: const EdgeInsets.all(12),
                      child: Image.asset(category.imageAsset!, fit: BoxFit.contain),
                    )
                  : Container(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      child: const Icon(Icons.quiz, size: 40, color: AppColors.primary),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Text(
                category.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  final IconData icon;
  final String message;
  final VoidCallback onRetry;
  const _MessageState({required this.icon, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppColors.accent),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

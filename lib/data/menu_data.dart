import 'package:flutter/material.dart';
import '../models/menu_item.dart';
import '../screens/quiz/quiz_categories_screen.dart';
import '../screens/visual_aid_screen.dart';
import '../screens/detailing_story_screen.dart';
import '../screens/reminder_sharing_screen.dart';
import '../screens/demo_detailing_screen.dart';
import '../screens/clinical_trials/clinical_trials_screen.dart';
import '../screens/calculator_screen.dart';
import '../screens/promotogram_screen.dart';
import '../screens/price_list_screen.dart';

/// The Utilities tab tiles, reconstructed from Menu.scm's first tab
/// (Btn_VisualAid ... Btn_MRP), in their original order. Labels match the
/// updated Utilities design. Each currently opens a placeholder screen --
/// swap `screenBuilder` for the real screen as each one is built.
List<MenuFeature> buildMenuFeatures() {
  return [
    MenuFeature(
      id: 'visual_aid',
      label: 'Visual Aid',
      icon: Icons.event_note,
      color: const Color(0xFFF9A825),
      screenBuilder: (_) => const VisualAidScreen(),
    ),
    MenuFeature(
      id: 'start_quiz',
      label: 'Start Quiz',
      icon: Icons.fact_check,
      color: const Color(0xFF43A047),
      screenBuilder: (_) => const QuizCategoriesScreen(),
    ),
    MenuFeature(
      id: 'reminder_sharing',
      label: 'Reminder Sharing',
      icon: Icons.ios_share,
      color: const Color(0xFF7B1FA2),
      screenBuilder: (profile) => ReminderSharingScreen(
	  headerTitle: 'Reminder Sharing',
	   userName: '',
	   ),
    ),
    MenuFeature(
      id: 'detailing_story',
      label: 'Detailing Story',
      icon: Icons.menu_book,
      color: const Color(0xFFD81B60),
      screenBuilder: (_) => const DetailingStoryScreen(),
    ),
    MenuFeature(
      id: 'demo_detailing',
      label: 'Demo Detailing',
      icon: Icons.movie,
      color: const Color(0xFFE53935),
      screenBuilder: (_) => const DemoDetailingScreen(),
    ),
    MenuFeature(
      id: 'clinical_trial',
      label: 'Clinical Trial',
      icon: Icons.groups,
      color: const Color(0xFF00897B),
      screenBuilder: (_) => const ClinicalTrialsScreen(),
    ),
    MenuFeature(
      id: 'calculator',
      label: 'Order / POB\nCalculator',
      icon: Icons.calculate,
      color: const Color(0xFF1E88E5),
      screenBuilder: (_) => const CalculatorScreen(),
    ),
    MenuFeature(
      id: 'promotogram',
      label: 'Promotogram',
      icon: Icons.campaign,
      color: const Color(0xFFF4511E),
      screenBuilder: (_) => const PromotogramScreen(),
    ),
    MenuFeature(
      id: 'price_list',
      label: 'Price List',
      icon: Icons.price_check,
      color: const Color(0xFF43A047),
      screenBuilder: (_) => const PriceListScreen(),
    ),
  ];
}

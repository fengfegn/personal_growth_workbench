import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/calendar/presentation/calendar_page.dart';
import '../../features/courses/presentation/courses_page.dart';
import '../../features/cultivation/presentation/cultivation_page.dart';
import '../../features/cultivation/presentation/realm_detail_page.dart';
import '../../features/cultivation/presentation/technique_detail_page.dart';
import '../../features/dashboard/presentation/dashboard_page.dart';
import '../../features/goals/presentation/goal_page.dart';
import '../../features/hotspots/presentation/hotspot_page.dart';
import '../../features/habits/presentation/habit_page.dart';
import '../../features/quick_notes/presentation/quick_notes_page.dart';
import '../../features/settings/presentation/settings_page.dart';
import '../../features/tasks/presentation/task_page.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      ShellRoute(
        builder: (context, state, child) {
          return AppShell(location: state.uri.path, child: child);
        },
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const DashboardHomePage(),
          ),
          GoRoute(
            path: '/tasks',
            builder: (context, state) => const TaskPage(),
          ),
          GoRoute(
            path: '/goals',
            builder: (context, state) => const GoalPage(),
          ),
          GoRoute(
            path: '/cultivation',
            builder: (context, state) => const CultivationPage(),
            routes: [
              GoRoute(
                path: 'technique/:id',
                builder: (context, state) => TechniqueDetailPage(
                  techniqueId: state.pathParameters['id']!,
                ),
              ),
              GoRoute(
                path: 'realm',
                builder: (context, state) => const RealmDetailPage(),
              ),
            ],
          ),
          GoRoute(
            path: '/habits',
            builder: (context, state) => const HabitPage(),
          ),
          GoRoute(
            path: '/courses',
            builder: (context, state) => const CoursesPage(),
          ),
          GoRoute(
            path: '/calendar',
            builder: (context, state) => const FeaturePlaceholderPage(
              title: '日历',
              icon: Icons.calendar_month_outlined,
              page: CalendarPage(),
              description: '日历视图将在核心行动闭环中接入。',
            ),
          ),
          GoRoute(
            path: '/quick-notes',
            builder: (context, state) => const QuickNotesPage(),
          ),
          GoRoute(
            path: '/hotspots',
            builder: (context, state) => const HotspotPage(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsPage(),
          ),
        ],
      ),
    ],
  );
});

class AppShell extends StatefulWidget {
  const AppShell({required this.location, required this.child, super.key});

  final String location;
  final Widget child;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  bool _railExpanded = true;

  static const desktopItems = [
    _NavigationItem('/', '首页', Icons.home_outlined),
    _NavigationItem('/tasks', '今日任务', Icons.check_circle_outline),
    _NavigationItem('/goals', '目标', Icons.flag_outlined),
    _NavigationItem('/courses', '课程安排', Icons.menu_book_outlined),
    _NavigationItem('/calendar', '日历', Icons.calendar_month_outlined),
    _NavigationItem('/cultivation', '图灵修炼', Icons.auto_awesome_outlined),
    _NavigationItem('/habits', '习惯养成', Icons.repeat_outlined),
    _NavigationItem('/hotspots', '今日热点', Icons.newspaper_outlined),
    _NavigationItem('/quick-notes', '随心记', Icons.edit_note_outlined),
    _NavigationItem('/settings', '设置', Icons.settings_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) =>
          _buildDesktop(context, compact: constraints.maxWidth < 1100),
    );
  }

  Widget _buildDesktop(BuildContext context, {required bool compact}) {
    final expanded = !compact && _railExpanded;
    return Scaffold(
      body: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: expanded ? 232 : 80,
            child: SafeArea(
              child: Column(
                children: [
                  Align(
                    alignment: expanded
                        ? Alignment.centerRight
                        : Alignment.center,
                    child: IconButton(
                      tooltip: expanded ? '收起导航' : '展开导航',
                      onPressed: compact
                          ? null
                          : () =>
                                setState(() => _railExpanded = !_railExpanded),
                      icon: Icon(expanded ? Icons.menu_open : Icons.menu),
                    ),
                  ),
                  Expanded(
                    child: NavigationRail(
                      extended: expanded,
                      selectedIndex: _selectedIndex(desktopItems),
                      onDestinationSelected: (index) =>
                          context.go(desktopItems[index].path),
                      destinations: [
                        for (final item in desktopItems)
                          NavigationRailDestination(
                            icon: Icon(item.icon),
                            selectedIcon: Icon(item.icon),
                            label: Text(item.label),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: widget.child),
        ],
      ),
    );
  }

  int _selectedIndex(List<_NavigationItem> items) {
    final exactIndex = items.indexWhere((item) => item.path == widget.location);
    if (exactIndex != -1) return exactIndex;
    final parentIndex = items.indexWhere(
      (item) => item.path != '/' && widget.location.startsWith('${item.path}/'),
    );
    return parentIndex == -1 ? 0 : parentIndex;
  }
}

class _NavigationItem {
  const _NavigationItem(this.path, this.label, this.icon);

  final String path;
  final String label;
  final IconData icon;
}

class FeaturePlaceholderPage extends StatelessWidget {
  const FeaturePlaceholderPage({
    required this.title,
    required this.icon,
    required this.description,
    this.page,
    super.key,
  });

  final String title;
  final IconData icon;
  final String description;
  final Widget? page;

  @override
  Widget build(BuildContext context) {
    if (page != null) {
      return page ?? const CalendarPage();
    }
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 48,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(description, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

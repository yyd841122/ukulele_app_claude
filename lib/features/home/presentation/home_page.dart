// Home page — T007 implementation.
//
// Shows today's practice (Day N, theme, task list) and quick nav to
// existing feature pages. Tapping a task navigates to the existing
// placeholder page; toggling the checkbox records completion in memory.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ukulele_app/features/home/application/today_practice_controller.dart';
import 'package:ukulele_app/features/home/presentation/widgets/home_quick_actions.dart';
import 'package:ukulele_app/features/home/presentation/widgets/today_practice_header.dart';
import 'package:ukulele_app/features/home/presentation/widgets/today_practice_task_card.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TodayPracticeState state = ref.watch(todayPracticeControllerProvider);
    final TodayPracticeController controller =
        ref.read(todayPracticeControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ukulele App'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            TodayPracticeHeader(state: state),
            const SizedBox(height: 16),
            ...state.plan.tasks.map(
              (task) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TodayPracticeTaskCard(
                  task: task,
                  onTap: () => context.push(task.routePath),
                  onToggleCompleted: (_) =>
                      controller.toggleTaskCompleted(task.id),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const HomeQuickActions(),
          ],
        ),
      ),
    );
  }
}

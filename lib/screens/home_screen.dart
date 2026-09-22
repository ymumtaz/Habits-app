import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/habit_provider.dart';
import '../models/habit.dart';
import '../widgets/habit_card.dart';
import '../widgets/habit_summary_card.dart';
import '../widgets/log_amount_dialog.dart';
import '../widgets/undo_snackbar.dart';
import 'add_edit_habit_screen.dart';
import 'appearance_screen.dart';
import 'habit_detail_screen.dart';
import 'insights_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HabitProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Habits'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AppearanceScreen()),
            ),
          ),
        ],
      ),
      body: _buildBody(context, provider),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AddEditHabitScreen()),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody(BuildContext context, HabitProvider provider) {
    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.habits.isEmpty) {
      return _EmptyState(
        onAdd: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AddEditHabitScreen()),
        ),
      );
    }

    return Column(
      children: [
        HabitSummaryCard(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const InsightsScreen()),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: provider.load,
            child: ReorderableListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: provider.habits.length,
              onReorder: provider.reorderHabits,
              itemBuilder: (context, index) {
                final habit = provider.habits[index];
                final streak = provider.streakFor(habit);
                return HabitCard(
                  key: ValueKey(habit.id),
                  habit: habit,
                  streak: streak,
                  onToggleToday: () async {
                    if (habit.type == HabitType.boolean) {
                      provider.toggleToday(habit);
                      return;
                    }
                    final current = provider.amountOn(habit, DateTime.now());
                    final result = await showLogAmountDialog(
                      context,
                      habit: habit,
                      date: DateTime.now(),
                      currentAmount: current,
                    );
                    if (result == null) return;
                    if (result <= 0) {
                      if (current != null) {
                        final removedLog =
                            provider.logOn(habit, DateTime.now());
                        await provider.removeLogForDate(
                            habit, DateTime.now());
                        if (context.mounted && removedLog != null) {
                          showUndoSnackBar(
                            context,
                            message: 'Removed today\'s log',
                            onUndo: () =>
                                provider.restoreLog(habit, removedLog),
                          );
                        }
                      }
                    } else {
                      await provider.logAmountForDate(
                          habit, DateTime.now(), result);
                    }
                  },
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => HabitDetailScreen(habit: habit),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.local_fire_department_outlined,
                size: 64, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              'No habits yet',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Add your first habit — going to the gym, drinking enough '
              'water, cutting screen time — and start a streak.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Add a habit'),
            ),
          ],
        ),
      ),
    );
  }
}

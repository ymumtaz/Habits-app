import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/project_provider.dart';
import '../widgets/home_todo_section.dart';

/// The standalone to-do list, reached via an icon on the Habits page
/// rather than living inline there or behind its own bottom-nav tab —
/// both of those were tried first and felt like clutter on the main
/// habit list. A dedicated page keeps it a tap away without taking up
/// permanent space.
class TodosScreen extends StatelessWidget {
  const TodosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProjectProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('To-dos')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: HomeTodoSection(provider: provider),
      ),
    );
  }
}

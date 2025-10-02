import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/controllers/auth_controller.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).value;
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: Center(child: Text('Hello ${user?.name ?? user?.email ?? 'User'}')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
        label: const Text('Sign out'),
      ),
    );
  }
}

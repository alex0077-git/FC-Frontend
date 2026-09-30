import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomeButton extends StatelessWidget {
  const HomeButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Home',
      onPressed: () => context.go('/'),
      icon: const Icon(Icons.home_outlined),
    );
  }
}

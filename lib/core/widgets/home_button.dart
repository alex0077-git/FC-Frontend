import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomeButton extends StatelessWidget {
  const HomeButton({super.key});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurface;
    return Tooltip(
      message: 'Home',
      child: InkWell(
        onTap: () => context.go('/'),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.home_outlined, size: 22, color: color),
            const SizedBox(height: 2),
            Text(
              'Home',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, height: 1.1, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

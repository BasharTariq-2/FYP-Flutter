import 'package:flutter/material.dart';
import 'primary_button.dart';

class EmptyState extends StatelessWidget {
  final String message;
  final VoidCallback? onAction;
  final String? actionText;
  const EmptyState(this.message, {super.key, this.onAction, this.actionText});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(message, style: TextStyle(color: Colors.grey.shade600), textAlign: TextAlign.center),
          if (onAction != null && actionText != null) ...[
            const SizedBox(height: 16),
            PrimaryButton(text: actionText!, onPressed: onAction, isFullWidth: false),
          ],
        ],
      ),
    );
  }
}
import 'package:flutter/material.dart';

/// Placeholder widget used to indicate that data is being loaded.
class LoadingIndicator extends StatelessWidget {
  const LoadingIndicator({super.key, this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const CircularProgressIndicator(),
          if (label != null) ...<Widget>[
            const SizedBox(height: 16),
            Text(label!, style: const TextStyle(fontSize: 14)),
          ],
        ],
      ),
    );
  }
}

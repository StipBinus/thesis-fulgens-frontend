import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'input_provider.dart';

// Input sheet
Future<void> showInputSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black38,
    builder: (context) {
      return DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.35,
        maxChildSize: 0.95,
        expand: false,
        snap: true,
        snapSizes: const [0.35, 0.65, 0.95],
        builder: (context, scrollController) {
          return InputSheetContent(scrollController: scrollController);
        },
      );
    },
  );
}

// Input sheet content
class InputSheetContent extends ConsumerWidget {
  const InputSheetContent({super.key, required this.scrollController});

  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inputState = ref.watch(inputProvider);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE0E0E0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Input',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Form
          Expanded(
            child: SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Blank Input Page — overlay draggable',
                    style: TextStyle(color: Color(0xFF757575)),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Drag the handle above to expand or shrink. Drag down to close.',
                    style: TextStyle(color: Color(0xFF9E9E9E), fontSize: 12),
                  ),
                  const SizedBox(height: 24),

                  // Input field
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Sample field (stored in Riverpod)',
                      border: OutlineInputBorder(),
                      hintText: 'Type something...',
                    ),
                    onChanged: (v) => ref.read(inputProvider.notifier).updateText(v),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Riverpod state: "${inputState.text}"',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF616161)),
                  ),
                  const SizedBox(height: 24),

                  // Placeholder
                  Container(
                    height: 120,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9F7F3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE8E0D8)),
                    ),
                    child: const Center(
                      child: Text(
                        'Empty area — you will fill in fields here',
                        style: TextStyle(color: Color(0xFF9E9E9E)),
                      ),
                    ),
                  ),
                  // Spacer
                  const SizedBox(height: 400),
                  const Center(
                    child: Text(
                      'End of scroll -> the sheet drags along',
                      style: TextStyle(color: Color(0xFFBDBDBD), fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'input_provider.dart';

/// Shows the Input overlay as a draggable bottom sheet.
/// - Covers HomePage without navigating away (overlay).
/// - Draggable: peek (35%) -> half (65%) -> full (95%).
/// - Scroll + drag are linked via [scrollController] to avoid gesture fight.
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

/// Actual content of the sheet. Blank for now — fill in fields later.
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
          // Drag handle
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

          // Blank form — scrollable and linked to draggable sheet
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
                    'Tarik handle di atas untuk membesarkan/mengecilkan. Tarik ke bawah untuk menutup.',
                    style: TextStyle(color: Color(0xFF9E9E9E), fontSize: 12),
                  ),
                  const SizedBox(height: 24),

                  // Example field wired to Riverpod (replace with real fields later)
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Contoh field (tersimpan di Riverpod)',
                      border: OutlineInputBorder(),
                      hintText: 'Ketik sesuatu...',
                    ),
                    onChanged: (v) => ref.read(inputProvider.notifier).updateText(v),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Riverpod state: "${inputState.text}"',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF616161)),
                  ),
                  const SizedBox(height: 24),

                  // Placeholder for future fields
                  Container(
                    height: 120,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9F7F3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE8E0D8)),
                    ),
                    child: const Center(
                      child: Text(
                        'Area kosong — nanti kamu isi field di sini',
                        style: TextStyle(color: Color(0xFF9E9E9E)),
                      ),
                    ),
                  ),
                  // Extra space so sheet can fully expand and scroll
                  const SizedBox(height: 400),
                  const Center(
                    child: Text(
                      'Scroll mentok -> sheet akan ikut ketarik',
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

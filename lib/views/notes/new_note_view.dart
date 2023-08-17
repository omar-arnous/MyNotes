import 'package:flutter/material.dart';

class NeewNoteView extends StatefulWidget {
  const NeewNoteView({super.key});

  @override
  State<NeewNoteView> createState() => _NeewNoteViewState();
}

class _NeewNoteViewState extends State<NeewNoteView> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Note'),
      ),
      body: const Text('Write your new note here...'),
    );
  }
}

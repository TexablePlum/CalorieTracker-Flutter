import 'package:flutter/material.dart';

class FindPage extends StatefulWidget {
  const FindPage({super.key});

  @override
  State<FindPage> createState() => _FindScreenState();
}

class _FindScreenState extends State<FindPage> {
  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text("Find Screen")));
  }
}

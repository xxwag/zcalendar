import 'package:flutter/material.dart';

class WorkHours {
  final TimeOfDay start;
  final TimeOfDay end;

  WorkHours({required this.start, required this.end});
}

class CustomLoadingWidget extends StatefulWidget {
  final String message;
  final Function(bool) onConfirm;
  final String stepDescription;

  const CustomLoadingWidget({
    super.key,
    required this.message,
    required this.onConfirm,
    required this.stepDescription,
  });

  @override
  CustomLoadingWidgetState createState() => CustomLoadingWidgetState();
}

class CustomLoadingWidgetState extends State<CustomLoadingWidget> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> children = [
      const CircularProgressIndicator(),
      const SizedBox(height: 16.0),
      Text(
        widget.message,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18.0,
        ),
      ),
      const SizedBox(height: 16.0),
      Text(
        widget.stepDescription,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16.0,
        ),
      ),
    ];

    return Container(
      color: Colors.black.withOpacity(0.7),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: children,
        ),
      ),
    );
  }
}

class AdminDataWidget extends StatelessWidget {
  const AdminDataWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // Replace with your admin-specific data rendering logic
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: const Text(
        'Admin Data',
        style: TextStyle(fontSize: 18.0),
      ),
    );
  }
}

class UserDataWidget extends StatelessWidget {
  const UserDataWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // Replace with your user-specific data rendering logic
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: const Text(
        'User Data',
        style: TextStyle(fontSize: 18.0),
      ),
    );
  }
}

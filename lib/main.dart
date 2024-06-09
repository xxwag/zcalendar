import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:zcalendar/database_helper.dart';
import 'package:zcalendar/ngrok.dart';

import '/calendar_page.dart'; // Make sure to import the CalendarPage class correctly

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NgrokManager.fetchNgrokData();
  // Delete the database to start fresh

  await DatabaseHelper.instance.deleteDB();

  initializeDateFormatting().then((_) => runApp(MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ZC Calendar Application',
      theme: ThemeData(
        // Set the primary swatch to deep purple
        primarySwatch: Colors.deepPurple,
        // Use Material 3 design system
        useMaterial3: true,
        // Define the color scheme from a seed color
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      debugShowCheckedModeBanner: false, // Optionally remove the debug banner
      home: const CalendarPage(), // Directly navigate to CalendarPage
    );
  }
}

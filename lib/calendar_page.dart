import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:table_calendar/table_calendar.dart';
import 'package:http/http.dart' as http;
// For date formatting
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:zcalendar/cursor_painer.dart';
import 'package:zcalendar/database_helper.dart';
import 'package:zcalendar/ngrok.dart';
import 'package:zcalendar/widgets/countries_dialogue.dart';

import 'events.dart';

enum DataSource { online, offline }

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

class Step {
  final String description;
  final Function() action;

  Step({required this.description, required this.action});
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

class CalendarPage extends StatefulWidget {
  const CalendarPage({Key? key}) : super(key: key); // Modified constructor

  @override
  CalendarPageState createState() => CalendarPageState();
}

class CalendarPageState extends State<CalendarPage> with ChangeNotifier {
  Set<DateTime> printedDates = Set(); // To keep track of printed dates
  DateTime? _lastDraggedDay;
  DataSource _dataSource = DataSource.online; // Default to online
// This tracks whether selection mode is active
  bool _isGroupSelectionEnabled = false; // Track group selection mode
  GlobalKey<CalendarPageState> calendarPageKey = GlobalKey<CalendarPageState>();
  bool _imagesLoaded = false;
  bool _dataLoaded = false;
  List<String?> seasonBackgroundImages = [];
  DateTime? _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  GlobalKey _calendarKey = GlobalKey();
  static const double rowHeight = 85.0;
  static const int columns = 7; // Typically 7 days in a week
  static const int rows = 6; // Maximum number of weeks visible in a month view
  CalendarFormat _calendarFormat = CalendarFormat.month;
  bool groupByCountry = false; // This will track the toggle state
  static const int debounceMillis = 1000; // Debounce time for gestures
  Map<DateTime, List<Event>> events = {};
  Set<DateTime> holidays = {};

  String userAuthorizationLevel = ''; // Move userAuthorizationLevel here
  String? userToken; // Add userToken here
  List<String>? selectedCountries;
  Set<DateTime> selectedDays = Set(); // Tracks multiple selected days
  List<Map<String, dynamic>> unifiedStructuredData = [];
  DateTime? _lastToggledDay;

  List<int> workingDays = [
    DateTime.monday,
    DateTime.tuesday,
    DateTime.wednesday,
    DateTime.thursday,
    DateTime.friday
  ];
  Offset? _cursorPosition;
// Default size initialization
// Default position initialization
  double _calendarMaxHeight = 600; // Default maximum height
  // Sample working hours
  Map<int, WorkHours> workingHours = {
    DateTime.monday: WorkHours(
        start: const TimeOfDay(hour: 9, minute: 0),
        end:
            const TimeOfDay(hour: 17, minute: 0)), // Monday: 9:00 AM to 5:00 PM
    DateTime.tuesday: WorkHours(
        start: const TimeOfDay(hour: 9, minute: 0),
        end: const TimeOfDay(
            hour: 17, minute: 0)), // Tuesday: 9:00 AM to 5:00 PM
    DateTime.wednesday: WorkHours(
        start: const TimeOfDay(hour: 9, minute: 0),
        end: const TimeOfDay(hour: 17, minute: 0)), // ...
    DateTime.thursday: WorkHours(
        start: const TimeOfDay(hour: 9, minute: 0),
        end: const TimeOfDay(hour: 17, minute: 0)),
    DateTime.friday: WorkHours(
        start: const TimeOfDay(hour: 9, minute: 0),
        end:
            const TimeOfDay(hour: 15, minute: 0)), // Friday: 9:00 AM to 3:00 PM
    // Add other days as needed
  };
// Directly compute startYear and endYear based on the current time
  DateTime startDateTime = DateTime(DateTime.now().year - 30, 1, 1);
  DateTime endDateTime = DateTime(DateTime.now().year + 30, 12, 31, 23, 59, 59);

  Map<String, String> seasonImages = {
    'Winter': 'initial_image_url_for_winter',
    'Late Winter': 'initial_image_url_for_late_winter',
    'Early Spring': 'initial_image_url_for_early_spring',
    'Spring': 'initial_image_url_for_spring',
    'Early Summer': 'initial_image_url_for_early_summer',
    'Summer': 'initial_image_url_for_summer',
    'Early Autumn': 'initial_image_url_for_early_autumn',
    'Autumn': 'initial_image_url_for_autumn',
  };
  late ValueNotifier<Set<DateTime>> selectedDaysNotifier;

  @override
  void initState() {
    selectedDaysNotifier = ValueNotifier<Set<DateTime>>({});
    _loadData();
    _fetchUserAuthorizationLevel();
    _performMaintenanceCheck(context);
    // _loadEvents();

    _preloadSeasonImages();

    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(_afterLayout);
  }

  Future<String> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('username') ?? 'admin';
  }

  List<Event> getEventsForMonth(DateTime month) {
    List<Event> monthEvents = events.entries
        .where((entry) =>
            entry.key.month == month.month && entry.key.year == month.year)
        .map((entry) => entry.value)
        .expand((eventList) => eventList)
        .toList();

    List<Event> filteredEvents = [];
    Set<String> holidayTitles = Set<
        String>(); // To track holidays and private events that have already been added

    for (Event event in monthEvents) {
      if (event.isPrivate) {
        // Check if this private event title has already been added to prevent duplicates
        if (!holidayTitles.contains(event.title)) {
          holidayTitles.add(event.title);

          // Combine all unique flag URLs for this private event
          String combinedFlagUrls = monthEvents
              .where((e) => e.title == event.title && e.isPrivate)
              .map((e) => e.flagUrl)
              .where((url) => url != null && url.isNotEmpty)
              .toSet()
              .join(", ");

          // Use copyWith to create a new event instance with the updated flagUrl
          Event updatedEvent = event.copyWith(flagUrl: combinedFlagUrls);
          filteredEvents.add(updatedEvent);
        }
      } else {
        filteredEvents.add(event); // Add non-private events normally
      }
    }

    return filteredEvents;
  }

  String getUserCredentials(String username) {
    // Extract two main letters from the username
    // For example, you might want to use the first and last letters
    if (username.length >= 2) {
      return username.substring(0, 1) + username.substring(username.length - 1);
    } else if (username.isNotEmpty) {
      return username.substring(0, 1);
    } else {
      return '';
    }
  }

  List<Widget> _buildTimelineForDay(DateTime day) {
    final List<Widget> timelineWidgets = [];
    final dayEvents = getEventsForDay(day);

    if (dayEvents.isEmpty) {
      timelineWidgets.add(const Text('No events for today.'));
    } else {
      for (var event in dayEvents) {
        TimeOfDay? startTime = parseTime(event.startTime);
        TimeOfDay? endTime = parseTime(event.endTime);
        String startTimeString =
            startTime != null ? startTime.format(context) : '';
        String endTimeString = endTime != null ? endTime.format(context) : '';

        timelineWidgets.add(ListTile(
          leading: Text(startTimeString),
          title: Row(
            children: [
              if (event.flagUrl != null)
                Image.network(event.flagUrl!, width: 20, height: 20),
              const SizedBox(width: 8),
              Text(event.title),
            ],
          ),
          trailing: Text(endTimeString),
        ));
      }
    }
    return timelineWidgets;
  }

  void _addNewEvent(Event newEvent, DateTime eventDate) {
    // Determine the date key for the events map
    DateTime dateKey;
    if (newEvent.isAllDay) {
      // For all-day events, use only the date part
      dateKey = DateTime(eventDate.year, eventDate.month, eventDate.day);
    } else {
      // For timed events, use the date and time
      // Ensure startTime is not null before parsing
      if (newEvent.startTime != null) {
        dateKey = DateFormat('yyyy-MM-dd HH:mm').parse(
            '${eventDate.year}-${eventDate.month}-${eventDate.day} ${newEvent.startTime}');
      } else {
        // Fallback if startTime is null
        dateKey = DateTime(eventDate.year, eventDate.month, eventDate.day);
      }
    }

    // Add the event to the map
    if (events.containsKey(dateKey)) {
      events[dateKey]!.add(newEvent);
    } else {
      events[dateKey] = [newEvent];
    }

    setState(() {
      // This will trigger a rebuild of the widget tree, thus updating the event list and timeline
    });
  }

  List<Event> getEventsForDay(DateTime day) {
    return events.entries
        .where((entry) =>
            isSameDay(entry.key, day) ||
            (entry.key.isBefore(day) &&
                entry.value
                    .any((event) => event.endDate?.isAfter(day) ?? false)))
        .map((entry) => entry.value)
        .expand((eventList) => eventList)
        .toList();
  }

  TimeOfDay? parseTime(String? timeString) {
    if (timeString == null) return null;

    // List of possible formats
    List<String> formats = ['H:m', 'h:m a', 'h:m'];

    for (String format in formats) {
      try {
        final DateFormat formatter = DateFormat(format);
        final DateTime dateTime = formatter.parse(timeString);
        return TimeOfDay(hour: dateTime.hour, minute: dateTime.minute);
      } catch (e) {
        continue; // Try the next format
      }
    }

    // Return null or throw an exception if no format matches
    return null;
  }

  @override
  void dispose() {
    super.dispose(); // Call the superclass's dispose method
  }

  // Function to extract the table count from the response data
  int? extractTableCount(Map<String, dynamic> responseData) {
    try {
      final results = responseData['results'] as List<dynamic>;
      if (results.isNotEmpty) {
        final countData = results[0] as Map<String, dynamic>;
        final countValue = countData['COUNT(*)'] as int?;
        return countValue;
      }
    } catch (e) {}
    return null;
  }

// Function to show the create data dialog
  Future<bool> _showCreateDataDialog() async {
    Completer<bool> completer = Completer<bool>();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Create Company Calendar Data'),
          content: const Text(
              'Do you want to create background data for the company calendar?'),
          actions: <Widget>[
            TextButton(
              child: const Text('No'),
              onPressed: () {
                Navigator.of(context)
                    .pop(false); // Close the dialog and return false
                completer.complete(false);
              },
            ),
            TextButton(
              child: const Text('Yes'),
              onPressed: () {
                Navigator.of(context)
                    .pop(true); // Close the dialog and return true
                completer.complete(true);
              },
            ),
          ],
        );
      },
    );

    return completer.future;
  }

  // Function to show the user notification
  void _showUserNotification() {
    showDialog(
      context: context, // Make sure you have access to the BuildContext
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Data Not Available'),
          content:
              const Text('Contact your administrator, data does not exist.'),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
            ),
          ],
        );
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  // Fetch the user's authorization level from shared preferences
  _fetchUserAuthorizationLevel() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      userAuthorizationLevel = prefs.getString('restrictionLevel') ?? '';
    });
  }

  // Fetch image URL for the current season
  Future<String?> fetchImageForSeason(String season) async {
    final String apiBaseUrl =
        'https://api.unsplash.com/photos/random?query=$season';
    final List<String> unsplashApiKeys = [
      '82b1_ECBSnBMA1fLB4ycGpuFjroV_DJ2eG2-cg5EVn8',
      'uX5gg9mWBMPRgfkkRvLCQc4pdhmRXnCw8A4_al_ga9g',
      'SdaFnP4rOWoNy-ladeHPwnsD617gbV5884GuhJneooc',
      'SOK1nziBnhWXlLbLPnwlO-NkYyMipHaH5Ejas3sdKyE',
      'ISPUVhnGmpLkCUatyyiI2_IdUklgf4uuvE-uNd5Fc-M',
      // Add more API keys as needed
    ];

    // Fetch image URL from API
    for (final apiKey in unsplashApiKeys) {
      try {
        final response = await http.get(Uri.parse(apiBaseUrl), headers: {
          'Authorization': 'Client-ID $apiKey',
        });

        if (response.statusCode == 200) {
          final imageData = json.decode(response.body);
          final String imageUrl = imageData['urls']['regular'];
          return imageUrl; // Exit the loop if an image is fetched successfully
        } else {}
      } catch (e) {}
    }

    // If none of the API keys work or an error occurs in all attempts
    return null;
  }

// Determine the season along with the month for more specific context using range comparisons
  String _getSeasonForMonth() {
    final int month = _focusedDay.month;
    if (month == 1 || month == 12) {
      return 'Winter';
    } else if (month == 2) {
      return 'Late Winter';
    } else if (month == 3) {
      return 'Early Spring';
    } else if (month == 4 || month == 5) {
      return 'Spring';
    } else if (month == 6) {
      return 'Early Summer';
    } else if (month == 7 || month == 8) {
      return 'Summer';
    } else if (month == 9) {
      return 'Early Autumn';
    } else if (month == 10 || month == 11) {
      return 'Autumn';
    } else {
      return 'Unknown Season'; // Fallback for any unexpected cases
    }
  }

  Future<Map<String, dynamic>?> getCountryInfoFromCoordinates(
      double latitude, double longitude) async {
    final url =
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$latitude&lon=$longitude';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Extract the country name and country code from the response
        final country = data['address']['country'];
        final countryCode = data['address']['country_code'];

        // Create a map to store both the country name and country code
        final countryInfo = {
          'country': country,
          'countryCode': countryCode,
        };

        return countryInfo;
      } else {}
    } catch (e) {}

    return null;
  }

  Future<Position?> getCurrentLocation() async {
    try {
      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      return position;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> fetchCountryForCurrentUser() async {
    try {
      final PermissionStatus status = await Permission.location.request();

      if (status.isGranted) {
        final Position? location = await getCurrentLocation();
        if (location != null) {
          final double latitude = location.latitude;
          final double longitude = location.longitude;

          final countryInfo =
              await getCountryInfoFromCoordinates(latitude, longitude);

          if (countryInfo != null) {
            // Access the country name and country code

            return countryInfo;
          } else {
            return null;
          }
        } else {
          return null;
        }
      } else if (status.isDenied) {
        return null;
      } else if (status.isPermanentlyDenied) {
        // Handle this case differently if needed.
        return null;
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> fetchNationalHolidays(
      String countryCode, int year, String apiKey, bool subdivisions) async {
    const baseUrl = 'https://holidayapi.com/v1/holidays';

    // Define the query parameters
    final params = {
      'country': countryCode,
      'language': 'en',
      'year': year.toString(),
      'key': apiKey,
      'subdivisions':
          subdivisions.toString(), // Include the 'subdivisions' parameter
    };

    final uri = Uri.parse(baseUrl).replace(queryParameters: params);

    try {
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return data;
      } else {
        return null; // Return null to indicate an error
      }
    } catch (e) {
      return null; // Return null to indicate an error
    }
  }

  Future<List<Map<String, dynamic>>?> fetchCountryList(String apiKey) async {
    const baseUrl = 'https://holidayapi.com/v1/countries';

    // Define the query parameters
    final params = {
      'key': apiKey,
      'pretty': 'true', // Include the 'pretty' parameter
    };

    final uri = Uri.parse(baseUrl).replace(queryParameters: params);

    try {
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final List<Map<String, dynamic>> countryList =
            (json.decode(response.body)['countries'] as List)
                .map((country) => Map<String, dynamic>.from(country))
                .toList();

        return countryList;
      } else {
        return null; // Return null to indicate an error
      }
    } catch (e) {
      return null; // Return null to indicate an error
    }
  }

  Future<bool> _askUserForMode(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text("Select Mode"),
              content: Text(
                  "Would you like to use the app in online or offline mode?"),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true), // online
                  child: Text("Online"),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false), // offline
                  child: Text("Offline"),
                ),
              ],
            );
          },
        ) ??
        true; // Default to online mode if the user doesn't select anything
  }

  _performMaintenanceCheck(BuildContext context) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    // Determine if the app is in online or offline mode
    String mode = prefs.getString('mode') ?? 'offline';

    if (mode == 'online') {
      // Online mode operations
      String? userToken = prefs.getString('token');
      String? userAccessLevel = prefs.getString('restrictionLevel');
      final Uri maintenanceCheckUri =
          Uri.parse('${NgrokManager.ngrokUrl}/api/query');
      const String sqlQuery =
          "SELECT COUNT(*) FROM information_schema.tables WHERE table_name = 'calendar_main'";

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => CustomLoadingWidget(
          message: 'Performing maintenance check...',
          stepDescription: 'Step 1',
          onConfirm: (bool) {},
        ),
      );

      try {
        final response = await http.post(
          maintenanceCheckUri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $userToken',
          },
          body: json.encode({'query': sqlQuery}),
        );

        Navigator.of(context).pop(); // Close the dialog

        if (response.statusCode == 200) {
          final responseData = json.decode(response.body);
          final int? tableCount = extractTableCount(responseData);
          if (tableCount == 0 && userAccessLevel == 'admin') {
            bool createData = await _showCreateDataDialog();
            if (createData) {
              await _createCalendarTableAndData(context, userToken!);
            }
            await _loadEvents(startDateTime, endDateTime);
            if (mounted) {
              setState(() {
                _dataLoaded = true;
              });
            }
          }
        }
      } catch (e) {
        // Handle exception
        Navigator.of(context).pop();
      }
    } else {
      // Ensure the database is initialized before continuing
      final db = await DatabaseHelper.instance.database;

      // For querying the 'events' table to check if it contains any entries
      final List<Map> entries = await db.query('events');

      if (entries.isEmpty) {
        // The "events" table exists but contains no entries. Proceed with inserting initial data
        print("No entries found in events table. Initializing data...");

        await _createCalendarTableAndData(context, '');
        await _loadData();

        // Proceed with any additional setup or data insertion as needed
      }
      if (mounted) {
        setState(() {
          _dataLoaded = true;
        });
      }
    }
  }

  Map<DateTime, List<Event>> structureEvents(List<Event> events) {
    Map<DateTime, List<Event>> structuredEvents = {};

    for (var event in events) {
      DateTime? eventDate =
          event.date; // Ensure event.date is a DateTime object
      structuredEvents.update(
        eventDate!,
        (existingEvents) => existingEvents..add(event),
        ifAbsent: () => [event],
      );
    }

    // Adding dummy data
    DateTime today = DateTime.now();
    structuredEvents.update(
      today,
      (existingEvents) => existingEvents
        ..addAll([
          Event(
            id: null,
            title: "Morning Meeting",
            isPrivate: false,
            isAllDay: false,
            date: today,
            startTime: "09:00",
            endTime: "10:00",
            username: "User",
          ),
          Event(
            id: null,
            title: "Lunch Break",
            isPrivate: false,
            isAllDay: false,
            date: today,
            startTime: "12:00",
            endTime: "13:00",
            username: "User",
          ),
        ]),
      ifAbsent: () => [
        Event(
          id: null,
          title: "Morning Meeting",
          isPrivate: false,
          isAllDay: false,
          date: today,
          startTime: "09:00",
          endTime: "10:00",
          username: "User",
        ),
        Event(
          id: null,
          title: "Lunch Break",
          isPrivate: false,
          isAllDay: false,
          date: today,
          startTime: "12:00",
          endTime: "13:00",
          username: "User",
        ),
      ],
    );

    return structuredEvents;
  }

  Future<void> _loadData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String mode = prefs.getString('mode') ?? 'offline';

    if (mode == 'online') {
      // Pass the DateTime range to _loadEvents
      await _loadEvents(startDateTime, endDateTime);
    } else {
      // Pass the DateTime range to _loadDataFromSQLite
      await _loadDataFromSQLite(startDateTime, endDateTime);
    }
  }

  Future<void> _loadEvents(DateTime startYear, DateTime endYear) async {
    try {
      final response =
          await http.get(Uri.parse('${NgrokManager.ngrokUrl}/api/fetchEvents'));
      if (response.statusCode == 200) {
        List<dynamic> fetchedData = jsonDecode(response.body)['results'];
        for (var entry in fetchedData) {
          DateTime eventDate = DateTime.parse(entry['event_date']);
          Event newEvent = Event(
            title: entry['event_name'],
            date: eventDate,
            isPrivate: entry['private'] == 1,
            isAllDay:
                entry['event_time'].isEmpty && entry['event_time_end'].isEmpty,
            startTime: entry['event_time'],
            endTime: entry['event_time_end'],
            flagUrl: entry['flag_url'],
            username: entry['username'],
          );

          if (newEvent.isPrivate) {
            // Add this holiday for each year in the range
            for (int year = startYear.year; year <= endYear.year; year++) {
              DateTime repeatingHoliday =
                  DateTime.utc(year, eventDate.month, eventDate.day);
              holidays.add(repeatingHoliday);
            }
          } else {
            events.putIfAbsent(eventDate, () => []).add(newEvent);
          }
        }
      } else {
        print('Failed to load events with status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Failed to load events: $e');
    }
  }

  Future<void> _loadDataFromSQLite(DateTime startYear, DateTime endYear) async {
    try {
      List<Event> eventsFromDB = await DatabaseHelper.instance.fetchEvents();
      print("Fetched ${eventsFromDB.length} events from SQLite.");

      for (var event in eventsFromDB) {
        if (event.date == null) {
          print("Skipping event with null date: ${event.title}");
          continue;
        }

        DateTime eventDate =
            DateTime(event.date!.year, event.date!.month, event.date!.day);
        if (event.isPrivate) {
          // Repeat this holiday for each year within the specified range
          for (int year = startYear.year; year <= endYear.year; year++) {
            DateTime repeatedHoliday =
                DateTime.utc(year, eventDate.month, eventDate.day);
            holidays.add(repeatedHoliday);
          }
        } else {
          events.putIfAbsent(eventDate, () => []).add(event);
        }
      }

      print(
          "Total events from SQLite: ${events.length}, Holidays: ${holidays.length}");
    } catch (e) {
      print("Error loading events from SQLite: $e");
    }
  }

  Future<void> _createCalendarTableAndData(
    BuildContext context,
    String userToken,
  ) async {
// Initialize as true
    List<String> storedCountries = []; // List to store country codes
    List<String>? selectedCountries = []; // List to store selected countries
    Map<String, dynamic> fetchedData = {};
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<Map<String, dynamic>> countryData =
        []; // Define countryData here if it's used in multiple steps

    String? mode =
        prefs.getString('mode') ?? 'offline'; // Assume 'offline' if not set

    try {
      // Define the list of steps
      final List<Step> steps = [
        Step(
          description: 'Creating the calendar table...',
          action: () async {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) {
                return CustomLoadingWidget(
                  message: 'Preparing calendar data...',
                  stepDescription: 'Step 1',
                  onConfirm: (bool2) {},
                );
              },
            );

            if (mode == 'online') {
              // Online mode: execute query to create table on remote server
              const String createTableQuery = '''
              CREATE TABLE IF NOT EXISTS calendar_main (
                id INT AUTO_INCREMENT PRIMARY KEY,
                event_name VARCHAR(255) NOT NULL,
                event_date DATE NOT NULL,
                event_description TEXT,
                origin VARCHAR(255) NOT NULL,
                private TINYINT(1) NULL,
                event_time TIME NULL,
                event_time_end TIME NULL
              )
            ''';

              try {
                await _sendQueryToEndpoint(createTableQuery, userToken);
              } catch (e) {
                // Handle the error
              } finally {
                Navigator.of(context)
                    .pop(); // Close the dialog regardless of the result
              }
            } else {
              // Offline mode: Use DatabaseHelper to initialize the SQLite database
              try {
                await DatabaseHelper.instance.database;
              } catch (e) {
                // Handle the error
                print("Error during table creation: $e");
              } finally {
                Navigator.of(context)
                    .pop(); // Close the dialog regardless of the result
              }
            }
          },
        ),
        Step(
          description: 'Fetching current country and national holidays...',
          action: () async {
            final Map<String, dynamic>? countryInfo =
                await fetchCountryForCurrentUser();
            String? currentCountry;

            if (countryInfo != null) {
              currentCountry = countryInfo['country'];
            }

            final countryCode = countryInfo?['countryCode'];
            if (countryCode != null &&
                (selectedCountries == null ||
                    !selectedCountries!.contains(countryCode.toUpperCase()))) {
              selectedCountries ??= [];
              selectedCountries?.add(countryCode.toUpperCase());
            }
            final bool addDataForCurrentCountry = await showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) {
                return AlertDialog(
                  title: const Text('Add National Data for Current Country?'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if (currentCountry != null)
                        Text('Current country: $currentCountry'),
                      const Text(
                          'Do you want to add national data for the current country?'),
                    ],
                  ),
                  actions: [
                    TextButton(
                      child: const Text('Yes'),
                      onPressed: () {
                        Navigator.of(context).pop(true); // User confirmed "Yes"
                      },
                    ),
                    TextButton(
                      child: const Text('No'),
                      onPressed: () {
                        Navigator.of(context).pop(false); // User selected "No"
                      },
                    ),
                  ],
                );
              },
            );

            if (addDataForCurrentCountry) {
              try {
                final nationalHolidays = await fetchNationalHolidays(
                  countryCode!,
                  2023,
                  'e95d7d2d-42b4-4b5f-8fa5-348e1f1e550e',
                  true, // Include the 'subdivisions' parameter
                );

                if (nationalHolidays != null && nationalHolidays.isNotEmpty) {
                  if (!storedCountries.contains(countryCode)) {
                    storedCountries
                        .add(countryCode); // Add the country to the list
                  }
                } else {}

                // Log when the step is finished
              } catch (e) {}
            }
          },
        ),

        Step(
          description: 'Add Data for Another Country?',
          action: () async {
            countryData = (await fetchCountryList(
                'e95d7d2d-42b4-4b5f-8fa5-348e1f1e550e'))!; // Fetch and store in the larger scope
            print('country data: $countryData');
            if (countryData.isNotEmpty) {
              await _storeCountriesInDatabase(countryData, userToken);
              selectedCountries = await showDialog<List<String>>(
                context: context,
                builder: (context) => SelectCountriesDialog(
                    countryData: countryData,
                    selectedCountries: selectedCountries),
              );

              if (selectedCountries!.isNotEmpty) {
                bool fetchConfirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => ConfirmFetchDialog(
                            selectedCountries: selectedCountries)) ??
                    false;

                if (fetchConfirmed) {
                  selectedCountries = selectedCountries!.toSet().toList();
                  selectedCountries!.removeWhere(
                      (country) => storedCountries.contains(country));

                  List<String>? modifiedCountries =
                      await showDialog<List<String>>(
                    context: context,
                    builder: (context) => ModifyCountriesDialog(
                        selectedCountries: selectedCountries,
                        countryData: countryData),
                  );

                  if (modifiedCountries != null &&
                      modifiedCountries.isNotEmpty) {
                    selectedCountries = modifiedCountries;

                    for (String countryCode in selectedCountries!) {
                      final holidayData = await fetchNationalHolidays(
                          countryCode,
                          DateTime.now().year - 1,
                          'e95d7d2d-42b4-4b5f-8fa5-348e1f1e550e',
                          true);

                      if (holidayData != null) {
                        fetchedData[countryCode] = holidayData;
                        if (_dataSource == DataSource.online) {
                          List<Map<String, dynamic>> structuredData =
                              structureHolidayData(holidayData, countryCode);
                          await insertHolidaysIntoDatabase(
                              structuredData, userToken); // Online storage only
                        }
                      }
                    }
                  }
                }
              }
            }
          },
        ), // Add this step in the final List<Step> steps array
        Step(
          description:
              'Structuring and inserting holiday data into database...',
          action: () async {
            try {
              List<Map<String, dynamic>> allStructuredData = [];
              // Create a dictionary for flag URLs using country code as key
              Map<String, String> flagUrls = {
                for (var country in countryData)
                  country['code']: country['flag']
              };

              // Iterate over each fetched country's data
              for (String countryCode in fetchedData.keys) {
                var structuredData =
                    structureHolidayData(fetchedData[countryCode], countryCode);
                // Add flag URL to each event in structured data
                structuredData.forEach((data) {
                  data['flagUrl'] = flagUrls[countryCode] ??
                      'default_flag_url'; // Provide a default if null
                });
                allStructuredData.addAll(structuredData);
              }

              if (mode == 'online') {
                // Insert all structured holiday data into the online database
                await insertHolidaysIntoDatabase(allStructuredData, userToken);
              } else {
                // Offline mode: Insert structured data into the SQLite database
                for (var holidayData in allStructuredData) {
                  Event newEvent = Event(
                      title: holidayData['event_name'],
                      isPrivate: holidayData['private'] == 1,
                      isAllDay:
                          true, // Assuming all holidays are all-day events
                      date: DateTime.parse(holidayData['event_date']),
                      startTime:
                          null, // No specific start time for all-day events
                      endTime: null, // No specific end time for all-day events
                      flagUrl: holidayData[
                          'flagUrl'], // Use the included or default flag URL
                      username:
                          "offlineUser" // Example username in offline mode
                      );

                  // Inserting event into SQLite database
                  await DatabaseHelper.instance.insertEvent(newEvent);
                }
              }
            } catch (e) {
              print('Error during data structuring or database operations: $e');
            }
          },
        )
      ];

      for (int i = 0; i < steps.length; i++) {
        // Log when the step is about to start

        // Execute the action for the current step
        await steps[i].action();
      }
    } catch (e) {}
  }

  Future<void> _storeCountriesInDatabase(
      List<Map<String, dynamic>> countries, String userToken) async {
    if (countries.isEmpty) {
      return;
    }

    // Table creation query
    const String createTableQuery = '''
CREATE TABLE IF NOT EXISTS calendar_countries (
    code CHAR(2) PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    flag TEXT NOT NULL
);

''';

    // Run the table creation query first
    bool isTableCreated =
        await _sendQueryToEndpoint(createTableQuery, userToken);
    if (!isTableCreated) {
      return; // Exit if the table wasn't created to avoid errors
    }

    List<String> valuesList = [];

    for (var country in countries) {
      final code = country['code'];
      final name = country['name'];
      final flagUrl = country['flag'];

      valuesList.add("('$code', '$name', '$flagUrl')");
    }

    final String values = valuesList.join(', ');

    final String insertQuery = '''
INSERT INTO calendar_countries (code, name, flag)
VALUES $values;
''';

    bool isSuccess = await _sendQueryToEndpoint(insertQuery, userToken);

    if (isSuccess) {
    } else {}
  }

  Future<void> insertHolidaysIntoDatabase(
      List<Map<String, dynamic>> structuredData, String userToken) async {
    if (structuredData.isEmpty) {
      return;
    }

    String values = structuredData
        .map((entry) =>
            "('${entry['event_name'].replaceAll("'", "''")}', '${entry['event_date']}', '${entry['origin']}', ${entry['private']}, NULL, NULL)") // Use NULL for event_time and event_time_end
        .join(', ');

    String insertQuery = '''
  INSERT INTO calendar_main (event_name, event_date, origin, private, event_time, event_time_end)
  VALUES $values;
''';

    // Print the query
    await _sendQueryToEndpoint(insertQuery, userToken);
  }

  List<Map<String, dynamic>> structureHolidayData(
      Map<String, dynamic> holidayData, String countryCode) {
    List<Map<String, dynamic>> structuredDataList = [];

    if (holidayData.containsKey('holidays')) {
      List<dynamic> holidays = holidayData['holidays'];

      for (var holiday in holidays) {
        structuredDataList.add({
          'event_name': holiday['name'],
          'event_date': holiday['date'],
          'origin': countryCode,
          'private': holiday['public'] == true
              ? 1
              : 0, // Map 'public' to 'private' and convert boolean to int
          'event_time': '', // Added this line for empty event_time
        });
      }
    }

    return structuredDataList;
  }

  Future<void> _deleteCalendarTables(String userToken) async {
    // Define the SQL queries to drop both calendar tables
    const String dropMainTableQuery = 'DROP TABLE IF EXISTS calendar_main';
    const String dropCountriesTableQuery =
        'DROP TABLE IF EXISTS calendar_countries';

    // Send the SQL queries to the query endpoint
    bool mainTableDeleted =
        await _sendQueryToEndpoint(dropMainTableQuery, userToken);
    bool countriesTableDeleted =
        await _sendQueryToEndpoint(dropCountriesTableQuery, userToken);

    if (mainTableDeleted && countriesTableDeleted) {
    } else {}
  }

  Future<bool> _sendQueryToEndpoint(String query, String userToken) async {
    // Define your API endpoint URL
    final String apiUrl = '${NgrokManager.ngrokUrl}/api/query';

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: <String, String>{
          'Content-Type': 'application/json',
          // Include any necessary headers, such as authorization if required
          'Authorization': 'Bearer $userToken',
        },
        body: jsonEncode(<String, String>{
          'query': query,
        }),
      );

      if (response.statusCode == 200) {
        // Query execution was successful

        return true;
      } else {
        // Query execution failed
        return false;
      }
    } catch (e) {
      // Handle network errors or exceptions
      return false;
    }
  }

  List<Widget> _buildEventListForMonth(DateTime month) {
    final Map<String, List<Event>> countryGroups = {};
    final List<Widget> eventWidgets = [];

    // Efficient processing by grouping events by country
    events.forEach((date, eventList) {
      if (date.month == month.month && date.year == month.year) {
        for (var event in eventList) {
          String countryKey = event.flagUrl ?? 'No Country';
          countryGroups.putIfAbsent(countryKey, () => []).add(event);
        }
      }
    });

    // Generate widgets for each group
    countryGroups.forEach((country, events) {
      events.sort((a, b) => a.title.compareTo(b.title));

      List<Widget> eventTiles = events.map((event) {
        return ListTile(
          title: Text(event.title),
          subtitle: Text(
              "${DateFormat('MMMM d, yyyy').format(event.date!)} | ${event.isAllDay ? 'All day' : '${event.startTime} - ${event.endTime}'}"),
          trailing: Icon(event.isPrivate ? Icons.person : Icons.public,
              color: event.isPrivate ? Colors.red : Colors.green),
        );
      }).toList();

      Widget flagWidget = country != 'No Country'
          ? Image.network(country, width: 30, height: 30)
          : SizedBox.shrink();
      eventWidgets.add(Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (flagWidget is! SizedBox)
              Padding(padding: EdgeInsets.all(8.0), child: flagWidget),
            ...eventTiles
          ],
        ),
      ));
    });

    if (eventWidgets.isEmpty) {
      eventWidgets.add(Text('No events for this month.',
          style: TextStyle(fontStyle: FontStyle.italic)));
    }

    return eventWidgets;
  }

  List<Widget> _buildEventListForMonthGrouped(DateTime month) {
    final Map<String, List<Event>> eventGroups = {};
    final Map<String, Set<String>> eventFlags = {};
    final Map<String, String> flagsKeyMap = {};
    final List<Widget> eventWidgets = [];

    // Collect flags for each event based on title and date
    events.forEach((date, eventList) {
      if (date.month == month.month && date.year == month.year) {
        for (var event in eventList) {
          String baseKey = '${event.title}_${event.date}';
          eventFlags.putIfAbsent(baseKey, () => Set<String>())
            ..add(event.flagUrl ?? '');
        }
      }
    });

    // Create a unique key for each set of flags
    eventFlags.forEach((key, flags) {
      List<String> sortedFlags = flags.toList()..sort();
      String flagsKey = sortedFlags.join('_');
      flagsKeyMap[key] = flagsKey;
    });

    // Group events by a unique combination of title, date, and flags
    events.forEach((date, eventList) {
      if (date.month == month.month && date.year == month.year) {
        for (var event in eventList) {
          String baseKey = '${event.title}_${event.date}';
          String flagsKey = flagsKeyMap[baseKey]!;
          String groupKey = '${baseKey}_$flagsKey';
          eventGroups.putIfAbsent(flagsKey, () => [])
            ..add(event); // Use flagsKey to group by flags
        }
      }
    });

    // Aggregate similar groups based on flags and create widgets
    eventGroups.forEach((flagsKey, events) {
      List<Widget> flags =
          eventFlags[events.first.title + '_' + '${events.first.date}']!
              .map((url) => Padding(
                  padding: EdgeInsets.symmetric(horizontal: 2),
                  child: Image.network(url, width: 30, height: 20)))
              .toList();

      Event representativeEvent = events.first;
      List<Widget> eventListTile = [
        ListTile(
          leading: Icon(Icons.circle,
              color: representativeEvent.isPrivate
                  ? Colors.red[300]
                  : Colors.green[300],
              size: 12),
          title: Text(representativeEvent.title,
              style: TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(
              "${representativeEvent.date != null ? DateFormat('MMMM d, yyyy').format(representativeEvent.date!) : 'Date not set'} | ${representativeEvent.isAllDay ? 'All day' : '${representativeEvent.startTime} - ${representativeEvent.endTime}'}"),
          trailing: Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () {},
        )
      ];

      // Construct the card for each group
      eventWidgets.add(Card(
        elevation: 4,
        margin: EdgeInsets.all(8),
        child: Column(
          children: [
            if (flags.isNotEmpty)
              Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Row(mainAxisSize: MainAxisSize.min, children: flags)),
            ...eventListTile
          ],
        ),
      ));
    });

    // Handle case when no events are available
    if (eventWidgets.isEmpty) {
      eventWidgets.add(Center(
          child: Text('No events for this month.',
              style: TextStyle(fontStyle: FontStyle.italic, fontSize: 16))));
    }

    return eventWidgets;
  }

  // Preload images for all seasons and cache them
  _preloadSeasonImages() async {
    for (final season in seasonImages.keys) {
      final imageUrl = await fetchImageForSeason(season);
      if (imageUrl != null) {
        final image = CachedNetworkImageProvider(imageUrl);
        await precacheImage(image, context); // Cache the image in memory
        setState(() {
          seasonImages[season] = imageUrl;
          seasonBackgroundImages.add(imageUrl);
        });
      }
    }
    setState(() {
      _imagesLoaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_imagesLoaded || !_dataLoaded) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final int currentSeasonIndex =
        seasonImages.keys.toList().indexOf(_getSeasonForMonth());
    final backgroundImage = seasonBackgroundImages[currentSeasonIndex];

    List<Widget> eventWidgets = groupByCountry
        ? _buildEventListForMonth(_focusedDay)
        : _buildEventListForMonthGrouped(
            _focusedDay); // Use the state to call the correct method

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 250.0,
            floating: false,
            pinned: true,
            flexibleSpace: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
              var top = constraints.biggest.height;
              double opacity = ((top - 100) / 170).clamp(0.0, 1.0);
              return Stack(fit: StackFit.expand, children: [
                Hero(
                  tag: 'backgroundImage',
                  child: CachedNetworkImage(
                    imageUrl: '$backgroundImage',
                    fit: BoxFit.cover,
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.3)
                      ],
                      stops: [0.5, 1.0],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Opacity(
                    opacity: opacity,
                    child: Container(
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.white.withOpacity(0.7),
                            Colors.white.withOpacity(0.0)
                          ],
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Today's Timeline",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: Colors.white)),
                          const SizedBox(height: 10.0),
                          ..._buildTimelineForDay(
                              _focusedDay), // Calls the method to build the timeline for the focused day
                        ],
                      ),
                    ),
                  ),
                ),
              ]);
            }),
          ),
          SliverToBoxAdapter(
            child: LayoutBuilder(builder: (context, constraints) {
              // Dynamic constraint handling within the sliver

              return Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.red, width: 2),
                  color: Colors.grey[200],
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: constraints.maxHeight > 0
                        ? constraints.maxHeight
                        : 500, // Providing a fallback
                  ),
                  child: buildCalendar(),
                ),
              );
            }),
          ),
          SliverFillRemaining(
            child: Container(
              decoration: BoxDecoration(
                // Adding a top border with increased thickness for clear separation
                border: Border(
                    top: BorderSide(color: Colors.grey.shade300, width: 3)),
                // Optional: Adding a shadow to the top border for a slight depth effect
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.5),
                    spreadRadius: 1,
                    blurRadius: 3,
                    offset: Offset(0, -2), // changes position of shadow
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              'Events for ${DateFormat('MMMM yyyy').format(_focusedDay)}',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 18)),
                          const SizedBox(height: 10.0),
                          ...eventWidgets // Using the event widgets
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            groupByCountry = !groupByCountry;
            print("Toggle state updated: $groupByCountry");
          });
        },
        child: Icon(groupByCountry ? Icons.flag : Icons.title),
        tooltip: 'Toggle Grouping',
      ),
    );
  }

  void _onFormatChanged(CalendarFormat format) {
    if (_calendarFormat != format) {
      setState(() {
        _calendarFormat = format;
      });
      // Force a layout update to recalculate the height based on the new format
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _afterLayout(_);
      });
    }
  }

  double calculateDynamicHeaderHeight() {
    // This could be based on device size, orientation, or other factors
    return 100.0; // Example static return
  }

  double calculateDynamicLeftMargin() {
    // Adjust margin dynamically if necessary
    return 50.0; // Example static return
  }

  DateTime _calculateDateFromGesture(Offset localPosition) {
    final RenderBox? box =
        _calendarKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) {
      print("Error: RenderBox is not available.");
      return DateTime(_focusedDay.year, _focusedDay.month,
          _focusedDay.day); // Fallback if box is not found
    }

    double leftMargin = calculateDynamicLeftMargin();
    double cellWidth = box.size.width / 7;
    double rowHeight = _getRowHeight();

    // Adjust localPosition by subtracting the header height
    double headerHeight = calculateDynamicHeaderHeight();
    Offset adjustedPosition =
        Offset(localPosition.dx, localPosition.dy - headerHeight);

    int column = ((adjustedPosition.dx - leftMargin) / cellWidth).floor();
    int row =
        (adjustedPosition.dy / rowHeight).floor(); // Adjusted row calculation

    // Ensure that adjusted position does not result in negative row values
    if (row < 0) {
      print("Gesture in header area, no date calculated.");
      return DateTime(_focusedDay.year, _focusedDay.month,
          _focusedDay.day); // Ignore gestures in the header
    }

    DateTime firstDayOfMonth = DateTime(_focusedDay.year, _focusedDay.month, 1);
    int daysToSubtract = (firstDayOfMonth.weekday - 1) % 7;
    DateTime firstVisibleDay =
        firstDayOfMonth.subtract(Duration(days: daysToSubtract));

    DateTime calculatedDate =
        firstVisibleDay.add(Duration(days: row * 7 + column));

    // Normalize the calculated date to start of the day
    calculatedDate =
        DateTime(calculatedDate.year, calculatedDate.month, calculatedDate.day);

    // Check if the calculated date is within the current focused month
    if (calculatedDate.month == _focusedDay.month &&
        calculatedDate.year == _focusedDay.year) {
      if (!printedDates.contains(calculatedDate)) {
        print("Calculated Date: $calculatedDate");
        printedDates.add(calculatedDate);
      }
      return calculatedDate;
    } else {
      // Return focusedDay if the calculated date is outside the focused month
      print("Calculated Date outside focused month: $calculatedDate");
      return DateTime(_focusedDay.year, _focusedDay.month, _focusedDay.day);
    }
  }

  double _getRowHeight() {
    int numRows = _calendarFormat == CalendarFormat.month
        ? 5
        : _calendarFormat == CalendarFormat.twoWeeks
            ? 2
            : 1;
    return (_calendarMaxHeight - 150.0 - 0.0) / numRows;
  }

  void _afterLayout(_) {
    final RenderBox? renderBox =
        _calendarKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      double newHeight = renderBox.size.height;
      // Only update if the height change is significant to prevent unnecessary updates
      if ((newHeight - _calendarMaxHeight).abs() > 1) {
        print(
            "Updating calendar max height from $_calendarMaxHeight to $newHeight");
        setState(() {
          _calendarMaxHeight = newHeight;
        });
      }
    }
  }

  Future<Set<DateTime>> getHolidayDates() async {
    List<Event> events =
        await getAllEvents(); // Fetches all events using the unified method.
    Set<DateTime> holidays = {};
    for (Event event in events) {
      if (event.isPrivate && event.date != null) {
        holidays.add(event.date!);
      }
    }
    return holidays;
  }

  Future<List<Event>> getAllEvents() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String mode = prefs.getString('mode') ?? 'offline';

    if (mode == 'online') {
      return await fetchEventsOnline();
    } else {
      return await DatabaseHelper.instance.fetchEvents();
    }
  }

  Future<List<Event>> fetchEventsOnline() async {
    List<Event> events = [];
    try {
      final response =
          await http.get(Uri.parse('${NgrokManager.ngrokUrl}/api/fetchEvents'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body)['results'] as List;
        events =
            data.map((e) => Event.fromMap(e as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      print("Failed to fetch events: $e");
    }
    return events;
  }

  Widget buildCalendar() {
    return Container(
      key: _calendarKey,
      child: LayoutBuilder(builder: (context, constraints) {
        return GestureDetector(
          onPanStart: (details) {
            // Optionally handle the start of a pan gesture
          },
          onPanUpdate: (details) => handlePan(details),
          onPanEnd: (details) {
            _lastToggledDay = null; // Reset the last toggled date
            // other cleanup if necessary
            setState(() {
              _cursorPosition = null; // Hide the cursor when pan ends
              // Optionally reset or update the focused day here
            });
          },
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 0.0),
                    child: TableCalendar(
                      locale: 'zh_CN',
                      availableGestures: _isGroupSelectionEnabled
                          ? AvailableGestures.none
                          : AvailableGestures.none,
                      rowHeight: 85.0,
                      firstDay: DateTime.utc(2000, 1, 1),
                      lastDay: DateTime.utc(2100, 12, 31),
                      focusedDay: _focusedDay,
                      headerVisible: true,
                      headerStyle: HeaderStyle(
                        formatButtonShowsNext: false,
                      ),
                      calendarFormat: _calendarFormat,
                      formatAnimationDuration:
                          const Duration(milliseconds: 250),
                      formatAnimationCurve: Curves.easeInOut,
                      onFormatChanged: _onFormatChanged,
                      holidayPredicate: (day) => holidays.contains(day),
                      onPageChanged: (focusedDay) {
                        // Set the focus to the first day of the current month when the page changes
                        DateTime firstDayOfNewMonth =
                            DateTime(focusedDay.year, focusedDay.month, 1);
                        setState(() {
                          _focusedDay = firstDayOfNewMonth;
                        });
                      },
                      eventLoader: _getEventsForDay,
                      calendarBuilders: CalendarBuilders(
                        defaultBuilder: (context, date, _) => CalendarDayCell(
                          key: ValueKey(
                              '${date.toString()}_${selectedDays.contains(date)}'), // Using a composite key
                          date: date,
                          isToday: isSameDay(date, DateTime.now()),
                          selectedDaysNotifier: selectedDaysNotifier,
                          isGroupSelectionEnabled: _isGroupSelectionEnabled,
                          isFocused: isSameDay(date, _focusedDay),
                          isHoliday: (DateTime date) {
                            DateTime normalizedDate =
                                DateTime(date.year, date.month, date.day);
                            return holidays.contains(normalizedDate);
                          },

                          onDayFocused: (DateTime focusedDate) {
                            setState(() {
                              _focusedDay =
                                  focusedDate; // Always update the focused day

                              // Toggle the selected state if group selection is enabled
                              if (_isGroupSelectionEnabled) {
                                toggleSelectedDay(focusedDate);
                              }
                            });
                          },

                          onDaySelected: (DateTime selectedDate) {
                            if (_isGroupSelectionEnabled) {
                              toggleSelectedDay(
                                  selectedDate); // Toggle selection when in group selection mode
                            }
                          },
                          onDayDoubleTapped: (DateTime date) {
                            _onDayCellTapped(context,
                                date); // Call the event creation or editing method on double tap
                          },
                          onDayLongPressed: (DateTime date) {
                            print(
                                'Group selection prestate $_isGroupSelectionEnabled');
                            setState(() {
                              _isGroupSelectionEnabled =
                                  true; // Enable group selection mode
                              if (!selectedDays.contains(date)) {
                                selectedDays.add(
                                    date); // Add the date to selected days if not already added
                              }
                              selectedDaysNotifier.value = Set.from(
                                  selectedDays); // Update the notifier to refresh the UI
                            });
                            print(
                                'Group selection prestate $_isGroupSelectionEnabled');
                          },
                        ),
                        selectedBuilder: (context, date, _) =>
                            _buildSelectedDayCell(context, date),
                        todayBuilder: (context, date, _) => _buildTodayCell(
                          context,
                          date,
                        ),
                        holidayBuilder: (context, date, _) {
                          print("Attempting to build holiday cell for $date");
                          if (holidays.contains(normalizeDate(date))) {
                            print("Building holiday cell for $date");
                            return Container(
                              decoration: BoxDecoration(
                                  color: Colors.red[300],
                                  borderRadius: BorderRadius.circular(8)),
                              child: Center(
                                child: Text(
                                  '${date.day}',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            );
                          } else {
                            return Container(); // Fallback if not a holiday
                          }
                        },
                        outsideBuilder: (context, date, _) =>
                            _buildOutsideCell(context, date),
                        rangeStartBuilder: (context, date, _) =>
                            _buildRangeStartCell(context, date),
                        rangeEndBuilder: (context, date, _) =>
                            _buildRangeEndCell(context, date),
                        withinRangeBuilder: (context, date, _) =>
                            _buildWithinRangeCell(context, date),
                        disabledBuilder: (context, date, _) =>
                            _buildDisabledCell(context, date),
                        markerBuilder: markerBuilder,
                      ),
                      daysOfWeekHeight: 50,
                    ),
                  ),
                ],
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: CursorPainter(
                      cursorPosition: _cursorPosition,
                      radius: 20.0,
                      color: Colors.red,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  DateTime normalizeDate(DateTime date) {
    return DateTime.utc(date.year, date.month, date.day);
  }

  List<Event> _getEventsForDay(DateTime day) {
    return events[day] ?? [];
  }

  void handlePan(DragUpdateDetails details) {
    RenderBox? box =
        _calendarKey.currentContext?.findRenderObject() as RenderBox?;
    if (box != null) {
      Offset localPosition = box.globalToLocal(details.globalPosition);
      double headerHeight = calculateDynamicHeaderHeight();

      // Ensure that the gesture is within the calendar bounds, below the header
      if (localPosition.dy > headerHeight) {
        localPosition = Offset(min(max(localPosition.dx, 0), box.size.width),
            min(max(localPosition.dy, headerHeight), box.size.height));

        DateTime dragDate = _calculateDateFromGesture(localPosition);

        // Throttle updates to reduce overhead, only update for new drag positions
        if (_lastToggledDay == null ||
            !_lastToggledDay!.isAtSameMomentAs(dragDate)) {
          _lastToggledDay = dragDate;

          // Handling based on group selection enabled
          if (_isGroupSelectionEnabled) {
            toggleSelectedDay(
                dragDate); // Method to handle adding/removing from selected days
          } else {
            setState(() {
              _selectedDay =
                  dragDate; // Set selected day without adding to group
            });
          }

          setState(() {
            _focusedDay = dragDate;
            _cursorPosition =
                localPosition; // Update cursor to reflect drag position
          });
        }
      } else {
        print("Gesture in header area ignored.");
      }
    }
  }

  void toggleSelectedDay(DateTime selectedDate) {
    DateTime normalizedSelectedDate = normalizeDate(selectedDate);

    // Toggle the selected state of the date
    if (selectedDays.contains(normalizedSelectedDate)) {
      selectedDays.remove(normalizedSelectedDate);
    } else {
      selectedDays.add(normalizedSelectedDate);
    }

    // Update the selected days state and notify listeners
    selectedDaysNotifier.value = Set.from(selectedDays);
    selectedDaysNotifier.notifyListeners();

    // Automatically disable group selection if no dates are selected
    if (selectedDays.isEmpty) {
      _isGroupSelectionEnabled = false;
      print("Group selection disabled due to no selected dates.");
    }
  }

  Widget _buildTodayCell(BuildContext context, DateTime date) {
    return ValueListenableBuilder<Set<DateTime>>(
      valueListenable: selectedDaysNotifier,
      builder: (context, selectedDays, _) {
        bool isSelected = selectedDays.contains(date);
        bool isFocused =
            _focusedDay.isAtSameMomentAs(date); // Check if the date is focused

        return GestureDetector(
          onTap: () {
            toggleSelectedDay(date);
            setState(() {
              _focusedDay = date; // Update the focused day to this date
            });
          },
          child: Container(
            decoration: BoxDecoration(
              color: isFocused
                  ? Colors.red
                  : (isSelected
                      ? Colors.blue[300]
                      : Colors.orange), // Change color based on focus
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? Colors.blue : Colors.orange[700]!,
                width: 2,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.5),
                        spreadRadius: 1,
                        blurRadius: 3,
                        offset: Offset(0, 2),
                      )
                    ]
                  : [],
            ),
            child: Center(
              child: Text(
                '${date.day}',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSelectedDayCell(BuildContext context, DateTime date) {
    // Use ValueListenableBuilder for selected states and manually check for focused states
    return ValueListenableBuilder<Set<DateTime>>(
      valueListenable: selectedDaysNotifier,
      builder: (context, selectedDays, _) {
        bool isSelected = selectedDays.contains(date);
        bool isFocused =
            _focusedDay.isAtSameMomentAs(date); // Check if the date is focused

        return GestureDetector(
          key: ValueKey(
              '${date.toString()}_${isSelected}'), // Reflect selection state in the key
          onTap: () => toggleSelectedDay(date),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? Colors.blue : Colors.white,
              border: Border.all(
                  color: isFocused
                      ? Colors.red
                      : (isSelected ? Colors.blueAccent : Colors.transparent),
                  width: 2),
            ),
            child: Center(
              child: Text('${date.day}',
                  style: TextStyle(
                    fontWeight: isFocused ? FontWeight.bold : FontWeight.normal,
                  )),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHolidayCell(BuildContext context, DateTime date) {
    // Customize holiday cell
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: Center(
          child: Text('${date.day}', style: TextStyle(color: Colors.white))),
    );
  }

  Widget _buildOutsideCell(BuildContext context, DateTime date) {
    // Customize outside cell (days outside the current month)
    return Container(
      decoration: BoxDecoration(
        color: Colors.yellow[200],
      ),
      child: Center(
          child: Text('${date.day}', style: TextStyle(color: Colors.grey))),
    );
  }

  Widget _buildRangeStartCell(BuildContext context, DateTime date) {
    // Customize range start cell
    return Container(
      decoration: BoxDecoration(
          color: Colors.green[200],
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(10),
            bottomLeft: Radius.circular(10),
          )),
      child: Center(
          child: Text('${date.day}', style: TextStyle(color: Colors.white))),
    );
  }

  Widget _buildRangeEndCell(BuildContext context, DateTime date) {
    // Customize range end cell
    return Container(
      decoration: BoxDecoration(
          color: Colors.green[200],
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(10),
            bottomRight: Radius.circular(10),
          )),
      child: Center(
          child: Text('${date.day}', style: TextStyle(color: Colors.white))),
    );
  }

  Widget _buildWithinRangeCell(BuildContext context, DateTime date) {
    // Customize within range cell
    return Container(
      decoration: BoxDecoration(color: Colors.green[100]),
      child: Center(
          child: Text('${date.day}', style: TextStyle(color: Colors.white))),
    );
  }

  Widget _buildDisabledCell(BuildContext context, DateTime date) {
    // Customize disabled cell
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[400],
      ),
      child: Center(
          child: Text('${date.day}', style: TextStyle(color: Colors.white))),
    );
  }

  AnimatedContainer? markerBuilder(
      BuildContext context, DateTime date, List<dynamic> events) {
    List<Event> typedEvents = events.cast<Event>();
    if (typedEvents.isNotEmpty) {
      bool isMultiDay = typedEvents.any((Event event) =>
          event.endDate != null && !isSameDay(event.date, event.endDate));
      return AnimatedContainer(
        duration: Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: isMultiDay ? Colors.blue[200] : Colors.blue,
          shape: BoxShape.rectangle,
        ),
        width: 16,
        height: 16,
        child: Center(
            child: Text('${typedEvents.length}',
                style: TextStyle(color: Colors.white))),
      );
    }
    return null;
  }

  Widget _buildRegularCellContent(DateTime date) {
    List<Event> dayEvents = getEventsForDay(date);
    bool hasEvent = dayEvents.isNotEmpty;

    return SingleChildScrollView(
      child: Container(
        padding: EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              date.day.toString(),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.black,
              ),
            ),
            if (hasEvent) Icon(Icons.event, size: 16, color: Colors.red),
            ...dayEvents
                .map((event) => Text(
                      event.title,
                      style: TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ))
                .toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedCellContent(DateTime date) {
    List<Event> dayEvents = getEventsForDay(date);
    bool isSelected = isSameDay(_selectedDay, date);

    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: isSelected ? Colors.blue : Colors.white,
        boxShadow: isSelected
            ? [
                BoxShadow(
                    color: Colors.blueAccent,
                    spreadRadius: 3,
                    blurRadius: 5,
                    offset: Offset(0, 2))
              ]
            : [],
        borderRadius: BorderRadius.circular(8),
      ),
      width: isSelected
          ? MediaQuery.of(context).size.width
          : MediaQuery.of(context).size.width / 7,
      height: isSelected ? 150 : 100,
      padding: EdgeInsets.all(8),
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              date.day.toString(),
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            if (dayEvents.isNotEmpty)
              ...dayEvents
                  .map((event) => Text(event.title,
                      style: TextStyle(
                          fontSize: 12, overflow: TextOverflow.ellipsis)))
                  .toList(),
          ],
        ),
      ),
    );
  }

  Future<void> _onDayCellTapped(BuildContext context, DateTime date) async {
    TextEditingController titleController = TextEditingController();
    bool isPrivate = false;
    bool isAllDay = true;

    // Convert Set to List and sort it
    List<DateTime> sortedSelectedDates = selectedDays.toList()
      ..sort((a, b) => a.compareTo(b));
    List<List<DateTime>> groupedDates = [];

    // Grouping contiguous dates
    if (sortedSelectedDates.isNotEmpty) {
      List<DateTime> currentGroup = [sortedSelectedDates.first];

      for (int i = 1; i < sortedSelectedDates.length; i++) {
        if (sortedSelectedDates[i]
                .difference(sortedSelectedDates[i - 1])
                .inDays ==
            1) {
          currentGroup.add(sortedSelectedDates[i]);
        } else {
          groupedDates.add(currentGroup);
          currentGroup = [sortedSelectedDates[i]];
        }
      }
      groupedDates.add(currentGroup); // Add the last group
    }

    String pickedStartTime = "0:00";
    String pickedEndTime = "0:00";
    String username = await getUsername();

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String mode = prefs.getString('mode') ?? 'offline';

    // Handling each group as a separate event
    for (var dateGroup in groupedDates) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: Text(
                    "Create Event for ${dateGroup.length > 1 ? '${dateGroup.first} to ${dateGroup.last}' : '${dateGroup.first}'}"),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      TextField(
                        controller: titleController,
                        decoration: InputDecoration(labelText: 'Event Title'),
                      ),
                      SwitchListTile(
                        title: Text('Private Event'),
                        value: isPrivate,
                        onChanged: (value) => setState(() => isPrivate = value),
                      ),
                      SwitchListTile(
                        title: Text('All Day Event'),
                        value: isAllDay,
                        onChanged: (value) {
                          setState(() {
                            isAllDay = value;
                            if (value) {
                              pickedStartTime = "0:00";
                              pickedEndTime = "0:00";
                            }
                          });
                        },
                      ),
                      if (!isAllDay) ...[
                        TextField(
                          decoration:
                              InputDecoration(labelText: "Start Time (HH:MM)"),
                          controller:
                              TextEditingController(text: pickedStartTime),
                          onTap: () async {
                            TimeOfDay? pickedTime = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay(hour: 0, minute: 0),
                            );
                            if (pickedTime != null) {
                              setState(() {
                                pickedStartTime =
                                    "${pickedTime.hour.toString().padLeft(2, '0')}:${pickedTime.minute.toString().padLeft(2, '0')}";
                              });
                            }
                          },
                        ),
                        TextField(
                          decoration:
                              InputDecoration(labelText: "End Time (HH:MM)"),
                          controller:
                              TextEditingController(text: pickedEndTime),
                          onTap: () async {
                            TimeOfDay? pickedTime = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay(hour: 0, minute: 0),
                            );
                            if (pickedTime != null) {
                              setState(() {
                                pickedEndTime =
                                    "${pickedTime.hour.toString().padLeft(2, '0')}:${pickedTime.minute.toString().padLeft(2, '0')}";
                              });
                            }
                          },
                        ),
                      ],
                    ],
                  ),
                ),
                actions: <Widget>[
                  TextButton(
                    child: Text("Cancel"),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  TextButton(
                    child: Text("Save"),
                    onPressed: () async {
                      DateTime startDate = dateGroup.first;
                      DateTime endDate = dateGroup.last;
                      Event newEvent = Event(
                        title: titleController.text,
                        isPrivate: isPrivate,
                        isAllDay: isAllDay,
                        date: startDate,
                        endDate: endDate,
                        startTime:
                            pickedStartTime != "0:00" ? pickedStartTime : null,
                        endTime: pickedEndTime != "0:00" ? pickedEndTime : null,
                        username: username,
                      );

                      if (mode == "offline") {
                        await DatabaseHelper.instance.insertEvent(newEvent);
                        await _loadDataFromSQLite(startDateTime, endDateTime);
                        ;
                        print("Event saved to SQLite in offline mode.");
                      } else {
                        print("Event added temporarily in online mode.");
                      }

                      Navigator.of(context).pop();
                    },
                  ),
                ],
              );
            },
          );
        },
      );
    }
  }
  //end of the calendar page
}

class CalendarDayCell extends StatelessWidget {
  final DateTime date;
  final bool isToday;
  final bool isFocused;
  final ValueNotifier<Set<DateTime>> selectedDaysNotifier;
  final bool isGroupSelectionEnabled;
  final Function(DateTime) onDayFocused;
  final Function(DateTime) onDaySelected;
  final Function(DateTime) onDayDoubleTapped;
  final Function(DateTime) onDayLongPressed;
  final bool Function(DateTime) isHoliday; // Predicate to check for holidays

  const CalendarDayCell({
    Key? key,
    required this.date,
    required this.isToday,
    required this.isFocused,
    required this.selectedDaysNotifier,
    required this.isGroupSelectionEnabled,
    required this.onDayFocused,
    required this.onDaySelected,
    required this.onDayDoubleTapped,
    required this.onDayLongPressed,
    required this.isHoliday, // Include this in the constructor
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Set<DateTime>>(
      valueListenable: selectedDaysNotifier,
      builder: (context, selectedDays, child) {
        bool isSelected = selectedDays.contains(date);
        bool isHoliday = this.isHoliday(date); // Check if the date is a holiday

        return GestureDetector(
          onTap: () => onDayFocused(date),
          onLongPress: () => onDayLongPressed(date),
          onDoubleTap: () => onDayDoubleTapped(date),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.blue
                  : isHoliday
                      ? Colors.red
                      : (isFocused
                          ? Colors.blue[300]
                          : Colors.grey[300]), // Highlight holidays in red
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: isSelected
                      ? Colors.blue
                      : (isFocused
                          ? (Colors.blue[700] ?? Colors.blue)
                          : (Colors.grey[700] ?? Colors.grey)),
                  width: 2),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        spreadRadius: 1,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      )
                    ]
                  : [],
            ),
            child: Center(
              child: Text(
                '${date.day}',
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

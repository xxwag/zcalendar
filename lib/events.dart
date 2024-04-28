import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class Event {
  final int? id;
  final String title;
  final bool isPrivate;
  final bool isAllDay;
  final DateTime? date;
  final DateTime? endDate; // Added to handle multi-day events
  final String? startTime;
  final String? endTime;
  final Color color;
  final String? flagUrl;
  final String username;

  Event({
    this.id,
    required this.title,
    this.isPrivate = false,
    this.isAllDay = true,
    this.date,
    this.endDate, // Initialize in constructor
    this.startTime,
    this.endTime,
    this.flagUrl,
    required this.username,
  }) : color = isPrivate ? Colors.red : Colors.green;

  Event copyWith({
    String? flagUrl,
  }) {
    return Event(
      id: this.id,
      title: this.title,
      isPrivate: this.isPrivate,
      isAllDay: this.isAllDay,
      date: this.date,
      endDate: this.endDate, // Copy with possible new end date
      startTime: this.startTime,
      endTime: this.endTime,
      flagUrl: flagUrl ?? this.flagUrl,
      username: this.username,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'isPrivate': isPrivate ? 1 : 0,
      'isAllDay': isAllDay ? 1 : 0,
      'date': date?.millisecondsSinceEpoch,
      'endDate': endDate?.millisecondsSinceEpoch, // Handle endDate
      'startTime': startTime,
      'endTime': endTime,
      'flagUrl': flagUrl,
      'username': username,
    };
  }

  static Event fromMap(Map<String, dynamic> map) {
    return Event(
      id: map['id'],
      title: map['title'],
      isPrivate: map['isPrivate'] == 1,
      isAllDay: map['isAllDay'] == 1,
      date: map['date'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['date'])
          : null,
      endDate: map['endDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['endDate'])
          : null, // Read endDate
      startTime: map['startTime'],
      endTime: map['endTime'],
      flagUrl: map['flagUrl'],
      username: map['username'],
    );
  }

  @override
  String toString() {
    return 'Event{id: $id, title: "$title", isPrivate: $isAllDay, isAllDay: $isAllDay, date: $date, endDate: $endDate, startTime: "$startTime", endTime: "$endTime", color: ${color.toString()}, flagUrl: "$flagUrl", username: "$username"}';
  }
}

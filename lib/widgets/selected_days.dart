import 'package:flutter/material.dart';

class SelectedDaysNotifier extends ValueNotifier<Set<DateTime>> {
  SelectedDaysNotifier(Set<DateTime> value) : super(value);

  void notifyDayChanged(DateTime date) {
    notifyListeners();
  }
}

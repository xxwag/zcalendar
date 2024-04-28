import 'package:flutter/material.dart';

class SelectCountriesDialog extends StatelessWidget {
  final List<Map<String, dynamic>> countryData;
  final List<String>? selectedCountries;

  const SelectCountriesDialog(
      {Key? key, required this.countryData, this.selectedCountries})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final _selectedCountries = selectedCountries ?? [];
    return AlertDialog(
      title: const Text('Select Countries'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: ListView.builder(
          itemCount: countryData.length,
          itemBuilder: (context, index) {
            final country = countryData[index];
            final isSelected = _selectedCountries.contains(country['code']);
            return CheckboxListTile(
              title: Text(country['name']),
              subtitle: Text(country['code']),
              value: isSelected,
              onChanged: (bool? value) {
                if (value == true) {
                  _selectedCountries.add(country['code']);
                } else {
                  _selectedCountries.remove(country['code']);
                }
                // This might need a way to update the UI based on selection changes
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          child: const Text('Done'),
          onPressed: () => Navigator.of(context).pop(_selectedCountries),
        ),
      ],
    );
  }
}

class ConfirmFetchDialog extends StatelessWidget {
  final List<String>? selectedCountries;

  const ConfirmFetchDialog({Key? key, this.selectedCountries})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Fetch Data?'),
      content: Text(
          'Do you want to fetch data for ${selectedCountries?.length} selected countries?'),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Yes'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('No'),
        ),
      ],
    );
  }
}

class ModifyCountriesDialog extends StatefulWidget {
  final List<String>? selectedCountries;
  final List<Map<String, dynamic>> countryData;

  const ModifyCountriesDialog(
      {Key? key, this.selectedCountries, required this.countryData})
      : super(key: key);

  @override
  _ModifyCountriesDialogState createState() => _ModifyCountriesDialogState();
}

class _ModifyCountriesDialogState extends State<ModifyCountriesDialog> {
  List<String>? modifiedCountries;

  @override
  void initState() {
    super.initState();
    modifiedCountries = widget.selectedCountries;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Modify Selected Countries'),
      content: Container(
        width: double.maxFinite,
        height: 400,
        child: ListView.builder(
          itemCount: modifiedCountries?.length ?? 0,
          itemBuilder: (BuildContext context, int index) {
            String code = modifiedCountries![index];
            String name = widget.countryData
                .firstWhere((item) => item['code'] == code)['name'];
            return ListTile(
              title: Text(name),
              trailing: IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () {
                  setState(() {
                    modifiedCountries!.removeAt(index);
                  });
                },
              ),
            );
          },
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(modifiedCountries),
          child: const Text('Done'),
        ),
      ],
    );
  }
}

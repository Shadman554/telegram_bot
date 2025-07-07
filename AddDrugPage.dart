import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'firestore_service.dart';
import 'package:VetDict/druglist.dart'; // Import Drug from druglist.dart



class AddDrugPage extends StatefulWidget {
  final ValueNotifier<Color> themeColorNotifier;
  final ValueNotifier<Color> buttonColorNotifier;

  AddDrugPage({
    required this.themeColorNotifier,
    required this.buttonColorNotifier,
  });

  @override
  _AddDrugPageState createState() => _AddDrugPageState();
}

class _AddDrugPageState extends State<AddDrugPage> {
  TextEditingController nameController = TextEditingController();
  TextEditingController infoController = TextEditingController();
  TextEditingController sideEffectController = TextEditingController();
  TextEditingController usageController = TextEditingController();
  TextEditingController searchController = TextEditingController(); // Search

  List<Drug> drugs = [];
  List<Drug> filteredDrugs = []; // Filtered list for search results
  final FirestoreService _firestoreService = FirestoreService();
  bool _isSending = false;
  Drug? _editingDrug; // For edit functionality

  @override
  void initState() {
    super.initState();
    _loadData();
    filteredDrugs = List.from(drugs); // Initialize filtered list
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Color>(
      valueListenable: widget.themeColorNotifier,
      builder: (context, themeColor, child) {
        return Scaffold(
          appBar: AppBar(
            title: Text(
              _editingDrug == null
                  ? 'زیادکردنی دەرمانی نوێ'
                  : 'دەستکاریکردنی دەرمان',
              style: TextStyle(
                fontFamily: 'nrt',
                fontSize: 20,
                color: Colors.white,
              ),
            ),
            backgroundColor: themeColor,
            centerTitle: true,
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back,
                color: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
          ),
          body: Container(
            color: Color(0xFFF5F5F5),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTextField(nameController, 'ناوی دەرمان'),
                        SizedBox(height: 8),
                        _buildTextField(usageController, 'بەکارهێنان'),
                        SizedBox(height: 8),
                        _buildTextField(
                            sideEffectController, 'کاریگەری لاوەکی'),
                        SizedBox(height: 8),
                        _buildTextField(infoController, 'زانیاری زیاتر',
                            maxLines: 3),
                        SizedBox(height: 16),
                        Center(child: _buildButtonRow()), // Adjust button row
                        SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                  searchController, 'گەڕان بۆ دەرمان',
                                  maxLines: 1),
                            ),
                            IconButton(
                              icon: Icon(Icons.search, color: Colors.blue),
                              onPressed: _performSearch, // Implement search
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    itemCount: filteredDrugs.length,
                    itemBuilder: (context, index) {
                      final drug = filteredDrugs[index];
                      return Dismissible(
                        key: Key(drug.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: Colors.redAccent,
                          alignment: Alignment.centerRight,
                          padding: EdgeInsets.symmetric(horizontal: 20),
                          child: Image.asset(
                            'assets/icons/trash.png',
                            width: 24,
                            height: 24,
                            color: Colors.white,
                          ),
                        ),
                        confirmDismiss: (direction) async {
                          return await showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                title: Center(
                                  child: Text(
                                    'دڵنیایت؟',
                                    style: TextStyle(
                                      fontFamily: 'Nrt',
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                                content: Text(
                                  'دەتەویت ئەم دەرمانە بسڕیتەوە؟',
                                  style: TextStyle(
                                    fontFamily: 'Nrt',
                                    color: Colors.black,
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                                actions: <Widget>[
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: <Widget>[
                                      TextButton(
                                        onPressed: () {
                                          Navigator.of(context).pop(false);
                                        },
                                        child: Text(
                                          'نەخێر',
                                          style: TextStyle(
                                            fontFamily: 'Nrt',
                                            color: Colors.red,
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      TextButton(
                                        onPressed: () {
                                          Navigator.of(context).pop(true);
                                        },
                                        child: Text(
                                          'بەڵێ',
                                          style: TextStyle(
                                            fontFamily: 'Nrt',
                                            color: Colors.blue,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              );
                            },
                          );
                        },
                        onDismissed: (direction) {
                          _deleteDrugPermanently(drug); // Firestore deletion
                        },
                        child: Card(
                          margin:
                              EdgeInsets.symmetric(vertical: 4, horizontal: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                          color: Colors.white,
                          child: ListTile(
                            title: Text(
                              drug.name,
                              style: TextStyle(
                                color: Colors.black,
                                fontFamily: 'nrt',
                              ),
                            ),
                            subtitle: Text(
                              "Info: ${drug.otherInfo}\n"
                              "Side Effects: ${drug.sideEffect}\n"
                              "Usage: ${drug.usage}",
                              style: TextStyle(
                                color: Colors.black,
                                fontFamily: 'nrt',
                              ),
                            ),
                            trailing: IconButton(
                              icon: Icon(Icons.edit),
                              onPressed: () {
                                _editDrug(drug); // Edit functionality
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildButtonRow() {
    return ValueListenableBuilder<Color>(
      valueListenable: widget.buttonColorNotifier,
      builder: (context, buttonColor, child) {
        if (_isSending) {
          return Center(
            child: CircularProgressIndicator(),
          );
        }
        return Wrap(
          spacing: 8.0,
          runSpacing: 8.0,
          alignment: WrapAlignment.center,
          children: [
            SizedBox(
              width: 110,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: buttonColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: _editingDrug == null ? _addDrug : _updateDrug,
                child: Text(
                  _editingDrug == null ? 'زیادکردن' : 'تازەکردنەوە',
                  style: TextStyle(
                    fontSize: 18,
                    fontFamily: 'nrt',
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 110,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: buttonColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: _sendAllDrugsToFirebase,
                child: Text(
                  'ناردن',
                  style: TextStyle(
                    fontSize: 18,
                    fontFamily: 'nrt',
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 110,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: buttonColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () async {
                  bool? confirmDelete = await _confirmDeleteAll();
                  if (confirmDelete == true) {
                    _deleteAllDrugs();
                  }
                },
                child: Text(
                  'سڕینەوە',
                  style: TextStyle(
                    fontSize: 18,
                    fontFamily: 'nrt',
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  TextField _buildTextField(TextEditingController controller, String label,
      {int maxLines = 1}) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.0),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
      ),
      maxLines: maxLines,
      style: TextStyle(
        color: Colors.black,
        fontFamily: 'nrt',
      ),
      textDirection: TextDirection.rtl,
    );
  }

  void _performSearch() async {
    setState(() {
      _isSending = true;
    });

    final query = searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        filteredDrugs = drugs; // Show all drugs if search query is empty
        _isSending = false;
      });
      return;
    }

    try {
      // Correct method name: searchDrugsByName
      final List<Drug> searchResults =
          await _firestoreService.searchDrugsByName(query);
      setState(() {
        filteredDrugs = searchResults; // Update the UI with search results
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error searching drugs: $e')),
      );
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  void _addDrug() async {
    setState(() {
      _isSending = true;
    });

    try {
      // Create new drug entry
      final id = DateTime.now().millisecondsSinceEpoch.toString();
      Drug newDrug = Drug(
        id: id,
        name: nameController.text,
        otherInfo: infoController.text,
        sideEffect: sideEffectController.text,
        usage: usageController.text,
      );

      // Add to Firestore
      await _firestoreService.addDrug(newDrug);

      // Update local list
      setState(() {
        drugs.add(newDrug);
        filteredDrugs = List.from(drugs); // Update filtered list
      });

      // Save locally
      await _saveData();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('دەرمان بەسەرکەوتووی زیادکرا!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ناتوانرێ زیاد بکەیت: $e')),
      );
    } finally {
      setState(() {
        _isSending = false;
      });
      _clearTextFields(); // Clear the input fields after adding
    }
  }


  void _editDrug(Drug drug) {
    setState(() {
      _editingDrug = drug;
      nameController.text = drug.name;
      infoController.text = drug.otherInfo;
      sideEffectController.text = drug.sideEffect;
      usageController.text = drug.usage;
    });
  }

  void _updateDrug() async {
    if (_editingDrug != null) {
      setState(() {
        _isSending = true;
      });

      try {
        Drug updatedDrug = Drug(
          id: _editingDrug!.id,
          name: nameController.text,
          otherInfo: infoController.text,
          sideEffect: sideEffectController.text,
          usage: usageController.text,
        );

        await _firestoreService.updateDrug(
            updatedDrug.id, updatedDrug.toJson());

        int index = drugs.indexWhere((d) => d.id == _editingDrug!.id);
        if (index != -1) {
          setState(() {
            drugs[index] = updatedDrug;
            filteredDrugs = List.from(drugs);
          });
        }

        await _saveData();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('دەرمان بەسەرکەوتووی نوێکرایەوە!')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('دەرمان نوێ نەکرایەوە: $e')),
        );
      } finally {
        setState(() {
          _editingDrug = null;
          _isSending = false;
        });
        _clearTextFields();
      }
    }
  }

  void _deleteDrugPermanently(Drug drug) async {
    try {
      await _firestoreService.deleteDrugByContent(drug.toJson());

      setState(() {
        drugs.removeWhere((d) => d.id == drug.id);
        filteredDrugs.removeWhere((d) => d.id == drug.id);
      });

      await _saveData();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('دەرمان بەسەرکەوتووی سڕدرایەوە!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error during deletion: $e')),
      );
    }
  }

  void _sendAllDrugsToFirebase() async {
    if (drugs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('هیچ دەرمانیکت نەنوسیوە!')),
      );
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      for (var drug in drugs) {
        await _firestoreService.addDrugByDetails(
          id: drug.id,
          name: drug.name,
          otherInfo: drug.otherInfo,
          sideEffect: drug.sideEffect,
          usage: drug.usage,
        );
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('بەسەرکەوتووی هەمووی نێردرا')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending drugs: $e')),
      );
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  void _clearTextFields() {
    nameController.clear();
    infoController.clear();
    sideEffectController.clear();
    usageController.clear();
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> drugList =
        drugs.map((drug) => jsonEncode(drug.toJson())).toList();
    await prefs.setStringList('drug_list', drugList);
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? drugList = prefs.getStringList('drug_list');
    if (drugList != null) {
      setState(() {
        drugs =
            drugList.map((drug) => Drug.fromJson(jsonDecode(drug))).toList();
        filteredDrugs = List.from(drugs);
      });
    }
  }

  Future<bool?> _confirmDeleteAll() {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Center(
            child: Text(
              'دڵنیایت؟',
              style: TextStyle(
                fontFamily: 'Nrt',
                color: Colors.black,
              ),
            ),
          ),
          content: Text(
            'دەتەوێ هەموو دەرمانەکان بسڕیتەوە؟',
            style: TextStyle(
              fontFamily: 'Nrt',
              color: Colors.black,
            ),
            textAlign: TextAlign.right,
          ),
          actions: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(false);
                  },
                  child: Text(
                    'نەخێر',
                    style: TextStyle(
                      fontFamily: 'Nrt',
                      color: Colors.red,
                    ),
                  ),
                ),
                SizedBox(width: 8),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(true);
                  },
                  child: Text(
                    'بەڵێ',
                    style: TextStyle(
                      fontFamily: 'Nrt',
                      color: Colors.blue,
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  void _deleteAllDrugs() async {
    setState(() {
      drugs.clear();
      filteredDrugs.clear(); // Clear filtered list as well
    });
    await _saveData();
  }
}

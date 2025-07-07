import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

class AddBookPage extends StatefulWidget {
  final ValueNotifier<Color> themeColorNotifier;
  final ValueNotifier<Color> buttonColorNotifier;

  AddBookPage({
    required this.themeColorNotifier,
    required this.buttonColorNotifier,
  });

  @override
  _AddBookPageState createState() => _AddBookPageState();
}

class _AddBookPageState extends State<AddBookPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  File? _coverFile;
  File? _pdfFile;
  String? _coverUrl;
  String? _pdfUrl;
  String _selectedCategory = 'کتێبە کوردیەکان';

  final List<String> _categories = [
    'کتێبە ئینگلیزیەکان',
    'کتێبە عەرەبیەکان',
    'کتێبە کوردیەکان'
  ];

  Future<void> _pickFile(bool isCover) async {
    final result = await FilePicker.platform.pickFiles(
      type: isCover ? FileType.image : FileType.custom,
      allowedExtensions: isCover ? null : ['pdf'],
    );

    if (result != null) {
      final file = File(result.files.single.path!);
      if (isCover) {
        setState(() {
          _coverFile = file;
        });
      } else {
        setState(() {
          _pdfFile = file;
        });
      }
    }
  }

  Future<void> _uploadFile(File file, bool isCover) async {
    final fileName = file.path.split('/').last;
    final destination = isCover ? 'covers/$fileName' : 'pdfs/$fileName';

    try {
      final ref = FirebaseStorage.instance.ref(destination);
      final uploadTask = ref.putFile(file);

      final snapshot = await uploadTask.whenComplete(() => {});
      final downloadUrl = await snapshot.ref.getDownloadURL();

      setState(() {
        if (isCover) {
          _coverUrl = downloadUrl;
        } else {
          _pdfUrl = downloadUrl;
        }
      });
    } catch (e) {
      print('Error uploading file: $e');
    }
  }

  void _addBook() async {
    if (_formKey.currentState!.validate() &&
        _coverFile != null &&
        _pdfFile != null) {
      await _uploadFile(_coverFile!, true);
      await _uploadFile(_pdfFile!, false);

      FirebaseFirestore.instance.collection('books').add({
        'title': _titleController.text,
        'description': _descriptionController.text,
        'category': _selectedCategory,
        'coverUrl': _coverUrl,
        'downloadUrl': _pdfUrl,
        'addedAt': Timestamp.now(),
      }).then((_) {
        Navigator.pop(context);
      }).catchError((error) {
        print('Error adding book: $error');
      });
    }
  }

  Widget _buildDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedCategory,
      onChanged: (String? newValue) {
        setState(() {
          _selectedCategory = newValue!;
        });
      },
      items: _categories.map((String category) {
        return DropdownMenuItem<String>(
          value: category,
          child: Text(
            category,
            style: TextStyle(
              color: Colors.black,
              fontFamily: 'nrt',
            ),
          ),
        );
      }).toList(),
      decoration: InputDecoration(
        labelText: 'جۆری کتێب',
        labelStyle: TextStyle(
          color: Colors.black,
          fontFamily: 'nrt',
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.0),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'تکایە جۆری کتێب هەڵبژیرە';
        }
        return null;
      },
    );
  }

  Widget _buildButton(String text, VoidCallback onPressed) {
    return ValueListenableBuilder<Color>(
      valueListenable: widget.buttonColorNotifier,
      builder: (context, buttonColor, _) {
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 8.0),
          child: ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: buttonColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.0),
              ),
              padding: EdgeInsets.symmetric(vertical: 16.0),
            ),
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'nrt',
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Color>(
      valueListenable: widget.themeColorNotifier,
      builder: (context, themeColor, _) {
        return Scaffold(
          backgroundColor: const Color(0xFFF5F5F5),
          appBar: AppBar(
            title: Text(
              'زیادکردنی کتێبی نوێ',
              style: TextStyle(
                fontFamily: 'nrt',
                color: Colors.white,
              ),
            ),
            backgroundColor: themeColor,
            centerTitle: true,
          ),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: ListView(
                children: [
                  TextFormField(
                    controller: _titleController,
                    style: TextStyle(color: Colors.black),
                    decoration: InputDecoration(
                      labelText: 'ناوی کتێب',
                      labelStyle: TextStyle(
                        color: Colors.black,
                        fontFamily: 'nrt',
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'تکایە ناوی کتێبەکە بنووسە';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 8),
                  TextFormField(
                    controller: _descriptionController,
                    style: TextStyle(color: Colors.black),
                    decoration: InputDecoration(
                      labelText: 'زانیاری دەربارەی کتێب',
                      labelStyle: TextStyle(
                        color: Colors.black,
                        fontFamily: 'nrt',
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'تکایە زانیاری دەربارەی کتێبەکە بنوسە';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 8),
                  _buildDropdown(),
                  SizedBox(height: 16),
                  _buildButton('کەڤەری کتێب', () => _pickFile(true)),
                  _buildButton('بارکردنی فایلی PDF', () => _pickFile(false)),
                  _buildButton('زیادکردنی کتێب', _addBook),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

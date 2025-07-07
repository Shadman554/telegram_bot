import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'firestore_service.dart';
import 'wordlist.dart'; // Import Word from wordlist.dart

class AddDataPage extends StatefulWidget {
  final ValueNotifier<Color> themeColorNotifier;
  final ValueNotifier<Color> buttonColorNotifier;

  AddDataPage({
    required this.themeColorNotifier,
    required this.buttonColorNotifier,
  });

  @override
  _AddDataPageState createState() => _AddDataPageState();
}

class _AddDataPageState extends State<AddDataPage> {
  TextEditingController nameController = TextEditingController();
  TextEditingController kurdishController = TextEditingController();
  TextEditingController arabicController = TextEditingController();
  TextEditingController descriptionController = TextEditingController();
  TextEditingController searchController = TextEditingController(); // Search

  List<Word> words = [];
  List<Word> filteredWords = []; // Filtered list for search results
  final FirestoreService _firestoreService = FirestoreService();
  bool _isSending = false;
  Word? _editingWord; // For edit functionality

  @override
  void initState() {
    super.initState();
    _loadData();
    filteredWords = List.from(words); // Initialize filtered list
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Color>(
      valueListenable: widget.themeColorNotifier,
      builder: (context, themeColor, child) {
        return Scaffold(
          appBar: AppBar(
            title: Text(
              _editingWord == null ? 'زیادکردنی وشەی نوێ' : 'دەستکاریکردنی وشە',
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
                        _buildTextField(nameController, 'ناو'),
                        SizedBox(height: 8),
                        _buildTextField(kurdishController, 'کوردی'),
                        SizedBox(height: 8),
                        _buildTextField(arabicController, 'عەرەبی'),
                        SizedBox(height: 8),
                        _buildTextField(descriptionController, 'پێناسە',
                            maxLines: 3),
                        SizedBox(height: 16),
                        Center(child: _buildButtonRow()), // Button row
                        SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                  searchController, 'گەڕان بۆ وشە',
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
                    itemCount: filteredWords.length,
                    itemBuilder: (context, index) {
                      final word = filteredWords[index];
                      return Dismissible(
                        key: Key(word.id),
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
                                  'دەتەویت ئەم وشەیە بسڕیتەوە؟',
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
                          _deleteWordPermanently(word); // Firestore deletion
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
                              word.name,
                              style: TextStyle(
                                color: Colors.black,
                                fontFamily: 'nrt',
                              ),
                            ),
                            subtitle: Text(
                              "Kurdish: ${word.kurdish}\n"
                              "Arabic: ${word.arabic}\n"
                              "Description: ${word.description}",
                              style: TextStyle(
                                color: Colors.black,
                                fontFamily: 'nrt',
                              ),
                            ),
                            trailing: IconButton(
                              icon: Icon(Icons.edit),
                              onPressed: () {
                                _editWord(word); // Edit functionality
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
                onPressed: _editingWord == null ? _addWord : _updateWord,
                child: Text(
                  _editingWord == null ? 'زیادکردن' : 'تازەکردنەوە',
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
                onPressed: _sendAllWordsToFirebase,
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
                    _deleteAllWords();
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
        filteredWords = words; // Show all words if search query is empty
        _isSending = false;
      });
      return;
    }

    try {
      final List<Word> searchResults =
          await _firestoreService.searchWords(query);
      setState(() {
        filteredWords = searchResults;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error searching words: $e')),
      );
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  void _addWord() async {
    setState(() {
      _isSending = true;
    });

    try {
      // Create new word entry
      final id = DateTime.now().millisecondsSinceEpoch.toString();
      Word newWord = Word(
        id: id,
        name: nameController.text,
        kurdish: kurdishController.text,
        arabic: arabicController.text,
        description: descriptionController.text,
      );

      // Add to Firestore
      await _firestoreService.addWord(newWord);

      // Update local list
      setState(() {
        words.add(newWord);
        filteredWords = List.from(words); // Update filtered list
      });

      // Save locally
      await _saveData();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('وشە بەسەرکەوتووی زیادکرا!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ناتوانرێ زیاد بکەیت: $e')),
      );
    } finally {
      setState(() {
        _isSending = false;
      });
      _clearTextFields(); // Clear input fields after adding
    }
  }

void _editWord(Word word) {
    setState(() {
      _editingWord = word; // Ensure the correct word with its ID is being used
      nameController.text = word.name;
      kurdishController.text = word.kurdish;
      arabicController.text = word.arabic;
      descriptionController.text = word.description;
    });
  }


 void _updateWord() async {
    if (_editingWord != null && _editingWord!.id.isNotEmpty) {
      // Ensure the word has an ID
      setState(() {
        _isSending = true;
      });

      try {
        // Use the existing document ID from Firestore
        Word updatedWord = Word(
          id: _editingWord!.id, // Use the ID from the word being edited
          name: nameController.text,
          kurdish: kurdishController.text,
          arabic: arabicController.text,
          description: descriptionController.text,
        );

        // Update the word in Firestore using the correct document ID
        await _firestoreService.updateWord(
            updatedWord.id, updatedWord.toJson());

        // Update the word in the local list
        int index = words.indexWhere((w) => w.id == _editingWord!.id);
        if (index != -1) {
          setState(() {
            words[index] = updatedWord;
            filteredWords = List.from(words); // Update filtered list
          });
        }

        await _saveData(); // Save the updated data locally

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('وشە بەسەرکەوتووی نوێکرایەوە!')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating word: $e')),
        );
      } finally {
        setState(() {
          _editingWord = null;
          _isSending = false;
        });
        _clearTextFields(); // Clear the fields after updating
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: Document ID is missing')),
      );
    }
  }


  void _deleteWordPermanently(Word word) async {
    try {
      await _firestoreService.deleteWordByContent(word.toJson());

      setState(() {
        words.removeWhere((w) => w.id == word.id);
        filteredWords.removeWhere((w) => w.id == word.id);
      });

      await _saveData();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('وشە بەسەرکەوتووی سڕدرایەوە!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting word: $e')),
      );
    }
  }

  void _sendAllWordsToFirebase() async {
    if (words.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('هیچ وشەیەکت نەنوسیوە!')),
      );
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      for (var word in words) {
        await _firestoreService.addWord(word);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('بەسەرکەوتووی هەمووی نێردرا')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending words: $e')),
      );
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  void _clearTextFields() {
    nameController.clear();
    kurdishController.clear();
    arabicController.clear();
    descriptionController.clear();
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> wordList =
        words.map((word) => jsonEncode(word.toJson())).toList();
    await prefs.setStringList('word_list', wordList);
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? wordList = prefs.getStringList('word_list');
    if (wordList != null) {
      setState(() {
        words =
            wordList.map((word) => Word.fromJson(jsonDecode(word))).toList();
        filteredWords = List.from(words);
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
            'دەتەوێ هەموو وشەکان بسریتەوە؟',
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

  void _deleteAllWords() async {
    setState(() {
      words.clear();
      filteredWords.clear(); // Clear filtered list as well
    });
    await _saveData();
  }
}

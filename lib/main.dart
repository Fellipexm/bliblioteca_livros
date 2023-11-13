import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

void main() {
  runApp(MyApp());
}

class Book {
  final int id;
  final String title;
  final String author;
  final int rating;

  Book({
    required this.id,
    required this.title,
    required this.author,
    required this.rating,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'rating': rating,
    };
  }

  factory Book.fromMap(Map<String, dynamic> map) {
    return Book(
      id: map['id'],
      title: map['title'],
      author: map['author'],
      rating: map['rating'],
    );
  }
}

class DatabaseHelper {
  late Database _database;

  Future<void> initDatabase() async {
    _database = await openDatabase(
      join(await getDatabasesPath(), 'books_database.db'),
      onCreate: (db, version) {
        return db.execute(
          '''
          CREATE TABLE books(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT,
            author TEXT,
            rating INTEGER
          )
          ''',
        );
      },
      version: 1,
    );
  }

  Future<void> insertBook(Book book) async {
    await _database.insert(
      'books',
      book.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Book>> getBooks({String? query}) async {
    final List<Map<String, dynamic>> maps = await _database.query(
      'books',
      where: query != null ? 'title LIKE ?' : null,
      whereArgs: query != null ? ['%$query%'] : null,
    );
    return List.generate(
      maps.length,
      (i) {
        return Book.fromMap(maps[i]);
      },
    );
  }

  Future<void> deleteBook(int id) async {
    await _database.delete(
      'books',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Biblioteca App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.grey[200],
      ),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  TextEditingController titleController = TextEditingController();
  TextEditingController authorController = TextEditingController();
  int? selectedRating;

  late DatabaseHelper databaseHelper;

  @override
  void initState() {
    super.initState();
    databaseHelper = DatabaseHelper();
    _initDatabase();
  }

  Future<void> _initDatabase() async {
    await databaseHelper.initDatabase();
    // Load books if needed
  }

  void addBook() async {
    String title = titleController.text;
    String author = authorController.text;

    if (title.isNotEmpty && author.isNotEmpty && selectedRating != null) {
      Book newBook = Book(
        id: DateTime.now().millisecondsSinceEpoch,
        title: title,
        author: author,
        rating: selectedRating!,
      );
      await databaseHelper.insertBook(newBook);
      _resetFields();
    }
  }

  void _resetFields() {
    titleController.clear();
    authorController.clear();
    selectedRating = null;
  }

  void viewSavedBooks(BuildContext context) async {
    List<Book> savedBooks = await databaseHelper.getBooks();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SavedBooksScreen(savedBooks),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('               Sistema Bibliotecário'),
      ), 
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              TextField(
                controller: titleController,
                decoration: InputDecoration(labelText: 'Título do Livro'),
              ),
              SizedBox(height: 8),
              TextField(
                controller: authorController,
                decoration: InputDecoration(labelText: 'Autor do Livro'),
              ),
              SizedBox(height: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Classificação: '),
                  for (int i = 0; i <= 5; i++)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Radio<int>(
                              value: i,
                              groupValue: selectedRating,
                              onChanged: (value) {
                                setState(() {
                                  selectedRating = value;
                                });
                              },
                            ),
                            Text('$i'),
                          ],
                        ),
                      ],
                    ),
                ],
              ),
              SizedBox(height: 8),
              ElevatedButton(
                onPressed: addBook,
                style: ElevatedButton.styleFrom(
                  primary: Colors.green,
                ),
                child: Text('Adicionar Livro'),
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => viewSavedBooks(context),
                style: ElevatedButton.styleFrom(
                  primary: Colors.blue,
                ),
                child: Text('Ver Livros Salvos'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SavedBooksScreen extends StatefulWidget {
  final List<Book> savedBooks;

  SavedBooksScreen(this.savedBooks);

  @override
  _SavedBooksScreenState createState() => _SavedBooksScreenState();
}

class _SavedBooksScreenState extends State<SavedBooksScreen> {
  TextEditingController searchController = TextEditingController();
  List<Book> filteredBooks = [];

  @override
  void initState() {
    filteredBooks = widget.savedBooks;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Livros Salvos'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                labelText: 'Pesquisar Livros',
                prefixIcon: Icon(Icons.search, size: 20),
              ),
              onChanged: (query) {
                setState(() {
                  filteredBooks = widget.savedBooks
                      .where((book) =>
                          book.title.toLowerCase().contains(query.toLowerCase()) ||
                          book.author.toLowerCase().contains(query.toLowerCase()))
                      .toList();
                });
              },
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: filteredBooks.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(filteredBooks[index].title),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Autor: ${filteredBooks[index].author}'),
                      Text('Classificação: ${filteredBooks[index].rating}'),
                    ],
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            BookDetailScreen(filteredBooks[index]),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class BookDetailScreen extends StatelessWidget {
  final Book book;

  BookDetailScreen(this.book);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Detalhes do Livro'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Título: ${book.title}',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Autor: ${book.author}',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              'Classificação: ${book.rating}',
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}

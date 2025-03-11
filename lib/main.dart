import 'package:english_words/english_words.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => MyAppState(), // register the state
      child: MaterialApp(
        title: 'Awsome Word App',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        ),
        home: MyHomePage(),
      ),
    );
  }
}

// define the state
class MyAppState extends ChangeNotifier {
  WordPair current = WordPair.random();
  var favorites = <WordPair>[];
  late Database _database;
  bool _isDatabaseInitialized = false;
  
  // Add a history list to track previous word pairs
  var history = <WordPair>[];
  int historyIndex = -1;  // Track current position in history

  // Constructor to initialize database and load favorites
  MyAppState() {
    _initDatabase();
    // Add the initial random word pair to history
    _addToHistory(current);
  }

  // Initialize the database
  Future<void> _initDatabase() async {
    // Avoid database initialization if it's already done
    if (_isDatabaseInitialized) return;
    
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'word_app.db');

    _database = await openDatabase(
      path,
      version: 1,
      onCreate: (Database db, int version) async {
        await db.execute(
          'CREATE TABLE favorites(id INTEGER PRIMARY KEY, first TEXT, second TEXT)',
        );
      },
    );
    
    _isDatabaseInitialized = true;
    await loadFavorites();
  }

  void getNext() {
    // Only generate a new word pair if at the end of history
    if (historyIndex >= history.length - 1) {
      current = WordPair.random();
      _addToHistory(current);
    } else {
      // Otherwise, move forward in history
      historyIndex++;
      current = history[historyIndex];
    }
    notifyListeners();
  }
  
  // Add a method to go back to the previous word pair
  void getPrevious() {
    // Make sure we have history to go back to
    if (historyIndex > 0) {
      historyIndex--;
      current = history[historyIndex];
      notifyListeners();
    }
  }
  
  // Helper method to add a word pair to history
  void _addToHistory(WordPair pair) {
    // If we're not at the end of history, truncate forward history
    if (historyIndex < history.length - 1) {
      history = history.sublist(0, historyIndex + 1);
    }
    
    // Add the current pair to history
    history.add(pair);
    historyIndex = history.length - 1;
  }

  void toggleFavorite() {
    if (favorites.contains(current)) {
      favorites.remove(current);
      _deleteFavorite(current);
    } else {
      favorites.add(current);
      _saveFavorite(current);
    }
    notifyListeners();
  }

  // Save a favorite to the database
  Future<void> _saveFavorite(WordPair pair) async {
    if (!_isDatabaseInitialized) await _initDatabase();
    
    await _database.insert(
      'favorites',
      {
        'first': pair.first,
        'second': pair.second,
      },
    );
  }

  // Delete a favorite from the database
  Future<void> _deleteFavorite(WordPair pair) async {
    if (!_isDatabaseInitialized) await _initDatabase();
    
    await _database.delete(
      'favorites',
      where: 'first = ? AND second = ?',
      whereArgs: [pair.first, pair.second],
    );
  }

  // Load favorites from the database
  Future<void> loadFavorites() async {
    if (!_isDatabaseInitialized) await _initDatabase();
    
    final List<Map<String, dynamic>> maps = await _database.query('favorites');
    
    favorites = List.generate(maps.length, (i) {
      return WordPair(
        maps[i]['first'],
        maps[i]['second'],
      );
    });
    
    notifyListeners();
  }
}

class MyHomePage extends StatefulWidget {
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  var selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    Widget page;
    switch (selectedIndex) {
      case 0:
        page = GeneratorPage();
        break;
      case 1:
        page = FavoritesPage();
        break;
      default:
        throw UnimplementedError('no widget for $selectedIndex');
    }

    return LayoutBuilder(
      builder: (context, constrants) {
        return Scaffold(
          body: Row(
            children: [
              SafeArea(
                child: NavigationRail(
                  extended: constrants.maxWidth > 600,
                  destinations: [
                    NavigationRailDestination(
                      icon: Icon(Icons.home),
                      label: Text('Home'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.favorite),
                      label: Text('Favorites'),
                    ),
                  ],
                  selectedIndex: selectedIndex,
                  onDestinationSelected: (value) {
                    setState(() {
                      selectedIndex = value;
                    });
                  },
                ),
              ),
              Expanded(
                child: Container(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: page,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class GeneratorPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>(); // use the state
    var pair = appState.current; // read the property from the state

    IconData icon;
    if (appState.favorites.contains(pair)) {
      icon = Icons.favorite;
    } else {
      icon = Icons.favorite_border;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          BigCard(pair: pair),
          SizedBox(height: 10),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  appState.toggleFavorite(); // update the state
                },
                icon: Icon(icon),
                label: Text('Like'),
              ),
              SizedBox(width: 10),
              // Add Previous button
              ElevatedButton(
                onPressed: appState.historyIndex > 0 
                  ? () {
                      appState.getPrevious(); // go to previous word pair
                    }
                  : null, // Disable button if no history to go back to
                child: Text('Previous'),
              ),
              SizedBox(width: 10),
              ElevatedButton(
                onPressed: () {
                  appState.getNext(); // update the state
                },
                child: Text('Next'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class BigCard extends StatelessWidget {
  const BigCard({super.key, required this.pair});

  final WordPair pair;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.displayMedium!.copyWith(
      color: theme.colorScheme.onPrimary,
    );

    return Card(
      elevation: 3,
      color: theme.colorScheme.primary,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Text(
          pair.asPascalCase,
          style: style,
          semanticsLabel: "${pair.first} ${pair.second}",
        ),
      ),
    );
  }
}

class FavoritesPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();

    if (appState.favorites.isEmpty) {
      return Center(child: Text('No favorites yet.'));
    }

    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            'You have '
            '${appState.favorites.length} favorites:',
          ),
        ),
        for (var pair in appState.favorites)
          ListTile(
            leading: Icon(Icons.favorite),
            title: Text(pair.asLowerCase),
          ),
      ],
    );
  }
}

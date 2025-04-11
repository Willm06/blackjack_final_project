import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
// import 'package:flutter/services.dart' show rootBundle;
// import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:playing_cards/playing_cards.dart';

void main() {
  createAppFolder();
  runApp(const MaterialApp(title: 'Navigation Basics', home: MyApp()));
}

Future<void> createAppFolder() async {
  Directory? documentsDirectory = await getApplicationDocumentsDirectory();
  String appFolderPath = '${documentsDirectory.path}/BlackjackFlutterApp';

  //creates an app
  Directory appFolder = Directory(appFolderPath);
  if (!appFolder.existsSync()) {
    appFolder.createSync(recursive: true);
    print("App folder created at: $appFolderPath");
  }

  // Define file paths
  String jsonFilePath = '$appFolderPath/player_data.json';

  // Copy contents from assets if they don't exist in the app folder
  File appJsonFile = File(jsonFilePath);

  // Check if the JSON file exists in the application folder
  if (!appJsonFile.existsSync()) {
    File assetJsonFile = File('assets/player_data.json');
    if (assetJsonFile.existsSync()) {
      appJsonFile.writeAsStringSync(assetJsonFile.readAsStringSync());
      print("JSON file copied to: $jsonFilePath");
    } else {
      print("Asset JSON file not found.");
    }
  } else {
    print("JSON file already exists at: $jsonFilePath");
  }
}

class PlayerData {
  String name;
  double balance;
  int wins;
  int matchesPlayed;

  PlayerData({
    required this.name,
    required this.balance,
    required this.wins,
    required this.matchesPlayed,
  });

  factory PlayerData.fromJson(Map<String, dynamic> json) {
    return PlayerData(
      name: json['name'],
      balance: json['balance'],
      wins: json['wins'],
      matchesPlayed: json['matches_played'],
    );
  }
}

Future<PlayerData> loadStudentData() async {
  Directory? documentsDirectory = await getApplicationDocumentsDirectory();
  String appFolderPath = '${documentsDirectory.path}/BlackjackFlutterApp';
  String jsonFilePath = '$appFolderPath/player_data.json';

  try {
    final file = File(jsonFilePath);
    final String response = await file.readAsString();
    final data = jsonDecode(response);
    return PlayerData.fromJson(data);
  } catch (e) {
    //throw errow if that somehow fails
    debugPrint("Error loading student data: $e");
    throw Exception("Failed to load student data.");
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        textTheme: TextTheme(
          bodyLarge: const TextStyle(color: Colors.black, fontSize: 18),
          bodyMedium: TextStyle(color: Colors.grey[600], fontSize: 16),
        ),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  _HomePageState createState() => _HomePageState();
}

Future<PlayerData>? futureStudentData;

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void updateStudentData(Future<PlayerData> newData) {
    setState(() {
      futureStudentData = newData.catchError((error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error loading student data: $error")),
        );
        return loadStudentData(); // Revert to default data if loading fails
      });
    });
  }

  @override
  void initState() {
    super.initState();
    futureStudentData = loadStudentData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<PlayerData>(
        future: futureStudentData,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return const Center(child: Text("Error loading data"));
          } else if (snapshot.hasData) {
            final List<Widget> pages = [
              //loading default values from the json into the widgets
              HomePageContent(
                name: snapshot.data!.name,
                balance: snapshot.data!.balance,
                wins: snapshot.data!.wins,
                matchesPlayed: snapshot.data!.matchesPlayed,
              ),
              GameScreen(
                name: snapshot.data!.name,
                balance: snapshot.data!.balance,
                wins: snapshot.data!.wins,
                matchesPlayed: snapshot.data!.matchesPlayed,
                onStudentDataUpdated: updateStudentData,
              ),
              RuleScreen(),
            ];
            return pages[_selectedIndex];
          } else {
            return const Center(child: Text("No data available"));
          }
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment_ind),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month),
            label: 'Game',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.class_rounded),
            label: 'Rules',
          ),
        ],
      ),
    );
  }
}

class HomePageContent extends StatefulWidget {
  const HomePageContent({
    super.key,
    required this.name,
    required this.balance,
    required this.wins,
    required this.matchesPlayed,
  });

  final String name;
  final double balance;
  final int wins;
  final int matchesPlayed;

  @override
  _HomePageContentState createState() => _HomePageContentState();
}

class _HomePageContentState extends State<HomePageContent> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text('Home')));
  }
}

class GameScreen extends StatefulWidget {
  static const routeName = '/gameScreen';
  const GameScreen({
    super.key,
    required this.name,
    required this.balance,
    required this.wins,
    required this.matchesPlayed,
    required this.onStudentDataUpdated,
  });

  final String name;
  final double balance;
  final int wins;
  final int matchesPlayed;
  final Function(Future<PlayerData>) onStudentDataUpdated;

  @override
  _GameScreenState createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  // This style object overrides the styles for the suits, replacing the
  // image-based default implementation for the suit emblems with a text based
  // implementation.

  PlayingCardViewStyle myCardStyles = PlayingCardViewStyle(
    suitStyles: {
      Suit.spades: SuitStyle(
        builder:
            (context) => const FittedBox(
              fit: BoxFit.fitHeight,
              child: Text("♠", style: TextStyle(fontSize: 500)),
            ),
        style: TextStyle(color: Colors.grey[800]),
      ),
      Suit.hearts: SuitStyle(
        builder:
            (context) => const FittedBox(
              fit: BoxFit.fitHeight,
              child: Text(
                "♥",
                style: TextStyle(fontSize: 500, color: Colors.red),
              ),
            ),
        style: const TextStyle(color: Colors.red),
      ),
      Suit.diamonds: SuitStyle(
        builder:
            (context) => const FittedBox(
              fit: BoxFit.fitHeight,
              child: Text(
                "♦",
                style: TextStyle(fontSize: 500, color: Colors.red),
              ),
            ),
        style: const TextStyle(color: Colors.red),
      ),
      Suit.clubs: SuitStyle(
        builder:
            (context) => const FittedBox(
              fit: BoxFit.fitHeight,
              child: Text("♣", style: TextStyle(fontSize: 500)),
            ),
        style: TextStyle(color: Colors.grey[800]),
      ),
      Suit.joker: SuitStyle(builder: (context) => Container()),
    },
  );

  PlayingCard playingCard(int cardNumber) {
    const List<CardValue> values = [
      CardValue.king,
      CardValue.ace,
      CardValue.two,
      CardValue.three,
      CardValue.four,
      CardValue.five,
      CardValue.six,
      CardValue.seven,
      CardValue.eight,
      CardValue.nine,
      CardValue.ten,
      CardValue.jack,
      CardValue.queen,
    ];

    const List<Suit> suits = [
      Suit.spades,
      Suit.hearts,
      Suit.clubs,
      Suit.diamonds,
    ];

    CardValue value = values[cardNumber % 13];
    Suit suit = suits[(cardNumber - 1) ~/ 13];

    return PlayingCard(suit, value);
  }

  List<int> deck = [];
  List<int> playerCards = [];
  List<int> dealerCards = [];
  bool playerBust = false;
  bool dealerBust = false;

  // Shuffle multiple standard decks together
  List<int> shuffleDeck(int numStanDecks) {
    List<int> newDeck = [];
    for (int k = 0; k < numStanDecks; k++) {
      newDeck += List.generate(52, (index) => index + 1);
    }
    newDeck.shuffle();
    return newDeck;
  }

  // Calculate the hand value, treating Aces as 1 or 11
  int handValueCheck(List<int> hand) {
    int value = 0;
    int aces = 0;

    for (int card in hand) {
      int rank = (card - 1) % 13 + 1;
      if (rank > 10) {
        value += 10;
      } else if (rank == 1) {
        aces += 1;
        value += 11; // count aces as 11 for now
      } else {
        value += rank;
      }
    }

    // Adjust for aces if value > 21
    while (value > 21 && aces > 0) {
      value -= 10;
      aces--;
    }

    return value;
  }

  // Draw a card for either player or dealer
  void drawCard(List<int> hand, bool isPlayer) {
    if (deck.isEmpty) return;

    int number = deck.removeLast();
    hand.add(number);

    int currentHandValue = handValueCheck(hand);

    if (currentHandValue > 21) {
      print(isPlayer ? 'Player busts' : 'Dealer busts');
      if (isPlayer) {
        playerBust = true;
      } else {
        dealerBust = true;
      }
    } else if (currentHandValue == 21) {
      print(isPlayer ? 'Player hits blackjack' : 'Dealer hits blackjack');
    }
  }

  // Game setup
  void gameStart() {
    // Reset all game state
  deck = shuffleDeck(2); // or whatever number of decks you want
  playerCards.clear();
  dealerCards.clear();
  playerBust = false;
  dealerBust = false;

  // Initial card draw
  drawCard(playerCards, true);
  drawCard(dealerCards, false);
  drawCard(playerCards, true);
  drawCard(dealerCards, false);
  
  print("Game started!");
  }

  // Player chooses to hit
  void playerHit() {
    drawCard(playerCards, true);
  }

  // Player chooses to stand
  void playerStand() {
    // Dealer draws until 17 or higher
    while (handValueCheck(dealerCards) < 17 && !dealerBust) {
      drawCard(dealerCards, false);
    }

    int dealerValue = handValueCheck(dealerCards);
    int playerValue = handValueCheck(playerCards);

    if (playerBust) {
      print("Dealer wins (Player busted)");
    } else if (dealerBust) {
      print("Player wins (Dealer busted)");
    } else if (dealerValue > playerValue) {
      print("Dealer wins");
    } else if (dealerValue < playerValue) {
      print("Player wins");
    } else {
      print("Push (tie)");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Row(
            children: [
              Text("zuh"),
              PlayingCardView(card: playingCard(1), style: myCardStyles),
              PlayingCardView(card: playingCard(13), style: myCardStyles),
            ],
          ),
          Column(
            children: [
              ElevatedButton(
                onPressed: gameStart,
                child: const Text('Start Game!!'),
              ),
              ElevatedButton(onPressed: playerHit, child: const Text('Hit')),
              ElevatedButton(
                onPressed: playerStand,
                child: const Text('Stand'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class RuleScreen extends StatelessWidget {
  static const routeName = '/ruleScreen';
  const RuleScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Third Page')),
      body: Center(
        child: Column(
          children: <Widget>[
            const Text("RULES PAGE"),
            const Text(""),
            const Text(
              "GOAL: Try to get as close as possible to 21 by drawing cards or making the dealer bust!",
            ),
            const Text(""),
            const Text(
              "You may 'HIT' to draw a random card from the deck, faces are worth 10 and aces are worth 11 or 1!",
            ),
            const Text(""),
            const Text(
              "If you draw a card and are now worth over 21, you bust and lose",
            ),
            const Text(""),
            const Text(
              "The dealer MUST draw a card if they are 'soft' 17 or below 17 meaning they can also bust",
            ),
            const Text(""),
            const Text(
              "You may also stand meaning your turn will pass and you will not draw a card and it will pass to the dealer",
            ),
            const Text(""),
            const Text(
              "After you and the dealer are both finished, whoever has a higher score will win",
            ),
            const Text(""),
          ],
        ),
      ),
    );
  }
}

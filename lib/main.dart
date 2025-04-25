import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
// import 'package:flutter/services.dart' show rootBundle;
// import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:playing_cards/playing_cards.dart';
//audio
//import 'package:just_audio/just_audio.dart';

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
    debugPrint("App folder created at: $appFolderPath");
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
      debugPrint("JSON file copied to: $jsonFilePath");
    } else {
      debugPrint("Asset JSON file not found.");
    }
  } else {
    debugPrint("JSON file already exists at: $jsonFilePath");
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

Future<void> writeToJson(String nameOfDataValToWrite, dynamic value) async {
  try {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String appFolderPath = '${documentsDirectory.path}/BlackjackFlutterApp';
    String jsonFilePath = '$appFolderPath/player_data.json';

    final file = File(jsonFilePath);

    if (!file.existsSync()) {
      throw Exception("JSON file does not exist at path: $jsonFilePath");
    }

    // Load existing data
    String contents = await file.readAsString();
    Map<String, dynamic> jsonData = jsonDecode(contents);

    // Update the specified key with the new value
    jsonData[nameOfDataValToWrite] = value;

    // Write updated JSON back to file
    await file.writeAsString(jsonEncode(jsonData), flush: true);
    debugPrint("Updated $nameOfDataValToWrite in JSON file.");
  } catch (e) {
    debugPrint("Error writing to JSON file: $e");
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
  //late AudioPlayer _audioPlayer;

  void _onItemTapped(int index) {
    setState(() {
      futureStudentData = loadStudentData();
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

  //audio not working
  /* 
  Future<void> _playBackgroundAudio() async {
  _audioPlayer = AudioPlayer();

  try {
    debugPrint("Setting loop mode...");
    await _audioPlayer.setLoopMode(LoopMode.all);

    debugPrint("Delaying audio load slightly...");
    await Future.delayed(const Duration(milliseconds: 100));

    debugPrint("Loading audio asset...");
    await _audioPlayer.setAsset('assets/audio/giornos_theme.mp3');
    debugPrint("Audio loaded successfully!");

    debugPrint("Starting playback...");
    await _audioPlayer.play();
    debugPrint("Audio playback started.");
  } on PlayerException catch (e) {
    debugPrint("PlayerException: ${e.message}");
    debugPrint("PlayerException code: ${e.code}");
  } on PlayerInterruptedException catch (e) {
    debugPrint("Playback was interrupted: ${e.message}");
  } catch (e) {
    debugPrint("Unexpected error during audio playback: $e");
  }
}
*/

  @override
  void initState() {
    super.initState();
    futureStudentData = loadStudentData();
    //_playBackgroundAudio();
  }

  //audio
  /*
  @override
void dispose() {
  _audioPlayer.dispose();
  super.dispose();
}
*/
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
            icon: Icon(Icons.credit_card_sharp),
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
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final TextEditingController _controller = TextEditingController();
  double? _betValue;
  late double _currentBalance;
  late int _currentWins;
  late int _currentMatchesPlayed;

  List<int> deck = [];
  List<int> playerCards = [];
  List<int> playerSplitHand = [];
  List<int> dealerCards = [];
  bool playerBust = false;
  bool dealerBust = false;
  bool cardNotShown = true;

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

  @override
  void initState() {
    super.initState();
    deck = shuffleDeck(1);
    _currentBalance = widget.balance;
    _currentWins = widget.wins;
    _currentMatchesPlayed = widget.matchesPlayed;
    _controller.addListener(() {
      setState(() {
        _betValue = double.tryParse(_controller.text);
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  PlayingCard playingCard(int cardNumber) {
    const List<CardValue> values = [
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
      CardValue.king,
    ];
    const List<Suit> suits = [
      Suit.spades,
      Suit.hearts,
      Suit.clubs,
      Suit.diamonds,
    ];
    return PlayingCard(
      suits[(cardNumber - 1) ~/ 13],
      values[(cardNumber - 1) % 13],
    );
  }

  List<int> shuffleDeck(int decks) {
    List<int> newDeck = [];
    for (int i = 0; i < decks; i++) {
      newDeck.addAll(List.generate(52, (i) => i + 1));
    }
    newDeck.shuffle();
    return newDeck;
  }

  int handValue(List<int> hand) {
    int total = 0;
    int aces = 0;
    for (int card in hand) {
      int rank = (card - 1) % 13 + 1;
      if (rank == 1) {
        total += 11;
        aces++;
      } else if (rank >= 11) {
        total += 10;
      } else {
        total += rank;
      }
    }
    while (total > 21 && aces > 0) {
      total -= 10;
      aces--;
    }
    return total;
  }

  void drawCard(List<int> hand, {required bool isPlayer}) {
    setState(() {
      if (deck.isEmpty) {
        deck = shuffleDeck(1);
        if (playerCards.isNotEmpty) {
          for (int i = 0; i < playerCards.length; i++) {
            deck.remove(playerCards[i]);
          }
        }
        if (dealerCards.isNotEmpty) {
          for (int i = 0; i < dealerCards.length; i++) {
            deck.remove(dealerCards[i]);
          }
        }
      }
      hand.add(deck.removeLast());
      if (handValue(hand) > 21) {
        if (isPlayer) {
          playerBust = true;
          playerStand();
        } else {
          dealerBust = true;
        }
      } else if (handValue(hand) == 21 && isPlayer) {
        playerStand();
      }
    });
  }

  void gameStart() {
    if (_betValue == null || _betValue! <= 0) return;

    setState(() {
      if (playerSplitHand.isNotEmpty) {
        playerCards = playerSplitHand;
        playerSplitHand = [];
      } else {
        playerCards = [];
        drawCard(playerCards, isPlayer: true);
      }
      drawCard(playerCards, isPlayer: true);

      dealerCards = [];
      drawCard(dealerCards, isPlayer: false);
      drawCard(dealerCards, isPlayer: false);

      playerBust = false;
      dealerBust = false;
      cardNotShown = true;
    });
  }

  void playerHit() {
    drawCard(playerCards, isPlayer: true);
  }

  void playerStand() async {
    setState(() {
      cardNotShown = false;
    });
    final playerValue = handValue(playerCards);
    if (!playerBust && !(playerValue == 21)) {
      while (handValue(dealerCards) < 17) {
        drawCard(dealerCards, isPlayer: false);
      }
    }
    final dealerValue = handValue(dealerCards);
    String result;
    if (playerBust) {
      result = 'You busted, Dealer wins';
      _currentBalance -= _betValue!;
      await writeToJson('balance', _currentBalance);
    } else if (dealerBust || playerValue > dealerValue) {
      result = 'You win!';
      _currentBalance += _betValue!;
      _currentWins++;
      await writeToJson('balance', _currentBalance);
      await writeToJson('wins', _currentWins);
    } else if (dealerValue > playerValue) {
      result = 'Dealer wins';
      _currentBalance -= _betValue!;
      await writeToJson('balance', _currentBalance);
    } else {
      result = 'Push';
    }
    _currentMatchesPlayed++;
    await writeToJson('matches_played', _currentMatchesPlayed);

    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Game Result'),
            content: Text(result),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context, rootNavigator: true).pop();
                  setState(() {
                    playerCards = [];
                  });
                },
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  bool validForSplit() {
    if (playerCards.length == 2) {
      int firstCard = (playerCards[0] - 1) % 13;
      int secondCard = (playerCards[1] - 1) % 13;
      if (firstCard == secondCard) {
        return true;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cards must be the same value to split.')),
        );
        return false;
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You can only split with two cards.')),
      );
      return false;
    }
  }

  void split() {
    if (validForSplit()) {
      playerSplitHand.add(playerCards[1]);
      playerCards.removeAt(1);
      drawCard(playerCards, isPlayer: true);
    }
  }

  void doubleDown() {
    if (_betValue! * 2 <= _currentBalance) {
      _betValue = _betValue! * 2;
      playerHit();
      if (playerBust == false) {
        playerStand();
      }
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Insufficient balance.')));
    }
  }

  void placeBet() {
    final bet = double.tryParse(_controller.text);

    if (bet == null || bet <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter a valid bet.')));
      return;
    }

    if (bet > _currentBalance) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Insufficient balance.')));
      return;
    }

    setState(() {
      _betValue = bet;
    });

    gameStart();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Blackjack')),
      body: SizedBox.expand(
        // Ensures full-screen height/width
        child: Stack(
          children: [
            // Full-screen background image
            Positioned.fill(
              child: Image.asset(
                "assets/backgroundSWAG.jpg",
                fit: BoxFit.cover,
              ),
            ),
            // Foreground content
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome, ${widget.name}!',
                    style: const TextStyle(fontSize: 18, color: Colors.white),
                  ),
                  Text(
                    'Balance: \$${_currentBalance.toStringAsFixed(2)}',
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _controller,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Enter your bet',
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: placeBet,
                    child: const Text('Place Bet & Start Game'),
                  ),
                  const SizedBox(height: 20),
                  if (playerCards.isNotEmpty) ...[
                    const Text(
                      'Your Cards:',
                      style: TextStyle(color: Colors.white),
                    ),
                    Row(
                      children:
                          playerCards.map((cardNumber) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              child: SizedBox(
                                width: 100,
                                height: 150,
                                child: PlayingCardView(
                                  card: playingCard(cardNumber),
                                  style: myCardStyles,
                                ),
                              ),
                            );
                          }).toList(),
                    ),
                    Text(
                      'Total: ${handValue(playerCards)}',
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Dealer Cards:',
                      style: TextStyle(color: Colors.white),
                    ),
                    Row(
                      children:
                          dealerCards.asMap().entries.map((entry) {
                            int index = entry.key;
                            int cardNumber = entry.value;

                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              child: SizedBox(
                                width: 100,
                                height: 150,
                                child: PlayingCardView(
                                  card: playingCard(cardNumber),
                                  showBack:
                                      cardNotShown &&
                                      index != 0, // Show front for index 0
                                  style: myCardStyles,
                                ),
                              ),
                            );
                          }).toList(),
                    ),
                    // Text('Total: ${handValue(dealerCards)}',
                    //    style: const TextStyle(color: Colors.white)),
                    if (!cardNotShown) ...[
                      const SizedBox(height: 10),
                      Text(
                        'Total: ${handValue(dealerCards)}',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                    if (cardNotShown) ...[
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          ElevatedButton(
                            onPressed: playerHit,
                            child: const Text('Hit'),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton(
                            onPressed: playerStand,
                            child: const Text('Stand'),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton(
                            onPressed: doubleDown,
                            child: const Text('Double Down'),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton(
                            onPressed: split,
                            child: const Text('Split Hand'),
                          ),
                        ],
                      ),
                    ],
                  ],
                  if (playerSplitHand.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    const Text(
                      'Your Split Cards:',
                      style: TextStyle(color: Colors.white),
                    ),
                    Row(
                      children:
                          playerSplitHand.map((cardNumber) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              child: SizedBox(
                                width: 100,
                                height: 150,
                                child: PlayingCardView(
                                  card: playingCard(cardNumber),
                                  style: myCardStyles,
                                ),
                              ),
                            );
                          }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
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
            const Text(""),
          ],
        ),
      ),
    );
  }
}

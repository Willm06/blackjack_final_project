import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:playing_cards/playing_cards.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:math';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint(await rootBundle.loadString('AssetManifest.json'));
  await createAppFolder();
  await playBackgroundMusic();
  runApp(const MaterialApp(title: 'Navigation Basics', home: MyApp()));
}

Future<void> createAppFolder() async {
  Directory documentsDirectory = await getApplicationDocumentsDirectory();
  String appFolderPath = '${documentsDirectory.path}/BlackjackFlutterApp';

  Directory appFolder = Directory(appFolderPath);
  if (!await appFolder.exists()) {
    await appFolder.create(recursive: true);
    debugPrint("App folder created at: $appFolderPath");
  }

  String jsonFilePath = '$appFolderPath/player_data.json';
  File appJsonFile = File(jsonFilePath);

  if (!await appJsonFile.exists()) {
    try {
      // Load from asset bundle
      String assetData = await rootBundle.loadString('assets/player_data.json');
      await appJsonFile.writeAsString(assetData);
      debugPrint("JSON file copied to: $jsonFilePath");
    } catch (e) {
      debugPrint("Error loading asset JSON file: $e");
    }
  } else {
    debugPrint("JSON file already exists at: $jsonFilePath");
  }
}

class PlayerData {
  String name;
  double balance;
  double highestBalance;
  int wins;
  int matchesPlayed;
  double volume;
  bool backgroundMuted;
  bool effectsMuted;

  PlayerData({
    required this.name,
    required this.balance,
    required this.highestBalance,
    required this.wins,
    required this.matchesPlayed,
    required this.volume,
    required this.backgroundMuted,
    required this.effectsMuted,
  });

  factory PlayerData.fromJson(Map<String, dynamic> json) {
    return PlayerData(
      name: json['name'],
      balance: json['balance'],
      highestBalance: json['highest_balance'],
      wins: json['wins'],
      matchesPlayed: json['matches_played'],
      volume: json['volume'],
      backgroundMuted: json['background_muted'],
      effectsMuted: json['effects_muted'],
    );
  }
}

Future<PlayerData> loadPlayerData() async {
  Directory documentsDirectory = await getApplicationDocumentsDirectory();
  String jsonFilePath =
      '${documentsDirectory.path}/BlackjackFlutterApp/player_data.json';

  try {
    final file = File(jsonFilePath);
    final String response = await file.readAsString();
    final data = jsonDecode(response);
    return PlayerData.fromJson(data);
  } catch (e) {
    debugPrint("Error loading player data: $e");
    throw Exception("Failed to load player data.");
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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
        primarySwatch: Colors.red,
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

Future<PlayerData>? futurePlayerData;

AudioPlayer? _backgroundPlayer;

double _volume = 0.0; // Range: 0.0 to 1.0
bool _isBackgroundMuted = true;
bool _isSoundEffectMuted = true;

bool _gameInProgress = false;

Future<void> setVolume(double volume) async {
  _volume = volume.clamp(0.0, 1.0); // Ensures volume stays in valid range
  if (_backgroundPlayer != null) {
    await _backgroundPlayer!.setVolume(_isBackgroundMuted ? 0.0 : _volume);
  }
}

Future<void> toggleMute() async {
  _isBackgroundMuted = !_isBackgroundMuted;
  if (_backgroundPlayer != null) {
    await _backgroundPlayer!.setVolume(_isBackgroundMuted ? 0.0 : _volume);
  }
}

Future<void> playBackgroundMusic() async {
  print("Attempting to play background music...");

  try {
    _backgroundPlayer = AudioPlayer();

    await _backgroundPlayer!.setReleaseMode(ReleaseMode.loop);
    await _backgroundPlayer!.setSource(AssetSource('audio/jazz-lounge.mp3'));
    await _backgroundPlayer!.setVolume(_isBackgroundMuted ? 0.0 : _volume);
    await _backgroundPlayer!.resume();

    print("Music is playing.");
  } catch (e) {
    print("Background music failed to play: $e");
  }
}

Future<void> stopBackgroundMusic() async {
  if (_backgroundPlayer != null) {
    await _backgroundPlayer!.stop();
    await _backgroundPlayer!.dispose();
    _backgroundPlayer = null;
    print("Music stopped.");
  }
}

Future<void> playSoundEffect(String assetPath, {double? volume}) async {
  final effectPlayer = AudioPlayer();
  try {
    await effectPlayer.setSource(AssetSource(assetPath));
    await effectPlayer.setVolume(
      _isSoundEffectMuted ? 0.0 : (volume ?? _volume),
    );
    await effectPlayer.resume();
    // Dispose the player after the sound is done
    effectPlayer.onPlayerComplete.listen((event) {
      effectPlayer.dispose();
    });
  } catch (e) {
    print("Failed to play sound effect: $e");
  }
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      if (_gameInProgress) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Game in progress.")));
        return;
      }
      futurePlayerData = loadPlayerData();
      _selectedIndex = index;
    });
  }

  void updatePlayerData(Future<PlayerData> newData) {
    setState(() {
      futurePlayerData = newData.catchError((error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error loading player data: $error")),
        );
        return loadPlayerData(); // Revert to default data if loading fails
      });
    });
  }

  @override
  void initState() {
    super.initState();

    futurePlayerData = loadPlayerData();
    futurePlayerData!
        .then((data) {
          setState(() {
            _volume = data.volume;
            _isBackgroundMuted = data.backgroundMuted;
            _isSoundEffectMuted = data.effectsMuted;
          });

          // Optionally: apply the volume settings to the audio player
          setVolume(_volume);
        })
        .catchError((e) {
          debugPrint("Failed to load player data in initState: $e");
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<PlayerData>(
        future: futurePlayerData,
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
                highestBalance: snapshot.data!.highestBalance,
                wins: snapshot.data!.wins,
                matchesPlayed: snapshot.data!.matchesPlayed,
                onPlayerDataUpdated: updatePlayerData,
              ),
              GameScreen(
                name: snapshot.data!.name,
                balance: snapshot.data!.balance,
                highestBalance: snapshot.data!.highestBalance,
                wins: snapshot.data!.wins,
                matchesPlayed: snapshot.data!.matchesPlayed,
                onPlayerDataUpdated: updatePlayerData,
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
    required this.highestBalance,
    required this.wins,
    required this.matchesPlayed,
    required this.onPlayerDataUpdated,
  });

  final String name;
  final double balance;
  final double highestBalance;
  final int wins;
  final int matchesPlayed;
  final Function(Future<PlayerData>) onPlayerDataUpdated;

  @override
  _HomePageContentState createState() => _HomePageContentState();
}

class _HomePageContentState extends State<HomePageContent> {
  final TextEditingController _controller = TextEditingController();
  String? _setNameTo;

  double _localVolume = _volume;
  bool _localBackgroundMuted = _isBackgroundMuted;
  bool _localSoundEffectMuted = _isSoundEffectMuted;

  late double _currentBalance;

  void setName() async {
    _setNameTo = _controller.text;
    if (_setNameTo == '') {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter a name.')));
      return;
    }
    await writeToJson('name', _setNameTo);
    widget.onPlayerDataUpdated(loadPlayerData());
  }

  void saveSoundSettings() async {
    await writeToJson('volume', _localVolume);
    await writeToJson('background_muted', _localBackgroundMuted);
    await writeToJson('effects_muted', _localSoundEffectMuted);
  }

  void resetBalance() async {
    await writeToJson('balance', 500.0);
    widget.onPlayerDataUpdated;
    setState(() {
      _currentBalance = 500.0;
    });
  }

  @override
  void initState() {
    super.initState();
    _currentBalance = widget.balance;
    _controller.addListener(() {
      setState(() {
        _setNameTo = _controller.text;
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      backgroundColor: const Color.fromARGB(255, 0, 0, 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.name.toLowerCase() == 'null' || widget.name.trim().isEmpty
                  ? 'Welcome!'
                  : 'Welcome, ${widget.name}!',
              style: const TextStyle(fontSize: 18, color: Colors.white),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _controller,
              keyboardType: TextInputType.text,
              decoration: const InputDecoration(
                labelText: 'Enter your name',
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(onPressed: setName, child: const Text('Set Name')),
            const SizedBox(height: 10),
            Text(
              'Current Balance: \$${_currentBalance.toStringAsFixed(2)}',
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 10),
            Text(
              'Highest Balance: \$${widget.highestBalance.toStringAsFixed(2)}',
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 10),
            Text(
              'Matches Played: ${widget.matchesPlayed}',
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 10),
            Text(
              'Wins: ${widget.wins}',
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 10),
            Text(
              'Losses: ${widget.matchesPlayed - widget.wins}',
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: resetBalance,
              child: const Text('Reset Balance'),
            ),
            const SizedBox(height: 20),
            Column(
              children: [
                const Text("Volume", style: TextStyle(color: Colors.white)),
                Slider(
                  value: _localVolume,
                  min: 0.0,
                  max: 1.0,
                  divisions: null,
                  label: (_localVolume * 100).round().toString(),
                  onChanged: (double value) {
                    setState(() {
                      _localVolume = value;
                    });
                    setVolume(value);
                  },
                ),
                SwitchListTile(
                  title: const Text(
                    "Mute Background Music",
                    style: TextStyle(color: Colors.white),
                  ),
                  value: _localBackgroundMuted,
                  onChanged: (bool value) {
                    setState(() {
                      _localBackgroundMuted = value; // update global
                    });
                    toggleMute(); // background music toggle
                  },
                ),
                SwitchListTile(
                  title: const Text(
                    "Mute Sound Effects",
                    style: TextStyle(color: Colors.white),
                  ),
                  value: _localSoundEffectMuted,
                  onChanged: (bool value) {
                    setState(() {
                      _localSoundEffectMuted = value;
                    });
                    _isSoundEffectMuted = value; // update global
                  },
                ),
                ElevatedButton(
                  onPressed: saveSoundSettings,
                  child: const Text('Save Sound Settings'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class FlipPlayingCard extends StatefulWidget {
  const FlipPlayingCard({
    super.key,
    required this.playingCard,
    required this.showFront,
    required this.playingCardViewStyle,
  });

  final PlayingCard playingCard;
  final bool showFront;
  final PlayingCardViewStyle playingCardViewStyle;

  @override
  _FlipPlayingCardState createState() => _FlipPlayingCardState();
}

class _FlipPlayingCardState extends State<FlipPlayingCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  late final bool _showFront;

  @override
  void initState() {
    super.initState();
    _showFront = widget.showFront;
    _controller = AnimationController(
      duration: Duration(milliseconds: 400),
      vsync: this,
    );

    _animation = Tween<double>(begin: 0, end: 1).animate(_controller);
  }

  @override
  void didUpdateWidget(covariant FlipPlayingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.showFront != widget.showFront) {
      flipCard();
    }
  }

  void flipCard() {
    if (widget.showFront) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildFront() {
    return PlayingCardView(
      card: widget.playingCard,
      showBack: !_showFront,
      style: widget.playingCardViewStyle,
    );
  }

  Widget _buildBack() {
    return PlayingCardView(
      card: widget.playingCard,
      showBack: _showFront,
      style: widget.playingCardViewStyle,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final angle = _animation.value * pi;
        final isFrontVisible = angle <= (pi / 2);
        return Transform(
          alignment: Alignment.center,
          transform:
              Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateY(angle),
          child:
              isFrontVisible
                  ? _buildFront()
                  : Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(pi),
                    child: _buildBack(),
                  ),
        );
      },
    );
  }
}

class GameScreen extends StatefulWidget {
  static const routeName = '/gameScreen';

  const GameScreen({
    super.key,
    required this.name,
    required this.balance,
    required this.highestBalance,
    required this.wins,
    required this.matchesPlayed,
    required this.onPlayerDataUpdated,
  });

  final String name;
  final double balance;
  final double highestBalance;
  final int wins;
  final int matchesPlayed;
  final Function(Future<PlayerData>) onPlayerDataUpdated;

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
  bool playerWin = false;
  bool cardNotShown = true;
  bool actionInProgress = false;

  List<int> indexPlayerCardsToShow = [];
  List<int> indexDealerCardsToShow = [];

  final PlayingCardViewStyle myCardStyles = PlayingCardViewStyle(
    suitStyles: _buildSuitStyles(),
  );

  @override
  void initState() {
    super.initState();
    _currentBalance = widget.balance;
    _currentWins = widget.wins;
    _currentMatchesPlayed = widget.matchesPlayed;
    deck = _shuffleDeck();
    _controller.addListener(_updateBetValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _updateBetValue() {
    setState(() {
      final parsed = double.tryParse(_controller.text);
      _betValue =
          parsed != null ? double.parse(parsed.toStringAsFixed(2)) : null;
    });
  }

  static Map<Suit, SuitStyle> _buildSuitStyles() => {
    Suit.spades: SuitStyle(
      builder: (context) => _suitText("♠"),
      style: TextStyle(color: Colors.grey[800]),
    ),
    Suit.hearts: SuitStyle(
      builder: (context) => _suitText("♥", color: Colors.red),
      style: const TextStyle(color: Colors.red),
    ),
    Suit.diamonds: SuitStyle(
      builder: (context) => _suitText("♦", color: Colors.red),
      style: const TextStyle(color: Colors.red),
    ),
    Suit.clubs: SuitStyle(
      builder: (context) => _suitText("♣"),
      style: TextStyle(color: Colors.grey[800]),
    ),
    Suit.joker: SuitStyle(builder: (context) => const SizedBox()),
  };

  static Widget _suitText(String symbol, {Color? color}) {
    return FittedBox(
      fit: BoxFit.fitHeight,
      child: Text(symbol, style: TextStyle(fontSize: 500, color: color)),
    );
  }

  PlayingCard _playingCard(int cardNumber) {
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

  List<int> _shuffleDeck() {
    return List.generate(52, (i) => i + 1)..shuffle();
  }

  int _handValue(List<int> hand) {
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

  void _drawCard(List<int> hand, {required bool isPlayer}) {
    if (deck.isEmpty) _replenishDeck();
    final card = deck.removeLast();
    setState(() {
      hand.add(card);
    });
    int _myHandValue = _handValue(hand);

    if (_myHandValue > 21) {
      setState(() {
        isPlayer ? playerBust = true : dealerBust = true;
      });
      if (isPlayer) {
        Future.delayed(
          const Duration(milliseconds: 300),
          _playerStand,
        ); // add delay
      }
    } else if (_myHandValue == 21 && isPlayer) {
      playerWin = true;
      Future.delayed(const Duration(milliseconds: 300), _playerStand);
    }
  }

  void _replenishDeck() {
    deck = _shuffleDeck();
    deck.removeWhere(
      (card) => playerCards.contains(card) || dealerCards.contains(card),
    );
  }

  void placeBet() {
    _updateBetValue();
    gameStart();
  }

  void betTenPercent() {
    double tenPercent = double.parse(
      (_currentBalance * 0.1).toStringAsFixed(2),
    );
    if (tenPercent <= 0 || tenPercent > _currentBalance) {
      allIn();
    } else {
      _betValue = tenPercent;
      gameStart();
    }
  }

  void allIn() {
    _betValue = _currentBalance;
    gameStart();
  }

  void gameStart() async {
    _gameInProgress = true;

    if (_betValue == null ||
        (_betValue! <= 0 || _betValue! > _currentBalance)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter a valid bet.')));
      return;
    }

    setState(() {
      _gameInProgress = true;
      actionInProgress = false;
      _resetGame();
    });

    await playSoundEffect('audio/flip-card.mp3');

    Future.delayed(const Duration(milliseconds: 300), () {
      setState(() {
        indexPlayerCardsToShow = [0, 1];
        indexDealerCardsToShow = [0];
      });
    });

    Future.delayed(const Duration(milliseconds: 600), () {
      if (_handValue(playerCards) == 21) {
        setState(() {
          playerWin = true;
          indexDealerCardsToShow.add(1); // Flip hidden dealer card
        });
      }
    });
  }

  void _resetGame() {
    indexDealerCardsToShow.clear();
    indexPlayerCardsToShow.clear();
    if (playerSplitHand.isNotEmpty) {
      playerCards = playerSplitHand;
      playerSplitHand = [];
    } else {
      playerCards = [];
    }
    dealerCards.clear();

    drawStartCards();
    playerBust = dealerBust = false;
    cardNotShown = true;
  }

  void drawStartCards() {
    _drawCard(dealerCards, isPlayer: false);
    _drawCard(dealerCards, isPlayer: false);
    if (playerCards.isEmpty) _drawCard(playerCards, isPlayer: true);
    _drawCard(playerCards, isPlayer: true);
  }

  Future<void> playerHit() async {
    if (actionInProgress) {
      return;
    }
    actionInProgress = true;
    await playSoundEffect('audio/flip-card.mp3');
    _drawCard(playerCards, isPlayer: true);
    Future.delayed(const Duration(milliseconds: 300), () {
      setState(() {
        indexPlayerCardsToShow.add(playerCards.length - 1);
      });
      actionInProgress = false;
    });
  }

  void _playerStand() async {
    actionInProgress = true;
    await playSoundEffect('audio/flip-card.mp3');
    setState(() {
      cardNotShown = false;
      indexDealerCardsToShow.add(1);
    });

    await Future.delayed(const Duration(milliseconds: 300));
    await _dealerPhase();
  }

  Future<void> _dealerPhase() async {
    final playerValue = _handValue(playerCards);
    if (!playerBust && playerValue != 21) {
      while (_handValue(dealerCards) < 17) {
        _drawCard(dealerCards, isPlayer: false);
        await playSoundEffect('audio/flip-card.mp3');
        await Future.delayed(const Duration(milliseconds: 300));
        setState(() => indexDealerCardsToShow.add(dealerCards.length - 1));
      }
    }
    await _evaluateWinner();
  }

  Future<void> _evaluateWinner() async {
    final playerValue = _handValue(playerCards);
    final dealerValue = _handValue(dealerCards);

    String result;
    if (playerBust) {
      result = 'You busted, Dealer wins';
      _currentBalance -= _betValue!;
      if (_currentBalance > 0) {
        playSoundEffect('audio/brass-fail.mp3');
      } else {
        playSoundEffect('audio/downer-noise.mp3');
      }
    } else if (dealerBust || playerValue > dealerValue) {
      result = 'You win!';
      _currentBalance += _betValue!;
      _currentWins++;
      if (_currentBalance > widget.highestBalance) {
        await writeToJson('highest_balance', _currentBalance);
      }
      if (_betValue! * 2 == _currentBalance) {
        playSoundEffect('audio/fanfare.mp3');
      } else {
        playSoundEffect('audio/cash-register-purchase.mp3');
      }
    } else if (dealerValue > playerValue) {
      result = 'Dealer wins';
      _currentBalance -= _betValue!;
      if (_currentBalance > 0) {
        if (dealerCards.length > 4 || dealerValue == 21) {
          playSoundEffect('audio/the-simpsons-nelsons-haha.mp3');
        } else {
          playSoundEffect('audio/brass-fail.mp3');
        }
      } else {
        playSoundEffect('audio/downer-noise.mp3');
      }
    } else {
      result = 'Push';
      playSoundEffect('audio/card-drop.mp3');
    }

    _currentMatchesPlayed++;

    await writeToJson('balance', _currentBalance);
    await writeToJson('wins', _currentWins);
    await writeToJson('matches_played', _currentMatchesPlayed);

    _showResultDialog(result);
    setState(() {
      actionInProgress = false;
      _gameInProgress = false;
    });
  }

  void _showResultDialog(String result) {
    Future.delayed(const Duration(milliseconds: 300), () {
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
                      playerCards.clear();
                    });
                  },
                  child: const Text('OK'),
                ),
              ],
            ),
      );
    });
  }

  bool _canSplit() {
    if (playerCards.length == 2) {
      final first = (playerCards[0] - 1) % 13;
      final second = (playerCards[1] - 1) % 13;
      return first == second;
    }
    return false;
  }

  Future<void> split() async {
    if (!_canSplit()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cards must be same value to split.')),
      );
      return;
    }

    final cardToSplit = playerCards.removeAt(1);
    playerSplitHand.add(cardToSplit);

    setState(() {
      indexPlayerCardsToShow.remove(1);
    });

    await Future.delayed(const Duration(milliseconds: 300));
    _drawCard(playerCards, isPlayer: true);

    await Future.delayed(const Duration(milliseconds: 300));
    setState(() {
      indexPlayerCardsToShow.add(1);
    });
  }

  void doubleDown() async {
    if ((_betValue ?? 0) * 2 <= _currentBalance) {
      _betValue = (_betValue ?? 0) * 2;
      await playerHit();
      if (_handValue(playerCards) < 21) {
        Future.delayed(const Duration(milliseconds: 300), () {
          _playerStand();
        });
      }
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Insufficient balance.')));
    }
  }

  bool dealerCardController(int index) {
    if (indexDealerCardsToShow.contains(index)) {
      return true;
    } else {
      return false;
    }
  }

  bool playerCardController(int index) {
    if (indexPlayerCardsToShow.contains(index)) {
      return true;
    } else {
      return false;
    }
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
                "assets/gambling.jpg",
                filterQuality: FilterQuality.none,
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
                    widget.name.toLowerCase() == 'null' ||
                            widget.name.trim().isEmpty
                        ? 'Welcome!'
                        : 'Welcome, ${widget.name}!',
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
                  if (!_gameInProgress) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10, // Space between buttons
                      runSpacing: 10, // Space between rows
                      children: [
                        ElevatedButton(
                          onPressed: gameStart,
                          child: const Text('Place Bet & Start Game'),
                        ),
                        ElevatedButton(
                          onPressed: betTenPercent,
                          child: const Text('Bet 10%'),
                        ),
                        ElevatedButton(
                          onPressed: allIn,
                          child: const Text('All In'),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 20),
                  if (playerCards.isNotEmpty) ...[
                    const Text(
                      'Your Cards:',
                      style: TextStyle(color: Colors.white),
                    ),
                    Wrap(
                      children:
                          playerCards.asMap().entries.map((entry) {
                            int index = entry.key;
                            int cardNumber = entry.value;
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              child: SizedBox(
                                width: 100,
                                height: 150,
                                child: FlipPlayingCard(
                                  playingCard: _playingCard(cardNumber),
                                  showFront: playerCardController(index),
                                  playingCardViewStyle: myCardStyles,
                                ),
                              ),
                            );
                          }).toList(),
                    ),
                    Text(
                      'Total: ${_handValue(playerCards)}',
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Dealer Cards:',
                      style: TextStyle(color: Colors.white),
                    ),
                    Wrap(
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
                                child: FlipPlayingCard(
                                  playingCard: _playingCard(cardNumber),
                                  showFront: dealerCardController(index),
                                  playingCardViewStyle: myCardStyles,
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
                        'Total: ${_handValue(dealerCards)}',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                    if (cardNotShown) ...[
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 10, // Space between buttons
                        runSpacing: 10, // Space between rows
                        children: [
                          ElevatedButton(
                            onPressed:
                                actionInProgress || playerBust || playerWin
                                    ? null
                                    : () {
                                      playerHit();
                                    },
                            child: const Text('Hit'),
                          ),
                          ElevatedButton(
                            onPressed: actionInProgress || playerBust || playerWin
                                    ? null
                                    : () {
                                      _playerStand();
                                    },
                            child: const Text('Stand'),
                          ),
                          ElevatedButton(
                            onPressed: actionInProgress || playerBust || playerWin
                                    ? null
                                    : () {
                                      doubleDown();
                                    },
                            child: const Text('Double Down'),
                          ),
                          ElevatedButton(
                            onPressed: actionInProgress || playerBust || playerWin
                                    ? null
                                    : () {
                                      split();
                                    },
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
                                  card: _playingCard(cardNumber),
                                  style: myCardStyles,
                                ),
                              ),
                            );
                          }).toList(),
                    ),
                  ],
                  SizedBox(height: 50),
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
      appBar: AppBar(title: const Text('Rules Page')),
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
            const Text("You may also double down -> Double your bet but only get 1 card"),
            const Text(""),
            const Text("If you have two of the same value cards, also same face, you may split to have another running hand"),
            const Text(""),
            const Text(
              "If you draw a card and are now over 21, you bust and lose",
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

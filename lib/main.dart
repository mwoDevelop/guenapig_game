import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Potrzebne do SystemNavigator
import 'dart:math';
import 'dart:async'; // Potrzebne do Timera
import 'package:shared_preferences/shared_preferences.dart'; // Do zapisywania wyników
import 'dart:convert'; // Do kodowania/dekodowania JSON

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Głodna Świnka Morska',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.lightGreen),
        useMaterial3: true,
      ),
      home: const MainMenuScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// --- Ekran Menu Głównego ---
class MainMenuScreen extends StatelessWidget {
  const MainMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Głodna Świnka Morska - Menu'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              '🐹', // Emoji świnki jako logo
              style: TextStyle(fontSize: 100),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                textStyle: const TextStyle(fontSize: 20),
              ),
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const GameScreen()),
                );
              },
              child: const Text('Start Gry'),
            ),
            const SizedBox(height: 20),
            // Przycisk Najlepsze Wyniki
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                textStyle: const TextStyle(fontSize: 20),
                backgroundColor: Colors.blue[300],
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.push( // Używamy push, aby można było wrócić
                  context,
                  MaterialPageRoute(builder: (context) => const HighScoresScreen()),
                );
              },
              child: const Text('Najlepsze Wyniki'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                textStyle: const TextStyle(fontSize: 20),
                backgroundColor: Colors.red[300], // Inny kolor dla wyjścia
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                SystemNavigator.pop();
              },
              child: const Text('Wyjście'),
            ),
          ],
        ),
      ),
    );
  }
}


// --- Ekran Gry ---

// Klasa reprezentująca jedzenie
class FoodItem {
  final String id;
  final String emoji;

  FoodItem({required this.id, required this.emoji});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FoodItem && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}


class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  // --- Stan Gry ---
  int _score = 0;
  int _lives = 3; // Dodajemy życia
  int _currentLevel = 1;
  final int _scoreToLevelUp = 100;
  final int _initialFoodCount = 3;
  final Duration _initialWishDuration = const Duration(seconds: 5);
  Duration _currentWishDuration = const Duration(seconds: 5);

  FoodItem? _currentWish;
  List<FoodItem> _orbitingFood = [];
  final List<FoodItem> _availableFood = [
    FoodItem(id: 'carrot', emoji: '🥕'), FoodItem(id: 'lettuce', emoji: '🥬'),
    FoodItem(id: 'apple', emoji: '🍎'), FoodItem(id: 'parsley', emoji: '🌿'),
    FoodItem(id: 'hay', emoji: '🌾'), FoodItem(id: 'pepper', emoji: '🫑'),
    FoodItem(id: 'cucumber', emoji: '🥒'), FoodItem(id: 'broccoli', emoji: '🥦'),
    FoodItem(id: 'strawberry', emoji: '🍓'), FoodItem(id: 'dandelion', emoji: '🌼'),
    FoodItem(id: 'banana', emoji: '🍌'), FoodItem(id: 'grapes', emoji: '🍇'),
  ];
  Timer? _wishTimer;
  late AnimationController _orbitAnimationController;
  late AnimationController _patienceAnimationController;
  bool _isLevelingUp = false;

  @override
  void initState() {
    super.initState();
    _orbitAnimationController = AnimationController(
      vsync: this, duration: const Duration(seconds: 10),
    )..repeat();
    _patienceAnimationController = AnimationController(
      vsync: this, duration: _currentWishDuration,
    );
    _startGame();
  }

  @override
  void dispose() {
    _wishTimer?.cancel();
    _orbitAnimationController.dispose();
    _patienceAnimationController.dispose();
    super.dispose();
  }

  void _startGame() {
    _orbitAnimationController.reset();
    _orbitAnimationController.repeat();
    _patienceAnimationController.reset();
    setState(() {
      _currentLevel = 1;
      _score = 0;
      _lives = 3; // Resetuj życia
      _currentWishDuration = _initialWishDuration;
      _isLevelingUp = false;
      _generateOrbitingFood(_calculateFoodCountForLevel(_currentLevel));
      _changeWish();
    });
  }

  void _startOrResetPatienceTimer() {
    _wishTimer?.cancel();
    _patienceAnimationController.reset();
    _patienceAnimationController.duration = _currentWishDuration;
    _patienceAnimationController.reverse(from: 1.0);
    _wishTimer = Timer(_currentWishDuration, () {
      if (mounted && !_isLevelingUp) {
        _handleTimeOut();
      }
    });
  }

  void _handleTimeOut() {
     if (!mounted || _isLevelingUp) return;
     print('Czas minął!');
     setState(() { _lives--; });
     if (_lives <= 0) {
       _gameOver();
     } else {
       _changeWish();
     }
  }

  int _calculateFoodCountForLevel(int level) {
    int count = _initialFoodCount + level - 1;
    return min(count, _availableFood.length);
  }

  void _generateOrbitingFood(int count) {
    final random = Random();
    final uniqueFoodCount = _availableFood.length;
    final effectiveCount = min(count, uniqueFoodCount);
    List<FoodItem> uniqueAvailableFood = List.from(_availableFood);
    uniqueAvailableFood.shuffle(random);
    _orbitingFood = uniqueAvailableFood.take(effectiveCount).toList();
    if (_currentWish != null && !_orbitingFood.contains(_currentWish)) {
      if (_orbitingFood.isNotEmpty) {
        _orbitingFood[random.nextInt(_orbitingFood.length)] = _currentWish!;
      } else {
        _orbitingFood.add(_currentWish!);
      }
    }
    if (mounted) { setState(() {}); }
  }

  void _changeWish() {
    final random = Random();
    FoodItem newWish;
    if (_availableFood.isEmpty) return;
    if (_availableFood.length > 1) {
      do { newWish = _availableFood[random.nextInt(_availableFood.length)]; } while (newWish == _currentWish);
    } else { newWish = _availableFood.first; }
    if (!_orbitingFood.contains(newWish)) {
       if (_orbitingFood.isNotEmpty) { _orbitingFood[random.nextInt(_orbitingFood.length)] = newWish; }
       else { _orbitingFood.add(newWish); }
    }
    if (mounted) {
      setState(() { _currentWish = newWish; });
      _startOrResetPatienceTimer();
    }
  }

  void _handleFoodTap(FoodItem tappedFood) {
    if (!mounted || _isLevelingUp) return;
    if (tappedFood == _currentWish) {
      _patienceAnimationController.stop();
      double remainingTimeFraction = _patienceAnimationController.value;
      int timeBonus = (remainingTimeFraction * 10).round();
      int pointsEarned = 10 + timeBonus;
      int newScore = _score + pointsEarned;
      bool leveledUp = newScore >= _scoreToLevelUp;
      setState(() { _score = newScore; });
      print('Dobrze! Punkty: $_score (Bonus: $timeBonus)');
      if (leveledUp) { _levelUp(); }
      else { _changeWish(); }
    } else {
      setState(() {
        _score -= 5;
        if (_score < 0) _score = 0;
        _lives--; // Zmniejsz życie
      });
      print('Źle! Życia: $_lives, Poziom: $_currentLevel, Punkty: $_score');
      if (_lives <= 0) { _gameOver(); }
    }
  }

  void _levelUp() {
    if (!mounted) return;
    print('Level Up! Przechodzisz na poziom ${_currentLevel + 1}');
    _wishTimer?.cancel();
    _patienceAnimationController.stop();
    setState(() { _isLevelingUp = true; });
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      setState(() {
        _currentLevel++;
        // _score = 0; // Usunięto resetowanie punktów
        int newDurationMillis = (_currentWishDuration.inMilliseconds * 0.9).round();
        _currentWishDuration = Duration(milliseconds: max(1000, newDurationMillis));
        int foodCountForLevel = _calculateFoodCountForLevel(_currentLevel);
        _generateOrbitingFood(foodCountForLevel);
        _isLevelingUp = false;
        _changeWish();
      });
    });
  }

  // Logika końca gry
  void _gameOver() {
    if (!mounted) return;
    print('Game Over! Wynik: $_score');
    _wishTimer?.cancel();
    _orbitAnimationController.stop();
    _patienceAnimationController.stop();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => GameOverScreen(score: _score)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final double centerX = screenSize.width / 2;
    final double centerY = screenSize.height / 2;
    final double orbitRadius = min(centerX, centerY) * 0.55;
    final double guineaPigSize = 70.0; // Rozmiar świnki (zmniejszony)
    final double patienceBarWidth = guineaPigSize * 0.8;
    final double patienceBarHeight = 8.0;

    return Scaffold(
      appBar: AppBar(
        title: Text('Głodna Świnka Morska - Poziom $_currentLevel'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const MainMenuScreen()),
            );
          },
          tooltip: 'Wróć do Menu',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _startGame,
            tooltip: 'Restart Gry',
          ),
        ],
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
                SizedBox(
                  height: 80,
                  child: (_currentWish != null && !_isLevelingUp)
                    ? Transform.translate(
                        offset: const Offset(-5.0, 0.0),
                        child: Center(
                          child: Transform.rotate(
                            angle: pi / 2,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                               color: Colors.white.withOpacity(0.9),
                               borderRadius: BorderRadius.circular(20),
                               border: Border.all(color: Colors.grey.shade400),
                                boxShadow: [ BoxShadow( color: Colors.black.withOpacity(0.1), spreadRadius: 1, blurRadius: 2, offset: const Offset(0, 1), ), ],
                             ),
                              child: Transform.rotate(
                                angle: -pi / 2,
                                child: Text(_currentWish!.emoji, style: const TextStyle(fontSize: 26)), // Zmniejszony rozmiar emoji
                              ),
                            ),
                          ),
                         ),
                      )
                   : null,
               ),
               SizedBox(
                 height: patienceBarHeight + 5,
                 child: (!_isLevelingUp)
                   ? AnimatedBuilder(
                       animation: _patienceAnimationController,
                       builder: (context, child) {
                         return Container(
                           width: patienceBarWidth,
                           height: patienceBarHeight,
                           margin: const EdgeInsets.only(bottom: 5),
                           child: ClipRRect(
                             borderRadius: BorderRadius.circular(patienceBarHeight / 2),
                             child: LinearProgressIndicator(
                               value: _patienceAnimationController.value,
                               backgroundColor: Colors.grey[300],
                               valueColor: AlwaysStoppedAnimation<Color>(
                                 _patienceAnimationController.value > 0.5 ? Colors.green : _patienceAnimationController.value > 0.2 ? Colors.orange : Colors.red,
                               ),
                               minHeight: patienceBarHeight,
                             ),
                           ),
                         );
                       },
                     )
                   : null,
               ),
               Container(
                 width: guineaPigSize,
                 height: guineaPigSize,
                 decoration: BoxDecoration(
                   color: Colors.brown[300],
                   shape: BoxShape.circle,
                   boxShadow: [ BoxShadow( color: Colors.black.withOpacity(0.2), spreadRadius: 1, blurRadius: 3, offset: const Offset(0, 2), ), ],
                 ),
                 child: const Center(child: Text('🐹', style: TextStyle(fontSize: 40))),
               ),
            ],
          ),
          if (!_isLevelingUp)
            AnimatedBuilder(
              animation: _orbitAnimationController,
              builder: (context, child) {
                return Stack(
                  children: _buildOrbitingFoodWidgets( centerX, centerY, orbitRadius, _orbitAnimationController.value * 2 * pi, ),
                );
              },
            ),
          Positioned(
            top: 10,
            left: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration( color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(12), ),
              child: Text(
                'Poziom: $_currentLevel | Punkty: $_score | Życia: $_lives', // Dodajemy życia
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ),
          if (_isLevelingUp)
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                 decoration: BoxDecoration(
                   color: Colors.amber.withOpacity(0.85),
                   borderRadius: BorderRadius.circular(20),
                   border: Border.all(color: Colors.white, width: 2),
                   boxShadow: [ BoxShadow( color: Colors.black.withOpacity(0.3), spreadRadius: 2, blurRadius: 5, offset: const Offset(0, 3), ), ]
                 ),
                child: Text(
                  'Level Up!',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white, shadows: [ Shadow(blurRadius: 2.0, color: Colors.black.withOpacity(0.5), offset: Offset(1, 1)) ]),
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildOrbitingFoodWidgets(double centerX, double centerY, double radius, double rotationAngle) {
    List<Widget> foodWidgets = [];
    if (_orbitingFood.isEmpty) return foodWidgets;
    double angleIncrement = (2 * pi) / _orbitingFood.length;
    for (int i = 0; i < _orbitingFood.length; i++) {
      final foodItem = _orbitingFood[i];
      final currentAngle = rotationAngle + (angleIncrement * i);
      final double foodX = centerX + radius * cos(currentAngle);
      final double foodY = centerY + radius * sin(currentAngle);
      foodWidgets.add(
        Positioned(
          left: foodX - 22.5, top: foodY - 22.5,
          child: _buildFoodItemWidget(foodItem),
        ),
      );
    }
    return foodWidgets;
  }

  Widget _buildFoodItemWidget(FoodItem foodItem) {
    return GestureDetector(
      onTap: () => _handleFoodTap(foodItem),
      child: Container(
        width: 45, height: 45,
        decoration: BoxDecoration(
           shape: BoxShape.circle,
           boxShadow: [ BoxShadow( color: Colors.black.withOpacity(0.15), spreadRadius: 1, blurRadius: 2, ) ]
        ),
        child: Center(child: Text(foodItem.emoji, style: const TextStyle(fontSize: 28))),
      ),
    );
  }
}

// --- Ekran Game Over ---
class GameOverScreen extends StatefulWidget {
  final int score;
  const GameOverScreen({super.key, required this.score});

  @override
  State<GameOverScreen> createState() => _GameOverScreenState();
}

class _GameOverScreenState extends State<GameOverScreen> {
  final _nameController = TextEditingController();
  bool _isSaving = false;

  Future<void> _saveScore() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar( const SnackBar(content: Text('Wpisz swoje imię!')), );
      return;
    }
    setState(() { _isSaving = true; });
    final prefs = await SharedPreferences.getInstance();
    final highScoresString = prefs.getString('highScores') ?? '[]';
    List<dynamic> highScores = jsonDecode(highScoresString);
    highScores.add({'name': _nameController.text.trim(), 'score': widget.score});
    highScores.sort((a, b) => b['score'].compareTo(a['score']));
    if (highScores.length > 10) { highScores = highScores.sublist(0, 10); }
    await prefs.setString('highScores', jsonEncode(highScores));
    setState(() { _isSaving = false; });
    if (mounted) {
       Navigator.pushReplacement( context, MaterialPageRoute(builder: (context) => const HighScoresScreen()), );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Koniec Gry!'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text( 'Twój wynik: ${widget.score}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold), ),
              const SizedBox(height: 30),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration( labelText: 'Wpisz swoje imię', border: OutlineInputBorder(), ),
                maxLength: 15,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 20),
              _isSaving
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      style: ElevatedButton.styleFrom( padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15), textStyle: const TextStyle(fontSize: 18), ),
                      onPressed: _saveScore,
                      child: const Text('Zapisz wynik'),
                    ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () {
                  Navigator.pushReplacement( context, MaterialPageRoute(builder: (context) => const MainMenuScreen()), );
                },
                child: const Text('Wróć do Menu Głównego'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Ekran Najlepszych Wyników ---
class HighScoresScreen extends StatefulWidget {
  const HighScoresScreen({super.key});

  @override
  State<HighScoresScreen> createState() => _HighScoresScreenState();
}

class _HighScoresScreenState extends State<HighScoresScreen> {
  List<dynamic> _highScores = [];

  @override
  void initState() {
    super.initState();
    _loadHighScores();
  }

  Future<void> _loadHighScores() async {
    final prefs = await SharedPreferences.getInstance();
    final highScoresString = prefs.getString('highScores') ?? '[]';
    if (mounted) {
      setState(() {
        _highScores = jsonDecode(highScoresString);
        _highScores.sort((a, b) => b['score'].compareTo(a['score']));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Najlepsze Wyniki'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Zmieniamy przycisk powrotu, aby wracał do Menu Głównego
        leading: IconButton(
          icon: const Icon(Icons.arrow_back), // Zmieniona ikona na strzałkę wstecz
          onPressed: () {
            Navigator.pushReplacement( // Wracamy do menu, zastępując ekran wyników
              context,
              MaterialPageRoute(builder: (context) => const MainMenuScreen()),
            );
          },
          tooltip: 'Wróć do Menu', // Zmieniony tooltip
        ),
      ),
      body: _highScores.isEmpty
          ? const Center(child: Text('Brak zapisanych wyników.'))
          : ListView.builder(
              itemCount: _highScores.length,
              itemBuilder: (context, index) {
                final scoreEntry = _highScores[index];
                return ListTile(
                  leading: Text('${index + 1}.', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  title: Text(scoreEntry['name'], style: const TextStyle(fontSize: 18)),
                  trailing: Text(scoreEntry['score'].toString(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                );
              },
            ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Potrzebne do SystemNavigator
import 'dart:math';
import 'dart:async'; // Potrzebne do Timera

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
      // Zmieniamy home na MainMenuScreen
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
            // Tytuł lub logo gry (placeholder)
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
                // Nawigacja do ekranu gry, zastępując menu
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const GameScreen()),
                );
              },
              child: const Text('Start Gry'),
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
                // Wyjście z aplikacji
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
  final String id; // Unikalny identyfikator, np. emoji
  final String emoji; // Emoji reprezentujące jedzenie

  FoodItem({required this.id, required this.emoji});

  // Przeciążenie operatora == i hashCode, aby porównywać obiekty FoodItem
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

// Dodajemy TickerProviderStateMixin (potrzebne 2 kontrolery animacji)
class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  // --- Stan Gry ---
  int _score = 0;
  int _currentLevel = 1;
  final int _scoreToLevelUp = 100;
  final int _initialFoodCount = 3;
  final Duration _initialWishDuration = const Duration(seconds: 5);
  Duration _currentWishDuration = const Duration(seconds: 5);

  FoodItem? _currentWish;
  List<FoodItem> _orbitingFood = [];
  // Dodajemy więcej jedzenia
  final List<FoodItem> _availableFood = [
    FoodItem(id: 'carrot', emoji: '🥕'),
    FoodItem(id: 'lettuce', emoji: '🥬'),
    FoodItem(id: 'apple', emoji: '🍎'),
    FoodItem(id: 'parsley', emoji: '🌿'),
    FoodItem(id: 'hay', emoji: '🌾'),
    FoodItem(id: 'pepper', emoji: '🫑'),
    FoodItem(id: 'cucumber', emoji: '🥒'),
    FoodItem(id: 'broccoli', emoji: '🥦'),
    FoodItem(id: 'strawberry', emoji: '🍓'),
    FoodItem(id: 'dandelion', emoji: '🌼'), // Mniszek lekarski
    FoodItem(id: 'banana', emoji: '🍌'),
    FoodItem(id: 'grapes', emoji: '🍇'),
  ];
  Timer? _wishTimer; // Timer do obsługi timeoutu cierpliwości

  // Kontroler animacji obrotu jedzenia
  late AnimationController _orbitAnimationController;
  // Kontroler animacji paska cierpliwości
  late AnimationController _patienceAnimationController;
  bool _isLevelingUp = false;

  @override
  void initState() {
    super.initState();
    // Inicjalizujemy kontroler animacji orbity
    _orbitAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    // Inicjalizujemy kontroler paska cierpliwości
    _patienceAnimationController = AnimationController(
      vsync: this,
      duration: _currentWishDuration, // Początkowy czas
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

  // Rozpoczyna lub restartuje grę
  void _startGame() {
    _orbitAnimationController.reset();
    _orbitAnimationController.repeat();
    _patienceAnimationController.reset();

    setState(() {
      _currentLevel = 1;
      _score = 0;
      _currentWishDuration = _initialWishDuration;
      _isLevelingUp = false;
      _generateOrbitingFood(_calculateFoodCountForLevel(_currentLevel));
      _changeWish(); // Ustawia życzenie i resetuje timer/pasek
    });
  }

  // Uruchamia lub resetuje timer zmiany życzenia i pasek cierpliwości
  void _startOrResetPatienceTimer() {
    _wishTimer?.cancel();
    _patienceAnimationController.reset();
    _patienceAnimationController.duration = _currentWishDuration; // Ustaw aktualny czas

    // Uruchom animację paska od pełnego (1.0) do zera (0.0)
    _patienceAnimationController.reverse(from: 1.0);

    // Uruchom timer, który sprawdzi, czy gracz zdążył
    _wishTimer = Timer(_currentWishDuration, () {
      if (mounted && !_isLevelingUp) {
        _handleTimeOut(); // Czas minął
      }
    });
  }

  // Obsługa sytuacji, gdy czas na wybór minął
  void _handleTimeOut() {
     if (!mounted || _isLevelingUp) return;
     print('Czas minął!');
     setState(() {
       _score -= 2; // Mała kara za brak reakcji
       if (_score < 0) _score = 0;
       // TODO: Dodać animację np. wzruszenia ramionami przez świnkę
     });
     _changeWish(); // Zmień życzenie na następne i zresetuj timer/pasek
  }


  // Oblicza liczbę jedzenia na orbicie dla danego poziomu
  int _calculateFoodCountForLevel(int level) {
    int count = _initialFoodCount + level - 1;
    return min(count, _availableFood.length);
  }

  // Generuje losowe jedzenie na orbitę
  void _generateOrbitingFood(int count) {
    final random = Random();
    final uniqueFoodCount = _availableFood.length;
    final effectiveCount = min(count, uniqueFoodCount);

    List<FoodItem> uniqueAvailableFood = List.from(_availableFood);
    uniqueAvailableFood.shuffle(random);
    _orbitingFood = uniqueAvailableFood.take(effectiveCount).toList();

    // Upewnij się, że aktualne życzenie (jeśli istnieje) jest na orbicie
    if (_currentWish != null && !_orbitingFood.contains(_currentWish)) {
      if (_orbitingFood.isNotEmpty) {
        _orbitingFood[random.nextInt(_orbitingFood.length)] = _currentWish!;
      } else {
        _orbitingFood.add(_currentWish!);
      }
    }
    if (mounted) {
      setState(() {});
    }
  }


  // Zmienia życzenie świnki i resetuje timer/pasek
  void _changeWish() {
    final random = Random();
    FoodItem newWish;

    if (_availableFood.isEmpty) return;

    if (_availableFood.length > 1) {
      do {
        newWish = _availableFood[random.nextInt(_availableFood.length)];
      } while (newWish == _currentWish);
    } else {
      newWish = _availableFood.first;
    }

    // Upewnijmy się, że nowe życzenie jest na orbicie
    if (!_orbitingFood.contains(newWish)) {
       if (_orbitingFood.isNotEmpty) {
         _orbitingFood[random.nextInt(_orbitingFood.length)] = newWish;
       } else {
         _orbitingFood.add(newWish);
       }
    }

    if (mounted) {
      setState(() {
        _currentWish = newWish;
      });
      _startOrResetPatienceTimer(); // Zresetuj timer i pasek dla nowego życzenia
    }
  }

  // Logika po tapnięciu jedzenia
  void _handleFoodTap(FoodItem tappedFood) {
    if (!mounted || _isLevelingUp) return;

    if (tappedFood == _currentWish) {
      // Poprawny wybór
      _patienceAnimationController.stop(); // Zatrzymaj animację paska

      // TODO: Obliczyć bonus czasowy na podstawie _patienceAnimationController.value
      // Im bliżej 1.0 (początku), tym większy bonus
      double remainingTimeFraction = _patienceAnimationController.value;
      int timeBonus = (remainingTimeFraction * 10).round(); // Prosty przykład bonusu
      int pointsEarned = 10 + timeBonus;

      int newScore = _score + pointsEarned;
      bool leveledUp = newScore >= _scoreToLevelUp;

      setState(() {
        _score = newScore;
        // TODO: Dodać animację jedzenia przez świnkę
      });

      print('Dobrze! Punkty: $_score (Bonus: $timeBonus)');

      if (leveledUp) {
        _levelUp();
      } else {
        _changeWish(); // Zmień życzenie i zresetuj timer/pasek
      }

    } else {
      // Błędny wybór
      setState(() {
        _score -= 5;
        if (_score < 0) _score = 0;
        // TODO: Dodać animację niezadowolenia świnki
      });
      print('Źle! Poziom: $_currentLevel, Punkty: $_score');
      // Nie resetujemy timera/paska przy błędnym wyborze, gracz nadal ma czas
    }
  }

  // Logika przejścia do następnego poziomu
  void _levelUp() {
    if (!mounted) return;

    print('Level Up! Przechodzisz na poziom ${_currentLevel + 1}');
    _wishTimer?.cancel();
    _patienceAnimationController.stop(); // Zatrzymaj pasek

    setState(() {
      _isLevelingUp = true;
    });

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;

      setState(() {
        _currentLevel++;
        _score = 0;

        int newDurationMillis = (_currentWishDuration.inMilliseconds * 0.9).round();
        _currentWishDuration = Duration(milliseconds: max(1000, newDurationMillis));
        print('Nowy czas życzenia: ${_currentWishDuration.inMilliseconds}ms');

        int foodCountForLevel = _calculateFoodCountForLevel(_currentLevel);
        print('Nowa liczba jedzenia: $foodCountForLevel');
        _generateOrbitingFood(foodCountForLevel);

        _isLevelingUp = false;
        _changeWish(); // Ustaw nowe życzenie i zresetuj timer/pasek
      });
    });
  }


  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final double centerX = screenSize.width / 2;
    final double centerY = screenSize.height / 2;
    final double orbitRadius = min(centerX, centerY) * 0.55;
    final double guineaPigSize = 80.0; // Rozmiar świnki
    final double patienceBarWidth = guineaPigSize * 0.8; // Szerokość paska
    final double patienceBarHeight = 8.0; // Wysokość paska

    return Scaffold(
      appBar: AppBar(
        // Zmieniamy tytuł na dynamiczny, pokazujący poziom
        title: Text('Głodna Świnka Morska - Poziom $_currentLevel'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Dodajemy przycisk powrotu do menu
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // Wróć do menu, zastępując ekran gry
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
          // Grupa: Chmurka + Pasek Cierpliwości + Świnka (wyśrodkowana przez Stack)
          Column(
            mainAxisSize: MainAxisSize.min, // Aby Column zajmował tylko potrzebne miejsce
            children: [
               // Wyświetlanie aktualnego życzenia w chmurce (przeniesione tutaj)
               // Ukryj chmurkę podczas level up
                // Dodajemy SizedBox, aby zarezerwować miejsce nawet gdy chmurka jest ukryta
                SizedBox(
                  // Zwiększamy wysokość, aby zmieścić obróconą chmurkę
                  height: 80,
                  child: (_currentWish != null && !_isLevelingUp)
                    // Dodajemy Transform.translate wokół Center, aby precyzyjnie przesunąć
                    ? Transform.translate(
                        // Przesuwamy lekko w lewo (ujemna wartość X)
                        offset: const Offset(-5.0, 0.0), // Dostosuj wartość przesunięcia
                        child: Center(
                          child: Transform.rotate( // Obracamy całą chmurkę
                            angle: pi / 2, // Obrót o 90 stopni
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              // Dostosowujemy padding do obróconego kształtu
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                               color: Colors.white.withOpacity(0.9),
                               borderRadius: BorderRadius.circular(20), // Można dostosować dla lepszego efektu
                               border: Border.all(color: Colors.grey.shade400),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    spreadRadius: 1,
                                    blurRadius: 2,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                             ),
                             child: Transform.rotate( // Obracamy tekst z powrotem
                               angle: -pi / 2, // Obrót o -90 stopni
                               child: Text(_currentWish!.emoji, style: const TextStyle(fontSize: 30)),
                             ),
                           ),
                          ),
                         ),
                      )
                   : null, // Nie pokazuj nic, jeśli nie ma życzenia lub jest level up
               ),

               // Pasek Cierpliwości (widoczny tylko gdy nie ma level up)
               // Dodajemy SizedBox, aby zarezerwować miejsce nawet gdy pasek jest ukryty
               SizedBox(
                 height: patienceBarHeight + 5, // Wysokość paska + margines
                 child: (!_isLevelingUp)
                   ? AnimatedBuilder(
                       animation: _patienceAnimationController,
                       builder: (context, child) {
                         return Container(
                           width: patienceBarWidth,
                           height: patienceBarHeight,
                           margin: const EdgeInsets.only(bottom: 5), // Odstęp od świnki
                           child: ClipRRect( // Zaokrąglamy rogi paska
                             borderRadius: BorderRadius.circular(patienceBarHeight / 2),
                             child: LinearProgressIndicator(
                               value: _patienceAnimationController.value, // Wartość od 0.0 do 1.0
                               backgroundColor: Colors.grey[300],
                               valueColor: AlwaysStoppedAnimation<Color>(
                                 // Zmieniaj kolor paska w zależności od pozostałego czasu
                                 _patienceAnimationController.value > 0.5
                                     ? Colors.green
                                     : _patienceAnimationController.value > 0.2
                                         ? Colors.orange
                                         : Colors.red,
                               ),
                               minHeight: patienceBarHeight,
                             ),
                           ),
                         );
                       },
                     )
                   : null, // Nie pokazuj nic podczas level up
               ),
               // Świnka
               Container(
                 width: guineaPigSize,
                 height: guineaPigSize,
                 decoration: BoxDecoration(
                   color: Colors.brown[300],
                   shape: BoxShape.circle,
                   boxShadow: [
                     BoxShadow(
                       color: Colors.black.withOpacity(0.2),
                       spreadRadius: 1,
                       blurRadius: 3,
                       offset: const Offset(0, 2),
                     ),
                   ],
                 ),
                 child: const Center(child: Text('🐹', style: TextStyle(fontSize: 40))),
               ),
            ],
          ),


          // Animowane jedzenie na orbicie
          if (!_isLevelingUp)
            AnimatedBuilder(
              animation: _orbitAnimationController,
              builder: (context, child) {
                return Stack(
                  children: _buildOrbitingFoodWidgets(
                    centerX,
                    centerY,
                    orbitRadius,
                    _orbitAnimationController.value * 2 * pi,
                  ),
                );
              },
            ),

          // Wyświetlanie Poziomu i Punktacji
          Positioned(
            top: 10,
            left: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Poziom: $_currentLevel | Punkty: $_score / $_scoreToLevelUp',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ),

          // Komunikat "Level Up!"
          if (_isLevelingUp)
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                 decoration: BoxDecoration(
                   color: Colors.amber.withOpacity(0.85),
                   borderRadius: BorderRadius.circular(20),
                   border: Border.all(color: Colors.white, width: 2),
                   boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        spreadRadius: 2,
                        blurRadius: 5,
                        offset: const Offset(0, 3),
                      ),
                   ]
                 ),
                child: Text(
                  'Level Up!',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white, shadows: [
                     Shadow(blurRadius: 2.0, color: Colors.black.withOpacity(0.5), offset: Offset(1, 1))
                  ]),
                ),
              ),
            ),

        ],
      ),
    );
  }

  // Funkcja generująca widgety jedzenia na orbicie
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
          left: foodX - 22.5,
          top: foodY - 22.5,
          child: _buildFoodItemWidget(foodItem),
        ),
      );
    }
    return foodWidgets;
  }


  // Funkcja pomocnicza do budowania pojedynczego widgetu jedzenia
  Widget _buildFoodItemWidget(FoodItem foodItem) {
    return GestureDetector(
      onTap: () => _handleFoodTap(foodItem),
      child: Container(
        width: 45,
        height: 45,
        decoration: BoxDecoration(
           shape: BoxShape.circle,
           boxShadow: [
             BoxShadow(
               color: Colors.black.withOpacity(0.15),
               spreadRadius: 1,
               blurRadius: 2,
             )
           ]
        ),
        child: Center(child: Text(foodItem.emoji, style: const TextStyle(fontSize: 28))),
      ),
    );
  }
}

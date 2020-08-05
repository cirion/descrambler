// I have no idea what I'm doing.

import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:audioplayers/audioplayers.dart';
import 'package:dart_random_choice/dart_random_choice.dart';
import 'package:english_words/english_words.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lexencrypt/cross_fade.dart';
import 'package:random_string/random_string.dart';
import 'package:rxdart/subjects.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audio_cache.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    sfxPlayer.loadAll([dingAudioPath, wrongAudioPath]);
    musicPlayer.loadAll([musicAudioPath]);
    //return CupertinoApp(title: 'Lexencrypt', home: RandomWords());
    return MaterialApp(
      title: 'Lexencrypt',
      //theme: ThemeData(fontFamily: "RobotoMono"),
      home: RandomWords(),
    );
  }
}

final _gridStreamSubject = PublishSubject<List<List<Box>>>();

Stream<List<List<Box>>> get _gridStream => _gridStreamSubject.stream;

final _gray1Font = TextStyle(
    fontFamily: 'RobotoMono',
    fontSize: 18.0,
    fontFeatures: [FontFeature.tabularFigures()],
    color: Colors.black12);

enum Guess { correct, incorrect, none }

class Box {
  String character;
  TextStyle style;
  int hits;

  Box(this.character, this.style, this.hits);

  Box clone() {
    return Box(character, style, hits);
  }

  @override
  bool operator ==(other) {
    return (other.character == this.character && other.style == this.style);
  }

  @override
  int get hashCode {
    return character.hashCode + style.toStringShort().hashCode;
  }
}

AudioCache sfxPlayer = new AudioCache();
final dingAudioPath = "ding.mp3";
final wrongAudioPath = "wrong.wav";

AudioCache musicPlayer = new AudioCache();
final musicAudioPath = "kai_engel_09_homeroad.mp3";
AudioPlayer activeMusic;

class RandomWordsState extends State<RandomWords> with WidgetsBindingObserver {
  static final _monoFont = TextStyle(
      fontFamily: 'RobotoMono',
      fontSize: 18.0,
      fontFeatures: [FontFeature.tabularFigures()]);
  final _random = Random();

  String _secretWord;
  int _secretWordX;
  int _secretWordY;
  int _columnCount;
  int _rowCount;
  GlobalKey _globalKey = GlobalKey();
  int _rotationIntervalMillis = 100;
  Timer _timer;
  int _victories = 0;
  int _streak = 0;
  DateTime _matchStartTime;
  double _rotationFactor = 0.1;
  int _hitsToReveal = 1;
  Duration _delaysBetweenReveals = Duration(seconds: 30);
  final Duration _extraDelayPerMatch = Duration(seconds: 30);
  DateTime _nextRevealTime;

  int _statTotalSolves;
  int _statLongestStreak;
  Duration _statFastestSolve;
  String _statLongestWord;

  static const String PREFERENCE_CURRENT_VICTORIES = "current_victories";
  static const String PREFERENCE_MUTED = "muted";
  static const String PREFERENCE_STAT_TOTAL_VICTORIES = "total_victories";
  static const String PREFERENCE_STAT_FASTEST_SOLVE = "fastest_solve";
  static const String PREFERENCE_STAT_LONGEST_STREAK = "longest_streak";
  static const String PREFERENCE_STAT_LONGEST_WORD = "longest_word";

  bool _muted = false;

  Guess _guess = Guess.none;

  String _wrongMessage = "";
  String _rightMessage = "";

  List<List<Box>> _grid = new List<List<Box>>();

  final _feedbackStyle = TextStyle(
    color: Colors.white,
  );

  final _fadeDuration = Duration(milliseconds: 500);

  _getWindowHeight() {
    final RenderBox renderBoxRed = _globalKey.currentContext.findRenderObject();
    return renderBoxRed.size.height;
  }

  _getWindowWidth() {
    final RenderBox renderBoxRed = _globalKey.currentContext.findRenderObject();
    return renderBoxRed.size.width;
  }

  _isDesiredChar(int i, int j) {
    if (i == _secretWordY) {
      if (j >= _secretWordX && j < _secretWordX + _secretWord.length) {
        final currentChar = _grid[i][j].character;
        final desiredChar =
            _secretWord.substring(j - _secretWordX, j - _secretWordX + 1);
        return (currentChar.toUpperCase() == desiredChar.toUpperCase());
      }
    }
    return false;
  }

  _generateCharacter() {
    // There's a bug in randomAlpha that causes it to only return capital
    // letters when you request a single character. So, request 2 instead and
    // trim down to the 1 we actually want.
    final value = randomAlpha(2).substring(0, 1);
    if (_victories < 2) {
      return value.toLowerCase();
    } else if (_victories < 4) {
      return value.toUpperCase();
    }
    return value;
  }

  _generateColor() {
    final index = min(_random.nextInt(_victories ~/ 2 + 1), _fonts.length - 1);
    return _fonts[index];
  }

  _generateStartingColor() {
    final index = min(_random.nextInt(_victories ~/ 4 + 1), _fonts.length - 1);
    return _fonts[index];
  }

  static final _startingCharacters = ["-", "|", "/", "\\", "*"];

  static final _wrongMessages = [
    "That's not it…",
    "Not quite…",
    "Try again…",
    "Guess again…",
    "Something else…",
    "I wish…",
    "If only…",
    "…",
    "Maybe another…",
    "It's different…",
  ];

  static final _rightMessages = [
    "That's right!",
    "Way to go!",
    "Keep going!",
    "You got it!",
    "Well played!",
    "Indeed!",
    "Truly!",
    "Nice one!",
    "Excellent!",
    "That's it!",
  ];

  _generateStartingCharacter() {
    if (_victories == 0) {
      return "-";
    } else if (_victories == 1) {
      return "|";
    } else if (_victories == 2) {
      return "/";
    } else if (_victories == 3) {
      return "\\";
    } else if (_victories == 4) {
      return "*";
    } else {
      return _startingCharacters[
          _random.nextInt(_startingCharacters.length - 1)];
    }
  }

  _generateSecretWord() {
    _secretWord = randomChoice(nouns
        .toList()
        .where((element) => element.length >= 6 && element.length <= 12));
    debugPrint("Secret word is $_secretWord");

    final secretWordLength = _secretWord.length;

    _grid = new List(_rowCount);
    for (int i = 0; i < _rowCount; ++i) {
      _grid[i] = new List(_columnCount);
      for (int j = 0; j < _columnCount; ++j) {
        _grid[i][j] =
            Box(_generateStartingCharacter(), _generateStartingColor(), 0);
      }
    }

    setState(() {
      _secretWordX = _random.nextInt(_columnCount - secretWordLength);
      _secretWordY = _random.nextInt(_rowCount);
      _nextRevealTime = DateTime.now().add(_delaysBetweenReveals);
      _matchStartTime = DateTime.now();
    });
    _timer?.cancel();
    _timer = Timer.periodic(Duration(milliseconds: _rotationIntervalMillis),
        (timer) {
      final charsToRotate =
          (_rowCount * _columnCount * _rotationFactor).toInt();
      for (int i = 0; i < charsToRotate; ++i) {
        final i = _random.nextInt(_rowCount);
        final j = _random.nextInt(_columnCount);

        final box = _grid[i][j];

        if (_isDesiredChar(i, j)) {
          if (DateTime.now().isAfter(_nextRevealTime)) {
            box.hits = box.hits + 1;
            if (box.hits >= _hitsToReveal) {
              box.style = _hintFont;
              _nextRevealTime = DateTime.now().add(_delaysBetweenReveals);
            }
          }
          continue;
        }
        box.character = _generateCharacter();
        box.style = _generateColor();
      }
      // Rebuilding the whole screen is expensive, so instead we publish the
      // update event, and let each leaf-node child in the grid decide whether
      // it needs to invalidate.
      _gridStreamSubject.add(_grid);
    });
  }

  _afterLayout(_) {
//    _initBoard();
  }

  _initBoard() {
    Future.delayed(const Duration(milliseconds: 500), () {
      final Size txtSize = _textSize("M", _monoFont);
      final glyphWidth = txtSize.width;
      final glyphHeight = txtSize.height;

      _rowCount = (_getWindowHeight() ~/ glyphHeight);

      _columnCount = _getWindowWidth() ~/ glyphWidth;

      _generateSecretWord();
    });
  }

  Size _textSize(String text, TextStyle style) {
    final TextPainter textPainter = TextPainter(
        text: TextSpan(text: text, style: style),
        maxLines: 1,
        textDirection: TextDirection.ltr)
      ..layout(minWidth: 0, maxWidth: double.infinity);
    return textPainter.size;
  }

  FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();

    _loadSave();

    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback(_afterLayout);

    _focusNode.addListener(() {
      if (_rowCount == null) {
        _initBoard();
      }
      if (!_focusNode.hasFocus) {
        FocusScope.of(context).requestFocus(_focusNode);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || _muted) {
      activeMusic.pause();
    } else {
      _startPlayingMusic();
    }
  }

  _startPlayingMusic() async {
    if (activeMusic == null) {
      final futureMusic = musicPlayer.play(musicAudioPath);
      Future.wait([
        () async {
          activeMusic = await futureMusic;
          _updateMusicState();
        }()
      ]);
    } else {
      activeMusic.resume();
    }
  }

  _updateMusicState() {
    if (_muted) {
      activeMusic?.setVolume(0.0);
    } else {
      activeMusic?.setVolume(1.0);
      _startPlayingMusic();
    }
  }

  _loadSave() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    debugPrint("Setting state");
    final fastestSolveSeconds = prefs.getInt(PREFERENCE_STAT_FASTEST_SOLVE);
    final fastestSolveDuration = fastestSolveSeconds == null
        ? null
        : Duration(seconds: fastestSolveSeconds);
    setState(() {
      _victories = (prefs.getInt(PREFERENCE_CURRENT_VICTORIES) ?? 0);
      _muted = (prefs.getBool(PREFERENCE_MUTED) ?? false);
      _statTotalSolves = (prefs.getInt(PREFERENCE_STAT_TOTAL_VICTORIES) ?? 0);
      _statFastestSolve = fastestSolveDuration;
      _statLongestStreak = (prefs.getInt(PREFERENCE_STAT_LONGEST_STREAK) ?? 0);
      _statLongestWord = (prefs.getString(PREFERENCE_STAT_LONGEST_WORD));
    });
  }

  var _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final appBar = AppBar(
      title: Text('Lexencrypt'),
      backgroundColor: Colors.lightGreen,
    );

    void _toggleAudio() async {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      prefs.setBool(PREFERENCE_MUTED, !_muted);
      setState(() {
        _muted = !_muted;
      });
    }

    void _restart() async {
      // Also starting message, etc.
      setState(() {
        _victories = 0;
        _streak = 0;
        _guess = Guess.none;
        _wrongMessage = "";
        _rightMessage = "";
        _delaysBetweenReveals = Duration(seconds: 30);
      });
      SharedPreferences prefs = await SharedPreferences.getInstance();
      prefs.setInt(PREFERENCE_CURRENT_VICTORIES, 0);

      _initBoard();
    }

    void _openInfo() async {
      final statsList = <Widget>[
        Text("Total Solves: $_statTotalSolves"),
        Text("Longest Streak: $_statLongestStreak"),
      ];
      if (_statLongestWord != null) {
        statsList.add(Text("Longest Word: $_statLongestWord"));
      }
      if (_statFastestSolve != null) {
        statsList.add(Text(
            "Fastest Solve: ${_statFastestSolve.toString().substring(2, 7)}"));
      }

      final actionsList = <Widget>[
        FlatButton(
          child: Text("Continue"),
          onPressed: () {
            Navigator.of(context).pop();
          },
        )
      ];
      if (_secretWord != null && _victories > 0) {
        actionsList.insert(
            0,
            FlatButton(
              child: Text("Restart"),
              onPressed: () {
                _restart();
                Navigator.of(context).pop();
              },
            ));
      }

      // TODO: Use Cupertino dialog for iOS.
      showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: statsList,
              ),
              actions: actionsList,
            );
          });
    }

    void _handleSubmitted(String value) async {
      if (value.trim().toLowerCase() == _secretWord.toLowerCase()) {
        if (!_muted) {
          sfxPlayer.play(dingAudioPath);
        }

        SharedPreferences prefs = await SharedPreferences.getInstance();
        prefs.setInt(PREFERENCE_CURRENT_VICTORIES, _victories + 1);
        prefs.setInt(PREFERENCE_STAT_TOTAL_VICTORIES, _statTotalSolves + 1);
        if (_streak + 1 > _statLongestStreak) {
          prefs.setInt(PREFERENCE_STAT_LONGEST_STREAK, _streak + 1);
        }

        final solveTime = DateTime.now().difference(_matchStartTime);
        if (_statFastestSolve == null ||
            solveTime.compareTo(_statFastestSolve) < 0) {
          prefs.setInt(PREFERENCE_STAT_FASTEST_SOLVE, solveTime.inSeconds);
        }

        if (_statLongestWord == null ||
            value.length >= _statLongestWord.length) {
          prefs.setString(PREFERENCE_STAT_LONGEST_WORD, value);
        }

        final messageIndex = _random.nextInt(_rightMessages.length) - 1;

        setState(() {
          _guess = Guess.correct;
          _rightMessage = _rightMessages[messageIndex];
          _victories = _victories + 1;
          _streak = _streak + 1;
          if (_streak > _statLongestStreak) {
            _statLongestStreak = _streak;
          }
          if (_statFastestSolve == null ||
              solveTime.compareTo(_statFastestSolve) < 0) {
            _statFastestSolve = solveTime;
          }
          if (_statLongestWord == null ||
              value.length >= _statLongestWord.length) {
            _statLongestWord = value;
          }
          _statTotalSolves = _statTotalSolves + 1;
          _delaysBetweenReveals = Duration(
              seconds: _delaysBetweenReveals.inSeconds +
                  _extraDelayPerMatch.inSeconds);
        });

        _generateSecretWord();
      } else {
        if (!_muted) {
          sfxPlayer.play(wrongAudioPath);
        }
        final messageIndex = _random.nextInt(_wrongMessages.length);
        setState(() {
          _guess = Guess.incorrect;
          _wrongMessage = _wrongMessages[messageIndex];
          _streak = 0;
        });
      }
    }

    /*
    final incorrectOpacity = AnimatedOpacity(
      // If the widget is visible, animate to 0.0 (invisible).
      // If the widget is hidden, animate to 1.0 (fully visible).
      opacity: _guess == Guess.incorrect ? 1.0 : 0.0,
      duration: _fadeDuration,
      child: Center(
          child: Text(
        _wrongMessage,
        style: _feedbackStyle,
      )),
    );
     */

    String newString = "";
    if (_guess == Guess.correct) {
      newString = _rightMessage;
    } else if (_guess == Guess.incorrect) {
      newString = _wrongMessage;
    } else if (_guess == Guess.none && _rowCount != null) {
      newString = "What is the word?";
    }

    final feedback = CrossFade<String>(
      initialData: "",
      data: newString,
      builder: (value) => Center(
        child: Text(value,
        style: _feedbackStyle
        ),
      ),
    );

    /*
    final correctOpacity = AnimatedOpacity(
      // If the widget is visible, animate to 0.0 (invisible).
      // If the widget is hidden, animate to 1.0 (fully visible).
      opacity: _guess == Guess.correct ? 1.0 : 0.0,
      duration: _fadeDuration,
      child: Center(
          child: Text(
        _rightMessage,
        style: _feedbackStyle,
      )),
    );

    final noneOpacity = AnimatedOpacity(
      // If the widget is visible, animate to 0.0 (invisible).
      // If the widget is hidden, animate to 1.0 (fully visible).
      opacity: _guess == Guess.none ? 1.0 : 0.0,
      duration: _fadeDuration,
      child: Center(
          child: Text(
        (_rowCount == null) ? "" : "What is the word?",
        style: _feedbackStyle,
      )),
    );
     */

    final solved = Align(
        alignment: Alignment.centerLeft,
        child: Padding(
            padding: EdgeInsets.all(8.0),
            child: Text(
              " Solved $_victories",
              textAlign: TextAlign.start,
              style: _feedbackStyle,
            ))
        //)
        );

    /*
    final victory = Align(
        alignment: Alignment.centerRight,
        // TODO: Cupertino button here?
        child: FlatButton(
          onPressed: _launchURL,
          child: Text("More..."),
        ));

     */

    final Widget mutedSvg = SvgPicture.asset("assets/music_off-white-24dp.svg");
    final Widget unMutedSvg =
        SvgPicture.asset("assets/music_note-white-24dp.svg");
    final audioImage = (_muted) ? mutedSvg : unMutedSvg;
    final Widget infoSvg = SvgPicture.asset("assets/info-white-24dp.svg");

    final buttons = Align(
        alignment: Alignment.centerRight,
        child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          AspectRatio(
              aspectRatio: 1.0,
              child: FlatButton(
                onPressed: _openInfo,
                padding: EdgeInsets.all(0.0),
                child: infoSvg,
              )),
          AspectRatio(
              aspectRatio: 1.0,
              child: FlatButton(
                onPressed: _toggleAudio,
                padding: EdgeInsets.all(0.0),
                child: audioImage,
              )),
        ]));

    _updateMusicState();

    final stack = Stack(
      alignment: Alignment.center,
      children: <Widget>[
        feedback,
        //incorrectOpacity,
        //correctOpacity,
        //noneOpacity,
      ],
    );

    if (_victories > 0) stack.children.add(solved);
    stack.children.add(buttons);

    final topContainer = Container(
      child: (_rowCount == 0) ? null : stack,
      color: Colors.blue,
      height: 40,
    );

    final decoration = InputDecoration(
      border: OutlineInputBorder(),
      labelText: (_rowCount == null) ? 'Tap to start' : null,
    );

    final _textField = TextField(
      decoration: decoration,
      controller: _controller,
      onSubmitted: (newValue) {
        _handleSubmitted(newValue);
        _controller.clear();
      },
      focusNode: _focusNode,
      keyboardType: TextInputType.text,
//      autofocus: true,
//      decoration: InputDecoration(),
    );

    /*
    final _cupertinoTextField = CupertinoTextField(
      controller: _controller,
      onSubmitted: (newValue) {
        _handleSubmitted(newValue);
        _controller.clear();
      },
      focusNode: _focusNode,
      keyboardType: TextInputType.text,
      autofocus: true,
    );

     */

    final children = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        topContainer,
        _buildGrid(),
        _textField,
//        _cupertinoTextField,
      ],
    );

    /*
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CupertinoColors.activeGreen,
        middle: Text("Lexencrypt"),
      ),
      child: children,
    );

     */

    //_focusNode.requestFocus();

    return Scaffold(
      appBar: appBar,
      body: children,
    );
  }

  Widget _buildGrid() {
    if (_columnCount == null) {
      return Expanded(
        key: _globalKey,
        child: Padding(
            padding: EdgeInsets.all(8.0),
            child: Container(
                width: double.infinity,
                height: double.infinity,
                child: Center(
                    child: Text(
                  "Welcome!",
                )))),
      );
    }
    final rowCount = _grid.length;
    final rows = new List<Widget>(rowCount);
    for (int i = 0; i < rowCount; ++i) {
      rows[i] = _buildRow(i);
    }
    return Expanded(
        child: Column(
      key: _globalKey,
      mainAxisAlignment: MainAxisAlignment.start,
      verticalDirection: VerticalDirection.down,
      textDirection: TextDirection.ltr,
      textBaseline: TextBaseline.alphabetic,
      mainAxisSize: MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    ));
  }

  Widget _buildRow(int index) {
    final chars = new List<Widget>(_columnCount);
    for (int i = 0; i < _columnCount; ++i) {
      final box = _grid[index][i];
      chars[i] = StyledBox(index, i, box);
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      mainAxisSize: MainAxisSize.max,
      textBaseline: TextBaseline.ideographic,
      textDirection: TextDirection.ltr,
      children: chars,
    );
  }

  static final _gray2Font = TextStyle(
      fontFamily: 'RobotoMono',
      fontSize: 18.0,
      fontFeatures: [FontFeature.tabularFigures()],
      color: Colors.black26);
  static final _gray3Font = TextStyle(
      fontFamily: 'RobotoMono',
      fontSize: 18.0,
      fontFeatures: [FontFeature.tabularFigures()],
      color: Colors.black38);
  static final _gray4Font = TextStyle(
      fontFamily: 'RobotoMono',
      fontSize: 18.0,
      fontFeatures: [FontFeature.tabularFigures()],
      color: Colors.black45);
  static final _gray5Font = TextStyle(
      fontFamily: 'RobotoMono',
      fontSize: 18.0,
      fontFeatures: [FontFeature.tabularFigures()],
      color: Colors.black54);
  static final _gray6Font = TextStyle(
      fontFamily: 'RobotoMono',
      fontSize: 18.0,
      fontFeatures: [FontFeature.tabularFigures()],
      color: Colors.black87);
  static final _fonts = [
    _monoFont,
    _gray6Font,
    _gray5Font,
    _gray4Font,
    _gray3Font,
    _gray2Font,
    _gray1Font,
  ];
  final _hintFont = TextStyle(
      fontFamily: 'RobotoMono',
      fontSize: 18.0,
      fontFeatures: [FontFeature.tabularFigures()],
      color: Colors.redAccent);
}

class RandomWords extends StatefulWidget {
  @override
  RandomWordsState createState() => RandomWordsState();
}

class StyledBoxState extends State<StyledBox> {
  final int _x;
  final int _y;

  Box _box;

  StyledBoxState(this._x, this._y, this._box) {
    _gridStream.listen((grid) {
      final box = grid[_x][_y];
      if (box != _box) {
        setState(() {
          _box = box.clone();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _box.character,
      style: _box.style,
      softWrap: false,
      overflow: TextOverflow.clip,
      maxLines: 1,
    );
  }
}

class StyledBox extends StatefulWidget {
  final int _x;
  final int _y;
  final Box _box;

  StyledBox(this._x, this._y, this._box);

  @override
  StyledBoxState createState() => StyledBoxState(_x, _y, _box.clone());
}

/*
Release checklist:

Stretch:
* More feedback messages (especially failure). Fade into "What is it?" and
  between failure messages.

Post-launch:
* Background and foreground support w/timer
* Change background colors
* Credits?

Thoughts on game progression:
Now that state can be saved, I'd like to extend the "discoveries" a bit more.

Items to vary could include:
Initial fill characters
Casing (lower, upper, mixed)
Font colors (gray, much later do colors?)
Backgrounds (maybe fade & stick per board for a while, then fade in-game?)
Music

Possible progression:
1: *, lower case, black
2: -, lower case, black
3: -, upper case, black
4: |, upper case, black
5: /, upper case, black
6-9: random chars to start, upper case, black
10+: Mixed case
15: 2 tones of characters.
20: Music starts.
25: 3 tones of characters.
30: Solid background fades.
35: 4 tones of characters.
40: Pulsating backgrounds.
45: 5 tones of characters.
50: Multicolored fonts. (Hm, maybe tones should be alpha value instead of gray shades?)

This is probably good for a version 1.1. Future enhancements could include:
* Pictures in background.
* Moving words in background.
* Off-centered letter positions.
* Vertical words (stretch goal! and beware of limited height on some screens)
* Diagonal words (as above).
* Confirmation on Restart?

Bugs:
* As of 6/14/2020, autofocus does not work on profile or release builds. Working around this by requiring manual focus.
* Music sometimes doesn't immediately stop when backgrounded or stopped. And/or duplicate music can play when re-launching.
* There's some extra padding between the buttons and the content of the AlertDialog.

*/

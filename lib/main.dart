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
import 'package:random_string/random_string.dart';
import 'package:rxdart/subjects.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
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
    final futureMusic = musicPlayer.play(musicAudioPath);
    Future.wait(
      [
        () async { activeMusic = await futureMusic; } ()
      ]
    );
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
      fontSize: 18.0, fontFeatures: [FontFeature.tabularFigures()]);
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
  double _rotationFactor = 0.1;
  int _hitsToReveal = 1;
  Duration _delaysBetweenReveals = Duration(seconds: 30);
  final Duration _extraDelayPerMatch = Duration(seconds: 30);
  DateTime _nextRevealTime;

  bool muted = false;

  Guess _guess = Guess.none;

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

//      print("txtSize after layout is $glyphWidth x $glyphHeight");

      _rowCount = (_getWindowHeight() ~/ glyphHeight);

      _columnCount = _getWindowWidth() ~/ glyphWidth;

//      print("Got $_rowCount rows and $_columnCount columns.");

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

    _loadSave();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      // TODO: Only if on a music-enabled stage.
      activeMusic.pause();
    } else {
      activeMusic.resume();
    }
    //setState(() { _notification = state; });
  }

  _loadSave() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _victories = (prefs.getInt('victories') ?? 0);
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
      setState(() {
        muted = !muted;
      });
    }

    void _handleSubmitted(String value) async {
      if (value.trim().toLowerCase() == _secretWord.toLowerCase()) {
        if (!muted) {
          sfxPlayer.play(dingAudioPath);
        }

        SharedPreferences prefs = await SharedPreferences.getInstance();
        prefs.setInt("victories", _victories + 1);

        setState(() {
          _guess = Guess.correct;
          _victories = _victories + 1;
          _delaysBetweenReveals = Duration(
              seconds: _delaysBetweenReveals.inSeconds +
                  _extraDelayPerMatch.inSeconds);
        });

        _generateSecretWord();
      } else {
        if (!muted) {
          sfxPlayer.play(wrongAudioPath);
        }
        setState(() {
          _guess = Guess.incorrect;
        });
      }
    }

    final incorrectOpacity = AnimatedOpacity(
      // If the widget is visible, animate to 0.0 (invisible).
      // If the widget is hidden, animate to 1.0 (fully visible).
      opacity: _guess == Guess.incorrect ? 1.0 : 0.0,
      duration: _fadeDuration,
      child: Center(
          child: Text(
        "That's not it...",
        style: _feedbackStyle,
      )),
    );

    final correctOpacity = AnimatedOpacity(
      // If the widget is visible, animate to 0.0 (invisible).
      // If the widget is hidden, animate to 1.0 (fully visible).
      opacity: _guess == Guess.correct ? 1.0 : 0.0,
      duration: _fadeDuration,
      child: Center(
          child: Text(
        "That's right!",
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

    final muteButton = Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints.expand(),
        child: FlatButton(
          onPressed: _toggleAudio,
          padding: EdgeInsets.all(0.0),
          child: mutedSvg,
        )
      )
    );

    if (muted) {
      activeMusic.setVolume(0.0);
    } else {
      activeMusic.setVolume(1.0);
    }

    final stack = Stack(
      alignment: Alignment.center,
      children: <Widget>[
        incorrectOpacity,
        correctOpacity,
        noneOpacity,
      ],
    );

    if (_victories > 0) stack.children.add(solved);
    //if (_victories > 2) stack.children.add(victory);
    stack.children.add(muteButton);

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
* More feedback messages (especially failure). Test fade.
* Bundle RobotoMono font into app assets and remove Internet permission.

Post-launch:
* Save high score
* Track time (per-board and/or total)
* Background and foreground support w/timer
* Button to restart
* Music
* Change background colors
* Remove "More..." button

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

Thoughts on UI:
* Mute (toggle on/off).
* Restart with confirmation
* Stats (maybe an icon near Mute? )
  * Total solves
  * Fastest solve
  * Longest correct streak
  *

Bugs:
* As of 6/14/2020, autofocus does not work on profile or release builds. Working around this by requiring manual focus.

*/

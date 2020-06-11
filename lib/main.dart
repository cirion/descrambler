// I have no idea what I'm doing.

import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:dart_random_choice/dart_random_choice.dart';
import 'package:english_words/english_words.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:random_string/random_string.dart';
import 'package:url_launcher/url_launcher.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    return MaterialApp(title: 'Lexencrypt', home: RandomWords());
  }
}

enum Guess { correct, incorrect, none }

class RandomWordsState extends State<RandomWords> {
  static final _monoFont = GoogleFonts.robotoMono(
      fontSize: 18.0, fontFeatures: [FontFeature.tabularFigures()]);
  static final _gray1Font = GoogleFonts.robotoMono(
      fontSize: 18.0,
      fontFeatures: [FontFeature.tabularFigures()],
      color: Colors.black12);
  static final _gray2Font = GoogleFonts.robotoMono(
      fontSize: 18.0,
      fontFeatures: [FontFeature.tabularFigures()],
      color: Colors.black26);
  static final _gray3Font = GoogleFonts.robotoMono(
      fontSize: 18.0,
      fontFeatures: [FontFeature.tabularFigures()],
      color: Colors.black38);
  static final _gray4Font = GoogleFonts.robotoMono(
      fontSize: 18.0,
      fontFeatures: [FontFeature.tabularFigures()],
      color: Colors.black45);
  static final _gray5Font = GoogleFonts.robotoMono(
      fontSize: 18.0,
      fontFeatures: [FontFeature.tabularFigures()],
      color: Colors.black54);
  static final _gray6Font = GoogleFonts.robotoMono(
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
  final _hintFont = GoogleFonts.robotoMono(
      fontSize: 18.0,
      fontFeatures: [FontFeature.tabularFigures()],
      color: Colors.redAccent);
  final _random = Random();

  String _secretWord;
  int _secretWordX;
  int _secretWordY;
  int _columnCount;
  int _rowCount;
  GlobalKey _globalKey = GlobalKey();
  String _inputWord = "";
  int _rotationIntervalMillis = 100;
  Timer _timer;
  int _victories = 0;
  double _rotationFactor = 0.1;
  int _hitsToReveal = 1;
  Duration _delaysBetweenReveals = Duration(seconds: 30);
  final Duration _extraDelayPerMatch = Duration(seconds: 30);
  DateTime _nextRevealTime;

  Guess _guess = Guess.none;

  List<List<String>> _characters = new List<List<String>>();
  List<List<int>> _characterHits = new List<List<int>>();
  List<List<int>> _colorIndex = new List<List<int>>();

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
        final currentChar = _characters[i][j];
        final desiredChar =
            _secretWord.substring(j - _secretWordX, j - _secretWordX + 1);
        return (currentChar.toUpperCase() == desiredChar.toUpperCase());
      }
    }
    return false;
  }

  _generateCharacter() {
    final value = randomAlpha(2).substring(0, 1);
    if (_victories < 2) {
      return value.toLowerCase();
    } else if (_victories < 4) {
      return value.toUpperCase();
    }
    return value;
  }

  _generateColorIndex() {
    // TODO: Maybe scale this based on difficulty?
//    return _random.nextInt(_fonts.length) ~/ 2;
    return 0;
  }

  _generateSecretWord() {
    _secretWord = randomChoice(nouns
        .toList()
        .where((element) => element.length >= 6 && element.length <= 12));

    final secretWordLength = _secretWord.length;

    _characters = new List(_rowCount);
    _characterHits = new List(_rowCount);
    _colorIndex = new List(_rowCount);
    for (int i = 0; i < _rowCount; ++i) {
      _characters[i] = new List(_columnCount);
      _characterHits[i] = new List(_columnCount);
      _colorIndex[i] = new List(_columnCount);
      for (int j = 0; j < _columnCount; ++j) {
        _characters[i][j] = "-";
        _characterHits[i][j] = 0;
        _colorIndex[i][j] = _generateColorIndex();
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

        if (_isDesiredChar(i, j)) {
          if (DateTime.now().isAfter(_nextRevealTime)) {
            _characterHits[i][j] = _characterHits[i][j] + 1;
            _nextRevealTime = DateTime.now().add(_delaysBetweenReveals);
          }
          continue;
        }
        _characters[i][j] = _generateCharacter();
        _colorIndex[i][j] = _chooseColorIndex();
      }
      setState(() {});
    });
  }

  _afterLayout(_) {
    Future.delayed(const Duration(milliseconds: 1000), () {
      final Size txtSize = _textSize("M", _monoFont);
      final glyphWidth = txtSize.width;
      final glyphHeight = txtSize.height;

      print("txtSize after layout is $glyphWidth x $glyphHeight");

      _rowCount = (_getWindowHeight() ~/ glyphHeight);

      _columnCount = _getWindowWidth() ~/ glyphWidth;

      print("Got $_rowCount rows and $_columnCount columns.");

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

    WidgetsBinding.instance.addPostFrameCallback(_afterLayout);

    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        FocusScope.of(context).requestFocus(_focusNode);
      }
    });
  }

  var _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final appBar = AppBar(
      title: Text('Lexencrypt'),
      backgroundColor: Colors.lightGreen,
    );

    final input = Text(
      _inputWord,
      style: _monoFont,
    );

    void _handleSubmitted(String value) {
      if (value.toLowerCase() == _secretWord.toLowerCase()) {
        setState(() {
          _guess = Guess.correct;
          _victories = _victories + 1;
          //_hitsToReveal = _hitsToReveal + 20;
          _delaysBetweenReveals = Duration(
              seconds: _delaysBetweenReveals.inSeconds +
                  _extraDelayPerMatch.inSeconds);
        });
        _generateSecretWord();
      } else {
        setState(() {
          _guess = Guess.incorrect;
        });
      }
    }

    final incorrectOpacity = AnimatedOpacity(
      // If the widget is visible, animate to 0.0 (invisible).
      // If the widget is hidden, animate to 1.0 (fully visible).
      opacity: _guess == Guess.incorrect ? 1.0 : 0.0,
      duration: Duration(milliseconds: 500),
      // The green box must be a child of the AnimatedOpacity widget.
      child: Center(
          child: Text(
        "That's not it...",
        style: TextStyle(
          color: Colors.white,
        ),
      )),
    );

    final correctOpacity = AnimatedOpacity(
      // If the widget is visible, animate to 0.0 (invisible).
      // If the widget is hidden, animate to 1.0 (fully visible).
      opacity: _guess == Guess.correct ? 1.0 : 0.0,
      duration: Duration(milliseconds: 500),
      // The green box must be a child of the AnimatedOpacity widget.
      child: Center(
          child: Text(
        "Yes!",
        style: TextStyle(
          color: Colors.white,
        ),
      )),
    );

    final noneOpacity = AnimatedOpacity(
      // If the widget is visible, animate to 0.0 (invisible).
      // If the widget is hidden, animate to 1.0 (fully visible).
      opacity: _guess == Guess.none ? 1.0 : 0.0,
      duration: Duration(milliseconds: 500),
      // The green box must be a child of the AnimatedOpacity widget.
      child: Center(
          child: Text(
        "What is it?",
        style: TextStyle(
          color: Colors.black87,
        ),
      )),
    );

    final solved = Align(
        alignment: Alignment.centerLeft,
        child: Text(
          "Solved $_victories",
          textAlign: TextAlign.start,
        ));

    _launchURL() async {
      const url = 'https://velosmobile.com';
      if (await canLaunch(url)) {
        await launch(url);
      } else {
        throw 'Could not launch $url';
      }
    }

    final victory = Align(
        alignment: Alignment.centerRight,
        child: FlatButton(
          onPressed: _launchURL,
          child: Text("Celebrate!"),
        ));

    final stack = Stack(
      alignment: Alignment.center,
      children: <Widget>[
        incorrectOpacity,
        correctOpacity,
        noneOpacity,
      ],
    );

    if (_victories > 0) stack.children.add(solved);
    if (_victories > 1) stack.children.add(victory);

    final topContainer = Container(
      child: stack,
      color: Colors.blue,
      height: 40,
    );

    final textField = TextField(
      controller: _controller,
      onSubmitted: (newValue) {
        _handleSubmitted(newValue);
        _controller.clear();
      },
      focusNode: _focusNode,
      keyboardType: TextInputType.text,
      autofocus: true,
      decoration: InputDecoration(),
    );

    final children = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        topContainer,
        _buildGrid(),
        textField,
        input,
      ],
    );

    return Scaffold(
      appBar: appBar,
      body: children,
    );
  }

  Widget _buildGrid() {
    if (_columnCount == null) {
      return Expanded(
        key: _globalKey,
        child: Container(
            width: double.infinity,
            height: double.infinity,
            child: Text(
              "Loading...",
            )),
      );
    }
    final rowCount = _characters.length;
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

  int _chooseColorIndex() {
    return _random.nextInt(_fonts.length);
  }

  Widget _buildRow(int index) {
    final chars = new List<Widget>(_columnCount);
    for (int i = 0; i < _columnCount; ++i) {
      // TODO: Maybe I should get rid of _characterHits and just directly set the hint in _colorIndex?
      final font = (_characterHits[index][i] >= _hitsToReveal)
          ? _hintFont
          : _fonts[_colorIndex[index][i]];
      chars[i] = Text(
        _characters[index][i],
        style: font,
        softWrap: false,
        overflow: TextOverflow.clip,
        maxLines: 1,
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      mainAxisSize: MainAxisSize.max,
      textBaseline: TextBaseline.ideographic,
      textDirection: TextDirection.ltr,
      children: chars,
    );
  }
}

class RandomWords extends StatefulWidget {
  @override
  RandomWordsState createState() => RandomWordsState();
}

/*
Release checklist:
* Change font colors
* Change background colors
* lower / upper / mixed-case
* Select numbers based on total character count

Bonus:
* Change default / initial characters
* Play music?
 */

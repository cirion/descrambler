// I have no idea what I'm doing.

import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:dart_random_choice/dart_random_choice.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:english_words/english_words.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:random_string/random_string.dart';
import 'package:virtual_keyboard/virtual_keyboard.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    print("Building app.");
    return MaterialApp(title: 'Startup Name Generator', home: RandomWords());
  }
}

class RandomWordsState extends State<RandomWords> {
  List<String> _suggestions = new List<String>();
  final _monoFont = GoogleFonts.robotoMono(
      fontSize: 18.0, fontFeatures: [FontFeature.tabularFigures()]);
  String _secretWord;
  int _secretWordX;
  int _secretWordY;
  int _columnCount;
  double _appBarHeight;
  GlobalKey _globalKey = GlobalKey();

  List<List<String>> _characters = new List<List<String>>();

  _getWindowHeight() {
    final RenderBox renderBoxRed = _globalKey.currentContext.findRenderObject();
    return renderBoxRed.size.height;
  }

  _getWindowWidth() {
    final RenderBox renderBoxRed = _globalKey.currentContext.findRenderObject();
    return renderBoxRed.size.width;
  }

  _afterLayout(_) {
    Future.delayed(const Duration(milliseconds: 1000), () {

      final Size txtSize = _textSize("M", _monoFont);
      final glyphWidth = txtSize.width;
      final glyphHeight = txtSize.height;

      print("txtSize after layout is $glyphWidth x $glyphHeight");

      final int rowCount = (_getWindowHeight() ~/ glyphHeight);
      print("Got $rowCount rows");

      _columnCount = _getWindowWidth() ~/ glyphWidth;

      _secretWord = randomChoice(nouns.toList().where((element) => element.length >= 6 && element.length <= 12));
      final secretWordLength = _secretWord.length;

      _characters = new List(rowCount);
      for (int i = 0; i < rowCount; ++i) {
        _characters[i] = new List(_columnCount);
        for (int j = 0; j < _columnCount; ++j) {
          _characters[i][j] = randomAlpha(2).substring(0, 1);
        }
      }

      if (_suggestions == null || _suggestions.length == 0) {
        setState(() {
          _secretWordX = Random().nextInt(_columnCount - secretWordLength);
          _secretWordY = Random().nextInt(rowCount);
        });
        Timer.periodic(const Duration(milliseconds: 200), (timer) {
          print("Tick.");
          for (int i = 0; i < rowCount; ++i) {
            for (int j = 0; j < _columnCount; ++j) {
              if (i == _secretWordY) {
                if (j >= _secretWordX && j < _secretWordX + secretWordLength) {
                  final currentChar = _characters[i][j];
                  final desiredChar =_secretWord.substring(j - _secretWordX, j - _secretWordX + 1);
                  print("Have $currentChar, want $desiredChar");
                  if (currentChar.toUpperCase() == desiredChar.toUpperCase()) {
                    continue;
                  }
                }
              }
              _characters[i][j] = randomAlpha(2).substring(0, 1);
            }
          }
          setState(() {
          });
        });
      }
    });
  }

  Size _textSize(String text, TextStyle style) {
    final TextPainter textPainter = TextPainter(
        text: TextSpan(text: text, style: style),
        maxLines: 1,
        textDirection: TextDirection.ltr)
      ..layout(minWidth: 0, maxWidth: double.infinity);
    final lineHeight = textPainter.preferredLineHeight;
    final metrics = textPainter.computeLineMetrics()[0];
    final metricH = metrics.height;
    final metricAscent = metrics.ascent;
    final metricDescent = metrics.descent;
    final metricUnscaledAscent = metrics.unscaledAscent;
    final metricBaseline = metrics.baseline;
    print ("Computed text info (want 24): $lineHeight / $metricH / $metricAscent / $metricDescent / $metricUnscaledAscent / $metricBaseline");
    return textPainter.size;
  }

  @override
  void initState() {
    super.initState();
    print("initState");
    WidgetsBinding.instance.addPostFrameCallback(_afterLayout);
  }

  @override
  Widget build(BuildContext context) {
    final appBar = AppBar(
      title: Text('Startup Name Generator'),
    );
    final appBarSize = appBar.preferredSize.height;
    _appBarHeight = appBarSize;

    final keyboard = Container(
      // Keyboard is transparent
      color: Colors.red,
      child: VirtualKeyboard(
        // [0-9] + .
          type: VirtualKeyboardType.Alphanumeric,
          // Callback for key press event
          onKeyPress: (key) => print(key.text)),
    );
    final children = Column(
      children: <Widget>[_buildSuggestions(), keyboard],
    );

    return Scaffold(
      appBar: appBar,
      body: children,
    );
  }

  Widget _buildSuggestions() {
    if (_columnCount == null) {
      return Expanded(
        key: _globalKey,
        child: Container(
          width: double.infinity,
            height: double.infinity,
            child: Text("Loading...",
        )
      ),
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

  Widget _buildRow(int index) {
    final chars = new List<Widget>(_columnCount);
    for (int i = 0; i < _columnCount; ++i) {
        chars[i] = Text(
          _characters[index][i],
          style: _monoFont,
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

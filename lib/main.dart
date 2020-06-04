// Copyright 2018 The Flutter team. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math';
import 'dart:ui';

import 'package:dart_random_choice/dart_random_choice.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:english_words/english_words.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:google_fonts/google_fonts.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    print("Building app.");
    return MaterialApp(title: 'Startup Name Generator', home: RandomWords());
  }
}

class RandomWordsState extends State<RandomWords> {
  //final _suggestions = <WordPair>[];
  List<String> _suggestions = new List<String>();
  //final _biggerFont = const TextStyle(fontSize: 18.0, fontFeatures: [FontFeature.tabularFigures()]);
  final _biggerFont = GoogleFonts.robotoMono(
      fontSize: 18.0, fontFeatures: [FontFeature.tabularFigures()]);
  final _secretWord = randomChoice(nouns);
  double glyphHeight;
  double glyphWidth;
  int columnCount;

  //creating Key for red panel
  GlobalKey _keyRed = GlobalKey();

  _getSizes() {
    final RenderBox renderBoxRed = _keyRed.currentContext.findRenderObject();
    final sizeRed = renderBoxRed.size;
    print("SIZE of Red: $sizeRed");
  }

  _getPositions() {
    final RenderBox renderBoxRed = _keyRed.currentContext.findRenderObject();
    final positionRed = renderBoxRed.localToGlobal(Offset.zero);
    print("POSITION of Red: $positionRed ");
  }

  _getWindowHeight() {
    final RenderBox renderBoxRed = _keyRed.currentContext.findRenderObject();
    return renderBoxRed.size.height;
  }

  _getWindowWidth() {
    final RenderBox renderBoxRed = _keyRed.currentContext.findRenderObject();
    return renderBoxRed.size.width;
  }

  _afterLayout(_) {
    _getSizes();
    _getPositions();
    final int rowCount = (_getWindowHeight() ~/ glyphHeight) - 1;
    print("Got $rowCount rows");
    if (_suggestions == null || _suggestions.length == 0) {
      setState(() {
        _suggestions = nouns.toList().take(rowCount).toList();
        columnCount = _getWindowWidth() ~/ glyphWidth;
      });
    }
  }

  Size _textSize(String text, TextStyle style) {
    final TextPainter textPainter = TextPainter(
        text: TextSpan(text: text, style: style),
        maxLines: 1,
        textDirection: TextDirection.ltr)
      ..layout(minWidth: 0, maxWidth: double.infinity);
    return textPainter.size;
  }

  @override
  void initState() {
    super.initState();
    print("initState");
    TextSpan span = new TextSpan(style: _biggerFont, text: "M");
    TextPainter tp = new TextPainter(
      textAlign: TextAlign.center,
      text: span,
      textHeightBehavior: TextHeightBehavior(
          applyHeightToFirstAscent: false, applyHeightToLastDescent: false),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    WidgetsBinding.instance.addPostFrameCallback(_afterLayout);
    final width = tp.width;
    final height = tp.height;
    glyphHeight = tp.height;
    glyphWidth = tp.width;
    print("GLYPH dimensions are $width x $height");
  }

  @override
  Widget build(BuildContext context) {
    final Size txtSize = _textSize("M", _biggerFont);
    final width = txtSize.width;
    final height = txtSize.height;

    print("txtSize in build is $width x $height");

    return Scaffold(
      /*
      appBar: AppBar(
        title: Text('Startup Name Generator'),
      ),
       */
      body: _buildSuggestions(),
    );
  }

  Widget _buildSuggestions() {
    return ListView.builder(
        key: _keyRed,
        padding: const EdgeInsets.all(0),
        itemCount: _suggestions.length,
        //padding: const EdgeInsets.all(16.0),
        itemBuilder: /* 1 */ (context, i) {
          /*
        if (i.isOdd) return Divider(); /* 2 */

        final index = i ~/ 2; /* 3 */
        if (index >= _suggestions.length) {
          _suggestions.addAll(generateWordPairs().take(10)); /* 4 */
        }

         */
          if (_suggestions != null) {
            return _buildRow(_suggestions[i]);
          } else {
            return Text("Loading...");
          }
        });
  }

  Widget _buildRow(String text) {
    if (text != null) {
      final list = new List<Text>(columnCount);
      int i;
      for (i = 0; i < text.length; ++i) {
        list[i] = Text(
          text.substring(i, i + 1),
          style: _biggerFont,
          softWrap: false,
          overflow: TextOverflow.clip,
          maxLines: 1,
        );
      }
      for (; i < columnCount - 1; ++i) {
        list[i] = Text(
          "Z",
          style: _biggerFont,
          softWrap: false,
          overflow: TextOverflow.clip,
          maxLines: 1,
        );
      }
      list[columnCount - 1] = Text(
        "E",
        style: _biggerFont,
        softWrap: false,
        overflow: TextOverflow.clip,
        maxLines: 1,
      );
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        mainAxisSize: MainAxisSize.max,
        textBaseline: TextBaseline.ideographic,
        textDirection: TextDirection.ltr,

        children: list,
      );
    } else {
      return Text("Loading...");
    }
    /*
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.all(0),
      title: Text(
        text,
        style: _biggerFont,
      ),
    );*/
  }
}

class RandomWords extends StatefulWidget {
  @override
  RandomWordsState createState() => RandomWordsState();
}

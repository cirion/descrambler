// Copyright 2018 The Flutter team. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math';
import 'dart:ui';

import 'package:dart_random_choice/dart_random_choice.dart';
import 'package:flutter/material.dart';
import 'package:english_words/english_words.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    print("Building app.");
    return MaterialApp(
      title: 'Startup Name Generator',
      home: RandomWords()
    );
  }
}

class RandomWordsState extends State<RandomWords> {
  //final _suggestions = <WordPair>[];
  List<String> _suggestions = new List<String>();
  final _biggerFont = const TextStyle(fontSize: 18.0, fontFeatures: [FontFeature.tabularFigures()]);
  final _secretWord = randomChoice(nouns);
  double glyphHeight;

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

  _afterLayout(_) {
    _getSizes();
    _getPositions();
    final int rowCount = _getWindowHeight() ~/ glyphHeight;
    print("Got $rowCount rows");
    setState(() {
      _suggestions = nouns.toList().take(rowCount).toList();
    });
  }

  @override
  void initState() {
    super.initState();
    print("initState");
    TextSpan span = new TextSpan(style: _biggerFont, text: "M");
    TextPainter tp = new TextPainter(
      text: span,
      textDirection: TextDirection.ltr
    );
    tp.layout();
    WidgetsBinding.instance.addPostFrameCallback(_afterLayout);
    final width = tp.width;
    final height = tp.height;
    glyphHeight = tp.height;
    print("GLYPH dimensions are $width x $height");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _keyRed,
      appBar: AppBar(
        title: Text('Startup Name Generator'),
      ),
      body: _buildSuggestions(),
    );
  }

  Widget _buildSuggestions() {
    return ListView.builder(
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
      }
    );
  }

  Widget _buildRow(String text) {
    return ListTile(
      title: Text(
        text,
        style: _biggerFont,
      ),
    );
  }
}

class RandomWords extends StatefulWidget {
  @override
  RandomWordsState createState() => RandomWordsState();
}


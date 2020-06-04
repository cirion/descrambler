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
  List<String> _suggestions = new List<String>();
  final _monoFont = GoogleFonts.robotoMono(
      fontSize: 18.0, fontFeatures: [FontFeature.tabularFigures()]);
  final _secretWord = randomChoice(nouns);
  int columnCount;
  double appBarHeight;

  GlobalKey _globalKey = GlobalKey();

  _getWindowHeight() {
    final RenderBox renderBoxRed = _globalKey.currentContext.findRenderObject();
    return renderBoxRed.size.height - appBarHeight;
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

      final int rowCount = (_getWindowHeight() ~/ glyphHeight) - 1;
      print("Got $rowCount rows");
      final shuffled = nouns.toList();
      shuffled.shuffle(Random());
      if (_suggestions == null || _suggestions.length == 0) {
        setState(() {
          _suggestions = shuffled.take(rowCount).toList();
          columnCount = _getWindowWidth() ~/ glyphWidth;
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
    print("appBarSize is $appBarSize");
    appBarHeight = appBarSize;

    return Scaffold(
      appBar: appBar,
      body: _buildSuggestions(),
      key: _globalKey,
    );
  }

  Widget _buildSuggestions() {
    if (_suggestions == null || columnCount == null) {
      return Text("Loading...");
    }
    final rows = new List<Widget>(_suggestions.length);
    for (int i = 0; i < _suggestions.length; ++i) {
      rows[i] = _buildRow(_suggestions[i]);
    }
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      verticalDirection: VerticalDirection.down,
      textDirection: TextDirection.ltr,
      textBaseline: TextBaseline.alphabetic,
      mainAxisSize: MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }

  Widget _buildRow(String text) {
    if (text != null) {
      final list = new List<Text>(columnCount);
      int i;
      for (i = 0; i < text.length; ++i) {
        list[i] = Text(
          text.substring(i, i + 1),
          style: _monoFont,
          softWrap: false,
          overflow: TextOverflow.clip,
          maxLines: 1,
        );
      }
      for (; i < columnCount - 1; ++i) {
        list[i] = Text(
          "Z",
          style: _monoFont,
          softWrap: false,
          overflow: TextOverflow.clip,
          maxLines: 1,
        );
      }
      list[columnCount - 1] = Text(
        "E",
        style: _monoFont,
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
  }
}

class RandomWords extends StatefulWidget {
  @override
  RandomWordsState createState() => RandomWordsState();
}

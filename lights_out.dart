// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.
//
// The "Lights Out" game for the STM32 F7 Discovery board.
// https://en.wikipedia.org/wiki/Lights_Out_(game)

library hello_world;

import 'dart:dartino';

import 'package:stm32/lcd.dart';
import 'package:stm32/stm32f746g_disco.dart';
import 'package:stm32/ts.dart';

const Color backgroundColor = Color.lightBlue;
const Color pressedColor = Color.yellow;
const Color lineColor = Color.white;
const Color textColor = Color.white;

STM32F746GDiscovery disco = new STM32F746GDiscovery();
FrameBuffer frameBuffer = disco.frameBuffer;
TouchScreen touchScreen = disco.touchScreen;

main() {
  // Initialize the board
  Board board = new Board();
  board.restart();

  // Input loop with simplistic debounce and key repeat
  int lastTouchCount = 0;
  int repeatCount = 0;
  while (true) {
    var touch = touchScreen.state;
    if (touch.count != 0) {
      if (repeatCount % 3 == 0) board.touched(touch.x[0], touch.y[0]);
      ++repeatCount;
    } else {
      repeatCount = 0;
    }
    if (lastTouchCount != touch.count || repeatCount > 0) {
      lastTouchCount = touch.count;
      sleep(500);
    }
  }
}

/// The main lights out board for drawing and handling touch
class Board {
  List<Button> allButtons = [];
  List<List<Button>> gridButtons = [];
  Button restartButton;
  Button nextButton;
  int gameIndex = 0;
  int messageX, messageY;

  Board() {
    frameBuffer.backgroundColor = backgroundColor;
    int margin = 6;
    int height = (frameBuffer.height - margin) ~/ 5 - margin;
    int width = height;
    for (int row = 0; row < 5; ++row) {
      gridButtons.add([]);
      for (int column = 0; column < 5; ++column) {
        int x = (column * (width + margin)) + margin;
        int y = (row * (height + margin)) + margin;
        var button = new Button(x, y, width, height);
        gridButtons[row].add(button);
        allButtons.add(button);
      }
    }
    int x = (6 * (width + margin)) + margin;
    int y = (2 * (height + margin)) + margin;
    restartButton =
        new Button(x, y, width * 2 + margin, height, text: 'Restart');
    allButtons.add(restartButton);
    y += height + margin;
    nextButton = new Button(x, y, width * 2 + margin, height, text: 'Next');
    allButtons.add(nextButton);
    messageX = x;
    messageY = margin + height + margin;
  }

  /// Draw the board and buttons without any pressed highlights
  void draw() {
    frameBuffer.clear(backgroundColor);
    for (Button button in allButtons) {
      button.draw();
    }
  }

  /// Switch to the next game
  void next() {
    gameIndex = (gameIndex + 1) % games.length;
    restart();
  }

  /// Restart the game
  void restart() {
    draw();
    for (int row = 0; row < 5; ++row) {
      for (int column = 0; column < 5; ++column) {
        gridButtons[row][column].pressed = games[gameIndex][row][column];
      }
    }
    updateMessage();
  }

  /// Handle a touch event at the given coordinates
  void touched(int x, int y) {
    toggle(int row, int column) {
      if (row >= 0 && row < 5 && column >= 0 && column < 5) {
        var button = gridButtons[row][column];
        button.pressed = !button.pressed;
      }
    }

    // Check if a button in the grid was pressed
    for (int row = 0; row < 5; ++row) {
      for (int column = 0; column < 5; ++column) {
        if (gridButtons[row][column].contains(x, y)) {
          toggle(row, column);
          toggle(row - 1, column);
          toggle(row + 1, column);
          toggle(row, column - 1);
          toggle(row, column + 1);
          updateMessage();
          return;
        }
      }
    }

    // Check other buttons
    if (restartButton.contains(x, y)) restart();
    if (nextButton.contains(x, y)) next();
  }

  void updateMessage() {
    bool anyLightsOn() {
      for (int row = 0; row < 5; ++row) {
        for (int column = 0; column < 5; ++column) {
          if (gridButtons[row][column].pressed) return true;
        }
      }
      return false;
    }

    String message;
    if (anyLightsOn()) {
      message = 'Turn out all the lights';
    } else {
      message = '***** YOU WIN !!! *****';
    }
    frameBuffer.foregroundColor = textColor;
    frameBuffer.writeText(messageX, messageY, message);
  }
}

class Button {
  final int x, y, width, height;
  final String text;
  bool _pressed = false;

  Button(this.x, this.y, this.width, this.height, {this.text});

  /// Draw the button and mark the button as not pressed
  void draw() {
    drawRect(x, y, width, height, color: lineColor);
    if (text != null) {
      // TODO center text in button
      frameBuffer.foregroundColor = textColor;
      frameBuffer.writeText(x + 10, y + 10, text);
    }
    _pressed = false;
  }

  bool get pressed => _pressed;

  void set pressed(bool newValue) {
    if (_pressed == newValue) return;
    _pressed = newValue;
    Color color = _pressed ? pressedColor : backgroundColor;
    drawRect(x + 5, y + 5, width - 10, height - 10, color: color);
    drawRect(x + 6, y + 6, width - 12, height - 12, color: color);
    drawRect(x + 7, y + 7, width - 14, height - 14, color: color);
    drawRect(x + 8, y + 8, width - 16, height - 16, color: color);
  }

  /// Return `true` if the given coordinates are within the button's bounds.
  bool contains(int x, int y) =>
      this.x <= x && x < this.x + width && this.y <= y && y < this.y + height;
}

drawRect(int x, int y, int width, int height, {Color color}) {
  if (color == null) color = pressedColor;
  int r = x + width;
  int b = y + height;
  frameBuffer.drawLine(x, y, r, y, color);
  frameBuffer.drawLine(r, y, r, b, color);
  frameBuffer.drawLine(x, y, x, b, color);
  frameBuffer.drawLine(x, b, r, b, color);
}

const List<List<List<bool>>> games = const [
  const [
    const [false, false, false, false, false],
    const [false, false, true, true, false],
    const [false, true, true, true, false],
    const [true, false, true, false, false],
    const [false, true, false, false, false],
  ],
  const [
    const [false, false, false, false, false],
    const [false, false, true, false, false],
    const [false, true, false, true, false],
    const [false, false, true, false, false],
    const [false, false, false, false, false],
  ],
  const [
    const [true, false, false, false, true],
    const [true, true, true, false, false],
    const [true, true, true, true, false],
    const [true, false, true, false, false],
    const [false, true, true, true, true],
  ],
  const [
    const [true, true, true, false, false],
    const [true, true, false, false, false],
    const [true, false, false, false, false],
    const [false, true, true, false, false],
    const [false, true, false, false, false],
  ],
];

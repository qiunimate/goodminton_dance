import 'dart:math';

class Move {
  final String instruction;
  final double waitTime;

  Move({
    required this.instruction,
    required this.waitTime,
  });

  static Move randomMove() {
    final random = Random();
    // Random instruction 1, 2, 3, or 4
    final instruction = (random.nextInt(4) + 1).toString();
    // Random wait time between 1.0 and 2.0 seconds
    final waitTime = 1.0 + random.nextDouble();

    return Move(
      instruction: instruction,
      waitTime: waitTime,
    );
  }

  String getInstruction(String handedness) {
    // Simply return the numeric instruction.
    // Handedness is still used in UI for wrist selection,
    // but instructions are now simplified to 1-4 directly.
    return instruction;
  }
}

enum GameState {
  idle,
  waitingForHit, // Instruction given, waiting for user to hit
  waitingForNext // Hit detected, waiting for next move delay
}

class GameEngine {
  GameState state = GameState.idle;
  Move? currentMove;
  bool handWasUp = false;
  DateTime? waitStartTime;
  DateTime? lastHitTime;

  // Constants
  static const int MIN_HIT_INTERVAL_MS = 500; // Reduced for faster response

  void reset() {
    state = GameState.idle;
    currentMove = null;
    handWasUp = false;
    waitStartTime = null;
    lastHitTime = null;
  }

  // Returns true if a new instruction should be spoken
  bool update(bool isHandUp, bool isHandDown) {
    final now = DateTime.now();

    if (state == GameState.idle) {
      // Generate new move
      currentMove = Move.randomMove();
      handWasUp = false;
      state = GameState.waitingForHit;
      return true; // Should speak instruction
    }

    if (state == GameState.waitingForHit) {
      // Hit detection logic
      if (lastHitTime != null &&
          now.difference(lastHitTime!).inMilliseconds < MIN_HIT_INTERVAL_MS) {
        return false;
      }

      if (isHandUp) {
        handWasUp = true;
      }

      if (handWasUp && isHandDown) {
        // HIT DETECTED
        print("Hit detected!");
        handWasUp = false;
        state = GameState.waitingForNext;
        waitStartTime = now;
        lastHitTime = now;
      }
    }

    if (state == GameState.waitingForNext) {
      if (currentMove != null && waitStartTime != null) {
        // Wait for the random 1-2s delay
        final waitMillis = (currentMove!.waitTime * 1000).toInt();

        if (now.difference(waitStartTime!).inMilliseconds >= waitMillis) {
          state = GameState.idle;
          currentMove = null;
          waitStartTime = null;
        }
      } else {
        state = GameState.idle;
      }
    }

    return false;
  }
}

import 'dart:math';

class Move {
  static const List<String> SIDES = ["left", "right"];
  static const List<String> ZONES = ["front", "back"];
  static const List<String> MOVE_TYPES = ["net", "lift", "drop", "smash", "clear"];
  static const List<String> DIRECTIONS = ["straight", "cross"];

  final String side;
  final String zone;
  final String moveType;
  final String direction;
  final double waitTime;

  Move({
    required this.side,
    required this.zone,
    required this.moveType,
    required this.direction,
    required this.waitTime,
  });

  static final Map<String, Map<String, double>> waitingTimes = {
    "net": {"straight": 1.0, "cross": 1.2},
    "lift": {"straight": 2.1, "cross": 2.3},
    "drop": {"straight": 1.7, "cross": 1.9},
    "smash": {"straight": 0.8, "cross": 1.0},
    "clear": {"straight": 2.4, "cross": 2.6}
  };

  static Move randomMove() {
    final random = Random();
    final zone = ZONES[random.nextInt(ZONES.length)];
    final side = SIDES[random.nextInt(SIDES.length)];
    final direction = DIRECTIONS[random.nextInt(DIRECTIONS.length)];

    String moveType;
    if (zone == "front") {
      moveType = ["net", "lift"][random.nextInt(2)];
    } else {
      moveType = ["drop", "smash", "clear"][random.nextInt(3)];
    }

    final waitTime = waitingTimes[moveType]![direction]!;
    
    return Move(
      side: side,
      zone: zone,
      moveType: moveType,
      direction: direction,
      waitTime: waitTime,
    );
  }

  String getInstruction(String handedness) {
    // handedness: 'R' or 'L'
    String forehand = (handedness == "R") ? "right" : "left";
    String backhand = (handedness == "R") ? "left" : "right";

    String instruction = "$side $zone $direction $moveType";
    
    Map<String, String> mapping = {
      "$forehand front": "1",
      "$forehand back": "2",
      "$backhand back": "3",
      "$backhand front": "4"
    };

    mapping.forEach((key, value) {
      instruction = instruction.replaceAll(key, value);
    });

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
  static const double COMPENSATION_TIME = 1.2;
  static const int MIN_HIT_INTERVAL_MS = 1000;

  void reset() {
    state = GameState.idle;
    currentMove = null;
    handWasUp = false;
    waitStartTime = null;
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
      // Check if we are outside the min hit interval
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
        final waitDuration = currentMove!.waitTime - COMPENSATION_TIME;
        // Ensure waitDuration is at least a small positive value
        final waitMillis = (max(0.0, waitDuration) * 1000).toInt();
        
        if (now.difference(waitStartTime!).inMilliseconds >= waitMillis) {
          state = GameState.idle;
          currentMove = null;
          waitStartTime = null;
        }
      } else {
        // Fallback if something is null
        state = GameState.idle;
      }
    }

    return false;
  }
}

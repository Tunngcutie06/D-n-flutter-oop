import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/leaderboard.dart';
class LeaderboardService {
  static final LeaderboardService _instance = LeaderboardService._internal();
  factory LeaderboardService() => _instance;
  LeaderboardService._internal();
  List<LeaderboardEntry> entries = [];
  bool _loaded = false; // track if we already loaded

  // --- FILE ---
  Future<File> _getFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/leaderboard.json');
  }

  // --- LOAD ONCE ---
  Future<void> load() async {
    if (_loaded) return; // avoid repeated loads
    try {
      final file = await _getFile();
      if (!await file.exists()) {
        entries = [];
      } else {
        final contents = await file.readAsString();
        final List data = json.decode(contents);
        entries = data.map((e) => LeaderboardEntry.fromJson(e)).toList();
      }
      // Sort descending by wave, then timestamp
      entries.sort((a, b) {
        int cmp = b.wave.compareTo(a.wave);
        return cmp != 0 ? cmp : b.timestamp.compareTo(a.timestamp);
      });
      _loaded = true;
    } catch (e) {
      entries = [];
      debugPrint("Leaderboard load error: $e");
    }
  }

  // --- SAVE ---
  Future<void> save() async {
    try {
      final file = await _getFile();
      final data = json.encode(entries.map((e) => e.toJson()).toList());
      await file.writeAsString(data);
    } catch (e) {
      debugPrint("Leaderboard save error: $e");
    }
  }

  // --- ADD ENTRY WITH BINARY INSERT ---
  Future<void> addEntry(int wave) async {
    final entry = LeaderboardEntry(wave: wave, timestamp: DateTime.now());

    // Find insertion index
    int index = entries.indexWhere(
      (e) =>
          e.wave < wave ||
          (e.wave == wave && e.timestamp.isBefore(entry.timestamp)),
    );
    if (index == -1) {
      entries.add(entry);
    } else {
      entries.insert(index, entry);
    }

    // Keep top 50 only
    if (entries.length > 50) {
      entries = entries.sublist(0, 50);
    }
    await save();
  }
}
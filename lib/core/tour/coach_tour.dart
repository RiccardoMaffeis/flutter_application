import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:showcaseview/showcaseview.dart';

/// Sections of the app that can have a guided tour (coach marks).
enum TourSection { shop, profile, nav, product, arLive }

/// Riverpod provider exposing a single instance of the tour service.
final coachTourServiceProvider = Provider<CoachTourService>((ref) {
  return CoachTourService(ref);
});

/// Centralized service to orchestrate "ShowcaseView" guided tours:
/// - Decides if a tour should be shown (persisted via SharedPreferences)
/// - Starts tours, queues subsequent tours if one is already running
/// - Marks a tour as "seen" once completed to avoid re-showing it
class CoachTourService {
  CoachTourService(this.ref);
  final Ref ref;

  /// Builds the preference key for a given section.
  String _k(TourSection s) => 'tour_seen_${s.name}';

  /// Whether a tour for the given section should be shown (i.e., not seen yet).
  Future<bool> shouldShow(TourSection s) async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_k(s)) ?? false);
  }

  /// Persists that a tour for the given section has been seen.
  Future<void> markSeen(TourSection s) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_k(s), true);
  }

  /// Internal state flags for tracking a running tour.
  bool _active = false;
  int _activeTotal = 0;
  int _completed = 0;

  /// Queue for a subsequent tour if another is currently active.
  TourSection? _queuedSection;
  List<GlobalKey>? _queuedSteps;
  BuildContext? _queuedContext;

  /// Callback for Showcase start: mark the system as active.
  void onShowcaseStart(int index, GlobalKey key) {
    _active = true;
  }

  /// Callback for each completed step; once all steps are done:
  /// - mark the current tour as finished
  /// - if a tour was queued, try to start it (respecting `shouldShow`)
  void onShowcaseStepComplete(int index, GlobalKey key) {
    if (!_active) return;
    _completed++;
    if (_completed >= _activeTotal) {
      _active = false;
      _activeTotal = 0;
      _completed = 0;

      final nextSteps = _queuedSteps;
      final nextSection = _queuedSection;
      final nextCtx = _queuedContext;
      _queuedSteps = null;
      _queuedSection = null;
      _queuedContext = null;

      if (nextSteps != null && nextSection != null && nextCtx != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (await shouldShow(nextSection)) {
            _active = true;
            _activeTotal = nextSteps.length;
            _completed = 0;
            ShowCaseWidget.of(nextCtx).startShowCase(nextSteps);
            await markSeen(nextSection);
          }
        });
      }
    }
  }

  /// Starts a tour immediately if none is active; otherwise it queues the tour.
  /// It also checks `shouldShow(section)` to avoid repeating already-seen tours.
  Future<void> startOrQueue(
    BuildContext context,
    TourSection section,
    List<GlobalKey> steps,
  ) async {
    if (steps.isEmpty) return;

    // If a tour is active, queue this one to be started later.
    if (_active) {
      _queuedSection = section;
      _queuedSteps = steps;
      _queuedContext = context;
      return;
    }

    // Start immediately if this section hasn't been shown yet.
    if (await shouldShow(section)) {
      _active = true;
      _activeTotal = steps.length;
      _completed = 0;
      ShowCaseWidget.of(context).startShowCase(steps);
      await markSeen(section);
    }
  }

  /// Force-starts a tour now (ignores the "seen" flag). If a tour is active,
  /// queue this one to run immediately after the current one finishes.
  void startNow(BuildContext context, List<GlobalKey> steps) {
    if (steps.isEmpty) return;
    if (_active) {
      _queuedSection = null;
      _queuedSteps = steps;
      _queuedContext = context;
      return;
    }
    _active = true;
    _activeTotal = steps.length;
    _completed = 0;
    ShowCaseWidget.of(context).startShowCase(steps);
  }

  /// Helper alias that respects queuing and "shouldShow" logic.
  Future<void> startIfNeeded(
    BuildContext context,
    TourSection section,
    List<GlobalKey> steps,
  ) => startOrQueue(context, section, steps);

  /// Clears the "seen" flags for all sections (useful for testing).
  Future<void> resetAll() async {
    final prefs = await SharedPreferences.getInstance();
    for (final s in TourSection.values) {
      await prefs.remove(_k(s));
    }
  }
}

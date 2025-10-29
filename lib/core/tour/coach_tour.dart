import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:showcaseview/showcaseview.dart';

enum TourSection { shop, profile, nav, product, arLive }

final coachTourServiceProvider = Provider<CoachTourService>((ref) {
  return CoachTourService(ref);
});

class CoachTourService {
  CoachTourService(this.ref);
  final Ref ref;

  String _k(TourSection s) => 'tour_seen_${s.name}';

  Future<bool> shouldShow(TourSection s) async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_k(s)) ?? false);
  }

  Future<void> markSeen(TourSection s) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_k(s), true);
  }

  bool _active = false;
  int _activeTotal = 0;
  int _completed = 0;

  TourSection? _queuedSection;
  List<GlobalKey>? _queuedSteps;
  BuildContext? _queuedContext;

  void onShowcaseStart(int index, GlobalKey key) {
    _active = true;
  }

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

  Future<void> startOrQueue(
    BuildContext context,
    TourSection section,
    List<GlobalKey> steps,
  ) async {
    if (steps.isEmpty) return;

    if (_active) {
      _queuedSection = section;
      _queuedSteps = steps;
      _queuedContext = context;
      return;
    }

    if (await shouldShow(section)) {
      _active = true;
      _activeTotal = steps.length;
      _completed = 0;
      ShowCaseWidget.of(context).startShowCase(steps);
      await markSeen(section);
    }
  }

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

  Future<void> startIfNeeded(
    BuildContext context,
    TourSection section,
    List<GlobalKey> steps,
  ) =>
      startOrQueue(context, section, steps);

  Future<void> resetAll() async {
    final prefs = await SharedPreferences.getInstance();
    for (final s in TourSection.values) {
      await prefs.remove(_k(s));
    }
  }
}

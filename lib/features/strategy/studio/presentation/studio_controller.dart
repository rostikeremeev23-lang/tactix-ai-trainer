import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/scenario.dart';
import '../domain/engine.dart';
import '../data/studio_store.dart';

class StudioController extends ChangeNotifier {
  final StudioStore store;
  StudioScenario scenario = StudioScenario.demo();
  ExerciseEngine? engine;
  String? selectedId, message;
  ObjectKind? adding;
  bool moving = false, loading = true, running = false, _disposed = false;
  int speed = 1, revision = 0;
  int? replayIndex;
  Timer? _clock, _debounce;
  String saveStatus = 'Загрузка…';
  StudioController(String userId) : store = StudioStore(userId);
  bool get editing => engine == null;
  bool get replay => replayIndex != null;
  ExerciseFrame? get frame =>
      replay ? engine!.frames[replayIndex!] : engine?.current;
  List<MapObject> get objects => frame?.objects ?? scenario.objects;
  MapObject? get selected {
    final matches = objects.where((o) => o.id == selectedId);
    return matches.isEmpty ? null : matches.first;
  }

  String? get instruction => adding != null
      ? 'Укажите место: ${objectLabels[adding!.index]}'
      : moving
      ? editing
            ? 'Укажите новое положение объекта'
            : 'Укажите конечную точку прямого маршрута'
      : null;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> restore() async {
    try {
      final document = await store.load();
      if (_disposed) return;
      if (document != null) {
        scenario = document.scenario;
        engine = document.engine;
      }
      saveStatus = document == null
          ? 'Новый учебный сценарий'
          : 'Восстановлено · на паузе';
      message = store.recoveryMessage;
    } catch (_) {
      saveStatus = 'Ошибка чтения';
      message = 'Сохранение недоступно. Демонстрация открыта без перезаписи повреждённых данных.';
    }
    loading = false;
    _notify();
  }

  Future<void> save() async {
    _debounce?.cancel();
    if (loading) return;
    final savedRevision = revision;
    try {
      await store.save(StudioDocument(scenario, engine));
      if (savedRevision == revision) saveStatus = 'Сохранено на устройстве';
    } catch (_) {
      saveStatus = 'Не сохранено · повторите';
      message =
          'Не удалось записать занятие. Текущее состояние остаётся на экране.';
    }
    _notify();
  }

  void _changed() {
    revision++;
    saveStatus = 'Сохранение…';
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 250),
      () => unawaited(save()),
    );
    _notify();
  }

  void configure(StudioScenario value) {
    if (!editing) return;
    value.validate();
    scenario = value;
    _changed();
  }

  void select(String id) {
    selectedId = id;
    adding = null;
    moving = false;
    _notify();
  }

  void armAdd(ObjectKind kind) {
    if (!editing) return;
    if (objects.length >= 30) {
      message = 'Лимит: 30 объектов.';
      _notify();
      return;
    }
    adding = kind;
    moving = false;
    _notify();
  }

  void armMove() {
    if (replay ||
        selected == null ||
        engine?.completed == true ||
        frame?.pending != null) {
      return;
    }
    adding = null;
    moving = true;
    _notify();
  }

  void cancelTool() {
    adding = null;
    moving = false;
    _notify();
  }

  void tapMap(MapPoint point) {
    if (adding != null && editing) {
      var n = 1;
      while (objects.any((o) => o.id == 'obj-$n')) {
        n++;
      }
      final object = MapObject(
        id: 'obj-$n',
        name: '${objectLabels[adding!.index]} $n',
        kind: adding!,
        position: point,
      );
      scenario = scenario.copyWith(objects: [...objects, object]);
      selectedId = object.id;
      adding = null;
      _changed();
    } else if (moving && selected != null && !replay) {
      if (editing) {
        updateObject(selected!.copyWith(position: point));
      } else if (engine!.move(selectedId!, point)) {
        _changed();
      } else {
        message = 'Маршрут недоступен: проверьте ресурсы и готовность.';
      }
      moving = false;
      _notify();
    }
  }

  void updateObject(MapObject object) {
    if (!editing) return;
    configure(
      scenario.copyWith(
        objects: objects.map((o) => o.id == object.id ? object : o).toList(),
      ),
    );
  }

  void deleteSelected() {
    if (!editing) return;
    configure(
      scenario.copyWith(
        objects: objects.where((o) => o.id != selectedId).toList(),
      ),
    );
    selectedId = null;
    moving = false;
    _notify();
  }

  void newScenario({bool demo = false}) {
    pause();
    scenario = demo ? StudioScenario.demo() : StudioScenario.blank();
    engine = null;
    replayIndex = null;
    selectedId = null;
    adding = null;
    moving = false;
    _changed();
  }

  void reset() {
    pause();
    engine = null;
    replayIndex = null;
    moving = false;
    adding = null;
    _changed();
  }

  void pause() {
    running = false;
    _clock?.cancel();
    _notify();
  }

  void play() {
    if (running) {
      pause();
      return;
    }
    if (editing) {
      if (scenario.launchProblem != null) {
        message = scenario.launchProblem;
        _notify();
        return;
      }
      engine = ExerciseEngine(scenario);
      adding = null;
      moving = false;
      _changed();
    }
    if (replay && replayIndex == engine!.frames.length - 1) replayIndex = 0;
    if (!replay && (engine!.completed || engine!.current.pending != null)) {
      return;
    }
    running = true;
    _clock?.cancel();
    _clock = Timer.periodic(
      Duration(milliseconds: 1000 ~/ speed),
      (_) => step(),
    );
    _notify();
  }

  void step() {
    if (engine == null) return;
    if (replay) {
      if (replayIndex! < engine!.frames.length - 1) {
        replayIndex = replayIndex! + 1;
      }
      if (replayIndex == engine!.frames.length - 1) pause();
      _notify();
      return;
    }
    if (engine!.advance()) _changed();
    if (engine!.completed || engine!.current.pending != null) pause();
  }

  void decide(int choice) {
    if (replay || engine == null) return;
    if (engine!.decide(choice)) _changed();
  }

  void setSpeed(int value) {
    if (![1, 2, 4].contains(value)) return;
    final resume = running;
    pause();
    speed = value;
    if (resume) play();
    _notify();
  }

  void toggleReplay() {
    if (engine == null) return;
    pause();
    replayIndex = replay ? null : 0;
    moving = false;
    adding = null;
    _notify();
  }

  void seek(int index) {
    if (!replay || index < 0 || index >= engine!.frames.length) return;
    pause();
    replayIndex = index;
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _clock?.cancel();
    _debounce?.cancel();
    if (!loading && revision > 0) unawaited(save());
    super.dispose();
  }
}

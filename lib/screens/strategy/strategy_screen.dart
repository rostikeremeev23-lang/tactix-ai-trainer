import '../../features/strategy/studio/presentation/studio_screen.dart';

/// Training destination backed by the existing simulator and saved-data keys.
class SimulationLabScreen extends StrategyStudioScreen {
  const SimulationLabScreen({
    super.key,
    required super.userId,
    super.startInLibrary = true,
    super.startInPlatform = false,
  });
}

/// Backward-compatible public entry for existing callers and stored integrations.
class TactixStrategyScreen extends SimulationLabScreen {
  const TactixStrategyScreen({
    super.key,
    required super.userId,
    super.startInLibrary = true,
    super.startInPlatform = false,
  });
}

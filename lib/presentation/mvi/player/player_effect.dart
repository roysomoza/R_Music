/// Single-shot side effects emitted by the MVI Player Store for UI consumption
/// (e.g. snackbars, dialogs, toasts, one-time triggers).
sealed class PlayerEffect {
  const PlayerEffect();
}

class ShowErrorEffect extends PlayerEffect {
  final String message;
  const ShowErrorEffect(this.message);
}

class ShowToastEffect extends PlayerEffect {
  final String message;
  const ShowToastEffect(this.message);
}

class SleepTimerExpiredEffect extends PlayerEffect {
  const SleepTimerExpiredEffect();
}

class NavigateToFullPlayerEffect extends PlayerEffect {
  const NavigateToFullPlayerEffect();
}

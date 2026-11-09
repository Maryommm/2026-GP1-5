/// Which design the main screens use.
///
/// - `false` (now): three tabs, Home, Your Farm and Ask Thamoor. Daily
///   Tasks opens from the "Today's Tasks" card on Home, and plants are added
///   from Your Farm, so Home has no "Grow a Plant" card.
/// - `true`: the previous design, kept in full: four tabs (Home, Daily
///   Tasks, Your Farm, Ask Thamoor) and Home's five feature cards.
///
/// Set this to `true` to get the previous design back; nothing else needs
/// to change.
const useClassicLayout = false;

/// The bottom bars tried for the current design.
enum NavBarStyle {
  /// A white bar: each tab's icon above its name, and a pale-green rounded
  /// square behind the open one (`LabeledNavBar`).
  labeled,

  /// A floating light-green pill; the open tab grows to show its name next
  /// to its icon (`PillNavBar`).
  pills,

  /// Home and Ask Thamoor on a white bar, with Your Farm as a big round
  /// button rising from its middle (`FarmCenterBottomBar`).
  centerButton,
}

/// The bottom bar of the current design (ignored with [useClassicLayout]).
const navBarStyle = NavBarStyle.labeled;

import 'package:flutter/material.dart';

/// Exposes the customer shell's drawer opener to any descendant screen so
/// the hamburger menu can be triggered from any bottom-nav tab (Explore,
/// Community, Games, Safety) without threading callbacks everywhere.
class MiloShellScope extends InheritedWidget {
 final VoidCallback openMenu;
 final void Function(int index) goToTab;

 const MiloShellScope({
 super.key,
 required this.openMenu,
 required this.goToTab,
 required super.child,
 });

 static MiloShellScope? maybeOf(BuildContext context) {
 return context.dependOnInheritedWidgetOfExactType<MiloShellScope>();
 }

 @override
 bool updateShouldNotify(MiloShellScope oldWidget) => false;
}

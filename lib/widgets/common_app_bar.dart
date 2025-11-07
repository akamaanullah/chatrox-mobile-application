import 'package:flutter/material.dart';

class CommonAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final bool showBackButton;
  final Color? backgroundColor;
  final Color? textColor;
  final double elevation;
  final Widget? leading;

  const CommonAppBar({
    Key? key,
    required this.title,
    this.actions,
    this.showBackButton = true,
    this.backgroundColor,
    this.textColor,
    this.elevation = 0,
    this.leading,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(
        title,
        style: TextStyle(
          color: textColor ?? Colors.black,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      backgroundColor: backgroundColor ?? Colors.white,
      elevation: elevation,
      centerTitle: false,
      leading: showBackButton
          ? leading ??
              IconButton(
                icon: Icon(
                  Icons.arrow_back_ios,
                  color: textColor ?? Colors.black,
                ),
                onPressed: () => Navigator.pop(context),
              )
          : null,
      actions: actions,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
} 
import 'dart:io';
import 'package:flutter/material.dart';

import 'ar_android_view.dart';
import 'ar_ios_view.dart';

class ArLivePage extends StatelessWidget {
  final String title;
  final String? glbUrl;
  final String? assetGlb;
  final double scale;

  const ArLivePage({
    super.key,
    required this.title,
    this.glbUrl,
    this.assetGlb,
    this.scale = 0.2,
  });

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (Platform.isAndroid) {
      body = AndroidArView(glbUrl: glbUrl, assetGlb: assetGlb, scale: scale);
    } else if (Platform.isIOS) {
      body = IosArView(glbUrl: glbUrl, assetGlb: assetGlb, scale: scale);
    } else {
      body = const Center(child: Text("AR non supportato"));
    }
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: body,
    );
  }
}

import 'package:flutter/material.dart';

import 'app.dart';
import 'config/api_config.dart';

void main() {
  ApiConfig.logResolvedConfig();
  runApp(const App());
}

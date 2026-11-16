import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';

class TestMapTileProvider extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(TileProvider.transparentImage);
}

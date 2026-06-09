import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:osm_location_picker/osm_location_picker.dart';

void main() {
  test('LocationModel toJson and fromJson serialization works', () {
    const latLng = LatLng(33.3152, 44.3661);
    const model = LocationModel(address: 'Test Address', latLng: latLng);

    final json = model.toJson();
    expect(json['address'], 'Test Address');
    expect(json['latLng']['latitude'], 33.3152);
    expect(json['latLng']['longitude'], 44.3661);

    final parsedModel = LocationModel.fromJson(json);
    expect(parsedModel.address, 'Test Address');
    expect(parsedModel.latLng?.latitude, 33.3152);
    expect(parsedModel.latLng?.longitude, 44.3661);
  });
}

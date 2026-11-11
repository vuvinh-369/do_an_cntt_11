"""Find nearby healthcare facilities from OpenStreetMap data."""
from collections import Counter
from concurrent.futures import FIRST_COMPLETED, ThreadPoolExecutor, wait
from http.client import HTTPException
import json
import math
import re
from threading import BoundedSemaphore
from urllib.parse import urlencode
from urllib.request import Request, urlopen


RADIUS_KM = 5
RESULTS_PER_TYPE = 15
PHOTON = 'https://photon.komoot.io'
OVERPASS = 'https://overpass-api.de/api/interpreter'
KINDS = {'hospital': 'Bệnh viện', 'clinic': 'Trung tâm y tế', 'pharmacy': 'Nhà thuốc'}
SEARCH_SLOTS = BoundedSemaphore(2)
SOURCE_LOOKUPS = ThreadPoolExecutor(max_workers=4)
OVERPASS_SLOTS = BoundedSemaphore(2)
PHOTON_SLOTS = BoundedSemaphore(2)


class NearbyPlacesError(Exception):
    def __init__(self, message, status=400):
        super().__init__(message)
        self.status = status


def _coordinates(lat, lon):
    if isinstance(lat, bool) or isinstance(lon, bool):
        raise ValueError('Invalid coordinates')
    lat, lon = float(lat), float(lon)
    if not (-90 <= lat <= 90 and -180 <= lon <= 180):
        raise ValueError('Invalid coordinates')
    return lat, lon


def _get_json(endpoint, parameters, timeout=7):
    request = Request(f'{endpoint}?{urlencode(parameters, doseq=True)}', headers={
        'Accept': 'application/json',
        'User-Agent': 'FirstAidWeb/1.0 (+https://github.com/vuvinh-369/do_an_cntt_11)',
    })
    with urlopen(request, timeout=timeout) as response:
        data = json.loads(response.read(3 * 1024 * 1024 + 1))
    if not isinstance(data, dict) or data.get('remark'):
        raise ValueError('Invalid map response')
    return data


def _photon_points(path, parameters):
    for feature in _get_json(PHOTON + path, parameters)['features']:
        try:
            lon, lat = feature['geometry']['coordinates']
            yield _coordinates(lat, lon), feature['properties']
        except (KeyError, TypeError, ValueError, OverflowError):
            continue


def _address(parts):
    return ', '.join(dict.fromkeys(
        part.strip() for part in parts if isinstance(part, str) and part.strip()
    ))


def _geocode(address):
    matches = []
    for point, props in _photon_points('/api/', {
        'q': address, 'countrycode': 'VN', 'limit': 5,
    }):
        if props.get('osm_key') == 'railway' and props.get('osm_value') == 'subway':
            continue
        label = _address(props.get(key) for key in ('name', 'street', 'district', 'city', 'state'))
        if label and not any(match['label'] == label for match in matches):
            matches.append({'label': label, 'latitude': point[0], 'longitude': point[1]})
    return matches


def _distance_km(origin, destination):
    lat1, lon1 = map(math.radians, origin)
    lat2, lon2 = map(math.radians, destination)
    a = (math.sin((lat2 - lat1) / 2) ** 2
         + math.cos(lat1) * math.cos(lat2) * math.sin((lon2 - lon1) / 2) ** 2)
    return 6371 * 2 * math.asin(min(1, math.sqrt(a)))


def _phone(tags):
    for key in ('contact:phone', 'phone', 'contact:mobile', 'mobile'):
        for value in re.split(r'[;,/]', tags.get(key, '')):
            digits = re.sub(r'[\s().-]', '', value)
            if re.fullmatch(r'\+?[0-9]{7,15}', digits):
                return value.strip(), digits
    return None, None


def _overpass_places(origin, radius_km):
    lat, lon = origin
    area = f'(around:{radius_km * 1000},{lat:.4f},{lon:.4f})'
    query = (
        '[out:json][timeout:6];('
        f'nwr{area}["amenity"~"^(hospital|clinic|pharmacy)$"];'
        f'nwr{area}["healthcare"~"^(hospital|clinic|health_centre|pharmacy)$"];'
        ');out center;'
    )
    for place in _get_json(OVERPASS, {'data': query})['elements']:
        tags = place.get('tags', {})
        amenity, healthcare = tags.get('amenity'), tags.get('healthcare')
        kind = amenity if amenity in KINDS else healthcare
        if kind == 'health_centre':
            kind = 'clinic'
        if kind not in KINDS:
            continue
        coords = place.get('center', place)
        try:
            point = _coordinates(coords.get('lat'), coords.get('lon'))
        except (TypeError, ValueError, OverflowError):
            continue
        street = ' '.join(filter(None, (tags.get('addr:housenumber'), tags.get('addr:street'))))
        address = tags.get('addr:full') or _address(
            (street, tags.get('addr:suburb'), tags.get('addr:city')))
        yield kind, point, tags, address


def _photon_places(origin, radius_km):
    lat, lon = origin

    def find_kind(kind):
        osm_tags = [f'amenity:{kind}', f'healthcare:{kind}']
        if kind == 'clinic':
            osm_tags.append('healthcare:health_centre')
        return [
            (kind, point, props, _address(props.get(key) for key in ('street', 'district', 'city')))
            for point, props in _photon_points('/reverse/', {
                'lat': round(lat, 4), 'lon': round(lon, 4), 'radius': radius_km,
                'osm_tag': osm_tags, 'limit': RESULTS_PER_TYPE,
            })
        ]

    with ThreadPoolExecutor(max_workers=len(KINDS)) as executor:
        return [place for group in executor.map(find_kind, KINDS) for place in group]


UPSTREAM_ERRORS = (OSError, HTTPException, KeyError, TypeError, ValueError)


def _source_records(provider, origin, radius_km):
    try:
        records = []
        for kind, point, tags, address in provider(origin, radius_km):
            distance = _distance_km(origin, point)
            if distance <= radius_km:
                records.append((kind, point, tags, address, distance))
        return records
    except UPSTREAM_ERRORS:
        return None


def _start_source(provider, slots, origin, radius_km):
    if not slots.acquire(blocking=False):
        return None
    try:
        future = SOURCE_LOOKUPS.submit(_source_records, provider, origin, radius_km)
    except BaseException:
        slots.release()
        raise
    future.add_done_callback(lambda _: slots.release())
    return future


def _nearby_records(origin, radius_km):
    overpass = _start_source(_overpass_places, OVERPASS_SLOTS, origin, radius_km)
    photon = _start_source(_photon_places, PHOTON_SLOTS, origin, radius_km)
    futures = [future for future in (overpass, photon) if future is not None]
    pending = set(futures)
    received_response = False
    while pending:
        done, pending = wait(pending, return_when=FIRST_COMPLETED)
        # Prefer Overpass when both are ready because it can return contact tags.
        for future in futures:
            if future not in done:
                continue
            records = future.result()
            if records:
                return records
            if records is not None:
                received_response = True
    if len(futures) < 2:
        raise NearbyPlacesError('Đang có lượt tra cứu khác. Hãy thử lại sau giây lát.', 429)
    if received_response:
        return []
    raise NearbyPlacesError('Chưa kết nối được OpenStreetMap. Hãy thử lại.', 503)


def search_nearby(payload):
    address = payload.get('address')
    radius_km = payload.get('radius_km', RADIUS_KM)
    if type(radius_km) is not int or radius_km not in (RADIUS_KM, 15):
        raise NearbyPlacesError('Hãy chọn bán kính 5 km hoặc 15 km.')
    if address is not None:
        if not isinstance(address, str) or not 3 <= len(address.strip()) <= 160:
            raise NearbyPlacesError('Hãy nhập địa chỉ từ 3 đến 160 ký tự.')
    else:
        try:
            origin = _coordinates(payload.get('latitude'), payload.get('longitude'))
        except (TypeError, ValueError, OverflowError) as exc:
            raise NearbyPlacesError('Vị trí gửi lên chưa hợp lệ.') from exc

    if not SEARCH_SLOTS.acquire(blocking=False):
        raise NearbyPlacesError('Đang có lượt tra cứu khác. Hãy thử lại sau giây lát.', 429)
    try:
        if address is not None:
            return {'locations': _geocode(address.strip())}
        records = _nearby_records(origin, radius_km)
    except UPSTREAM_ERRORS as exc:
        raise NearbyPlacesError('Chưa kết nối được OpenStreetMap. Hãy thử lại.', 503) from exc
    finally:
        SEARCH_SLOTS.release()

    candidates = []
    for kind, point, tags, place_address, distance in records:
        phone, dial_number = _phone(tags)
        candidates.append({
            'kind': kind, 'name': tags.get('name:vi') or tags.get('name') or KINDS[kind],
            'address': place_address, 'latitude': point[0], 'longitude': point[1],
            'distance_km': distance, 'phone': phone, 'dial_number': dial_number,
        })
    counts = Counter()
    places = []
    for place in sorted(candidates, key=lambda item: item['distance_km']):
        kind = place['kind']
        if counts[kind] < RESULTS_PER_TYPE:
            places.append(place)
            counts[kind] += 1
    return {'radius_km': radius_km, 'places': places, 'source': 'openstreetmap'}

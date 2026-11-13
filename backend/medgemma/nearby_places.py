"""Find nearby healthcare facilities from Google Maps (Serper.dev) with OpenStreetMap fallback."""
from collections import Counter, OrderedDict
from concurrent.futures import FIRST_COMPLETED, ThreadPoolExecutor, wait
from datetime import datetime
from http.client import HTTPException
import json
import logging
import math
import os
import re
from threading import BoundedSemaphore, Lock
import time
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import Request, urlopen


LOGGER = logging.getLogger(__name__)

RADIUS_KM = 5
RESULTS_PER_TYPE = 15
DEFAULT_SERPER_API_KEY = '49caf79f7b022cf65297a103605d463725678d62'
SERPER_MAPS_URL = 'https://google.serper.dev/maps'
SUPABASE_URL = 'https://oageskffhndqypwuuaij.supabase.co'
SUPABASE_PUBLISHABLE_KEY = 'sb_publishable_G_vCmGysKprr-mnkK4EeSg_CrqsGdCM'
SUPABASE_KEY_CACHE_TTL_SECONDS = 30
PHOTON = 'https://photon.komoot.io'
OVERPASS = 'https://overpass-api.de/api/interpreter'
KINDS = {'hospital': 'Bệnh viện', 'clinic': 'Trung tâm y tế', 'pharmacy': 'Nhà thuốc'}
SERPER_KIND_QUERIES = {
    'hospital': 'bệnh viện',
    'clinic': 'phòng khám',
    'pharmacy': 'nhà thuốc',
}
WEEKDAY_KEYS = ('Thứ Hai', 'Thứ Ba', 'Thứ Tư', 'Thứ Năm', 'Thứ Sáu', 'Thứ Bảy', 'Chủ Nhật')

PLACES_CACHE_TTL_SECONDS = 1800
GEOCODE_CACHE_TTL_SECONDS = 21600
CACHE_MAX_ENTRIES = 128

SEARCH_SLOTS = BoundedSemaphore(4)
SERPER_SLOTS = BoundedSemaphore(4)
SERPER_POOL = ThreadPoolExecutor(max_workers=6)
SOURCE_LOOKUPS = ThreadPoolExecutor(max_workers=4)
OVERPASS_SLOTS = BoundedSemaphore(2)
PHOTON_SLOTS = BoundedSemaphore(2)

CACHE_LOCK = Lock()
_PLACES_CACHE = OrderedDict()
_GEOCODE_CACHE = OrderedDict()

_COORD_PAIR = r'([+-]?\d{1,3}(?:\.\d+)?)\s*,\s*([+-]?\d{1,3}(?:\.\d+)?)'
_COORD_PATTERNS = (
    re.compile(rf'^\s*{_COORD_PAIR}\s*$'),
    re.compile(r'!3d([+-]?\d{1,3}(?:\.\d+)?)!4d([+-]?\d{1,3}(?:\.\d+)?)'),
    re.compile(rf'@{_COORD_PAIR}'),
    re.compile(rf'[?&](?:q|query|ll)={_COORD_PAIR}'),
)


class NearbyPlacesError(Exception):
    def __init__(self, message, status=400):
        super().__init__(message)
        self.status = status


def clear_cache():
    with CACHE_LOCK:
        _PLACES_CACHE.clear()
        _GEOCODE_CACHE.clear()


def _cache_get(cache, key, ttl_seconds):
    now = time.monotonic()
    with CACHE_LOCK:
        entry = cache.get(key)
        if entry is None:
            return None
        expires_at, value = entry
        if expires_at <= now:
            cache.pop(key, None)
            return None
        cache.move_to_end(key)
        return value


def _cache_set(cache, key, value, ttl_seconds):
    expires_at = time.monotonic() + ttl_seconds
    with CACHE_LOCK:
        cache[key] = (expires_at, value)
        cache.move_to_end(key)
        while len(cache) > CACHE_MAX_ENTRIES:
            cache.popitem(last=False)


_SUPABASE_KEY_LOCK = Lock()
_SUPABASE_KEY_STATE = {'expires_at': 0.0, 'key': None, 'last_active_key': None}


def _fetch_supabase_serper_key():
    endpoint = (
        f'{SUPABASE_URL}/rest/v1/system_configurations'
        '?id=eq.app_settings&select=serper_api_key'
    )
    request = Request(
        endpoint,
        headers={
            'apikey': SUPABASE_PUBLISHABLE_KEY,
            'Accept': 'application/json',
        },
        method='GET',
    )
    try:
        with urlopen(request, timeout=2.0) as response:
            rows = json.loads(response.read().decode('utf-8'))
        if isinstance(rows, list) and rows and isinstance(rows[0], dict):
            value = str(rows[0].get('serper_api_key') or '').strip()
            return value or None
    except (HTTPError, URLError, OSError, ValueError) as exc:
        LOGGER.debug('Supabase Serper key fetch skipped: %s', exc)
    return None


def _get_supabase_serper_key(force_refresh=False):
    now = time.monotonic()
    with _SUPABASE_KEY_LOCK:
        if not force_refresh and _SUPABASE_KEY_STATE['expires_at'] > now:
            return _SUPABASE_KEY_STATE['key']

    fetched = _fetch_supabase_serper_key()
    key_changed = False
    with _SUPABASE_KEY_LOCK:
        previous = _SUPABASE_KEY_STATE.get('last_active_key')
        if fetched and previous is not None and fetched != previous:
            key_changed = True
        if fetched:
            _SUPABASE_KEY_STATE['last_active_key'] = fetched
        _SUPABASE_KEY_STATE['key'] = fetched
        _SUPABASE_KEY_STATE['expires_at'] = time.monotonic() + SUPABASE_KEY_CACHE_TTL_SECONDS

    if key_changed:
        clear_cache()
    return fetched


def refresh_serper_config():
    clear_cache()
    with _SUPABASE_KEY_LOCK:
        _SUPABASE_KEY_STATE['expires_at'] = 0.0
    fetched = _get_supabase_serper_key(force_refresh=True)
    return {
        'refreshed': True,
        'source': 'supabase' if fetched else 'default',
        'has_key': bool(_serper_api_key()),
    }


def _serper_api_key():
    if 'SERPER_API_KEY' in os.environ:
        return os.environ['SERPER_API_KEY'].strip()
    if 'MEDGEMMA_SERPER_API_KEY' in os.environ:
        return os.environ['MEDGEMMA_SERPER_API_KEY'].strip()
    remote_key = _get_supabase_serper_key()
    if remote_key:
        return remote_key
    return DEFAULT_SERPER_API_KEY.strip()


def test_serper_api_key(api_key):
    clean_key = str(api_key or '').strip()
    if not clean_key:
        return {
            'is_success': False,
            'message': 'Vui lòng nhập hoặc dán Serper API Key trước khi kiểm tra.',
        }

    payload = json.dumps({
        'q': 'bệnh viện',
        'll': '@10.772500,106.698000,14z',
        'gl': 'vn',
        'hl': 'vi',
    }).encode('utf-8')
    request = Request(
        SERPER_MAPS_URL,
        data=payload,
        headers={
            'X-API-KEY': clean_key,
            'Content-Type': 'application/json; charset=utf-8',
            'Accept': 'application/json',
        },
        method='POST',
    )
    started = time.monotonic()
    try:
        with urlopen(request, timeout=12) as response:
            latency_ms = int((time.monotonic() - started) * 1000)
            data = json.loads(response.read().decode('utf-8'))
        places = data.get('places') if isinstance(data, dict) else []
        count = len(places) if isinstance(places, list) else 0
        credits = data.get('credits') if isinstance(data, dict) else None
        credit_text = f' · Tốn/còn credit: {credits}' if credits is not None else ''
        return {
            'is_success': True,
            'status_code': getattr(response, 'status', 200),
            'latency_ms': latency_ms,
            'sample_count': count,
            'credits': credits,
            'message': (
                f'Kết nối thành công tới Serper Google Maps! '
                f'Độ trễ {latency_ms}ms · tìm thấy {count} địa điểm mẫu{credit_text}.'
            ),
        }
    except HTTPError as exc:
        latency_ms = int((time.monotonic() - started) * 1000)
        api_error = ''
        try:
            err_body = json.loads(exc.read().decode('utf-8', errors='replace'))
            if isinstance(err_body, dict):
                api_error = str(err_body.get('message') or '').strip()
        except Exception:
            pass
        if exc.code in {401, 403}:
            detail = api_error or 'Hãy kiểm tra lại key trên serper.dev.'
            return {
                'is_success': False,
                'status_code': exc.code,
                'latency_ms': latency_ms,
                'message': f'API Key không hợp lệ hoặc đã bị thu hồi (HTTP {exc.code}). {detail}',
            }
        if exc.code in {400, 402, 429}:
            suffix = f': {api_error}' if api_error else '.'
            return {
                'is_success': False,
                'status_code': exc.code,
                'latency_ms': latency_ms,
                'message': f'Key có thể đã hết credit hoặc vượt giới hạn (HTTP {exc.code}){suffix}',
            }
        suffix = f': {api_error}' if api_error else '.'
        return {
            'is_success': False,
            'status_code': exc.code,
            'latency_ms': latency_ms,
            'message': f'Serper trả về HTTP {exc.code}{suffix}',
        }
    except (URLError, HTTPException, OSError, TimeoutError, ValueError) as exc:
        return {
            'is_success': False,
            'message': f'Lỗi kết nối tới Serper.dev: {exc}',
        }


def _coordinates(lat, lon):
    if isinstance(lat, bool) or isinstance(lon, bool):
        raise ValueError('Invalid coordinates')
    lat, lon = float(lat), float(lon)
    if not (math.isfinite(lat) and math.isfinite(lon)):
        raise ValueError('Invalid coordinates')
    if not (-90 <= lat <= 90 and -180 <= lon <= 180):
        raise ValueError('Invalid coordinates')
    return lat, lon


def _parse_coordinates_text(text):
    if not isinstance(text, str):
        return None
    for pattern in _COORD_PATTERNS:
        match = pattern.search(text)
        if not match:
            continue
        try:
            return _coordinates(match.group(1), match.group(2))
        except (TypeError, ValueError, OverflowError):
            continue
    return None


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


def _serper_post(payload, timeout=8):
    key = _serper_api_key()
    if not key:
        raise ValueError('Missing Serper API key')
    request = Request(
        SERPER_MAPS_URL,
        data=json.dumps(payload, ensure_ascii=False).encode('utf-8'),
        headers={
            'X-API-KEY': key,
            'Content-Type': 'application/json',
            'Accept': 'application/json',
        },
        method='POST',
    )
    with urlopen(request, timeout=timeout) as response:
        data = json.loads(response.read(3 * 1024 * 1024 + 1))
    if not isinstance(data, dict):
        raise ValueError('Invalid Serper response')
    return data


def _distance_km(origin, destination):
    lat1, lon1 = map(math.radians, origin)
    lat2, lon2 = map(math.radians, destination)
    a = (math.sin((lat2 - lat1) / 2) ** 2
         + math.cos(lat1) * math.cos(lat2) * math.sin((lon2 - lon1) / 2) ** 2)
    return 6371 * 2 * math.asin(min(1, math.sqrt(a)))


def _extract_phone(*values):
    for raw in values:
        if not isinstance(raw, str) or not raw.strip():
            continue
        for value in re.split(r'[;,/]', raw):
            digits = re.sub(r'[\s().-]', '', value)
            if re.fullmatch(r'\+?[0-9]{7,15}', digits):
                return value.strip(), digits
    return None, None


def _phone(tags):
    return _extract_phone(*(tags.get(key, '') for key in (
        'contact:phone', 'phone', 'contact:mobile', 'mobile',
    )))


def _today_hours(opening_hours):
    if not isinstance(opening_hours, dict) or not opening_hours:
        return None
    today_key = WEEKDAY_KEYS[datetime.now().weekday()]
    value = opening_hours.get(today_key)
    if isinstance(value, str) and value.strip():
        return value.strip()
    for fallback in opening_hours.values():
        if isinstance(fallback, str) and fallback.strip():
            return fallback.strip()
    return None


def _classify_serper_kind(requested_kind, item):
    primary = (item.get('type') or '').casefold()
    title = (item.get('title') or '').casefold()
    all_types = ' '.join(
        t.casefold() for t in (item.get('types') or []) if isinstance(t, str)
    )
    if any(token in primary for token in ('nhà thuốc', 'hiệu thuốc', 'cửa hàng thuốc', 'pharmacy', 'drugstore')):
        return 'pharmacy'
    if any(token in primary for token in ('bệnh viện', 'hospital')):
        return 'hospital'
    if any(token in primary for token in (
        'phòng khám', 'trung tâm y tế', 'trạm y tế', 'clinic',
        'medical', 'doctor', 'bác sĩ', 'nha khoa', 'đa khoa',
    )):
        return 'clinic'
    if requested_kind == 'pharmacy' and ('thuốc' in title or 'pharmacy' in all_types):
        return 'pharmacy'
    return requested_kind


def _serper_geocode(address):
    cache_key = ' '.join(address.casefold().split())
    cached = _cache_get(_GEOCODE_CACHE, cache_key, GEOCODE_CACHE_TTL_SECONDS)
    if cached is not None:
        return [dict(item) for item in cached]

    data = _serper_post({'q': address, 'gl': 'vn', 'hl': 'vi'})
    matches = []
    for item in data.get('places', [])[:5]:
        try:
            lat, lon = _coordinates(item.get('latitude'), item.get('longitude'))
        except (TypeError, ValueError, OverflowError):
            continue
        title = (item.get('title') or '').strip()
        place_addr = (item.get('address') or '').strip()
        if title and place_addr:
            label = place_addr if title.casefold() in place_addr.casefold() else f'{title} — {place_addr}'
        else:
            label = title or place_addr
        if label and not any(existing['label'] == label for existing in matches):
            matches.append({'label': label, 'latitude': lat, 'longitude': lon})

    if not matches and isinstance(data.get('ll'), str):
        point = _parse_coordinates_text(data['ll'])
        if point is not None:
            matches.append({'label': address, 'latitude': point[0], 'longitude': point[1]})

    if matches:
        _cache_set(_GEOCODE_CACHE, cache_key, [dict(item) for item in matches], GEOCODE_CACHE_TTL_SECONDS)
    return matches


def _serper_zoom(kind, radius_km):
    if radius_km <= RADIUS_KM:
        return '14z' if kind == 'hospital' else '15z'
    return '13z'


def _serper_fetch_kind(kind, origin, radius_km):
    query = SERPER_KIND_QUERIES[kind]
    zoom = _serper_zoom(kind, radius_km)
    data = _serper_post({
        'q': query,
        'll': f'@{origin[0]:.5f},{origin[1]:.5f},{zoom}',
        'gl': 'vn',
        'hl': 'vi',
    })
    items = []
    for raw in data.get('places', []):
        try:
            lat, lon = _coordinates(raw.get('latitude'), raw.get('longitude'))
        except (TypeError, ValueError, OverflowError):
            continue
        detected_kind = _classify_serper_kind(kind, raw)
        name = (raw.get('title') or '').strip() or KINDS[detected_kind]
        address = (raw.get('address') or '').strip()
        phone, dial_number = _extract_phone(raw.get('phoneNumber'))
        rating = raw.get('rating')
        rating_value = float(rating) if isinstance(rating, (int, float)) and not isinstance(rating, bool) else None
        rating_count = raw.get('ratingCount')
        rating_count_value = int(rating_count) if isinstance(rating_count, int) and not isinstance(rating_count, bool) else None
        place_id = raw.get('placeId') if isinstance(raw.get('placeId'), str) and raw.get('placeId').strip() else None
        dedup_key = (
            place_id
            or (raw.get('cid') if isinstance(raw.get('cid'), str) and raw.get('cid').strip() else None)
            or (raw.get('fid') if isinstance(raw.get('fid'), str) and raw.get('fid').strip() else None)
            or f'{name.casefold()}:{lat:.4f}:{lon:.4f}'
        )
        items.append({
            '_dedup': dedup_key,
            'kind': detected_kind,
            'name': name,
            'address': address,
            'latitude': lat,
            'longitude': lon,
            'phone': phone,
            'dial_number': dial_number,
            'rating': rating_value,
            'rating_count': rating_count_value,
            'hours': _today_hours(raw.get('openingHours')),
            'place_id': place_id,
        })
    return items


def _serper_places(origin, radius_km):
    cache_key = (round(origin[0], 3), round(origin[1], 3), radius_km)
    cached = _cache_get(_PLACES_CACHE, cache_key, PLACES_CACHE_TTL_SECONDS)
    if cached is not None:
        return [dict(item) for item in cached], True

    if not SERPER_SLOTS.acquire(blocking=False):
        raise NearbyPlacesError('Đang có lượt tra cứu khác. Hãy thử lại sau giây lát.', 429)
    try:
        futures = {
            kind: SERPER_POOL.submit(_serper_fetch_kind, kind, origin, radius_km)
            for kind in SERPER_KIND_QUERIES
        }
        deduped = {}
        succeeded = 0
        last_error = None
        for kind, future in futures.items():
            try:
                batch = future.result()
                succeeded += 1
            except UPSTREAM_ERRORS as exc:
                last_error = exc
                LOGGER.warning('Serper Maps lookup failed for %s: %s', kind, type(exc).__name__)
                continue
            for entry in batch:
                key = entry['_dedup']
                existing = deduped.get(key)
                if existing is None:
                    deduped[key] = entry
                else:
                    if existing['phone'] is None and entry['phone'] is not None:
                        existing['phone'] = entry['phone']
                        existing['dial_number'] = entry['dial_number']
                    if existing['hours'] is None and entry['hours'] is not None:
                        existing['hours'] = entry['hours']

        if succeeded == 0:
            raise last_error or ValueError('Serper Maps returned no usable response')

        records = [
            {k: v for k, v in item.items() if k != '_dedup'}
            for item in deduped.values()
        ]
        if succeeded == len(SERPER_KIND_QUERIES) and records:
            _cache_set(_PLACES_CACHE, cache_key, [dict(item) for item in records], PLACES_CACHE_TTL_SECONDS)
        return records, False
    finally:
        SERPER_SLOTS.release()


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


def _osm_geocode(address):
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


def _geocode(address):
    direct = _parse_coordinates_text(address)
    if direct is not None:
        lat, lon = direct
        return [{'label': f'Tọa độ ({lat:.5f}, {lon:.5f})', 'latitude': lat, 'longitude': lon}]
    if _serper_api_key():
        try:
            matches = _serper_geocode(address)
            if matches:
                return matches
        except UPSTREAM_ERRORS as exc:
            LOGGER.warning('Serper geocode failed (%s); falling back to OpenStreetMap.', type(exc).__name__)
    return _osm_geocode(address)


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
        results = []
        for point, props in _photon_points('/reverse/', {
            'lat': round(lat, 4), 'lon': round(lon, 4), 'radius': radius_km,
            'osm_tag': osm_tags, 'limit': RESULTS_PER_TYPE,
        }):
            street = ' '.join(filter(None, (props.get('housenumber'), props.get('street'))))
            address = _address((street, props.get('district'), props.get('city')))
            results.append((kind, point, props, address))
        return results

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
    if not futures or (len(futures) < 2 and not received_response):
        raise NearbyPlacesError('Đang có lượt tra cứu khác. Hãy thử lại sau giây lát.', 429)
    if received_response:
        return []
    raise NearbyPlacesError('Chưa kết nối được OpenStreetMap. Hãy thử lại.', 503)


def _format_osm_candidates(records):
    candidates = []
    for kind, point, tags, place_address, distance in records:
        phone, dial_number = _phone(tags)
        candidates.append({
            'kind': kind,
            'name': tags.get('name:vi') or tags.get('name') or KINDS[kind],
            'address': place_address,
            'latitude': point[0],
            'longitude': point[1],
            'distance_km': distance,
            'phone': phone,
            'dial_number': dial_number,
        })
    return candidates


def _format_serper_candidates(origin, radius_km, records):
    candidates = []
    for item in records:
        distance = _distance_km(origin, (item['latitude'], item['longitude']))
        if distance <= radius_km:
            candidate = dict(item)
            candidate['distance_km'] = distance
            candidates.append(candidate)
    return candidates


def search_nearby(payload):
    address = payload.get('address')
    radius_km = payload.get('radius_km', RADIUS_KM)
    if type(radius_km) is not int or radius_km not in (RADIUS_KM, 15):
        raise NearbyPlacesError('Hãy chọn bán kính 5 km hoặc 15 km.')
    if address is not None:
        if not isinstance(address, str) or not 3 <= len(address.strip()) <= 500:
            raise NearbyPlacesError('Hãy nhập địa chỉ từ 3 đến 500 ký tự.')
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

        if _serper_api_key():
            try:
                serper_records, cached = _serper_places(origin, radius_km)
                candidates = _format_serper_candidates(origin, radius_km, serper_records)
                source = 'google_maps_serper'
            except NearbyPlacesError:
                raise
            except UPSTREAM_ERRORS as exc:
                LOGGER.warning('Serper Places failed (%s); falling back to OpenStreetMap.', type(exc).__name__)
                records = _nearby_records(origin, radius_km)
                candidates = _format_osm_candidates(records)
                source = 'openstreetmap'
                cached = False
        else:
            records = _nearby_records(origin, radius_km)
            candidates = _format_osm_candidates(records)
            source = 'openstreetmap'
            cached = False
    except UPSTREAM_ERRORS as exc:
        raise NearbyPlacesError('Chưa kết nối được dịch vụ bản đồ. Hãy thử lại.', 503) from exc
    finally:
        SEARCH_SLOTS.release()

    counts = Counter()
    places = []
    for place in sorted(candidates, key=lambda item: item['distance_km']):
        kind = place['kind']
        if counts[kind] < RESULTS_PER_TYPE:
            places.append(place)
            counts[kind] += 1
    return {
        'radius_km': radius_km,
        'places': places,
        'source': source,
        'cached': cached,
    }

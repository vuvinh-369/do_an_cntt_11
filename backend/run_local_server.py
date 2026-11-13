"""One process: LAN web gateway, loopback admin API and one preloaded model."""
import argparse
from pathlib import Path
import ssl
import sys
import threading

from local_config import load_config
from lan_gateway import GatewayServer, local_ipv4_addresses, make_gateway


def main():
    backend = load_config()
    parser = argparse.ArgumentParser()
    parser.add_argument('--lan', action='store_true', help='Serve the demo to devices on the same private network')
    parser.add_argument('--port', type=int, default=8080)
    parser.add_argument('--api-port', type=int, default=8765)
    parser.add_argument('--no-preload', action='store_true')
    parser.add_argument('--tls-cert', type=Path, help='PEM certificate for the LAN web address')
    parser.add_argument('--tls-key', type=Path, help='PEM private key for the LAN certificate')
    parser.add_argument('--web-root', type=Path, default=backend.parent / 'build' / 'web')
    args = parser.parse_args()
    if not 1 <= args.port <= 65535 or not 1 <= args.api_port <= 65535 or args.port == args.api_port:
        parser.error('Choose different web/API ports in the range 1..65535.')
    if not (args.web_root / 'index.html').is_file():
        parser.error('Web build missing. Run .\\Build-Web.ps1 first.')
    if bool(args.tls_cert) != bool(args.tls_key):
        parser.error('Provide both --tls-cert and --tls-key to enable HTTPS.')
    tls_context = None
    if args.tls_cert:
        tls_context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        try:
            tls_context.load_cert_chain(args.tls_cert, args.tls_key)
        except OSError as error:
            parser.error(f'Could not load the HTTPS certificate or key: {error}')
    sys.path.insert(0, str(backend / 'medgemma'))
    from server import ChatService, ThreadingHTTPServer, configured_knowledge_store, make_handler

    store = configured_knowledge_store()
    service = ChatService(store=store, preload_enabled=not args.no_preload)
    api = ThreadingHTTPServer(('127.0.0.1', args.api_port), make_handler(service, allow_local_web=True))
    try:
        addresses = local_ipv4_addresses()
        web = GatewayServer(('0.0.0.0' if args.lan else '127.0.0.1', args.port),
                            make_gateway(args.web_root, api.server_port, addresses))
        web.tls_context = tls_context
    except BaseException:
        api.server_close()
        raise
    worker = threading.Thread(target=api.serve_forever, daemon=True)
    worker.start()
    try:
        scheme = 'https' if tls_context else 'http'
        print(f'Web: {scheme}://127.0.0.1:{web.server_port}/', flush=True)
        if args.lan:
            for address in addresses:
                if address != '127.0.0.1':
                    print(f'Thiet bi cung mang: {scheme}://{address}:{web.server_port}/', flush=True)
        print(f'Quan tri nguon (chi tren may chu): http://127.0.0.1:{api.server_port}/admin', flush=True)
        print(f'Kho so cuu: {store.backend_name}', flush=True)
        print('Nguon co so y te: OpenStreetMap', flush=True)
        print('Mot tien trinh model. Ctrl+C de dung ca web va API.', flush=True)
        if not args.no_preload:
            service.runner.warmup()
            print('Dang nap MedGemma tu thu muc rieng; xem trang thai trong ChatBox.', flush=True)
        web.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        web.server_close()
        api.shutdown()
        api.server_close()
        worker.join(timeout=5)


if __name__ == '__main__':
    main()

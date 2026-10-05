def online_wallpapers(pin, collection, destination, cache, callback):
    # SUMI_WALLPAPER_ZIP_PACKS_V1: full collection uses pinned independent ZIPs.
    if collection != 'full':
        return _online_wallpapers_individual(pin, collection, destination, cache, callback)
    import concurrent.futures
    import stat
    import threading
    import time
    import zipfile
    packs = pin.get('packs', {}).get('full', {})
    parts = packs.get('parts', [])
    if packs.get('format') != 'independent-zips' or not parts:
        raise SetupError('The full wallpaper collection lacks pinned ZIP packs.')
    prefix = '/' + pin['repository'] + '/releases/download/' + pin['tag'] + '/'
    seen_assets = set()
    for part in parts:
        spec_valid(part)
        if part['asset'] in seen_assets or not urlsplit(part['url']).path.startswith(prefix):
            raise SetupError('Wallpaper ZIP pack identity differs.')
        seen_assets.add(part['asset'])
    destination = Path(destination).absolute()
    no_symlink_parents(destination)
    destination.mkdir(parents=True, exist_ok=True)
    with cache.locked():
        manifest = download(pin['manifest'], cache.path(pin['manifest']['asset']), callback)
        data = json.loads(manifest.read_text())
        if data.get('schema') != 1 or data.get('snapshot_sha256') != pin['snapshot_sha256']:
            raise SetupError('Wallpaper snapshot identity differs from the pinned collection.')
        items = data['wallpapers']
        if len(items) != pin['wallpaper_count']:
            raise SetupError('Wallpaper count differs from the pinned collection.')
        expected = {}
        for item in items:
            spec_valid(item)
            name = 'Wallpapers/' + str(relative_path(item['path']))
            if name in expected:
                raise SetupError('Duplicate wallpaper path in the manifest.')
            expected[name] = item
        # Reserve room for every missing pack and the complete output collection.
        # Completed, hash-verified packs are reused by the normal resumable transport.
        pending = sum(p['bytes'] for p in parts if not verified(cache.path(p['asset']), p))
        unpacked = sum(item['bytes'] for item in items)
        if cache.root.stat().st_dev == destination.stat().st_dev:
            required = pending + unpacked + 128 * 1024**2
            if shutil.disk_usage(cache.root).free < required:
                raise SetupError('Insufficient space for wallpaper ZIP packs and extracted images.')
        elif (shutil.disk_usage(cache.root).free < pending + 128 * 1024**2
              or shutil.disk_usage(destination).free < unpacked + 128 * 1024**2):
            raise SetupError('Insufficient space for wallpaper ZIP packs or extracted images.')
        lock = threading.Lock()
        last = {}
        def progress(event):
            # Large packs emit chunk-level transport events. Throttle GUI logs,
            # keeping final events and separate progress for each active pack.
            key = (event.get('stage'), event.get('message'))
            now = time.monotonic()
            complete = event.get('total', 0) and event.get('completed') == event.get('total')
            with lock:
                if complete or now - last.get(key, 0) >= 0.4:
                    last[key] = now
                    callback(event)
        emit(callback, 'wallpapers', 'Download ' + str(len(parts)) + ' verified ZIP packs; up to three transfers in parallel')
        def fetch(part):
            return download(part, cache.path(part['asset']), progress)
        with concurrent.futures.ThreadPoolExecutor(max_workers=min(3, len(parts))) as pool:
            archives = list(pool.map(fetch, parts))
        # Validate every ZIP directory before writing any extracted wallpaper.
        members = {}
        for archive in archives:
            with zipfile.ZipFile(archive) as packed:
                for info in packed.infolist():
                    if info.filename not in expected or info.filename in members:
                        raise SetupError('Unexpected or duplicate ZIP member: ' + info.filename)
                    kind = stat.S_IFMT(info.external_attr >> 16)
                    item = expected[info.filename]
                    if info.is_dir() or kind not in (0, stat.S_IFREG) or info.flag_bits & 1:
                        raise SetupError('ZIP member is not an ordinary unencrypted image.')
                    if info.file_size != item['bytes']:
                        raise SetupError('ZIP image size differs: ' + info.filename)
                    members[info.filename] = archive
        if set(members) != set(expected):
            raise SetupError('ZIP packs do not contain exactly the pinned wallpaper collection.')
        results = []
        # Keep ZIPs open during extraction, and only stage one image at a time.
        with contextlib.ExitStack() as stack:
            opened = {path: stack.enter_context(zipfile.ZipFile(path)) for path in archives}
            for index, item in enumerate(items, 1):
                name = 'Wallpapers/' + str(relative_path(item['path']))
                fd, temporary = tempfile.mkstemp(prefix='.wallpaper-pack-', dir=cache.root)
                staged = Path(temporary)
                try:
                    h = hashlib.sha256()
                    size = 0
                    with os.fdopen(fd, 'wb') as output, opened[members[name]].open(name) as source:
                        while chunk := source.read(CHUNK):
                            size += len(chunk)
                            if size > item['bytes']:
                                raise SetupError('ZIP image exceeds its pinned size.')
                            h.update(chunk)
                            output.write(chunk)
                    if size != item['bytes'] or h.hexdigest() != item['sha256']:
                        raise SetupError('Extracted wallpaper checksum differs: ' + item['path'])
                    result, status = put_wallpaper(staged, item['path'], destination, item['sha256'])
                    results.append({'path': str(result), 'status': status})
                    emit(callback, 'wallpapers', result.name, index, len(items), result=status)
                finally:
                    staged.unlink(missing_ok=True)
        return results

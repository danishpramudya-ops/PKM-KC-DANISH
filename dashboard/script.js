/* ============================================
   POINT RESCUE — Tracking Command Center
   script.js — Real-time GPS Dashboard Engine
   ============================================
   
   TRACKING LOGIC IS PRESERVED FROM ORIGINAL.
   Only UI rendering updated for new layout.
   ============================================ */

(function () {
    'use strict';

    /* === Configuration === */
    const CONFIG = {
        FETCH_INTERVAL: 1000,       // Poll GPS data every 1 second
        OFFLINE_TIMEOUT: 60000,     // Device offline after 60 seconds tanpa kabar (heartbeat termasuk)
        GPS_URL: 'gps.json',
        DEFAULT_CENTER: [-7.953850, 112.614955],
        DEFAULT_ZOOM: 16,
        MARKER_ZOOM: 18,

        // Lokasi base station GATEWAY. Gateway tidak punya modul GPS (lihat CLAUDE.md),
        // jadi posisinya ditetapkan manual di sini sebagai titik komando tetap.
        GATEWAY_BASE: {
            id: 'GATEWAY-0',
            label: 'GATEWAY (Base)',
            latitude: -7.940706768120514,
            longitude: 112.61834472963696,
        },
    };

    /* === Device Color Palette === */
    const DEVICE_COLORS = [
        '#3b82f6', // Blue
        '#10b981', // Emerald
        '#f59e0b', // Amber
        '#ef4444', // Red
        '#8b5cf6', // Violet
        '#ec4899', // Pink
        '#06b6d4', // Cyan
        '#f97316', // Orange
    ];

    /* === State === */
    let map = null;
    let mapInitialized = false;
    const devices = {};         // { device_id: { data, marker, lastUpdate, colorIndex } }
    let selectedDeviceId = null;
    let colorCounter = 0;
    let fetchErrorCount = 0;
    let lastGlobalUpdate = null;

    /* === State: Fitur Jarak Antar Node === */
    let baseMarker = null;          // Marker Gateway (base station tetap)
    let measureMode = false;        // Mode ukur di peta aktif/tidak
    let measureFirstId = null;      // Node pertama yang dipilih saat mode ukur
    let measureFirstHalo = null;    // Lingkaran penanda node pertama
    let measureLayer = null;        // LayerGroup garis + label pengukuran aktif
    let selectedPairKey = null;     // Pasangan yang sedang disorot di panel jarak

    /* === DOM References === */
    const DOM = {
        // Map
        map: document.getElementById('map'),
        mapOverlayText: document.getElementById('mapOverlayText'),

        // Sidebar stats
        totalDevices: document.getElementById('totalDevices'),
        onlineDevices: document.getElementById('onlineDevices'),
        offlineDevices: document.getElementById('offlineDevices'),

        // Sidebar device list
        deviceList: document.getElementById('deviceList'),

        // Right panel - Status cards
        scardTotal: document.getElementById('scardTotal'),
        scardOnline: document.getElementById('scardOnline'),
        scardOffline: document.getElementById('scardOffline'),
        scardLastUpdate: document.getElementById('scardLastUpdate'),

        // Right panel - Detail
        detailPanel: document.getElementById('detailPanel'),
        detailPlaceholder: document.getElementById('detailPlaceholder'),
        detailContent: document.getElementById('detailContent'),
        detailDeviceId: document.getElementById('detailDeviceId'),
        detailDeviceIcon: document.getElementById('detailDeviceIcon'),
        detailStatus: document.getElementById('detailStatus'),
        detailLat: document.getElementById('detailLat'),
        detailLon: document.getElementById('detailLon'),
        detailAlt: document.getElementById('detailAlt'),
        detailSpeed: document.getElementById('detailSpeed'),
        detailSat: document.getElementById('detailSat'),
        detailLastUpdate: document.getElementById('detailLastUpdate'),

        // Header
        connectionStatus: document.getElementById('connectionStatus'),
        headerDeviceCount: document.getElementById('headerDeviceCount'),
        clock: document.getElementById('clock'),
        sidebarToggle: document.getElementById('sidebarToggle'),
        sidebar: document.getElementById('sidebar'),

        // SOS banner (baru)
        sosBanner: document.getElementById('sosBanner'),
        sosBannerText: document.getElementById('sosBannerText'),

        // Fitur jarak antar node
        distanceList: document.getElementById('distanceList'),
        distanceCount: document.getElementById('distanceCount'),
        mapContainer: document.querySelector('.map-container'),
        measureToggle: document.getElementById('measureToggle'),
        measureClear: document.getElementById('measureClear'),
        measureHint: document.getElementById('measureHint'),
        measureHintText: document.getElementById('measureHintText'),
    };


    /* ============================================
       MAP INITIALIZATION (called once, never again)
       ============================================ */
    function initMap() {
        if (mapInitialized) return;

        map = L.map('map', {
            center: CONFIG.DEFAULT_CENTER,
            zoom: CONFIG.DEFAULT_ZOOM,
            zoomControl: true,
            attributionControl: true,
        });

        L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
            attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors',
            maxZoom: 19,
        }).addTo(map);

        mapInitialized = true;
        DOM.mapOverlayText.textContent = 'Waiting for GPS data...';
    }


    /* ============================================
       CUSTOM MARKER ICON
       ============================================ */
    function createMarkerIcon(color, isSOS) {
        const pinColor = isSOS ? '#ef4444' : color;

        // Ring pulsing tambahan di belakang pin saat SOS aktif
        const sosRing = isSOS ? `
                <circle cx="16" cy="16" r="14" fill="none" stroke="#ef4444" stroke-width="2" class="sos-ring-1"/>
                <circle cx="16" cy="16" r="14" fill="none" stroke="#ef4444" stroke-width="2" class="sos-ring-2"/>` : '';

        const svg = `
            <svg xmlns="http://www.w3.org/2000/svg" width="32" height="42" viewBox="0 0 32 42" overflow="visible">
                <defs>
                    <filter id="shadow" x="-20%" y="-10%" width="140%" height="130%">
                        <feDropShadow dx="0" dy="2" stdDeviation="2" flood-color="rgba(0,0,0,0.3)"/>
                    </filter>
                </defs>
                ${sosRing}
                <path d="M16 0 C7.16 0 0 7.16 0 16 C0 28 16 42 16 42 S32 28 32 16 C32 7.16 24.84 0 16 0Z"
                      fill="${pinColor}" filter="url(#shadow)"/>
                <circle cx="16" cy="16" r="7" fill="white" opacity="0.9"/>
                <circle cx="16" cy="16" r="4" fill="${pinColor}"/>
            </svg>`;

        return L.divIcon({
            html: svg,
            className: 'custom-marker' + (isSOS ? ' custom-marker-sos' : ''),
            iconSize: [32, 42],
            iconAnchor: [16, 42],
            popupAnchor: [0, -42],
        });
    }


    /* ============================================
       DEVICE MANAGEMENT
       ============================================ */

    function getDeviceColor(index) {
        return DEVICE_COLORS[index % DEVICE_COLORS.length];
    }

    function isDeviceOnline(device) {
        if (!device.lastUpdate) return false;
        return (Date.now() - device.lastUpdate) < CONFIG.OFFLINE_TIMEOUT;
    }

    function isDeviceSOS(device) {
        // Anggap SOS masih "aktif" selama device online, meski gps.json
        // hanya membawa is_sos di packet terakhir yang diterima.
        return !!(device.data && device.data.is_sos) && isDeviceOnline(device);
    }

    function formatTime(timestamp) {
        if (!timestamp) return '—';
        const d = new Date(timestamp);
        return d.toLocaleTimeString('id-ID', {
            hour: '2-digit',
            minute: '2-digit',
            second: '2-digit',
        });
    }

    /* Waktu relatif ("baru saja", "12 dtk lalu", "3 mnt lalu") dari timestamp ms */
    function formatRelativeTime(timestampMs) {
        if (!timestampMs) return '—';
        const diffSec = Math.max(0, Math.round((Date.now() - timestampMs) / 1000));
        if (diffSec < 5) return 'baru saja';
        if (diffSec < 60) return diffSec + ' dtk lalu';
        const diffMin = Math.round(diffSec / 60);
        if (diffMin < 60) return diffMin + ' mnt lalu';
        const diffHour = Math.round(diffMin / 60);
        return diffHour + ' jam lalu';
    }

    /* Sumber kebenaran "kapan node terakhir terdengar": pakai field last_seen
       dari data (epoch detik, ditulis serial_listener.py/simulate.py) bila ada.
       TIDAK memakai waktu fetch browser — device yang tetap muncul di gps.json
       tanpa data baru (hanya di-refresh presence-nya) tidak boleh dianggap
       "baru saja update" hanya karena kebetulan ikut ter-fetch. */
    function resolveLastSeenMs(entry, fallbackNow) {
        if (typeof entry.last_seen === 'number') return entry.last_seen * 1000;
        return fallbackNow;   // fallback untuk sumber data lama yang belum punya field ini
    }


    /* ============================================
       PROCESS GPS DATA
       ============================================ */
    function processGPSData(dataArray) {
        const now = Date.now();
        lastGlobalUpdate = now;

        dataArray.forEach(function (entry) {
            const id = entry.device_id;

            if (!devices[id]) {
                /* --- New Device --- */
                const ci = colorCounter++;
                const color = getDeviceColor(ci);
                const icon = createMarkerIcon(color, !!entry.is_sos);

                const marker = L.marker(
                    [entry.latitude, entry.longitude],
                    { icon: icon }
                ).addTo(map);

                devices[id] = {
                    data: entry,
                    marker: marker,
                    lastUpdate: resolveLastSeenMs(entry, now),
                    colorIndex: ci,
                    color: color,
                };

                // Bind popup — di mode ukur, klik = pilih node untuk pengukuran jarak
                marker.on('click', function () {
                    if (measureMode) handleMeasureClick(id);
                    else selectDevice(id);
                });

                // First device? Center map on it
                if (Object.keys(devices).length === 1) {
                    map.setView([entry.latitude, entry.longitude], CONFIG.DEFAULT_ZOOM);
                }

            } else {
                /* --- Existing Device: update position only --- */
                const device = devices[id];
                device.data = entry;
                device.lastUpdate = resolveLastSeenMs(entry, now);
                device.marker.setLatLng([entry.latitude, entry.longitude]);
            }
        });

        // Update marker icons (warna/pulsing SOS bisa berubah tiap update) + popups
        Object.keys(devices).forEach(function (id) {
            const device = devices[id];
            const online = isDeviceOnline(device);
            const sos = isDeviceSOS(device);
            const d = device.data;

            device.marker.setIcon(createMarkerIcon(device.color, sos));

            const popupHTML = buildPopupHTML(id, d, device.color, online, sos);
            device.marker.bindPopup(popupHTML, { closeButton: true, maxWidth: 260 });
        });

        // Update UI
        updateSidebar();
        updateStats();
        updateDetailPanel();
        updateMapOverlay();
        updateSOSBanner();
        updateDistancePanel();
    }


    /* ============================================
       POPUP HTML
       ============================================ */
    function buildPopupHTML(id, data, color, online, sos) {
        const statusClass = online ? 'online' : 'offline';
        const statusText = online ? 'Online' : 'Offline';
        const sosRow = sos
            ? `<div class="popup-row popup-row-sos"><span class="popup-sos-badge">⚠ SOS ACTIVE</span></div>`
            : '';
        const validRow = (data.gps_valid === false)
            ? `<div class="popup-row popup-row-warning"><span class="popup-warning-badge">No GPS Fix (dummy)</span></div>`
            : '';

        return `
            <div class="popup-content">
                <div class="popup-header">
                    <span class="popup-color-dot" style="background:${sos ? '#ef4444' : color}; box-shadow: 0 0 6px ${sos ? '#ef4444' : color};"></span>
                    <span class="popup-device-name">Device ${id}</span>
                    <span class="popup-status ${statusClass}">${statusText}</span>
                </div>
                ${sosRow}
                ${validRow}
                <div class="popup-row">
                    <span class="popup-row-label">Latitude</span>
                    <span class="popup-row-value">${Number(data.latitude).toFixed(6)}</span>
                </div>
                <div class="popup-row">
                    <span class="popup-row-label">Longitude</span>
                    <span class="popup-row-value">${Number(data.longitude).toFixed(6)}</span>
                </div>
                <div class="popup-row">
                    <span class="popup-row-label">Altitude</span>
                    <span class="popup-row-value">${data.altitude} m</span>
                </div>
                <div class="popup-row">
                    <span class="popup-row-label">Speed</span>
                    <span class="popup-row-value">${data.speed} km/h</span>
                </div>
                <div class="popup-row">
                    <span class="popup-row-label">Satellites</span>
                    <span class="popup-row-value">${data.satellites}</span>
                </div>
            </div>`;
    }


    /* ============================================
       SIDEBAR: DEVICE LIST
       ============================================ */
    function updateSidebar() {
        // SOS aktif diprioritaskan tampil paling atas, sisanya alfabetis
        const ids = Object.keys(devices).sort(function (a, b) {
            const sosA = isDeviceSOS(devices[a]) ? 0 : 1;
            const sosB = isDeviceSOS(devices[b]) ? 0 : 1;
            if (sosA !== sosB) return sosA - sosB;
            return a.localeCompare(b);
        });

        if (ids.length === 0) {
            DOM.deviceList.innerHTML = `
                <div class="device-list-empty">
                    <span class="material-icons-round">search_off</span>
                    <span>No devices detected</span>
                </div>`;
            return;
        }

        // Build device list items
        let html = '';
        ids.forEach(function (id) {
            const device = devices[id];
            const online = isDeviceOnline(device);
            const sos = isDeviceSOS(device);
            const activeClass = (selectedDeviceId === id) ? ' active' : '';
            const sosClass = sos ? ' device-item-sos' : '';
            const statusClass = online ? 'online' : 'offline';
            const statusText = online ? 'Online' : 'Offline';
            const d = device.data;
            const dotColor = sos ? '#ef4444' : device.color;
            const sosBadge = sos ? '<span class="device-item-sos-badge">SOS</span>' : '';

            html += `
                <div class="device-item${activeClass}${sosClass}" data-device-id="${id}" onclick="window.__selectDevice('${id}')">
                    <span class="device-item-color" style="color:${dotColor}; background:${dotColor};"></span>
                    <div class="device-item-info">
                        <div class="device-item-name">Device ${id} ${sosBadge}</div>
                        <div class="device-item-coords">${Number(d.latitude).toFixed(4)}, ${Number(d.longitude).toFixed(4)}</div>
                        <div class="device-item-lastseen">${statusText} &middot; ${formatRelativeTime(device.lastUpdate)}</div>
                    </div>
                    <span class="device-item-status ${statusClass}"></span>
                </div>`;
        });

        DOM.deviceList.innerHTML = html;
    }


    /* ============================================
       STATS (Sidebar + Right Panel Cards)
       ============================================ */
    function updateStats() {
        const ids = Object.keys(devices);
        const total = ids.length;
        let onlineCount = 0;

        ids.forEach(function (id) {
            if (isDeviceOnline(devices[id])) onlineCount++;
        });

        const offlineCount = total - onlineCount;

        // Sidebar stats
        DOM.totalDevices.textContent = total;
        DOM.onlineDevices.textContent = onlineCount;
        DOM.offlineDevices.textContent = offlineCount;

        // Right panel status cards
        DOM.scardTotal.textContent = total;
        DOM.scardOnline.textContent = onlineCount;
        DOM.scardOffline.textContent = offlineCount;
        DOM.scardLastUpdate.textContent = formatTime(lastGlobalUpdate);

        // Header device count
        DOM.headerDeviceCount.textContent = total + ' Device' + (total !== 1 ? 's' : '');
    }


    /* ============================================
       DETAIL PANEL
       ============================================ */
    function selectDevice(id) {
        if (!devices[id]) return;

        selectedDeviceId = id;
        const device = devices[id];

        // Focus map on device marker (no animation, instant)
        map.setView(
            [device.data.latitude, device.data.longitude],
            CONFIG.MARKER_ZOOM,
            { animate: false }
        );

        // Open popup
        device.marker.openPopup();

        // Update detail panel & sidebar
        updateDetailPanel();
        updateSidebar();

        // Close mobile sidebar
        closeMobileSidebar();
    }

    // Expose to global for onclick handler in sidebar list items
    window.__selectDevice = selectDevice;

    function updateDetailPanel() {
        if (!selectedDeviceId || !devices[selectedDeviceId]) {
            DOM.detailPlaceholder.style.display = 'flex';
            DOM.detailContent.style.display = 'none';
            return;
        }

        DOM.detailPlaceholder.style.display = 'none';
        DOM.detailContent.style.display = 'flex';

        const device = devices[selectedDeviceId];
        const d = device.data;
        const online = isDeviceOnline(device);
        const sos = isDeviceSOS(device);

        // Device header
        DOM.detailDeviceId.textContent = 'Device ' + selectedDeviceId + (sos ? '  ⚠ SOS' : '');
        DOM.detailDeviceIcon.style.background = (sos ? '#ef4444' : device.color) + '18';
        DOM.detailDeviceIcon.style.color = sos ? '#ef4444' : device.color;

        // Status (SOS menimpa tampilan online/offline biasa agar menonjol)
        if (sos) {
            DOM.detailStatus.className = 'detail-status device-item-sos';
            DOM.detailStatus.querySelector('.status-label').textContent = 'SOS ACTIVE';
        } else {
            const statusClass = online ? 'online' : 'offline';
            const statusText = online ? 'Online' : 'Offline';
            DOM.detailStatus.className = 'detail-status ' + statusClass;
            DOM.detailStatus.querySelector('.status-label').textContent = statusText;
        }

        // Values
        DOM.detailLat.textContent = Number(d.latitude).toFixed(6) + '°';
        DOM.detailLon.textContent = Number(d.longitude).toFixed(6) + '°';
        DOM.detailAlt.textContent = d.altitude + ' m';
        DOM.detailSpeed.textContent = d.speed + ' km/h';
        DOM.detailSat.textContent = d.satellites + (d.gps_valid === false ? ' (no fix)' : '');
        DOM.detailLastUpdate.textContent = formatTime(device.lastUpdate) + ' (' + formatRelativeTime(device.lastUpdate) + ')';
    }


    /* ============================================
       SOS BANNER (global alert di atas dashboard)
       ============================================ */
    function updateSOSBanner() {
        if (!DOM.sosBanner) return;   // Elemen belum ditambahkan di HTML

        const sosIds = Object.keys(devices).filter(function (id) {
            return isDeviceSOS(devices[id]);
        });

        if (sosIds.length === 0) {
            DOM.sosBanner.style.display = 'none';
            return;
        }

        DOM.sosBanner.style.display = 'flex';
        DOM.sosBannerText.textContent =
            sosIds.length === 1
                ? `SOS ACTIVE — Device ${sosIds[0]}`
                : `SOS ACTIVE — ${sosIds.length} devices: ${sosIds.join(', ')}`;
    }


    /* ============================================
       MAP OVERLAY INFO
       ============================================ */
    function updateMapOverlay() {
        const total = Object.keys(devices).length;
        if (total === 0) {
            DOM.mapOverlayText.textContent = 'Waiting for GPS data...';
        } else {
            let onlineCount = 0;
            Object.keys(devices).forEach(function (id) {
                if (isDeviceOnline(devices[id])) onlineCount++;
            });
            DOM.mapOverlayText.textContent = `Tracking ${total} device${total > 1 ? 's' : ''} · ${onlineCount} online`;
        }
    }


    /* ============================================
       FITUR JARAK ANTAR NODE (Distance Measurement)
       Semua fungsi di bawah ini murni front-end:
       tidak mengubah pipeline serial maupun firmware.
       ============================================ */

    /* Jarak great-circle (haversine) dalam meter */
    function haversine(lat1, lng1, lat2, lng2) {
        const R = 6371000; // radius bumi rata-rata (meter)
        const toRad = function (d) { return d * Math.PI / 180; };
        const dLat = toRad(lat2 - lat1);
        const dLng = toRad(lng2 - lng1);
        const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
            Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) *
            Math.sin(dLng / 2) * Math.sin(dLng / 2);
        return 2 * R * Math.asin(Math.min(1, Math.sqrt(a)));
    }

    /* Format jarak: "850 m" atau "1.28 km" */
    function formatDistance(m) {
        if (m < 1000) return Math.round(m) + ' m';
        return (m / 1000).toFixed(2) + ' km';
    }

    function pairKey(id1, id2) {
        return [id1, id2].sort().join('|');
    }

    function shortNodeName(node) {
        return node.isBase ? 'GATEWAY' : node.id;
    }

    /* Objek node standar untuk 1 id (base atau device), atau null bila tak berposisi */
    function getNodeById(id) {
        if (id === CONFIG.GATEWAY_BASE.id) {
            const b = CONFIG.GATEWAY_BASE;
            return {
                id: b.id, label: b.label, latitude: b.latitude, longitude: b.longitude,
                role: 'GATEWAY', gps_valid: true, isBase: true, color: '#0F3D84',
            };
        }
        const dev = devices[id];
        if (!dev || !dev.data) return null;
        const d = dev.data;
        if (typeof d.latitude !== 'number' || typeof d.longitude !== 'number') return null;
        return {
            id: id, label: id, latitude: d.latitude, longitude: d.longitude,
            role: d.role || 'UNKNOWN', gps_valid: d.gps_valid !== false,
            isBase: false, color: dev.color,
        };
    }

    /* Base station + semua node lapangan yang online & punya koordinat (untuk matriks) */
    function getPositionedNodes() {
        const list = [getNodeById(CONFIG.GATEWAY_BASE.id)];
        Object.keys(devices).forEach(function (id) {
            const dev = devices[id];
            if (!dev.data) return;
            if (typeof dev.data.latitude !== 'number' || typeof dev.data.longitude !== 'number') return;
            if (!isDeviceOnline(dev)) return;   // hanya node online yang relevan
            list.push(getNodeById(id));
        });
        return list;
    }

    /* --- Marker base station Gateway (ikon perisai/home navy) --- */
    function createBaseIcon() {
        const svg =
            '<svg xmlns="http://www.w3.org/2000/svg" width="34" height="40" viewBox="0 0 34 40" overflow="visible">' +
            '<defs><filter id="baseShadow" x="-20%" y="-10%" width="140%" height="130%">' +
            '<feDropShadow dx="0" dy="2" stdDeviation="2" flood-color="rgba(0,0,0,0.35)"/></filter></defs>' +
            '<path d="M17 0 L34 8 V23 C34 33 17 40 17 40 S0 33 0 23 V8 Z" fill="#0F3D84" filter="url(#baseShadow)"/>' +
            '<path d="M17 10 l7 6 v8 h-4 v-6 h-6 v6 h-4 v-8 z" fill="#fff"/>' +
            '</svg>';
        return L.divIcon({
            html: svg, className: 'custom-marker-base',
            iconSize: [34, 40], iconAnchor: [17, 40], popupAnchor: [0, -40],
        });
    }

    function initBaseStation() {
        const b = CONFIG.GATEWAY_BASE;
        baseMarker = L.marker([b.latitude, b.longitude], {
            icon: createBaseIcon(),
            zIndexOffset: -100,   // di bawah marker node lapangan
        }).addTo(map);

        baseMarker.bindPopup(
            '<div class="popup-content"><div class="popup-header">' +
            '<span class="popup-color-dot" style="background:#0F3D84;box-shadow:0 0 6px #0F3D84;"></span>' +
            '<span class="popup-device-name">' + b.label + '</span>' +
            '<span class="popup-status online">Base</span></div>' +
            '<div class="popup-row"><span class="popup-row-label">Latitude</span>' +
            '<span class="popup-row-value">' + b.latitude.toFixed(6) + '</span></div>' +
            '<div class="popup-row"><span class="popup-row-label">Longitude</span>' +
            '<span class="popup-row-value">' + b.longitude.toFixed(6) + '</span></div>' +
            '<div class="popup-row"><span class="popup-row-label">GPS</span>' +
            '<span class="popup-row-value">Titik tetap (tanpa modul GPS)</span></div></div>',
            { closeButton: true, maxWidth: 260 }
        );

        baseMarker.on('click', function () {
            if (measureMode) handleMeasureClick(b.id);
            else baseMarker.openPopup();
        });
    }

    /* --- Interaksi mode ukur: klik node A lalu node B --- */
    function setMeasureHint(text) {
        if (DOM.measureHintText) DOM.measureHintText.textContent = text;
    }

    function highlightMeasureFirst(id) {
        clearMeasureFirstHighlight();
        const n = getNodeById(id);
        if (!n) return;
        measureFirstHalo = L.circleMarker([n.latitude, n.longitude], {
            radius: 16, color: '#F97316', weight: 2, fill: false, dashArray: '4 3',
        }).addTo(map);
    }

    function clearMeasureFirstHighlight() {
        if (measureFirstHalo) { map.removeLayer(measureFirstHalo); measureFirstHalo = null; }
    }

    function handleMeasureClick(id) {
        const node = getNodeById(id);
        if (!node) return;

        if (measureFirstId === null) {
            measureFirstId = id;
            highlightMeasureFirst(id);
            setMeasureHint('Klik node kedua…');
        } else if (measureFirstId === id) {
            measureFirstId = null;
            clearMeasureFirstHighlight();
            setMeasureHint('Klik node pertama…');
        } else {
            const a = getNodeById(measureFirstId);
            if (a) { drawMeasurement(a, node); selectedPairKey = pairKey(a.id, node.id); updateDistancePanel(); }
            measureFirstId = null;
            clearMeasureFirstHighlight();
            setMeasureHint('Klik node pertama…');
        }
    }

    function toggleMeasureMode() {
        measureMode = !measureMode;
        if (DOM.measureToggle) DOM.measureToggle.classList.toggle('active', measureMode);
        if (DOM.mapContainer) DOM.mapContainer.classList.toggle('measure-active', measureMode);
        if (DOM.measureHint) DOM.measureHint.classList.toggle('visible', measureMode);

        measureFirstId = null;
        clearMeasureFirstHighlight();
        if (measureMode) setMeasureHint('Klik node pertama…');
    }

    /* --- Gambar garis + label jarak antara dua node --- */
    function drawMeasurement(a, b) {
        clearMeasurement();

        const latlngs = [[a.latitude, a.longitude], [b.latitude, b.longitude]];
        const dist = haversine(a.latitude, a.longitude, b.latitude, b.longitude);
        const dummy = (!a.gps_valid || !b.gps_valid);

        const line = L.polyline(latlngs, {
            color: '#F97316', weight: 3, opacity: 0.9, dashArray: '8 6',
        });

        const mid = [(a.latitude + b.latitude) / 2, (a.longitude + b.longitude) / 2];
        const label = L.marker(mid, {
            icon: L.divIcon({
                className: 'measure-label',
                html: '<span>' + formatDistance(dist) + (dummy ? ' *' : '') + '</span>',
                iconSize: [0, 0],
            }),
            interactive: false,
        });

        measureLayer = L.layerGroup([line, label]).addTo(map);
        map.fitBounds(L.latLngBounds(latlngs), { padding: [80, 80], maxZoom: 18 });
    }

    function clearMeasurement() {
        if (measureLayer) { map.removeLayer(measureLayer); measureLayer = null; }
    }

    /* Bersihkan semua pengukuran (tombol "layers_clear") */
    function clearAllMeasurement() {
        clearMeasurement();
        clearMeasureFirstHighlight();
        measureFirstId = null;
        selectedPairKey = null;
        if (measureMode) setMeasureHint('Klik node pertama…');
        updateDistancePanel();
    }

    /* Dipanggil dari klik baris tabel jarak */
    function measurePairById(id1, id2) {
        const a = getNodeById(id1);
        const b = getNodeById(id2);
        if (!a || !b) return;
        selectedPairKey = pairKey(id1, id2);
        drawMeasurement(a, b);
        updateDistancePanel();
    }
    window.__measurePair = measurePairById;

    /* --- Panel tabel jarak semua pasangan (update tiap fetch) --- */
    function updateDistancePanel() {
        if (!DOM.distanceList) return;

        const nodes = getPositionedNodes();

        if (nodes.length < 2) {
            DOM.distanceList.innerHTML =
                '<div class="distance-empty">' +
                '<span class="material-icons-round">social_distance</span>' +
                '<span>Butuh minimal 2 node ber-posisi</span></div>';
            if (DOM.distanceCount) DOM.distanceCount.textContent = '';
            return;
        }

        const pairs = [];
        for (let i = 0; i < nodes.length; i++) {
            for (let j = i + 1; j < nodes.length; j++) {
                const a = nodes[i], b = nodes[j];
                pairs.push({
                    a: a, b: b, key: pairKey(a.id, b.id),
                    dist: haversine(a.latitude, a.longitude, b.latitude, b.longitude),
                    dummy: (!a.gps_valid || !b.gps_valid),
                });
            }
        }
        pairs.sort(function (p, q) { return p.dist - q.dist; });

        if (DOM.distanceCount) {
            DOM.distanceCount.textContent = pairs.length + ' pasangan';
        }

        const nearestKey = pairs[0].key;
        let html = '';
        pairs.forEach(function (p) {
            const cls = 'distance-row'
                + (p.key === nearestKey ? ' nearest' : '')
                + (p.key === selectedPairKey ? ' selected' : '');
            const dummyBadge = p.dummy ? '<span class="distance-badge-dummy">EST</span>' : '';
            const meta = (p.key === nearestKey) ? 'Terdekat' : '';
            html +=
                '<div class="' + cls + '" onclick="window.__measurePair(\'' + p.a.id + '\',\'' + p.b.id + '\')">' +
                '<div class="distance-pair">' +
                '<div class="distance-pair-nodes">' +
                '<span class="dpn">' + shortNodeName(p.a) + '</span>' +
                '<span class="material-icons-round">sync_alt</span>' +
                '<span class="dpn">' + shortNodeName(p.b) + '</span>' +
                '</div>' +
                (meta ? '<span class="distance-pair-meta">' + meta + '</span>' : '') +
                '</div>' +
                dummyBadge +
                '<span class="distance-value">' + formatDistance(p.dist) + '</span>' +
                '</div>';
        });

        DOM.distanceList.innerHTML = html;
    }

    function setupMeasureTools() {
        if (DOM.measureToggle) DOM.measureToggle.addEventListener('click', toggleMeasureMode);
        if (DOM.measureClear) DOM.measureClear.addEventListener('click', clearAllMeasurement);
    }


    /* ============================================
       GPS DATA FETCHER
       ============================================ */
    async function fetchGPSData() {
        try {
            const response = await fetch(CONFIG.GPS_URL + '?t=' + Date.now());

            if (!response.ok) {
                throw new Error('HTTP ' + response.status);
            }

            let data = await response.json();

            // Support both single object and array format
            if (!Array.isArray(data)) {
                data = [data];
            }

            processGPSData(data);

            // Reset error state
            fetchErrorCount = 0;
            setConnectionStatus(true);

        } catch (err) {
            fetchErrorCount++;
            console.warn('[PointRescue] Fetch error:', err.message);

            if (fetchErrorCount >= 3) {
                setConnectionStatus(false);
            }

            // Still update UI for offline detection
            updateStats();
            updateSidebar();
            updateDetailPanel();
            updateSOSBanner();
            updateDistancePanel();
        }
    }


    /* ============================================
       CONNECTION STATUS
       ============================================ */
    function setConnectionStatus(connected) {
        const el = DOM.connectionStatus;
        const textEl = el.querySelector('.status-text');

        if (connected) {
            el.classList.remove('error');
            textEl.textContent = 'SYSTEM ONLINE';
        } else {
            el.classList.add('error');
            textEl.textContent = 'DISCONNECTED';
        }
    }


    /* ============================================
       CLOCK
       ============================================ */
    function updateClock() {
        const now = new Date();
        DOM.clock.textContent = now.toLocaleTimeString('id-ID', {
            hour: '2-digit',
            minute: '2-digit',
            second: '2-digit',
        });
    }


    /* ============================================
       MOBILE SIDEBAR
       ============================================ */
    let overlay = null;

    function setupMobileSidebar() {
        // Create overlay
        overlay = document.createElement('div');
        overlay.className = 'sidebar-overlay';
        document.body.appendChild(overlay);

        DOM.sidebarToggle.addEventListener('click', function () {
            const isOpen = DOM.sidebar.classList.contains('open');
            if (isOpen) {
                closeMobileSidebar();
            } else {
                openMobileSidebar();
            }
        });

        overlay.addEventListener('click', closeMobileSidebar);
    }

    function openMobileSidebar() {
        DOM.sidebar.classList.add('open');
        if (overlay) overlay.classList.add('active');
    }

    function closeMobileSidebar() {
        DOM.sidebar.classList.remove('open');
        if (overlay) overlay.classList.remove('active');
    }


    /* ============================================
       INITIALIZATION
       ============================================ */
    function init() {
        initMap();
        initBaseStation();
        setupMeasureTools();
        setupMobileSidebar();
        updateClock();

        // Start clock update
        setInterval(updateClock, 1000);

        // Start GPS data polling
        fetchGPSData();
        setInterval(fetchGPSData, CONFIG.FETCH_INTERVAL);
    }

    // Boot up when DOM is ready
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }

})();
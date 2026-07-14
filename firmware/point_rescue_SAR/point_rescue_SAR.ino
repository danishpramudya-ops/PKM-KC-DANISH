#include <SPI.h>
#include <LoRa.h>
#include <TinyGPS++.h>
#include <ArduinoJson.h>

// BLE bawaan Arduino-ESP32 core (tidak perlu install library tambahan) —
// jembatan lokal HP <-> node SAR ini. Lihat docs/protokol-paket.md §8.
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

// ============================================================
// SAR NODE — Perangkat Tim Search And Rescue
// Node ID: 1XXX (contoh: 1001, 1002, 1003, ...)
// ============================================================
#define NODE_ID   1222   // <-- UBAH nomor ini per device SAR (1001, 1002, dst)
#define NET_ID    "PR01" // Harus sama persis di GATEWAY & KORBAN

// --- PIN LORA SX1278 (SPI) ---
#define LORA_SCK   5
#define LORA_MISO 19
#define LORA_MOSI 27
#define LORA_SS   18
#define LORA_RST  23
#define LORA_DI0  26
#define LORA_FREQ 433E6

// --- PIN GPS M10 (UART2) ---
// Pin 16 (RX2 ESP32) <- TX GPS | Pin 17 (TX2 ESP32) -> RX GPS
#define GPS_RX_PIN 16
#define GPS_TX_PIN 17
#define GPS_BAUD   9600

#define TRACKING_INTERVAL_MS   5000    // Broadcast lokasi sendiri
#define HEARTBEAT_INTERVAL_MS  10000   // Broadcast "masih hidup"

// SAR = kecepatan menengah (lebih cepat dari Korban, lebih lambat dari Gateway)
#define SAR_DELAY_MIN_MS 400
#define SAR_DELAY_MAX_MS 700

// PKT_CHAT (=3): pesan tim SAR, diketik di HP -> masuk lewat BLE -> di-broadcast
// ke mesh sama seperti paket lain (lihat docs/protokol-paket.md).
enum PacketType : uint8_t { PKT_HEARTBEAT = 0, PKT_TRACKING = 1, PKT_SOS = 2, PKT_CHAT = 3 };

// Panjang maksimum isi pesan chat (byte) — dibatasi supaya airtime LoRa tetap kecil.
#define CHAT_MSG_MAX_LEN 100

uint8_t hopLimitFor(PacketType t) {
  switch (t) {
    case PKT_HEARTBEAT: return 1;
    case PKT_TRACKING:  return 3;
    case PKT_CHAT:      return 4;
    case PKT_SOS:       return 5;
  }
  return 3;
}

uint8_t priorityFor(PacketType t) {
  switch (t) {
    case PKT_SOS:       return 3;
    case PKT_CHAT:      return 2;
    case PKT_TRACKING:  return 1;
    case PKT_HEARTBEAT: return 0;
  }
  return 0;
}

const char* roleName(uint8_t role) {
  switch (role) {
    case 0: return "GATEWAY";
    case 1: return "SAR";
    case 2: return "KORBAN";
  }
  return "UNKNOWN";
}

const char* typeName(PacketType t) {
  switch (t) {
    case PKT_HEARTBEAT: return "HEARTBEAT";
    case PKT_TRACKING:  return "TRACKING";
    case PKT_SOS:       return "SOS";
    case PKT_CHAT:      return "CHAT";
  }
  return "UNKNOWN";
}

// ============================================================
// DUPLICATE DETECTION
// ============================================================
#define SEEN_CACHE_SIZE   30
#define SEEN_CACHE_TTL_MS 30000

struct SeenEntry { String pid; uint32_t seenAt; bool used = false; };
SeenEntry seenCache[SEEN_CACHE_SIZE];

bool isPacketSeen(const String& pid) {
  uint32_t now = millis();
  for (int i = 0; i < SEEN_CACHE_SIZE; i++) {
    if (seenCache[i].used && (now - seenCache[i].seenAt) < SEEN_CACHE_TTL_MS
        && seenCache[i].pid == pid) return true;
  }
  return false;
}

void markPacketSeen(const String& pid) {
  uint32_t now = millis();
  for (int i = 0; i < SEEN_CACHE_SIZE; i++) {
    if (!seenCache[i].used || (now - seenCache[i].seenAt) >= SEEN_CACHE_TTL_MS) {
      seenCache[i] = { pid, now, true };
      return;
    }
  }
  int oldest = 0;
  for (int i = 1; i < SEEN_CACHE_SIZE; i++)
    if (seenCache[i].seenAt < seenCache[oldest].seenAt) oldest = i;
  seenCache[oldest] = { pid, now, true };
}

// ============================================================
// PRIORITY TX QUEUE
// ============================================================
#define TX_QUEUE_SIZE 8
struct QueuedPacket { String payload; uint8_t priority; uint32_t queuedAt; bool used = false; };
QueuedPacket txQueue[TX_QUEUE_SIZE];
uint32_t nextTxAllowedAt = 0;

bool enqueueTx(const String& payload, uint8_t priority) {
  for (int i = 0; i < TX_QUEUE_SIZE; i++) {
    if (!txQueue[i].used) { txQueue[i] = { payload, priority, millis(), true }; return true; }
  }
  Serial.println(F("[QUEUE] Penuh — paket dibuang"));
  return false;
}

int pickHighestPriorityIdx() {
  int best = -1;
  for (int i = 0; i < TX_QUEUE_SIZE; i++) {
    if (!txQueue[i].used) continue;
    if (best == -1 || txQueue[i].priority > txQueue[best].priority ||
       (txQueue[i].priority == txQueue[best].priority && txQueue[i].queuedAt < txQueue[best].queuedAt))
      best = i;
  }
  return best;
}

void processTxQueue() {
  if (millis() < nextTxAllowedAt) return;
  int idx = pickHighestPriorityIdx();
  if (idx == -1) return;

  LoRa.beginPacket();
  LoRa.print(txQueue[idx].payload);
  LoRa.endPacket();

  Serial.printf("[TX] (prio %d) %s\n", txQueue[idx].priority, txQueue[idx].payload.c_str());
  txQueue[idx].used = false;

  nextTxAllowedAt = millis() + random(SAR_DELAY_MIN_MS, SAR_DELAY_MAX_MS + 1);
}

// Dipakai bersama oleh buildPacket() (tracking/heartbeat/SOS) dan
// buildChatPacket() (chat) — dideklarasikan di sini (bukan di bawah, dekat
// gps/gpsSerial) karena buildChatPacket() pada blok BLE di bawah ini
// membutuhkannya lebih awal.
uint32_t seqCounter = 0;

// ============================================================
// BLE BRIDGE — Jembatan ke Mobile App (hanya node SAR)
// Murni lokal HP <-> node ini via Bluetooth Low Energy; TIDAK menambah
// trafik LoRa maupun mengubah format paket mesh. Detail UUID & tiap
// characteristic: docs/protokol-paket.md §8 dan mobile/README.md.
// ============================================================
#define BLE_SERVICE_UUID    "9c370001-3a1e-4f6a-9c37-a1b2c3d4e5f6"
#define BLE_NODE_INFO_UUID  "9c370002-3a1e-4f6a-9c37-a1b2c3d4e5f6"
#define BLE_MESH_RX_UUID    "9c370003-3a1e-4f6a-9c37-a1b2c3d4e5f6"
#define BLE_CHAT_TX_UUID    "9c370004-3a1e-4f6a-9c37-a1b2c3d4e5f6"
#define BLE_CHAT_RX_UUID    "9c370005-3a1e-4f6a-9c37-a1b2c3d4e5f6"

BLECharacteristic* chNodeInfo = nullptr;
BLECharacteristic* chMeshRx   = nullptr;
BLECharacteristic* chChatTx   = nullptr;
BLECharacteristic* chChatRx   = nullptr;
bool bleClientConnected = false;

// Kirim satu paket mesh (JSON string apa adanya, sama persis dengan yang
// dicetak ke Serial) ke HP lewat MESH_RX. No-op bila tak ada HP terhubung.
void bleNotifyMeshPacket(const String& payload) {
  if (!bleClientConnected || chMeshRx == nullptr) return;
  chMeshRx->setValue(payload.c_str());
  chMeshRx->notify();
}

// Notifikasi khusus pesan chat, supaya app tak perlu memfilter ulang dari MESH_RX.
void bleNotifyChat(int originId, uint8_t originRole, const char* msg) {
  if (!bleClientConnected || chChatRx == nullptr) return;
  JsonDocument doc;
  doc["id"]   = originId;
  doc["role"] = roleName(originRole);
  doc["msg"]  = msg;
  String out;
  serializeJson(doc, out);
  chChatRx->setValue(out.c_str());
  chChatRx->notify();
}

// Bungkus teks chat dari HP jadi paket PKT_CHAT — origin = node SAR ini sendiri.
String buildChatPacket(const String& msg) {
  JsonDocument doc;
  seqCounter++;
  doc["net"]  = NET_ID;
  doc["id"]   = NODE_ID;
  doc["seq"]  = seqCounter;
  doc["type"] = (int)PKT_CHAT;
  doc["hop"]  = 0;
  doc["msg"]  = msg;

  String out;
  serializeJson(doc, out);
  markPacketSeen(String(NODE_ID) + "-" + String(seqCounter));
  return out;
}

// Dipanggil saat HP menulis pesan ke characteristic CHAT_TX. Pesan dipotong
// ke CHAT_MSG_MAX_LEN (bukan ditolak) supaya pengalaman pakai tetap mulus.
void originateChat(const String& rawMsg) {
  String msg = rawMsg;
  msg.trim();
  if (msg.length() == 0) return;
  if (msg.length() > CHAT_MSG_MAX_LEN) msg = msg.substring(0, CHAT_MSG_MAX_LEN);

  String payload = buildChatPacket(msg);
  enqueueTx(payload, priorityFor(PKT_CHAT));

  // HP pengirim juga ikut lihat pesannya sendiri di UI chat (echo lokal)
  bleNotifyMeshPacket(payload);
  bleNotifyChat(NODE_ID, NODE_ID / 1000, msg.c_str());

  Serial.printf("[CHAT] TX dari HP -> LoRa: %s\n", msg.c_str());
}

class BleServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer* server) override {
    bleClientConnected = true;
    Serial.println(F("[BLE] HP terhubung."));
  }
  void onDisconnect(BLEServer* server) override {
    bleClientConnected = false;
    Serial.println(F("[BLE] HP terputus — mulai advertising lagi."));
    delay(200);   // beri waktu stack BLE beres-beres sebelum re-advertise
    server->getAdvertising()->start();
  }
};

class ChatTxCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic* ch) override {
    String value = String(ch->getValue().c_str());
    originateChat(value);
  }
};

void initBLE() {
  BLEDevice::init(("ANCHORPULSE-SAR-" + String(NODE_ID)).c_str());
  BLEServer* server = BLEDevice::createServer();
  server->setCallbacks(new BleServerCallbacks());

  BLEService* service = server->createService(BLE_SERVICE_UUID);

  chNodeInfo = service->createCharacteristic(
      BLE_NODE_INFO_UUID, BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY);
  chNodeInfo->addDescriptor(new BLE2902());

  chMeshRx = service->createCharacteristic(BLE_MESH_RX_UUID, BLECharacteristic::PROPERTY_NOTIFY);
  chMeshRx->addDescriptor(new BLE2902());

  chChatTx = service->createCharacteristic(BLE_CHAT_TX_UUID, BLECharacteristic::PROPERTY_WRITE);
  chChatTx->setCallbacks(new ChatTxCallbacks());

  chChatRx = service->createCharacteristic(BLE_CHAT_RX_UUID, BLECharacteristic::PROPERTY_NOTIFY);
  chChatRx->addDescriptor(new BLE2902());

  service->start();

  JsonDocument info;
  info["id"]   = NODE_ID;
  info["net"]  = NET_ID;
  info["role"] = "SAR";
  String infoStr;
  serializeJson(info, infoStr);
  chNodeInfo->setValue(infoStr.c_str());

  // Susun paket advertising SECARA EKSPLISIT supaya tidak melebihi batas 31 byte.
  // Nama panjang ("ANCHORPULSE-SAR-1001") + UUID 128-bit tidak muat bila
  // digabung di satu paket utama — advertising bisa gagal / UUID terpotong,
  // membuat HP tidak menemukan node. Solusi: UUID di paket UTAMA, NAMA di
  // SCAN RESPONSE (paket kedua saat HP melakukan active scan). App mencocokkan
  // keduanya (lihat AnchorpulseBleService.isAnchorpulse di mobile/).
  BLEAdvertising* adv = BLEDevice::getAdvertising();

  BLEAdvertisementData advData;
  advData.setFlags(0x06);   // LE General Discoverable + BR/EDR not supported
  advData.setCompleteServices(BLEUUID(BLE_SERVICE_UUID));
  adv->setAdvertisementData(advData);

  BLEAdvertisementData scanResp;
  scanResp.setName(("ANCHORPULSE-SAR-" + String(NODE_ID)).c_str());
  adv->setScanResponseData(scanResp);

  adv->setScanResponse(true);
  BLEDevice::startAdvertising();

  Serial.printf("[BLE] GATT server siap — advertising sebagai ANCHORPULSE-SAR-%d\n", NODE_ID);
}

// ============================================================
// GPS & LORA OBJECTS
// ============================================================
TinyGPSPlus    gps;
HardwareSerial gpsSerial(2);

// ============================================================
// BUILD & ORIGINATE PACKET
// ============================================================
String buildPacket(PacketType type, bool includeGPS) {
  JsonDocument doc;
  seqCounter++;
  doc["net"]  = NET_ID;
  doc["id"]   = NODE_ID;
  doc["seq"]  = seqCounter;
  doc["type"] = (int)type;
  doc["hop"]  = 0;

  if (includeGPS) {
    if (gps.location.isValid()) {
      doc["lat"] = gps.location.lat();
      doc["lng"] = gps.location.lng();
      doc["alt"] = gps.altitude.meters();
      doc["spd"] = gps.speed.mps();
      doc["sats"] = gps.satellites.value();
      doc["valid"] = true;
    } else {
      doc["lat"] = -7.953850; doc["lng"] = 112.614955;
      doc["alt"] = 535.5; doc["spd"] = 0.0; doc["sats"] = 0;
      doc["valid"] = false;
    }
  }

  String out;
  serializeJson(doc, out);
  markPacketSeen(String(NODE_ID) + "-" + String(seqCounter));
  return out;
}

void originatePacket(PacketType type, bool includeGPS) {
  String payload = buildPacket(type, includeGPS);
  enqueueTx(payload, priorityFor(type));
  bleNotifyMeshPacket(payload);   // HP juga melihat status/lokasi node ini sendiri
}

void triggerSOS() {
  Serial.println(F("\n[SOS] !!! TRIGGER SOS MANUAL (SAR) !!!\n"));
  originatePacket(PKT_SOS, true);
}

// ============================================================
// VALIDASI PAKET MASUK
// ============================================================
bool validatePacket(JsonDocument& doc) {
  if (!doc["net"].is<const char*>() || !doc["id"].is<int>() ||
      !doc["seq"].is<int>() || !doc["type"].is<int>() || !doc["hop"].is<int>()) return false;

  if (String(doc["net"].as<const char*>()) != NET_ID) return false;

  int id = doc["id"].as<int>();
  if (id < 0 || id > 2999) return false;

  int type = doc["type"].as<int>();
  if (type < 0 || type > 3) return false;

  int hop = doc["hop"].as<int>();
  if (hop < 0 || hop > 10) return false;

  if (type == PKT_CHAT) {
    if (!doc["msg"].is<const char*>()) return false;
    if (strlen(doc["msg"].as<const char*>()) > CHAT_MSG_MAX_LEN) return false;
  }

  return true;
}

// ============================================================
// HANDLE PAKET MASUK — SAR selalu boleh relay
// ============================================================
void handleIncomingPacket() {
  int packetSize = LoRa.parsePacket();
  if (packetSize == 0) return;

  String raw;
  while (LoRa.available()) raw += (char)LoRa.read();
  int rssi = LoRa.packetRssi();

  JsonDocument doc;
  if (deserializeJson(doc, raw) != DeserializationError::Ok) return;
  if (!validatePacket(doc)) return;

  int        originId = doc["id"].as<int>();
  uint32_t   seq       = doc["seq"].as<uint32_t>();
  PacketType type      = (PacketType)doc["type"].as<int>();
  int        hop       = doc["hop"].as<int>();

  if (originId == NODE_ID) return;   // Paket sendiri yang muter balik

  String pid = String(originId) + "-" + String(seq);
  if (isPacketSeen(pid)) return;     // Duplikat
  markPacketSeen(pid);

  uint8_t originRole = originId / 1000;

  Serial.printf("[RX] dari %d (%s) | %s | seq %d | hop %d | RSSI %d\n",
    originId, roleName(originRole), typeName(type), seq, hop, rssi);

  bool hasLocation = doc["lat"].is<float>() && doc["lng"].is<float>();

  if (hasLocation) {
    float lat   = doc["lat"].as<float>();
    float lng   = doc["lng"].as<float>();
    float alt   = doc["alt"] | 0.0f;
    float spd   = doc["spd"] | 0.0f;
    int   sats  = doc["sats"] | 0;
    bool  valid = doc["valid"] | false;

    Serial.printf("  [LOKASI] id=%d | lat=%.6f | lng=%.6f | alt=%.1fm | "
                  "spd=%.2fm/s | sats=%d | gps_valid=%s\n",
      originId, lat, lng, alt, spd, sats, valid ? "YA" : "TIDAK (dummy)");

    if (!valid) {
      Serial.println(F("  [WARN] Node pengirim belum dapat fix GPS asli — data dummy"));
    }
  } else if (type == PKT_CHAT) {
    const char* msg = doc["msg"] | "";
    Serial.printf("  [CHAT] dari %d (%s): %s\n", originId, roleName(originRole), msg);
  } else {
    Serial.println(F("  [INFO] Paket ini heartbeat — tidak membawa data lokasi"));
  }

  if (type == PKT_SOS) Serial.printf("  ⚠️  SOS DITERIMA dari node %d !!\n", originId);

  // Teruskan paket mesh apa adanya ke HP lewat BLE (mobile app) — dipakai untuk
  // node list, lokasi, dan status. Tidak menambah trafik LoRa (murni lokal via BLE).
  bleNotifyMeshPacket(raw);
  if (type == PKT_CHAT) {
    const char* msg = doc["msg"] | "";
    bleNotifyChat(originId, originRole, msg);
  }

  // SAR selalu boleh relay
  int maxHop = hopLimitFor(type);
  if (hop + 1 > maxHop) {
    Serial.println(F("  [RELAY] Hop limit tercapai — stop"));
    return;
  }

  doc["hop"] = hop + 1;
  String rePayload;
  serializeJson(doc, rePayload);
  enqueueTx(rePayload, priorityFor(type));
  Serial.printf("  [RELAY] hop %d -> %d, prio %d\n", hop, hop + 1, priorityFor(type));
}

// ============================================================
// SETUP
// ============================================================
void setup() {
  Serial.begin(115200);
  while (!Serial) delay(10);

  Serial.println(F("\n========================================"));
  Serial.printf("  Node ID   : %d\n", NODE_ID);
  Serial.println(F("  Role      : SAR"));
  Serial.printf("  Net ID    : %s\n", NET_ID);
  Serial.println(F("  Can Relay : YA"));
  Serial.println(F("========================================\n"));

  gpsSerial.begin(GPS_BAUD, SERIAL_8N1, GPS_RX_PIN, GPS_TX_PIN);

  SPI.begin(LORA_SCK, LORA_MISO, LORA_MOSI, LORA_SS);
  LoRa.setPins(LORA_SS, LORA_RST, LORA_DI0);

  if (!LoRa.begin(LORA_FREQ)) {
    Serial.println(F("[LORA] Gagal init! Cek wiring."));
    while (true) delay(1000);
  }

  LoRa.setSpreadingFactor(10);
  LoRa.setSignalBandwidth(125E3);
  LoRa.setCodingRate4(5);
  LoRa.setTxPower(20);

  Serial.println(F("[LORA] Siap.\n"));

  initBLE();

  Serial.println(F("[INFO] Ketik 'SOS' di Serial Monitor untuk trigger darurat manual.\n"));
  randomSeed(analogRead(0));
}

// ============================================================
// LOOP
// ============================================================
uint32_t lastTracking = 0;
uint32_t lastHeartbeat = 0;

void loop() {
  while (gpsSerial.available()) gps.encode(gpsSerial.read());

  uint32_t now = millis();

  if (now - lastTracking >= TRACKING_INTERVAL_MS) {
    lastTracking = now;
    originatePacket(PKT_TRACKING, true);
  }

  if (now - lastHeartbeat >= HEARTBEAT_INTERVAL_MS) {
    lastHeartbeat = now;
    originatePacket(PKT_HEARTBEAT, false);
  }

  if (Serial.available()) {
    String cmd = Serial.readStringUntil('\n');
    cmd.trim();
    if (cmd.equalsIgnoreCase("SOS")) triggerSOS();
  }

  handleIncomingPacket();
  processTxQueue();
}

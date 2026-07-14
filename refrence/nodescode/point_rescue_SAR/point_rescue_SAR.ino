#include <SPI.h>
#include <LoRa.h>
#include <TinyGPS++.h>
#include <ArduinoJson.h>

// ============================================================
// SAR NODE — Perangkat Tim Search And Rescue
// Node ID: 1XXX (contoh: 1001, 1002, 1003, ...)
// ============================================================
#define NODE_ID   1111   // <-- UBAH nomor ini per device SAR (1001, 1002, dst)
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

enum PacketType : uint8_t { PKT_HEARTBEAT = 0, PKT_TRACKING = 1, PKT_SOS = 2 };

uint8_t hopLimitFor(PacketType t) {
  switch (t) {
    case PKT_HEARTBEAT: return 1;
    case PKT_TRACKING:  return 3;
    case PKT_SOS:       return 5;
  }
  return 3;
}

uint8_t priorityFor(PacketType t) {
  switch (t) {
    case PKT_SOS:       return 2;
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

// ============================================================
// GPS & LORA OBJECTS
// ============================================================
TinyGPSPlus    gps;
HardwareSerial gpsSerial(2);
uint32_t seqCounter = 0;

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
  enqueueTx(buildPacket(type, includeGPS), priorityFor(type));
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
  if (type < 0 || type > 2) return false;

  int hop = doc["hop"].as<int>();
  if (hop < 0 || hop > 10) return false;

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
  } else {
    Serial.println(F("  [INFO] Paket ini heartbeat — tidak membawa data lokasi"));
  }

  if (type == PKT_SOS) Serial.printf("  ⚠️  SOS DITERIMA dari node %d !!\n", originId);

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

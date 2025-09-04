CREATE TABLE subscriber (
    id BIGSERIAL PRIMARY KEY,
    owner_eid VARCHAR NOT NULL,
    subscriber_eid VARCHAR NOT NULL,
    status VARCHAR NOT NULL CHECK (status IN ('block', 'active')),
    awareness_status VARCHAR NOT NULL DEFAULT 'allow' CHECK (awareness_status IN ('allow', 'block')),
    inserted_at TIMESTAMP DEFAULT now()
);

-- 🔎 Indexes
CREATE INDEX idx_subscriber_owner ON subscriber (owner_eid);
CREATE INDEX idx_subscriber_member ON subscriber (subscriber_eid);
CREATE INDEX idx_subscriber_status ON subscriber (status);

CREATE TABLE devices (
    id SERIAL PRIMARY KEY,                 -- auto-increment id
    device_id VARCHAR UNIQUE NOT NULL,     -- unique device identifier
    eid VARCHAR NOT NULL,
    last_seen TIMESTAMP,
    ws_pid TEXT,
    status VARCHAR,
    last_received_version INTEGER,
    ip_address VARCHAR,
    app_version VARCHAR,
    os VARCHAR,
    last_activity TIMESTAMP,
    supports_notifications BOOLEAN DEFAULT FALSE,
    supports_media BOOLEAN DEFAULT FALSE,
    status_source VARCHAR,
    awareness_intention INTEGER DEFAULT 0,
    inserted_at TIMESTAMP DEFAULT now()
);

-- Index for querying by user_id
CREATE INDEX devices_eid_index ON devices(eid);




pingpong = %Dartmessaging.PingPong{
  from: "a@domain.com",
  to: "b@domain.com",
  type: 0,
  status: 0,
  request_time: DateTime.to_unix(DateTime.utc_now(), :millisecond),
  response_time: 0
}

message = %Dartmessaging.MessageScheme{
  route: 6, 
  payload: {:pingpong_message, pingpong}
}

binary = Dartmessaging.MessageScheme.encode(message)
hex = Base.encode16(binary, case: :upper)
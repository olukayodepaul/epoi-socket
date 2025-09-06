```
message AwarenessRequest {
  Identity from = 1;
  Identity to = 2;
  int64 awareness_identifier = 3;  // Unique request ID
  int64 timestamp = 4;
}

message AwarenessResponse {
  Identity from = 1;
  Identity to = 2;
  string awareness_identifier = 3;
  int32 status = 4;                 // 1=ONLINE, 2=OFFLINE, 3=AWAY, 4=BUSY, 5=DO_NOT_DISTURB, 6=INVISIBLE, 7=IDLE, 8=UNKNOWN
  double latitude = 5;
  double longitude = 6;
  int32 awareness_intention = 7;
  int64 timestamp = 8;
}

message TokenRevokeRequest {
  Identity to = 1;
  string token = 2;
  int64 timestamp = 3;
}

message TokenRevokeResponse {
  Identity to = 1;
  int32 status = 2;       // 1=SUCCESS, 2=FAILED
  int64 timestamp = 3;
}

message SubscriberAddRequest {
  Identity owner = 1;
  Identity subscriber = 2;
  string nickname = 3;
  string group = 4;
  string subscriber_resource_id = 5;
  int64 timestamp = 6;
}

message SubscriberAddResponse {
  Identity owner = 1;
  Identity subscriber = 2;
  string subscriber_resource_id = 3;
  int32 status = 4;       // 1=SUCCESS, 2=FAILED
  string message = 5;
  int64 timestamp = 6;
}

message BlockSubscriber {
  Identity owner = 1;
  Identity subscriber = 2;
  int32 type = 3;           // 1=REQUEST, 2=RESPONSE
  int32 status = 4;         // 1=SUCCESS, 2=FAILED (if RESPONSE)
  string message = 5;
  int64 timestamp = 6;
}




//messaging protoco
// ---------------- Payloads ----------------
message TextPayloadRequest {
  Identity from           = 1;
  repeated Identity to    = 2;
  string content          = 3;
  string message_id_local = 4;
  string text_size_count  = 5;
  int64 created_at        = 6;

  // Optional fields for media attachments
  string cdn_url_id       = 7;  // client-generated resource ID for image/file
  int64 media_size_bytes  = 8;  // size of the media if attached
}


//using grpc for images on cdn servers. send to cdn server to upload image and return with thumbnail_url
//note, generate the thumbnail_url from client.
message MediaPayloadRequest {
  Identity from           = 1;
  repeated Identity to    = 2;
  string message_id_local = 3;
  string chat_id          = 4;
  int32  type             = 5;  // 1=image | 2=audio | 3=video | 4=file
  string caption          = 6;
  string cdn_url_id       = 8;
  int64 media_size_bytes  = 9;
  int64 created_at        = 10;
}

def generate_image_resource_id(username, device_id) do
  timestamp = DateTime.utc_now() |> DateTime.to_unix(:millisecond)
  random_hash = :crypto.strong_rand_bytes(6) |> Base.url_encode64(padding: false)
  "#{username}-#{device_id}-#{timestamp}-#{random_hash}"
end


// ---------------- Acknowledgment ----------------
// 1. Receiver send acknowledgment to senders
// 2. Sender acknowledge receive base of the status
message AcknowledgmentRequest{
  Identity from     = 1;       // receiving client
  Identity to       = 2;       // original sender
  string message_id = 3;
  int32  status     = 4;       // Sender ( 1 = unread | 2 = delivered | 3=read ) || Reciever ( 4 = sent | 2 = delivered | 3 = read )
  int64  timestamp  = 5;
}

message AcknowledgmentResponse{
  Identity from     = 1;    // receiving client
  Identity to       = 2;    // original sender
  string message_id = 3;
  int32  status     = 4;    // Sender ( 1 = unread | 2 = delivered | 3=read ) || Reciever ( 4 = sent | 2 = delivered | 3 = read )
  int64  timestamp  = 5;
}

// ---------------- ChatMessage ----------------
// sender keep a version of this
// server send a version of this to recervers.
message ChatMessage {
  Identity from           = 5;
  repeated Identity to    = 6;
  string message_id       = 1;  // server-assigned global ID
  string message_id_local = 2;  // client temporary ID
  int64  version          = 3;  // server-assigned chat sequence
  string chat_id          = 4;  // conversation ID
  string ownership        = 5;  // 1 = sender, 2 = receiver

  oneof payload {
    string  text  = 7;
    string media_url = 8; //cnd links
  }

  string acknowledgment =  9; // update acknowledgment status
  string  acknowledgment_timestamp =  10; // update acknowledgment timestamp

  int64 created_at         = 9;
  int64 server_received_at = 10;

}


message MessageScheme {
  int64 route = 1;

  oneof payload {
    AwarenessNotification awareness_notification = 2;
    AwarenessResponse awareness_response = 3;
    AwarenessRequest awareness_request = 4;


    TokenRevokeRequest token_revoke_request = 7;
    TokenRevokeResponse token_revoke_response = 8;
    SubscriberAddRequest subscriber_add_request = 9;
    SubscriberAddResponse subscriber_add_response = 10;
    BlockSubscriber block_subscriber = 11;
    Logout logout = 12;
    TextPayloadRequest text_payload_request = 13
    MediaPayloadRequest media_payload_request = 14;
  }
}


```
